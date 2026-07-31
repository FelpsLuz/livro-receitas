<?php
/**
 * Filtro da vitrine. Formulário GET + pre_get_posts.
 * Com 30 imóveis isso resolve o caso de uso inteiro — não precisa de AJAX.
 */

defined( 'ABSPATH' ) || exit;

const FL_POR_PAGINA = 12;

/**
 * Lê e higieniza os filtros da URL.
 */
function fl_filtros_ativos() {
	$filtros = array(
		'tipo'       => isset( $_GET['tipo'] ) ? sanitize_title( wp_unslash( $_GET['tipo'] ) ) : '',
		'finalidade' => isset( $_GET['finalidade'] ) ? sanitize_title( wp_unslash( $_GET['finalidade'] ) ) : '',
		'bairro'     => isset( $_GET['bairro'] ) ? sanitize_title( wp_unslash( $_GET['bairro'] ) ) : '',
		'preco_min'  => isset( $_GET['preco_min'] ) ? (float) $_GET['preco_min'] : 0,
		'preco_max'  => isset( $_GET['preco_max'] ) ? (float) $_GET['preco_max'] : 0,
		'dorm'       => isset( $_GET['dorm'] ) ? absint( $_GET['dorm'] ) : 0,
		'vagas'      => isset( $_GET['vagas'] ) ? absint( $_GET['vagas'] ) : 0,
		'ordem'      => isset( $_GET['ordem'] ) ? sanitize_key( wp_unslash( $_GET['ordem'] ) ) : 'recentes',
	);

	return $filtros;
}

function fl_tem_filtro_ativo() {
	$f = fl_filtros_ativos();
	unset( $f['ordem'] );
	return (bool) array_filter( $f );
}

add_action( 'pre_get_posts', 'fl_filtrar_vitrine' );

function fl_filtrar_vitrine( $query ) {

	if ( is_admin() || ! $query->is_main_query() ) {
		return;
	}

	$e_arquivo_imovel = $query->is_post_type_archive( 'imovel' )
		|| $query->is_tax( array( 'imovel_tipo', 'imovel_finalidade', 'imovel_bairro' ) );

	if ( ! $e_arquivo_imovel ) {
		return;
	}

	$query->set( 'posts_per_page', FL_POR_PAGINA );

	$filtros    = fl_filtros_ativos();
	$tax_query  = (array) $query->get( 'tax_query' );
	$meta_query = (array) $query->get( 'meta_query' );

	foreach ( array( 'tipo' => 'imovel_tipo', 'finalidade' => 'imovel_finalidade', 'bairro' => 'imovel_bairro' ) as $param => $taxonomia ) {
		if ( $filtros[ $param ] ) {
			$tax_query[] = array(
				'taxonomy' => $taxonomia,
				'field'    => 'slug',
				'terms'    => $filtros[ $param ],
			);
		}
	}

	if ( $filtros['preco_min'] > 0 ) {
		$meta_query[] = array(
			'key'     => 'fl_preco',
			'value'   => $filtros['preco_min'],
			'type'    => 'DECIMAL(15,2)',
			'compare' => '>=',
		);
	}

	if ( $filtros['preco_max'] > 0 ) {
		$meta_query[] = array(
			'key'     => 'fl_preco',
			'value'   => $filtros['preco_max'],
			'type'    => 'DECIMAL(15,2)',
			'compare' => '<=',
		);
	}

	if ( $filtros['dorm'] > 0 ) {
		$meta_query[] = array(
			'key'     => 'fl_dormitorios',
			'value'   => $filtros['dorm'],
			'type'    => 'NUMERIC',
			'compare' => '>=',
		);
	}

	if ( $filtros['vagas'] > 0 ) {
		$meta_query[] = array(
			'key'     => 'fl_vagas',
			'value'   => $filtros['vagas'],
			'type'    => 'NUMERIC',
			'compare' => '>=',
		);
	}

	/**
	 * Vendido nunca some do site — mas também não polui a vitrine de
	 * quem está procurando o que comprar. Ele vive em /vendidos/.
	 */
	$meta_query[] = array(
		'relation' => 'OR',
		array(
			'key'     => 'fl_situacao',
			'value'   => 'vendido',
			'compare' => '!=',
		),
		array(
			'key'     => 'fl_situacao',
			'compare' => 'NOT EXISTS',
		),
	);

	if ( $tax_query ) {
		$query->set( 'tax_query', $tax_query );
	}
	if ( $meta_query ) {
		$query->set( 'meta_query', $meta_query );
	}

	switch ( $filtros['ordem'] ) {
		case 'preco_asc':
			$query->set( 'meta_key', 'fl_preco' );
			$query->set( 'orderby', 'meta_value_num' );
			$query->set( 'order', 'ASC' );
			break;
		case 'preco_desc':
			$query->set( 'meta_key', 'fl_preco' );
			$query->set( 'orderby', 'meta_value_num' );
			$query->set( 'order', 'DESC' );
			break;
		default:
			$query->set( 'orderby', array( 'menu_order' => 'ASC', 'date' => 'DESC' ) );
	}
}

/**
 * Query dos imóveis vendidos.
 *
 * Ordena por data do post, não por fl_data_venda: usar a data da venda como
 * meta_key faria o WordPress excluir todo imóvel importado sem esse campo
 * preenchido — justamente o histórico antigo, que é o mais valioso aqui.
 */
function fl_query_vendidos( $por_pagina = 24 ) {
	return new WP_Query(
		array(
			'post_type'      => 'imovel',
			'post_status'    => 'publish',
			'posts_per_page' => $por_pagina,
			'paged'          => max( 1, get_query_var( 'paged' ), get_query_var( 'page' ) ),
			'orderby'        => 'date',
			'order'          => 'DESC',
			'meta_query'     => array(
				array(
					'key'   => 'fl_situacao',
					'value' => 'vendido',
				),
			),
		)
	);
}

/**
 * Destaques da home. Cai para os mais recentes se ninguém marcou destaque.
 */
function fl_query_destaques( $quantidade = 6 ) {
	$base = array(
		'post_type'      => 'imovel',
		'post_status'    => 'publish',
		'posts_per_page' => $quantidade,
		'no_found_rows'  => true,
		'meta_query'     => array(
			'relation' => 'AND',
			array(
				'key'     => 'fl_destaque',
				'value'   => '1',
			),
			array(
				'relation' => 'OR',
				array( 'key' => 'fl_situacao', 'value' => 'vendido', 'compare' => '!=' ),
				array( 'key' => 'fl_situacao', 'compare' => 'NOT EXISTS' ),
			),
		),
	);

	$query = new WP_Query( $base );

	// Ninguém marcou destaque ainda: mostra os mais recentes.
	if ( ! $query->have_posts() ) {
		$base['meta_query'] = array(
			array( 'relation' => 'OR',
				array( 'key' => 'fl_situacao', 'value' => 'vendido', 'compare' => '!=' ),
				array( 'key' => 'fl_situacao', 'compare' => 'NOT EXISTS' ),
			),
		);
		$query = new WP_Query( $base );
	}

	return $query;
}

/**
 * Imóveis parecidos: mesmo bairro, mesma faixa, exceto o atual.
 */
function fl_query_relacionados( $post_id, $quantidade = 3 ) {
	$bairros = wp_get_post_terms( $post_id, 'imovel_bairro', array( 'fields' => 'ids' ) );

	$args = array(
		'post_type'      => 'imovel',
		'post_status'    => 'publish',
		'posts_per_page' => $quantidade,
		'post__not_in'   => array( $post_id ),
		'no_found_rows'  => true,
		'orderby'        => 'rand',
		'meta_query'     => array(
			array( 'relation' => 'OR',
				array( 'key' => 'fl_situacao', 'value' => 'vendido', 'compare' => '!=' ),
				array( 'key' => 'fl_situacao', 'compare' => 'NOT EXISTS' ),
			),
		),
	);

	if ( $bairros && ! is_wp_error( $bairros ) ) {
		$args['tax_query'] = array(
			array(
				'taxonomy' => 'imovel_bairro',
				'field'    => 'term_id',
				'terms'    => $bairros,
			),
		);
	}

	$query = new WP_Query( $args );

	if ( ! $query->have_posts() && isset( $args['tax_query'] ) ) {
		unset( $args['tax_query'] );
		$query = new WP_Query( $args );
	}

	return $query;
}
