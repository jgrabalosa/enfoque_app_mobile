import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

import '../l10n/app_localizations.dart';
import '../l10n/formatos.dart';
import '../services/controlador_enfoque.dart';
import '../services/mascota_enfoque.dart';

/// La sesión en curso: el aro con la cuenta atrás y Nori dentro, el destino,
/// el aviso fijo de que salir la pierde, y Terminar y Rendirse.
///
/// No navega por su cuenta: cuando la sesión acaba, `HomeShell` la sustituye
/// por el resultado.
class SesionScreen extends StatefulWidget {
  const SesionScreen({
    super.key,
    required this.controlador,
    this.cargarMascota = mascotaDelBackend,
  });

  final ControladorEnfoque controlador;
  final CargaMascota cargarMascota;

  @override
  State<SesionScreen> createState() => _SesionScreenState();
}

class _SesionScreenState extends State<SesionScreen> {
  ({String? fase, String? estado})? _mascota;
  bool _dialogoAbierto = false;

  MotorSesion get _motor => widget.controlador.motor;

  @override
  void initState() {
    super.initState();
    unawaited(_cargarMascota());
  }

  Future<void> _cargarMascota() async {
    final m = await widget.cargarMascota();
    if (mounted && m != null) setState(() => _mascota = m);
  }

  Future<bool> _confirmar({
    required String titulo,
    required String cuerpo,
    required String accion,
  }) async {
    if (_dialogoAbierto) return false;
    _dialogoAbierto = true;
    final l = AppLocalizations.of(context)!;
    final si = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(titulo),
        content: Text(cuerpo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(l.sesionSeguir),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(accion),
          ),
        ],
      ),
    );
    _dialogoAbierto = false;
    return si ?? false;
  }

  Future<void> _terminar() async {
    final l = AppLocalizations.of(context)!;
    final s = _motor.sesion.value;
    if (s == null) return;
    final hecho = s.duracionObjetivo - _motor.restante.value;
    final cuenta = hecho >= s.reglas.minimoParaContar;
    final si = await _confirmar(
      titulo: l.sesionTerminarTitulo,
      cuerpo: cuenta
          ? l.sesionTerminarCuenta(duracionLegible(l, hecho.inMinutes))
          : l.sesionTerminarCorta,
      accion: l.sesionTerminar,
    );
    if (si) await _motor.terminar();
  }

  Future<void> _rendirse() async {
    final l = AppLocalizations.of(context)!;
    final si = await _confirmar(
      titulo: l.sesionRendirseTitulo,
      cuerpo: l.sesionRendirseCuerpo,
      accion: l.sesionRendirse,
    );
    if (si) await _motor.rendirse();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = NordayCoreLocalizations.of(context)!;
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;

    return PopScope(
      // Atrás no saca de la sesión: llevaría al escritorio y la perdería.
      // Pregunta si rendirse.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _rendirse();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: FondoIdentidad()),
            SafeArea(
              child: ValueListenableBuilder<SesionConcentracion?>(
                valueListenable: _motor.sesion,
                builder: (context, sesion, _) {
                  if (sesion == null) return const SizedBox.shrink();
                  final destino = destinoDeDatos(sesion.datosApp);
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        const Spacer(),
                        ValueListenableBuilder<Duration>(
                          valueListenable: _motor.restante,
                          builder: (context, restante, _) => AroCuentaAtras(
                            restante: restante,
                            total: sesion.duracionObjetivo,
                            tamano: 260,
                            centro: ExcludeSemantics(
                              child: MascotaAnimadaViva(
                                fase: _mascota?.fase,
                                estado: _mascota?.estado,
                                tamano: 96,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          destino == null
                              ? l.destinoSinHabito
                              : textoDestino(l, destino),
                          textAlign: TextAlign.center,
                          style: tema.titleMedium?.copyWith(color: t.text),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.triangleAlert,
                              size: 18,
                              color: t.streakText,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(
                                c.sesionAvisoSalir,
                                style: tema.bodyMedium?.copyWith(
                                  color: t.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _terminar,
                            icon: const Icon(LucideIcons.square),
                            label: Text(l.sesionTerminar),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _rendirse,
                          child: Text(l.sesionRendirse),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
