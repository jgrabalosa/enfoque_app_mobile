import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:norday_flutter_core/norday_flutter_core.dart';

import '../models/enfoque.dart';

/// Qué pasó al enviar una sesión.
sealed class ResultadoEnvio {
  const ResultadoEnvio();
}

/// 201 (nueva) o 200 (la clave ya estaba, con el mismo cuerpo: el resultado
/// original). La sesión está guardada en el backend.
class EnvioAceptado extends ResultadoEnvio {
  final RespuestaSesion respuesta;
  final bool nueva;
  const EnvioAceptado(this.respuesta, {required this.nueva});
}

/// 400 o 409: definitivo. Reintentar la misma no cambia nada.
class EnvioRechazado extends ResultadoEnvio {
  final int codigoHttp;

  /// El `mensaje` del backend, ya en el idioma del usuario.
  final String? mensaje;
  const EnvioRechazado(this.codigoHttp, this.mensaje);
}

/// 5xx, sin respuesta o cualquier otra cosa que no sea definitiva:
/// reintentar más tarde con la misma clave y el mismo cuerpo.
class EnvioFallido extends ResultadoEnvio {
  final ApiException error;
  const EnvioFallido(this.error);
}

/// Los endpoints de Norday Focus. Abstracto para poder probar la cola y las
/// pantallas con un falso.
abstract interface class ApiEnfoque {
  /// `GET /api/enfoque/destinos`. Lanza [ApiException].
  Future<List<DestinoDisponible>> destinos();

  /// `POST /api/enfoque/sesiones`. No lanza: todo va en el resultado.
  Future<ResultadoEnvio> enviarSesion(PeticionSesion peticion);

  /// `GET /api/enfoque/resumen?desde=&hasta=` (como mucho 62 días). Lanza
  /// [ApiException].
  Future<ResumenEnfoque> resumen(DateTime desde, DateTime hasta);

  /// `GET /api/enfoque/sesiones?pagina=&tamano=`. Lanza [ApiException].
  Future<PaginaHistorial> historial({int pagina = 0, int tamano = 20});
}

/// Disparadores: los endpoints que saben de sesiones de enfoque. Todo lo
/// genérico —sesión, usuario, gamificación, tienda, mascota— vive en
/// `ApiServiceCore`, dentro de norday_flutter_core.
///
/// Se apoya en la tubería del motor ([ApiServiceCore.enviar], `verificar`,
/// `parsear`) para que un fallo de red se clasifique igual aquí que allí. El
/// usuario sale del token: ninguna ruta lleva su id.
class ApiServiceEnfoque implements ApiEnfoque {
  ApiServiceEnfoque({
    http.Client? cliente,
    Future<Map<String, String>> Function()? cabeceras,
    this.baseUrl = ApiServiceCore.baseUrl,
  }) : _cliente = cliente ?? ApiServiceCore.cliente,
       _cabeceras = cabeceras ?? ApiServiceCore.getHeaders;

  final http.Client _cliente;
  final Future<Map<String, String>> Function() _cabeceras;
  final String baseUrl;

  Uri _uri(String ruta, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/enfoque/$ruta').replace(queryParameters: query);

  @override
  Future<List<DestinoDisponible>> destinos() async {
    final headers = await _cabeceras();
    final r = await ApiServiceCore.enviar(
      () => _cliente.get(_uri('destinos'), headers: headers),
    );
    ApiServiceCore.verificar(r);
    return ApiServiceCore.parsear(() => destinosDe(jsonDecode(cuerpoDe(r))));
  }

  @override
  Future<ResultadoEnvio> enviarSesion(PeticionSesion peticion) async {
    try {
      final headers = await _cabeceras();
      final r = await ApiServiceCore.enviar(
        () => _cliente.post(
          _uri('sesiones'),
          headers: headers,
          body: jsonEncode(peticion.toJson()),
        ),
      );
      if (r.statusCode == 200 || r.statusCode == 201) {
        // Un 2xx con un cuerpo que no se entiende sigue siendo una sesión
        // guardada: reintentarla daría otra vez el mismo 200. Se da por
        // enviada, sin detalles del aporte.
        RespuestaSesion respuesta;
        try {
          respuesta = RespuestaSesion.fromJson(jsonDecode(cuerpoDe(r)));
        } catch (_) {
          respuesta = const RespuestaSesion();
        }
        return EnvioAceptado(respuesta, nueva: r.statusCode == 201);
      }
      if (r.statusCode == 400 || r.statusCode == 409) {
        return EnvioRechazado(r.statusCode, mensajeDe(cuerpoDe(r)));
      }
      // Lo demás lo clasifica el core: un 401 cierra además la sesión
      // (alCaducarSesion) y la sesión espera en la cola al siguiente login.
      ApiServiceCore.verificar(r, ok: const [200, 201]);
      throw ApiException(
        TipoErrorApi.respuestaInesperada,
        codigoEstado: r.statusCode,
      );
    } on ApiException catch (e) {
      return EnvioFallido(e);
    } catch (e) {
      // Leer el token o montar la petición puede fallar por cosas del
      // dispositivo: tampoco es definitivo.
      return EnvioFallido(
        ApiException(TipoErrorApi.sinConexion, cuerpo: e.toString()),
      );
    }
  }

  @override
  Future<ResumenEnfoque> resumen(DateTime desde, DateTime hasta) async {
    final headers = await _cabeceras();
    final r = await ApiServiceCore.enviar(
      () => _cliente.get(
        _uri('resumen', {'desde': textoDia(desde), 'hasta': textoDia(hasta)}),
        headers: headers,
      ),
    );
    ApiServiceCore.verificar(r);
    return ApiServiceCore.parsear(
      () => ResumenEnfoque.fromJson(jsonDecode(cuerpoDe(r))),
    );
  }

  @override
  Future<PaginaHistorial> historial({int pagina = 0, int tamano = 20}) async {
    final headers = await _cabeceras();
    final r = await ApiServiceCore.enviar(
      () => _cliente.get(
        _uri('sesiones', {'pagina': '$pagina', 'tamano': '$tamano'}),
        headers: headers,
      ),
    );
    ApiServiceCore.verificar(r);
    return ApiServiceCore.parsear(
      () => PaginaHistorial.fromJson(jsonDecode(cuerpoDe(r))),
    );
  }
}

/// El cuerpo en UTF-8, diga lo que diga la cabecera. `Response.body` de
/// `http` decodifica en latin1 si falta `Content-Type: application/json` (un
/// proxy que la quite basta), y los textos del backend llevan tildes.
String cuerpoDe(http.Response r) =>
    utf8.decode(r.bodyBytes, allowMalformed: true);

/// El `mensaje` de un cuerpo de error `{"mensaje": "..."}`, o `null`.
String? mensajeDe(String cuerpo) {
  try {
    final m = mapaDe(jsonDecode(cuerpo));
    final t = textoDe(m?['mensaje'])?.trim();
    return t == null || t.isEmpty ? null : t;
  } catch (_) {
    return null;
  }
}
