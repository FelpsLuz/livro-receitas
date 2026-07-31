<?php
/**
 * Testes do parser do importador — rodam sem WordPress.
 *
 *   php tools/testes/teste-importador.php
 *
 * Cobrem as duas famílias de XML do mercado: feed de CRM (tags em
 * português, valores no formato brasileiro) e feed de portal
 * (tags em inglês, namespace declarado, muitas fotos e características).
 *
 * Quando o XML real da Code 49 chegar, jogue uma cópia anonimizada em
 * tools/testes/amostras/ e acrescente um bloco aqui. É o que impede
 * um ajuste no mapa de campos de quebrar outro formato.
 */

define( 'ABSPATH', __DIR__ . '/' );
define( 'FL_IMOVEIS_DIR', dirname( __DIR__, 2 ) . '/wp-content/plugins/fl-imoveis/' );

/* Stubs mínimos do WordPress usados pelo parser. */
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

/** Abre os métodos protegidos para inspeção. */
class FL_Sonda extends FL_Importador_XML {
	public function registros() {
		return $this->encontrar_registros( $this->carregar() );
	}
	public function plano( $no ) {
		return $this->achatar( $no );
	}
	public function campo( $plano, $nome, $todos = false ) {
		return $this->valor( $plano, $nome, $todos );
	}
	public function fotos( $plano ) {
		return $this->imagens( $plano );
	}
	public function num( $v ) {
		return $this->numero( $v );
	}
	public function tipo( $v ) {
		return $this->normalizar_tipo( $v );
	}
	public function finalidade( $v, $venda, $locacao ) {
		return $this->normalizar_finalidade( $v, $venda, $locacao );
	}
	public function situacao( $v ) {
		return $this->normalizar_situacao( $v );
	}
	public function bairro( $v ) {
		return $this->normalizar_bairro( $v );
	}
	public function converter_data( $v ) {
		return $this->data( $v );
	}
}

$falhas = 0;
$totais = 0;

function checar( $rotulo, $obtido, $esperado ) {
	global $falhas, $totais;
	$totais++;
	$ok = ( $obtido === $esperado );
	if ( ! $ok ) {
		$falhas++;
	}
	printf(
		"  %s %-44s %s\n",
		$ok ? "\033[32mok \033[0m" : "\033[31mFALHA\033[0m",
		$rotulo,
		$ok ? '' : sprintf( "obtido %s / esperado %s", var_export( $obtido, true ), var_export( $esperado, true ) )
	);
}

function titulo( $texto ) {
	echo "\n\033[1m" . $texto . "\033[0m\n";
}

$amostras = __DIR__ . '/amostras/';

/* =====================================================================
 * Feed estilo CRM: tags em português, preço no formato brasileiro
 * ================================================================== */

$sonda     = new FL_Sonda( $amostras . 'code49-estilo-crm.xml' );
$registros = $sonda->registros();

titulo( 'Feed de CRM — detecção de estrutura' );
checar( 'nó do imóvel', $registros[0]->getName(), 'Imovel' );
checar( 'quantidade de imóveis', count( $registros ), 3 );

$p1 = $sonda->plano( $registros[0] );
$p2 = $sonda->plano( $registros[1] );
$p3 = $sonda->plano( $registros[2] );

titulo( 'Feed de CRM — imóvel 1 (apartamento disponível)' );
checar( 'codigo', $sonda->campo( $p1, 'codigo' ), 'AP1042' );
checar( 'preco 1.250.000,00 vira float', $sonda->num( $sonda->campo( $p1, 'preco' ) ), 1250000.0 );
checar( 'condominio 980,00', $sonda->num( $sonda->campo( $p1, 'valor_condominio' ) ), 980.0 );
checar( 'iptu 3200,00', $sonda->num( $sonda->campo( $p1, 'valor_iptu' ) ), 3200.0 );
checar( 'QtdDormitorios -> dormitorios', $sonda->num( $sonda->campo( $p1, 'dormitorios' ) ), 3.0 );
checar( 'QtdSuites -> suites', $sonda->num( $sonda->campo( $p1, 'suites' ) ), 1.0 );
checar( 'QtdBanheiros -> banheiros', $sonda->num( $sonda->campo( $p1, 'banheiros' ) ), 2.0 );
checar( 'QtdVagas -> vagas', $sonda->num( $sonda->campo( $p1, 'vagas' ) ), 2.0 );
checar( 'area util', $sonda->num( $sonda->campo( $p1, 'area_util' ) ), 98.0 );
checar( 'area total nao vira area util', $sonda->num( $sonda->campo( $p1, 'area_total' ) ), 140.0 );
checar( 'cidade com acento', $sonda->campo( $p1, 'cidade' ), 'São Paulo' );
checar( 'cep', $sonda->campo( $p1, 'cep' ), '04101-000' );
checar( 'latitude negativa', $sonda->campo( $p1, 'latitude' ), '-23.5891' );
checar( 'descricao dentro de CDATA', $sonda->campo( $p1, 'descricao' ), 'Apartamento reformado, andar alto, vista livre. Prédio com lazer completo.' );
checar( 'Apartamento Padrão -> Apartamento', $sonda->tipo( $sonda->campo( $p1, 'tipo' ) ), 'Apartamento' );
checar( 'VILA MARIANA -> Vila Mariana', $sonda->bairro( $sonda->campo( $p1, 'bairro' ) ), 'Vila Mariana' );
checar( 'situacao disponivel', $sonda->situacao( $sonda->campo( $p1, 'situacao' ) ), 'disponivel' );
checar( 'video', $sonda->campo( $p1, 'video_url' ), 'https://www.youtube.com/watch?v=abc123' );

$fotos = $sonda->fotos( $p1 );
checar( 'total de fotos', count( $fotos ), 3 );
checar( 'foto principal em primeiro', $fotos[0] ?? '', 'https://cdn.exemplo.com.br/fotos/ap1042-01.jpg' );
checar( 'extensao .JPG maiuscula aceita', in_array( 'https://cdn.exemplo.com.br/fotos/ap1042-03.JPG', $fotos, true ), true );
checar( 'url de video fora da galeria', in_array( 'https://www.youtube.com/watch?v=abc123', $fotos, true ), false );
checar( 'caracteristicas em nós repetidos', count( (array) $sonda->campo( $p1, 'caracteristicas', true ) ), 3 );

titulo( 'Feed de CRM — imóvel 2 (vendido)' );
checar( 'codigo', $sonda->campo( $p2, 'codigo' ), 'CA0311' );
checar( 'preco sem separador', $sonda->num( $sonda->campo( $p2, 'preco' ) ), 2400000.0 );
checar( 'Sobrado -> Casa', $sonda->tipo( $sonda->campo( $p2, 'tipo' ) ), 'Casa' );
checar( 'situacao vendido', $sonda->situacao( $sonda->campo( $p2, 'situacao' ) ), 'vendido' );

titulo( 'Feed de CRM — imóvel 3 (locação)' );
checar( 'sem preco de venda', $sonda->num( $sonda->campo( $p3, 'preco' ) ), '' );
checar( 'preco de locacao', $sonda->num( $sonda->campo( $p3, 'preco_locacao' ) ), 8500.0 );
checar( 'Locacao -> Locação', $sonda->finalidade( $sonda->campo( $p3, 'finalidade' ), 0, 8500 ), 'Locação' );
checar( 'Sala Comercial -> Sala comercial', $sonda->tipo( $sonda->campo( $p3, 'tipo' ) ), 'Sala comercial' );
checar( 'sem situacao -> disponivel', $sonda->situacao( $sonda->campo( $p3, 'situacao' ) ), 'disponivel' );
checar( 'foto .webp aceita', count( $sonda->fotos( $p3 ) ), 1 );

titulo( 'Normalização de datas' );
checar( 'ISO com hora', $sonda->converter_data( '2025-03-14T10:30:00' ), '2025-03-14' );
checar( 'formato brasileiro', $sonda->converter_data( '14/03/2025' ), '2025-03-14' );
checar( 'brasileiro com hora', $sonda->converter_data( '14/03/2025 09:15' ), '2025-03-14' );
checar( 'timestamp unix', $sonda->converter_data( '1741910400' ), '2025-03-14' );
checar( 'vazio continua vazio', $sonda->converter_data( '' ), '' );
checar( 'lixo vira vazio', $sonda->converter_data( 'a definir' ), '' );

titulo( 'Finalidade deduzida pelo preço' );
checar( 'só preço de venda -> Venda', $sonda->finalidade( '', 500000, 0 ), 'Venda' );
checar( 'só aluguel -> Locação', $sonda->finalidade( '', 0, 3000 ), 'Locação' );
checar( 'sem nada -> Venda', $sonda->finalidade( '', 0, 0 ), 'Venda' );

/* =====================================================================
 * Feed estilo portal: namespace, tags em inglês, 40 características
 * e 25 fotos por imóvel — o caso que engana a detecção ingênua do
 * "nó que mais se repete".
 * ================================================================== */

titulo( 'Feed de portal — estrutura com nós repetidos internos' );

$relatorio = ( new FL_Importador_XML( $amostras . 'vivareal-estilo-portal.xml' ) )->inspecionar( 0 );

checar( 'nó do imóvel (não Caracteristica/Foto)', $relatorio['no_imovel'], 'Listing' );
checar( 'quantidade de imóveis', $relatorio['total'], 2 );
checar( 'fotos do primeiro imóvel', $relatorio['imagens_amostra'], 25 );

titulo( 'Feed de portal — campos reconhecidos' );
$esperados = array(
	'codigo'      => 'L001',
	'preco'       => '950000',
	'dormitorios' => '2',
	'banheiros'   => '2',
	'vagas'       => '1',
	'area_util'   => '85',
	'bairro'      => 'Moema',
	'cidade'      => 'Sao Paulo',
);
foreach ( $esperados as $campo => $valor ) {
	checar( 'campo ' . $campo, $relatorio['mapeados'][ $campo ] ?? '(não achou)', $valor );
}
checar( 'NumeroDormitorios reduz para dormitorios', isset( $relatorio['mapeados']['dormitorios'] ), true );
checar( 'Features/Caracteristica achado por segmento', isset( $relatorio['mapeados']['caracteristicas'] ), true );
checar( 'PropertyType achado', isset( $relatorio['mapeados']['tipo'] ), true );
checar( 'TransactionType achado', isset( $relatorio['mapeados']['finalidade'] ), true );

/* ================================================================== */

printf(
	"\n%s %d verificações, %d falha(s).\n\n",
	$falhas ? "\033[31m✗\033[0m" : "\033[32m✓\033[0m",
	$totais,
	$falhas
);

exit( $falhas ? 1 : 0 );
