/// El destino que pide un enlace de entrada:
/// `norday-enfoque://sesion?destino=habito&id=N`. Lo manda Norday Habits
/// desde «Empezar sesión» del panel de minutos, y deja Inicio con ese destino
/// elegido.
class DestinoPedido {
  final String tipo;
  final int id;

  const DestinoPedido(this.tipo, this.id);

  @override
  bool operator ==(Object other) =>
      other is DestinoPedido && other.tipo == tipo && other.id == id;

  @override
  int get hashCode => Object.hash(tipo, id);

  @override
  String toString() => 'DestinoPedido($tipo, $id)';
}

/// El esquema del enlace de entrada (intent-filter del AndroidManifest).
const String esquemaEnlace = 'norday-enfoque';

/// El destino del enlace [texto], o `null` si no es un enlace de sesión
/// válido: otro esquema u otro host, sin `destino` o sin `id`, o un `id` que
/// no es un entero positivo. Un `destino` desconocido para esta versión
/// también vale: quien decide si existe es la lista de destinos del backend.
DestinoPedido? destinoDeEnlace(String? texto) {
  if (texto == null) return null;
  final uri = Uri.tryParse(texto.trim());
  if (uri == null) return null;
  if (uri.scheme.toLowerCase() != esquemaEnlace ||
      uri.host.toLowerCase() != 'sesion') {
    return null;
  }
  final tipo = uri.queryParameters['destino']?.trim();
  final id = int.tryParse(uri.queryParameters['id']?.trim() ?? '');
  if (tipo == null || tipo.isEmpty || id == null || id <= 0) return null;
  return DestinoPedido(tipo, id);
}
