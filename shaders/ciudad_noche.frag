#version 460 core

// El suelo de la ciudad de Neotokyo+ de noche: solares, calles mojadas con
// reflejos de neón, farolas, avenidas que brillan y el río con su orilla.
// Los edificios, los coches y los hitos van encima, desde Dart
// (pintor_ciudad.dart).
//
// Las cuentas van en coordenadas del mundo, con las mismas medidas que
// colocador_ciudad.dart: manzanas de 200, calles de 36 y, cada tres
// manzanas, una avenida de 80. Si cambian allí, cambian aquí.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTamano;       // 0-1
uniform vec2 uCentro;       // 2-3
uniform float uEscala;      // 4
uniform float uSemilla;     // 5:  0..1
uniform float uRadio;       // 6:  hasta dónde llega la ciudad
uniform float uRioVertical; // 7:  1 si baja, 0 si cruza
uniform float uRioFase;     // 8
uniform float uRioDesp;     // 9
uniform float uTiempo;      // 10: segundos

out vec4 fragColor;

const float TRIO = 752.0;     // tres manzanas y una avenida
const float PASO = 236.0;     // manzana + calle
const float MEDIA = 100.0;    // media manzana
const float BORDE_AV = 336.0; // donde empieza la avenida, desde el centro del trío

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
  for (int i = 0; i < 4; i++) {
    v += a * ruido(p);
    p = p * 2.03 + vec2(17.1, 9.2);
    a *= 0.5;
  }
  return v;
}

// Para una coordenada x: (¿calle?, ¿avenida?, distancia al centro de la
// calle, medio ancho de la calle).
vec4 eje(float x) {
  float t = floor((x + TRIO * 0.5) / TRIO);
  float l = x - t * TRIO;
  float a = abs(l);
  if (a > BORDE_AV) {
    return vec4(1.0, 1.0, TRIO * 0.5 - a, 40.0);
  }
  if (a <= MEDIA || abs(a - PASO) <= MEDIA) {
    // Dentro de una manzana: la distancia, a la calle más cercana.
    float d = a <= MEDIA ? MEDIA - a : MEDIA - abs(a - PASO);
    return vec4(0.0, 0.0, d + 18.0, 18.0);
  }
  return vec4(1.0, 0.0, abs(a - PASO * 0.5), 18.0);
}

// Qué avenida es (para alternar su color): la misma a los dos lados.
float avenida(float x) {
  return floor(x / TRIO);
}

// Una campana: 1 en 0 y bajando. Sin pow() de un negativo, que en GLSL no
// está definido y en algunos móviles da cualquier cosa.
float cuad(float d, float ancho) {
  return exp(-d * d / ancho);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 w = (frag - uTamano * 0.5) / uEscala + uCentro;
  float r = length(w);
  vec2 sem = vec2(uSemilla * 37.0, uSemilla * 53.0);

  // Lo que se ve de la ciudad: se apaga hacia fuera.
  float ciudad = 1.0 - smoothstep(uRadio, uRadio + 600.0, r);
  // El detalle fino (farolas, rayas) solo se ve de cerca.
  float cerca = smoothstep(0.18, 0.45, uEscala);

  vec3 col = vec3(0.035, 0.024, 0.078);                       // #090614
  col += (fbm(w / 300.0 + sem) - 0.5) * 0.03;

  vec4 ex = eje(w.x);
  vec4 ey = eje(w.y);
  float enCalle = max(ex.x, ey.x);

  // Los solares: un poco más claros que el campo.
  vec3 solar = vec3(0.068, 0.046, 0.13) + (ruido(w / 9.0 + sem) - 0.5) * 0.02;
  col = mix(col, solar, ciudad * (1.0 - enCalle));

  // El asfalto mojado: oscuro, con reflejos de neón que se mueven poco.
  vec2 qr = w / 160.0 + sem;
  float brillo = fbm(qr + vec2(0.0, uTiempo * 0.03));
  vec3 reflejo = mix(vec3(1.0, 0.18, 0.53), vec3(0.0, 0.9, 1.0), fbm(qr * 0.4 + 3.0));
  vec3 asfalto = vec3(0.045, 0.036, 0.085) + reflejo * pow(brillo, 3.0) * 0.22;

  // Las rayas del centro, discontinuas, en las avenidas.
  float raya = 0.0;
  if (ex.y > 0.5 && ey.x < 0.5) {
    raya = step(ex.z, 1.5) * step(0.5, fract(w.y / 30.0));
  }
  if (ey.y > 0.5 && ex.x < 0.5) {
    raya = max(raya, step(ey.z, 1.5) * step(0.5, fract(w.x / 30.0)));
  }
  asfalto += raya * vec3(0.55, 0.5, 0.25) * cerca;

  // Farolas: una cada 48 unidades, en el borde de la calle.
  float farolas = 0.0;
  if (ex.x > 0.5 && ey.x < 0.5) {
    float along = mod(w.y, 48.0) - 24.0;
    float desde = ex.w - 5.0 - ex.z;
    farolas = exp(-(along * along + desde * desde) / 30.0);
  }
  if (ey.x > 0.5 && ex.x < 0.5) {
    float along = mod(w.x, 48.0) - 24.0;
    float desde = ey.w - 5.0 - ey.z;
    farolas = max(farolas, exp(-(along * along + desde * desde) / 30.0));
  }
  asfalto += vec3(1.0, 0.85, 0.6) * farolas * 0.9 * cerca;
  // De lejos, la calle entera brilla un poco en vez de las farolas sueltas.
  asfalto += vec3(0.25, 0.16, 0.30) * (1.0 - cerca) * 0.35;

  // Las avenidas: una franja de neón a cada lado, rosa o cian por trío.
  float avNeon = 0.0;
  vec3 avColor = vec3(0.0);
  if (ex.y > 0.5) {
    avNeon = cuad(ex.z - 34.0, 8.0);
    avColor = mod(avenida(w.x), 2.0) < 0.5 ? vec3(1.0, 0.18, 0.53) : vec3(0.0, 0.9, 1.0);
  }
  if (ey.y > 0.5) {
    float n = cuad(ey.z - 34.0, 8.0);
    if (n > avNeon) {
      avNeon = n;
      avColor = mod(avenida(w.y), 2.0) < 0.5 ? vec3(0.0, 0.9, 1.0) : vec3(1.0, 0.18, 0.53);
    }
  }
  asfalto += avColor * avNeon * (0.35 + 0.3 * cerca);
  // Y su halo, que de lejos dibuja el mapa de la ciudad.
  float avHalo = max(ex.y * exp(-ex.z / 60.0), ey.y * exp(-ey.z / 60.0));
  asfalto += vec3(0.30, 0.10, 0.35) * avHalo * 0.4;

  col = mix(col, asfalto, ciudad * enCalle);

  // El río: agua oscura con reflejos que tiemblan, y la orilla en cian. Los
  // puentes, donde lo cruza una avenida.
  float a = uRioVertical > 0.5 ? w.y : w.x;
  float b = uRioVertical > 0.5 ? w.x : w.y;
  float dRio = abs(b - (uRioDesp + 260.0 * sin(a / 900.0 + uRioFase)));
  float puente = uRioVertical > 0.5 ? ey.y : ex.y;
  if (dRio < 75.0 && puente < 0.5) {
    vec2 qa = w / 40.0 + vec2(uTiempo * 0.4, 0.0);
    float ola = fbm(qa + sem) * fbm(qa * 0.5 - sem);
    vec3 agua = vec3(0.02, 0.05, 0.12)
        + reflejo * pow(ola, 2.0) * 0.5
        + vec3(0.6, 0.9, 1.0) * pow(ola, 6.0) * 0.6 * cerca;
    col = agua;
  }
  float orilla = cuad(dRio - 75.0, 6.0) * (1.0 - puente);
  col += vec3(0.0, 0.9, 1.0) * orilla * 0.6;

  // El resplandor de la ciudad en la niebla.
  float rr = r / (uRadio * 0.9 + 300.0);
  col += vec3(0.20, 0.07, 0.22) * exp(-rr * rr) * 0.35;

  col = 1.0 - exp(-col * 1.25);
  col += (hash(frag + 0.5) - 0.5) / 255.0;
  fragColor = vec4(col, 1.0);
}
