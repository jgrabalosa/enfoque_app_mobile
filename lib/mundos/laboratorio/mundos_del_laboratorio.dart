import '../ciudad/ciudad_isometrica.dart';
import '../ciudad/colocador_ciudad.dart';
import '../ciudad/escena_ciudad.dart';
import '../escena_mundo.dart';
import '../galaxia/colocador_galaxia.dart';
import '../galaxia/escena_galaxia.dart';
import '../galaxia/pintor_codigo.dart';
import '../galaxia/pintor_prueba.dart';
import '../jardin/colocador_jardin.dart';
import '../jardin/escena_jardin.dart';
import '../jardin/jardin_isometrico.dart';

/// Los mundos que enseña el laboratorio, cada uno con sus pintores. El
/// primero es el que se ve al entrar.
///
/// Solo los elegidos (Quim, 18-nov): la galaxia, Neotokyo+ 3D y Dulce 3D.
/// Las versiones planas de la ciudad y del jardín salen del laboratorio; su
/// código se queda porque las 3D se apoyan en él (`PintorCiudadBlender`
/// hereda de `PintorCiudadCodigo`, y el jardín usa las especies de
/// `flores.dart`).
List<MundoDeLaboratorio> mundosDelLaboratorio() => [
  MundoDeLaboratorio<EscenaGalaxia>(
    nombre: 'Profundidad',
    crearEscena: (semilla, cantidad) =>
        EscenaGalaxia(ColocadorGalaxia(semilla), cantidad),
    pintores: [PintorCodigo(), PintorPrueba()],
  ),
  // La misma ciudad en isométrico, con los edificios renderizados en
  // Blender (`encargos/focus-mundos.md` §11).
  MundoDeLaboratorio<EscenaCiudad>(
    nombre: 'Neotokyo+ 3D',
    crearEscena: (semilla, cantidad) =>
        EscenaCiudadIso(ColocadorCiudad(semilla), cantidad),
    pintores: [PintorCiudadBlender()],
  ),
  // El jardín de Dulce en 3D a lápiz, como Neotokyo+ 3D (decisión 18).
  MundoDeLaboratorio<EscenaJardin>(
    nombre: 'Dulce 3D',
    crearEscena: (semilla, cantidad) =>
        EscenaJardinIso(ColocadorJardin(semilla), cantidad),
    pintores: [PintorJardin3D()],
  ),
];
