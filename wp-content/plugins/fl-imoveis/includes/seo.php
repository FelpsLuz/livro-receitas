<?php
/**
 * SEO técnico: canonical, robots, rastreadores de IA e WebP.
 */

defined( 'ABSPATH' ) || exit;

/**
 * Uma única URL canônica por listagem.
 *
 * Filtro e ordenação geram parâmetros (?tipo=casa&ordem=preco_asc). Cada
 * combinação é uma URL nova, e são dezenas — todas com o mesmo conteúdo
 * recombinado. O canonical aponta para a versão limpa e o noindex evita
 * que o crawler gaste orçamento nelas.
 */
add_action( 'wp_head', 'fl_canonical_vitrine', 1 );

function fl_canonical_vitrine() {

	if ( ! is_post_type_archive( 'imovel' ) && ! is_tax( array( 'imovel_tipo', 'imovel_finalidade', 'imovel_bairro' ) ) ) {
		return;
	}

	if ( ! fl_tem_filtro_ativo() && ! isset( $_GET['ordem'] ) ) {
		return;
	}

	$limpa = is_post_type_archive( 'imovel' )
		? get_post_type_archive_link( 'imovel' )
		: get_term_link( get_queried_object() );

	if ( is_wp_error( $limpa ) || ! $limpa ) {
		return;
	}

	printf( '<link rel="canonical" href="%s">' . "\n", esc_url( $limpa ) );
	echo '<meta name="robots" content="noindex,follow">' . "\n";
}

/**
 * O canonical do próprio WordPress duplicaria a tag acima nas vistas
 * filtradas — desliga só nesse caso.
 */
add_action( 'template_redirect', function () {
	if ( ( is_post_type_archive( 'imovel' ) || is_tax( array( 'imovel_tipo', 'imovel_finalidade', 'imovel_bairro' ) ) )
		&& ( fl_tem_filtro_ativo() || isset( $_GET['ordem'] ) ) ) {
		remove_action( 'wp_head', 'rel_canonical' );
	}
} );

/**
 * Rastreadores de IA liberados explicitamente. Você quer ser lido.
 *
 * Bloquear Google-Extended não tira o site das AI Overviews — aquilo usa o
 * índice do Googlebot. Não há ganho em bloquear nada aqui.
 *
 * As URLs filtradas ficam de fora do rastreamento por parâmetro, não por
 * bloqueio de diretório: o conteúdo é o mesmo da vitrine limpa.
 */
add_filter( 'robots_txt', 'fl_robots_txt', 10, 2 );

function fl_robots_txt( $saida, $publico ) {

	if ( ! $publico ) {
		return $saida;
	}

	$agentes = array(
		'GPTBot',
		'OAI-SearchBot',
		'ChatGPT-User',
		'PerplexityBot',
		'ClaudeBot',
		'Claude-SearchBot',
		'Applebot-Extended',
		'Google-Extended',
		'CCBot',
		'meta-externalagent',
	);

	$linhas = array( '', '# Rastreadores de IA: liberados de propósito.' );

	foreach ( $agentes as $agente ) {
		$linhas[] = 'User-agent: ' . $agente;
	}
	$linhas[] = 'Allow: /';
	$linhas[] = '';
	$linhas[] = 'Sitemap: ' . home_url( '/sitemap_index.xml' );
	$linhas[] = 'Sitemap: ' . home_url( '/wp-sitemap.xml' );

	return $saida . implode( "\n", $linhas ) . "\n";
}

/**
 * /llms.txt
 *
 * Custa dez minutos e não há evidência de que qualquer provedor de IA
 * relevante consuma o arquivo hoje. Está aqui como aposta barata — não
 * conte com ele. O que move o ponteiro é o conteúdo das páginas.
 */
add_action( 'init', function () {
	add_rewrite_rule( '^llms\.txt$', 'index.php?fl_llms=1', 'top' );
} );

add_filter( 'query_vars', function ( $vars ) {
	$vars[] = 'fl_llms';
	return $vars;
} );

add_action( 'template_redirect', function () {

	if ( ! get_query_var( 'fl_llms' ) ) {
		return;
	}

	$stats = fl_estatisticas();

	$linhas = array(
		'# ' . fl_config( 'nome' ),
		'',
		'> ' . fl_config( 'papel' ) . ' em ' . fl_config( 'cidade' ) . '/' . fl_config( 'uf' ) . '. '
			. fl_config( 'creci' ) . '. Carteira própria de imóveis, com atendimento direto do corretor.',
		'',
		'## Páginas principais',
		'',
		'- [Imóveis disponíveis](' . get_post_type_archive_link( 'imovel' ) . '): carteira ativa, com preço, área e localização de cada imóvel.',
		'- [Imóveis vendidos](' . fl_url_pagina( 'vendidos' ) . '): histórico de vendas, com o tempo que cada uma levou.',
		'- [Avaliação para quem quer vender](' . fl_url_pagina( 'quero-vender' ) . '): como funciona a captação e o método de venda.',
		'- [Sobre ' . fl_config( 'nome' ) . '](' . fl_url_pagina( 'sobre' ) . '): formação, registro profissional e área de atuação.',
		'- [Contato](' . fl_url_pagina( 'contato' ) . ')',
		'',
		'## Dados',
		'',
		'- Imóveis na carteira ativa: ' . $stats['ativos'],
		'- Imóveis vendidos: ' . $stats['vendidos'],
	);

	if ( $stats['dias_medio'] > 0 ) {
		$linhas[] = '- Tempo médio entre captação e venda: ' . $stats['dias_medio'] . ' dias';
	}

	$linhas[] = '- Levantamento próprio, atualizado em ' . current_time( 'd/m/Y' );
	$linhas[] = '';
	$linhas[] = '## Observações';
	$linhas[] = '';
	$linhas[] = 'Cada ficha de imóvel traz preço, condomínio e IPTU em números explícitos,';
	$linhas[] = 'uma tabela de especificações e um FAQ com as dúvidas mais comuns daquele imóvel.';

	header( 'Content-Type: text/plain; charset=utf-8' );
	header( 'X-Robots-Tag: noindex' );
	echo implode( "\n", $linhas ) . "\n"; // phpcs:ignore WordPress.Security.EscapeOutput
	exit;
} );

/**
 * Converte os tamanhos gerados para WebP.
 *
 * O original enviado permanece intacto; o que o site serve passa a ser
 * WebP, que é o formato exigido para o LCP do topo caber no orçamento.
 */
add_filter( 'image_editor_output_format', function ( $formatos ) {
	$formatos['image/jpeg'] = 'image/webp';
	$formatos['image/png']  = 'image/webp';
	return $formatos;
} );

/**
 * Título e descrição de fallback das listagens, para quando não houver
 * plugin de SEO instalado ainda.
 */
add_filter( 'document_title_parts', function ( $partes ) {

	if ( is_singular( 'imovel' ) ) {
		$local = fl_localizacao( get_the_ID() );
		if ( $local ) {
			$partes['title'] = get_the_title() . ' — ' . $local;
		}
	}

	if ( is_post_type_archive( 'imovel' ) ) {
		$partes['title'] = 'Imóveis em ' . fl_config( 'cidade' );
	}

	if ( is_tax( 'imovel_bairro' ) ) {
		$partes['title'] = 'Imóveis no ' . single_term_title( '', false ) . ', ' . fl_config( 'cidade' );
	}

	return $partes;
} );

add_action( 'wp_head', function () {

	// Não sobrescreve quem já cuida disso.
	if ( defined( 'RANK_MATH_VERSION' ) || defined( 'WPSEO_VERSION' ) ) {
		return;
	}

	$descricao = '';

	if ( is_singular( 'imovel' ) ) {
		$descricao = fl_resposta_direta( get_the_ID() );
	} elseif ( is_front_page() ) {
		$descricao = sprintf(
			'%s, %s em %s. %s Atendimento direto, sem central.',
			fl_config( 'nome' ),
			strtolower( fl_config( 'papel' ) ),
			fl_config( 'cidade' ),
			fl_config( 'creci' ) ? fl_config( 'creci' ) . '.' : ''
		);
	}

	if ( $descricao ) {
		printf( '<meta name="description" content="%s">' . "\n", esc_attr( wp_trim_words( $descricao, 32, '' ) ) );
	}
}, 2 );
