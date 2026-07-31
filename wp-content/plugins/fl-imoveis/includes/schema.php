<?php
/**
 * JSON-LD. O Rank Math cuida do resto do SEO; isso aqui é o que ele não sabe:
 * a ficha do imóvel e a identidade do corretor.
 */

defined( 'ABSPATH' ) || exit;

add_action( 'wp_head', 'fl_json_ld', 20 );

function fl_json_ld() {

	$grafo = array();

	$corretor = array(
		'@type' => 'RealEstateAgent',
		'@id'   => home_url( '/#corretor' ),
		'name'  => get_bloginfo( 'name' ),
		'url'   => home_url( '/' ),
	);

	if ( fl_config( 'cidade' ) ) {
		$corretor['areaServed'] = fl_config( 'cidade' );
	}
	if ( fl_config( 'telefone' ) ) {
		$corretor['telephone'] = fl_config( 'telefone' );
	}
	if ( fl_config( 'email' ) ) {
		$corretor['email'] = fl_config( 'email' );
	}
	if ( fl_config( 'creci' ) ) {
		$corretor['identifier'] = 'CRECI ' . fl_config( 'creci' );
	}
	if ( fl_config( 'cidade' ) ) {
		$corretor['address'] = array(
			'@type'           => 'PostalAddress',
			'addressLocality' => fl_config( 'cidade' ),
			'addressRegion'   => fl_config( 'uf' ),
			'addressCountry'  => 'BR',
		);
	}

	$grafo[] = $corretor;

	if ( is_singular( 'imovel' ) ) {
		$post_id = get_the_ID();

		$imovel = array(
			'@type'       => 'RealEstateListing',
			'@id'         => get_permalink() . '#imovel',
			'name'        => get_the_title(),
			'url'         => get_permalink(),
			'description' => wp_strip_all_tags( get_the_excerpt() ),
			'datePosted'  => get_the_date( 'c' ),
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

		$preco = fl_preco_numerico( $post_id );
		if ( $preco > 0 && ! fl_esta_vendido( $post_id ) ) {
			$imovel['offers'] = array(
				'@type'         => 'Offer',
				'price'         => $preco,
				'priceCurrency' => 'BRL',
				'availability'  => 'reservado' === fl_situacao( $post_id )
					? 'https://schema.org/LimitedAvailability'
					: 'https://schema.org/InStock',
			);
		}

		$local = array( '@type' => 'Place' );
		$bairro = get_the_terms( $post_id, 'imovel_bairro' );
		if ( $bairro && ! is_wp_error( $bairro ) ) {
			$local['address'] = array(
				'@type'           => 'PostalAddress',
				'addressLocality' => fl_campo( 'cidade', $post_id ),
				'addressRegion'   => fl_campo( 'uf', $post_id, 'SP' ),
				'addressCountry'  => 'BR',
				'name'            => $bairro[0]->name,
			);
			$imovel['containedInPlace'] = $local;
		}

		$area = (float) fl_campo( 'area_util', $post_id, 0 );
		if ( $area > 0 ) {
			$imovel['floorSize'] = array(
				'@type'    => 'QuantitativeValue',
				'value'    => $area,
				'unitCode' => 'MTK',
			);
		}

		foreach ( array( 'dormitorios' => 'numberOfBedrooms', 'banheiros' => 'numberOfBathroomsTotal' ) as $campo => $prop ) {
			$valor = (int) fl_campo( $campo, $post_id, 0 );
			if ( $valor > 0 ) {
				$imovel[ $prop ] = $valor;
			}
		}

		$grafo[] = $imovel;
	}

	$json = wp_json_encode(
		array(
			'@context' => 'https://schema.org',
			'@graph'   => $grafo,
		),
		JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
	);

	echo '<script type="application/ld+json">' . $json . '</script>' . "\n"; // phpcs:ignore WordPress.Security.EscapeOutput
}
