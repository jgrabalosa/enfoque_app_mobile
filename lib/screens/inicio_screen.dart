import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/formatos.dart';
import '../models/enfoque.dart';
import '../services/abrir_habits.dart';
import '../services/mascota_enfoque.dart';
import '../services/servicios_enfoque.dart';
import 'inicio_logica.dart';

/// Inicio, de un solo gesto (diseño de Focus, 17-nov-2026): el aro con Nori
/// y los minutos, la técnica (Pomodoro, Profundo o Libre) con sus rondas,
/// Empezar y, debajo, una línea con el destino que abre la lista.
///
/// La técnica, las rondas y los minutos de Libre se recuerdan
/// ([claveTecnica], [claveRondas], [claveMinutosLibre]): normalmente basta
/// con pulsar Empezar.
class InicioScreen extends StatefulWidget {
  const InicioScreen({
    super.key,
    required this.usuarioId,
    this.cargarMascota = mascotaDelBackend,
  });

  final int usuarioId;
  final CargaMascota cargarMascota;

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  ServiciosEnfoque? _servicios;
  ServiciosEnfoque get _s => _servicios!;

  Tecnica _tecnica = Tecnica.porDefecto;
  int _minutosLibre = Duraciones.porDefecto;
  int _rondas = Rondas.porDefecto;
  DestinoDisponible? _elegido;

  List<DestinoDisponible> _destinos = const [];
  bool _cargandoDestinos = true;
  bool _errorDestinos = false;

  ({String? fase, String? estado})? _mascota;

  bool _empezando = false;

  /// Repinta la hoja de destinos si está abierta (la lista puede llegar o
  /// fallar con la hoja ya a la vista). Con su contexto, para no repintarla
  /// cuando ya se ha ido.
  StateSetter? _repintarHoja;
  BuildContext? _contextoHoja;

  int get _minutos => _tecnica.minutos(_minutosLibre);

  /// Las rondas que se van a hacer: en Libre, siempre una.
  int get _rondasEfectivas => _tecnica.conRondas ? _rondas : 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_servicios != null) return;
    _servicios = AmbitoEnfoque.de(context);
    _s.controlador.refrescos.addListener(_cargarDestinos);
    _s.destinoPedido.addListener(_aplicarPedido);
    unawaited(_cargarEleccion());
    unawaited(_cargarMascota());
    _cargarDestinos();
  }

  @override
  void dispose() {
    _s.controlador.refrescos.removeListener(_cargarDestinos);
    _s.destinoPedido.removeListener(_aplicarPedido);
    super.dispose();
  }

  void _cambiar(VoidCallback cambio) {
    if (!mounted) return;
    setState(cambio);
    if (_contextoHoja?.mounted ?? false) _repintarHoja?.call(() {});
  }

  /// La técnica y los minutos de Libre de la última vez.
  Future<void> _cargarEleccion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tecnica = Tecnica.deClave(prefs.getString(claveTecnica));
      final libre = Duraciones.ajustar(
        prefs.getInt(claveMinutosLibre) ?? Duraciones.porDefecto,
      );
      final rondas = Rondas.ajustar(
        prefs.getInt(claveRondas) ?? Rondas.porDefecto,
      );
      _cambiar(() {
        _tecnica = tecnica;
        _minutosLibre = libre;
        _rondas = rondas;
      });
    } catch (_) {
      // Sin preferencias, la de por defecto.
    }
  }

  Future<void> _guardarEleccion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(claveTecnica, _tecnica.name);
      await prefs.setInt(claveMinutosLibre, _minutosLibre);
      await prefs.setInt(claveRondas, _rondas);
    } catch (_) {
      // Si no se guarda, la próxima vez sale la de por defecto.
    }
  }

  void _elegirTecnica(Tecnica t) {
    _cambiar(() => _tecnica = t);
    unawaited(_guardarEleccion());
  }

  void _cambiarRondas(int r) {
    _cambiar(() => _rondas = Rondas.ajustar(r));
    unawaited(_guardarEleccion());
  }

  void _cambiarMinutosLibre(int m) {
    _cambiar(() => _minutosLibre = m);
    unawaited(_guardarEleccion());
  }

  Future<void> _cargarMascota() async {
    final m = await widget.cargarMascota();
    if (m != null) _cambiar(() => _mascota = m);
  }

  Future<void> _cargarDestinos() async {
    _cambiar(() {
      _cargandoDestinos = true;
      _errorDestinos = false;
    });
    try {
      final destinos = await _s.api.destinos();
      _cambiar(() {
        _destinos = destinos;
        _elegido = elegidoTrasRecargar(_elegido, destinos);
        _cargandoDestinos = false;
      });
      _aplicarPedido();
    } catch (_) {
      _cambiar(() {
        _cargandoDestinos = false;
        _errorDestinos = true;
      });
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
    _cambiar(() => _elegido = destino);
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
    if (!mounted) return;
    final aviso = switch (abierto) {
      AperturaHabits.nada => AppLocalizations.of(context)!.abrirHabitsError,
      AperturaHabits.faltaPrueba => textoFaltaHabitsPrueba,
      _ => null,
    };
    if (aviso != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(aviso)));
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
      await _s.tanda.empezar(
        rondas: _rondasEfectivas,
        minutos: _minutos,
        descanso: _tecnica.minutosDescanso ?? 0,
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

  Future<void> _abrirDestinos() async {
    final l = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (hoja) => StatefulBuilder(
        builder: (hoja, repintar) {
          _repintarHoja = repintar;
          _contextoHoja = hoja;
          final t = tokens(hoja);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(hoja).size.height * 0.7,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                children: [
                  Text(
                    l.inicioDestino,
                    style: Theme.of(
                      hoja,
                    ).textTheme.titleMedium?.copyWith(color: t.text),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ..._bloqueDestino(l, t, alElegir: () => Navigator.pop(hoja)),
                ],
              ),
            ),
          );
        },
      ),
    );
    _repintarHoja = null;
    _contextoHoja = null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = tokens(context);
    final duracion = duracionLegible(l, _minutos);

    return LayoutBuilder(
      builder: (context, limites) => RefreshIndicator(
        onRefresh: _cargarDestinos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: limites.maxHeight - 2 * AppSpacing.md,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox.shrink(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Column(
                    children: [
                      Center(
                        child: Semantics(
                          container: true,
                          label: l.inicioAroEtiqueta(duracion),
                          excludeSemantics: true,
                          child: AroCuentaAtras(
                            restante: Duration(minutes: _minutos),
                            total: Duration(minutes: _minutos),
                            tamano: 260,
                            centro: MascotaAnimadaViva(
                              fase: _mascota?.fase,
                              estado: _mascota?.estado,
                              tamano: 96,
                            ),
                          ),
                        ),
                      ),
                      if (_rondasEfectivas > 1) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l.inicioTandaResumen(
                            _rondasEfectivas,
                            _minutos,
                            _tecnica.minutosDescanso!,
                            duracionLegible(
                              l,
                              minutosTanda(
                                rondas: _rondasEfectivas,
                                minutos: _minutos,
                                descanso: _tecnica.minutosDescanso!,
                              ),
                            ),
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: t.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        for (final tec in Tecnica.values) ...[
                          if (tec != Tecnica.values.first)
                            const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _ChipTecnica(
                              nombre: _nombreTecnica(l, tec),
                              detalle: _detalleTecnica(l, tec),
                              elegida: tec == _tecnica,
                              alPulsar: () => _elegirTecnica(tec),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_tecnica.conRondas)
                      SelectorRondas(rondas: _rondas, alCambiar: _cambiarRondas)
                    else
                      SelectorDuracion(
                        minutos: _minutosLibre,
                        alCambiar: _cambiarMinutosLibre,
                      ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: _empezando ? null : _empezar,
                      icon: const Icon(LucideIcons.play),
                      label: Text(l.inicioEmpezar),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Center(
                      child: Semantics(
                        hint: l.inicioDestinoCambiar,
                        child: TextButton.icon(
                          onPressed: _abrirDestinos,
                          iconAlignment: IconAlignment.end,
                          icon: Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: t.textMuted,
                          ),
                          label: Text(
                            l.inicioDestinoLinea(
                              _elegido == null
                                  ? l.destinoSinHabito
                                  : textoDestino(l, _elegido!),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _nombreTecnica(AppLocalizations l, Tecnica tec) => switch (tec) {
    Tecnica.pomodoro => l.inicioTecnicaPomodoro,
    Tecnica.profundo => l.inicioTecnicaProfundo,
    Tecnica.libre => l.inicioTecnicaLibre,
  };

  String _detalleTecnica(AppLocalizations l, Tecnica tec) => switch (tec) {
    Tecnica.libre => l.inicioTecnicaLibreDetalle,
    _ => l.duracionMinutos(tec.minutosFijos!),
  };

  /// La lista de destinos de la hoja. [alElegir] la cierra al elegir uno.
  List<Widget> _bloqueDestino(
    AppLocalizations l,
    TokensContextuales t, {
    required VoidCallback alElegir,
  }) {
    final cuerpo = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: t.textMuted);
    void elegir(DestinoDisponible? d) {
      _cambiar(() => _elegido = d);
      alElegir();
    }

    final sinHabito = OpcionDestino(
      titulo: l.destinoSinHabito,
      subtitulo: l.destinoSinHabitoAyuda,
      elegida: _elegido == null,
      alPulsar: () => elegir(null),
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
          alPulsar: () => elegir(d),
        ),
      ],
    ];
  }
}

/// Un botón de técnica: el nombre y, debajo, sus minutos («25 min») o «A tu
/// aire».
class _ChipTecnica extends StatelessWidget {
  const _ChipTecnica({
    required this.nombre,
    required this.detalle,
    required this.elegida,
    required this.alPulsar,
  });

  final String nombre;
  final String detalle;
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
      label: AppLocalizations.of(
        context,
      )!.inicioTecnicaEtiqueta(nombre, detalle),
      excludeSemantics: true,
      child: SuperficieIdentidad(
        onTap: alPulsar,
        relleno: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        filo: elegida ? BorderSide(color: t.primaryTrazo, width: 2) : null,
        filoNeon: elegida ? FiloNeon.encendido : FiloNeon.fijo,
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                nombre,
                maxLines: 1,
                style: tema.labelLarge?.copyWith(
                  color: elegida ? t.successText : t.text,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                detalle,
                maxLines: 1,
                style: tema.labelSmall?.copyWith(color: t.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Las rondas de Pomodoro y Profundo: de 1 a 4.
class SelectorRondas extends StatelessWidget {
  const SelectorRondas({
    super.key,
    required this.rondas,
    required this.alCambiar,
  });

  final int rondas;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = tokens(context);
    return Semantics(
      container: true,
      label: l.inicioRondas(rondas),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: rondas > Rondas.minimo
                ? () => alCambiar(rondas - 1)
                : null,
            icon: const Icon(LucideIcons.minus),
            tooltip: l.inicioRondaMenos,
            color: t.text,
          ),
          ExcludeSemantics(
            child: SizedBox(
              width: 120,
              child: Text(
                l.inicioRondas(rondas),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: t.text),
              ),
            ),
          ),
          IconButton(
            onPressed: rondas < Rondas.maximo
                ? () => alCambiar(rondas + 1)
                : null,
            icon: const Icon(LucideIcons.plus),
            tooltip: l.inicioRondaMas,
            color: t.text,
          ),
        ],
      ),
    );
  }
}

/// El selector de minutos de Libre: de 10 a 120, de 5 en 5.
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
    return Semantics(
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
                ).textTheme.titleLarge?.copyWith(color: t.text),
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
