<?php
/**
 * 301 das URLs antigas (Code 49) para as novas.
 * Sem isso o pouco de indexação que existe hoje vira 404 no dia da virada.
 */

defined( 'ABSPATH' ) || exit;

function fl_mapa_redirects() {
	$arquivo = FL_IMOVEIS_DIR . 'config/redirects.php';
	$mapa    = file_exists( $arquivo ) ? include $arquivo : array();
	return is_array( $mapa ) ? $mapa : array();
}

add_action( 'template_redirect', 'fl_aplicar_redirects', 1 );

function fl_aplicar_redirects() {

	if ( ! is_404() ) {
		return;
	}

	$caminho = wp_parse_url( add_query_arg( array() ), PHP_URL_PATH );
	$caminho = untrailingslashit( strtolower( (string) $caminho ) );
	if ( '' === $caminho ) {
		return;
	}

	$mapa = fl_mapa_redirects();

	foreach ( array( $caminho, $caminho . '/' ) as $chave ) {
		if ( isset( $mapa[ $chave ] ) ) {
			wp_safe_redirect( home_url( $mapa[ $chave ] ), 301 );
			exit;
		}
	}

	/**
	 * Fallback: se a URL antiga carregava a referência do imóvel
	 * (ex.: /imovel/AP1234/ ou ?codigo=AP1234), procura pelo código.
	 */
	if ( preg_match( '#([A-Za-z]{1,4}\-?\d{2,8})#', $caminho, $m ) ) {
		$encontrados = get_posts(
			array(
				'post_type'      => 'imovel',
				'posts_per_page' => 1,
				'fields'         => 'ids',
				'meta_query'     => array(
					array(
						'key'     => 'fl_codigo',
						'value'   => $m[1],
						'compare' => '=',
					),
				),
			)
		);

		if ( $encontrados ) {
			wp_safe_redirect( get_permalink( $encontrados[0] ), 301 );
			exit;
		}
	}

	// Qualquer coisa sob a antiga árvore de imóveis cai na vitrine, nunca em 404.
	if ( preg_match( '#^/(imoveis?|busca|pesquisa|comprar|alugar)#', $caminho ) ) {
		wp_safe_redirect( get_post_type_archive_link( 'imovel' ), 301 );
		exit;
	}
}
