// GRADE DE ESTAÇÃO + SNAP DE PALETA — um shader só (spec v4 §C.2).
//
// Não é rede de segurança: é o que devolve a cena à condição de pixel art.
// O render medido tinha >1000 cores porque véu em gradiente, mix() de
// recessão, modulate de tier e ruído multiplicativo são todos operações
// CONTÍNUAS sobre ~100 cores de arte. Este passe recoloca tudo na paleta.
//
// Estação e snap no MESMO passe, de propósito: fundir depois obrigaria a
// quantizar duas vezes (uma no snap, outra depois do grade), e a segunda
// reintroduz cor fora da paleta. Aqui o grade roda antes e a paleta alvo
// já é a da estação — a cor de saída cai EXATAMENTE numa entrada.
//
// Distância em OKLab, não em RGB: dois verdes a mesma distância euclidiana
// em RGB podem estar a distâncias perceptuais muito diferentes, e o snap
// escolhia o vizinho errado nas rampas de folhagem.
shader_type canvas_item;

uniform sampler2D paleta : filter_nearest;   // N×1, a paleta da estação
uniform int paleta_n = 56;
uniform float mistura : hint_range(0.0, 1.0) = 1.0;
uniform vec3 tint = vec3(1.0);
uniform float saturacao : hint_range(0.0, 2.0) = 1.0;
uniform float luminancia : hint_range(0.0, 2.0) = 1.0;
// Dither ordenado 2×2 na TRANSIÇÃO (v4 §C.2): quando os dois vizinhos de
// paleta ficam quase empatados, alterna entre eles em xadrez em vez de
// chapar. É a resposta a banding — afrouxar a paleta é proibido.
uniform float dither : hint_range(0.0, 1.0) = 1.0;
const float ERRO_DITHER = 0.012;   // erro em OKLab a partir do qual vale alternar

vec3 oklab(vec3 c) {
	vec3 lin = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)),
			step(vec3(0.04045), c));
	float l = dot(lin, vec3(0.4122214708, 0.5363325363, 0.0514459929));
	float m = dot(lin, vec3(0.2119034982, 0.6806995451, 0.1073969566));
	float s = dot(lin, vec3(0.0883024619, 0.2817188376, 0.6299787005));
	vec3 c3 = pow(max(vec3(l, m, s), vec3(0.0)), vec3(1.0 / 3.0));
	return vec3(
		dot(c3, vec3(0.2104542553, 0.7936177850, -0.0040720468)),
		dot(c3, vec3(1.9779984951, -2.4285922050, 0.4505937099)),
		dot(c3, vec3(0.0259040371, 0.7827717662, -0.8086757660)));
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec3 c = src.rgb * tint * luminancia;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = clamp(mix(vec3(l), c, saturacao), 0.0, 1.0);

	vec3 alvo = oklab(c);
	float d1 = 1e9;
	float d2 = 1e9;
	vec3 p1 = c;
	vec3 p2 = c;
	for (int i = 0; i < paleta_n; i++) {
		vec3 p = texelFetch(paleta, ivec2(i, 0), 0).rgb;
		vec3 dv = oklab(p) - alvo;
		float d = dot(dv, dv);
		if (d < d1) { d2 = d1; p2 = p1; d1 = d; p1 = p; }
		else if (d < d2) { d2 = d; p2 = p; }
	}
	// xadrez 2×2 só onde os dois primeiros quase empatam
	vec3 escolhida = p1;
	if (dither > 0.0 && d2 > 0.0) {
		float razao = d1 / d2;
		if (razao > 0.80) {   // só empate de verdade: 0.62 disparava em quase todo pixel
			vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
			float xadrez = mod(px.x + px.y, 2.0);
			escolhida = mix(p1, p2, step(0.5, xadrez) * dither);
		}
	}
	COLOR = vec4(mix(c, escolhida, mistura), src.a);
}
