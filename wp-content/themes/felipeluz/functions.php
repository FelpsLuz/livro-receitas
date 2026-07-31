<?php
/**
 * Tema Felipe Luz Broker — filho do GeneratePress.
 */

defined( 'ABSPATH' ) || exit;

define( 'FL_TEMA_VERSAO', '1.0.0' );

add_action( 'wp_enqueue_scripts', 'fl_assets', 20 );

function fl_assets() {
	wp_enqueue_style(
		'felipeluz',
		get_stylesheet_directory_uri() . '/assets/css/felipeluz.css',
		array(),
		FL_TEMA_VERSAO
	);

	wp_enqueue_script(
		'felipeluz',
		get_stylesheet_directory_uri() . '/assets/js/felipeluz.js',
		array(),
		FL_TEMA_VERSAO,
		true
	);
}

add_action( 'after_setup_theme', function () {
	add_theme_support( 'post-thumbnails' );
	add_image_size( 'fl-card', 800, 560, true );
	add_image_size( 'fl-capa', 1600, 900, true );
	add_image_size( 'fl-miniatura', 240, 180, true );
} );

/**
 * Um único menu; o rodapé é montado no template.
 */
add_action( 'after_setup_theme', function () {
	register_nav_menus( array( 'principal' => 'Menu principal' ) );
} );

/* -------------------------------------------------------------------
 * Componentes de template
 * ---------------------------------------------------------------- */

/**
 * Selo de situação usado no card e na ficha.
 */
function fl_selo( $post_id = null ) {
	$situacao = fl_situacao( $post_id );
	if ( 'disponivel' === $situacao ) {
		return '';
	}
	return sprintf(
		'<span class="fl-selo fl-selo--%s">%s</span>',
		esc_attr( $situacao ),
		esc_html( fl_situacao_rotulo( $post_id ) )
	);
}

/**
 * Mensagem de retorno do formulário (?fl_ok=1 ou ?fl_erro=...).
 */
function fl_aviso_formulario() {
	if ( isset( $_GET['fl_ok'] ) ) {
		echo '<div class="fl-aviso fl-aviso--ok" role="status">Recebido. Retorno o contato em até 1 dia útil — normalmente bem antes disso.</div>';
		return;
	}

	if ( ! isset( $_GET['fl_erro'] ) ) {
		return;
	}

	$mensagens = array(
		'nome'    => 'Preencha seu nome.',
		'contato' => 'Informe ao menos um telefone ou e-mail.',
		'email'   => 'O e-mail informado parece inválido.',
		'sessao'  => 'A página ficou aberta tempo demais. Envie novamente.',
		'rapido'  => 'Envio bloqueado por segurança. Tente outra vez.',
		'salvar'  => 'Houve uma falha ao registrar. Chame no WhatsApp que resolvo na hora.',
	);

	$chave = sanitize_key( wp_unslash( $_GET['fl_erro'] ) );
	printf(
		'<div class="fl-aviso fl-aviso--erro" role="alert">%s</div>',
		esc_html( $mensagens[ $chave ] ?? 'Não consegui enviar. Tente novamente.' )
	);
}

/**
 * Campos ocultos comuns a todos os formulários.
 */
function fl_campos_ocultos( $origem, $imovel_id = 0 ) {
	wp_nonce_field( 'fl_lead', 'fl_nonce' );
	printf( '<input type="hidden" name="action" value="fl_lead">' );
	printf( '<input type="hidden" name="fl_origem" value="%s">', esc_attr( $origem ) );
	printf( '<input type="hidden" name="fl_retorno" value="%s">', esc_url( fl_url_atual() ) );
	printf( '<input type="hidden" name="fl_t" value="%d">', time() );
	if ( $imovel_id ) {
		printf( '<input type="hidden" name="fl_imovel" value="%d">', (int) $imovel_id );
	}
	// Honeypot.
	echo '<div class="fl-hp" aria-hidden="true"><label>Não preencha<input type="text" name="fl_site" tabindex="-1" autocomplete="off"></label></div>';
}

function fl_url_atual() {
	if ( is_singular() ) {
		return get_permalink();
	}
	if ( is_post_type_archive( 'imovel' ) ) {
		return get_post_type_archive_link( 'imovel' );
	}
	return home_url( add_query_arg( array() ) );
}

/**
 * Rodapé com CRECI — obrigatório em publicidade imobiliária.
 * Vai em wp_footer, e não num hook do GeneratePress, para continuar
 * aparecendo caso o tema-pai mude um dia.
 */
add_action( 'wp_footer', 'fl_rodape_creci', 5 );

function fl_rodape_creci() {
	$creci = fl_config( 'creci' );
	if ( ! $creci ) {
		return;
	}
	printf( '<div class="fl-creci">CRECI %s</div>', esc_html( $creci ) );
}

/**
 * Botão flutuante de WhatsApp.
 */
add_action( 'wp_footer', 'fl_botao_whatsapp' );

function fl_botao_whatsapp() {
	$link = fl_link_whatsapp( '', is_singular( 'imovel' ) ? get_the_ID() : 0 );
	if ( ! $link ) {
		return;
	}
	printf(
		'<a class="fl-zap" href="%s" target="_blank" rel="noopener" aria-label="Falar no WhatsApp">
			<svg viewBox="0 0 24 24" width="26" height="26" fill="currentColor" aria-hidden="true"><path d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 1.75.46 3.46 1.32 4.96L2 22l5.25-1.38a9.9 9.9 0 0 0 4.79 1.22h.01c5.46 0 9.91-4.45 9.91-9.91S17.5 2 12.04 2zm0 18.15h-.01a8.2 8.2 0 0 1-4.19-1.15l-.3-.18-3.12.82.83-3.04-.2-.31a8.19 8.19 0 0 1-1.26-4.38c0-4.54 3.7-8.23 8.25-8.23a8.23 8.23 0 0 1 0 16.47zm4.52-6.16c-.25-.12-1.47-.72-1.69-.81-.23-.08-.39-.12-.56.13-.16.24-.64.8-.78.97-.14.16-.29.18-.54.06-.25-.12-1.05-.39-1.99-1.23-.74-.66-1.23-1.47-1.38-1.72-.14-.25-.01-.38.11-.5.11-.11.25-.29.37-.43.12-.15.16-.25.25-.41.08-.17.04-.31-.02-.43-.06-.12-.56-1.34-.76-1.84-.2-.48-.4-.42-.56-.42h-.47c-.16 0-.43.06-.65.31-.22.25-.86.84-.86 2.05s.88 2.38 1 2.54c.12.16 1.73 2.65 4.2 3.71.59.25 1.04.4 1.4.52.59.19 1.12.16 1.54.1.47-.07 1.47-.6 1.67-1.18.21-.58.21-1.08.15-1.18-.06-.11-.22-.17-.47-.29z"/></svg>
		</a>',
		esc_url( $link )
	);
}

/**
 * Título do arquivo de imóveis.
 */
add_filter( 'get_the_archive_title', function ( $titulo ) {
	if ( is_post_type_archive( 'imovel' ) ) {
		return 'Imóveis';
	}
	if ( is_tax( 'imovel_bairro' ) ) {
		return 'Imóveis em ' . single_term_title( '', false );
	}
	if ( is_tax( array( 'imovel_tipo', 'imovel_finalidade' ) ) ) {
		return single_term_title( '', false );
	}
	return $titulo;
} );

/**
 * Excerpt: usa a descrição do imóvel quando não há resumo manual.
 */
add_filter( 'excerpt_length', function ( $tamanho ) {
	return is_post_type_archive( 'imovel' ) ? 24 : $tamanho;
} );

add_filter( 'excerpt_more', function () {
	return '…';
} );
