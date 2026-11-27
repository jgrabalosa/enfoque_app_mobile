import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor, rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'entorno.dart';
import 'l10n/app_localizations.dart';
import 'l10n/logros_enfoque.dart';
import 'l10n/textos_enfoque.dart';
import 'models/enlace_entrada.dart';
import 'screens/home_shell.dart';
import 'services/api_service_enfoque.dart';
import 'services/avisos_sesion_locales.dart';
import 'services/canal_sistema.dart';
import 'services/cola_envios.dart';
import 'services/controlador_enfoque.dart';
import 'services/crashlytics_service.dart';
import 'services/desfase_servidor.dart';
import 'services/servicios_enfoque.dart';
import 'services/tanda.dart';

/// El usuario con la sesión abierta, o `null` (sin token no hay usuario).
Future<int?> usuarioIdActual() async {
  final usuario = await ApiServiceCore.getUsuarioLocal();
  final id = usuario?['usuarioId'];
  return id is int && id > 0 ? id : null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Antes que nada: si el flavor y la URL del backend no van juntos, no se
  // arranca. Así la app de prueba no escribe en producción ni un AAB de Play
  // sale apuntando a staging.
  final motivoEntorno = errorDeEntorno(
    flavor: appFlavor,
    url: ApiServiceCore.baseUrl,
  );
  if (motivoEntorno != null) {
    runApp(PantallaEntornoIncorrecto(motivo: motivoEntorno));
    return;
  }
  // El core es compartido por varias apps; esta app fija su dominio antes
  // de que cualquier catálogo pueda hacer una petición. Con él, el backend
  // filtra los catálogos y guarda el token de avisos como de `enfoque`.
  ApiServiceCore.appId = 'enfoque';
  // El core habla en neutro («Norday»): el nombre, el lema del login y los
  // textos de actualización obligatoria y de borrado de cuenta los pone la app.
  registrarTextosEnfoque();
  // Los nombres de los 21 logros propios de Focus, para la pantalla de logros
  // y las celebraciones: el core no puede conocerlos.
  registrarLogrosEnfoque();
  // Cada vez que la app vuelve a primer plano, si está por debajo de la
  // versión mínima que da el backend, se bloquea hasta actualizar. El
  // arranque lo comprueba el splash.
  VersionMinimaService.vigilarAlVolver();
  // Las siete familias van empaquetadas en `google_fonts/`, así que no hay
  // que salir a la red a por ellas. Con esto, un fichero que falte deja de
  // ser un fallo invisible —la fuente del sistema en su lugar— y pasa a
  // gritar en consola con el nombre exacto del que falta.
  GoogleFonts.config.allowRuntimeFetching = false;

  // La OFL obliga a distribuir la licencia con la fuente. Una por familia:
  // los nombres llevan sufijo porque los siete ficheros originales se llaman
  // igual y se pisarían al estar todos en la misma carpeta.
  LicenseRegistry.addLicense(() async* {
    for (final familia in const [
      'Caveat',
      'Chakra_Petch',
      'IBM_Plex_Sans',
      'Manrope',
      'Nunito',
      'Quicksand',
      'Space_Grotesk',
    ]) {
      final texto = await rootBundle.loadString(
        'google_fonts/OFL-$familia.txt',
      );
      yield LicenseEntryWithLineBreaks(['google_fonts'], texto);
    }
  });

  await Firebase.initializeApp();
  // Lo primero tras Firebase: si algo de lo de abajo revienta, ya hay red.
  await CrashlyticsService.inicializar();
  // Antes de runApp: si no, el primer frame se pinta en el idioma equivocado
  await IdiomaService.cargarAlArrancar();
  await SonidoService.cargarPreferencia();
  // Obligatorio: sin esto DateFormat lanza LocaleDataException para es/en/pt.
  await initializeDateFormatting();

  // Los avisos locales de la sesión. Si el plugin falla al arrancar, la
  // sesión sigue igual, solo que sin avisos.
  final salidaAvisos = SalidaAvisosPlugin();
  try {
    await salidaAvisos.inicializar();
  } catch (e, pila) {
    unawaited(CrashlyticsService.registrarError(e, pila));
  }

  // Lo que va el reloj del servidor por delante del móvil, medido en cada
  // respuesta del backend; corrige el inicio de las sesiones al encolarlas.
  final desfase = DesfaseServidor();
  await desfase.cargar();
  final api = ApiServiceEnfoque(desfase: desfase);
  final motor = MotorSesion(
    reloj: const RelojSistema(),
    pantalla: const PantallaSistema(),
    avisos: AvisosSesionLocales(salida: salidaAvisos),
  );
  final controlador = ControladorEnfoque(
    motor: motor,
    cola: ColaEnvios(api: api, usuarioActual: usuarioIdActual),
    usuarioActual: usuarioIdActual,
    desfase: desfase,
    enCurso: AvisoEnCursoLocal(salida: salidaAvisos),
  );
  final tanda = ControladorTanda(
    controlador: controlador,
    avisos: AvisosDescansoLocales(salida: salidaAvisos),
  );
  await tanda.cargar();
  final servicios = ServiciosEnfoque(
    api: api,
    controlador: controlador,
    tanda: tanda,
    lanzador: const LanzadorSistema(),
    flavor: appFlavor,
    usuarioActual: usuarioIdActual,
    pedirPermisoAvisos: NotificacionesService.pedirYRegistrar,
    celebrar: CelebracionService.mostrar,
  );

  // El motor escucha el ciclo de vida desde ya, antes de runApp: una sesión
  // en marcha sigue vigilada aunque la app abra en el login (sesión de
  // usuario caducada). Recoger la sesión acabada sigue siendo cosa de
  // HomeShell, que sabe quién está conectado.
  try {
    await motor.iniciar();
  } catch (e, pila) {
    unawaited(CrashlyticsService.registrarError(e, pila));
  }
  // La notificación fija mientras hay sesión, también con la app en el
  // login. Sin sesión activa, la para por si quedó colgada.
  controlador.vigilarEnCurso();

  // Lo que llega de Android sin pedirlo: el desbloqueo (para la sesión) y
  // los enlaces norday-enfoque:// con la app abierta.
  final eventos = EventosSistema()..escuchar();
  eventos.desbloqueos.listen((_) => motor.avisarDesbloqueo());
  eventos.enlaces.listen((e) => servicios.pedirDestino(destinoDeEnlace(e)));
  servicios.pedirDestino(destinoDeEnlace(await eventos.enlaceInicial()));

  // Si la sesión caduca con la app abierta, el core ya la ha borrado: aquí
  // sólo se lleva al login con el aviso, quitando todo lo que había debajo.
  // Una sesión de concentración en curso sigue en el motor y se recompone al
  // volver a entrar.
  ApiServiceCore.alCaducarSesion = () {
    nordayNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(
          destinoTrasLogin: destinoTrasLogin,
          sesionCaducada: true,
        ),
      ),
      (_) => false,
    );
  };
  runApp(EnfoqueApp(servicios: servicios));
}

class EnfoqueApp extends StatelessWidget {
  const EnfoqueApp({super.key, required this.servicios, this.home});

  final ServiciosEnfoque servicios;

  /// Para los tests: otra pantalla de entrada en vez del splash.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    // Dos notifiers anidados: el tema y el idioma cambian por su cuenta y
    // cualquiera de los dos debe repintar sin reiniciar la app.
    return AmbitoEnfoque(
      servicios: servicios,
      child: ValueListenableBuilder<TokensContextuales>(
        valueListenable: temaEquipadoNotifier,
        builder: (context, tema, _) {
          return ValueListenableBuilder<Locale>(
            valueListenable: IdiomaService.localeNotifier,
            builder: (context, locale, _) {
              return MaterialApp(
                // El del paquete, no uno propio: el motor lo necesita para
                // abrir cosas que no cuelgan de ninguna pantalla (la
                // celebración de un logro puede dispararse desde cualquier
                // sitio).
                navigatorKey: nordayNavigatorKey,
                // El nombre es de la app: el `appTitulo` del core dice
                // «Norday».
                onGenerateTitle: (context) =>
                    AppLocalizations.of(context)!.appNombre,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.deTema(tema),
                locale: locale,
                supportedLocales: IdiomaService.localesSoportados,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  NordayCoreLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                // La cinta «PRUEBA» por fuera del grano: tiene que verse en
                // cualquier identidad.
                builder: (context, child) => conCintaDeEntorno(
                  servicios.flavor,
                  envolverConGrano(context, child),
                ),
                home: home ?? const SplashScreen(),
              );
            },
          );
        },
      ),
    );
  }
}

/// El `builder` del MaterialApp: pone el grano de papel de Dulce encima de todo
/// lo que se pinte, pantallas, diálogos y hojas. No recibe toques ni se oye; en
/// las demás identidades no pinta nada. Igual que en Norday Habits.
Widget envolverConGrano(BuildContext context, Widget? child) => Stack(
  children: [
    child ?? const SizedBox.shrink(),
    Positioned.fill(
      child: RepaintBoundary(
        child: GranoPapel(
          key: ValueKey(identidadEquipadaNotifier.value.codigo),
        ),
      ),
    ),
  ],
);

/// Lo que el splash averigua antes de decidir a dónde ir.
class _Sesion {
  final String? token;
  final int? usuarioId;
  final bool? poseeIdentidad;

  /// Había sesión, pero el token ya había caducado: se va al login con el
  /// aviso.
  final bool caducada;

  /// La versión instalada está por debajo de la mínima: no se entra.
  final bool actualizar;
  const _Sesion(
    this.token,
    this.usuarioId,
    this.poseeIdentidad, {
    this.caducada = false,
    this.actualizar = false,
  });
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Future<_Sesion> _checkSession() async {
    // Lo primero: una versión por debajo de la mínima no pasa de aquí. Si el
    // backend no contesta, deja pasar.
    if (await VersionMinimaService.hayQueActualizar()) {
      return const _Sesion(null, null, null, actualizar: true);
    }
    // Antes que nada: con un token caducado, cualquier petición de aquí abajo
    // la rechazaría el backend mientras el splash aún decide a dónde ir.
    if (await ApiServiceCore.descartarSesionCaducada()) {
      return const _Sesion(null, null, null, caducada: true);
    }
    final token = await ApiServiceCore.getToken();
    if (token == null) return const _Sesion(null, null, null);
    final prefs = await SharedPreferences.getInstance();
    // Con sesión guardada, el aspecto lo manda el backend: puede haber
    // equipado otro tema desde otro dispositivo (o desde Norday Habits: la
    // cuenta y las identidades son las mismas).
    final usuarioId = prefs.getInt('usuarioId');
    bool? posee;
    if (usuarioId != null) {
      posee = await Equipamiento.cargarDeUsuarioSiSePuede(usuarioId);
      // El login ya registra el aviso; esto cubre al que abre la app con la
      // sesión guardada.
      unawaited(NotificacionesService.registrarSiHayPermiso(usuarioId));
    }
    return _Sesion(token, usuarioId, posee);
  }

  @override
  Widget build(BuildContext context) {
    return SplashGenerico<_Sesion>(
      // Sin rutaImagen: Norday Focus aún no tiene símbolo propio, así que el
      // splash pinta a Nori (NoriMarca), la caída del core.
      colorFondo: const Color(0xFF0A1628),
      wordmark: AppLocalizations.of(context)!.appNombre,
      tamanoWordmark: 32,
      tarea: _checkSession,
      onListo: (context, sesion) {
        if (sesion.actualizar) {
          VersionMinimaService.bloquear();
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (ctx) => sesion.token != null
                ? destinoConIdentidad(
                    ctx,
                    false,
                    sesion.poseeIdentidad,
                    sesion.usuarioId ?? 0,
                  )
                : LoginScreen(
                    destinoTrasLogin: destinoTrasLogin,
                    sesionCaducada: sesion.caducada,
                  ),
          ),
        );
      },
    );
  }
}
