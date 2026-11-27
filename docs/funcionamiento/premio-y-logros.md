# El premio de la sesión y los logros

_Sacado del `CLAUDE.md` el 24-nov-2026 para que no pase de 200 líneas (D-38 del proyecto: lo que sale va a `docs/`). El `CLAUDE.md` dice cuándo leer este fichero._

### El premio de la sesión (backend V27, 16-nov-2026)

Cada sesión que cuenta paga lo suyo, tenga hábito o no: 1 moneda por minuto
(+5 si se completa) y 1 XP de Nori por cada 5 minutos, con un tope de 120
monedas y 24 XP al día (`TOPE_MONEDAS_DIA` y `TOPE_XP_DIA`). Si lleva
hábito, el hábito paga además lo suyo. La respuesta los separa: `aporte` (el hábito) y `premio` (la sesión,
`{monedas, xp, logros, topeAlcanzado}`, modelo `Premio`). Un backend anterior
a V27 no lo manda y se queda en `Premio.vacio`.

En pantalla las monedas se llaman **puntos**; en el código y en el backend
siguen siendo `monedas`.

El Resultado enseña «+30 puntos · +5 XP» para cualquier sesión que cuente y
se haya enviado; si con ella se llega al tope, «Has llegado al tope de hoy…»;
si el tope ya estaba, sin cifras, «Hoy ya has ganado todo lo que dan las
sesiones…». Debajo, lo del hábito como siempre. Se celebran los logros de las
dos partes, sin repetir. Las cifras y las reglas las decide el backend
(`ParametrosPremioEnfoque` en `habitos-app`): aquí no se calcula nada.

### El premio de una tanda (T-085)

Al acabar la última ronda de una tanda, el Resultado suma lo que pagaron
las rondas **ya enviadas**: los puntos (los de la sesión y los del hábito)
y la XP de Nori, en una línea («+60 puntos · +10 XP»). Una ronda pendiente
o enviándose no entra en la suma, y se avisa: «Alguna ronda aún no se ha
enviado: sus puntos llegarán al enviarse». Debajo, lo de la última ronda,
como siempre. Los logros se celebran ronda a ronda, como hasta ahora. El
detalle de la cuenta, en `inicio-y-rondas.md`.

### Logros que paga el hábito

El aporte devuelve los logros que desbloqueó el hábito. Focus no registra los
logros de hábitos y el backend tampoco se los da en el catálogo
(`X-Norday-App: enfoque` los filtra), así que celebrarlos aquí enseñaría el
código crudo. `separarLogros` celebra solo los que `CatalogosCore` sabe
nombrar (los genéricos del core, como `MASCOTA_CRIA`, y los de Focus) y de
los demás dice «Tienes N logros nuevos en Norday Habits».
