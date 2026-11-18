import 'dart:math' as math;
import 'dart:ui';

import 'vista_mundo.dart';

/// Lo que todos los mundos (la galaxia de Profundidad, la ciudad de
/// Neotokyo+ y, más adelante, el jardín de Dulce) le cuentan al laboratorio
/// y a la cámara. Cada mundo tiene su escena con lo suyo colocado; esto es
/// lo común.
abstract interface class EscenaMundo {
  /// Cuántas piezas hay.
  int get cantidad;

  /// Cuántas piezas forman una región (una constelación, una manzana).
  int get piezasPorRegion;

  /// Regiones completas.
  int get completas;

  /// La región de la última pieza (la de hoy). Sin piezas, la primera.
  int get deLaUltima;

  /// Cuántas piezas tiene ya la región de la última (1 a [piezasPorRegion]).
  int get enLaUltima;

  /// El nombre de una región («La Grulla Errante», «Barrio Hikari»).
  String nombreRegion(int region);

  /// Dónde está una región, en unidades del mundo.
  Offset centroRegion(int region);

  /// Lo que mide una región: la vista «Hoy» la enseña entera, con aire.
  double get ladoRegion;

  /// Lo lejos del centro que llega lo que hay: la vista «Todo» lo enseña.
  double get radio;
}

/// Una forma de dibujar un mundo. El laboratorio tiene varias por mundo, y
/// todas reciben **la misma escena y la misma vista**: así la comparación es
/// justa, solo cambia el dibujo (`encargos/focus-mundos.md` §3).
abstract class PintorMundo<E extends EscenaMundo> {
  /// Lo que se ve en el botón del laboratorio.
  String get nombre;

  /// Lo que haya que preparar una vez (texturas, shaders). Se espera antes
  /// del primer [pintar].
  Future<void> preparar();

  /// Pinta un fotograma. [segundos] es el reloj de la animación; [nueva], la
  /// pieza que está apareciendo, y [aparicion], cuánto le falta (0 a 1).
  void pintar(
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    E escena, {
    required double segundos,
    int? nueva,
    double aparicion = 1,
  });

  /// Lo que el laboratorio enseña junto al nombre, si algo no ha ido bien
  /// (por ejemplo, «sin shader»).
  String? get aviso => null;

  void liberar() {}
}

/// Los tres niveles de zoom (`encargos/focus-mundos.md` §3).
enum NivelZoom { hoy, cerca, todo }

/// Dónde se pone la cámara en cada nivel, para cualquier mundo.
abstract final class VistasMundo {
  /// Lo más lejos y lo más cerca que se deja ir con los dedos.
  static const double escalaMinima = 0.02;
  static const double escalaMaxima = 4;

  static VistaMundo de(NivelZoom nivel, EscenaMundo escena, Size tamano) =>
      switch (nivel) {
        NivelZoom.hoy => hoy(escena, tamano),
        NivelZoom.cerca => cerca(escena, tamano),
        NivelZoom.todo => todo(escena, tamano),
      };

  /// La región de hoy, grande.
  static VistaMundo hoy(EscenaMundo escena, Size tamano) => VistaMundo(
    centro: escena.centroRegion(escena.deLaUltima),
    escala: _lado(tamano) / (escena.ladoRegion * 2.36),
  );

  /// La de hoy y unas cuantas alrededor.
  static VistaMundo cerca(EscenaMundo escena, Size tamano) => VistaMundo(
    centro: escena.centroRegion(escena.deLaUltima) * 0.85,
    escala: _lado(tamano) / (escena.ladoRegion * 9.3),
  );

  /// Todo lo que hay, con el centro del mundo en el centro.
  static VistaMundo todo(EscenaMundo escena, Size tamano) => VistaMundo(
    centro: Offset.zero,
    escala: _lado(tamano) / (2 * (escena.radio + 120)),
  );

  static double _lado(Size t) => math.min(t.width, t.height);
}

/// Un mundo tal como lo enseña el laboratorio: su nombre, cómo se monta su
/// escena y sus formas de dibujarlo. Junta cada escena con sus pintores, que
/// son del mismo tipo.
class MundoDeLaboratorio<E extends EscenaMundo> {
  MundoDeLaboratorio({
    required this.nombre,
    required this.crearEscena,
    required this.pintores,
  });

  final String nombre;
  final E Function(int semilla, int cantidad) crearEscena;
  final List<PintorMundo<E>> pintores;

  Future<void> preparar() async {
    for (final p in pintores) {
      await p.preparar();
    }
  }

  void liberar() {
    for (final p in pintores) {
      p.liberar();
    }
  }

  void pintar(
    int pintor,
    Canvas canvas,
    Size tamano,
    VistaMundo vista,
    EscenaMundo escena, {
    required double segundos,
    int? nueva,
    double aparicion = 1,
  }) => pintores[pintor].pintar(
    canvas,
    tamano,
    vista,
    escena as E,
    segundos: segundos,
    nueva: nueva,
    aparicion: aparicion,
  );
}
