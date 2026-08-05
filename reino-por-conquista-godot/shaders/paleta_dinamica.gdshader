// ============================================================
// PALETA DINÂMICA — troca as cores de personagem e cenário por clima/estação.
//
// Duas maneiras, e a diferença entre elas é a diferença entre pixel art e
// "foto com filtro":
//
// 1. LOOKUP (padrão, `usar_lookup = true`). A cor de saída sai de uma TABELA:
//    uma tira Nx1 com a paleta de origem e outra com a paleta de destino. Cada
//    pixel acha o índice mais próximo na primeira e devolve a cor da segunda.
//    O resultado fica EXATAMENTE dentro da paleta nova — nenhuma cor inventada.
//    É o método correto para pixel art, e é caro: N comparações por pixel.
//
// 2. MATIZ/CROMA (`usar_lookup = false`). Desloca matiz e satura em HSV. É
//    barato e serve para um vidro d'água ou um flash de dano, mas INVENTA
//    cor: o resultado quase nunca cai numa entrada da paleta. Numa cena
//    inteira, é o que faz a arte parecer lavada.
//
// A guarda de croma existe porque contorno preto, metal e branco de olho não
// devem seguir a estação: eles são a leitura da silhueta. Abaixo de
// `croma_minimo` a cor passa intacta nos dois modos.
// ============================================================
shader_type canvas_item;

uniform bool usar_lookup = true;
/// Tiras Nx1, filtro nearest, na MESMA ordem: origem[i] vira destino[i].
uniform sampler2D paleta_origem : filter_nearest, repeat_disable;
uniform sampler2D paleta_destino : filter_nearest, repeat_disable;
uniform int paleta_n = 0;

uniform float mistura : hint_range(0.0, 1.0) = 1.0;
uniform float croma_minimo : hint_range(0.0, 1.0) = 0.10;

// modo 2 — só quando usar_lookup = false
uniform float desvio_matiz : hint_range(-0.5, 0.5) = 0.0;
uniform float ganho_croma : hint_range(0.0, 2.0) = 1.0;
uniform float ganho_valor : hint_range(0.0, 2.0) = 1.0;

vec3 rgb_para_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)),
			d / (q.x + 1e-10), q.x);
}

vec3 hsv_para_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a < 0.01) {
		COLOR = src;
	} else {
		vec3 hsv = rgb_para_hsv(src.rgb);
		if (hsv.y < croma_minimo) {
			// neutro: contorno, metal, branco de olho. Não segue a estação.
			COLOR = src;
		} else {
			vec3 saida = src.rgb;
			if (usar_lookup && paleta_n > 0) {
				// vizinho mais próximo na paleta de origem, por distância
				// euclidiana em RGB. É aproximação — OKLab seria melhor — mas
				// as duas tiras vêm da MESMA arte, então os candidatos já
				// estão bem separados e o erro não aparece.
				int melhor = 0;
				float menor = 1e9;
				for (int i = 0; i < paleta_n; i++) {
					vec3 p = texelFetch(paleta_origem, ivec2(i, 0), 0).rgb;
					vec3 d = p - src.rgb;
					float dd = dot(d, d);
					if (dd < menor) {
						menor = dd;
						melhor = i;
					}
				}
				saida = texelFetch(paleta_destino, ivec2(melhor, 0), 0).rgb;
			} else {
				hsv.x = fract(hsv.x + desvio_matiz);
				hsv.y = clamp(hsv.y * ganho_croma, 0.0, 1.0);
				hsv.z = clamp(hsv.z * ganho_valor, 0.0, 1.0);
				saida = hsv_para_rgb(hsv);
			}
			COLOR = vec4(mix(src.rgb, saida, mistura), src.a);
		}
	}
}
