<?php
/**
 * Importador de XML.
 *
 * Escrito para ser tolerante ao formato: acha sozinho o nó que se repete,
 * achata a árvore e casa os campos por sufixo do caminho. Quando o XML da
 * Code 49 chegar, o ajuste fino acontece em config/mapa-xml.php.
 */

defined( 'ABSPATH' ) || exit;

class FL_Importador_XML {

	protected $arquivo;
	protected $mapa;
	protected $opcoes;
	public    $log = array();

	public function __construct( $arquivo, $opcoes = array() ) {
		$this->arquivo = $arquivo;
		$this->opcoes  = wp_parse_args(
			$opcoes,
			array(
				'dry_run'      => false,
				'limite'       => 0,
				'imagens'      => true,
				'max_imagens'  => 30,
				'status'       => 'draft',
			)
		);
		$this->mapa = include FL_IMOVEIS_DIR . 'config/mapa-xml.php';
	}

	/* ---------------------------------------------------------------
	 * Leitura
	 * ------------------------------------------------------------- */

	protected function carregar() {
		if ( ! file_exists( $this->arquivo ) ) {
			throw new Exception( 'Arquivo não encontrado: ' . $this->arquivo );
		}

		$anterior = libxml_use_internal_errors( true );
		$xml      = simplexml_load_file( $this->arquivo, 'SimpleXMLElement', LIBXML_NOCDATA | LIBXML_NOBLANKS );

		if ( false === $xml ) {
			$erros = array_map( function ( $e ) { return trim( $e->message ); }, libxml_get_errors() );
			libxml_clear_errors();
			libxml_use_internal_errors( $anterior );
			throw new Exception( 'XML inválido: ' . implode( ' | ', array_slice( $erros, 0, 3 ) ) );
		}

		libxml_use_internal_errors( $anterior );
		return $xml;
	}

	/**
	 * Encontra o nó que se repete — é ele que representa um imóvel.
	 * Vale para <Imoveis><Imovel>, <ListingDataFeed><Listings><Listing>, etc.
	 *
	 * Contar repetição sozinha não basta: um imóvel com 40 características
	 * repetidas venceria uma lista de 30 imóveis. O peso é repetições ×
	 * tamanho da subárvore — um <Imovel> carrega dezenas de nós dentro de
	 * si, uma <Caracteristica> carrega um. Em caso de empate vence o mais
	 * raso, porque a varredura processa cada nível antes de descer.
	 */
	protected function encontrar_registros( SimpleXMLElement $xml ) {
		$melhor       = null;
		$melhor_score = 0;

		$peso = function ( SimpleXMLElement $no, $profundidade = 0 ) use ( &$peso ) {
			if ( $profundidade > 8 ) {
				return 1;
			}
			$total = 1;
			foreach ( $no->children() as $filho ) {
				$total += $peso( $filho, $profundidade + 1 );
			}
			return $total;
		};

		$visitar = function ( SimpleXMLElement $no, $profundidade ) use ( &$visitar, &$melhor, &$melhor_score, $peso ) {
			if ( $profundidade > 6 ) {
				return;
			}

			$contagem = array();
			foreach ( $no->children() as $filho ) {
				$nome = $filho->getName();
				$contagem[ $nome ] = ( $contagem[ $nome ] ?? 0 ) + 1;
			}

			foreach ( $contagem as $nome => $total ) {
				if ( $total < 2 ) {
					continue;
				}

				$grupo = $no->{$nome};
				$score = $total * $peso( $grupo[0] );

				if ( $score > $melhor_score ) {
					$melhor_score = $score;
					$melhor       = $grupo;
				}
			}

			foreach ( $no->children() as $filho ) {
				if ( count( $filho->children() ) ) {
					$visitar( $filho, $profundidade + 1 );
				}
			}
		};

		$visitar( $xml, 0 );

		// XML com um único imóvel: o próprio nó raiz serve.
		if ( ! $melhor ) {
			$primeiro = $xml->children();
			$melhor   = count( $primeiro ) ? $primeiro : $xml;
		}

		return $melhor;
	}

	/**
	 * Transforma a árvore em array plano: 'imovel.detalhes.dormitorios' => '3'.
	 * Tags repetidas viram array.
	 */
	protected function achatar( SimpleXMLElement $no, $prefixo = '', &$saida = array() ) {

		foreach ( $no->attributes() as $nome => $valor ) {
			$this->guardar( $saida, $prefixo . '@' . strtolower( $nome ), trim( (string) $valor ) );
		}

		foreach ( $no->children() as $filho ) {
			$chave = $prefixo . strtolower( $filho->getName() );

			if ( count( $filho->children() ) ) {
				$this->achatar( $filho, $chave . '.', $saida );
				foreach ( $filho->attributes() as $nome => $valor ) {
					$this->guardar( $saida, $chave . '@' . strtolower( $nome ), trim( (string) $valor ) );
				}
				continue;
			}

			$this->guardar( $saida, $chave, trim( (string) $filho ) );

			foreach ( $filho->attributes() as $nome => $valor ) {
				$this->guardar( $saida, $chave . '@' . strtolower( $nome ), trim( (string) $valor ) );
			}
		}

		return $saida;
	}

	protected function guardar( &$saida, $chave, $valor ) {
		if ( '' === $valor ) {
			return;
		}
		if ( ! isset( $saida[ $chave ] ) ) {
			$saida[ $chave ] = $valor;
			return;
		}
		if ( ! is_array( $saida[ $chave ] ) ) {
			$saida[ $chave ] = array( $saida[ $chave ] );
		}
		$saida[ $chave ][] = $valor;
	}

	/**
	 * Busca o valor de um campo canônico dentro do registro achatado.
	 *
	 * Três passadas, da mais restrita à mais frouxa — só desce de nível
	 * quando a anterior não achou nada:
	 *   1. folha exata ....... <QtdVagas> casa com o candidato "qtdvagas"
	 *   2. folha reduzida .... <QtdDormitorios> casa com "dormitorios"
	 *   3. segmento .......... <Caracteristicas><Item> casa com "caracteristicas"
	 */
	protected function valor( array $registro, $campo, $todos = false ) {

		$candidatos = array_map(
			array( $this, 'normalizar_chave' ),
			$this->mapa[ $campo ] ?? array( $campo )
		);

		foreach ( array( 'folha', 'folha_reduzida', 'segmento' ) as $estrategia ) {
			$achados = $this->buscar( $registro, $candidatos, $estrategia );
			if ( $achados ) {
				return $todos ? $achados : $achados[0];
			}
		}

		return $todos ? array() : '';
	}

	/**
	 * A ordem dos candidatos é prioridade: o primeiro que casar vence,
	 * para "precovenda" ganhar de "preco" quando ambos existirem.
	 */
	protected function buscar( array $registro, array $candidatos, $estrategia ) {

		foreach ( $candidatos as $candidato ) {
			$achados = array();

			foreach ( $registro as $chave => $valor ) {
				if ( ! $this->casa( $chave, $candidato, $estrategia ) ) {
					continue;
				}
				foreach ( (array) $valor as $v ) {
					if ( '' !== $v ) {
						$achados[] = $v;
					}
				}
			}

			if ( $achados ) {
				return $achados;
			}
		}

		return array();
	}

	protected function casa( $chave, $candidato, $estrategia ) {

		$segmentos = preg_split( '/[.@]/', $chave );
		$folha     = $this->normalizar_chave( (string) end( $segmentos ) );

		if ( 'folha' === $estrategia ) {
			return $folha === $candidato;
		}

		if ( 'folha_reduzida' === $estrategia ) {
			return $this->reduzir_chave( $folha ) === $this->reduzir_chave( $candidato );
		}

		foreach ( $segmentos as $segmento ) {
			if ( $this->normalizar_chave( $segmento ) === $candidato ) {
				return true;
			}
		}

		return false;
	}

	protected function normalizar_chave( $texto ) {
		return preg_replace( '/[^a-z0-9]/', '', strtolower( (string) $texto ) );
	}

	/**
	 * Tira os prefixos de contagem: "qtd", "qtde", "numerode", "num"…
	 * É o que faz <QtdDormitorios>, <NumeroDormitorios> e <Dormitorios>
	 * caírem todos no mesmo campo.
	 */
	protected function reduzir_chave( $chave ) {
		$reduzida = preg_replace( '/^(quantidadede|quantidade|numerode|numero|qtde|qtd|nro|num|nr|qt)/', '', $chave );
		return ( '' === $reduzida ) ? $chave : $reduzida;
	}

	/**
	 * URLs de imagem: qualquer valor que pareça uma foto.
	 */
	protected function imagens( array $registro ) {
		$urls = array();

		foreach ( $registro as $chave => $valor ) {
			foreach ( (array) $valor as $v ) {
				if ( ! preg_match( '#^https?://#i', $v ) ) {
					continue;
				}
				$caminho = strtolower( (string) wp_parse_url( $v, PHP_URL_PATH ) );
				$e_foto  = preg_match( '/\.(jpe?g|png|webp|avif)$/i', $caminho )
					|| preg_match( '/(foto|imagem|image|photo|midia|media)/i', $chave );

				if ( $e_foto && ! preg_match( '/(video|youtube|vimeo|tour)/i', $chave . $v ) ) {
					$urls[] = $v;
				}
			}
		}

		return array_values( array_unique( $urls ) );
	}

	protected function numero( $valor ) {
		if ( '' === $valor || null === $valor ) {
			return '';
		}
		$valor = (string) $valor;
		// "1.250.000,00" e "1250000.00" devem dar o mesmo número.
		if ( strpos( $valor, ',' ) !== false ) {
			$valor = str_replace( array( '.', ' ' ), '', $valor );
			$valor = str_replace( ',', '.', $valor );
		}
		$valor = preg_replace( '/[^0-9.\-]/', '', $valor );
		return ( '' === $valor ) ? '' : (float) $valor;
	}

	/**
	 * Normaliza data para Y-m-d, que é o formato que os campos gravam.
	 * Aceita ISO, "31/12/2025" e timestamps.
	 */
	protected function data( $valor ) {
		$valor = trim( (string) $valor );
		if ( '' === $valor ) {
			return '';
		}

		if ( preg_match( '#^(\d{2})/(\d{2})/(\d{4})#', $valor, $m ) ) {
			return $m[3] . '-' . $m[2] . '-' . $m[1];
		}

		if ( preg_match( '/^\d{9,11}$/', $valor ) ) {
			return gmdate( 'Y-m-d', (int) $valor );
		}

		$tempo = strtotime( $valor );
		return $tempo ? gmdate( 'Y-m-d', $tempo ) : '';
	}

	protected function booleano( $valor ) {
		$valor = strtolower( trim( (string) $valor ) );
		return in_array( $valor, array( '1', 'true', 'sim', 's', 'yes', 'y' ), true ) ? 1 : 0;
	}

	/* ---------------------------------------------------------------
	 * Inspeção — rode isso primeiro, com o XML real em mãos
	 * ------------------------------------------------------------- */

	public function inspecionar( $amostras = 2 ) {
		$xml       = $this->carregar();
		$registros = $this->encontrar_registros( $xml );

		$relatorio = array(
			'raiz'      => $xml->getName(),
			'no_imovel' => $registros ? $registros[0]->getName() : '?',
			'total'     => count( $registros ),
			'campos'    => array(),
			'amostras'  => array(),
			'mapeados'  => array(),
			'faltando'  => array(),
		);

		$i = 0;
		foreach ( $registros as $registro ) {
			$plano = $this->achatar( $registro );

			foreach ( $plano as $chave => $valor ) {
				$relatorio['campos'][ $chave ] = ( $relatorio['campos'][ $chave ] ?? 0 ) + 1;
			}

			if ( $i < $amostras ) {
				$relatorio['amostras'][] = array_map(
					function ( $v ) {
						$v = is_array( $v ) ? implode( ' | ', array_slice( $v, 0, 3 ) ) . ( count( $v ) > 3 ? ' …(' . count( $v ) . ')' : '' ) : $v;
						return mb_substr( (string) $v, 0, 90 );
					},
					$plano
				);
			}

			if ( 0 === $i ) {
				foreach ( array_keys( $this->mapa ) as $campo ) {
					$valor = $this->valor( $plano, $campo );
					if ( '' !== $valor ) {
						$relatorio['mapeados'][ $campo ] = mb_substr( (string) $valor, 0, 60 );
					} else {
						$relatorio['faltando'][] = $campo;
					}
				}
				$relatorio['imagens_amostra'] = count( $this->imagens( $plano ) );
			}

			$i++;
		}

		arsort( $relatorio['campos'] );
		return $relatorio;
	}

	/* ---------------------------------------------------------------
	 * Importação
	 * ------------------------------------------------------------- */

	public function importar( $progresso = null ) {

		$xml       = $this->carregar();
		$registros = $this->encontrar_registros( $xml );

		$resumo = array( 'criados' => 0, 'atualizados' => 0, 'ignorados' => 0, 'imagens' => 0, 'erros' => 0 );
		$i      = 0;

		foreach ( $registros as $registro ) {

			if ( $this->opcoes['limite'] && $i >= $this->opcoes['limite'] ) {
				break;
			}
			$i++;

			try {
				$plano     = $this->achatar( $registro );
				$resultado = $this->importar_registro( $plano );

				$resumo[ $resultado['acao'] ]++;
				$resumo['imagens'] += $resultado['imagens'];

				$this->log[] = sprintf(
					'%s: %s (%s) — %d foto(s)',
					strtoupper( substr( $resultado['acao'], 0, 4 ) ),
					$resultado['titulo'],
					$resultado['codigo'] ?: 's/ ref.',
					$resultado['imagens']
				);
			} catch ( Exception $e ) {
				$resumo['erros']++;
				$this->log[] = 'ERRO no registro ' . $i . ': ' . $e->getMessage();
			}

			if ( is_callable( $progresso ) ) {
				call_user_func( $progresso, $i );
			}
		}

		if ( ! $this->opcoes['dry_run'] ) {
			delete_transient( 'fl_estatisticas' );
		}

		return $resumo;
	}

	protected function importar_registro( array $plano ) {

		$codigo    = (string) $this->valor( $plano, 'codigo' );
		$tipo      = $this->normalizar_tipo( (string) $this->valor( $plano, 'tipo' ) );
		$bairro    = (string) $this->valor( $plano, 'bairro' );
		$descricao = (string) $this->valor( $plano, 'descricao' );

		$preco_venda   = $this->numero( $this->valor( $plano, 'preco' ) );
		$preco_locacao = $this->numero( $this->valor( $plano, 'preco_locacao' ) );
		$dormitorios   = $this->numero( $this->valor( $plano, 'dormitorios' ) );

		$finalidade = $this->normalizar_finalidade(
			(string) $this->valor( $plano, 'finalidade' ),
			$preco_venda,
			$preco_locacao
		);

		$titulo = (string) $this->valor( $plano, 'titulo' );
		if ( ! $titulo ) {
			$titulo = trim(
				sprintf(
					'%s%s%s',
					$tipo ?: 'Imóvel',
					$dormitorios ? ' com ' . (int) $dormitorios . ' dormitório' . ( $dormitorios > 1 ? 's' : '' ) : '',
					$bairro ? ' no ' . $bairro : ''
				)
			);
		}

		$existente = $this->encontrar_existente( $codigo, $titulo );

		if ( $this->opcoes['dry_run'] ) {
			return array(
				'acao'    => $existente ? 'atualizados' : 'criados',
				'titulo'  => $titulo,
				'codigo'  => $codigo,
				'imagens' => count( $this->imagens( $plano ) ),
			);
		}

		$dados = array(
			'post_type'    => 'imovel',
			'post_title'   => wp_strip_all_tags( $titulo ),
			'post_content' => wp_kses_post( $descricao ),
			'post_status'  => $existente ? get_post_status( $existente ) : $this->opcoes['status'],
		);

		if ( $existente ) {
			$dados['ID'] = $existente;
			$post_id     = wp_update_post( $dados, true );
			$acao        = 'atualizados';
		} else {
			$post_id = wp_insert_post( $dados, true );
			$acao    = 'criados';
		}

		if ( is_wp_error( $post_id ) ) {
			throw new Exception( $post_id->get_error_message() );
		}

		$preco = $preco_venda ?: $preco_locacao;

		$metas = array(
			'codigo'           => $codigo,
			'preco'            => $preco ?: 0,
			'situacao'         => $this->normalizar_situacao( (string) $this->valor( $plano, 'situacao' ) ),
			'dormitorios'      => $dormitorios,
			'suites'           => $this->numero( $this->valor( $plano, 'suites' ) ),
			'banheiros'        => $this->numero( $this->valor( $plano, 'banheiros' ) ),
			'vagas'            => $this->numero( $this->valor( $plano, 'vagas' ) ),
			'area_util'        => $this->numero( $this->valor( $plano, 'area_util' ) ),
			'area_total'       => $this->numero( $this->valor( $plano, 'area_total' ) ),
			'valor_condominio' => $this->numero( $this->valor( $plano, 'valor_condominio' ) ),
			'valor_iptu'       => $this->numero( $this->valor( $plano, 'valor_iptu' ) ),
			'cidade'           => (string) $this->valor( $plano, 'cidade' ),
			'uf'               => (string) $this->valor( $plano, 'uf' ),
			'cep'              => (string) $this->valor( $plano, 'cep' ),
			'endereco'         => (string) $this->valor( $plano, 'endereco' ),
			'condominio'       => (string) $this->valor( $plano, 'condominio' ),
			'latitude'         => (string) $this->valor( $plano, 'latitude' ),
			'longitude'        => (string) $this->valor( $plano, 'longitude' ),
			'ano_construcao'   => $this->numero( $this->valor( $plano, 'ano_construcao' ) ),
			'video_url'        => (string) $this->valor( $plano, 'video_url' ),
			'tour_url'         => (string) $this->valor( $plano, 'tour_url' ),
			'exclusividade'    => $this->booleano( $this->valor( $plano, 'exclusividade' ) ),
			'destaque'         => $this->booleano( $this->valor( $plano, 'destaque' ) ),
			'data_venda'       => $this->data( $this->valor( $plano, 'data_venda' ) ),
			'data_captacao'    => $this->data( $this->valor( $plano, 'data_captacao' ) ),
		);

		$caracteristicas = $this->valor( $plano, 'caracteristicas', true );
		if ( $caracteristicas ) {
			$metas['caracteristicas'] = implode( "\n", array_unique( (array) $caracteristicas ) );
		}

		foreach ( $metas as $chave => $valor ) {
			if ( '' === $valor || null === $valor ) {
				continue;
			}
			update_post_meta( $post_id, 'fl_' . $chave, $valor );
		}

		update_post_meta( $post_id, 'fl_importado_em', current_time( 'mysql' ) );

		if ( $tipo ) {
			wp_set_object_terms( $post_id, $tipo, 'imovel_tipo' );
		}
		if ( $finalidade ) {
			wp_set_object_terms( $post_id, $finalidade, 'imovel_finalidade' );
		}
		if ( $bairro ) {
			wp_set_object_terms( $post_id, $this->normalizar_bairro( $bairro ), 'imovel_bairro' );
		}

		$total_imagens = 0;
		if ( $this->opcoes['imagens'] ) {
			$total_imagens = $this->importar_imagens( $post_id, $this->imagens( $plano ) );
		}

		return array(
			'acao'    => $acao,
			'titulo'  => $titulo,
			'codigo'  => $codigo,
			'imagens' => $total_imagens,
		);
	}

	protected function encontrar_existente( $codigo, $titulo ) {
		if ( $codigo ) {
			$achados = get_posts(
				array(
					'post_type'      => 'imovel',
					'post_status'    => 'any',
					'posts_per_page' => 1,
					'fields'         => 'ids',
					'meta_query'     => array(
						array( 'key' => 'fl_codigo', 'value' => $codigo ),
					),
				)
			);
			if ( $achados ) {
				return (int) $achados[0];
			}
		}

		$pagina = get_page_by_title( $titulo, OBJECT, 'imovel' );
		return $pagina ? (int) $pagina->ID : 0;
	}

	/**
	 * Baixa as fotos para a biblioteca de mídia. Idempotente: se o imóvel
	 * já tem galeria, não baixa de novo (reimportar 30 imóveis não deve
	 * gerar 900 anexos duplicados).
	 */
	protected function importar_imagens( $post_id, array $urls ) {

		if ( ! $urls ) {
			return 0;
		}

		$existentes = get_post_meta( $post_id, 'fl_galeria', false );
		if ( $existentes ) {
			return 0;
		}

		require_once ABSPATH . 'wp-admin/includes/media.php';
		require_once ABSPATH . 'wp-admin/includes/file.php';
		require_once ABSPATH . 'wp-admin/includes/image.php';

		$urls  = array_slice( $urls, 0, (int) $this->opcoes['max_imagens'] );
		$total = 0;

		foreach ( $urls as $url ) {
			$anexo_id = media_sideload_image( $url, $post_id, null, 'id' );

			if ( is_wp_error( $anexo_id ) ) {
				$this->log[] = 'Foto falhou (' . $url . '): ' . $anexo_id->get_error_message();
				continue;
			}

			add_post_meta( $post_id, 'fl_galeria', $anexo_id );

			if ( 0 === $total ) {
				set_post_thumbnail( $post_id, $anexo_id );
			}

			$total++;
		}

		return $total;
	}

	/* ---------------------------------------------------------------
	 * Normalização
	 * ------------------------------------------------------------- */

	protected function normalizar_tipo( $bruto ) {
		$bruto = trim( $bruto );
		if ( ! $bruto ) {
			return '';
		}

		$chave = strtolower( remove_accents( $bruto ) );

		$mapa = array(
			'apartamento'   => 'Apartamento',
			'apto'          => 'Apartamento',
			'flat'          => 'Apartamento',
			'kitnet'        => 'Apartamento',
			'studio'        => 'Apartamento',
			'cobertura'     => 'Cobertura',
			'casa de condominio' => 'Casa em condomínio',
			'casa em condominio' => 'Casa em condomínio',
			'sobrado'       => 'Casa',
			'casa'          => 'Casa',
			'terreno'       => 'Terreno',
			'lote'          => 'Terreno',
			'area'          => 'Terreno',
			'sala'          => 'Sala comercial',
			'conjunto'      => 'Sala comercial',
			'comercial'     => 'Sala comercial',
			'galpao'        => 'Galpão',
			'chacara'       => 'Chácara',
			'sitio'         => 'Chácara',
			'fazenda'       => 'Chácara',
		);

		foreach ( $mapa as $agulha => $nome ) {
			if ( false !== strpos( $chave, $agulha ) ) {
				return $nome;
			}
		}

		return ucfirst( mb_strtolower( $bruto ) );
	}

	protected function normalizar_finalidade( $bruto, $preco_venda, $preco_locacao ) {
		$chave = strtolower( remove_accents( trim( $bruto ) ) );

		if ( preg_match( '/(loca|alug|rent)/', $chave ) ) {
			return 'Locação';
		}
		if ( preg_match( '/(vend|sale|compra)/', $chave ) ) {
			return 'Venda';
		}

		if ( $preco_venda > 0 ) {
			return 'Venda';
		}
		if ( $preco_locacao > 0 ) {
			return 'Locação';
		}

		return 'Venda';
	}

	protected function normalizar_situacao( $bruto ) {
		$chave = strtolower( remove_accents( trim( $bruto ) ) );

		if ( preg_match( '/(vendid|sold)/', $chave ) ) {
			return 'vendido';
		}
		if ( preg_match( '/(reserv|proposta)/', $chave ) ) {
			return 'reservado';
		}
		return 'disponivel';
	}

	protected function normalizar_bairro( $bruto ) {
		$bruto = trim( preg_replace( '/\s+/', ' ', $bruto ) );
		return mb_convert_case( mb_strtolower( $bruto ), MB_CASE_TITLE, 'UTF-8' );
	}
}
