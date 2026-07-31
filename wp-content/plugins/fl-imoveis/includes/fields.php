<?php
/**
 * Campos do imóvel via Meta Box (versão gratuita).
 * Todos os tipos usados aqui existem no core do Meta Box — nada de extensão paga.
 */

defined( 'ABSPATH' ) || exit;

add_filter( 'rwmb_meta_boxes', 'fl_registrar_campos' );

function fl_registrar_campos( $meta_boxes ) {

	$p = FL_PREFIXO;

	$meta_boxes[] = array(
		'id'         => 'fl_imovel_principal',
		'title'      => 'Dados do imóvel',
		'post_types' => array( 'imovel' ),
		'context'    => 'normal',
		'priority'   => 'high',
		'fields'     => array(
			array(
				'name'    => 'Situação',
				'id'      => $p . 'situacao',
				'type'    => 'select',
				'options' => fl_situacoes(),
				'std'     => 'disponivel',
				'columns' => 3,
				'desc'    => 'Vendido alimenta a página /vendidos/ automaticamente.',
			),
			array(
				'name'    => 'Referência',
				'id'      => $p . 'codigo',
				'type'    => 'text',
				'columns' => 3,
			),
			array(
				'name'    => 'Preço (R$)',
				'id'      => $p . 'preco',
				'type'    => 'number',
				'step'    => '0.01',
				'min'     => 0,
				'columns' => 3,
			),
			array(
				'name'    => 'Preço sob consulta',
				'id'      => $p . 'preco_sob_consulta',
				'type'    => 'checkbox',
				'columns' => 3,
			),
			array(
				'name'    => 'Destaque na home',
				'id'      => $p . 'destaque',
				'type'    => 'checkbox',
				'columns' => 4,
			),
			array(
				'name'    => 'Exclusividade',
				'id'      => $p . 'exclusividade',
				'type'    => 'checkbox',
				'columns' => 4,
			),
			array(
				'name'    => 'Aceita permuta',
				'id'      => $p . 'permuta',
				'type'    => 'checkbox',
				'columns' => 4,
			),
		),
	);

	$meta_boxes[] = array(
		'id'         => 'fl_imovel_ficha',
		'title'      => 'Ficha técnica',
		'post_types' => array( 'imovel' ),
		'fields'     => array(
			array(
				'name'    => 'Dormitórios',
				'id'      => $p . 'dormitorios',
				'type'    => 'number',
				'min'     => 0,
				'columns' => 2,
			),
			array(
				'name'    => 'Suítes',
				'id'      => $p . 'suites',
				'type'    => 'number',
				'min'     => 0,
				'columns' => 2,
			),
			array(
				'name'    => 'Banheiros',
				'id'      => $p . 'banheiros',
				'type'    => 'number',
				'min'     => 0,
				'columns' => 2,
			),
			array(
				'name'    => 'Vagas',
				'id'      => $p . 'vagas',
				'type'    => 'number',
				'min'     => 0,
				'columns' => 2,
			),
			array(
				'name'    => 'Área útil (m²)',
				'id'      => $p . 'area_util',
				'type'    => 'number',
				'step'    => '0.01',
				'min'     => 0,
				'columns' => 2,
			),
			array(
				'name'    => 'Área total (m²)',
				'id'      => $p . 'area_total',
				'type'    => 'number',
				'step'    => '0.01',
				'min'     => 0,
				'columns' => 2,
			),
			array(
				'name'    => 'Condomínio (R$/mês)',
				'id'      => $p . 'valor_condominio',
				'type'    => 'number',
				'step'    => '0.01',
				'min'     => 0,
				'columns' => 3,
			),
			array(
				'name'    => 'IPTU (R$/ano)',
				'id'      => $p . 'valor_iptu',
				'type'    => 'number',
				'step'    => '0.01',
				'min'     => 0,
				'columns' => 3,
			),
			array(
				'name'    => 'Nome do condomínio',
				'id'      => $p . 'condominio',
				'type'    => 'text',
				'columns' => 3,
			),
			array(
				'name'    => 'Ano de construção',
				'id'      => $p . 'ano_construcao',
				'type'    => 'number',
				'min'     => 1900,
				'columns' => 3,
			),
			array(
				'name'    => 'Características',
				'id'      => $p . 'caracteristicas',
				'type'    => 'textarea',
				'rows'    => 6,
				'desc'    => 'Uma por linha. Ex.: Varanda gourmet',
			),
		),
	);

	$meta_boxes[] = array(
		'id'         => 'fl_imovel_local',
		'title'      => 'Localização',
		'post_types' => array( 'imovel' ),
		'fields'     => array(
			array(
				'name'    => 'Cidade',
				'id'      => $p . 'cidade',
				'type'    => 'text',
				'columns' => 4,
			),
			array(
				'name'    => 'UF',
				'id'      => $p . 'uf',
				'type'    => 'text',
				'std'     => 'SP',
				'columns' => 2,
			),
			array(
				'name'    => 'CEP',
				'id'      => $p . 'cep',
				'type'    => 'text',
				'columns' => 3,
			),
			array(
				'name'    => 'Endereço (uso interno)',
				'id'      => $p . 'endereco',
				'type'    => 'text',
				'columns' => 3,
				'desc'    => 'Não é exibido no site.',
			),
			array(
				'name'    => 'Latitude',
				'id'      => $p . 'latitude',
				'type'    => 'text',
				'columns' => 3,
			),
			array(
				'name'    => 'Longitude',
				'id'      => $p . 'longitude',
				'type'    => 'text',
				'columns' => 3,
			),
		),
	);

	$meta_boxes[] = array(
		'id'         => 'fl_imovel_midia',
		'title'      => 'Fotos e mídia',
		'post_types' => array( 'imovel' ),
		'fields'     => array(
			array(
				'name'             => 'Galeria',
				'id'               => $p . 'galeria',
				'type'             => 'image_advanced',
				'max_file_uploads' => 40,
				'desc'             => 'A primeira foto é a capa se não houver imagem destacada.',
			),
			array(
				'name'    => 'Vídeo (YouTube/Vimeo)',
				'id'      => $p . 'video_url',
				'type'    => 'url',
				'columns' => 6,
			),
			array(
				'name'    => 'Tour 360º',
				'id'      => $p . 'tour_url',
				'type'    => 'url',
				'columns' => 6,
			),
		),
	);

	/**
	 * O bloco que faz o SEO e alimenta os sistemas de IA.
	 * Cinco perguntas respondidas aqui viram o FAQ da ficha e o FAQPage
	 * do schema — sem ninguém precisar escrever prosa.
	 */
	$meta_boxes[] = array(
		'id'         => 'fl_imovel_conteudo',
		'title'      => 'Conteúdo para busca e IA',
		'post_types' => array( 'imovel' ),
		'fields'     => array(
			array(
				'name' => 'Resposta direta',
				'id'   => $p . 'resposta_direta',
				'type' => 'textarea',
				'rows' => 3,
				'desc' => 'Deixe em branco: o site monta sozinho a partir dos campos (tipo, área, dormitórios, vagas, preço). Preencha só quando quiser um texto diferente. É o parágrafo que a IA extrai.',
			),
			array(
				'name'    => 'Aceita financiamento?',
				'id'      => $p . 'aceita_financiamento',
				'type'    => 'select',
				'options' => array(
					''          => '— não exibir —',
					'sim'       => 'Sim',
					'nao'       => 'Não',
					'consultar' => 'Depende do caso',
				),
				'columns' => 4,
			),
			array(
				'name'    => 'Aceita permuta?',
				'id'      => $p . 'aceita_permuta',
				'type'    => 'select',
				'options' => array(
					''          => '— não exibir —',
					'sim'       => 'Sim',
					'nao'       => 'Não',
					'consultar' => 'Avalia propostas',
				),
				'columns' => 4,
			),
			array(
				'name'    => 'Ocupação',
				'id'      => $p . 'ocupacao',
				'type'    => 'select',
				'options' => array(
					''             => '— não exibir —',
					'desocupado'   => 'Desocupado',
					'proprietario' => 'Ocupado pelo proprietário',
					'inquilino'    => 'Alugado',
				),
				'columns' => 4,
			),
			array(
				'name'    => 'O condomínio inclui',
				'id'      => $p . 'condominio_inclui',
				'type'    => 'text',
				'columns' => 6,
				'desc'    => 'Ex.: água, gás, portaria 24h e manutenção do lazer',
			),
			array(
				'name'    => 'Distância até o centro',
				'id'      => $p . 'distancia_centro',
				'type'    => 'text',
				'columns' => 6,
				'desc'    => 'Ex.: cerca de 4 km, 10 minutos de carro',
			),
			array(
				'name' => 'Outras perguntas',
				'id'   => $p . 'faq_extra',
				'type' => 'textarea',
				'rows' => 5,
				'desc' => 'Uma por linha, no formato <code>Pergunta :: Resposta</code>. Ex.: <code>Tem elevador? :: Sim, dois elevadores sociais e um de serviço.</code>',
			),
		),
	);

	$meta_boxes[] = array(
		'id'         => 'fl_imovel_venda',
		'title'      => 'Registro da venda',
		'post_types' => array( 'imovel' ),
		'context'    => 'side',
		'fields'     => array(
			array(
				'name' => 'Data de captação',
				'id'   => $p . 'data_captacao',
				'type' => 'date',
				'js_options' => array( 'dateFormat' => 'yy-mm-dd' ),
				'desc' => 'Base do cálculo "vendido em X dias". Sem ela usa a data de publicação.',
			),
			array(
				'name' => 'Data da venda',
				'id'   => $p . 'data_venda',
				'type' => 'date',
				'js_options' => array( 'dateFormat' => 'yy-mm-dd' ),
			),
			array(
				'name' => 'Valor da venda (R$)',
				'id'   => $p . 'valor_venda',
				'type' => 'number',
				'step' => '0.01',
				'min'  => 0,
				'desc' => 'Uso interno. Entra só na média, nunca aparece isolado.',
			),
			array(
				'name' => 'Depoimento do cliente',
				'id'   => $p . 'depoimento',
				'type' => 'textarea',
				'rows' => 4,
			),
			array(
				'name' => 'Autor do depoimento',
				'id'   => $p . 'depoimento_autor',
				'type' => 'text',
			),
		),
	);

	$meta_boxes[] = array(
		'id'         => 'fl_avaliacao_dados',
		'title'      => 'Dados da avaliação',
		'post_types' => array( 'fl_avaliacao' ),
		'fields'     => array(
			array(
				'name'    => 'Nota',
				'id'      => $p . 'nota',
				'type'    => 'select',
				'options' => array( '5' => '5 estrelas', '4' => '4 estrelas', '3' => '3 estrelas' ),
				'std'     => '5',
				'columns' => 3,
			),
			array(
				'name'    => 'Origem',
				'id'      => $p . 'origem',
				'type'    => 'select',
				'options' => array(
					'google'    => 'Google',
					'instagram' => 'Instagram',
					'direto'    => 'Enviado direto',
				),
				'std'     => 'google',
				'columns' => 3,
			),
			array(
				'name'    => 'Data',
				'id'      => $p . 'data',
				'type'    => 'date',
				'js_options' => array( 'dateFormat' => 'yy-mm-dd' ),
				'columns' => 3,
			),
			array(
				'name'    => 'Link da avaliação',
				'id'      => $p . 'url',
				'type'    => 'url',
				'columns' => 3,
				'desc'    => 'Link público no Google, se houver.',
			),
		),
	);

	return $meta_boxes;
}
