import 'dart:async';

import 'package:enfoque_app_mobile/l10n/app_localizations.dart';
import 'package:enfoque_app_mobile/models/enfoque.dart';
import 'package:enfoque_app_mobile/models/enlace_entrada.dart';
import 'package:enfoque_app_mobile/screens/estadisticas_screen.dart';
import 'package:enfoque_app_mobile/screens/inicio_screen.dart';
import 'package:enfoque_app_mobile/screens/resultado_screen.dart';
import 'package:enfoque_app_mobile/screens/sesion_screen.dart';
import 'package:enfoque_app_mobile/services/api_service_enfoque.dart';
import 'package:enfoque_app_mobile/services/controlador_enfoque.dart';
import 'package:enfoque_app_mobile/widgets/barras_semana.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'montaje.dart';

/// Las pantallas principales con falsos de reloj, pantalla y API.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppLocalizations l;
  late NordayCoreLocalizations c;

  setUpAll(() async {
    await initializeDateFormatting();
    l = await AppLocalizations.delegate.load(const Locale('es'));
    c = await NordayCoreLocalizations.delegate.load(const Locale('es'));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Deja correr futuros y animaciones un rato. Sin pumpAndSettle: el fondo
  /// y Nori se animan sin fin.
  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Termina la sesión que quede para que el motor no deje temporizadores.
  Future<void> cerrarSesion(WidgetTester tester, Montaje m) async {
    if (m.motor.sesion.value?.estado.activa ?? false) {
      await m.motor.rendirse();
    }
    await asentar(tester);
  }

  group('Inicio', () {
    final hoy = DateTime(2026, 11, 18);

    Widget inicio(Montaje m) =>
        m.app(Scaffold(body: InicioScreen(usuarioId: 7, hoy: () => hoy)));

    testWidgets('cifras de hoy, duración, destinos y Empezar', (tester) async {
      final m = Montaje(tester);
      m.api.listaDestinos = [destinoLeer];
      m.api.resumenDado = ResumenEnfoque(
        dias: [DiaResumen(dia: hoy, minutos: 50, sesiones: 2)],
        totalMinutos: 50,
        totalSesiones: 2,
        rachaActual: 3,
      );
      await m.controlador.iniciar();
      await tester.pumpWidget(inicio(m));
      await asentar(tester);

      expect(m.api.resumenesPedidos.single, (hoy, hoy));
      expect(find.text('50'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3 días'), findsOneWidget);
      expect(
        find.bySemanticsLabel('${l.inicioMinutosHoy}: 50'),
        findsOneWidget,
      );
      expect(find.text('Leer · 20 / 30 min'), findsOneWidget);
      expect(find.text(l.destinoSinHabito), findsOneWidget);
      // 25 por defecto: en el chip y en el selector.
      expect(find.text('25 min'), findsNWidgets(2));

      await tester.tap(find.text('45 min'));
      await tester.pump();
      expect(find.text('45 min'), findsNWidgets(2));
      await tester.tap(find.byTooltip(l.duracionMas));
      await tester.pump();
      expect(find.text('50 min'), findsOneWidget);

      await tester.tap(find.text('Leer · 20 / 30 min'));
      await tester.pump();
      await tester.tap(find.text(l.inicioEmpezar));
      await asentar(tester);

      // El permiso se pide la primera vez, y solo esa.
      expect(m.permisosPedidos, [7]);
      final s = m.motor.sesion.value!;
      expect(s.estado, EstadoSesion.corriendo);
      expect(s.duracionObjetivo, const Duration(minutes: 50));
      expect(destinoDeDatos(s.datosApp)!.id, 16);

      await cerrarSesion(tester, m);
      await m.controlador.motor.cerrar();
      m.controlador.soltarResultado();
      await tester.tap(find.text(l.inicioEmpezar));
      await asentar(tester);
      expect(m.permisosPedidos, [7]);
      await cerrarSesion(tester, m);
    });

    testWidgets('un destino de una hora o más, en horas', (tester) async {
      final m = Montaje(tester);
      m.api.listaDestinos = [destinoLeerLargo];
      await tester.pumpWidget(inicio(m));
      await asentar(tester);

      expect(find.text('Leer · 1 h / 1 h 30 min'), findsOneWidget);
      expect(find.textContaining('60 / 90'), findsNothing);
    });

    testWidgets('el primer Empezar no espera al permiso ni al registro del '
        'aviso', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final m = Montaje(tester);
      m.puertaPermiso = Completer<bool>();
      await m.controlador.iniciar();
      await tester.pumpWidget(inicio(m));
      await asentar(tester);
      await tester.tap(find.text(l.inicioEmpezar));
      await asentar(tester);
      expect(m.permisosPedidos, [7]);
      expect(m.motor.sesion.value!.estado, EstadoSesion.corriendo);
      m.puertaPermiso!.complete(false);
      await cerrarSesion(tester, m);
    });

    testWidgets('sin hábitos de minutos: «Crea hábitos en Norday Habits» '
        'abre Habits', (tester) async {
      final m = Montaje(tester);
      m.lanzador.abre = ({enlace, paquete}) => true;
      await tester.pumpWidget(inicio(m));
      await asentar(tester);

      expect(find.text(l.destinoSinHabitosMinutos), findsOneWidget);
      await tester.tap(find.text(l.destinoCrearEnHabits));
      await asentar(tester);
      expect(m.lanzador.llamadas.single.paquete, 'com.norday.habitos.prueba');
    });

    testWidgets('un enlace deja elegido su hábito', (tester) async {
      final m = Montaje(tester);
      m.api.listaDestinos = [destinoLeer];
      m.servicios.pedirDestino(const DestinoPedido('habito', 16));
      await tester.pumpWidget(inicio(m));
      await asentar(tester);

      final opcion = find.widgetWithText(OpcionDestino, 'Leer · 20 / 30 min');
      expect(
        find.descendant(
          of: opcion,
          matching: find.byIcon(LucideIcons.circleCheck),
        ),
        findsOneWidget,
      );
      expect(m.servicios.destinoPedido.value, isNull);
    });

    testWidgets('un enlace a un hábito que no está: aviso y «Sin hábito»', (
      tester,
    ) async {
      final m = Montaje(tester);
      m.api.listaDestinos = [destinoLeer];
      await tester.pumpWidget(inicio(m));
      await asentar(tester);
      m.servicios.pedirDestino(const DestinoPedido('habito', 99));
      await asentar(tester);

      expect(find.text(l.destinoNoDisponible), findsOneWidget);
      final sin = find.widgetWithText(OpcionDestino, l.destinoSinHabito);
      expect(
        find.descendant(
          of: sin,
          matching: find.byIcon(LucideIcons.circleCheck),
        ),
        findsOneWidget,
      );
    });

    testWidgets('error al cargar: raya en las cifras y reintentar', (
      tester,
    ) async {
      final m = Montaje(tester);
      m.api.errorDestinos = const ApiException(TipoErrorApi.sinConexion);
      m.api.errorResumen = const ApiException(TipoErrorApi.sinConexion);
      await tester.pumpWidget(inicio(m));
      await asentar(tester);

      expect(find.text('—'), findsNWidgets(3));
      expect(find.text(l.destinosError), findsOneWidget);
      m.api.errorDestinos = null;
      m.api.listaDestinos = [destinoLeer];
      await tester.tap(find.text(c.reintentar));
      await asentar(tester);
      expect(find.text('Leer · 20 / 30 min'), findsOneWidget);
    });
  });

  group('Sesión', () {
    testWidgets('aro con la cuenta atrás, destino, aviso fijo y botones', (
      tester,
    ) async {
      final m = Montaje(tester);
      await m.controlador.iniciar();
      await m.controlador.empezar(
        duracion: const Duration(minutes: 25),
        destino: destinoLeer,
      );
      await tester.pumpWidget(
        m.app(
          SesionScreen(
            controlador: m.controlador,
            cargarMascota: () async => null,
          ),
        ),
      );
      await asentar(tester);

      expect(find.byType(AroCuentaAtras), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.bySemanticsLabel('Quedan 25 minutos'), findsOneWidget);
      expect(find.text('Leer · 20 / 30 min'), findsOneWidget);
      expect(find.text(c.sesionAvisoSalir), findsOneWidget);
      expect(find.text(l.sesionTerminar), findsOneWidget);
      expect(find.text(l.sesionRendirse), findsOneWidget);

      // Pasa el tiempo: la cuenta atrás baja.
      m.reloj.avanzar(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      await asentar(tester);
      expect(find.text('20:00'), findsOneWidget);

      // Terminar a los 5 min avisa de que no contará.
      await tester.tap(find.text(l.sesionTerminar));
      await asentar(tester);
      expect(find.text(l.sesionTerminarCorta), findsOneWidget);
      await tester.tap(find.text(l.sesionSeguir));
      await asentar(tester);
      expect(m.motor.sesion.value!.estado, EstadoSesion.corriendo);

      // Rendirse, confirmado: perdida.
      await tester.tap(find.text(l.sesionRendirse));
      await asentar(tester);
      expect(find.text(l.sesionRendirseCuerpo), findsOneWidget);
      await tester.tap(find.text(l.sesionRendirse).last);
      await asentar(tester);
      expect(
        m.controlador.resultado.value!.sesion.estado,
        EstadoSesion.perdida,
      );
    });

    testWidgets('el destino de una hora o más va en horas', (tester) async {
      final m = Montaje(tester);
      await m.controlador.iniciar();
      await m.controlador.empezar(
        duracion: const Duration(minutes: 25),
        destino: destinoLeerLargo,
      );
      await tester.pumpWidget(
        m.app(
          SesionScreen(
            controlador: m.controlador,
            cargarMascota: () async => null,
          ),
        ),
      );
      await asentar(tester);

      expect(find.text('Leer · 1 h / 1 h 30 min'), findsOneWidget);
      await cerrarSesion(tester, m);
    });

    testWidgets('Terminar con 10 min o más: cuenta con lo hecho', (
      tester,
    ) async {
      final m = Montaje(tester);
      await m.controlador.iniciar();
      await m.controlador.empezar(duracion: const Duration(minutes: 25));
      await tester.pumpWidget(
        m.app(
          SesionScreen(
            controlador: m.controlador,
            cargarMascota: () async => null,
          ),
        ),
      );
      m.reloj.avanzar(const Duration(minutes: 12));
      await tester.pump(const Duration(seconds: 1));
      await asentar(tester);
      expect(find.text(l.destinoSinHabito), findsOneWidget);

      await tester.tap(find.text(l.sesionTerminar));
      await asentar(tester);
      expect(find.text(l.sesionTerminarCuenta(12)), findsOneWidget);
      await tester.tap(find.text(l.sesionTerminar).last);
      await asentar(tester);
      expect(m.api.enviadas.single.estado, EstadoEnvio.terminada);
    });
  });

  group('Resultado', () {
    Future<Montaje> acabar(
      WidgetTester tester, {
      ResultadoEnvio? envio,
      DestinoDisponible? destino = destinoLeer,
      Duration duracion = const Duration(minutes: 25),
      Duration hecho = const Duration(minutes: 25),
    }) async {
      final m = Montaje(tester);
      if (envio != null) m.api.envios.add(envio);
      await m.controlador.iniciar();
      await m.controlador.empezar(duracion: duracion, destino: destino);
      m.reloj.avanzar(hecho);
      await m.motor.terminar();
      await asentar(tester);
      await tester.pumpWidget(
        m.app(ResultadoScreen(controlador: m.controlador)),
      );
      await asentar(tester);
      return m;
    }

    testWidgets('aceptado: «+25 min a Leer (30 / 30)», monedas y logros', (
      tester,
    ) async {
      final m = await acabar(
        tester,
        envio: const EnvioAceptado(
          RespuestaSesion(
            aporte: Aporte(
              estado: EstadoAporte.aceptado,
              minutos: 25,
              monedas: 10,
              minutosDia: 30,
              minutosObjetivo: 30,
              diaHecho: true,
              logros: ['MASCOTA_CRIA', 'RACHA_3'],
            ),
          ),
          nueva: true,
        ),
      );
      expect(find.text(l.resultadoCompletada), findsOneWidget);
      expect(find.text('25 min'), findsOneWidget);
      expect(find.text('+25 min a Leer (30 / 30)'), findsOneWidget);
      expect(find.text('+10 monedas'), findsOneWidget);
      expect(find.text(l.resultadoDiaHecho), findsOneWidget);
      // MASCOTA_CRIA lo nombra el core y se celebra; RACHA_3 es de Habits.
      expect(find.text(l.resultadoLogrosEnHabits(1)), findsOneWidget);
      expect(m.celebrados, ['MASCOTA_CRIA']);

      await tester.tap(find.text(l.resultadoVolver));
      await asentar(tester);
      expect(m.controlador.resultado.value, isNull);
    });

    testWidgets('una hora o más: «+1 h 30 min a Leer (1 h 30 min / 2 h)»', (
      tester,
    ) async {
      await acabar(
        tester,
        duracion: const Duration(minutes: 120),
        hecho: const Duration(minutes: 90),
        envio: const EnvioAceptado(
          RespuestaSesion(
            aporte: Aporte(
              estado: EstadoAporte.aceptado,
              minutos: 90,
              minutosDia: 90,
              minutosObjetivo: 120,
            ),
          ),
          nueva: true,
        ),
      );
      expect(find.text(l.resultadoTerminada), findsOneWidget);
      expect(find.text('1 h 30 min'), findsOneWidget);
      expect(
        find.text('+1 h 30 min a Leer (1 h 30 min / 2 h)'),
        findsOneWidget,
      );
    });

    testWidgets('rechazado: el motivo del backend', (tester) async {
      await acabar(
        tester,
        envio: const EnvioAceptado(
          RespuestaSesion(
            aporte: Aporte(
              estado: EstadoAporte.rechazado,
              motivo: 'habitos.enfoque.pausado',
              motivoTexto: 'El hábito está en pausa',
            ),
          ),
          nueva: true,
        ),
      );
      expect(find.text(l.resultadoAporteRechazado('Leer')), findsOneWidget);
      expect(find.text('El hábito está en pausa'), findsOneWidget);
    });

    testWidgets('sin red: pendiente de enviar', (tester) async {
      await acabar(
        tester,
        envio: const EnvioFallido(ApiException(TipoErrorApi.sinConexion)),
      );
      expect(find.text(l.resultadoPendiente), findsOneWidget);
    });

    testWidgets('409: no se pudo guardar, con el mensaje', (tester) async {
      await acabar(
        tester,
        envio: const EnvioRechazado(409, 'Se solapa con otra sesión'),
      );
      expect(find.text(l.resultadoNoAceptada), findsOneWidget);
      expect(find.text('Se solapa con otra sesión'), findsOneWidget);
    });

    testWidgets('descartada: no cuenta, no se envía', (tester) async {
      final m = await acabar(tester, hecho: const Duration(minutes: 4));
      expect(find.text(l.resultadoDescartada), findsOneWidget);
      expect(find.text(l.resultadoDescartadaCuerpo), findsOneWidget);
      expect(m.api.enviadas, isEmpty);
    });
  });

  group('Estadísticas', () {
    testWidgets('barras, totales, pendientes e historial', (tester) async {
      final m = Montaje(tester);
      // Miércoles 18-nov-2026.
      final hoy = DateTime(2026, 11, 18);
      m.api.resumenDado = ResumenEnfoque(
        dias: [
          DiaResumen(dia: DateTime(2026, 11, 2), minutos: 40, sesiones: 1),
          DiaResumen(dia: DateTime(2026, 11, 16), minutos: 25, sesiones: 1),
          DiaResumen(dia: DateTime(2026, 11, 18), minutos: 15, sesiones: 1),
        ],
      );
      m.api.historialDado = PaginaHistorial(
        sesiones: [
          SesionServidor(
            clave: 's1',
            inicioUtc: DateTime.utc(2026, 11, 16, 8),
            duracionSeg: 1500,
            duracionObjetivoMin: 25,
            estado: EstadoEnvio.completada,
            destinoTipo: 'habito',
            destinoId: 16,
          ),
        ],
      );
      m.api.listaDestinos = [destinoLeer];
      m.api.envioPorDefecto = (_) =>
          const EnvioFallido(ApiException(TipoErrorApi.sinConexion));
      await m.cola.encolar(
        peticionDePrueba(clave: 'pendiente', duracionSeg: 900),
        usuarioId: 7,
        destino: destinoLeer,
      );

      await tester.pumpWidget(
        m.app(Scaffold(body: EstadisticasScreen(hoy: () => hoy))),
      );
      await asentar(tester);

      expect(find.byType(BarrasSemana), findsOneWidget);
      expect(find.bySemanticsLabel('lunes: 25 minutos'), findsOneWidget);
      expect(find.bySemanticsLabel('miércoles: 15 minutos'), findsOneWidget);
      expect(find.bySemanticsLabel('${l.estSemana}: 40 min'), findsOneWidget);
      expect(find.bySemanticsLabel('${l.estMes}: 80 min'), findsOneWidget);
      expect(find.textContaining(l.estadoPendiente), findsOneWidget);
      expect(find.text('15 de 25 min · Leer'), findsOneWidget);
      expect(find.textContaining(l.estadoCompletada), findsOneWidget);
      expect(find.text('25 de 25 min · Leer'), findsOneWidget);
    });
  });

  group('Estadísticas, carga', () {
    SesionServidor sesion(
      String clave, {
      String tipo = 'habito',
      int id = 16,
    }) => SesionServidor(
      clave: clave,
      inicioUtc: DateTime.utc(2026, 11, 16, 8),
      duracionSeg: 600,
      duracionObjetivoMin: 25,
      estado: EstadoEnvio.terminada,
      destinoTipo: tipo,
      destinoId: id,
    );

    testWidgets('«Cargar más» que llega después de recargar se descarta', (
      tester,
    ) async {
      final m = Montaje(tester);
      final hoy = DateTime(2026, 11, 18);
      m.api.paginasHistorial[0] = PaginaHistorial(
        sesiones: [sesion('p0')],
        hayMas: true,
      );
      final puerta = Completer<void>();
      m.api.puertasHistorial[1] = puerta;
      m.api.paginasHistorial[1] = PaginaHistorial(sesiones: [sesion('vieja')]);

      Widget pantalla(bool activa) => m.app(
        Scaffold(
          body: EstadisticasScreen(activa: activa, hoy: () => hoy),
        ),
      );
      await tester.pumpWidget(pantalla(true));
      await asentar(tester);
      await tester.tap(find.text(l.estCargarMas));
      await asentar(tester);

      // Mientras tanto, recarga (vuelve a la pestaña) con otra página 0.
      m.api.paginasHistorial[0] = PaginaHistorial(sesiones: [sesion('nueva')]);
      await tester.pumpWidget(pantalla(false));
      await tester.pumpWidget(pantalla(true));
      await asentar(tester);
      puerta.complete();
      await asentar(tester);

      expect(find.byType(FilaSesion), findsOneWidget);
      expect(find.text(l.estCargarMas), findsNothing);
    });

    testWidgets('el nombre del destino va por tipo e id', (tester) async {
      final m = Montaje(tester);
      m.api.listaDestinos = [destinoLeer];
      m.api.historialDado = PaginaHistorial(
        sesiones: [sesion('otro', tipo: 'otro', id: 16)],
      );
      await tester.pumpWidget(
        m.app(
          Scaffold(body: EstadisticasScreen(hoy: () => DateTime(2026, 11, 18))),
        ),
      );
      await asentar(tester);
      expect(find.text('10 de 25 min · Leer'), findsNothing);
      expect(find.text('10 de 25 min · ${l.filaSesionHabito}'), findsOneWidget);
    });
  });
}
