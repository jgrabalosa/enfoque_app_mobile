import 'package:flutter/scheduler.dart';

/// Cuánto tardan los fotogramas de verdad, con los tiempos del motor (desde
/// que empieza a construir hasta que la GPU termina), no a ojo. Guarda los
/// últimos [capacidad].
class MedidorFotogramas {
  MedidorFotogramas({this.capacidad = 120});

  final int capacidad;
  final List<double> _ms = [];

  /// Para los tests: mete tiempos a mano.
  void anotar(Iterable<double> milisegundos) {
    _ms.addAll(milisegundos);
    if (_ms.length > capacidad) _ms.removeRange(0, _ms.length - capacidad);
  }

  void _alLlegar(List<FrameTiming> tiempos) =>
      anotar(tiempos.map((t) => t.totalSpan.inMicroseconds / 1000));

  void empezar() => SchedulerBinding.instance.addTimingsCallback(_alLlegar);

  void parar() => SchedulerBinding.instance.removeTimingsCallback(_alLlegar);

  void reiniciar() => _ms.clear();

  /// La media, en milisegundos, o `null` sin datos.
  double? get media =>
      _ms.isEmpty ? null : _ms.reduce((a, b) => a + b) / _ms.length;

  /// El tiempo que solo supera el peor 10 % de los fotogramas.
  double? get peor10 {
    if (_ms.isEmpty) return null;
    final orden = [..._ms]..sort();
    return orden[((orden.length - 1) * 0.9).round()];
  }

  /// Un resumen para la pantalla: «8,1 ms · peor 10 % 12,4 ms».
  String get resumen {
    final m = media;
    final p = peor10;
    if (m == null || p == null) return 'midiendo…';
    String f(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    return '${f(m)} ms · peor 10 % ${f(p)} ms';
  }
}
