<?php
/**
 * Post types: imóvel (público) e lead (interno).
 */

defined( 'ABSPATH' ) || exit;

add_action( 'init', 'fl_registrar_post_types' );

function fl_registrar_post_types() {

	register_post_type(
		'imovel',
		array(
			'labels'              => array(
				'name'               => 'Imóveis',
				'singular_name'      => 'Imóvel',
				'add_new'            => 'Adicionar imóvel',
				'add_new_item'       => 'Adicionar novo imóvel',
				'edit_item'          => 'Editar imóvel',
				'new_item'           => 'Novo imóvel',
				'view_item'          => 'Ver imóvel',
				'search_items'       => 'Buscar imóveis',
				'not_found'          => 'Nenhum imóvel encontrado',
				'all_items'          => 'Todos os imóveis',
				'menu_name'          => 'Imóveis',
			),
			'public'              => true,
			'has_archive'         => 'imoveis',
			'rewrite'             => array(
				'slug'       => 'imovel',
				'with_front' => false,
			),
			'menu_icon'           => 'dashicons-admin-home',
			'menu_position'       => 5,
			'supports'            => array( 'title', 'editor', 'thumbnail', 'excerpt', 'revisions', 'page-attributes' ),
			'show_in_rest'        => true,
			'rest_base'           => 'imoveis',
			'exclude_from_search' => false,
		)
	);

	/**
	 * Avaliações reais, transcritas do Google Business Profile.
	 * Título = nome de quem avaliou; conteúdo = o texto da avaliação.
	 */
	register_post_type(
		'fl_avaliacao',
		array(
			'labels'             => array(
				'name'          => 'Avaliações',
				'singular_name' => 'Avaliação',
				'add_new'       => 'Adicionar avaliação',
				'add_new_item'  => 'Adicionar nova avaliação',
				'edit_item'     => 'Editar avaliação',
				'not_found'     => 'Nenhuma avaliação cadastrada',
				'menu_name'     => 'Avaliações',
			),
			'public'             => false,
			'publicly_queryable' => false,
			'show_ui'            => true,
			'show_in_menu'       => true,
			'show_in_rest'       => false,
			'menu_icon'          => 'dashicons-star-filled',
			'menu_position'      => 7,
			'supports'           => array( 'title', 'editor', 'page-attributes' ),
			'has_archive'        => false,
			'rewrite'            => false,
		)
	);

	/**
	 * Leads: o mini-CRM que substitui o que a Code 49 entregava.
	 * Não é público — nem no site, nem na REST API, nem na busca.
	 */
	register_post_type(
		'fl_lead',
		array(
			'labels'             => array(
				'name'          => 'Leads',
				'singular_name' => 'Lead',
				'edit_item'     => 'Ver lead',
				'search_items'  => 'Buscar leads',
				'not_found'     => 'Nenhum lead recebido ainda',
				'menu_name'     => 'Leads',
			),
			'public'             => false,
			'publicly_queryable' => false,
			'show_ui'            => true,
			'show_in_menu'       => true,
			'show_in_rest'       => false,
			'menu_icon'          => 'dashicons-email-alt',
			'menu_position'      => 6,
			'capability_type'    => 'post',
			'map_meta_cap'       => true,
			'capabilities'       => array( 'create_posts' => 'do_not_allow' ),
			'supports'           => array( 'title' ),
			'has_archive'        => false,
			'rewrite'            => false,
		)
	);
}
