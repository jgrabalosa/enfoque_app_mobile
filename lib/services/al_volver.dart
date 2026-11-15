import 'dart:async';

import 'package:norday_flutter_core/norday_flutter_core.dart';

import 'identidad_al_volver.dart';

/// Lo que pasa al volver a primer plano, en un único punto: la identidad
/// equipada (puede haberse cambiado desde Norday Habits, que comparte
/// cuenta), el registro del aviso del móvil (el token de FCM, por si el
/// permiso se dio en Ajustes) y el reenvío de las sesiones pendientes.
///
/// No espera a nada: ninguno de los tres puede bloquear el regreso a la app,
/// y un fallo nunca llega a quien llama.
void alVolverAPrimerPlano(
  int usuarioId, {
  required Future<void> Function() enviarPendientes,
  Future<bool?> Function(int)? recargarIdentidad,
  Future<void> Function(int)? registrarAviso,
}) {
  recargarIdentidadAlVolver(usuarioId, cargar: recargarIdentidad);
  if (usuarioId > 0) {
    unawaited(_seguro(() => (registrarAviso ?? _registrar)(usuarioId)));
    unawaited(_seguro(enviarPendientes));
  }
}

Future<void> _registrar(int usuarioId) =>
    NotificacionesService.registrarSiHayPermiso(usuarioId);

Future<void> _seguro(Future<void> Function() accion) async {
  try {
    await accion();
  } catch (_) {
    // Se reintenta en el siguiente regreso a la app o login.
  }
}
