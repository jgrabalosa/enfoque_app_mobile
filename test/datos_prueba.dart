import 'package:enfoque_app_mobile/models/enfoque.dart';

const DestinoDisponible destinoLeer = DestinoDisponible(
  tipo: 'habito',
  id: 16,
  nombre: 'Leer',
  minutosDia: 20,
  minutosObjetivo: 30,
);

PeticionSesion peticionDePrueba({
  String clave = '3f2a8c1e-5b7d-4e9a-8c6f-1a2b3c4d5e6f',
  EstadoEnvio estado = EstadoEnvio.completada,
  int duracionSeg = 1500,
  bool conDestino = true,
}) => PeticionSesion(
  clave: clave,
  inicioUtc: DateTime.utc(2026, 11, 16, 8, 30),
  duracionSeg: duracionSeg,
  duracionObjetivoMin: 25,
  estado: estado,
  destinoTipo: conDestino ? 'habito' : null,
  destinoId: conDestino ? 16 : null,
);
