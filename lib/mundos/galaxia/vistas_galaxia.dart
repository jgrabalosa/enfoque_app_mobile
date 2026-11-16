import 'dart:math' as math;
import 'dart:ui';

import '../vista_mundo.dart';
import 'escena_galaxia.dart';

/// Los tres niveles de zoom (`encargos/focus-mundos.md` §3).
enum NivelZoom { hoy, cerca, todo }

/// Dónde se pone la cámara en cada nivel.
abstract final class VistasGalaxia {
  /// Lo más cerca y lo más lejos que se deja ir con los dedos.
  static const double escalaMinima = 0.02;
  static const double escalaMaxima = 4;

  static VistaMundo de(NivelZoom nivel, EscenaGalaxia escena, Size tamano) =>
      switch (nivel) {
        NivelZoom.hoy => hoy(escena, tamano),
        NivelZoom.cerca => cerca(escena, tamano),
        NivelZoom.todo => todo(escena, tamano),
      };

  /// La constelación de hoy, grande. Sin estrellas, el sitio de la primera.
  static VistaMundo hoy(EscenaGalaxia escena, Size tamano) => VistaMundo(
    centro: escena.colocador.constelacion(escena.deLaUltima).centro,
    escala: _lado(tamano) / 330,
  );

  /// La de hoy y unas cuantas alrededor.
  static VistaMundo cerca(EscenaGalaxia escena, Size tamano) => VistaMundo(
    centro: escena.colocador.constelacion(escena.deLaUltima).centro * 0.85,
    escala: _lado(tamano) / 1300,
  );

  /// Todo lo que hay, con el núcleo en el centro.
  static VistaMundo todo(EscenaGalaxia escena, Size tamano) => VistaMundo(
    centro: Offset.zero,
    escala: _lado(tamano) / (2 * (escena.radio + 120)),
  );

  static double _lado(Size t) => math.min(t.width, t.height);
}
