import 'package:enfoque_app_mobile/l10n/app_localizations.dart';
import 'package:enfoque_app_mobile/l10n/textos_enfoque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

/// Con `registrarTextosEnfoque()`, las pantallas del core dicen «Norday
/// Focus» y los textos propios; sin él, el neutro del core.
void main() {
  tearDown(TextosApp.reiniciar);

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

  for (final idioma in ['es', 'en', 'pt']) {
    testWidgets('registrados, en $idioma: los de Norday Focus', (tester) async {
      registrarTextosEnfoque();
      final l = await AppLocalizations.delegate.load(Locale(idioma));
      await conContexto(tester, Locale(idioma), (c) {
        expect(TextosApp.nombreDe(c), 'Norday Focus');
        expect(TextosApp.lemaLoginDe(c), l.loginLema);
        expect(
          TextosApp.actualizacionObligatoriaDe(c),
          contains('Norday Focus'),
        );
        expect(TextosApp.eliminarCuentaDe(c), l.eliminarCuentaCuerpo);
      });
    });
  }

  testWidgets('sin registrar: el neutro del core', (tester) async {
    await conContexto(tester, const Locale('es'), (c) {
      expect(TextosApp.nombreDe(c), 'Norday');
    });
  });
}
