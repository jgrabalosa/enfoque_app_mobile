import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

import '../l10n/app_localizations.dart';
import '../services/controlador_enfoque.dart';
import '../services/mascota_enfoque.dart';
import '../services/tanda.dart';
import 'resultado_screen.dart';

/// El descanso entre dos rondas de una tanda (diseño de Focus, 17-nov-2026):
/// la ronda hecha y lo que pagó, el aro con el descanso que queda y Nori
/// durmiendo, y dos botones: empezar la ronda siguiente (también antes de
/// que acabe el descanso) o terminar aquí.
///
/// Al acabar el descanso no empieza sola la ronda: avisa y espera. Durante
/// el descanso se puede salir de la app.
class DescansoScreen extends StatefulWidget {
  const DescansoScreen({
    super.key,
    required this.controlador,
    required this.tanda,
    this.cargarMascota = mascotaDelBackend,
  });

  final ControladorEnfoque controlador;
  final ControladorTanda tanda;
  final CargaMascota cargarMascota;

  @override
  State<DescansoScreen> createState() => _DescansoScreenState();
}

class _DescansoScreenState extends State<DescansoScreen> {
  Timer? _tic;
  ({String? fase, String? estado})? _mascota;
  final Set<String> _celebrados = {};
  bool _saliendo = false;

  /// Lo último que se pintó: al salir se suelta, y la pantalla sigue
  /// enseñándolo mientras se va.
  Tanda? _ultima;
  ResultadoSesion? _resultado;

  @override
  void initState() {
    super.initState();
    _ultima = widget.tanda.tanda.value;
    _resultado = _resultadoDeLaRonda();
    widget.controlador.resultado.addListener(_alCambiarResultado);
    _tic = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    unawaited(_cargarMascota());
    WidgetsBinding.instance.addPostFrameCallback((_) => _celebrar());
  }

  @override
  void dispose() {
    _tic?.cancel();
    widget.controlador.resultado.removeListener(_alCambiarResultado);
    super.dispose();
  }

  Future<void> _cargarMascota() async {
    final m = await widget.cargarMascota();
    if (mounted && m != null) setState(() => _mascota = m);
  }

  /// El resultado de la ronda que dio paso al descanso, si aún está (tras
  /// matar la app ya no: entonces solo se ve el descanso).
  ResultadoSesion? _resultadoDeLaRonda() {
    final r = widget.controlador.resultado.value;
    return r != null && r.clave == _ultima?.claveRonda ? r : null;
  }

  void _alCambiarResultado() {
    final r = _resultadoDeLaRonda();
    if (r == null || !mounted) return;
    setState(() => _resultado = r);
    _celebrar();
  }

  void _celebrar() {
    if (mounted) celebrarResultado(context, _resultado, _celebrados);
  }

  // En los dos botones, la tanda cambia ANTES de soltar el resultado: al
  // soltarlo, HomeShell mira si hay un descanso pendiente que enseñar, y
  // tiene que ver ya la tanda nueva (o ninguna).

  Future<void> _siguiente() async {
    if (_saliendo) return;
    _saliendo = true;
    final siguiente = widget.tanda.siguienteRonda();
    widget.controlador.soltarResultado();
    // La sesión nueva la pone encima HomeShell; esta se va antes.
    Navigator.of(context).pop();
    await siguiente;
  }

  Future<void> _terminar() async {
    if (_saliendo) return;
    _saliendo = true;
    final fin = widget.tanda.terminar();
    widget.controlador.soltarResultado();
    if (mounted) Navigator.of(context).pop();
    await fin;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;
    final tanda = _ultima;
    if (tanda == null) return const Scaffold(body: SizedBox.shrink());
    final restante = widget.tanda.restanteDescanso() ?? Duration.zero;
    final acabado = restante == Duration.zero;

    return PopScope(
      // Atrás es «Terminar aquí»: lo hecho ya cuenta.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_terminar());
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
                  Text(
                    l.descansoRondaHecha(tanda.ronda, tanda.rondas),
                    textAlign: TextAlign.center,
                    style: tema.titleSmall?.copyWith(color: t.textMuted),
                  ),
                  Semantics(
                    header: true,
                    child: Text(
                      l.descansoTitulo,
                      textAlign: TextAlign.center,
                      style: tema.headlineMedium?.copyWith(color: t.text),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: AroCuentaAtras(
                      restante: restante,
                      total: Duration(minutes: tanda.descanso),
                      tamano: 220,
                      centro: ExcludeSemantics(
                        child: MascotaAnimadaViva(
                          fase: _mascota?.fase,
                          // Nori descansa contigo.
                          estado: acabado ? _mascota?.estado : 'dormida',
                          tamano: 80,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    acabado ? l.descansoListo : l.descansoCuerpo,
                    textAlign: TextAlign.center,
                    style: tema.bodyLarge?.copyWith(color: t.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_resultado case final r?) LineasResultado(resultado: r),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: _siguiente,
                    icon: const Icon(LucideIcons.play),
                    label: Text(l.descansoEmpezarRonda(tanda.ronda + 1)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _terminar,
                    child: Text(l.descansoTerminar),
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
