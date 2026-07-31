<?php
/**
 * Acessores usados pelos templates.
 * Tudo lê meta cru (get_post_meta), então os templates continuam
 * funcionando mesmo se o Meta Box for desativado.
 */

defined( 'ABSPATH' ) || exit;

const FL_PREFIXO = 'fl_';

/**
 * Situações possíveis. A chave é o que fica no banco.
 */
function fl_situacoes() {
	return array(
		'disponivel' => 'Disponível',
		'reservado'  => 'Reservado',
		'vendido'    => 'Vendido',
	);
}

function fl_campo( $chave, $post_id = null, $padrao = '' ) {
	$post_id = $post_id ? (int) $post_id : get_the_ID();
	if ( ! $post_id ) {
		return $padrao;
	}
	$valor = get_post_meta( $post_id, FL_PREFIXO . $chave, true );
	return ( '' === $valor || null === $valor ) ? $padrao : $valor;
}

function fl_situacao( $post_id = null ) {
	$situacao = fl_campo( 'situacao', $post_id, 'disponivel' );
	return array_key_exists( $situacao, fl_situacoes() ) ? $situacao : 'disponivel';
}

function fl_situacao_rotulo( $post_id = null ) {
	$situacoes = fl_situacoes();
	return $situacoes[ fl_situacao( $post_id ) ];
}

function fl_esta_vendido( $post_id = null ) {
	return 'vendido' === fl_situacao( $post_id );
}

/**
 * Preço formatado. Zero, vazio ou "sob consulta" caem no mesmo lugar.
 */
function fl_preco( $post_id = null ) {
	if ( fl_campo( 'preco_sob_consulta', $post_id ) ) {
		return 'Sob consulta';
	}
	$preco = (float) fl_campo( 'preco', $post_id, 0 );
	if ( $preco <= 0 ) {
		return 'Sob consulta';
	}
	return 'R$ ' . number_format( $preco, 0, ',', '.' );
}

function fl_preco_numerico( $post_id = null ) {
	return (float) fl_campo( 'preco', $post_id, 0 );
}

function fl_valor_brl( $valor ) {
	$valor = (float) $valor;
	if ( $valor <= 0 ) {
		return '';
	}
	return 'R$ ' . number_format( $valor, 0, ',', '.' );
}

/**
 * IDs da galeria. O Meta Box grava image_advanced como linhas repetidas
 * da mesma meta key — o importador segue exatamente o mesmo formato.
 */
function fl_galeria_ids( $post_id = null ) {
	$post_id = $post_id ? (int) $post_id : get_the_ID();
	if ( ! $post_id ) {
		return array();
	}

	$ids = get_post_meta( $post_id, FL_PREFIXO . 'galeria', false );
	$ids = array_values( array_filter( array_map( 'absint', (array) $ids ) ) );

	if ( ! $ids && has_post_thumbnail( $post_id ) ) {
		$ids = array( get_post_thumbnail_id( $post_id ) );
	}

	return array_values( array_unique( $ids ) );
}

/**
 * Localização pública: bairro e cidade. Nunca o endereço exato —
 * ninguém precisa do número da casa do cliente indexado no Google.
 */
function fl_localizacao( $post_id = null ) {
	$post_id = $post_id ? (int) $post_id : get_the_ID();
	$partes  = array();

	$bairros = get_the_terms( $post_id, 'imovel_bairro' );
	if ( $bairros && ! is_wp_error( $bairros ) ) {
		$partes[] = $bairros[0]->name;
	}

	$cidade = fl_campo( 'cidade', $post_id );
	if ( $cidade ) {
		$partes[] = $cidade;
	}

	return implode( ', ', $partes );
}

function fl_tipo_nome( $post_id = null ) {
	$termos = get_the_terms( $post_id ? $post_id : get_the_ID(), 'imovel_tipo' );
	return ( $termos && ! is_wp_error( $termos ) ) ? $termos[0]->name : 'Imóvel';
}

function fl_finalidade_nome( $post_id = null ) {
	$termos = get_the_terms( $post_id ? $post_id : get_the_ID(), 'imovel_finalidade' );
	return ( $termos && ! is_wp_error( $termos ) ) ? $termos[0]->name : '';
}

/**
 * Ficha técnica resumida para o card e para o topo da página do imóvel.
 */
function fl_atributos( $post_id = null ) {
	$post_id = $post_id ? (int) $post_id : get_the_ID();
	$saida   = array();

	$mapa = array(
		'area_util'   => array( 'sufixo' => ' m²', 'rotulo' => 'Área útil' ),
		'dormitorios' => array( 'sufixo' => '', 'rotulo' => 'Dorm.' ),
		'suites'      => array( 'sufixo' => '', 'rotulo' => 'Suítes' ),
		'banheiros'   => array( 'sufixo' => '', 'rotulo' => 'Banheiros' ),
		'vagas'       => array( 'sufixo' => '', 'rotulo' => 'Vagas' ),
	);

	foreach ( $mapa as $chave => $config ) {
		$valor = fl_campo( $chave, $post_id );
		if ( '' === $valor || (float) $valor <= 0 ) {
			continue;
		}
		$saida[ $chave ] = array(
			'rotulo' => $config['rotulo'],
			'valor'  => rtrim( rtrim( number_format( (float) $valor, 2, ',', '.' ), '0' ), ',' ) . $config['sufixo'],
		);
	}

	return $saida;
}

/**
 * Características livres, uma por linha no campo.
 */
function fl_caracteristicas( $post_id = null ) {
	$bruto = fl_campo( 'caracteristicas', $post_id );
	if ( ! $bruto ) {
		return array();
	}
	$linhas = preg_split( '/\r\n|\r|\n/', $bruto );
	return array_values( array_filter( array_map( 'trim', $linhas ) ) );
}

/**
 * Dias entre a publicação e a venda — o número que a página /vendidos/ vende.
 */
function fl_dias_para_venda( $post_id = null ) {
	$post_id = $post_id ? (int) $post_id : get_the_ID();

	$data_venda = fl_campo( 'data_venda', $post_id );
	if ( ! $data_venda ) {
		return 0;
	}

	$inicio = fl_campo( 'data_captacao', $post_id );
	$inicio = $inicio ? strtotime( $inicio ) : get_post_time( 'U', true, $post_id );
	$fim    = strtotime( $data_venda );

	if ( ! $inicio || ! $fim || $fim <= $inicio ) {
		return 0;
	}

	return (int) round( ( $fim - $inicio ) / DAY_IN_SECONDS );
}

/**
 * Configurações de contato. Ficam em option para não precisar
 * mexer em código quando o número mudar.
 */
function fl_config( $chave, $padrao = '' ) {
	$padroes = array(
		'whatsapp' => '',
		'telefone' => '',
		'email'    => get_option( 'admin_email' ),
		'creci'    => '',
		'cidade'   => '',
		'uf'       => 'SP',
	);

	$valor = get_option( 'fl_config_' . $chave, null );
	if ( null === $valor || '' === $valor ) {
		return isset( $padroes[ $chave ] ) && '' !== $padroes[ $chave ] ? $padroes[ $chave ] : $padrao;
	}
	return $valor;
}

/**
 * Link de WhatsApp com mensagem pré-preenchida.
 */
function fl_link_whatsapp( $mensagem = '', $post_id = null ) {
	$numero = preg_replace( '/\D/', '', fl_config( 'whatsapp' ) );
	if ( ! $numero ) {
		return '';
	}
	if ( strlen( $numero ) <= 11 ) {
		$numero = '55' . $numero;
	}

	if ( ! $mensagem && $post_id ) {
		$codigo   = fl_campo( 'codigo', $post_id );
		$mensagem = sprintf(
			'Olá, Felipe. Tenho interesse no imóvel %s%s.',
			get_the_title( $post_id ),
			$codigo ? ' (ref. ' . $codigo . ')' : ''
		);
	}

	if ( ! $mensagem ) {
		$mensagem = 'Olá, Felipe. Vim pelo site.';
	}

	return 'https://wa.me/' . $numero . '?text=' . rawurlencode( $mensagem );
}

/**
 * URL de uma página do site pelo slug, com fallback para a home.
 */
function fl_url_pagina( $slug ) {
	$pagina = get_page_by_path( $slug );
	return $pagina ? get_permalink( $pagina ) : home_url( '/' . $slug . '/' );
}

/**
 * Números usados como prova social. Calculados de verdade, não chutados.
 */
function fl_estatisticas() {
	$cache = get_transient( 'fl_estatisticas' );
	if ( false !== $cache ) {
		return $cache;
	}

	$vendidos = get_posts(
		array(
			'post_type'      => 'imovel',
			'post_status'    => 'publish',
			'posts_per_page' => -1,
			'fields'         => 'ids',
			'meta_query'     => array(
				array(
					'key'   => 'fl_situacao',
					'value' => 'vendido',
				),
			),
		)
	);

	$dias   = array();
	$valores = array();

	foreach ( $vendidos as $id ) {
		$d = fl_dias_para_venda( $id );
		if ( $d > 0 ) {
			$dias[] = $d;
		}
		$v = (float) fl_campo( 'valor_venda', $id, fl_preco_numerico( $id ) );
		if ( $v > 0 ) {
			$valores[] = $v;
		}
	}

	$stats = array(
		'vendidos'     => count( $vendidos ),
		'dias_medio'   => $dias ? (int) round( array_sum( $dias ) / count( $dias ) ) : 0,
		'ticket_medio' => $valores ? array_sum( $valores ) / count( $valores ) : 0,
		'ativos'       => (int) wp_count_posts( 'imovel' )->publish - count( $vendidos ),
	);

	set_transient( 'fl_estatisticas', $stats, HOUR_IN_SECONDS );
	return $stats;
}

/**
 * Qualquer alteração em imóvel invalida o cache das estatísticas.
 */
add_action( 'save_post_imovel', function () { delete_transient( 'fl_estatisticas' ); } );
add_action( 'deleted_post', function () { delete_transient( 'fl_estatisticas' ); } );
