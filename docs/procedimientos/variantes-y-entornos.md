# Variantes y entornos

_Sacado del `CLAUDE.md` el 24-nov-2026 para que no pase de 200 líneas (D-38 del proyecto: lo que sale va a `docs/`). El `CLAUDE.md` dice cuándo leer este fichero._

## Variantes: produccion y prueba

- **`--flavor` siempre.** `produccion` es `com.norday.enfoque`, «Norday
  Focus». `prueba` es `com.norday.enfoque.prueba`, «Norday Focus PRUEBA», y va
  contra staging con
  `--dart-define=NORDAY_API_URL=https://staging-api.norday.app/api`.
- **`lib/entorno.dart` para la app al arrancar** si el flavor y la URL no
  cuadran. No se quita ni se salta.
- **La de prueba se ve: cinta «PRUEBA»** arriba a la derecha en todas las
  pantallas, también en el login (`conCintaDeEntorno` de `lib/entorno.dart`,
  en el `builder` del `MaterialApp`, con el flavor de `ServiciosEnfoque`).
  Sin cinta, es la de producción. Se puso el 16-nov-2026: con varias apps de
  prueba y de Play instaladas, Quim entró con una cuenta sin saber si era
  staging o producción.
- **La de prueba nunca abre Google Play.** Si falta Norday PRUEBA, «Crea
  hábitos en Norday Habits» avisa (`AperturaHabits.faltaPrueba`) en vez de ir
  a la ficha de Play, que lleva a la Habits de producción sin que se note el
  cambio de entorno.
- **El nombre visible sale de `manifestPlaceholders["appLabel"]`** en
  `android/app/build.gradle.kts`, no del manifest.
- **`google-services.json` tiene que llevar las dos apps**, en el mismo
  proyecto de Firebase que Habits. No se versiona (`android/.gitignore`). El
  que hay en la máquina de Quim es del 15-nov-2026 por la noche y lleva
  las dos apps de Focus con sus clientes OAuth (README, puntos 2 y 3). Si
  cambian las huellas o los clientes, volver a bajarlo.
