import 'package:flutter/material.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

/// El tema de la barra inferior según la identidad equipada: la forma del
/// indicador y el color de lo activo. Copiado tal cual de
/// `identidad_ui.dart` de Norday Habits, que es UI de aspecto sin dominio:
/// las dos apps se ven iguales en la barra.
NavigationBarThemeData barraNavegacionIdentidad(
  IdentidadPaleta id,
  TokensContextuales t,
  TextStyle? estiloEtiqueta,
) {
  final ({ShapeBorder forma, Color color}) indicador = switch (id.forma) {
    // Profundidad — pastilla redondeada con el radio de la identidad.
    FormaIdentidad.glass => (
      forma: formaIdentidad(id, radio: id.radioSecundario),
      color: t.primary.withValues(alpha: 0.18),
    ),
    // Neotokyo+ — el mismo corte de esquina de las tarjetas, con filo.
    FormaIdentidad.chamfer => (
      forma: BordeChaflan(
        chaflan: id.chaflan,
        side: BorderSide(color: t.primary, width: 1.2),
      ),
      color: t.primary.withValues(alpha: 0.20),
    ),
    // Dulce — la pestaña elegida va a lápiz, con el sombreado a rayas dentro:
    // sin relleno liso, como en la maqueta.
    FormaIdentidad.pill => (
      forma: BordeLapiz(
        radio: 999,
        side: BorderSide(color: t.primaryTrazo, width: 1.3),
        rayas: t.primary,
      ),
      color: Colors.transparent,
    ),
  };

  return NavigationBarThemeData(
    backgroundColor: t.surface,
    indicatorColor: indicador.color,
    indicatorShape: indicador.forma,
    iconTheme: WidgetStateProperty.resolveWith(
      (estados) => IconThemeData(
        size: 24,
        color: estados.contains(WidgetState.selected)
            ? t.primaryTrazo
            : t.textMuted,
      ),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (estados) => (estiloEtiqueta ?? const TextStyle()).copyWith(
        fontWeight: estados.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500,
        // El primario va aquí como TEXTO pequeño, así que en las identidades
        // claras manda la variante que contrasta.
        color: estados.contains(WidgetState.selected)
            ? t.successText
            : t.textMuted,
      ),
    ),
  );
}
