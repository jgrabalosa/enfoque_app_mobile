import 'dart:io' show HttpDate;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cuánto va el reloj del servidor por delante del reloj de pared del móvil
/// (servidor − móvil), sacado de la cabecera `Date` de las respuestas del
/// backend y guardado en el móvil.
///
/// Sirve para una sola cosa: corregir el `inicioUtc` de una sesión al
/// meterla en la cola. El backend valida el inicio contra su reloj (que no
/// acabe más de 2 minutos en el futuro, que no empezara hace más de 7 días,
/// que no se solape) y saca de él el día de la sesión: con un móvil que va
/// mal de hora, una sesión buena acabaría en 400 o en otro día.
///
/// - **Resolución**: `Date` va en segundos enteros y se lee al recibir, así
///   que cada medida trae ±1 s de ruido más la latencia.
/// - **Histéresis**: una medida nueva solo sustituye a la guardada si se
///   aparta más de [histeresis]. Si cada sesión se corrigiera con el ruido de
///   su medida, dos sesiones seguidas podrían acabar solapadas un segundo y
///   la segunda daría 409.
/// - **Umbral**: con un desfase de menos de [umbral] no se corrige nada.
class DesfaseServidor {
  DesfaseServidor({
    this.clave = 'enfoque_desfase_servidor_ms',
    this.histeresis = const Duration(seconds: 5),
    this.umbral = const Duration(seconds: 5),
  });

  final String clave;
  final Duration histeresis;
  final Duration umbral;

  Duration? _desfase;

  /// El desfase conocido, o `null` si aún no se ha medido nunca.
  Duration? get desfase => _desfase;

  /// Lee el desfase guardado. Un fallo deja «sin desfase conocido».
  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(clave);
      _desfase = ms == null ? null : Duration(milliseconds: ms);
    } catch (e) {
      debugPrint('DesfaseServidor: no se pudo leer: $e');
    }
  }

  /// Apunta una medida: la hora del servidor [servidorUtc] y la del móvil
  /// [movilUtc] al recibir la respuesta.
  Future<void> registrar(DateTime servidorUtc, DateTime movilUtc) async {
    final medida = servidorUtc.toUtc().difference(movilUtc.toUtc());
    final actual = _desfase;
    if (actual != null && (medida - actual).abs() <= histeresis) return;
    _desfase = medida;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(clave, medida.inMilliseconds);
    } catch (e) {
      debugPrint('DesfaseServidor: no se pudo guardar: $e');
    }
  }

  /// Apunta la cabecera `Date` de una respuesta, si la trae y se entiende.
  Future<void> registrarCabecera(String? date, DateTime movilUtc) async {
    if (date == null) return;
    final DateTime servidor;
    try {
      servidor = HttpDate.parse(date);
    } catch (_) {
      return;
    }
    await registrar(servidor, movilUtc);
  }

  /// [inicioUtc] en la hora del servidor, o tal cual si no hay desfase
  /// conocido o es menor que [umbral].
  DateTime corregir(DateTime inicioUtc) {
    final d = _desfase;
    if (d == null || d.abs() < umbral) return inicioUtc.toUtc();
    return inicioUtc.toUtc().add(d);
  }
}
