import 'package:norday_flutter_core/norday_flutter_core.dart';

import 'app_localizations.dart';

/// Le da al core los textos que dependen de qué app es: el nombre, el lema
/// del login, la explicación de la actualización obligatoria y lo que se
/// pierde al borrar la cuenta. Sin esto, el core dice «Norday» y frases
/// neutras.
///
/// Se llama en `main()`, antes de `runApp`, igual que se fija
/// `ApiServiceCore.appId`.
void registrarTextosEnfoque() {
  TextosApp.registrar(
    nombre: (c) => AppLocalizations.of(c)!.appNombre,
    lemaLogin: (c) => AppLocalizations.of(c)!.loginLema,
    actualizacionObligatoria: (c) =>
        AppLocalizations.of(c)!.actualizacionObligatoriaTexto,
    eliminarCuenta: (c) => AppLocalizations.of(c)!.eliminarCuentaCuerpo,
  );
}
