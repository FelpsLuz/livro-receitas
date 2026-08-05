// Palette cycling na água (addendum v3.1 §G.1) — técnica de época: nenhum
// frame de animação, as 4 cores de SPECULAR trocam de lugar no tempo.
// Só as claras ciclam; o corpo d'água escuro fica parado (senão pulsa).
shader_type canvas_item;

// 3 cores, não 4 (aferição v3.2 §D): das 4 claras da água, as duas
// intermediárias formam FITAS horizontais (8–14px) e ciclam como onda;
// o azul-escuro (traços de 3px) era pipoca dispersa — ficou estático,
// o corpo d'água não pulsa. O branco-gelo entra só como pico da rampa.
uniform sampler2D rampa : filter_nearest;   // 3×1
uniform float velocidade = 1.6;
uniform vec3 alvos[3];
uniform float tolerancia = 0.02;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	for (int i = 0; i < 3; i++) {
		if (distance(c.rgb, alvos[i]) < tolerancia) {
			int j = (i + int(TIME * velocidade)) % 3;
			c.rgb = texelFetch(rampa, ivec2(j, 0), 0).rgb;
			break;
		}
	}
	COLOR = c;
}
