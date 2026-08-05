// Véu de valor em gradiente vertical (addendum v3.1 §D): escurece e
// dessatura uma banda com transição suave — o padrão ratificado para
// qualquer ajuste de valor (modulate seco criaria emenda entre fatias).
// As fatias vêm de AtlasTexture: UV aqui é do ATLAS inteiro, por isso os
// limites da região entram como uniforms e o gradiente é normalizado.
shader_type canvas_item;

uniform float uv_topo = 0.0;         // UV.y do topo da região no atlas
uniform float uv_pe = 1.0;           // UV.y do pé da região no atlas
uniform float mult_topo : hint_range(0.5, 1.2) = 0.97;
uniform float mult_pe : hint_range(0.5, 1.2) = 0.85;
uniform float saturacao : hint_range(0.0, 2.0) = 0.92;
// Quebra de estrato (v3.2 §C), fundida aqui porque um CanvasItem só tem um
// material. Regras não negociáveis da spec: blocos de 2px (floor), nunca
// por pixel contínuo; SEM TIME — ruído animado em grama é formigamento.
uniform float ruido_amplitude : hint_range(0.0, 0.12) = 0.0;   // 0 = off
uniform float ruido_bloco = 2.0;

float ruido(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = clamp((UV.y - uv_topo) / max(uv_pe - uv_topo, 1e-5), 0.0, 1.0);
	c.rgb *= mix(mult_topo, mult_pe, t);
	float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	c.rgb = mix(vec3(l), c.rgb, saturacao);
	if (ruido_amplitude > 0.0) {
		vec2 px = floor((UV / TEXTURE_PIXEL_SIZE) / ruido_bloco);
		c.rgb *= 1.0 + (ruido(px) - 0.5) * 2.0 * ruido_amplitude;
	}
	COLOR = c;
}
