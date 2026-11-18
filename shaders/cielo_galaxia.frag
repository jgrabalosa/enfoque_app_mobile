#version 460 core

// El cielo de la galaxia de Profundidad: el fondo, las estrellas lejanas y la
// galaxia en sí (núcleo, disco, brazos, polvo y nudos). Lo pinta la GPU píxel
// a píxel; las estrellas de las piezas van encima, desde Dart
// (pintor_codigo.dart).
//
// Imita las fotos de galaxias espirales vistas de frente (M51, M101, M74 del
// Hubble y el JWST), con la paleta de Profundidad:
// - el fondo casi negro, sin neblina fuera del disco;
// - un núcleo dorado (estrellas viejas) que se apaga poco a poco;
// - brazos hechos de muchas estrellas finas y grumos, no de una niebla lisa;
// - franjas de polvo oscuro por el lado de dentro de cada brazo, deshilachadas;
// - nudos rosados y ámbar (regiones de formación de estrellas) en los brazos;
// - y, entre los brazos, solo un poco de luz.
//
// Las cuentas van en coordenadas del mundo (las mismas del colocador), así
// que todo se queda pegado a los brazos al mover y hacer zoom. Las estrellas
// finas tienen tres tamaños de celda; cada uno se apaga cuando sus celdas
// miden pocos píxeles (de lejos su luz ya la pone el brillo difuso), para que
// no parpadeen ni se vean en rejilla.
//
// Precisión: los móviles calculan con menos decimales que un ordenador. Por
// eso se pide `highp` y el azar nunca trabaja con números grandes (`mod`
// antes de nada); si no, el ruido se rompe en bloques cuadrados. Y nunca
// `pow()` de algo que pueda ser negativo.

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

// Cada octava, girada: si no, el ruido sale alineado con la rejilla y, con
// mucho contraste, se ven cuadros.
const mat2 GIRO = mat2(0.80, 0.60, -0.60, 0.80);

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * ruido(p);
    p = GIRO * p * 2.03 + vec2(17.1, 9.2);
    a *= 0.5;
  }
  return v;
}

float fbm3(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 3; i++) {
    v += a * ruido(p);
    p = GIRO * p * 2.03 + vec2(4.7, 13.9);
    a *= 0.5;
  }
  return v;
}

// Base positiva elevada: `pow` solo con base >= 0.
float potencia(float x, float e) {
  return pow(max(x, 0.0), e);
}

// Estrellas lejanas de fondo (fuera de la galaxia): una por celda, con
// suerte. En pantalla y con un poco de paralaje.
float lejanas(vec2 s, float celda, float umbral) {
  vec2 c = floor(s / celda);
  float h = hash(c);
  if (h < umbral) return 0.0;
  vec2 pos = (c + vec2(hash(c + 3.1), hash(c + 7.7))) * celda;
  float d = length(s - pos);
  return exp(-d * d * 1.6) * (h - umbral) / (1.0 - umbral);
}

// Cerca de un brazo (1) o lejos (0). [desfase] mueve la espiral un poco y
// [onda] la tuerce, para que el brazo no sea una curva perfecta.
float brazos(float th, float r, float desfase, float potenciaBrazo, float onda) {
  float m = 0.0;
  for (int b = 0; b < 3; b++) {
    float fase = th - uGiroInicial - float(b) * 2.0943951 - desfase
        - uGiro * log(max(r, 1.0) / uR0) + onda;
    m = max(m, potencia(0.5 + 0.5 * cos(fase), potenciaBrazo));
  }
  return m;
}

// Las estrellas finas de la galaxia, en el mundo: una por celda de [celda]
// unidades, con probabilidad [densidad]. Casi todas débiles, unas pocas
// brillantes, como en una foto. Devuelve la luz con su color.
vec3 estrellasFinas(vec2 w, float celda, float densidad, float sal) {
  float celdaPx = celda * uEscala;
  // Con celdas de menos de ~3 px se verían en rejilla: se apagan.
  float lod = smoothstep(2.5, 7.0, celdaPx);
  if (lod <= 0.0) return vec3(0.0);
  vec2 c = floor(w / celda);
  vec2 cs = mod(c, 289.0) + sal;
  if (hash(cs) > densidad) return vec3(0.0);
  vec2 pos = (c + 0.15 + 0.7 * vec2(hash(cs + 3.1), hash(cs + 7.7))) * celda;
  float dpx = length(w - pos) * uEscala;
  float magnitud = hash(cs + 11.3);
  float brillo = 0.12 + 0.88 * magnitud * magnitud * magnitud;
  // El tamaño en píxeles: fino, y nunca tanto que se salga de su celda.
  float sigma = min(0.45 + 1.1 * brillo, 0.1 * celdaPx);
  float luz = exp(-dpx * dpx / (2.0 * sigma * sigma)) * brillo * lod;
  // Del ámbar al blanco cálido; alguna, blanca azulada (las jóvenes).
  float t = hash(cs + 5.9);
  vec3 color = t < 0.5 ? mix(vec3(1.0, 0.78, 0.45), vec3(1.0, 0.90, 0.72), t * 2.0)
                       : (t < 0.88 ? vec3(1.0, 0.95, 0.86) : vec3(0.82, 0.88, 1.0));
  return color * luz;
}

// Los nudos de formación de estrellas: manchas pequeñas de gas rosado o
// ámbar en lo más denso de los brazos. Del tamaño de una celda de [celda].
vec3 nudos(vec2 w, float celda, float densidad) {
  vec2 c = floor(w / celda);
  vec2 cs = mod(c, 289.0) + 41.0;
  if (hash(cs) > densidad) return vec3(0.0);
  vec2 pos = (c + 0.3 + 0.4 * vec2(hash(cs + 2.3), hash(cs + 8.1))) * celda;
  float radio = celda * (0.045 + 0.06 * hash(cs + 4.4));
  vec2 v = (w - pos) / radio;
  // Grumoso, no un círculo: un borde roto y dos o tres nudos más claros.
  float g = fbm3(v * 1.6 + cs);
  float d = length(v) + (g - 0.5) * 0.9;
  float luz = exp(-d * d * 1.8) * (0.4 + 1.1 * smoothstep(0.45, 0.8, g));
  vec3 color = hash(cs + 6.6) < 0.6 ? vec3(0.95, 0.38, 0.55)   // rosa
                                    : vec3(1.0, 0.62, 0.30);   // ámbar
  return color * luz;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 w = (frag - uTamano * 0.5) / uEscala + uCentro;
  float r = length(w);
  float th = atan(w.y, w.x);
  vec2 semilla = vec2(uSemilla * 41.0, uSemilla * 23.0);

  // El disco crece con lo que hay: brillo exponencial y un borde suave.
  float escalaDisco = max(uR0 * 0.9, uRadio * 0.34);
  float disco = exp(-r / escalaDisco);
  float borde = 1.0 - smoothstep(uRadio * 0.8, uRadio * 1.15 + 160.0, r);

  // Los brazos, un poco torcidos por el ruido.
  vec2 q = w / 650.0 + semilla;
  // Poco: las constelaciones van sobre la espiral exacta y no deben quedarse
  // fuera del brazo.
  float onda = (fbm3(q * 0.7) - 0.5) * 0.35;
  float enBrazo = brazos(th, r, 0.0, 7.0, onda);
  float nucleoTapa = smoothstep(uR0 * 0.35, uR0 * 1.1, r);  // en el núcleo no hay brazos
  float brazo = enBrazo * nucleoTapa * borde;

  // Grumos a lo largo del brazo: cúmulos de estrellas que no se ven una a una.
  float grumos = fbm(w / 160.0 + semilla * 3.0);
  float grumoso = smoothstep(0.3, 0.85, grumos);

  vec3 col = vec3(0.027, 0.051, 0.098) * 0.8;   // #070D19, algo más hondo

  // La luz difusa del disco y de los brazos (las estrellas que no se ven).
  vec3 calido = vec3(1.0, 0.82, 0.55);
  vec3 blancoCalido = vec3(1.0, 0.86, 0.66);
  col += disco * borde * calido * 0.07;                                   // entre brazos, poco
  col += brazo * disco * blancoCalido * (0.35 + 0.5 * grumoso) * 1.1;     // los brazos

  // El polvo: una franja oscura por dentro de cada brazo, con plumas.
  float polvo = brazos(th, r, -0.42, 10.0, onda) * borde;
  polvo *= smoothstep(0.38, 0.72, fbm(q * 3.4 + vec2(fbm3(q * 2.0)) * 1.5 + 2.9));
  polvo *= smoothstep(uR0 * 0.25, uR0 * 0.9, r);
  col *= 1.0 - 0.62 * polvo;
  col = mix(col, col * vec3(0.9, 0.7, 0.55), polvo * 0.5);                // marrón

  // El núcleo: dorado, con un centro muy brillante y un halo largo.
  float nucleo = exp(-potencia(r / (uR0 * 0.38), 1.6));
  float bulbo = exp(-r / (uR0 * 0.55));
  col += nucleo * vec3(1.0, 0.86, 0.60) * 0.9;
  col += bulbo * vec3(1.0, 0.70, 0.36) * 0.22;

  // Las estrellas finas, más en los brazos y en el bulbo que fuera.
  float densidad = clamp(brazo * (0.45 + 0.55 * grumoso) * 1.2
                         + bulbo * 0.6 + disco * borde * 0.04, 0.0, 1.0);
  vec3 finas = estrellasFinas(w, 5.0, densidad * 0.55, 0.0)
             + estrellasFinas(w, 13.0, densidad * 0.7, 17.0)
             + estrellasFinas(w, 34.0, densidad * 0.8, 53.0) * 1.3;
  col += finas * 0.9;

  // De lejos las estrellas finas ya no caben (sus celdas miden menos de unos
  // píxeles) y su luz pasa al brillo difuso: si no, la galaxia se apagaría
  // al alejarse.
  float perdida = (1.0 - smoothstep(2.5, 7.0, 5.0 * uEscala)) * 0.35
                + (1.0 - smoothstep(2.5, 7.0, 13.0 * uEscala)) * 0.35
                + (1.0 - smoothstep(2.5, 7.0, 34.0 * uEscala)) * 0.30;
  col += densidad * perdida * vec3(1.0, 0.86, 0.66) * 0.16;

  // Los nudos rosados y ámbar, solo en lo más denso de los brazos.
  float densNudos = clamp(brazo * grumoso * 1.6 - 0.25, 0.0, 1.0) * 0.55;
  col += nudos(w, 90.0, densNudos) * 0.42 * (1.0 - polvo * 0.6);

  // Estrellas lejanas, de la Vía Láctea, delante: pocas y tenues.
  vec2 s = frag + uCentro * uEscala * 0.06;
  col += vec3(0.85, 0.88, 1.0) * lejanas(s, 9.0, 0.95) * 0.35;
  col += vec3(1.0, 0.93, 0.80) * lejanas(s + 101.0, 27.0, 0.92) * 0.6;

  col = 1.0 - exp(-col * 1.1);                                            // sin quemar
  // Un poco de grano invisible: quita los escalones en los degradados oscuros.
  col += (hash(frag + 0.5) - 0.5) / 255.0;
  fragColor = vec4(col, 1.0);
}
