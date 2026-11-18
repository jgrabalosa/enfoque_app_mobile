#version 460 core

// El papel del jardín de Dulce: el crema de la identidad (#FFFCF5) con su
// diente (el relieve fino donde se agarra el lápiz), unas fibras y manchas de
// tono muy suaves. Va pegado al mundo: al mover el jardín, el papel se mueve
// con él, como una hoja de verdad.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTamano;  // 0-1
uniform vec2 uCentro;  // 2-3: el punto del mundo en el centro de la pantalla
uniform float uEscala; // 4:   píxeles por unidad del mundo
uniform float uSemilla; // 5

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

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 w = (frag - uTamano * 0.5) / uEscala + uCentro;
  vec2 s = vec2(uSemilla * 41.0, uSemilla * 23.0);
  vec3 papel = vec3(1.0, 0.988, 0.961);

  // El diente: solo cuando se ve (de lejos se funde en el tono).
  float grano = 0.72;
  float visible = smoothstep(0.6, 2.2, grano * uEscala);
  float d = ruido(w / grano + s) * 0.6 + ruido(w / (grano * 0.5) + s + 5.0) * 0.4;
  float f = ruido(vec2(w.x / (grano * 4.0), w.y / grano) + s + 9.0);
  float relieve = (d - 0.5) * 0.06 + (f - 0.5) * 0.025;

  // Manchas de tono, muy suaves, como un papel que no es de fábrica.
  float tono = (ruido(w / 400.0 + s) - 0.5) * 0.014;

  vec3 col = papel * (1.0 + relieve * visible + tono);
  col += (hash(frag + 0.5) - 0.5) / 255.0;
  fragColor = vec4(col, 1.0);
}
