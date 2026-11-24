# Textos, idioma, zona y duraciones

_Sacado del `CLAUDE.md` el 24-nov-2026 para que no pase de 200 líneas (D-38 del proyecto: lo que sale va a `docs/`). El `CLAUDE.md` dice cuándo leer este fichero._

## Idioma, zona y «hoy»

Idioma y zona son preferencias independientes, en el core
(`IdiomaService`, `ZonaService`), como en Habits.

**Hoy es el día del móvil.** Inicio y Estadísticas piden el resumen con la
fecha local del dispositivo (`DateTime.now()`), porque Dart no da la zona
IANA y el día de cada sesión lo calcula el backend con la zona del usuario.
Si la zona del perfil no es la del móvil, cerca de medianoche «hoy» puede
ser el día de al lado.

## Textos

Ninguna pantalla lleva literales. Dos catálogos y dos clases, como en Habits:

- Lo de enfoque → `lib/l10n/app_*.arb`, con `AppLocalizations.of(context)!`.
  `es` es la plantilla; `pt` es portugués europeo («tu», «ecrã»,
  «telemóvel»).
- Lo genérico → los `core_*.arb` del paquete. Se usan directamente las
  claves del core que ya existen (`tiendaTitulo`, `logrosTitulo`,
  `navColeccion`, `perfilTitulo`, `reintentar`, `sesionAvisoSalir`,
  `sesionAviso*`): ninguna clave está duplicada.

Los `app_localizations*.dart` los genera `flutter gen-l10n` y **no** se
versionan. Los textos que manda el backend (`motivoTexto`, `mensaje`) ya
vienen traducidos al idioma del usuario y se enseñan tal cual.

### Duraciones

Una sola regla para todo lo que enseña minutos al usuario (decisión del
15-nov-2026, la misma que Norday Habits): menos de 60, «{m} min»; desde
60, «{h} h» si no sobran minutos y si no «{h} h {m} min». La aplica
`duracionLegible` (`l10n/formatos.dart`, claves `durMinutos`, `durHoras` y
`durHorasMinutos`). Es de la app, no del core. Se guarda y se envía siempre
en minutos.

- **Pasan por ella**: lo que oye el lector en el aro de Inicio («Sesión de
  25 min»), el progreso del destino (Inicio y sesión), «Llevas…» al terminar, la cifra grande y el
  aporte del Resultado, los totales de semana y mes, la cifra de encima de
  cada barra y lo que oye el lector en ella, y el historial.
- **Pares** (lo hecho y su objetivo): si los dos son de menos de una hora,
  la unidad va una vez al final, como siempre («Leer · 20 / 30 min»,
  «(30 / 30)», «25 de 25 min · Leer»); si alguno llega a la hora, cada
  cifra con la regla («Leer · 45 min / 1 h 30 min», «1 h 30 min de 2 h ·
  Leer»). Lo deciden `progresoLegible`, `textoAporte` y `textoFilaSesion`.
- **No pasan por ella**: los minutos de las técnicas de Inicio («25 min»,
  «50 min»), el selector de Libre, de 10 a 120 (`duracionMinutos`,
  `duracionEtiqueta`), y la cuenta atrás `mm:ss` del core, también la del
  aro de Inicio. Siguen en minutos.
- **Ninguna etiqueta dice «minutos» junto a una cifra que puede ir en
  horas**. Los textos con «minutos» que quedan van con
  cifras fijas («menos de 10 minutos») o sin cifra.
- Donde el sitio es estrecho (los botones de técnica, encima de las barras) el
  texto se encoge con `FittedBox` en vez de cortarse.
