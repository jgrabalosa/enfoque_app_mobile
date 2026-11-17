import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

import '../l10n/app_localizations.dart';
import '../l10n/formatos.dart';
import '../models/enfoque.dart';
import '../services/controlador_enfoque.dart';
import '../services/servicios_enfoque.dart';

/// Los logros que esta app sabe nombrar (los genéricos del core y los propios
/// de Focus, que registra `registrarLogrosEnfoque`) y cuántos no. Norday Focus
/// no registra los logros de hábitos y el backend tampoco se los manda en el
/// catálogo (`X-Norday-App: enfoque`), así que celebrarlos aquí enseñaría el
/// código crudo. Esos se cuentan y se dice que están en Norday Habits.
({List<String> conocidos, int otros}) separarLogros(
  BuildContext context,
  List<String> codigos,
) {
  final conocidos = <String>[];
  var otros = 0;
  for (final c in codigos) {
    if (CatalogosCore.logro(context, c, '').isNotEmpty) {
      conocidos.add(c);
    } else {
      otros++;
    }
  }
  return (conocidos: conocidos, otros: otros);
}

/// Celebra los logros de [r] una sola vez ([celebrados] apunta las claves ya
/// celebradas), cuando ya está enviada. Los de la sesión (Focus y la fase de
/// Nori) y los del hábito, sin repetir: un logro de fase lo puede dar
/// cualquiera de los dos.
void celebrarResultado(
  BuildContext context,
  ResultadoSesion? r,
  Set<String> celebrados,
) {
  if (r == null || r.envio != EnvioResultado.enviada) return;
  if (!celebrados.add(r.clave)) return;
  final logros = {
    ...?r.respuesta?.premio.logros,
    ...?r.respuesta?.aporte.logros,
  }.toList();
  final conocidos = separarLogros(context, logros).conocidos;
  if (conocidos.isNotEmpty) {
    unawaited(AmbitoEnfoque.de(context).celebrar(conocidos));
  }
}

/// El resultado de la última sesión: los minutos, lo que pagó la sesión (el
/// premio, tenga hábito o no), lo que pasó con los minutos en su hábito y el
/// estado del envío.
class ResultadoScreen extends StatefulWidget {
  const ResultadoScreen({super.key, required this.controlador});

  final ControladorEnfoque controlador;

  @override
  State<ResultadoScreen> createState() => _ResultadoScreenState();
}

class _ResultadoScreenState extends State<ResultadoScreen> {
  /// Lo último que se pintó: al soltar el resultado al salir, la pantalla
  /// sigue enseñándolo mientras se va.
  ResultadoSesion? _ultimo;
  final Set<String> _celebrados = {};

  @override
  void initState() {
    super.initState();
    widget.controlador.resultado.addListener(_alCambiar);
    _ultimo = widget.controlador.resultado.value;
    WidgetsBinding.instance.addPostFrameCallback((_) => _celebrar());
  }

  @override
  void dispose() {
    widget.controlador.resultado.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    final r = widget.controlador.resultado.value;
    if (r == null || !mounted) return;
    setState(() => _ultimo = r);
    _celebrar();
  }

  void _celebrar() {
    if (!mounted) return;
    celebrarResultado(context, _ultimo, _celebrados);
  }

  void _salir() {
    widget.controlador.soltarResultado();
    Navigator.of(context).maybePop();
  }

  String _titulo(AppLocalizations l, EstadoSesion e) => switch (e) {
    EstadoSesion.completada => l.resultadoCompletada,
    EstadoSesion.terminada => l.resultadoTerminada,
    EstadoSesion.perdida => l.resultadoPerdida,
    _ => l.resultadoDescartada,
  };

  String? _explicacion(AppLocalizations l, SesionConcentracion s) =>
      switch (s.estado) {
        EstadoSesion.descartada => l.resultadoDescartadaCuerpo,
        EstadoSesion.perdida => switch (s.motivoPerdida) {
          MotivoPerdida.salida => l.resultadoPerdidaSalida,
          MotivoPerdida.reinicio => l.resultadoPerdidaReinicio,
          _ => l.resultadoPerdidaRendicion,
        },
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final r = _ultimo;
    final l = AppLocalizations.of(context)!;
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;
    if (r == null) return const Scaffold(body: SizedBox.shrink());
    final s = r.sesion;
    final explicacion = _explicacion(l, s);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.controlador.soltarResultado();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: FondoIdentidad()),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  if (rondaDeDatos(s.datosApp) case final ronda?)
                    Text(
                      l.sesionRonda(ronda.n, ronda.de),
                      textAlign: TextAlign.center,
                      style: tema.titleSmall?.copyWith(color: t.textMuted),
                    ),
                  Semantics(
                    header: true,
                    child: Text(
                      _titulo(l, s.estado),
                      textAlign: TextAlign.center,
                      style: tema.headlineMedium?.copyWith(color: t.text),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (s.estado.cuenta)
                    Text(
                      duracionLegible(l, s.minutos),
                      textAlign: TextAlign.center,
                      style: tema.displaySmall?.copyWith(color: t.successText),
                    ),
                  if (explicacion != null)
                    Text(
                      explicacion,
                      textAlign: TextAlign.center,
                      style: tema.bodyLarge?.copyWith(color: t.textMuted),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  LineasResultado(resultado: r),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton(
                    onPressed: _salir,
                    child: Text(l.resultadoVolver),
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

/// Lo que pasó con el envío de [resultado]: «Enviando…», pendiente, no
/// aceptada o, enviada, lo que pagó la sesión y lo que pasó en su hábito. Lo
/// usan el resultado y el descanso entre rondas.
class LineasResultado extends StatelessWidget {
  const LineasResultado({super.key, required this.resultado});

  final ResultadoSesion resultado;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: _envio(context, AppLocalizations.of(context)!, resultado),
  );

  List<Widget> _envio(
    BuildContext context,
    AppLocalizations l,
    ResultadoSesion r,
  ) {
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;
    Widget linea(IconData icono, String texto, {Color? color}) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: color ?? t.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(texto, style: tema.bodyLarge?.copyWith(color: t.text)),
          ),
        ],
      ),
    );

    switch (r.envio) {
      case EnvioResultado.noSeEnvia:
        return const [];
      case EnvioResultado.enviando:
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l.resultadoEnviando,
                style: tema.bodyMedium?.copyWith(color: t.textMuted),
              ),
            ],
          ),
        ];
      case EnvioResultado.pendiente:
        return [linea(LucideIcons.cloudOff, l.resultadoPendiente)];
      case EnvioResultado.noAceptada:
        return [
          linea(
            LucideIcons.circleX,
            l.resultadoNoAceptada,
            color: t.streakText,
          ),
          if (r.mensaje != null) linea(LucideIcons.info, r.mensaje!),
        ];
      case EnvioResultado.enviada:
        return [
          ..._premio(context, l, r, linea),
          ..._aporte(context, l, r, linea),
        ];
    }
  }

  /// Lo que pagó la sesión por sí misma, tenga hábito o no. Una perdida no
  /// paga nada y no dice nada (la explicación de arriba ya lo cuenta).
  List<Widget> _premio(
    BuildContext context,
    AppLocalizations l,
    ResultadoSesion r,
    Widget Function(IconData, String, {Color? color}) linea,
  ) {
    final t = tokens(context);
    final premio = r.respuesta?.premio ?? Premio.vacio;
    if (!r.sesion.estado.cuenta) return const [];
    if (premio.monedas == 0 && premio.xp == 0) {
      return [
        if (premio.topeAlcanzado) linea(LucideIcons.info, l.resultadoTopeYa),
      ];
    }
    return [
      linea(
        LucideIcons.coins,
        premio.xp > 0
            ? l.resultadoPremio(premio.monedas, premio.xp)
            : l.resultadoMonedas(premio.monedas),
        color: t.pointsText,
      ),
      if (premio.topeAlcanzado) linea(LucideIcons.info, l.resultadoTopeAhora),
    ];
  }

  List<Widget> _aporte(
    BuildContext context,
    AppLocalizations l,
    ResultadoSesion r,
    Widget Function(IconData, String, {Color? color}) linea,
  ) {
    final t = tokens(context);
    final destino = r.destino;
    final aporte = r.respuesta?.aporte ?? Aporte.vacio;
    // Sin destino o perdida, no hay nada que contar del hábito: una perdida
    // con destino vuelve siempre RECHAZADO (`enfoque.aporte.sesion.perdida`)
    // y la explicación de arriba ya lo dice.
    if (destino == null || !r.sesion.estado.cuenta) return const [];
    final nombre = nombreDestino(l, destino);
    final logros = separarLogros(context, aporte.logros);
    return switch (aporte.estado) {
      EstadoAporte.aceptado => [
        linea(
          LucideIcons.target,
          textoAporte(l, aporte, nombre),
          color: t.successText,
        ),
        if (aporte.monedas > 0)
          linea(
            LucideIcons.coins,
            l.resultadoMonedas(aporte.monedas),
            color: t.pointsText,
          ),
        if (aporte.diaHecho == true)
          linea(
            LucideIcons.circleCheck,
            l.resultadoDiaHecho,
            color: t.successText,
          ),
        if (logros.otros > 0)
          linea(
            LucideIcons.medal,
            l.resultadoLogrosEnHabits(logros.otros),
            color: t.pointsText,
          ),
      ],
      EstadoAporte.repetido => [
        linea(LucideIcons.circleCheck, l.resultadoAporteRepetido(nombre)),
      ],
      EstadoAporte.rechazado => [
        linea(
          LucideIcons.circleX,
          l.resultadoAporteRechazado(nombre),
          color: t.streakText,
        ),
        linea(
          LucideIcons.info,
          aporte.motivoTexto ?? l.resultadoMotivoDesconocido,
        ),
      ],
      // Pendiente (el backend no llegó a llevarla), sin destino o un estado
      // que esta versión no conoce: no se promete nada.
      _ => const [],
    };
  }
}
