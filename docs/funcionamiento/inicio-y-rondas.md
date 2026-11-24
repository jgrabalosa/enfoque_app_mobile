# Inicio, rondas y descanso

_Sacado del `CLAUDE.md` el 24-nov-2026 para que no pase de 200 líneas (D-38 del proyecto: lo que sale va a `docs/`). El `CLAUDE.md` dice cuándo leer este fichero._

## Inicio de un solo gesto (17-nov-2026)

Diseño de Focus con Quim (`encargos/focus-diseno.md` del proyecto).

- **El aro de la sesión, ya en Inicio**: el mismo `AroCuentaAtras` (260) con
  Nori (96) que la sesión, lleno y con los minutos de la técnica. Al
  empezar no cambia de sitio.
- **Tres técnicas** (`Tecnica` en `inicio_logica.dart`): Pomodoro (25),
  Profundo (50) y Libre (de 10 a 120, con el selector). La primera vez,
  Pomodoro. Se recuerdan la técnica, las rondas y los minutos de Libre.
- **El destino, en una línea bajo Empezar** («Para: Sin hábito»), que abre
  la lista en una hoja. El enlace desde Habits sigue eligiendo el hábito.
- **Sin las cifras de hoy** (tiempo, sesiones y racha): están en
  Estadísticas.

## Rondas y descanso (17-nov-2026)

- **Pomodoro y Profundo van por rondas**, de 1 a 4, con descanso entre una
  y otra (5 y 10 minutos; después de la última, ninguno). Libre, siempre
  una. Bajo el aro, con más de una ronda: «2 × 25 min, con 5 min de
  descanso · 55 min».
- **Cada ronda es una sesión normal del motor**, con su premio: el core no
  sabe nada de rondas. La ronda va en `datosApp` (`{"ronda": {n, de}}`,
  `rondaDeDatos`), y la sesión y el resultado enseñan «Ronda 1 de 2».
- **`ControladorTanda`** (`services/tanda.dart`) lleva la tanda y la guarda
  en `enfoque_tanda`. Al acabar una ronda, `HomeShell` le pregunta
  (`alAcabar`): si se completó y no era la última, `DescansoScreen`; si no
  (terminada, perdida, rendida o la última), el resultado de siempre y la
  tanda se acaba.
- **El descanso no empieza sola la ronda siguiente**: en el descanso se
  puede salir de la app, y una sesión que empieza con la app fuera se
  perdería en el acto. Avisa (canal `enfoque_descanso`, id fijo 7103,
  `AvisosDescansoLocales`) y la empieza el usuario. Se puede empezar antes
  de que acabe. «Terminar aquí» (y Atrás) dejan la tanda: lo hecho ya
  cuenta.
- **Si se mata la app en el descanso**, al volver `HomeShell` lo abre otra
  vez (sin las líneas del premio, que ya no están). Una tanda que no está en
  descanso y no tiene sesión activa se deja (`limpiarSiHuerfana`).
- **La hora del descanso es la de pared** (`DateTime.now`), no la del reloj
  monótono: es un descanso, no hay nada que proteger.
