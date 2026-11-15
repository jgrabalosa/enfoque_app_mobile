import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/enlace_entrada.dart';
import 'api_service_enfoque.dart';
import 'canal_sistema.dart';
import 'controlador_enfoque.dart';

/// Todo lo que las pantallas de esta app necesitan de fuera: la API, el
/// controlador de sesiones, el lanzador del sistema y el destino que haya
/// pedido un enlace. En la app se monta en `main()`; en los tests, con
/// falsos.
class ServiciosEnfoque {
  ServiciosEnfoque({
    required this.api,
    required this.controlador,
    required this.lanzador,
    required this.flavor,
    required this.usuarioActual,
    required this.pedirPermisoAvisos,
    required this.celebrar,
    this.clavePermisoPedido = 'enfoque_permiso_avisos_pedido',
  });

  final ApiEnfoque api;
  final ControladorEnfoque controlador;
  final Lanzador lanzador;

  /// El flavor con que se compiló (`appFlavor`): decide qué Norday Habits se
  /// abre.
  final String? flavor;

  /// El usuario con la sesión abierta, o `null`.
  final Future<int?> Function() usuarioActual;

  /// Pide el permiso de notificaciones y, si se da, registra el aviso del
  /// móvil (en la app, `NotificacionesService.pedirYRegistrar`).
  final Future<bool> Function(int usuarioId) pedirPermisoAvisos;

  /// Celebra logros (en la app, `CelebracionService.mostrar`).
  final Future<void> Function(List<String> codigos) celebrar;

  /// Dónde se apunta que el permiso ya se pidió una vez.
  final String clavePermisoPedido;

  final ValueNotifier<DestinoPedido?> _destinoPedido = ValueNotifier(null);

  /// El destino que pidió el último enlace de entrada, hasta que Inicio lo
  /// aplica y lo suelta con [soltarDestinoPedido].
  ValueListenable<DestinoPedido?> get destinoPedido => _destinoPedido;

  /// Un enlace ha pedido [destino]. Un enlace que no se entiende (`null`) no
  /// cambia nada.
  void pedirDestino(DestinoPedido? destino) {
    if (destino != null) _destinoPedido.value = destino;
  }

  void soltarDestinoPedido() => _destinoPedido.value = null;
}

/// Pone [ServiciosEnfoque] al alcance de toda la app. Va por encima del
/// `MaterialApp`, así que lo ven también las rutas que empuja el core (el
/// login lleva a `destinoTrasLogin`).
class AmbitoEnfoque extends InheritedWidget {
  const AmbitoEnfoque({
    super.key,
    required this.servicios,
    required super.child,
  });

  final ServiciosEnfoque servicios;

  static ServiciosEnfoque de(BuildContext context) {
    final ambito = context.dependOnInheritedWidgetOfExactType<AmbitoEnfoque>();
    assert(ambito != null, 'Falta AmbitoEnfoque por encima');
    return ambito!.servicios;
  }

  @override
  bool updateShouldNotify(AmbitoEnfoque oldWidget) =>
      oldWidget.servicios != servicios;
}
