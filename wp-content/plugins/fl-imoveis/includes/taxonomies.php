<?php
/**
 * Três taxonomias e nada mais: tipo, finalidade e bairro.
 * Condomínio, características e afins são campos — não taxonomia.
 */

defined( 'ABSPATH' ) || exit;

add_action( 'init', 'fl_registrar_taxonomias' );

function fl_registrar_taxonomias() {

	$taxonomias = array(
		'imovel_tipo'       => array(
			'plural'   => 'Tipos',
			'singular' => 'Tipo',
			'slug'     => 'tipo',
		),
		'imovel_finalidade' => array(
			'plural'   => 'Finalidades',
			'singular' => 'Finalidade',
			'slug'     => 'finalidade',
		),
		'imovel_bairro'     => array(
			'plural'   => 'Bairros',
			'singular' => 'Bairro',
			'slug'     => 'bairro',
		),
	);

	foreach ( $taxonomias as $nome => $args ) {
		register_taxonomy(
			$nome,
			array( 'imovel' ),
			array(
				'labels'            => array(
					'name'          => $args['plural'],
					'singular_name' => $args['singular'],
					'search_items'  => 'Buscar ' . strtolower( $args['plural'] ),
					'all_items'     => 'Todos os ' . strtolower( $args['plural'] ),
					'edit_item'     => 'Editar ' . strtolower( $args['singular'] ),
					'add_new_item'  => 'Adicionar ' . strtolower( $args['singular'] ),
					'menu_name'     => $args['plural'],
				),
				'hierarchical'      => true,
				'public'            => true,
				'show_admin_column' => true,
				'show_in_rest'      => true,
				'rewrite'           => array(
					'slug'         => $args['slug'],
					'with_front'   => false,
					'hierarchical' => false,
				),
			)
		);
	}
}

/**
 * Termos iniciais, criados uma única vez na primeira carga do admin.
 * Bairro fica vazio de propósito: sai do XML da carteira real.
 */
add_action( 'admin_init', 'fl_semear_termos' );

function fl_semear_termos() {
	if ( get_option( 'fl_termos_semeados' ) ) {
		return;
	}

	$sementes = array(
		'imovel_tipo'       => array( 'Apartamento', 'Casa', 'Casa em condomínio', 'Cobertura', 'Terreno', 'Sala comercial', 'Galpão', 'Chácara' ),
		'imovel_finalidade' => array( 'Venda', 'Locação' ),
	);

	foreach ( $sementes as $taxonomia => $termos ) {
		foreach ( $termos as $termo ) {
			if ( ! term_exists( $termo, $taxonomia ) ) {
				wp_insert_term( $termo, $taxonomia );
			}
		}
	}

	update_option( 'fl_termos_semeados', 1 );
}
