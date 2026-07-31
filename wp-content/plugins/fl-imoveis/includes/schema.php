<?php
/**
 * JSON-LD. O Rank Math cuida do resto do SEO; isso aqui é o que ele não sabe:
 * a ficha do imóvel, o FAQ e a identidade do corretor como entidade única.
 *
 * JSON-LD, nunca microdata.
 */

defined( 'ABSPATH' ) || exit;

add_action( 'wp_head', 'fl_json_ld', 20 );

function fl_json_ld() {

	$grafo = array( fl_schema_corretor() );

	if ( is_singular( 'imovel' ) ) {
		$grafo[] = fl_schema_imovel( get_the_ID() );
		$grafo[] = fl_schema_migalhas( get_the_ID() );

		$faq = fl_schema_faq( get_the_ID() );
		if ( $faq ) {
			$grafo[] = $faq;
		}
	}

	$json = wp_json_encode(
		array(
			'@context' => 'https://schema.org',
			'@graph'   => array_values( array_filter( $grafo ) ),
		),
		JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
	);

	echo '<script type="application/ld+json">' . $json . '</script>' . "\n"; // phpcs:ignore WordPress.Security.EscapeOutput
}

/**
 * RealEstateAgent. O sameAs é o que amarra site, Google Business Profile,
 * Instagram e LinkedIn como uma entidade só — divergir aqui fragmenta a
 * identidade e é o erro que mais custa em SEO local.
 */
function fl_schema_corretor() {

	$corretor = array(
		'@type' => 'RealEstateAgent',
		'@id'   => home_url( '/#corretor' ),
		'name'  => fl_config( 'nome' ),
		'url'   => home_url( '/' ),
	);

	$descricao = get_bloginfo( 'description' );
	if ( $descricao ) {
		$corretor['description'] = $descricao;
	}

	$retrato = fl_id_retrato();
	if ( $retrato ) {
		$corretor['image'] = wp_get_attachment_image_url( $retrato, 'full' );
	}

	if ( fl_config( 'cidade' ) ) {
		$corretor['areaServed'] = array(
			'@type' => 'City',
			'name'  => fl_config( 'cidade' ),
		);
		$corretor['address'] = array(
			'@type'           => 'PostalAddress',
			'addressLocality' => fl_config( 'cidade' ),
			'addressRegion'   => fl_config( 'uf' ),
			'addressCountry'  => 'BR',
		);
	}

	if ( fl_config( 'telefone' ) ) {
		$corretor['telephone'] = fl_config( 'telefone' );
	}
	if ( fl_config( 'email' ) ) {
		$corretor['email'] = fl_config( 'email' );
	}
	if ( fl_config( 'creci' ) ) {
		$corretor['identifier'] = fl_config( 'creci' );
	}

	$perfis = fl_perfis_externos();
	if ( $perfis ) {
		$corretor['sameAs'] = $perfis;
	}

	return $corretor;
}

/**
 * RealEstateListing + Offer + Residence.
 */
function fl_schema_imovel( $post_id ) {

	$imovel = array(
		'@type'       => 'RealEstateListing',
		'@id'         => get_permalink( $post_id ) . '#imovel',
		'name'        => get_the_title( $post_id ),
		'url'         => get_permalink( $post_id ),
		'description' => fl_resposta_direta( $post_id ),
		'datePosted'  => get_the_date( 'c', $post_id ),
		'provider'    => array( '@id' => home_url( '/#corretor' ) ),
	);

	$galeria = fl_galeria_ids( $post_id );
	if ( $galeria ) {
		$imagens = array();
		foreach ( array_slice( $galeria, 0, 6 ) as $id ) {
			$url = wp_get_attachment_image_url( $id, 'large' );
			if ( $url ) {
				$imagens[] = $url;
			}
		}
		if ( $imagens ) {
			$imovel['image'] = $imagens;
		}
	}

	/**
	 * Preço numérico explícito. "Consulte-nos" esvazia o offers.price e
	 * torna o imóvel invisível para qualquer sistema que precise do número.
	 */
	$preco = fl_preco_numerico( $post_id );
	if ( $preco > 0 && ! fl_esta_vendido( $post_id ) ) {
		$imovel['offers'] = array(
			'@type'         => 'Offer',
			'price'         => $preco,
			'priceCurrency' => 'BRL',
			'url'           => get_permalink( $post_id ),
			'availability'  => 'reservado' === fl_situacao( $post_id )
				? 'https://schema.org/LimitedAvailability'
				: 'https://schema.org/InStock',
			'seller'        => array( '@id' => home_url( '/#corretor' ) ),
		);
	}

	/* Residence: os atributos físicos do imóvel. */
	$residencia = array( '@type' => 'Residence', 'name' => get_the_title( $post_id ) );

	$bairros = get_the_terms( $post_id, 'imovel_bairro' );
	$endereco = array(
		'@type'          => 'PostalAddress',
		'addressCountry' => 'BR',
		'addressRegion'  => fl_campo( 'uf', $post_id, fl_config( 'uf' ) ),
	);
	$cidade = fl_campo( 'cidade', $post_id, fl_config( 'cidade' ) );
	if ( $cidade ) {
		$endereco['addressLocality'] = $cidade;
	}
	if ( $bairros && ! is_wp_error( $bairros ) ) {
		$endereco['addressArea'] = $bairros[0]->name;
	}
	$residencia['address'] = $endereco;

	$area = (float) fl_campo( 'area_util', $post_id, 0 );
	if ( $area > 0 ) {
		$residencia['floorSize'] = array(
			'@type'    => 'QuantitativeValue',
			'value'    => $area,
			'unitCode' => 'MTK',
		);
	}

	$comodos = (int) fl_campo( 'dormitorios', $post_id, 0 );
	if ( $comodos > 0 ) {
		$residencia['numberOfRooms']    = $comodos;
		$residencia['numberOfBedrooms'] = $comodos;
	}

	$banheiros = (int) fl_campo( 'banheiros', $post_id, 0 );
	if ( $banheiros > 0 ) {
		$residencia['numberOfBathroomsTotal'] = $banheiros;
	}

	$latitude  = fl_campo( 'latitude', $post_id );
	$longitude = fl_campo( 'longitude', $post_id );
	if ( $latitude && $longitude ) {
		$residencia['geo'] = array(
			'@type'     => 'GeoCoordinates',
			'latitude'  => (float) $latitude,
			'longitude' => (float) $longitude,
		);
	}

	$imovel['about'] = $residencia;

	return $imovel;
}

/**
 * FAQPage.
 *
 * O Google removeu o rich result de FAQ para a maioria dos sites em 2023 —
 * não espere estrela no resultado. O markup segue valendo como leitura por
 * máquina, e é aí que ele paga.
 */
function fl_schema_faq( $post_id ) {

	$itens = fl_faq_itens( $post_id );
	if ( ! $itens ) {
		return null;
	}

	$perguntas = array();
	foreach ( $itens as $item ) {
		$perguntas[] = array(
			'@type'          => 'Question',
			'name'           => $item[0],
			'acceptedAnswer' => array(
				'@type' => 'Answer',
				'text'  => $item[1],
			),
		);
	}

	return array(
		'@type'      => 'FAQPage',
		'@id'        => get_permalink( $post_id ) . '#faq',
		'mainEntity' => $perguntas,
	);
}

/**
 * BreadcrumbList — este ainda gera rich result.
 */
function fl_schema_migalhas( $post_id ) {

	$itens = array();
	foreach ( fl_migalhas( $post_id ) as $posicao => $migalha ) {
		$itens[] = array(
			'@type'    => 'ListItem',
			'position' => $posicao + 1,
			'name'     => $migalha[0],
			'item'     => $migalha[1],
		);
	}

	return array(
		'@type'           => 'BreadcrumbList',
		'@id'             => get_permalink( $post_id ) . '#migalhas',
		'itemListElement' => $itens,
	);
}

/**
 * Foto do corretor: definida em Configurações, usada no hero e no schema.
 */
function fl_id_retrato() {
	return (int) get_option( 'fl_config_retrato', 0 );
}
