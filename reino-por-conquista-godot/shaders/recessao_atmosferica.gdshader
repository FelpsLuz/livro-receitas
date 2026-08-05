// Recessão atmosférica (addendum v3.2 §B, tentativa 1): montanha de fundo
// não deveria ter contraste alto — comprimir contraste + dessaturar +
// bruma dissolve tanto a claridade que puxava o maciço para FRENTE quanto
// o resto de direcionalidade. Aplicado à camada montanha_central.png
// (carregador RGBA extraído da placa), POR CIMA da fatia intacta.
// Valores default MEDIDOS da placa (auditar_luz.py, não chutados).
shader_type canvas_item;

uniform vec3 cor_horizonte = vec3(0.491, 0.742, 0.701);
uniform float bruma : hint_range(0.0, 1.0) = 0.34;
uniform float contraste : hint_range(0.0, 1.0) = 0.58;   // 1 = original
uniform float saturacao : hint_range(0.0, 1.0) = 0.55;
uniform float meio_tom = 0.779;                          // L médio da rocha

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 s = mix(vec3(l), c.rgb, saturacao);
	vec3 k = mix(vec3(meio_tom), s, contraste);
	COLOR = vec4(mix(k, cor_horizonte, bruma), c.a);
}
