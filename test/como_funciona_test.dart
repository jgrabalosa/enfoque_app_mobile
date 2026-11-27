import 'package:enfoque_app_mobile/l10n/app_localizations.dart';
import 'package:enfoque_app_mobile/screens/como_funciona_screen.dart';
import 'package:enfoque_app_mobile/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:norday_flutter_core/services/escribir_a_norday.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'montaje.dart';

/// «Cómo funciona» y «Escribir a Norday»: las dos entradas nuevas del menú.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppLocalizations l;

  setUpAll(() async {
    await initializeDateFormatting();
    l = await AppLocalizations.delegate.load(const Locale('es'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reiniciarEscribirANordayParaTest();
  });
  tearDown(reiniciarEscribirANordayParaTest);

  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<Montaje> abrirMenu(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final m = Montaje(tester);
    await tester.pumpWidget(m.app(const HomeShell()));
    await asentar(tester);
    await tester.tap(find.text(l.navMenu));
    await asentar(tester);
    return m;
  }

  /// Los `Uri` que se habrían lanzado; contesta [respuesta].
  List<Uri> falsearCorreo({bool respuesta = true}) {
    final lanzados = <Uri>[];
    infoAppCorreo = () async => (app: 'Norday Focus', version: '1.0.0');
    sistemaCorreo = () => 'Android 14';
    lanzarCorreo = (uri) async {
      lanzados.add(uri);
      return respuesta;
    };
    return lanzados;
  }

  testWidgets('el menú tiene las dos entradas, entre Perfil y Cerrar sesión', (
    tester,
  ) async {
    await abrirMenu(tester);
    final c = NordayCoreLocalizations.of(
      tester.element(find.byType(HomeShell)),
    )!;
    double y(String texto) => tester.getTopLeft(find.text(texto)).dy;
    expect(find.text(l.menuComoFunciona), findsOneWidget);
    expect(find.text(l.menuEscribirANorday), findsOneWidget);
    expect(y(c.perfilTitulo), lessThan(y(l.menuComoFunciona)));
    expect(y(l.menuComoFunciona), lessThan(y(l.menuEscribirANorday)));
    expect(y(l.menuEscribirANorday), lessThan(y(l.shellCerrarSesion)));
  });

  testWidgets('«Cómo funciona» enseña los cinco apartados y despliega uno', (
    tester,
  ) async {
    await abrirMenu(tester);
    await tester.tap(find.text(l.menuComoFunciona));
    await asentar(tester);
    expect(find.byType(ComoFuncionaScreen), findsOneWidget);

    for (final titulo in [
      l.comoFuncionaSesionTitulo,
      l.comoFuncionaDescansosTitulo,
      l.comoFuncionaPuntosTitulo,
      l.comoFuncionaNoriTitulo,
      l.comoFuncionaEscribenosTitulo,
    ]) {
      expect(find.text(titulo), findsOneWidget);
    }
    expect(find.text(l.comoFuncionaPuntosCuerpo), findsNothing);

    await tester.tap(find.text(l.comoFuncionaPuntosTitulo));
    await asentar(tester);
    expect(find.text(l.comoFuncionaPuntosCuerpo), findsOneWidget);
  });

  testWidgets('el botón de «Escríbenos» llama a escribirANorday', (
    tester,
  ) async {
    final lanzados = falsearCorreo();
    await abrirMenu(tester);
    await tester.tap(find.text(l.menuComoFunciona));
    await asentar(tester);
    await tester.tap(find.text(l.comoFuncionaEscribenosTitulo));
    await asentar(tester);
    await tester.tap(find.text(l.comoFuncionaEscribirBoton));
    await asentar(tester);

    expect(lanzados, hasLength(1));
    expect(lanzados.single.scheme, 'mailto');
    expect(lanzados.single.path, 'hola@norday.app');
    expect(lanzados.single.queryParameters['subject'], l.correoAsunto);
    expect(find.text(l.correoNoHayApp), findsNothing);
  });

  testWidgets('«Escribir a Norday» del menú abre el correo a '
      'hola@norday.app', (tester) async {
    final lanzados = falsearCorreo();
    await abrirMenu(tester);
    await tester.tap(find.text(l.menuEscribirANorday));
    await asentar(tester);

    expect(lanzados, hasLength(1));
    expect(lanzados.single.path, 'hola@norday.app');
    expect(lanzados.single.queryParameters['subject'], l.correoAsunto);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('sin app de correo, sale el SnackBar', (tester) async {
    final lanzados = falsearCorreo(respuesta: false);
    await abrirMenu(tester);
    await tester.tap(find.text(l.menuEscribirANorday));
    await asentar(tester);

    expect(lanzados, hasLength(1));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(l.correoNoHayApp), findsOneWidget);
  });
}
