import 'dart:convert';

import 'package:enfoque_app_mobile/l10n/app_localizations.dart';
import 'package:enfoque_app_mobile/screens/descanso_screen.dart';
import 'package:enfoque_app_mobile/screens/home_shell.dart';
import 'package:enfoque_app_mobile/screens/inicio_logica.dart';
import 'package:enfoque_app_mobile/screens/resultado_screen.dart';
import 'package:enfoque_app_mobile/screens/sesion_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'montaje.dart';

/// Qué pone encima HomeShell: la sesión mientras está activa y su resultado
/// cuando acaba, también al recomponer una sesión guardada.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppLocalizations l;

  setUpAll(() async {
    await initializeDateFormatting();
    l = await AppLocalizations.delegate.load(const Locale('es'));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Empezar abre la sesión; al acabar, el resultado; Listo, a '
      'Inicio', (tester) async {
    // Alto de sobra: Inicio es una lista y Empezar va al final.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final m = Montaje(tester);
    m.api.listaDestinos = [destinoLeer];
    await tester.pumpWidget(m.app(const HomeShell()));
    await asentar(tester);
    expect(find.text(l.inicioEmpezar), findsOneWidget);

    await tester.tap(find.text(l.inicioEmpezar));
    await asentar(tester);
    expect(find.byType(SesionScreen), findsOneWidget);

    m.reloj.avanzar(const Duration(minutes: 25));
    await tester.pump(const Duration(seconds: 1));
    await asentar(tester);
    expect(find.byType(SesionScreen), findsNothing);
    expect(find.byType(ResultadoScreen), findsOneWidget);
    expect(find.text(l.resultadoCompletada), findsOneWidget);
    expect(m.api.enviadas.single.duracionSeg, 1500);

    await tester.tap(find.text(l.resultadoListo));
    await asentar(tester);
    expect(find.byType(ResultadoScreen), findsNothing);
    expect(find.text(l.inicioEmpezar), findsOneWidget);
  });

  testWidgets('al entrar con una sesión activa guardada, se abre la sesión', (
    tester,
  ) async {
    final m = Montaje(tester);
    final s = SesionConcentracion.preparar(
      duracionObjetivo: const Duration(minutes: 25),
      clave: '11111111-2222-4333-8444-555555555555',
    ).empezar(monoMs: m.reloj.mono, ahoraUtc: m.reloj.utc);
    m.reloj.avanzar(const Duration(minutes: 3));
    SharedPreferences.setMockInitialValues({
      'sesion_concentracion_actual': jsonEncode(s.toJson()),
    });

    await tester.pumpWidget(m.app(const HomeShell()));
    await asentar(tester);
    expect(find.byType(SesionScreen), findsOneWidget);
    expect(find.text('22:00'), findsOneWidget);

    await m.motor.rendirse();
    await asentar(tester);
    expect(find.byType(ResultadoScreen), findsOneWidget);
    expect(find.text(l.resultadoPerdida), findsOneWidget);
  });

  group('Rondas', () {
    Future<Montaje> montar(
      WidgetTester tester, {
      Map<String, Object> prefs = const {claveRondas: 2},
    }) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(prefs);
      final m = Montaje(tester);
      await m.tanda.cargar();
      await tester.pumpWidget(m.app(const HomeShell()));
      await asentar(tester);
      return m;
    }

    Future<void> acabarRonda(WidgetTester tester, Montaje m) async {
      m.reloj.avanzar(const Duration(minutes: 25));
      await tester.pump(const Duration(seconds: 1));
      await asentar(tester);
    }

    testWidgets('dos rondas: la primera da paso al descanso; la segunda, al '
        'resultado', (tester) async {
      final m = await montar(tester);
      expect(
        find.text('2 × 25 min, con 5 min de descanso · 55 min'),
        findsOneWidget,
      );

      await tester.tap(find.text(l.inicioEmpezar));
      await asentar(tester);
      expect(find.byType(SesionScreen), findsOneWidget);
      expect(find.text('Ronda 1 de 2'), findsOneWidget);

      await acabarRonda(tester, m);
      expect(find.byType(DescansoScreen), findsOneWidget);
      expect(find.text(l.descansoTitulo), findsOneWidget);
      expect(find.text('Ronda 1 de 2 hecha'), findsOneWidget);
      expect(find.text(l.descansoCuerpo), findsOneWidget);
      expect(m.api.enviadas, hasLength(1));
      expect(
        m.avisosDescanso.programados.single,
        m.ahora.add(const Duration(minutes: 5)),
      );

      // El descanso acaba: no empieza sola la ronda, avisa y espera.
      m.ahora = m.ahora.add(const Duration(minutes: 6));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l.descansoListo), findsOneWidget);
      expect(find.byType(SesionScreen), findsNothing);

      await tester.tap(find.text('Empezar la ronda 2'));
      await asentar(tester);
      expect(find.byType(DescansoScreen), findsNothing);
      expect(find.byType(SesionScreen), findsOneWidget);
      expect(find.text('Ronda 2 de 2'), findsOneWidget);
      expect(m.avisosDescanso.cancelados, 1);

      await acabarRonda(tester, m);
      expect(find.byType(ResultadoScreen), findsOneWidget);
      expect(find.text('Ronda 2 de 2'), findsOneWidget);
      expect(find.text('2 rondas · 50 min'), findsOneWidget);
      expect(m.api.enviadas, hasLength(2));
      expect(m.tanda.tanda.value, isNull);

      await tester.tap(find.text(l.resultadoListo));
      await asentar(tester);
      expect(find.text(l.inicioEmpezar), findsOneWidget);
      expect(m.tanda.resumen.value, isNull);
    });

    testWidgets('«Otra igual» empieza otra tanda como la que acaba de '
        'terminar', (tester) async {
      final m = await montar(tester);
      await tester.tap(find.text(l.inicioEmpezar));
      await asentar(tester);
      await acabarRonda(tester, m);
      await tester.tap(find.text('Empezar la ronda 2'));
      await asentar(tester);
      await acabarRonda(tester, m);
      expect(find.byType(ResultadoScreen), findsOneWidget);

      await tester.tap(find.text(l.resultadoOtraIgual));
      await asentar(tester);
      expect(find.byType(ResultadoScreen), findsNothing);
      expect(find.byType(SesionScreen), findsOneWidget);
      expect(find.text('Ronda 1 de 2'), findsOneWidget);
      final s = m.motor.sesion.value!;
      expect(s.duracionObjetivo, const Duration(minutes: 25));
      expect(m.tanda.tanda.value!.rondas, 2);
      expect(m.tanda.tanda.value!.descanso, 5);
      expect(m.controlador.resultado.value, isNull);
      await m.motor.rendirse();
      await asentar(tester);
    });

    testWidgets('Nori va vestido en el resultado y celebra al entrar', (
      tester,
    ) async {
      final m = await montar(tester, prefs: const {claveRondas: 1});
      await tester.tap(find.text(l.inicioEmpezar));
      await asentar(tester);
      await acabarRonda(tester, m);
      expect(find.byType(ResultadoScreen), findsOneWidget);
      final nori = tester.widget<MascotaAnimadaViva>(
        find.byType(MascotaAnimadaViva),
      );
      expect(nori.vestida, isTrue);
      expect((nori.reaccion! as ValueListenable<int>).value, 1);
    });

    testWidgets('perdida: Nori sin reacción', (tester) async {
      final m = await montar(tester, prefs: const {claveRondas: 1});
      await tester.tap(find.text(l.inicioEmpezar));
      await asentar(tester);
      await m.motor.rendirse();
      await asentar(tester);
      expect(find.text(l.resultadoPerdida), findsOneWidget);
      final nori = tester.widget<MascotaAnimadaViva>(
        find.byType(MascotaAnimadaViva),
      );
      expect((nori.reaccion! as ValueListenable<int>).value, 0);
    });

    testWidgets('rendirse en la ronda 2 de 3: «1 de 3 rondas»', (tester) async {
      final m = await montar(tester, prefs: const {claveRondas: 3});
      await tester.tap(find.text(l.inicioEmpezar));
      await asentar(tester);
      await acabarRonda(tester, m);
      await tester.tap(find.text('Empezar la ronda 2'));
      await asentar(tester);
      m.reloj.avanzar(const Duration(minutes: 3));
      await m.motor.rendirse();
      await asentar(tester);
      expect(find.byType(ResultadoScreen), findsOneWidget);
      expect(find.text(l.resultadoPerdida), findsOneWidget);
      expect(find.text('1 de 3 rondas · 25 min'), findsOneWidget);
      expect(find.text('Ronda 2 de 3'), findsOneWidget);
    });

    testWidgets('Nori va vestida en el aro de Inicio, de la sesión y del '
        'descanso (D-53)', (tester) async {
      final m = await montar(tester);
      final nori = find.byType(MascotaAnimadaViva);
      bool vestida() => tester.widget<MascotaAnimadaViva>(nori).vestida;

      expect(nori, findsOneWidget);
      expect(vestida(), isTrue, reason: 'Inicio');

      await tester.tap(find.text(l.inicioEmpezar));
      await asentar(tester);
      expect(find.byType(SesionScreen), findsOneWidget);
      expect(vestida(), isTrue, reason: 'Sesión');

      await acabarRonda(tester, m);
      expect(find.byType(DescansoScreen), findsOneWidget);
      expect(vestida(), isTrue, reason: 'Descanso');

      await tester.tap(find.text(l.descansoTerminar));
      await asentar(tester);
    });

    testWidgets('Terminar aquí deja la tanda y vuelve a Inicio', (
      tester,
    ) async {
      final m = await montar(tester);
      await tester.tap(find.text(l.inicioEmpezar));
      await asentar(tester);
      await acabarRonda(tester, m);
      expect(find.byType(DescansoScreen), findsOneWidget);

      await tester.tap(find.text(l.descansoTerminar));
      await asentar(tester);
      expect(find.byType(DescansoScreen), findsNothing);
      expect(find.text(l.inicioEmpezar), findsOneWidget);
      expect(m.tanda.tanda.value, isNull);
      expect(m.avisosDescanso.cancelados, 1);
      expect(m.api.enviadas, hasLength(1));
    });

    testWidgets('rendirse en una ronda acaba la tanda: resultado, sin '
        'descanso', (tester) async {
      final m = await montar(tester);
      await tester.tap(find.text(l.inicioEmpezar));
      await asentar(tester);
      await m.motor.rendirse();
      await asentar(tester);
      expect(find.byType(DescansoScreen), findsNothing);
      expect(find.byType(ResultadoScreen), findsOneWidget);
      expect(m.tanda.tanda.value, isNull);
      expect(m.avisosDescanso.programados, isEmpty);
    });

    testWidgets('si se mató la app en el descanso, al volver sigue el '
        'descanso', (tester) async {
      final m = await montar(
        tester,
        prefs: {
          'enfoque_tanda': jsonEncode({
            'rondas': 3,
            'ronda': 1,
            'minutos': 50,
            'descanso': 10,
            'finDescansoUtc': DateTime.utc(
              2026,
              11,
              18,
              9,
              4,
            ).toIso8601String(),
            'claveRonda': 'ya-enviada',
          }),
        },
      );
      expect(find.byType(DescansoScreen), findsOneWidget);
      expect(find.text('Ronda 1 de 3 hecha'), findsOneWidget);
      expect(find.text('04:00'), findsOneWidget);

      await tester.tap(find.text('Empezar la ronda 2'));
      await asentar(tester);
      expect(find.byType(SesionScreen), findsOneWidget);
      expect(
        m.motor.sesion.value!.duracionObjetivo,
        const Duration(minutes: 50),
      );
      expect(find.text('Ronda 2 de 3'), findsOneWidget);
      await m.motor.rendirse();
      await asentar(tester);
    });
  });
}
