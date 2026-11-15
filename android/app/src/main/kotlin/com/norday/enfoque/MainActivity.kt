package com.norday.enfoque

import android.app.KeyguardManager
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * La parte nativa de Norday Focus: todo pasa por un solo canal,
 * com.norday.enfoque/sistema (lib/services/canal_sistema.dart).
 *
 * De Dart a Android:
 * - "monotonicoMs": el reloj monótono de la sesión.
 * - "encendidaYDesbloqueada": si salir de la app cuenta como salir.
 * - "abrir": abre un enlace o una app (Norday Habits, su ficha de Play).
 * - "enlaceInicial": el enlace norday-enfoque:// con que se abrió la app, una
 *   sola vez.
 *
 * De Android a Dart:
 * - "desbloqueo": el usuario acaba de desbloquear (ACTION_USER_PRESENT).
 * - "enlace": ha llegado un enlace con la app ya abierta (onNewIntent).
 */
class MainActivity : FlutterActivity() {
    private var canal: MethodChannel? = null

    /** El enlace de arranque, hasta que Dart lo pide con "enlaceInicial". */
    private var enlacePendiente: String? = null

    /**
     * Avisa a Dart de cada desbloqueo, para MotorSesion.avisarDesbloqueo():
     * bloquear con la sesión delante, desbloquear y abrir otra app puede no
     * pasar nunca por resumed.
     * https://developer.android.com/reference/android/content/Intent#ACTION_USER_PRESENT
     *
     * Se registra aquí, en tiempo de ejecución, y no en el manifest: «apps
     * that target the API level 26 or higher can't register broadcast
     * receivers for implicit broadcasts in their manifest unless the
     * broadcast is sent specifically to them», y ACTION_USER_PRESENT no está
     * entre las excepciones
     * (https://developer.android.com/develop/background-work/background-tasks/broadcasts/broadcast-exceptions).
     */
    private val receptorDesbloqueo = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_USER_PRESENT) {
                canal?.invokeMethod(METODO_DESBLOQUEO, null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Solo en un arranque nuevo: al recrear la actividad (girar, cambiar
        // de idioma) el intent es el mismo y el enlace ya se leyó. Y no si se
        // abre desde Recientes: el sistema relanza con el intent original
        // (el enlace de entonces) y pone FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY,
        // que «is not normally set by application code, but set for you by
        // the system if this activity is being launched from history»
        // (https://developer.android.com/reference/android/content/Intent#FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY).
        // Volver a elegir aquel destino no es lo que el usuario ha pedido.
        val desdeRecientes =
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        if (savedInstanceState == null && !desdeRecientes) {
            enlacePendiente = enlaceDe(intent)
        }
        registrarReceptorDesbloqueo()
    }

    /**
     * Con la actividad registrada, el receptor recibe «as long as the
     * activity remains active», también con la app detrás, que es justo
     * cuando hace falta. Se suelta en onDestroy: «Make sure to unregister in
     * onDestroy()»
     * (https://developer.android.com/develop/background-work/background-tasks/broadcasts).
     *
     * RECEIVER_EXPORTED (Android 13+; desde Android 14 hay que indicar uno
     * u otro). La misma página: «Some system broadcasts come from highly
     * privileged apps, such as Bluetooth and telephony, that are part of the
     * Android framework but don't run under the system's unique process ID
     * (UID). To receive all system broadcasts, including broadcasts from
     * highly privileged apps, flag your receiver with RECEIVER_EXPORTED.» y
     * «If you flag your receiver with RECEIVER_NOT_EXPORTED, the receiver is
     * able to receive some system broadcasts and broadcasts from your app,
     * but not broadcasts from the highly privileged apps.» ACTION_USER_PRESENT
     * lo manda la pantalla de bloqueo, así que se exporta. Es un broadcast
     * protegido: otra app no puede enviarlo, y un aviso de más solo provoca
     * una consulta de pantalla de más.
     * https://developer.android.com/reference/android/content/Context#registerReceiver(android.content.BroadcastReceiver,%20android.content.IntentFilter,%20int)
     *
     * Sin ContextCompat.registerReceiver: androidx.core no es dependencia
     * directa de la app (flutter_local_notifications la trae como
     * `implementation`, que no llega al classpath de la app), así que no está
     * garantizado. Se usa el registerReceiver del framework con su versión.
     */
    private fun registrarReceptorDesbloqueo() {
        val filtro = IntentFilter(Intent.ACTION_USER_PRESENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receptorDesbloqueo, filtro, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receptorDesbloqueo, filtro)
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(receptorDesbloqueo)
        } catch (e: IllegalArgumentException) {
            // No estaba registrado: nada que soltar.
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        canal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    // Desde el arranque del móvil, contando el sueño profundo
                    // y sin saltar si se cambia la hora: «return the time since
                    // the system was booted, and include deep sleep. This clock
                    // is guaranteed to be monotonic».
                    // https://developer.android.com/reference/android/os/SystemClock#elapsedRealtime()
                    METODO_MONOTONICO -> result.success(SystemClock.elapsedRealtime())
                    METODO_PANTALLA -> result.success(encendidaYDesbloqueada())
                    METODO_ABRIR -> result.success(
                        abrir(call.argument<String>("enlace"), call.argument<String>("paquete"))
                    )
                    METODO_ENLACE_INICIAL -> {
                        result.success(enlacePendiente)
                        enlacePendiente = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        canal?.setMethodCallHandler(null)
        canal = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /**
     * Un enlace con la app abierta. Con launchMode singleTop la actividad que
     * ya está arriba recibe el intent aquí en vez de crearse otra:
     * https://developer.android.com/reference/android/app/Activity#onNewIntent(android.content.Intent)
     * («getIntent() still returns the original Intent. You can use
     * setIntent(Intent) to update it to this new Intent»).
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val enlace = enlaceDe(intent) ?: return
        val c = canal
        if (c == null) {
            enlacePendiente = enlace
        } else {
            c.invokeMethod(METODO_ENLACE, enlace)
        }
    }

    /** El enlace norday-enfoque:// de [intent], o null si no lo es. */
    private fun enlaceDe(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val datos = intent.data ?: return null
        return if (datos.scheme == ESQUEMA) datos.toString() else null
    }

    /**
     * Pantalla encendida y sin el bloqueo delante.
     *
     * - isInteractive: falso cuando el dispositivo «is dozing or asleep»
     *   (pantalla apagada).
     *   https://developer.android.com/reference/android/os/PowerManager#isInteractive()
     * - isKeyguardLocked: cierto mientras se ve la pantalla de bloqueo.
     *   https://developer.android.com/reference/android/app/KeyguardManager#isKeyguardLocked()
     */
    private fun encendidaYDesbloqueada(): Boolean {
        val energia = getSystemService(Context.POWER_SERVICE) as PowerManager
        val bloqueo = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return energia.isInteractive && !bloqueo.isKeyguardLocked
    }

    /**
     * Con [enlace], un Intent ACTION_VIEW (con [paquete], solo para esa app:
     * setPackage). Sin enlace y con [paquete], la actividad de inicio de esa
     * app (getLaunchIntentForPackage, que necesita el paquete en <queries>:
     * https://developer.android.com/training/package-visibility/declaring).
     *
     * Devuelve false si no hay quien lo abra, como recomienda Android: «invoke
     * the intent and handle the ActivityNotFoundException exception if no app
     * is available»
     * (https://developer.android.com/training/package-visibility/use-cases).
     */
    private fun abrir(enlace: String?, paquete: String?): Boolean {
        val intent = when {
            enlace != null -> Intent(Intent.ACTION_VIEW, Uri.parse(enlace)).apply {
                if (paquete != null) setPackage(paquete)
            }
            paquete != null -> packageManager.getLaunchIntentForPackage(paquete) ?: return false
            else -> return false
        }
        // En su propia tarea, no encima de Focus: con FLAG_ACTIVITY_NEW_TASK
        // «The system starts the activity in a new task. If a task is already
        // running for the activity being started, that task is brought to the
        // foreground with its last state restored»
        // (https://developer.android.com/guide/components/activities/tasks-and-back-stack).
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }

    companion object {
        private const val CANAL = "com.norday.enfoque/sistema"
        private const val ESQUEMA = "norday-enfoque"
        private const val METODO_MONOTONICO = "monotonicoMs"
        private const val METODO_PANTALLA = "encendidaYDesbloqueada"
        private const val METODO_ABRIR = "abrir"
        private const val METODO_ENLACE_INICIAL = "enlaceInicial"
        private const val METODO_DESBLOQUEO = "desbloqueo"
        private const val METODO_ENLACE = "enlace"
    }
}
