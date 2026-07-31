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
		'nome'       => 'Felipe Luz',
		'papel'      => 'Personal Broker Imobiliário',
		'whatsapp'   => '',
		'telefone'   => '',
		'email'      => get_option( 'admin_email' ),
		'creci'      => 'CRECI/SP 266085-F',
		'cidade'     => 'Sorocaba',
		'uf'         => 'SP',
		'desde'      => '',
		'instagram'  => '',
		'linkedin'   => '',
		'google'     => '',
	);

	$valor = get_option( 'fl_config_' . $chave, null );
	if ( null === $valor || '' === $valor ) {
		return isset( $padroes[ $chave ] ) && '' !== $padroes[ $chave ] ? $padroes[ $chave ] : $padrao;
	}
	return $valor;
}

/**
 * sameAs do schema: é o que amarra o site, o Google Business Profile e as
 * redes como uma entidade só. Divergência aqui fragmenta a identidade.
 */
function fl_perfis_externos() {
	$perfis = array();
	foreach ( array( 'google', 'instagram', 'linkedin' ) as $rede ) {
		$url = fl_config( $rede );
		if ( $url && filter_var( $url, FILTER_VALIDATE_URL ) ) {
			$perfis[] = $url;
		}
	}
	return $perfis;
}

/**
 * "atuando desde 20XX" — número concreto exigido no momento da confiança.
 */
function fl_anos_de_atuacao() {
	$desde = (int) fl_config( 'desde', 0 );
	if ( $desde < 1980 || $desde > (int) current_time( 'Y' ) ) {
		return 0;
	}
	return (int) current_time( 'Y' ) - $desde;
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

/* ---------------------------------------------------------------------
 * Blocos da ficha — o material que sistemas de IA extraem
 * ------------------------------------------------------------------ */

/**
 * Bloco de resposta direta: 2 a 3 frases logo abaixo do título, com tipo,
 * bairro, cidade, área, dormitórios, vagas e o preço numérico.
 *
 * É o parágrafo que a IA recupera. Escrito como resposta de pergunta,
 * autocontido — quem lê só este trecho já sabe do que se trata.
 * Pode ser sobrescrito à mão no campo "Resposta direta".
 */
function fl_resposta_direta( $post_id = null ) {
	$post_id = $post_id ? (int) $post_id : get_the_ID();

	$manual = fl_campo( 'resposta_direta', $post_id );
	if ( $manual ) {
		return $manual;
	}

	$tipo       = fl_tipo_nome( $post_id );
	$finalidade = fl_finalidade_nome( $post_id );
	$local      = fl_localizacao( $post_id );
	$area       = (float) fl_campo( 'area_util', $post_id, 0 );
	$dorm       = (int) fl_campo( 'dormitorios', $post_id, 0 );
	$suites     = (int) fl_campo( 'suites', $post_id, 0 );
	$banheiros  = (int) fl_campo( 'banheiros', $post_id, 0 );
	$vagas      = (int) fl_campo( 'vagas', $post_id, 0 );

	/* Frase 1 — o que é, onde fica, qual o tamanho. */
	$primeira = $tipo;
	if ( $area > 0 ) {
		$primeira .= ' de ' . fl_numero( $area ) . ' m²';
	}
	$primeira .= ( 'Locação' === $finalidade ) ? ' para alugar' : ' à venda';
	if ( $local ) {
		$primeira .= ' em ' . $local;
	}

	$comodos = array();
	if ( $dorm > 0 ) {
		$comodos[] = $dorm . ( 1 === $dorm ? ' dormitório' : ' dormitórios' )
			. ( $suites > 0 ? ' (' . $suites . ( 1 === $suites ? ' suíte' : ' suítes' ) . ')' : '' );
	}
	if ( $banheiros > 0 ) {
		$comodos[] = $banheiros . ( 1 === $banheiros ? ' banheiro' : ' banheiros' );
	}
	if ( $vagas > 0 ) {
		$comodos[] = $vagas . ( 1 === $vagas ? ' vaga' : ' vagas' );
	}
	if ( $comodos ) {
		$primeira .= ', com ' . fl_lista_em_texto( $comodos );
	}
	$primeira .= '.';

	/* Frase 2 — os números de dinheiro, explícitos. */
	$segunda = '';
	if ( fl_esta_vendido( $post_id ) ) {
		$dias    = fl_dias_para_venda( $post_id );
		$segunda = 'Este imóvel já foi vendido'
			. ( $dias > 0 ? ', em ' . $dias . ' dias entre a captação e a assinatura' : '' ) . '.';
	} else {
		$preco = fl_preco_numerico( $post_id );
		$custos = array();
		$cond   = (float) fl_campo( 'valor_condominio', $post_id, 0 );
		$iptu   = (float) fl_campo( 'valor_iptu', $post_id, 0 );
		if ( $cond > 0 ) {
			$custos[] = 'condomínio de ' . fl_valor_brl( $cond ) . ' por mês';
		}
		if ( $iptu > 0 ) {
			$custos[] = 'IPTU de ' . fl_valor_brl( $iptu ) . ' por ano';
		}

		if ( $preco > 0 ) {
			$segunda = ( 'Locação' === $finalidade ? 'O aluguel é de ' : 'O preço é ' ) . fl_valor_brl( $preco );
			$segunda .= $custos ? ', com ' . fl_lista_em_texto( $custos ) . '.' : '.';
		} elseif ( $custos ) {
			$segunda = 'Tem ' . fl_lista_em_texto( $custos ) . '.';
		}
	}

	/* Frase 3 — quem responde. */
	$terceira = 'O atendimento é direto com ' . fl_config( 'nome' )
		. ( fl_config( 'creci' ) ? ' (' . fl_config( 'creci' ) . ')' : '' ) . '.';

	return trim( implode( ' ', array_filter( array( $primeira, $segunda, $terceira ) ) ) );
}

/**
 * "a, b e c" — junção em português, não a lista com vírgula do inglês.
 */
function fl_lista_em_texto( array $itens ) {
	$itens = array_values( array_filter( $itens ) );
	if ( ! $itens ) {
		return '';
	}
	if ( 1 === count( $itens ) ) {
		return $itens[0];
	}
	$ultimo = array_pop( $itens );
	return implode( ', ', $itens ) . ' e ' . $ultimo;
}

/**
 * Número sem casas decimais inúteis: 98 e não 98,00.
 */
function fl_numero( $valor ) {
	$valor = (float) $valor;
	return rtrim( rtrim( number_format( $valor, 2, ',', '.' ), '0' ), ',' );
}

/**
 * Tabela de especificações. Tabela é o formato que LLM extrai melhor —
 * por isso os dados vão em <table>, não em parágrafo.
 */
function fl_especificacoes( $post_id = null ) {
	$post_id = $post_id ? (int) $post_id : get_the_ID();
	$linhas  = array();

	$codigo = fl_campo( 'codigo', $post_id );
	if ( $codigo ) {
		$linhas['Referência'] = $codigo;
	}

	$linhas['Tipo'] = fl_tipo_nome( $post_id );

	$finalidade = fl_finalidade_nome( $post_id );
	if ( $finalidade ) {
		$linhas['Finalidade'] = $finalidade;
	}

	$local = fl_localizacao( $post_id );
	if ( $local ) {
		$linhas['Localização'] = $local;
	}

	$numericos = array(
		'area_util'   => array( 'Área útil', ' m²' ),
		'area_total'  => array( 'Área total', ' m²' ),
		'dormitorios' => array( 'Dormitórios', '' ),
		'suites'      => array( 'Suítes', '' ),
		'banheiros'   => array( 'Banheiros', '' ),
		'vagas'       => array( 'Vagas de garagem', '' ),
	);

	foreach ( $numericos as $campo => $config ) {
		$valor = (float) fl_campo( $campo, $post_id, 0 );
		if ( $valor > 0 ) {
			$linhas[ $config[0] ] = fl_numero( $valor ) . $config[1];
		}
	}

	$condominio = fl_campo( 'condominio', $post_id );
	if ( $condominio ) {
		$linhas['Condomínio'] = $condominio;
	}

	$ano = (int) fl_campo( 'ano_construcao', $post_id, 0 );
	if ( $ano > 1800 ) {
		$linhas['Ano de construção'] = $ano;
	}

	if ( ! fl_esta_vendido( $post_id ) ) {
		$linhas['Preço'] = fl_preco( $post_id );

		foreach ( array( 'valor_condominio' => array( 'Condomínio (mensal)', '/mês' ), 'valor_iptu' => array( 'IPTU (anual)', '/ano' ) ) as $campo => $config ) {
			$valor = (float) fl_campo( $campo, $post_id, 0 );
			if ( $valor > 0 ) {
				$linhas[ $config[0] ] = fl_valor_brl( $valor );
			}
		}
	}

	$linhas['Situação'] = fl_situacao_rotulo( $post_id );

	return $linhas;
}

/**
 * FAQ da ficha. Montado dos campos estruturados — o corretor responde
 * cinco perguntinhas no painel e o bloco sai pronto, junto com o
 * FAQPage do schema. Sem escrever prosa, sem esquecer nenhuma.
 */
function fl_faq_itens( $post_id = null ) {
	$post_id = $post_id ? (int) $post_id : get_the_ID();
	$itens   = array();

	$financiamento = fl_campo( 'aceita_financiamento', $post_id );
	if ( $financiamento ) {
		$respostas = array(
			'sim'       => 'Sim, este imóvel aceita financiamento bancário. A documentação já foi conferida para isso.',
			'nao'       => 'Não. Este imóvel é negociado apenas à vista ou com parcelamento direto.',
			'consultar' => 'Depende da condição do comprador e do banco. Me chame que eu verifico caso a caso.',
		);
		if ( isset( $respostas[ $financiamento ] ) ) {
			$itens[] = array( 'Este imóvel aceita financiamento?', $respostas[ $financiamento ] );
		}
	}

	$permuta = fl_campo( 'aceita_permuta', $post_id );
	if ( $permuta ) {
		$respostas = array(
			'sim'       => 'Sim, o proprietário avalia permuta por outro imóvel.',
			'nao'       => 'Não. O proprietário não tem interesse em permuta neste imóvel.',
			'consultar' => 'O proprietário avalia propostas de permuta conforme o imóvel oferecido.',
		);
		if ( isset( $respostas[ $permuta ] ) ) {
			$itens[] = array( 'O proprietário aceita permuta?', $respostas[ $permuta ] );
		}
	}

	$inclui = fl_campo( 'condominio_inclui', $post_id );
	$valor_cond = (float) fl_campo( 'valor_condominio', $post_id, 0 );
	if ( $inclui && $valor_cond > 0 ) {
		$itens[] = array(
			'O que está incluído no condomínio?',
			'O condomínio é de ' . fl_valor_brl( $valor_cond ) . ' por mês e inclui ' . rtrim( $inclui, '.' ) . '.',
		);
	} elseif ( $inclui ) {
		$itens[] = array( 'O que está incluído no condomínio?', $inclui );
	}

	$ocupacao = fl_campo( 'ocupacao', $post_id );
	if ( $ocupacao ) {
		$respostas = array(
			'desocupado' => 'Sim, o imóvel está desocupado e a entrega das chaves é imediata após a assinatura.',
			'proprietario' => 'O imóvel está ocupado pelo proprietário. A desocupação é combinada na negociação.',
			'inquilino'  => 'O imóvel está alugado. O prazo de desocupação depende do contrato vigente e é informado na proposta.',
		);
		if ( isset( $respostas[ $ocupacao ] ) ) {
			$itens[] = array( 'O imóvel está desocupado?', $respostas[ $ocupacao ] );
		}
	}

	$distancia = fl_campo( 'distancia_centro', $post_id );
	if ( $distancia ) {
		$itens[] = array(
			'Qual a distância até o centro de ' . fl_config( 'cidade' ) . '?',
			$distancia,
		);
	}

	/* Perguntas livres, uma por linha: "Pergunta :: Resposta". */
	$extras = fl_campo( 'faq_extra', $post_id );
	if ( $extras ) {
		foreach ( preg_split( '/\r\n|\r|\n/', $extras ) as $linha ) {
			$partes = array_map( 'trim', explode( '::', $linha, 2 ) );
			if ( count( $partes ) === 2 && '' !== $partes[0] && '' !== $partes[1] ) {
				$itens[] = array( $partes[0], $partes[1] );
			}
		}
	}

	return $itens;
}

/**
 * Alt descritivo de verdade. Usa o alt do anexo se alguém escreveu um;
 * senão monta "Apartamento no Campolim, Sorocaba — foto 2 de 12", que já
 * é infinitamente melhor que "foto-1.jpg".
 */
function fl_alt_foto( $anexo_id, $post_id, $indice = 0, $total = 0 ) {
	$alt = trim( (string) get_post_meta( $anexo_id, '_wp_attachment_image_alt', true ) );
	if ( $alt ) {
		return $alt;
	}

	$alt = fl_tipo_nome( $post_id );
	$local = fl_localizacao( $post_id );
	if ( $local ) {
		$alt .= ' em ' . $local;
	}
	if ( $total > 1 ) {
		$alt .= ' — foto ' . ( $indice + 1 ) . ' de ' . $total;
	}
	return $alt;
}

/**
 * Migalhas de pão. Alimentam o BreadcrumbList, que continua gerando
 * rich result — diferente do FAQ, que o Google aposentou em 2023.
 */
function fl_migalhas( $post_id = null ) {
	$post_id  = $post_id ? (int) $post_id : get_the_ID();
	$migalhas = array( array( 'Início', home_url( '/' ) ) );

	if ( fl_esta_vendido( $post_id ) ) {
		$migalhas[] = array( 'Vendidos', fl_url_pagina( 'vendidos' ) );
	} else {
		$migalhas[] = array( 'Imóveis', get_post_type_archive_link( 'imovel' ) );
	}

	$bairros = get_the_terms( $post_id, 'imovel_bairro' );
	if ( $bairros && ! is_wp_error( $bairros ) ) {
		$migalhas[] = array( $bairros[0]->name, get_term_link( $bairros[0] ) );
	}

	$migalhas[] = array( get_the_title( $post_id ), get_permalink( $post_id ) );

	return $migalhas;
}

/**
 * Avaliações reais, cadastradas a partir do Google Business Profile.
 */
function fl_avaliacoes( $quantidade = 3 ) {
	return get_posts(
		array(
			'post_type'      => 'fl_avaliacao',
			'post_status'    => 'publish',
			'posts_per_page' => $quantidade,
			'orderby'        => 'menu_order date',
			'order'          => 'ASC',
		)
	);
}

/**
 * Qualquer alteração em imóvel invalida o cache das estatísticas.
 */
add_action( 'save_post_imovel', function () { delete_transient( 'fl_estatisticas' ); } );
add_action( 'deleted_post', function () { delete_transient( 'fl_estatisticas' ); } );
