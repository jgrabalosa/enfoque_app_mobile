import 'dart:convert';

import 'package:enfoque_app_mobile/l10n/app_localizations.dart';
import 'package:enfoque_app_mobile/screens/home_shell.dart';
import 'package:enfoque_app_mobile/screens/resultado_screen.dart';
import 'package:enfoque_app_mobile/screens/sesion_screen.dart';
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

  testWidgets('Empezar abre la sesión; al acabar, el resultado; Volver, a '
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

    await tester.tap(find.text(l.resultadoVolver));
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
}
