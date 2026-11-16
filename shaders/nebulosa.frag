#version 460 core

// Una nebulosa para los hitos de la galaxia (texturas_galaxia.dart). Se pinta
// una vez por variante al preparar el pintor y se guarda como imagen.
//
// Humo con remolinos (ruido deformado por otro ruido) y vetas de dos colores.
// Se apaga del todo antes del borde de la imagen: si llegara al borde, de
// lejos se vería el recuadro.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTamano;   // 0-1: lado de la imagen, en píxeles
uniform float uSemilla; // 2:   cambia la forma
uniform vec3 uColorA;   // 3-5: el color de fuera
uniform vec3 uColorB;   // 6-8: el color de las vetas

out vec4 fragColor;

// Azar que no depende de números grandes: aguanta la precisión de los
// móviles.
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
  for (int i = 0; i < 6; i++) {
    v += a * ruido(p);
    p = p * 2.02 + vec2(17.1, 9.2);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uTamano * 2.0 - 1.0; // -1..1
  float r = length(uv);

  vec2 q = uv * 2.4 + uSemilla * 37.0;
  vec2 w = vec2(fbm(q), fbm(q + vec2(5.2, 1.3)));
  float n = fbm(q + 2.6 * w);
  float vetas = fbm(q * 1.9 - 1.8 * w + 3.1);

  // Borde irregular, y a cero antes de llegar al de la imagen.
  float forma = 1.0 - smoothstep(0.25, 0.85, r + (n - 0.5) * 0.45);
  forma *= 1.0 - smoothstep(0.78, 0.97, r);

  float densidad = clamp(n * 1.7 - 0.45, 0.0, 1.0) * forma;
  vec3 col = mix(uColorA, uColorB, clamp(vetas * 1.6 - 0.45, 0.0, 1.0));
  // Filamentos más oscuros dentro del humo.
  col *= 0.55 + 0.45 * smoothstep(0.25, 0.7, vetas);
  col *= densidad * 0.9;
  // Un corazón algo más claro.
  col += uColorB * 0.25 * pow(forma, 3.0) * clamp(n * 1.5 - 0.5, 0.0, 1.0);

  // Premultiplicado: el alfa no puede quedar por debajo del color.
  float a = clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0);
  fragColor = vec4(min(col, vec3(a)), a);
}
