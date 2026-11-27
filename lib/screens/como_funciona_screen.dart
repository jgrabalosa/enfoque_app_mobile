import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:norday_flutter_core/services/escribir_a_norday.dart';

import '../l10n/app_localizations.dart';

/// La dirección a la que escribe «Escribir a Norday» (la misma que Habits).
const direccionNorday = 'hola@norday.app';

/// Abre el correo a Norday con el asunto de la app. Si no hay app de correo,
/// avisa con un `SnackBar`. Lo usan el menú y esta pantalla.
Future<void> escribirANordayDesdeApp(BuildContext context) async {
  final l = AppLocalizations.of(context)!;
  final mensajero = ScaffoldMessenger.of(context);
  final abierto = await escribirANorday(
    direccion: direccionNorday,
    asunto: l.correoAsunto,
  );
  if (!abierto) {
    mensajero.showSnackBar(SnackBar(content: Text(l.correoNoHayApp)));
  }
}

/// «Cómo funciona»: Focus se explica sola, en apartados que se despliegan.
class ComoFuncionaScreen extends StatelessWidget {
  const ComoFuncionaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;

    final apartados = <({String titulo, String cuerpo})>[
      (titulo: l.comoFuncionaSesionTitulo, cuerpo: l.comoFuncionaSesionCuerpo),
      (
        titulo: l.comoFuncionaDescansosTitulo,
        cuerpo: l.comoFuncionaDescansosCuerpo,
      ),
      (titulo: l.comoFuncionaPuntosTitulo, cuerpo: l.comoFuncionaPuntosCuerpo),
      (titulo: l.comoFuncionaNoriTitulo, cuerpo: l.comoFuncionaNoriCuerpo),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l.comoFuncionaTitulo),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: FondoIdentidad()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                for (final a in apartados)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SuperficieIdentidad(
                      child: _Apartado(
                        titulo: a.titulo,
                        hijos: [
                          Text(
                            a.cuerpo,
                            style: tema.bodyMedium?.copyWith(
                              color: t.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SuperficieIdentidad(
                  child: _Apartado(
                    titulo: l.comoFuncionaEscribenosTitulo,
                    hijos: [
                      Text(
                        l.comoFuncionaEscribenosCuerpo,
                        style: tema.bodyMedium?.copyWith(color: t.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: () => escribirANordayDesdeApp(context),
                          icon: const Icon(LucideIcons.mail, size: 18),
                          label: Text(l.comoFuncionaEscribirBoton),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un apartado desplegable: el título siempre a la vista, el resto al tocar.
class _Apartado extends StatelessWidget {
  const _Apartado({required this.titulo, required this.hijos});

  final String titulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(titulo, style: tema.titleMedium?.copyWith(color: t.text)),
        iconColor: t.points,
        collapsedIconColor: t.points,
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: hijos,
      ),
    );
  }
}
