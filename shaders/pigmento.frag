#version 460 core

// El pigmento del lápiz de color sobre el papel (el jardín de Dulce).
//
// Un lápiz de verdad no deja una mancha lisa: el papel tiene relieve (el
// «diente») y el pigmento solo se agarra a lo que sobresale. Con poca presión
// tocan solo las crestas y salen motas sueltas; apretando, se llenan también
// los valles y el color se cierra. Aquí se hace eso mismo: la imagen
// [uPresion] dice cuánto se ha apretado en cada punto (los trazos se suman) y
// el relieve del papel decide, píxel a píxel, si agarra.
//
// Sale blanco con alfa: el color lo pone quien lo dibuja (`drawAtlas` con
// `modulate`), y se mezcla con `multiply` sobre el papel, como las capas de
// lápiz de verdad.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTamano;   // 0-1: lado de la imagen, en píxeles
uniform float uSemilla; // 2:   mueve el papel, para que cada imagen sea otra
uniform float uGrano;   // 3:   el tamaño del diente, en píxeles
uniform sampler2D uPresion;

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

// El relieve del papel: un diente fino, otro más fino aún y unas fibras
// algo alargadas en horizontal, como las del papel de dibujo.
float diente(vec2 p) {
  vec2 s = vec2(uSemilla * 31.0, uSemilla * 17.0);
  float a = ruido(p / uGrano + s);
  float b = ruido(p / (uGrano * 0.5) + s + 7.3);
  float c = ruido(vec2(p.x / (uGrano * 3.5), p.y / (uGrano * 0.8)) + s + 3.1);
  return a * 0.55 + b * 0.25 + c * 0.2;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float presion = clamp(texture(uPresion, p / uTamano).a, 0.0, 1.0);
  if (presion <= 0.002) {
    fragColor = vec4(0.0);
    return;
  }
  // Cuanto más se aprieta, más bajo queda el listón: agarra en más sitios.
  float liston = mix(0.80, 0.12, presion);
  float agarra = smoothstep(liston - 0.07, liston + 0.07, diente(p));
  // Y lo que agarra, más oscuro cuanto más se aprieta.
  float alfa = agarra * mix(0.55, 1.0, presion);
  fragColor = vec4(alfa);
}
