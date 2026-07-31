<?php
/**
 * Testes dos blocos de conteúdo da ficha — rodam sem WordPress.
 *
 *   php tools/testes/teste-conteudo.php
 *
 * Cobrem a resposta direta (o parágrafo que sistemas de IA extraem), a
 * tabela de especificações e o FAQ montado a partir dos campos. São
 * textos gerados: um erro aqui não quebra nada, só publica uma frase
 * errada em toda ficha do site — o pior tipo de bug.
 */

define( 'ABSPATH', __DIR__ . '/' );
define( 'FL_IMOVEIS_DIR', dirname( __DIR__, 2 ) . '/wp-content/plugins/fl-imoveis/' );
define( 'DAY_IN_SECONDS', 86400 );
define( 'HOUR_IN_SECONDS', 3600 );

/* ------------------------------------------------------------------
 * Banco falso: metadados, termos e opções
 * --------------------------------------------------------------- */

$GLOBALS['fl_meta']   = array();
$GLOBALS['fl_termos'] = array();
$GLOBALS['fl_opcoes'] = array();

function fl_teste_montar( $id, array $meta, array $termos = array() ) {
	$GLOBALS['fl_meta'][ $id ]   = $meta;
	$GLOBALS['fl_termos'][ $id ] = $termos;
}

function get_post_meta( $id, $chave, $unico = false ) {
	$valor = $GLOBALS['fl_meta'][ $id ][ $chave ] ?? ( $unico ? '' : array() );
	return $unico ? $valor : (array) $valor;
}

function get_the_terms( $id, $taxonomia ) {
	$termos = $GLOBALS['fl_termos'][ $id ][ $taxonomia ] ?? array();
	if ( ! $termos ) {
		return false;
	}
	return array_map(
		function ( $nome ) {
			return (object) array( 'name' => $nome, 'slug' => sanitize_title( $nome ) );
		},
		(array) $termos
	);
}

function get_option( $chave, $padrao = false ) {
	return $GLOBALS['fl_opcoes'][ $chave ] ?? $padrao;
}

function sanitize_title( $texto ) {
	return strtolower( preg_replace( '/[^a-z0-9]+/i', '-', iconv( 'UTF-8', 'ASCII//TRANSLIT', $texto ) ) );
}

function get_the_ID() { return 0; }
function current_time( $formato ) { return gmdate( $formato ); }
function get_post_time( $f, $gmt = false, $id = 0 ) { return strtotime( '2025-01-01' ); }
function has_post_thumbnail( $id = null ) { return false; }
function get_post_thumbnail_id( $id = null ) { return 0; }
function add_action() {}
function add_filter() {}
function get_transient( $k ) { return false; }
function set_transient( $k, $v, $t = 0 ) {}
function delete_transient( $k ) {}
function is_wp_error( $c ) { return false; }
function get_posts( $args = array() ) { return array(); }
function get_permalink( $id = 0 ) { return 'https://exemplo.test/imovel/x/'; }
function get_the_title( $id = 0 ) { return 'Imóvel'; }
function home_url( $c = '/' ) { return 'https://exemplo.test' . $c; }
function get_term_link( $t ) { return 'https://exemplo.test/bairro/x/'; }
function get_post_type_archive_link( $t ) { return 'https://exemplo.test/imoveis/'; }
function get_page_by_path( $s ) { return null; }

require_once FL_IMOVEIS_DIR . 'includes/helpers.php';

/* ------------------------------------------------------------------ */

$falhas = 0;
$totais = 0;

function checar( $rotulo, $obtido, $esperado ) {
	global $falhas, $totais;
	$totais++;
	$ok = ( $obtido === $esperado );
	if ( ! $ok ) {
		$falhas++;
	}
	printf( "  %s %s\n", $ok ? "\033[32mok \033[0m" : "\033[31mFALHA\033[0m", $rotulo );
	if ( ! $ok ) {
		printf( "        obtido ...: %s\n        esperado .: %s\n", var_export( $obtido, true ), var_export( $esperado, true ) );
	}
}

function contem( $rotulo, $agulha, $palheiro ) {
	global $falhas, $totais;
	$totais++;
	$ok = ( false !== mb_strpos( $palheiro, $agulha ) );
	if ( ! $ok ) {
		$falhas++;
	}
	printf( "  %s %s\n", $ok ? "\033[32mok \033[0m" : "\033[31mFALHA\033[0m", $rotulo );
	if ( ! $ok ) {
		printf( "        não achei \"%s\" em:\n        %s\n", $agulha, $palheiro );
	}
}

function titulo( $texto ) {
	echo "\n\033[1m" . $texto . "\033[0m\n";
}

$GLOBALS['fl_opcoes'] = array(
	'fl_config_nome'   => 'Felipe Luz',
	'fl_config_creci'  => 'CRECI/SP 266085-F',
	'fl_config_cidade' => 'Sorocaba',
	'fl_config_desde'  => '2023',
);

/* ================================================================== */

titulo( 'Utilitários de texto' );
checar( 'lista de um item', fl_lista_em_texto( array( 'a' ) ), 'a' );
checar( 'lista de dois', fl_lista_em_texto( array( 'a', 'b' ) ), 'a e b' );
checar( 'lista de três', fl_lista_em_texto( array( 'a', 'b', 'c' ) ), 'a, b e c' );
checar( 'lista vazia', fl_lista_em_texto( array() ), '' );
checar( 'número inteiro sem casas', fl_numero( 98.0 ), '98' );
checar( 'número com casas reais', fl_numero( 98.5 ), '98,5' );
checar( 'milhar com separador', fl_numero( 1250 ), '1.250' );

/* ================================================================== */

titulo( 'Resposta direta — apartamento à venda' );

fl_teste_montar(
	101,
	array(
		'fl_situacao'         => 'disponivel',
		'fl_preco'            => 1250000,
		'fl_area_util'        => 98,
		'fl_dormitorios'      => 3,
		'fl_suites'           => 1,
		'fl_banheiros'        => 2,
		'fl_vagas'            => 2,
		'fl_valor_condominio' => 980,
		'fl_valor_iptu'       => 3200,
		'fl_cidade'           => 'Sorocaba',
	),
	array(
		'imovel_tipo'       => 'Apartamento',
		'imovel_finalidade' => 'Venda',
		'imovel_bairro'     => 'Campolim',
	)
);

$resposta = fl_resposta_direta( 101 );
echo "        \033[2m" . $resposta . "\033[0m\n";

contem( 'diz o tipo', 'Apartamento', $resposta );
contem( 'diz a área', '98 m²', $resposta );
contem( 'diz a finalidade', 'à venda', $resposta );
contem( 'diz o bairro e a cidade', 'Campolim, Sorocaba', $resposta );
contem( 'diz dormitórios com suíte', '3 dormitórios (1 suíte)', $resposta );
contem( 'diz banheiros', '2 banheiros', $resposta );
contem( 'diz vagas', '2 vagas', $resposta );
contem( 'preço numérico explícito', 'R$ 1.250.000', $resposta );
contem( 'condomínio explícito', 'R$ 980 por mês', $resposta );
contem( 'IPTU explícito', 'R$ 3.200 por ano', $resposta );
contem( 'identifica o corretor com CRECI', 'Felipe Luz (CRECI/SP 266085-F)', $resposta );
checar( 'não diz "consulte"', false !== mb_stripos( $resposta, 'consult' ), false );

/* ================================================================== */

titulo( 'Resposta direta — casos de borda' );

fl_teste_montar( 102, array( 'fl_situacao' => 'disponivel', 'fl_preco' => 0, 'fl_dormitorios' => 1 ), array( 'imovel_tipo' => 'Terreno' ) );
$r2 = fl_resposta_direta( 102 );
echo "        \033[2m" . $r2 . "\033[0m\n";
contem( 'singular de dormitório', 'com 1 dormitório.', $r2 );
checar( 'sem preço, não inventa valor', false !== mb_strpos( $r2, 'R$' ), false );

fl_teste_montar(
	103,
	array( 'fl_situacao' => 'vendido', 'fl_preco' => 800000, 'fl_data_venda' => '2025-04-11', 'fl_data_captacao' => '2025-01-01' ),
	array( 'imovel_tipo' => 'Casa', 'imovel_bairro' => 'Jardim Emília' )
);
$r3 = fl_resposta_direta( 103 );
echo "        \033[2m" . $r3 . "\033[0m\n";
contem( 'vendido informa os dias', 'em 100 dias', $r3 );
checar( 'vendido não anuncia preço', false !== mb_strpos( $r3, 'R$' ), false );

fl_teste_montar( 104, array( 'fl_situacao' => 'disponivel', 'fl_preco' => 3500 ), array( 'imovel_tipo' => 'Sala comercial', 'imovel_finalidade' => 'Locação' ) );
$r4 = fl_resposta_direta( 104 );
echo "        \033[2m" . $r4 . "\033[0m\n";
contem( 'locação diz "para alugar"', 'para alugar', $r4 );
contem( 'locação diz "O aluguel é de"', 'O aluguel é de R$ 3.500', $r4 );

fl_teste_montar( 105, array( 'fl_resposta_direta' => 'Texto escrito à mão.' ) );
checar( 'texto manual tem prioridade', fl_resposta_direta( 105 ), 'Texto escrito à mão.' );

/* ================================================================== */

titulo( 'Tabela de especificações' );

$specs = fl_especificacoes( 101 );
checar( 'tipo na tabela', $specs['Tipo'] ?? '', 'Apartamento' );
checar( 'área sem casas inúteis', $specs['Área útil'] ?? '', '98 m²' );
checar( 'vagas', $specs['Vagas de garagem'] ?? '', '2' );
checar( 'preço formatado', $specs['Preço'] ?? '', 'R$ 1.250.000' );
checar( 'condomínio mensal', $specs['Condomínio (mensal)'] ?? '', 'R$ 980' );
checar( 'IPTU anual', $specs['IPTU (anual)'] ?? '', 'R$ 3.200' );
checar( 'situação', $specs['Situação'] ?? '', 'Disponível' );
checar( 'vendido não expõe preço na tabela', isset( fl_especificacoes( 103 )['Preço'] ), false );

/* ================================================================== */

titulo( 'FAQ montado a partir dos campos' );

fl_teste_montar(
	201,
	array(
		'fl_situacao'             => 'disponivel',
		'fl_valor_condominio'     => 780,
		'fl_aceita_financiamento' => 'sim',
		'fl_aceita_permuta'       => 'nao',
		'fl_ocupacao'             => 'desocupado',
		'fl_condominio_inclui'    => 'água, gás e portaria 24h',
		'fl_distancia_centro'     => 'cerca de 4 km, 10 minutos de carro',
		'fl_faq_extra'            => "Tem elevador? :: Sim, dois sociais e um de serviço.\nlinha invalida sem separador\n :: resposta sem pergunta",
	)
);

$faq = fl_faq_itens( 201 );

checar( 'quantidade de perguntas', count( $faq ), 6 );
checar( 'primeira pergunta é financiamento', $faq[0][0], 'Este imóvel aceita financiamento?' );
contem( 'resposta de financiamento afirmativa', 'Sim, este imóvel aceita financiamento', $faq[0][1] );
contem( 'permuta negada com clareza', 'não tem interesse em permuta', $faq[1][1] );
contem( 'condomínio soma valor e itens', 'R$ 780 por mês e inclui água, gás e portaria 24h', $faq[2][1] );
contem( 'desocupado fala de chaves', 'entrega das chaves é imediata', $faq[3][1] );
checar( 'distância usa a cidade configurada', $faq[4][0], 'Qual a distância até o centro de Sorocaba?' );
checar( 'pergunta livre entrou', $faq[5][0], 'Tem elevador?' );
checar( 'linha sem separador foi ignorada', count( array_filter( $faq, function ( $i ) { return 'linha invalida sem separador' === $i[0]; } ) ), 0 );
checar( 'linha sem pergunta foi ignorada', count( array_filter( $faq, function ( $i ) { return '' === $i[0]; } ) ), 0 );

fl_teste_montar( 202, array( 'fl_situacao' => 'disponivel' ) );
checar( 'sem campos preenchidos, sem FAQ', fl_faq_itens( 202 ), array() );

/* ================================================================== */

titulo( 'Anos de atuação' );
checar( 'calcula a partir do ano configurado', fl_anos_de_atuacao(), (int) gmdate( 'Y' ) - 2023 );
$GLOBALS['fl_opcoes']['fl_config_desde'] = '1500';
checar( 'ano absurdo é descartado', fl_anos_de_atuacao(), 0 );

/* ================================================================== */

printf(
	"\n%s %d verificações, %d falha(s).\n\n",
	$falhas ? "\033[31m✗\033[0m" : "\033[32m✓\033[0m",
	$totais,
	$falhas
);

exit( $falhas ? 1 : 0 );
