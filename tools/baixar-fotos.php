<?php
/**
 * Baixa todas as fotos referenciadas no XML, antes de cancelar a Code 49.
 *
 * Roda sem WordPress — é o backup bruto da carteira, independente do site.
 * Faça isso ANTES de qualquer cancelamento: quando o contrato encerra,
 * o CDN das fotos costuma sair do ar junto.
 *
 *   php tools/baixar-fotos.php carteira.xml fotos/
 *   php tools/baixar-fotos.php carteira.xml fotos/ --listar
 *
 * As fotos saem organizadas por referência do imóvel:
 *   fotos/AP1042/01.jpg, fotos/AP1042/02.jpg, …
 *
 * Também grava fotos/indice.csv com referência, ordem e URL de origem —
 * é o mapa que permite reconstruir a galeria se algo der errado.
 */

define( 'ABSPATH', __DIR__ . '/' );
define( 'FL_IMOVEIS_DIR', dirname( __DIR__ ) . '/wp-content/plugins/fl-imoveis/' );

function wp_parse_args( $args, $padroes ) {
	return array_merge( $padroes, (array) $args );
}
function wp_parse_url( $url, $componente = -1 ) {
	return parse_url( $url, $componente );
}
function remove_accents( $texto ) {
	return iconv( 'UTF-8', 'ASCII//TRANSLIT', $texto );
}

require_once FL_IMOVEIS_DIR . 'includes/importer.php';

class FL_Coletor extends FL_Importador_XML {
	/** @return array lista de ['codigo' => string, 'urls' => string[]] */
	public function coletar() {
		$saida = array();
		foreach ( $this->encontrar_registros( $this->carregar() ) as $registro ) {
			$plano    = $this->achatar( $registro );
			$saida[]  = array(
				'codigo' => (string) $this->valor( $plano, 'codigo' ),
				'urls'   => $this->imagens( $plano ),
			);
		}
		return $saida;
	}
}

/* ------------------------------------------------------------------ */

$argumentos = array_slice( $argv, 1 );
$opcoes     = array_values( array_filter( $argumentos, function ( $a ) { return 0 === strpos( $a, '--' ); } ) );
$posicional = array_values( array_filter( $argumentos, function ( $a ) { return 0 !== strpos( $a, '--' ); } ) );

$xml     = $posicional[0] ?? '';
$destino = rtrim( $posicional[1] ?? 'fotos', '/' );
$listar  = in_array( '--listar', $opcoes, true );

if ( ! $xml ) {
	fwrite( STDERR, "uso: php tools/baixar-fotos.php <arquivo.xml> [pasta-destino] [--listar]\n" );
	exit( 1 );
}

try {
	$imoveis = ( new FL_Coletor( $xml ) )->coletar();
} catch ( Exception $e ) {
	fwrite( STDERR, 'Erro: ' . $e->getMessage() . "\n" );
	exit( 1 );
}

$total_fotos = array_sum( array_map( function ( $i ) { return count( $i['urls'] ); }, $imoveis ) );

printf( "%d imóveis, %d fotos no XML.\n\n", count( $imoveis ), $total_fotos );

if ( $listar ) {
	foreach ( $imoveis as $imovel ) {
		printf( "%-12s %d foto(s)\n", $imovel['codigo'] ?: '(sem ref.)', count( $imovel['urls'] ) );
		foreach ( $imovel['urls'] as $url ) {
			echo '   ' . $url . "\n";
		}
	}
	exit( 0 );
}

if ( ! is_dir( $destino ) && ! mkdir( $destino, 0775, true ) ) {
	fwrite( STDERR, "Não consegui criar a pasta $destino\n" );
	exit( 1 );
}

$indice = fopen( $destino . '/indice.csv', 'w' );
fputcsv( $indice, array( 'referencia', 'ordem', 'arquivo', 'url_origem', 'status' ) );

$baixadas = 0;
$falhas   = 0;

foreach ( $imoveis as $n => $imovel ) {

	$codigo = $imovel['codigo'] ?: 'imovel-' . str_pad( $n + 1, 3, '0', STR_PAD_LEFT );
	$pasta  = $destino . '/' . preg_replace( '/[^A-Za-z0-9_-]/', '', $codigo );

	if ( ! is_dir( $pasta ) ) {
		mkdir( $pasta, 0775, true );
	}

	printf( "%-12s ", $codigo );

	foreach ( $imovel['urls'] as $ordem => $url ) {

		$extensao = strtolower( pathinfo( (string) parse_url( $url, PHP_URL_PATH ), PATHINFO_EXTENSION ) );
		$extensao = preg_match( '/^(jpe?g|png|webp|avif|gif)$/', $extensao ) ? $extensao : 'jpg';
		$nome     = str_pad( $ordem + 1, 2, '0', STR_PAD_LEFT ) . '.' . $extensao;
		$caminho  = $pasta . '/' . $nome;

		if ( file_exists( $caminho ) && filesize( $caminho ) > 0 ) {
			echo '·';
			fputcsv( $indice, array( $codigo, $ordem + 1, $nome, $url, 'ja-existia' ) );
			continue;
		}

		$contexto = stream_context_create(
			array(
				'http' => array(
					'timeout'    => 30,
					'user_agent' => 'Mozilla/5.0 (compatible; backup-carteira/1.0)',
				),
				'ssl'  => array( 'verify_peer' => true, 'verify_peer_name' => true ),
			)
		);

		$conteudo = @file_get_contents( $url, false, $contexto );

		if ( false === $conteudo || strlen( $conteudo ) < 512 ) {
			echo 'x';
			$falhas++;
			fputcsv( $indice, array( $codigo, $ordem + 1, $nome, $url, 'falhou' ) );
			continue;
		}

		file_put_contents( $caminho, $conteudo );
		echo '.';
		$baixadas++;
		fputcsv( $indice, array( $codigo, $ordem + 1, $nome, $url, 'ok' ) );

		usleep( 150000 ); // 150ms entre downloads: não derruba o servidor de origem
	}

	echo "\n";
}

fclose( $indice );

printf(
	"\n%d foto(s) baixada(s), %d falha(s). Índice em %s/indice.csv\n",
	$baixadas,
	$falhas,
	$destino
);

if ( $falhas ) {
	echo "As falhas estão marcadas no CSV. Rode de novo — o que já baixou é pulado.\n";
}

exit( $falhas ? 2 : 0 );
