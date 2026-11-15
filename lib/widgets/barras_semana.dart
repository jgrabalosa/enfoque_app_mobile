import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

import '../l10n/app_localizations.dart';
import '../l10n/formatos.dart';

/// Las barras de minutos de los siete días de la semana. Encima de cada una,
/// su duración («25 min», «1 h 30 min»), encogida si no cabe en la columna;
/// cada barra se oye entera («lunes: 25 min»). La altura es relativa al día
/// con más minutos. Los días que aún no han llegado van apagados.
class BarrasSemana extends StatelessWidget {
  const BarrasSemana({
    super.key,
    required this.dias,
    required this.hoy,
    this.alto = 120,
  });

  /// Los siete días, de lunes a domingo, con sus minutos.
  final List<({DateTime dia, int minutos})> dias;
  final DateTime hoy;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final maximo = dias.fold<int>(0, (m, d) => math.max(m, d.minutos));
    final dHoy = DateTime(hoy.year, hoy.month, hoy.day);

    return SizedBox(
      height: alto + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in dias)
            Expanded(
              child: Semantics(
                container: true,
                label: l.estBarraEtiqueta(
                  DateFormat.EEEE(locale).format(d.dia),
                  duracionLegible(l, d.minutos),
                ),
                excludeSemantics: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        d.minutos > 0 ? duracionLegible(l, d.minutos) : '',
                        maxLines: 1,
                        style: tema.labelSmall?.copyWith(color: t.textMuted),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: 18,
                      height: maximo == 0
                          ? 2
                          : math.max(2, alto * d.minutos / maximo),
                      decoration: BoxDecoration(
                        color: d.dia.isAfter(dHoy)
                            ? t.inactivo
                            : (d.minutos > 0 ? t.primary : t.aroVacio),
                        borderRadius: BorderRadius.circular(AppSpacing.xs),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      DateFormat.E(locale).format(d.dia),
                      style: tema.labelSmall?.copyWith(
                        color: d.dia == dHoy ? t.text : t.textMuted,
                        fontWeight: d.dia == dHoy ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
