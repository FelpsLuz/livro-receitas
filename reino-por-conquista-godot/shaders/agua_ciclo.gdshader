// Palette cycling na água (addendum v3.1 §G.1) — técnica de época: nenhum
// frame de animação, as 4 cores de SPECULAR trocam de lugar no tempo.
// Só as claras ciclam; o corpo d'água escuro fica parado (senão pulsa).
shader_type canvas_item;

uniform sampler2D rampa : filter_nearest;   // 4×1: as 4 cores de água claras
uniform float velocidade = 1.6;
uniform vec3 alvos[4];                      // mesmas 4 cores, espaço 0..1
uniform float tolerancia = 0.02;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	for (int i = 0; i < 4; i++) {
		if (distance(c.rgb, alvos[i]) < tolerancia) {
			int j = (i + int(TIME * velocidade)) % 4;
			c.rgb = texelFetch(rampa, ivec2(j, 0), 0).rgb;
			break;
		}
	}
	COLOR = c;
}
