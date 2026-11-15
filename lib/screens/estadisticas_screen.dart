import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

import '../l10n/app_localizations.dart';
import '../models/enfoque.dart';
import '../services/cola_envios.dart';
import '../services/servicios_enfoque.dart';
import '../widgets/barras_semana.dart';
import 'estadisticas_logica.dart';

/// Estadísticas: las barras de minutos de la semana, los totales de la
/// semana y del mes, y el historial con lo pendiente de enviar y lo que el
/// backend no aceptó delante.
class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key, this.activa = true, this.hoy});

  /// Es la pestaña visible: al pasar a serlo, recarga.
  final bool activa;

  /// El día de hoy. Sin él, el del móvil.
  final DateTime Function()? hoy;

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  static const int _tamanoPagina = 20;

  ServiciosEnfoque? _servicios;
  ServiciosEnfoque get _s => _servicios!;
  ColaEnvios get _cola => _s.controlador.cola;

  int? _usuarioId;
  ResumenEnfoque? _resumen;
  final List<SesionServidor> _historial = [];
  bool _hayMas = false;
  int _pagina = 0;
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _error = false;

  /// Nombres de los destinos que el backend da hoy, para poner nombre a las
  /// sesiones del historial (que solo traen tipo e id).
  Map<int, String> _nombres = const {};

  DateTime get _hoy {
    final h = (widget.hoy ?? DateTime.now)();
    return DateTime(h.year, h.month, h.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_servicios != null) return;
    _servicios = AmbitoEnfoque.de(context);
    _s.controlador.refrescos.addListener(_cargar);
    _cargar();
  }

  @override
  void didUpdateWidget(EstadisticasScreen old) {
    super.didUpdateWidget(old);
    if (widget.activa && !old.activa) _cargar();
  }

  @override
  void dispose() {
    _s.controlador.refrescos.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = false;
    });
    final usuario = await _s.usuarioActual();
    unawaited(_cargarNombres());
    try {
      final hoy = _hoy;
      final resultados = await Future.wait([
        _s.api.resumen(FechasEstadisticas.desde(hoy), hoy),
        _s.api.historial(pagina: 0, tamano: _tamanoPagina),
      ]);
      if (!mounted) return;
      final pagina = resultados[1] as PaginaHistorial;
      setState(() {
        _usuarioId = usuario;
        _resumen = resultados[0] as ResumenEnfoque;
        _historial
          ..clear()
          ..addAll(pagina.sesiones);
        _pagina = 0;
        _hayMas = pagina.hayMas;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _usuarioId = usuario;
        _cargando = false;
        _error = true;
      });
    }
  }

  Future<void> _cargarNombres() async {
    try {
      final destinos = await _s.api.destinos();
      if (!mounted) return;
      setState(() => _nombres = {for (final d in destinos) d.id: d.nombre});
    } catch (_) {
      // Sin nombres, «Hábito».
    }
  }

  Future<void> _cargarMas() async {
    if (_cargandoMas) return;
    setState(() => _cargandoMas = true);
    try {
      final pagina = await _s.api.historial(
        pagina: _pagina + 1,
        tamano: _tamanoPagina,
      );
      if (!mounted) return;
      setState(() {
        final claves = _historial.map((e) => e.clave).toSet();
        _historial.addAll(
          pagina.sesiones.where((e) => !claves.contains(e.clave)),
        );
        _pagina++;
        _hayMas = pagina.hayMas;
      });
    } catch (e) {
      if (mounted) MensajesError.enSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;
    final hoy = _hoy;
    final titulo = tema.titleMedium?.copyWith(color: t.text);

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_cargando && _resumen == null)
            const SkeletonPulso(child: SkeletonCard(height: 160))
          else if (_resumen != null) ...[
            SuperficieIdentidad(
              protagonista: true,
              child: BarrasSemana(
                hoy: hoy,
                dias: [
                  for (final d in FechasEstadisticas.semana(hoy))
                    (dia: d, minutos: _resumen!.delDia(d).minutos),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _Total(
                    etiqueta: l.estSemana,
                    minutos: _resumen!.minutosEntre(
                      FechasEstadisticas.lunes(hoy),
                      hoy,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Total(
                    etiqueta: l.estMes,
                    minutos: _resumen!.minutosEntre(
                      FechasEstadisticas.primeroDeMes(hoy),
                      hoy,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_error) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.estError,
              style: tema.bodyMedium?.copyWith(color: t.textMuted),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _cargar,
                child: Text(NordayCoreLocalizations.of(context)!.reintentar),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Semantics(header: true, child: Text(l.estHistorial, style: titulo)),
          const SizedBox(height: AppSpacing.sm),
          ..._historialLocal(l),
          for (final s in _historial) ...[
            FilaSesion.deServidor(
              sesion: s,
              nombreDestino: s.destinoId == null ? null : _nombres[s.destinoId],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (!_cargando && !_error && _historial.isEmpty && _locales().isEmpty)
            Text(
              l.estSinSesiones,
              style: tema.bodyMedium?.copyWith(color: t.textMuted),
            ),
          if (_hayMas)
            Center(
              child: TextButton(
                onPressed: _cargandoMas ? null : _cargarMas,
                child: Text(l.estCargarMas),
              ),
            ),
        ],
      ),
    );
  }

  /// Lo pendiente y lo no aceptado del usuario actual (nunca de otra cuenta
  /// que haya entrado en el mismo móvil).
  List<Object> _locales() {
    final id = _usuarioId;
    if (id == null) return const [];
    return [
      ..._cola.pendientes.value.where((e) => e.usuarioId == id),
      ..._cola.noAceptados.value.where((e) => e.usuarioId == id),
    ];
  }

  List<Widget> _historialLocal(AppLocalizations l) => [
    ValueListenableBuilder<List<EnvioPendiente>>(
      valueListenable: _cola.pendientes,
      builder: (context, pendientes, _) => Column(
        children: [
          for (final e in pendientes.reversed)
            if (e.usuarioId == _usuarioId)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: FilaSesion.pendiente(envio: e),
              ),
        ],
      ),
    ),
    ValueListenableBuilder<List<EnvioNoAceptado>>(
      valueListenable: _cola.noAceptados,
      builder: (context, noAceptados, _) => Column(
        children: [
          for (final e in noAceptados)
            if (e.usuarioId == _usuarioId)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: FilaSesion.noAceptada(envio: e),
              ),
        ],
      ),
    ),
  ];
}

class _Total extends StatelessWidget {
  const _Total({required this.etiqueta, required this.minutos});

  final String etiqueta;
  final int minutos;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$etiqueta: ${l.estMinutos(minutos)}',
      excludeSemantics: true,
      child: SuperficieIdentidad(
        relleno: const EdgeInsets.all(AppSpacing.ms),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiqueta,
              style: tema.labelMedium?.copyWith(color: t.textMuted),
            ),
            Text(
              l.estMinutos(minutos),
              style: tema.titleLarge?.copyWith(color: t.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// Qué se pinta en el estado de una fila del historial.
enum EstadoFila { completada, terminada, perdida, pendiente, noEnviada }

/// Una sesión del historial: cuándo, cuánto de cuánto, a dónde, y su estado
/// (completada, terminada, perdida, pendiente de enviar o no enviada).
class FilaSesion extends StatelessWidget {
  const FilaSesion({
    super.key,
    required this.inicio,
    required this.minutos,
    required this.objetivo,
    required this.estado,
    this.destino,
    this.conDestino = false,
    this.motivo,
  });

  /// Del backend.
  factory FilaSesion.deServidor({
    required SesionServidor sesion,
    String? nombreDestino,
  }) => FilaSesion(
    inicio: sesion.inicioUtc,
    minutos: sesion.duracionSeg ~/ 60,
    objetivo: sesion.duracionObjetivoMin,
    estado: switch (sesion.estado) {
      EstadoEnvio.completada => EstadoFila.completada,
      EstadoEnvio.terminada => EstadoFila.terminada,
      _ => EstadoFila.perdida,
    },
    destino: nombreDestino,
    conDestino: sesion.destinoId != null,
  );

  /// De la cola: pendiente de enviar.
  factory FilaSesion.pendiente({required EnvioPendiente envio}) => FilaSesion(
    inicio: envio.peticion.inicioUtc,
    minutos: envio.peticion.duracionSeg ~/ 60,
    objetivo: envio.peticion.duracionObjetivoMin,
    estado: EstadoFila.pendiente,
    destino: envio.destino?.nombre,
    conDestino: envio.peticion.conDestino,
  );

  /// Del historial local: el backend no la aceptó.
  factory FilaSesion.noAceptada({required EnvioNoAceptado envio}) => FilaSesion(
    inicio: envio.peticion.inicioUtc,
    minutos: envio.peticion.duracionSeg ~/ 60,
    objetivo: envio.peticion.duracionObjetivoMin,
    estado: EstadoFila.noEnviada,
    destino: envio.destino?.nombre,
    conDestino: envio.peticion.conDestino,
    motivo: envio.mensaje,
  );

  final DateTime? inicio;
  final int minutos;
  final int objetivo;
  final EstadoFila estado;

  /// El nombre del destino, si se sabe.
  final String? destino;

  /// Iba a un destino (aunque no se sepa su nombre).
  final bool conDestino;

  /// Solo en [EstadoFila.noEnviada]: el motivo del backend.
  final String? motivo;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = tokens(context);
    final tema = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final (IconData icono, Color color, String textoEstado) = switch (estado) {
      EstadoFila.completada => (
        LucideIcons.circleCheck,
        t.successText,
        l.estadoCompletada,
      ),
      EstadoFila.terminada => (
        LucideIcons.circleStop,
        t.successText,
        l.estadoTerminada,
      ),
      EstadoFila.perdida => (LucideIcons.circleX, t.textMuted, l.estadoPerdida),
      EstadoFila.pendiente => (
        LucideIcons.cloudOff,
        t.pointsText,
        l.estadoPendiente,
      ),
      EstadoFila.noEnviada => (
        LucideIcons.circleAlert,
        t.streakText,
        l.estadoNoEnviada,
      ),
    };
    final nombre = (destino == null || destino!.trim().isEmpty)
        ? (conDestino ? l.filaSesionHabito : l.destinoSinHabito)
        : destino!;
    final cuando = inicio == null
        ? ''
        : DateFormat.MMMd(locale).add_Hm().format(inicio!.toLocal());

    return SuperficieIdentidad(
      relleno: const EdgeInsets.all(AppSpacing.ms),
      child: MergeSemantics(
        child: Row(
          children: [
            Icon(icono, size: 20, color: color),
            const SizedBox(width: AppSpacing.ms),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.filaSesionResumen(minutos, objetivo, nombre),
                    style: tema.bodyLarge?.copyWith(color: t.text),
                  ),
                  Text(
                    cuando.isEmpty ? textoEstado : '$cuando · $textoEstado',
                    style: tema.bodySmall?.copyWith(color: color),
                  ),
                  if (estado == EstadoFila.noEnviada)
                    Text(
                      motivo ?? l.estNoEnviadaMotivo,
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
