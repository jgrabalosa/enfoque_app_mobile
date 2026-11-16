import 'package:flutter/widgets.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

import 'app_localizations.dart';

/// Los códigos de los logros propios de Norday Focus. Son los que siembra el
/// backend con `origen_app = enfoque` (`LogrosEnfoqueInitializer`, V27): si
/// cambia uno allí, cambia aquí.
const List<String> codigosLogrosEnfoque = [
  'ENFOQUE_PRIMERA_SESION',
  'ENFOQUE_DIA',
  'ENFOQUE_CON_DESTINO',
  'ENFOQUE_DIAS_3',
  'ENFOQUE_DIAS_7',
  'ENFOQUE_DIAS_30',
  'ENFOQUE_DIAS_100',
  'ENFOQUE_RACHA_3',
  'ENFOQUE_RACHA_7',
  'ENFOQUE_RACHA_30',
  'ENFOQUE_HORAS_5',
  'ENFOQUE_HORAS_25',
  'ENFOQUE_HORAS_100',
  'ENFOQUE_HORAS_500',
  'ENFOQUE_SESION_60',
  'ENFOQUE_SESION_120',
  'ENFOQUE_CUATRO',
  'ENFOQUE_SIN_RENDIRSE',
  'ENFOQUE_TOPE',
  'ENFOQUE_MANANA',
  'ENFOQUE_NOCHE',
];

/// Le da al core los nombres y las descripciones de los logros de Focus, para
/// la pantalla de logros y las celebraciones (16-nov-2026). Sin esto, el core
/// enseñaría el nombre que manda el backend, en español.
///
/// Se llama en `main()`, antes de `runApp`, junto a `registrarTextosEnfoque`.
void registrarLogrosEnfoque() {
  CatalogosCore.registrarLogrosDeDominio(
    nombres: nombresLogrosEnfoque,
    descripciones: descripcionesLogrosEnfoque,
  );
}

Map<String, String> nombresLogrosEnfoque(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return {
    'ENFOQUE_PRIMERA_SESION': l.logroPrimeraSesion,
    'ENFOQUE_DIA': l.logroDia,
    'ENFOQUE_CON_DESTINO': l.logroConDestino,
    'ENFOQUE_DIAS_3': l.logroDias3,
    'ENFOQUE_DIAS_7': l.logroDias7,
    'ENFOQUE_DIAS_30': l.logroDias30,
    'ENFOQUE_DIAS_100': l.logroDias100,
    'ENFOQUE_RACHA_3': l.logroRacha3,
    'ENFOQUE_RACHA_7': l.logroRacha7,
    'ENFOQUE_RACHA_30': l.logroRacha30,
    'ENFOQUE_HORAS_5': l.logroHoras5,
    'ENFOQUE_HORAS_25': l.logroHoras25,
    'ENFOQUE_HORAS_100': l.logroHoras100,
    'ENFOQUE_HORAS_500': l.logroHoras500,
    'ENFOQUE_SESION_60': l.logroSesion60,
    'ENFOQUE_SESION_120': l.logroSesion120,
    'ENFOQUE_CUATRO': l.logroCuatro,
    'ENFOQUE_SIN_RENDIRSE': l.logroSinRendirse,
    'ENFOQUE_TOPE': l.logroTope,
    'ENFOQUE_MANANA': l.logroManana,
    'ENFOQUE_NOCHE': l.logroNoche,
  };
}

Map<String, String> descripcionesLogrosEnfoque(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return {
    'ENFOQUE_PRIMERA_SESION': l.logroPrimeraSesionDesc,
    'ENFOQUE_DIA': l.logroDiaDesc,
    'ENFOQUE_CON_DESTINO': l.logroConDestinoDesc,
    'ENFOQUE_DIAS_3': l.logroDias3Desc,
    'ENFOQUE_DIAS_7': l.logroDias7Desc,
    'ENFOQUE_DIAS_30': l.logroDias30Desc,
    'ENFOQUE_DIAS_100': l.logroDias100Desc,
    'ENFOQUE_RACHA_3': l.logroRacha3Desc,
    'ENFOQUE_RACHA_7': l.logroRacha7Desc,
    'ENFOQUE_RACHA_30': l.logroRacha30Desc,
    'ENFOQUE_HORAS_5': l.logroHoras5Desc,
    'ENFOQUE_HORAS_25': l.logroHoras25Desc,
    'ENFOQUE_HORAS_100': l.logroHoras100Desc,
    'ENFOQUE_HORAS_500': l.logroHoras500Desc,
    'ENFOQUE_SESION_60': l.logroSesion60Desc,
    'ENFOQUE_SESION_120': l.logroSesion120Desc,
    'ENFOQUE_CUATRO': l.logroCuatroDesc,
    'ENFOQUE_SIN_RENDIRSE': l.logroSinRendirseDesc,
    'ENFOQUE_TOPE': l.logroTopeDesc,
    'ENFOQUE_MANANA': l.logroMananaDesc,
    'ENFOQUE_NOCHE': l.logroNocheDesc,
  };
}
