import 'canal_sistema.dart';

// «Crea hábitos en Norday Habits»: cuando no hay hábitos de minutos a los que
// llevar la sesión, Inicio ofrece abrir Norday Habits o, si no está, su ficha
// de Google Play.
//
// Se intenta abrir y, si no hay quien lo abra, se pasa al siguiente, como
// recomienda Android: «invoke the intent and handle the
// ActivityNotFoundException exception if no app is available»
// (https://developer.android.com/training/package-visibility/use-cases).
// Abrir Habits por su paquete necesita declararlo en `<queries>` del
// AndroidManifest; la ficha de Play, no.

/// El paquete de Norday Habits en Google Play.
const String paqueteHabits = 'com.norday.habitos';

/// El paquete de Habits que corresponde al flavor de esta app: la Focus de
/// prueba abre la Habits de prueba, que va contra el mismo staging; la de
/// Play (o sin flavor) abre la de Play.
String paqueteHabitsDe(String? flavor) =>
    flavor == 'prueba' ? '$paqueteHabits.prueba' : paqueteHabits;

/// La ficha de Habits en la app de Google Play. Sólo desde la Focus de Play:
/// la de prueba no tiene ficha, y la de Play habla con producción.
final Uri fichaPlayHabits = Uri.parse('market://details?id=$paqueteHabits');

/// La misma ficha en la web, si no hay app de Google Play.
final Uri fichaWebHabits = Uri.parse(
  'https://play.google.com/store/apps/details?id=$paqueteHabits',
);

/// Qué se acabó abriendo.
///
/// [faltaPrueba]: nada, desde la Focus de prueba sin la Habits de prueba
/// instalada. No se cae a Google Play: su ficha es la de la Habits de Play,
/// que habla con producción, y desde allí se acababa entrando en la app
/// equivocada (prueba del 16-nov-2026).
enum AperturaHabits { app, fichaPlay, fichaWeb, faltaPrueba, nada }

/// Lo que se enseña con [AperturaHabits.faltaPrueba]. Sólo lo ve quien
/// desarrolla (la Focus de prueba), por eso no se traduce, como
/// `PantallaEntornoIncorrecto`.
const String textoFaltaHabitsPrueba =
    'Instala Habits PRUEBA: la app de prueba no abre Google Play, que lleva '
    'a la de producción.';

/// Abre Norday Habits; si no está, su ficha de Google Play, y si tampoco hay
/// Google Play, la ficha en la web. Para en lo primero que se abra. Con el
/// flavor `prueba` sólo intenta la Habits de prueba: si no está,
/// [AperturaHabits.faltaPrueba].
Future<AperturaHabits> abrirHabits({
  required String? flavor,
  required Lanzador lanzador,
}) async {
  if (await lanzador.abrir(paquete: paqueteHabitsDe(flavor))) {
    return AperturaHabits.app;
  }
  if (flavor == 'prueba') return AperturaHabits.faltaPrueba;
  if (await lanzador.abrir(enlace: fichaPlayHabits)) {
    return AperturaHabits.fichaPlay;
  }
  if (await lanzador.abrir(enlace: fichaWebHabits)) {
    return AperturaHabits.fichaWeb;
  }
  return AperturaHabits.nada;
}
