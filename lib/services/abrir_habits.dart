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

/// La ficha de Habits en la app de Google Play. Siempre la de Play: la de
/// prueba no tiene ficha.
final Uri fichaPlayHabits = Uri.parse('market://details?id=$paqueteHabits');

/// La misma ficha en la web, si no hay app de Google Play.
final Uri fichaWebHabits = Uri.parse(
  'https://play.google.com/store/apps/details?id=$paqueteHabits',
);

/// Qué se acabó abriendo.
enum AperturaHabits { app, fichaPlay, fichaWeb, nada }

/// Abre Norday Habits; si no está, su ficha de Google Play, y si tampoco hay
/// Google Play, la ficha en la web. Para en lo primero que se abra.
Future<AperturaHabits> abrirHabits({
  required String? flavor,
  required Lanzador lanzador,
}) async {
  if (await lanzador.abrir(paquete: paqueteHabitsDe(flavor))) {
    return AperturaHabits.app;
  }
  if (await lanzador.abrir(enlace: fichaPlayHabits)) {
    return AperturaHabits.fichaPlay;
  }
  if (await lanzador.abrir(enlace: fichaWebHabits)) {
    return AperturaHabits.fichaWeb;
  }
  return AperturaHabits.nada;
}
