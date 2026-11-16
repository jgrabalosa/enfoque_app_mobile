import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../escena_mundo.dart';
import '../vista_mundo.dart';
import 'medidor_fotogramas.dart';
import 'mundos_del_laboratorio.dart';

/// El laboratorio de los mundos (`encargos/focus-mundos.md` §4): cada mundo
/// con piezas de mentira, para verlo en el móvil antes de construirlo de
/// verdad. **Solo existe en el flavor `prueba`**: se entra desde
/// Estadísticas.
///
/// Los textos van en español y sin traducir a propósito: esta pantalla no
/// llega nunca a Play.
class LaboratorioMundosScreen extends StatefulWidget {
  const LaboratorioMundosScreen({
    super.key,
    this.semilla = 2026,
    this.cantidadInicial = 10,
    this.mundos,
    this.medir = true,
  });

  final int semilla;
  final int cantidadInicial;

  /// Los mundos que se pueden ver. Sin ellos, los de
  /// [mundosDelLaboratorio].
  final List<MundoDeLaboratorio>? mundos;

  /// Medir los fotogramas (en los tests no hay motor que los dé).
  final bool medir;

  static const List<int> cantidades = [1, 10, 50, 100, 1000];

  @override
  State<LaboratorioMundosScreen> createState() =>
      _LaboratorioMundosScreenState();
}

class _LaboratorioMundosScreenState extends State<LaboratorioMundosScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _viaje = Duration(milliseconds: 900);
  static const double _duracionAparicion = 1.4;

  late final List<MundoDeLaboratorio> _mundos =
      widget.mundos ?? mundosDelLaboratorio();
  int _mundo = 0;
  int _pintor = 0;
  final Set<int> _preparados = {};

  MundoDeLaboratorio get _m => _mundos[_mundo];

  late int _semilla = widget.semilla;
  late int _cantidad = widget.cantidadInicial;
  late EscenaMundo _escena = _nuevaEscena();
  NivelZoom _nivel = NivelZoom.hoy;

  final ValueNotifier<double> _segundos = ValueNotifier(0);
  late final Ticker _ticker;
  final MedidorFotogramas _medidor = MedidorFotogramas();
  Timer? _refresco;

  Size? _tamano;
  VistaMundo? _vista;

  // El viaje de la cámara en curso, si lo hay.
  VistaMundo? _desde;
  VistaMundo? _hacia;
  double _inicioViaje = 0;

  // La pieza que está apareciendo, si la hay.
  int? _nueva;
  double _inicioNueva = 0;

  double _escalaAlEmpezar = 1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((t) {
      _segundos.value = t.inMicroseconds / 1e6;
    })..start();
    if (widget.medir) {
      _medidor.empezar();
      _refresco = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() {});
      });
    }
    _preparar(_mundo);
  }

  Future<void> _preparar(int mundo) async {
    if (_preparados.contains(mundo)) return;
    await _mundos[mundo].preparar();
    if (mounted) setState(() => _preparados.add(mundo));
  }

  @override
  void dispose() {
    _refresco?.cancel();
    if (widget.medir) _medidor.parar();
    _ticker.dispose();
    _segundos.dispose();
    for (final m in _mundos) {
      m.liberar();
    }
    super.dispose();
  }

  EscenaMundo _nuevaEscena() => _m.crearEscena(_semilla, _cantidad);

  /// La vista en este momento, con el viaje de la cámara aplicado.
  VistaMundo _vistaAhora(Size tamano) {
    _vista ??= VistasMundo.de(_nivel, _escena, tamano);
    final desde = _desde;
    final hacia = _hacia;
    if (desde == null || hacia == null) return _vista!;
    final t = ((_segundos.value - _inicioViaje) / (_viaje.inMicroseconds / 1e6))
        .clamp(0.0, 1.0);
    final v = desde.hacia(hacia, Curves.easeInOutCubic.transform(t));
    if (t >= 1) {
      _vista = hacia;
      _desde = _hacia = null;
    }
    return v;
  }

  void _viajarA(NivelZoom nivel) {
    final tamano = _tamano;
    if (tamano == null) return;
    _desde = _vistaAhora(tamano);
    _hacia = VistasMundo.de(nivel, _escena, tamano);
    _inicioViaje = _segundos.value;
  }

  void _elegirNivel(NivelZoom nivel) {
    setState(() => _nivel = nivel);
    _viajarA(nivel);
  }

  void _elegirCantidad(int cantidad) {
    setState(() {
      _cantidad = cantidad;
      _escena = _nuevaEscena();
      _nueva = null;
      _medidor.reiniciar();
    });
    _viajarA(_nivel);
  }

  void _anadirUna() {
    setState(() {
      _cantidad++;
      _escena = _nuevaEscena();
      _nueva = _cantidad - 1;
      _inicioNueva = _segundos.value;
    });
    if (_nivel == NivelZoom.hoy) _viajarA(NivelZoom.hoy);
  }

  void _otraSemilla() {
    setState(() {
      _semilla = math.Random().nextInt(1 << 30);
      _escena = _nuevaEscena();
      _nueva = null;
    });
    _viajarA(_nivel);
  }

  void _cambiarPintor() => setState(() {
    _pintor = (_pintor + 1) % _m.pintores.length;
    _medidor.reiniciar();
  });

  void _cambiarMundo() {
    setState(() {
      _mundo = (_mundo + 1) % _mundos.length;
      _pintor = 0;
      _escena = _nuevaEscena();
      _nueva = null;
      _desde = _hacia = null;
      final tamano = _tamano;
      if (tamano != null) _vista = VistasMundo.de(_nivel, _escena, tamano);
      _medidor.reiniciar();
    });
    _preparar(_mundo);
  }

  void _alEmpezarGesto(ScaleStartDetails d) {
    final tamano = _tamano;
    if (tamano == null) return;
    _vista = _vistaAhora(tamano);
    _desde = _hacia = null;
    _escalaAlEmpezar = _vista!.escala;
  }

  void _alMoverGesto(ScaleUpdateDetails d) {
    final tamano = _tamano;
    final vista = _vista;
    if (tamano == null || vista == null) return;
    final escala = (_escalaAlEmpezar * d.scale).clamp(
      VistasMundo.escalaMinima,
      VistasMundo.escalaMaxima,
    );
    _vista = vista
        .movida(d.focalPointDelta)
        .conEscala(escala, d.localFocalPoint, tamano);
  }

  @override
  Widget build(BuildContext context) {
    final escena = _escena;
    final mundo = _m;
    final pintor = mundo.pintores[_pintor];
    final preparado = _preparados.contains(_mundo);
    final estiloInfo = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.white70);
    final aviso = preparado ? pintor.aviso : null;

    return Scaffold(
      backgroundColor: const Color(0xFF070D19),
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, limites) {
                final tamano = limites.biggest;
                if (_tamano != tamano) {
                  _tamano = tamano;
                  _vista = VistasMundo.de(_nivel, escena, tamano);
                }
                if (!preparado) {
                  return const Center(child: CircularProgressIndicator());
                }
                return GestureDetector(
                  onScaleStart: _alEmpezarGesto,
                  onScaleUpdate: _alMoverGesto,
                  child: CustomPaint(
                    size: tamano,
                    painter: _Lienzo(
                      repaint: _segundos,
                      pintar: (canvas, size) {
                        final s = _segundos.value;
                        final nueva = _nueva;
                        double aparicion = 1;
                        if (nueva != null) {
                          aparicion = ((s - _inicioNueva) / _duracionAparicion)
                              .clamp(0.0, 1.0);
                        }
                        mundo.pintar(
                          _pintor,
                          canvas,
                          size,
                          _vistaAhora(size),
                          escena,
                          segundos: s,
                          nueva: nueva,
                          aparicion: aparicion,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    const BackButton(color: Colors.white),
                    Expanded(
                      child: Text(
                        'Laboratorio de mundos · ${mundo.nombre}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${escena.cantidad} piezas · ${escena.completas} '
                        'regiones completas',
                        style: estiloInfo,
                      ),
                      Text(
                        escena.cantidad == 0
                            ? 'Sin piezas'
                            : '${escena.nombreRegion(escena.deLaUltima)} · '
                                  '${escena.enLaUltima}/'
                                  '${escena.piezasPorRegion}',
                        style: estiloInfo,
                      ),
                      Text(
                        'Pintor: ${pintor.nombre}'
                        '${aviso == null ? '' : ' ($aviso)'}'
                        ' · semilla $_semilla',
                        style: estiloInfo,
                      ),
                      if (widget.medir)
                        Text(
                          'Fotograma: ${_medidor.resumen}',
                          key: const Key('lab-tiempos'),
                          style: estiloInfo,
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                _Mandos(
                  cantidad: _cantidad,
                  nivel: _nivel,
                  pintor: pintor.nombre,
                  mundo: _mundos.length > 1 ? mundo.nombre : null,
                  alElegirCantidad: _elegirCantidad,
                  alElegirNivel: _elegirNivel,
                  alAnadir: _anadirUna,
                  alOtraSemilla: _otraSemilla,
                  alCambiarPintor: _cambiarPintor,
                  alCambiarMundo: _cambiarMundo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Mandos extends StatelessWidget {
  const _Mandos({
    required this.cantidad,
    required this.nivel,
    required this.pintor,
    required this.mundo,
    required this.alElegirCantidad,
    required this.alElegirNivel,
    required this.alAnadir,
    required this.alOtraSemilla,
    required this.alCambiarPintor,
    required this.alCambiarMundo,
  });

  final int cantidad;
  final NivelZoom nivel;
  final String pintor;

  /// El mundo que se ve, o `null` si solo hay uno.
  final String? mundo;
  final ValueChanged<int> alElegirCantidad;
  final ValueChanged<NivelZoom> alElegirNivel;
  final VoidCallback alAnadir;
  final VoidCallback alOtraSemilla;
  final VoidCallback alCambiarPintor;
  final VoidCallback alCambiarMundo;

  static const Map<NivelZoom, String> _nombres = {
    NivelZoom.hoy: 'Hoy',
    NivelZoom.cerca: 'Cerca',
    NivelZoom.todo: 'Todo',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xCC070D19),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final n in LaboratorioMundosScreen.cantidades)
                ChoiceChip(
                  label: Text('$n'),
                  selected: cantidad == n,
                  onSelected: (_) => alElegirCantidad(n),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final n in NivelZoom.values)
                ChoiceChip(
                  label: Text(_nombres[n]!),
                  selected: nivel == n,
                  onSelected: (_) => alElegirNivel(n),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonal(onPressed: alAnadir, child: const Text('+1')),
              OutlinedButton(
                onPressed: alOtraSemilla,
                child: const Text('Otra semilla'),
              ),
              OutlinedButton(
                onPressed: alCambiarPintor,
                child: Text('Pintor: $pintor'),
              ),
              if (mundo != null)
                OutlinedButton(
                  onPressed: alCambiarMundo,
                  child: Text('Mundo: $mundo'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Lienzo extends CustomPainter {
  _Lienzo({required Listenable repaint, required this.pintar})
    : super(repaint: repaint);

  final void Function(Canvas canvas, Size size) pintar;

  @override
  void paint(Canvas canvas, Size size) => pintar(canvas, size);

  @override
  bool shouldRepaint(_Lienzo old) => true;
}
