import 'package:norday_flutter_core/norday_flutter_core.dart';

/// Fase y ánimo de Nori, o `null` si no se pudo saber (entonces se pinta con
/// los valores por defecto).
typedef CargaMascota = Future<({String? fase, String? estado})?> Function();

/// Nori del usuario conectado, desde el backend. Lo usan Inicio y la sesión,
/// que la pintan dentro del aro.
Future<({String? fase, String? estado})?> mascotaDelBackend() async {
  try {
    final usuario = await ApiServiceCore.getUsuarioLocal();
    final id = usuario?['usuarioId'];
    if (id is! int) return null;
    final datos = await ApiServiceCore.getMascota(id);
    return (fase: datos['fase'] as String?, estado: animoDeMascota(datos));
  } catch (_) {
    return null;
  }
}
