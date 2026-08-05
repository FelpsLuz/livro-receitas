// VIDA NO ESTÁGIO ACHATADO — água ciclando + junco balançando.
//
// O cenário agora é UMA imagem pintada, sem camadas para separar. As duas
// animações portam mesmo assim porque operam por CORRESPONDÊNCIA DE COR,
// não por camada — era a aposta do §6 do pacote de prompts, e ela se
// sustenta com uma ressalva importante, registrada abaixo.
//
// O balanço NÃO pode ir no vertex aqui. Num quad de tela cheia, deslocar
// VERTEX.x move a imagem inteira, não os juncos. A versão em camadas podia
// fazer isso porque a touceira era um nó próprio. Aqui o deslocamento tem
// que ser na AMOSTRAGEM: para cada pixel, decide-se primeiro se ele é
// junco pela cor original e, se for, lê-se a cor de uma UV deslocada. O
// gate por cor evita arrastar ponte, aldeão ou pedra que estejam na mesma
// faixa de altura.
shader_type canvas_item;

// ---- água: as cores CLARAS do rio, medidas em medir_estagios.py ----
uniform sampler2D rampa : filter_nearest;   // N×1 com as cores do ciclo
uniform int rampa_n = 3;
uniform vec3 agua_alvo[4];
uniform int agua_n = 3;
uniform float agua_velocidade = 1.6;
uniform float agua_tolerancia = 0.02;
// PORTA ESPACIAL: as cores claras do rio também existem no céu, e sem
// este limite o ciclo mexia 7792px na imagem inteira em vez dos ~50px da
// água. Correspondência de cor sozinha não basta numa imagem achatada.
uniform float agua_topo = 0.86;

// ---- junco: faixa e cores ----
uniform float junco_topo = 0.84;      // UV.y onde a margem começa
uniform float junco_base = 0.95;      // UV.y do pé (amplitude zero aqui)
uniform vec3 junco_alvo[6];
uniform int junco_n = 4;
uniform float junco_tolerancia = 0.04;
uniform float junco_amplitude = 1.0;  // em PIXELS, inteiro (v3.1 §J)
uniform float junco_freq = 1.1;

bool perto(vec3 a, vec3 b, float tol) {
	vec3 d = a - b;
	return dot(d, d) < tol * tol;
}

void fragment() {
	vec2 uv = UV;
	vec4 c = texture(TEXTURE, uv);

	// ---- balanço do junco ----
	if (uv.y >= junco_topo && uv.y <= junco_base) {
		bool eh_junco = false;
		for (int i = 0; i < junco_n; i++) {
			if (perto(c.rgb, junco_alvo[i], junco_tolerancia)) {
				eh_junco = true;
			}
		}
		if (eh_junco) {
			// peso quadrático pela altura: pé cravado, topo balançando
			float t = 1.0 - (uv.y - junco_topo) / max(junco_base - junco_topo, 1e-5);
			float px = sin(TIME * junco_freq + uv.x * 34.0) * junco_amplitude * t * t;
			// arredonda para pixel INTEIRO: fração vira tremulação
			px = floor(px + 0.5);
			c = texture(TEXTURE, uv + vec2(px * TEXTURE_PIXEL_SIZE.x, 0.0));
		}
	}

	// ---- ciclo de paleta na água ----
	if (uv.y >= agua_topo) {
	for (int i = 0; i < agua_n; i++) {
		if (perto(c.rgb, agua_alvo[i], agua_tolerancia)) {
			int j = (i + int(TIME * agua_velocidade)) % rampa_n;
			c.rgb = texelFetch(rampa, ivec2(j, 0), 0).rgb;
			break;
		}
	}
	}
	COLOR = c;
}
