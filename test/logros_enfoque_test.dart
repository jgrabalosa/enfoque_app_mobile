import 'package:enfoque_app_mobile/l10n/app_localizations.dart';
import 'package:enfoque_app_mobile/l10n/logros_enfoque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

/// Los 21 logros propios de Norday Focus (backend V27): cada uno con nombre y
/// descripción en los tres idiomas, y el core los nombra una vez registrados.
void main() {
  Future<void> conContexto(
    WidgetTester tester,
    Locale locale,
    void Function(BuildContext) mirar,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: [
          ...AppLocalizations.localizationsDelegates,
          NordayCoreLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            mirar(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  test('los 21 códigos del backend, sin repetir', () {
    expect(codigosLogrosEnfoque, hasLength(21));
    expect(codigosLogrosEnfoque.toSet(), hasLength(21));
    expect(codigosLogrosEnfoque.every((c) => c.startsWith('ENFOQUE_')), isTrue);
    expect(
      codigosLogrosEnfoque,
      containsAll([
        'ENFOQUE_PRIMERA_SESION',
        'ENFOQUE_DIA',
        'ENFOQUE_CON_DESTINO',
        'ENFOQUE_DIAS_100',
        'ENFOQUE_RACHA_30',
        'ENFOQUE_HORAS_500',
        'ENFOQUE_SESION_120',
        'ENFOQUE_CUATRO',
        'ENFOQUE_SIN_RENDIRSE',
        'ENFOQUE_TOPE',
        'ENFOQUE_MANANA',
        'ENFOQUE_NOCHE',
      ]),
    );
  });

  for (final idioma in ['es', 'en', 'pt']) {
    testWidgets('en $idioma: todos con nombre y descripción, distintos', (
      tester,
    ) async {
      await conContexto(tester, Locale(idioma), (c) {
        final nombres = nombresLogrosEnfoque(c);
        final descripciones = descripcionesLogrosEnfoque(c);
        expect(nombres.keys.toSet(), codigosLogrosEnfoque.toSet());
        expect(descripciones.keys.toSet(), codigosLogrosEnfoque.toSet());
        expect(nombres.values.every((n) => n.trim().isNotEmpty), isTrue);
        expect(descripciones.values.every((d) => d.trim().isNotEmpty), isTrue);
        expect(nombres.values.toSet(), hasLength(21), reason: 'sin repetir');
      });
    });
  }

  testWidgets('registrados, el core los nombra en el idioma del usuario', (
    tester,
  ) async {
    registrarLogrosEnfoque();
    await conContexto(tester, const Locale('en'), (c) {
      expect(
        CatalogosCore.logro(c, 'ENFOQUE_SESION_120', 'Maratón'),
        'Marathon',
      );
      expect(
        CatalogosCore.logroDescripcion(c, 'ENFOQUE_DIA', ''),
        'Reach 50 minutes of focus in a day',
      );
      // Uno de Habits sigue sin nombre aquí: se cuenta «en Norday Habits».
      expect(CatalogosCore.logro(c, 'RACHA_3', ''), isEmpty);
    });
  });
}
