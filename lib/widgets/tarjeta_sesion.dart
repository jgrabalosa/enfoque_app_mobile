import 'package:flutter/material.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

import '../l10n/app_localizations.dart';
import '../l10n/formatos.dart';

/// La postal de una sesión que cuenta, para compartir (T-086). Se captura a
/// [ancho] × [alto] (1080 × 1350, 4:5): el fondo de la identidad equipada,
/// Nori vestido dentro del aro lleno (el mismo dibujo que la sesión), la
/// duración y la marca «Norday Focus».
///
/// Sin puntos ni XP (no se presume de cifras) y sin el nombre del hábito (es
/// privado): solo lo que cabe en una foto pública.
///
/// En una tanda, [minutos] es el total y [rondas] (más de una) añade «{n}
/// rondas» bajo la duración.
class TarjetaSesion extends StatelessWidget {
  const TarjetaSesion({
    super.key,
    required this.minutos,
    this.rondas,
    this.fase,
    this.estado,
  });

  static const double ancho = 1080;
  static const double alto = 1350;

  /// Los minutos de la sesión o, en una tanda, los de todas sus rondas.
  final int minutos;

  /// Las rondas de la tanda; `null` o 1, una sesión suelta.
  final int? rondas;

  /// La fase y el ánimo de Nori, del backend (si no se han podido cargar,
  /// los de por defecto).
  final String? fase;
  final String? estado;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;
    final varias = (rondas ?? 1) > 1;

    // La letra de la tarjeta no depende del tamaño de letra del móvil: la
    // postal sale igual en todos. Los roles del tema están pensados para un
    // móvil de ~360 de ancho; la tarjeta mide 1080, así que van ×3 (sin
    // `fontSize` a mano).
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: const Size(ancho, alto),
        textScaler: const TextScaler.linear(3),
      ),
      child: SizedBox(
        width: ancho,
        height: alto,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: FondoIdentidad()),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 96,
                vertical: 120,
              ),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // El aro lleno, con Nori dentro.
                  SizedBox.square(
                    dimension: 640,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const AnilloIdentidad(tamano: 640, pct: 1),
                        MascotaAnimadaViva(
                          fase: fase,
                          estado: estado,
                          tamano: 420,
                          vestida: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 72),
                  Text(
                    duracionLegible(l, minutos),
                    textAlign: TextAlign.center,
                    style: tema.displayMedium?.copyWith(color: t.text),
                  ),
                  if (varias) ...[
                    const SizedBox(height: 16),
                    Text(
                      l.inicioRondas(rondas!),
                      textAlign: TextAlign.center,
                      style: tema.titleLarge?.copyWith(color: t.textMuted),
                    ),
                  ],
                  const Spacer(flex: 3),
                  Text(
                    l.postalSesionMarca,
                    textAlign: TextAlign.center,
                    style: tema.headlineSmall?.copyWith(color: t.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
