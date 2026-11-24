import 'package:enfoque_app_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La ayuda de la XP de Nori dice cuánto da cada comida (15) y el tope
/// diario de comidas (3), igual que Norday Habits.
void main() {
  for (final idioma in ['es', 'en', 'pt']) {
    test('mascotaAyudaXp, en $idioma, nombra el 15 y el 3', () async {
      final l = await AppLocalizations.delegate.load(Locale(idioma));
      expect(l.mascotaAyudaXp, contains('(15 '));
      expect(l.mascotaAyudaXp, contains(' 3 '));
    });
  }
}
