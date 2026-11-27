# La sesión, la cola de envíos y el reloj

_Sacado del `CLAUDE.md` el 24-nov-2026 para que no pase de 200 líneas (D-38 del proyecto: lo que sale va a `docs/`). El `CLAUDE.md` dice cuándo leer este fichero._

## La sesión, de principio a fin

1. Inicio → `ControladorEnfoque.empezar(duracion, destino)` →
   `MotorSesion.empezar`. `HomeShell` ve la sesión activa y pone encima
   `SesionScreen`.
2. El motor hace el resto: ciclo de vida, gracia, avisos, persistencia y
   recomposición tras matar la app.
3. Cuando la sesión es final, el controlador la recoge:
   - **descartada** (terminar antes de 10 min): no se envía; resultado
     «descartada» y `MotorSesion.cerrar()`.
   - **completada, terminada o perdida**: `peticionDeSesion` monta el
     cuerpo y se mete en la cola con su dueño (el `usuarioId` de
     `datosApp`). Si `encolar` dice que quedó guardada, se cierra en el
     motor en el acto y el envío va después, sin bloquear. Si no se pudo
     guardar, la sesión se queda en el motor y la recogida se reintenta en
     el siguiente `iniciar()` o `enviarPendientes()` (al volver a primer
     plano).
4. `HomeShell` ve el resultado nuevo y sustituye la sesión por
   `ResultadoScreen`, que se actualiza cuando llega la respuesta.

`MotorSesion.iniciar()` se llama en `main()`, antes de `runApp`: el motor
recompone y vigila la sesión aunque la app abra en el login. La recogida
(`ControladorEnfoque.iniciar()`) la hace cada `HomeShell` al montarse.

**Otra cuenta, o ninguna, al acabar**: la sesión se encola con su dueño
igualmente y la cola solo la envía cuando ese usuario vuelva a estar
conectado. Solo una sesión sin dueño guardado (anterior a guardarlo) y sin
nadie conectado se queda en el motor hasta el siguiente login.

### La cola y el contrato de reintento

El contrato es el de `EnfoqueController` del backend:

- **201/200** → enviada; sale de la cola. Un 2xx con un cuerpo que no se
  entiende también cuenta como enviada (reintentar daría el mismo 200).
- **400 y 409** → definitivos: salen de la cola y quedan en
  `noAceptados` (historial local, los 50 últimos) con el `mensaje` del
  backend. No se reintentan nunca.
- **5xx, sin red, timeout, 401, 404, 429…** → se quedan. Reintento
  automático con espera de 30 s × 2^(intentos − 1), hasta 30 min, y además
  en cuanto se fuerza: al arrancar y al volver a primer plano.
- **Siempre el mismo cuerpo con la misma clave**: se guarda la petición al
  encolar y se reenvía tal cual. El backend devuelve el resultado original
  sin sumar ni pagar dos veces.
- Cada entrada lleva su `usuarioId` y **solo se envía con la sesión de ese
  usuario abierta**, comprobado antes de cada envío (también a mitad de
  pasada): si en el mismo móvil entra otra cuenta, no se mandan sesiones
  ajenas con su token.
- **`encolar` devuelve si quedó guardada** (el `bool` de `setString`; si
  escribir lanza, relanza) y deshace la entrada en memoria si no. Si leer la
  cola falla, no se da por cargada y no se escribe nada: el siguiente
  guardado pisaría lo que hubiera. El almacén es inyectable (`AlmacenCola`).
- Una sola pasada a la vez; lo que se pide durante una pasada se hace al
  acabarla.
- **Más de 7 días sin enviar**: al empezar cada pasada, las que empezaron
  hace más de 7 días (de cualquier usuario) salen de la cola y quedan como
  no enviadas por antigüedad (`antigua`, código 0): el backend las
  rechazaría con un 400.

### El reloj del móvil, desfasado

El backend valida el inicio de cada sesión contra su reloj (que no acabe
más de 2 minutos en el futuro, que no empezara hace más de 7 días, que no se
solape) y saca de él el día. Un móvil que va mal de hora daría 400 o el día
equivocado. Por eso (decisión de la revisión del 15-nov-2026):

- `ApiServiceEnfoque` apunta en `DesfaseServidor` la cabecera `Date` de cada
  respuesta del backend: desfase = servidor − móvil, guardado en
  `enfoque_desfase_servidor_ms`.
- El controlador corrige `inicioUtc` **una sola vez, al encolar**, con el
  desfase conocido entonces. Después el cuerpo no cambia nunca: la misma
  clave con otro cuerpo daría 409. Sin desfase conocido, la hora del móvil.
- `Date` va en segundos y llega con la latencia: ±1 s de ruido. Una medida
  solo sustituye a la guardada si se aparta más de 5 s (histéresis), y
  desfases de menos de 5 s no se corrigen. Si no, dos sesiones seguidas
  corregidas con medidas distintas podrían solaparse un segundo (409).
- La duración no se toca: sale del reloj monótono.
- **Límite**: si el desfase cambia de verdad entre dos sesiones seguidas
  (alguien cambia la hora del móvil), esas dos pueden solaparse.

Claves en `SharedPreferences` (ocho `enfoque_*`): `enfoque_cola_envios`,
`enfoque_envios_no_aceptados`, `enfoque_desfase_servidor_ms`, en Inicio
`enfoque_tecnica`, `enfoque_minutos_libre` y `enfoque_rondas` (la última
elección), `enfoque_tanda` (la tanda de rondas en marcha) y
`enfoque_permiso_avisos_pedido`. `enfoque_gracia`, `enfoque_fin`,
`enfoque_descanso` y `enfoque_en_curso` no son claves: son canales de
avisos.

Mientras la sesión está activa hay una notificación fija (servicio en
primer plano) que mueve `ControladorEnfoque.vigilarEnCurso()`: ver
`parte-nativa-y-avisos.md`. La sesión en curso
la guarda el core en `sesion_concentracion_actual`.
