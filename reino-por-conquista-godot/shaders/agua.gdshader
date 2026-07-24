// ============================================================
// SHADER DE ÁGUA ORGÂNICA — distorce o que está desenhado
// atrás (hint_screen_texture), tinge de azul e acrescenta
// brilhos de sol onde o ruído passa do limiar.
// O ruído vem de um NoiseTexture2D + FastNoiseLite criado em
// código por agua_overlay.gd (sem passos manuais no Inspector).
// ============================================================
shader_type canvas_item;

uniform sampler2D tela : hint_screen_texture, filter_nearest;
uniform sampler2D textura_ruido : repeat_enable;
uniform vec2 velocidade_agua = vec2(0.05, 0.02);
uniform float forca_distorcao = 0.006;
uniform vec4 tinta_agua : source_color = vec4(0.16, 0.35, 0.55, 0.30);
uniform float limiar_brilho = 0.82;

void fragment() {
    vec2 uv_ruido = UV + TIME * velocidade_agua;
    vec2 desloc = texture(textura_ruido, uv_ruido).rg * 2.0 - 1.0;
    vec2 uv_tela = SCREEN_UV + desloc * forca_distorcao;
    vec4 fundo = texture(tela, uv_tela);

    // tinge o fundo distorcido com a cor da água
    vec4 cor = vec4(mix(fundo.rgb, tinta_agua.rgb, tinta_agua.a), 1.0);

    // brilhos de reflexo do sol
    float brilho = texture(textura_ruido, uv_ruido * 2.0).r;
    if (brilho > limiar_brilho) {
        cor.rgb += vec3(0.18);
    }

    // borda macia em cima e embaixo para casar com as margens do rio
    float borda = smoothstep(0.0, 0.18, UV.y) * (1.0 - smoothstep(0.82, 1.0, UV.y));
    COLOR = vec4(mix(fundo.rgb, cor.rgb, borda), 1.0);
}
