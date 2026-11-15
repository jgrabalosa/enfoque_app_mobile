import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/formatos.dart';
import '../models/enfoque.dart';
import '../services/abrir_habits.dart';
import '../services/servicios_enfoque.dart';
import 'inicio_logica.dart';

/// Inicio: lo de hoy (minutos, sesiones y racha), la duración, el destino y
/// Empezar.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key, required this.usuarioId, this.hoy});

  final int usuarioId;

  /// El día de hoy. Sin él, el del móvil (ver la decisión en CLAUDE.md:
  /// «Hoy es el día del móvil»).
  final DateTime Function()? hoy;

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  ServiciosEnfoque? _servicios;
  ServiciosEnfoque get _s => _servicios!;

  int _minutos = Duraciones.porDefecto;
  DestinoDisponible? _elegido;

  List<DestinoDisponible> _destinos = const [];
  bool _cargandoDestinos = true;
  bool _errorDestinos = false;

  ResumenEnfoque? _resumenHoy;
  bool _errorResumen = false;

  bool _empezando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_servicios != null) return;
    _servicios = AmbitoEnfoque.de(context);
    _s.controlador.refrescos.addListener(_cargar);
    _s.destinoPedido.addListener(_aplicarPedido);
    _cargar();
  }

  @override
  void dispose() {
    _s.controlador.refrescos.removeListener(_cargar);
    _s.destinoPedido.removeListener(_aplicarPedido);
    super.dispose();
  }

  DateTime get _hoy {
    final h = (widget.hoy ?? DateTime.now)();
    return DateTime(h.year, h.month, h.day);
  }

  Future<void> _cargar() async {
    unawaited(_cargarResumen());
    await _cargarDestinos();
  }

  Future<void> _cargarDestinos() async {
    setState(() {
      _cargandoDestinos = true;
      _errorDestinos = false;
    });
    try {
      final destinos = await _s.api.destinos();
      if (!mounted) return;
      setState(() {
        _destinos = destinos;
        _elegido = elegidoTrasRecargar(_elegido, destinos);
        _cargandoDestinos = false;
      });
      _aplicarPedido();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoDestinos = false;
        _errorDestinos = true;
      });
    }
  }

  Future<void> _cargarResumen() async {
    try {
      final r = await _s.api.resumen(_hoy, _hoy);
      if (!mounted) return;
      setState(() {
        _resumenHoy = r;
        _errorResumen = false;
      });
    } catch (_) {
      if (mounted) setState(() => _errorResumen = true);
    }
  }

  /// Un enlace ha pedido un destino. Se aplica en cuanto hay lista; si el
  /// destino no está en ella, se avisa y se queda «Sin hábito».
  void _aplicarPedido() {
    final pedido = _s.destinoPedido.value;
    if (pedido == null || _cargandoDestinos || !mounted) return;
    if (_errorDestinos) return; // Se aplicará al recargar.
    _s.soltarDestinoPedido();
    final destino = destinoPedidoEn(_destinos, pedido);
    setState(() => _elegido = destino);
    if (destino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.destinoNoDisponible),
        ),
      );
    }
  }

  Future<void> _abrirHabits() async {
    final abierto = await abrirHabits(flavor: _s.flavor, lanzador: _s.lanzador);
    if (abierto == AperturaHabits.nada && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.abrirHabitsError)),
      );
    }
  }

  /// La primera vez que se pulsa Empezar, el permiso de notificaciones (para
  /// los avisos de gracia y de fin). Una sola vez. No se espera ni al diálogo
  /// ni al registro del aviso en el backend: si se deniega, las reglas no
  /// cambian, y la sesión no puede quedarse esperando a la red.
  Future<void> _pedirPermisoSiEsLaPrimera() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_s.clavePermisoPedido) ?? false) return;
      await prefs.setBool(_s.clavePermisoPedido, true);
      if (widget.usuarioId > 0) {
        unawaited(
          _s
              .pedirPermisoAvisos(widget.usuarioId)
              .then<void>((_) {}, onError: (Object _) {}),
        );
      }
    } catch (_) {
      // Sin permiso la sesión es la misma.
    }
  }

  Future<void> _empezar() async {
    if (_empezando) return;
    setState(() => _empezando = true);
    try {
      await _pedirPermisoSiEsLaPrimera();
      await _s.controlador.empezar(
        duracion: Duration(minutes: _minutos),
        destino: _elegido,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.inicioNoSePudoEmpezar),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _empezando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = tokens(context);
    final titulo = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(color: t.text);

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _CifrasHoy(resumen: _resumenHoy, error: _errorResumen, hoy: _hoy),
          const SizedBox(height: AppSpacing.lg),
          Text(l.inicioDuracion, style: titulo),
          const SizedBox(height: AppSpacing.sm),
          SelectorDuracion(
            minutos: _minutos,
            alCambiar: (m) => setState(() => _minutos = m),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l.inicioDestino, style: titulo),
          const SizedBox(height: AppSpacing.sm),
          ..._bloqueDestino(l, t),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: _empezando ? null : _empezar,
            icon: const Icon(LucideIcons.play),
            label: Text(l.inicioEmpezar),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  List<Widget> _bloqueDestino(AppLocalizations l, TokensContextuales t) {
    final cuerpo = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: t.textMuted);
    final sinHabito = OpcionDestino(
      titulo: l.destinoSinHabito,
      subtitulo: l.destinoSinHabitoAyuda,
      elegida: _elegido == null,
      alPulsar: () => setState(() => _elegido = null),
    );
    if (_cargandoDestinos) {
      return [
        sinHabito,
        const SizedBox(height: AppSpacing.sm),
        // 72 y no menos: la tarjeta lleva 14 de relleno y dos barras (66).
        const SkeletonPulso(child: SkeletonCard(height: 72)),
      ];
    }
    if (_errorDestinos) {
      return [
        sinHabito,
        const SizedBox(height: AppSpacing.sm),
        Text(l.destinosError, style: cuerpo),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _cargarDestinos,
            child: Text(NordayCoreLocalizations.of(context)!.reintentar),
          ),
        ),
      ];
    }
    if (_destinos.isEmpty) {
      return [
        sinHabito,
        const SizedBox(height: AppSpacing.sm),
        Text(l.destinoSinHabitosMinutos, style: cuerpo),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _abrirHabits,
            icon: const Icon(LucideIcons.externalLink, size: 18),
            label: Text(l.destinoCrearEnHabits),
          ),
        ),
      ];
    }
    return [
      sinHabito,
      for (final d in _destinos) ...[
        const SizedBox(height: AppSpacing.sm),
        OpcionDestino(
          titulo: textoDestino(l, d),
          elegida: _elegido?.esElMismo(d) ?? false,
          alPulsar: () => setState(() => _elegido = d),
        ),
      ],
    ];
  }
}

/// Minutos hoy, sesiones hoy y racha. Con error, una raya en vez de la
/// cifra: un cero diría algo que no se sabe.
class _CifrasHoy extends StatelessWidget {
  const _CifrasHoy({
    required this.resumen,
    required this.error,
    required this.hoy,
  });

  final ResumenEnfoque? resumen;
  final bool error;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final dia = resumen?.delDia(hoy);
    String cifra(String Function() valor) =>
        resumen == null || error ? '—' : valor();
    return Row(
      children: [
        Expanded(
          child: _Cifra(
            etiqueta: l.inicioMinutosHoy,
            valor: cifra(() => '${dia!.minutos}'),
            icono: LucideIcons.timer,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _Cifra(
            etiqueta: l.inicioSesionesHoy,
            valor: cifra(() => '${dia!.sesiones}'),
            icono: LucideIcons.circleCheck,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _Cifra(
            etiqueta: l.inicioRacha,
            valor: cifra(() => l.inicioRachaDias(resumen!.rachaActual)),
            icono: LucideIcons.flame,
          ),
        ),
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.etiqueta,
    required this.valor,
    required this.icono,
  });

  final String etiqueta;
  final String valor;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: AppLocalizations.of(context)!.inicioCifraEtiqueta(etiqueta, valor),
      excludeSemantics: true,
      child: SuperficieIdentidad(
        relleno: const EdgeInsets.all(AppSpacing.ms),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 18, color: t.points),
            const SizedBox(height: AppSpacing.xs),
            Text(
              valor,
              style: tema.titleLarge?.copyWith(color: t.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              etiqueta,
              style: tema.labelMedium?.copyWith(color: t.textMuted),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Los chips de duración rápida y el selector de 10 a 120 de 5 en 5.
class SelectorDuracion extends StatelessWidget {
  const SelectorDuracion({
    super.key,
    required this.minutos,
    required this.alCambiar,
  });

  final int minutos;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = tokens(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final m in Duraciones.rapidas)
              _ChipDuracion(
                texto: l.duracionMinutos(m),
                elegido: m == minutos,
                alPulsar: () => alCambiar(m),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          container: true,
          label: l.duracionEtiqueta(minutos),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: minutos > Duraciones.minima
                    ? () => alCambiar(Duraciones.bajar(minutos))
                    : null,
                icon: const Icon(LucideIcons.minus),
                tooltip: l.duracionMenos,
                color: t.text,
              ),
              ExcludeSemantics(
                child: SizedBox(
                  width: 120,
                  child: Text(
                    l.duracionMinutos(minutos),
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: t.text),
                  ),
                ),
              ),
              IconButton(
                onPressed: minutos < Duraciones.maxima
                    ? () => alCambiar(Duraciones.subir(minutos))
                    : null,
                icon: const Icon(LucideIcons.plus),
                tooltip: l.duracionMas,
                color: t.text,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChipDuracion extends StatelessWidget {
  const _ChipDuracion({
    required this.texto,
    required this.elegido,
    required this.alPulsar,
  });

  final String texto;
  final bool elegido;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final t = tokens(context);
    return Semantics(
      button: true,
      selected: elegido,
      inMutuallyExclusiveGroup: true,
      child: SuperficieIdentidad(
        onTap: alPulsar,
        relleno: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        filo: elegido ? BorderSide(color: t.primaryTrazo, width: 2) : null,
        filoNeon: elegido ? FiloNeon.encendido : FiloNeon.fijo,
        child: Text(
          texto,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: elegido ? t.successText : t.text,
          ),
        ),
      ),
    );
  }
}

/// Una opción de destino: «Sin hábito» o un hábito de minutos con su
/// progreso.
class OpcionDestino extends StatelessWidget {
  const OpcionDestino({
    super.key,
    required this.titulo,
    required this.elegida,
    required this.alPulsar,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;
  final bool elegida;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: elegida,
      inMutuallyExclusiveGroup: true,
      child: SuperficieIdentidad(
        onTap: alPulsar,
        relleno: const EdgeInsets.all(AppSpacing.ms),
        filo: elegida ? BorderSide(color: t.primaryTrazo, width: 2) : null,
        filoNeon: elegida ? FiloNeon.encendido : FiloNeon.fijo,
        child: Row(
          children: [
            Icon(
              elegida ? LucideIcons.circleCheck : LucideIcons.circle,
              size: 20,
              color: elegida ? t.primaryTrazo : t.textMuted,
            ),
            const SizedBox(width: AppSpacing.ms),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: tema.bodyLarge?.copyWith(color: t.text)),
                  if (subtitulo != null)
                    Text(
                      subtitulo!,
                      style: tema.bodySmall?.copyWith(color: t.textMuted),
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
