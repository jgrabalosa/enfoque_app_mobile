# Tocar el paquete (norday_flutter_core)

_Sacado del `CLAUDE.md` el 24-nov-2026 para que no pase de 200 líneas (D-38 del proyecto: lo que sale va a `docs/`). El `CLAUDE.md` dice cuándo leer este fichero._

## Tocar el paquete

Un cambio en `norday_flutter_core` no llega solo: se mergea y se tagea
allí, se cambia aquí el `ref:` al tag nuevo y se hace
`flutter pub upgrade norday_flutter_core`. Antes de probar, comprobar el
`resolved-ref` del `pubspec.lock`. Para probar una rama del core sin tag,
`pubspec_overrides.yaml` con `path: ../norday_flutter_core`, que no se
commitea (está en `.gitignore`).

**Core fijado por `v0.62.0`** (24-nov-2026): `resolved-ref`
`e8f8994774c91ae8e28dde574d37b4c04e7c0670`. El `pubspec.lock` se versiona
desde el 15-nov-2026 (entonces, `v0.55.0`; el 21-nov, `v0.59.1`).

Lo que trae la subida de la 0.59.1 a la 0.62.0 (el CHANGELOG del core) y
cómo le toca a Focus:

- **Lo que se ve en Focus:** tu Nori como avatar en Mi cuenta y en
  Colección (T-032); en temporada, Nori del login con la prenda de la
  temporada; en la pantalla de Nori, «Alimentar» y «Tienda» suben debajo de
  Nori y Nori hace su gesto al comer (T-051); la primera vez que se abre la
  tienda, una nota junto al saldo (T-052); la ayuda de la tienda nombra la
  ropa.
- **Lo que está en el core y Focus no usa:** el aviso de versión nueva de
  Play y la «versión recomendada» (`AvisoActualizacion.comprobar`: Focus no
  lo llama); el interruptor «Avisos de Norday» de Perfil (solo con
  `mostrarAvisosApp: true`, que Focus no pasa); los datos del widget de Nori
  (`WidgetNori`, que no escribe nada hasta que la app llame a `iniciar`); el
  check vivo y la figura del día.
- **Dependencia nueva, transitiva:** `home_widget` 0.10.0 (la trae
  `WidgetNori`). Ninguna firma pública que use Focus cambia.
