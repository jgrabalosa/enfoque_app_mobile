import 'dart:async';

import 'package:enfoque_app_mobile/models/enfoque.dart';
import 'package:enfoque_app_mobile/services/api_service_enfoque.dart';
import 'package:enfoque_app_mobile/services/canal_sistema.dart';
import 'package:enfoque_app_mobile/services/cola_envios.dart';
import 'package:enfoque_app_mobile/services/tanda.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

export 'datos_prueba.dart';

/// Reloj a mano, como el de los tests del motor en el core.
class RelojFalso implements FuenteReloj {
  int mono = 5000000;
  DateTime utc = DateTime.utc(2026, 11, 16, 9);

  void avanzar(Duration d) {
    mono += d.inMilliseconds;
    utc = utc.add(d);
  }

  @override
  Future<int> monotonicoMs() async => mono;

  @override
  DateTime ahoraUtc() => utc;
}

class PantallaFalsa implements FuentePantalla {
  bool valor = true;

  @override
  Future<bool> encendidaYDesbloqueada() async => valor;
}

/// Una API que contesta lo que se le diga y apunta lo que recibe.
class ApiFalsa implements ApiEnfoque {
  List<DestinoDisponible> listaDestinos = const [];
  Object? errorDestinos;
  ResumenEnfoque resumenDado = const ResumenEnfoque();
  Object? errorResumen;
  PaginaHistorial historialDado = const PaginaHistorial();

  /// Lo que contesta cada envío, en orden; agotado, [envioPorDefecto].
  final List<ResultadoEnvio> envios = [];
  ResultadoEnvio Function(PeticionSesion p)? envioPorDefecto;

  final List<PeticionSesion> enviadas = [];
  final List<Map<String, Object?>> cuerposEnviados = [];
  final List<(DateTime, DateTime)> resumenesPedidos = [];

  /// Si está puesta, cada envío espera a que se complete.
  Completer<void>? puertaEnvio;

  @override
  Future<List<DestinoDisponible>> destinos() async {
    if (errorDestinos != null) throw errorDestinos!;
    return listaDestinos;
  }

  @override
  Future<ResultadoEnvio> enviarSesion(PeticionSesion peticion) async {
    await puertaEnvio?.future;
    enviadas.add(peticion);
    cuerposEnviados.add(peticion.toJson());
    if (envios.isNotEmpty) return envios.removeAt(0);
    return envioPorDefecto?.call(peticion) ??
        EnvioAceptado(
          RespuestaSesion(
            aporte: Aporte(
              estado: peticion.conDestino
                  ? EstadoAporte.aceptado
                  : EstadoAporte.sinDestino,
              minutos: peticion.minutos,
            ),
          ),
          nueva: true,
        );
  }

  @override
  Future<ResumenEnfoque> resumen(DateTime desde, DateTime hasta) async {
    resumenesPedidos.add((desde, hasta));
    if (errorResumen != null) throw errorResumen!;
    return resumenDado;
  }

  /// Páginas concretas del historial; las demás, [historialDado].
  final Map<int, PaginaHistorial> paginasHistorial = {};

  /// Si hay puerta para una página, esa página espera a que se complete.
  final Map<int, Completer<void>> puertasHistorial = {};

  @override
  Future<PaginaHistorial> historial({int pagina = 0, int tamano = 20}) async {
    await puertasHistorial[pagina]?.future;
    return paginasHistorial[pagina] ?? historialDado;
  }
}

class LanzadorFalso implements Lanzador {
  /// Qué se abre: si devuelve true para esa llamada.
  bool Function({Uri? enlace, String? paquete}) abre = _nada;
  final List<({Uri? enlace, String? paquete})> llamadas = [];

  static bool _nada({Uri? enlace, String? paquete}) => false;

  @override
  Future<bool> abrir({Uri? enlace, String? paquete}) async {
    llamadas.add((enlace: enlace, paquete: paquete));
    return abre(enlace: enlace, paquete: paquete);
  }
}

/// Los avisos del descanso, apuntados.
class AvisosDescansoFalsos implements AvisosDescanso {
  final List<DateTime> programados = [];
  int cancelados = 0;

  @override
  Future<void> programarFin(DateTime finUtc) async => programados.add(finUtc);

  @override
  Future<void> cancelar() async => cancelados++;
}

/// Un temporizador que no corre: el test mira qué se programó.
class ProgramadorFalso {
  final List<Duration> esperas = [];
  final List<void Function()> acciones = [];

  Timer call(Duration espera, void Function() accion) {
    esperas.add(espera);
    acciones.add(accion);
    return _TimerQuieto();
  }
}

class _TimerQuieto implements Timer {
  bool _activo = true;
  @override
  void cancel() => _activo = false;
  @override
  bool get isActive => _activo;
  @override
  int get tick => 0;
}

/// Un almacén de la cola en memoria que puede fallar al leer o al escribir.
class AlmacenFalso implements AlmacenCola {
  final Map<String, String> datos = {};
  int lecturasQueFallan = 0;
  bool escrituraDevuelve = true;
  bool escrituraLanza = false;
  int escrituras = 0;

  @override
  Future<String?> leer(String clave) async {
    if (lecturasQueFallan > 0) {
      lecturasQueFallan--;
      throw StateError('disco ilegible');
    }
    return datos[clave];
  }

  @override
  Future<bool> escribir(String clave, String valor) async {
    escrituras++;
    if (escrituraLanza) throw StateError('disco lleno');
    if (!escrituraDevuelve) return false;
    datos[clave] = valor;
    return true;
  }
}
