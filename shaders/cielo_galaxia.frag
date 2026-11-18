#version 460 core

// El cielo de la galaxia de Profundidad: el fondo, las estrellas lejanas, la
// nebulosa y el polvo de los brazos y el núcleo. Lo pinta la GPU píxel a
// píxel; las estrellas de las piezas van encima, desde Dart
// (pintor_codigo.dart).
//
// Las cuentas van en coordenadas del mundo (las mismas del colocador), así
// que la nebulosa se queda pegada a los brazos al mover y hacer zoom.
//
// Precisión: los móviles calculan con menos decimales que un ordenador. Por
// eso se pide `highp` y el azar nunca trabaja con números grandes (`mod`
// antes de nada); si no, el ruido se rompe en bloques cuadrados.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTamano;      // 0-1: el lienzo, en píxeles lógicos
uniform vec2 uCentro;      // 2-3: el punto del mundo en el centro
uniform float uEscala;     // 4:   píxeles por unidad del mundo
uniform float uSemilla;    // 5:   0..1, de la semilla del usuario
uniform float uRadio;      // 6:   el radio de lo que hay
uniform float uGiro;       // 7:   cuánto se enrollan los brazos
uniform float uGiroInicial;// 8:   el ángulo del primer brazo
uniform float uR0;         // 9:   donde empiezan los brazos

out vec4 fragColor;

float hash(vec2 p) {
  p = mod(p, 289.0);
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float ruido(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * ruido(p);
    p = p * 2.03 + vec2(17.1, 9.2);
    a *= 0.5;
  }
  return v;
}

float fbm3(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 3; i++) {
    v += a * ruido(p);
    p = p * 2.03 + vec2(4.7, 13.9);
    a *= 0.5;
  }
  return v;
}

// Estrellas lejanas: una por celda, con suerte. En pantalla y con un poco de
// paralaje, para que no se amontonen al alejarse.
float lejanas(vec2 s, float celda, float umbral) {
  vec2 c = floor(s / celda);
  float h = hash(c);
  if (h < umbral) return 0.0;
  vec2 pos = (c + vec2(hash(c + 3.1), hash(c + 7.7))) * celda;
  float d = length(s - pos);
  return exp(-d * d * 1.6) * (h - umbral) / (1.0 - umbral);
}

// Cerca de un brazo (1) o lejos (0). [desfase] mueve la espiral un poco.
float brazos(float th, float r, float desfase, float potencia) {
  float m = 0.0;
  for (int b = 0; b < 3; b++) {
    float fase = th - uGiroInicial - float(b) * 2.0943951 - desfase
        - uGiro * log(max(r, 1.0) / uR0);
    m = max(m, pow(0.5 + 0.5 * cos(fase), potencia));
  }
  return m;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 w = (frag - uTamano * 0.5) / uEscala + uCentro;
  float r = length(w);
  float th = atan(w.y, w.x);
  vec2 semilla = vec2(uSemilla * 41.0, uSemilla * 23.0);

  float caida = exp(-pow(r / (uRadio * 1.1 + 200.0), 2.0));
  float enBrazo = brazos(th, r, 0.0, 5.0);

  // La nebulosa, deformada por otro ruido: humo con remolinos, no manchas.
  vec2 q = w / 650.0 + semilla;
  vec2 deform = vec2(fbm3(q * 0.9), fbm3(q * 0.9 + vec2(5.2, 1.3)));
  float n1 = fbm(q + 1.6 * deform);
  float n2 = fbm(q * 2.3 - 1.2 * deform + 7.3);
  float neb = (enBrazo * 0.85 + 0.15) * caida * clamp(n1 * 1.8 - 0.5, 0.0, 1.0);

  vec3 col = vec3(0.027, 0.051, 0.098);                                    // #070D19
  col += neb * vec3(0.30, 0.19, 0.60);                                     // violeta
  col += neb * clamp(n2 * 2.0 - 0.9, 0.0, 1.0) * vec3(0.06, 0.38, 0.48);   // turquesa

  // La luz difusa de las estrellas que no se ven, a lo largo de los brazos.
  col += brazos(th, r, 0.0, 3.0) * caida * vec3(0.10, 0.09, 0.13) * (0.6 + 0.4 * n2);

  // El polvo: una franja oscura por dentro de cada brazo, deshilachada.
  float polvo = brazos(th, r, -0.38, 9.0) * caida;
  polvo *= smoothstep(0.35, 0.75, fbm(q * 3.1 + deform * 2.0 + 2.9));
  col *= 1.0 - 0.55 * polvo * smoothstep(uR0 * 0.5, uR0 * 1.4, r);

  // El núcleo, cálido, y su halo.
  float nucleo = exp(-pow(r / (uR0 * 0.55), 2.0));
  col += nucleo * vec3(1.0, 0.80, 0.52) * 0.85;
  col += exp(-pow(r / (uR0 * 1.6), 2.0)) * vec3(0.25, 0.18, 0.30) * 0.6;

  // Estrellas lejanas, en dos capas.
  vec2 s = frag + uCentro * uEscala * 0.06;
  col += vec3(0.75, 0.82, 1.0) * lejanas(s, 9.0, 0.93) * 0.55;
  col += vec3(1.0) * lejanas(s + 101.0, 27.0, 0.90) * 0.9;

  col = 1.0 - exp(-col * 1.35);                                            // sin quemar
  // Un poco de grano invisible: quita los escalones en los degradados oscuros.
  col += (hash(frag + 0.5) - 0.5) / 255.0;
  fragColor = vec4(col, 1.0);
}
