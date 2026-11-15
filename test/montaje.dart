import 'dart:async';

import 'package:enfoque_app_mobile/l10n/app_localizations.dart';
import 'package:enfoque_app_mobile/services/cola_envios.dart';
import 'package:enfoque_app_mobile/services/controlador_enfoque.dart';
import 'package:enfoque_app_mobile/services/servicios_enfoque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

import 'falsos.dart';

export 'falsos.dart';

/// Todo lo que una pantalla necesita, con falsos.
class Montaje {
  Montaje(WidgetTester tester, {int? usuarioId = 7})
    : reloj = RelojFalso(),
      pantalla = PantallaFalsa(),
      api = ApiFalsa(),
      lanzador = LanzadorFalso() {
    motor = MotorSesion(
      reloj: reloj,
      pantalla: pantalla,
      binding: tester.binding,
    );
    addTearDown(motor.dispose);
    cola = ColaEnvios(
      api: api,
      usuarioActual: () async => usuarioId,
      programar: programador.call,
    );
    controlador = ControladorEnfoque(
      motor: motor,
      cola: cola,
      usuarioActual: () async => usuarioId,
    );
    servicios = ServiciosEnfoque(
      api: api,
      controlador: controlador,
      lanzador: lanzador,
      flavor: 'prueba',
      usuarioActual: () async => usuarioId,
      pedirPermisoAvisos: (id) async {
        permisosPedidos.add(id);
        return await puertaPermiso?.future ?? true;
      },
      celebrar: (codigos) async => celebrados.addAll(codigos),
    );
  }

  final RelojFalso reloj;
  final PantallaFalsa pantalla;
  final ApiFalsa api;
  final LanzadorFalso lanzador;
  final ProgramadorFalso programador = ProgramadorFalso();
  late final MotorSesion motor;
  late final ColaEnvios cola;
  late final ControladorEnfoque controlador;
  late final ServiciosEnfoque servicios;
  final List<int> permisosPedidos = [];

  /// Si está puesta, el permiso no contesta hasta que se complete.
  Completer<bool>? puertaPermiso;
  final List<String> celebrados = [];

  /// [hijo] dentro de un MaterialApp con los textos y el tema, y los
  /// servicios encima.
  Widget app(Widget hijo, {Locale locale = const Locale('es')}) =>
      AmbitoEnfoque(
        servicios: servicios,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: [
            ...AppLocalizations.localizationsDelegates,
            NordayCoreLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.deTema(temaEquipadoNotifier.value),
          home: hijo,
        ),
      );
}
