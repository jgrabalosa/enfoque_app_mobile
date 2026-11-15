import '../models/enfoque.dart';
import 'app_localizations.dart';

/// El nombre de un destino, o «Hábito» si el backend no mandó ninguno.
String nombreDestino(AppLocalizations l, DestinoDisponible d) =>
    d.nombre.trim().isEmpty ? l.filaSesionHabito : d.nombre;

/// Un destino con su progreso de hoy: «Leer · 20 / 30 min».
String textoDestino(AppLocalizations l, DestinoDisponible d) =>
    l.destinoProgreso(nombreDestino(l, d), d.minutosDia, d.minutosObjetivo);
