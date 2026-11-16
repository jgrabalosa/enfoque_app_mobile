import '../ciudad/colocador_ciudad.dart';
import '../ciudad/escena_ciudad.dart';
import '../ciudad/pintor_ciudad.dart';
import '../ciudad/pintor_ciudad_prueba.dart';
import '../escena_mundo.dart';
import '../galaxia/colocador_galaxia.dart';
import '../galaxia/escena_galaxia.dart';
import '../galaxia/pintor_codigo.dart';
import '../galaxia/pintor_prueba.dart';

/// Los mundos que enseña el laboratorio, cada uno con sus pintores. El
/// primero es el que se ve al entrar.
List<MundoDeLaboratorio> mundosDelLaboratorio() => [
  MundoDeLaboratorio<EscenaGalaxia>(
    nombre: 'Profundidad',
    crearEscena: (semilla, cantidad) =>
        EscenaGalaxia(ColocadorGalaxia(semilla), cantidad),
    pintores: [PintorCodigo(), PintorPrueba()],
  ),
  MundoDeLaboratorio<EscenaCiudad>(
    nombre: 'Neotokyo+',
    crearEscena: (semilla, cantidad) =>
        EscenaCiudad(ColocadorCiudad(semilla), cantidad),
    pintores: [PintorCiudadCodigo(), PintorCiudadPrueba()],
  ),
];
