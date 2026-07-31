<?php
/**
 * Comandos WP-CLI.
 *
 *   wp fl inspecionar-xml --file=carteira.xml
 *   wp fl importar-xml    --file=carteira.xml --dry-run
 *   wp fl importar-xml    --file=carteira.xml --status=publish
 */

defined( 'ABSPATH' ) || exit;

class FL_Comandos {

	/**
	 * Mostra a estrutura do XML e o que o mapa atual consegue casar.
	 * Rode isto ANTES de importar.
	 *
	 * ## OPTIONS
	 *
	 * --file=<arquivo>
	 * : Caminho do XML.
	 *
	 * [--amostras=<n>]
	 * : Quantos registros exibir por extenso. Padrão: 1.
	 */
	public function inspecionar_xml( $args, $assoc ) {

		$arquivo = $assoc['file'] ?? '';
		if ( ! $arquivo ) {
			WP_CLI::error( 'Informe --file=caminho/do/arquivo.xml' );
		}

		try {
			$importador = new FL_Importador_XML( $arquivo );
			$relatorio  = $importador->inspecionar( (int) ( $assoc['amostras'] ?? 1 ) );
		} catch ( Exception $e ) {
			WP_CLI::error( $e->getMessage() );
		}

		WP_CLI::log( '' );
		WP_CLI::log( WP_CLI::colorize( '%9Estrutura%n' ) );
		WP_CLI::log( '  Raiz do XML .......: <' . $relatorio['raiz'] . '>' );
		WP_CLI::log( '  Nó do imóvel ......: <' . $relatorio['no_imovel'] . '>' );
		WP_CLI::log( '  Imóveis no arquivo : ' . $relatorio['total'] );
		WP_CLI::log( '  Fotos no 1º imóvel : ' . ( $relatorio['imagens_amostra'] ?? 0 ) );

		WP_CLI::log( '' );
		WP_CLI::log( WP_CLI::colorize( '%2Campos que o mapa já reconhece%n' ) );
		foreach ( $relatorio['mapeados'] as $campo => $valor ) {
			WP_CLI::log( sprintf( '  %-18s %s', $campo, $valor ) );
		}

		if ( $relatorio['faltando'] ) {
			WP_CLI::log( '' );
			WP_CLI::log( WP_CLI::colorize( '%3Campos sem correspondência (ajuste config/mapa-xml.php)%n' ) );
			WP_CLI::log( '  ' . implode( ', ', $relatorio['faltando'] ) );
		}

		WP_CLI::log( '' );
		WP_CLI::log( WP_CLI::colorize( '%9Todas as tags encontradas%n' ) );
		$linhas = array();
		foreach ( $relatorio['campos'] as $chave => $total ) {
			$linhas[] = array( 'tag' => $chave, 'ocorrencias' => $total );
		}
		WP_CLI\Utils\format_items( 'table', $linhas, array( 'tag', 'ocorrencias' ) );

		foreach ( $relatorio['amostras'] as $n => $amostra ) {
			WP_CLI::log( '' );
			WP_CLI::log( WP_CLI::colorize( '%9Amostra ' . ( $n + 1 ) . '%n' ) );
			foreach ( $amostra as $chave => $valor ) {
				WP_CLI::log( sprintf( '  %-40s %s', $chave, $valor ) );
			}
		}
	}

	/**
	 * Importa a carteira do XML para o CPT imovel.
	 *
	 * ## OPTIONS
	 *
	 * --file=<arquivo>
	 * : Caminho do XML.
	 *
	 * [--dry-run]
	 * : Não grava nada; só mostra o que faria.
	 *
	 * [--limite=<n>]
	 * : Importa apenas os N primeiros. Útil para testar.
	 *
	 * [--sem-imagens]
	 * : Não baixa as fotos.
	 *
	 * [--max-imagens=<n>]
	 * : Máximo de fotos por imóvel. Padrão: 30.
	 *
	 * [--status=<status>]
	 * : Status dos imóveis criados: draft (padrão) ou publish.
	 */
	public function importar_xml( $args, $assoc ) {

		$arquivo = $assoc['file'] ?? '';
		if ( ! $arquivo ) {
			WP_CLI::error( 'Informe --file=caminho/do/arquivo.xml' );
		}

		$dry_run = isset( $assoc['dry-run'] );
		$status  = in_array( $assoc['status'] ?? 'draft', array( 'draft', 'publish' ), true ) ? $assoc['status'] ?? 'draft' : 'draft';

		$importador = new FL_Importador_XML(
			$arquivo,
			array(
				'dry_run'     => $dry_run,
				'limite'      => (int) ( $assoc['limite'] ?? 0 ),
				'imagens'     => ! isset( $assoc['sem-imagens'] ),
				'max_imagens' => (int) ( $assoc['max-imagens'] ?? 30 ),
				'status'      => $status,
			)
		);

		if ( $dry_run ) {
			WP_CLI::warning( 'Modo simulação: nada será gravado.' );
		}

		$inicio = microtime( true );

		try {
			$resumo = $importador->importar();
		} catch ( Exception $e ) {
			WP_CLI::error( $e->getMessage() );
		}

		foreach ( $importador->log as $linha ) {
			WP_CLI::log( '  ' . $linha );
		}

		WP_CLI::log( '' );
		WP_CLI::success(
			sprintf(
				'%d criado(s), %d atualizado(s), %d foto(s), %d erro(s) em %.1fs.',
				$resumo['criados'],
				$resumo['atualizados'],
				$resumo['imagens'],
				$resumo['erros'],
				microtime( true ) - $inicio
			)
		);

		if ( ! $dry_run && 'draft' === $status ) {
			WP_CLI::log( 'Os imóveis entraram como rascunho. Revise e publique pelo painel, ou rode de novo com --status=publish.' );
		}
	}

	/**
	 * Cria as páginas fixas do site (home, quero vender, vendidos, sobre, contato)
	 * e aponta a home para a página certa.
	 */
	public function instalar_paginas() {

		$paginas = array(
			'inicio'       => array( 'Início', '' ),
			'quero-vender' => array( 'Quero vender meu imóvel', 'quero-vender.php' ),
			'vendidos'     => array( 'Vendidos', 'vendidos.php' ),
			'sobre'        => array( 'Sobre', 'sobre.php' ),
			'contato'      => array( 'Contato', 'contato.php' ),
		);

		$home_id = 0;

		foreach ( $paginas as $slug => $config ) {
			$existente = get_page_by_path( $slug );

			if ( $existente ) {
				$id = $existente->ID;
				WP_CLI::log( 'Já existia: /' . $slug . '/' );
			} else {
				$id = wp_insert_post(
					array(
						'post_type'   => 'page',
						'post_status' => 'publish',
						'post_title'  => $config[0],
						'post_name'   => $slug,
					)
				);
				WP_CLI::log( 'Criada: /' . $slug . '/' );
			}

			if ( $config[1] ) {
				update_post_meta( $id, '_wp_page_template', $config[1] );
			}

			if ( 'inicio' === $slug ) {
				$home_id = $id;
			}
		}

		if ( $home_id ) {
			update_option( 'show_on_front', 'page' );
			update_option( 'page_on_front', $home_id );
		}

		flush_rewrite_rules();
		WP_CLI::success( 'Páginas prontas. A home aponta para /inicio/ e usa front-page.php.' );
	}
}

WP_CLI::add_command(
	'fl',
	'FL_Comandos',
	array(
		'shortdesc' => 'Comandos do site Felipe Luz Broker.',
	)
);
