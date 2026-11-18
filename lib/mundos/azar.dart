/// Un número entre 0 y 1 que solo depende de (semilla, numero, sal): el
/// mismo en todos los móviles y siempre igual, sin `Random`. Es lo que hace
/// que cada pieza de cada mundo caiga siempre en su sitio sin guardarlo.
///
/// SplitMix32.
double azarMundo(int semilla, int numero, int sal) {
  var x =
      (semilla * 0x9E3779B1 + numero * 0x85EBCA77 + sal * 0xC2B2AE3D) &
      0xFFFFFFFF;
  x = ((x ^ (x >> 16)) * 0x85EBCA6B) & 0xFFFFFFFF;
  x = ((x ^ (x >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF;
  x = (x ^ (x >> 16)) & 0xFFFFFFFF;
  return x / 4294967296.0;
}
