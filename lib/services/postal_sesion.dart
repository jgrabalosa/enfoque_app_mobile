import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../l10n/formatos.dart';
import '../widgets/tarjeta_sesion.dart';

/// La ficha de Norday Focus en Google Play. Igual desde la app de prueba: es
/// solo texto, no abre nada.
const String enlaceFichaFocus =
    'https://play.google.com/store/apps/details?id=com.norday.enfoque';

/// Abre el menú de compartir del móvil con [texto] y la postal [png].
/// Devuelve `false` si la persona lo cancela.
typedef MenuCompartir =
    Future<bool> Function(String texto, String asunto, Uint8List png);

/// Mide [evento] con [parametros].
typedef MedirEvento =
    Future<void> Function(String evento, Map<String, Object> parametros);

Future<bool> _menuDelMovil(String texto, String asunto, Uint8List png) async {
  final r = await SharePlus.instance.share(
    ShareParams(
      text: texto,
      subject: asunto,
      files: [XFile.fromData(png, mimeType: 'image/png', name: 'focus.png')],
    ),
  );
  return r.status != ShareResultStatus.dismissed;
}

Future<void> _medirConAnalytics(
  String evento,
  Map<String, Object> parametros,
) => AnalyticsCore.analytics.logEvent(name: evento, parameters: parametros);

/// Comparte la postal de una sesión que cuenta («Compartir» del resultado),
/// como «Compartir mi Nori» en Habits (T-086). Los seams ([menu], [medir]) son
/// los de los tests.
class PostalSesion {
  const PostalSesion({
    this.menu = _menuDelMovil,
    this.medir = _medirConAnalytics,
    this.espera = const Duration(milliseconds: 400),
  });

  final MenuCompartir menu;
  final MedirEvento medir;

  /// Lo que se deja a Nori para cargar antes de capturar.
  final Duration espera;

  /// El texto del menú: la frase y, debajo, el enlace de la ficha de Play.
  static String texto(AppLocalizations l, int minutos) =>
      '${l.postalSesionTexto(duracionLegible(l, minutos))}\n$enlaceFichaFocus';

  /// Pinta la tarjeta fuera de pantalla, la captura a 1080 × 1350 y abre el
  /// menú. Mide `sesion_compartida` (identidad y minutos) solo si no se
  /// cancela. Si algo falla, no lanza: devuelve `false`.
  Future<bool> compartir(
    BuildContext context, {
    required int minutos,
    int? rondas,
    String? fase,
    String? estado,
  }) async {
    OverlayEntry? entrada;
    try {
      final l = AppLocalizations.of(context)!;
      final overlay = Overlay.of(context, rootOverlay: true);
      final identidad = identidadEquipadaNotifier.value.codigo;
      final llave = GlobalKey();
      entrada = OverlayEntry(
        builder: (_) => Positioned(
          // Fuera de pantalla, pero pintada.
          left: -TarjetaSesion.ancho * 2,
          top: 0,
          width: TarjetaSesion.ancho,
          height: TarjetaSesion.alto,
          child: IgnorePointer(
            child: RepaintBoundary(
              key: llave,
              child: TarjetaSesion(
                minutos: minutos,
                rondas: rondas,
                fase: fase,
                estado: estado,
              ),
            ),
          ),
        ),
      );
      overlay.insert(entrada);
      await WidgetsBinding.instance.endOfFrame;
      if (espera > Duration.zero) await Future<void>.delayed(espera);
      await WidgetsBinding.instance.endOfFrame;

      final caja =
          llave.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (caja == null) return false;
      final imagen = await caja.toImage();
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
      imagen.dispose();
      if (datos == null) return false;
      final png = datos.buffer.asUint8List();

      entrada.remove();
      entrada.dispose();
      entrada = null;

      final compartido = await menu(
        texto(l, minutos),
        l.postalSesionAsunto,
        png,
      );
      if (!compartido) return false;
      try {
        await medir('sesion_compartida', {
          'identidad': identidad,
          'minutos': minutos,
        });
      } catch (_) {
        // Medir no puede romper compartir.
      }
      return true;
    } catch (e) {
      debugPrint('postal_sesion: $e');
      return false;
    } finally {
      if (entrada != null) {
        entrada.remove();
        entrada.dispose();
      }
    }
  }
}
