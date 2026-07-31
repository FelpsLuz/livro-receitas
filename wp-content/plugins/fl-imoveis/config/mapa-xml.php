<?php
/**
 * Mapa de campos do XML.
 *
 * Cada chave é um campo do site; o valor é a lista de nomes de tag
 * que podem carregar esse dado no XML de origem. A busca é
 * case-insensitive e funciona por sufixo do caminho achatado,
 * então "Imovel.Detalhes.Dormitorios" casa com "dormitorios".
 *
 * Os nomes abaixo cobrem os padrões mais comuns do mercado brasileiro
 * (VivaReal/ZAP, ImovelWeb, OLX e variações de CRM). Quando o XML da
 * Code 49 chegar, rode `wp fl inspecionar-xml` e ajuste esta lista —
 * é o único arquivo que precisa mudar.
 */

defined( 'ABSPATH' ) || exit;

return array(

	'codigo' => array( 'codigo', 'codigoimovel', 'referencia', 'ref', 'listingid', 'id', 'codigo_imovel', 'cod' ),

	'titulo' => array( 'titulo', 'title', 'nome', 'tituloimovel', 'listingtitle' ),

	'descricao' => array( 'descricao', 'description', 'observacao', 'observacoes', 'texto', 'detalhes', 'descricaocompleta' ),

	'preco' => array( 'precovenda', 'valorvenda', 'preco', 'valor', 'price', 'listprice', 'precodevenda', 'valor_venda' ),

	'preco_locacao' => array( 'precolocacao', 'valorlocacao', 'valoraluguel', 'precoaluguel', 'rentalprice' ),

	'valor_condominio' => array( 'valorcondominio', 'condominio', 'precocondominio', 'taxacondominio' ),

	'valor_iptu' => array( 'valoriptu', 'iptu', 'precoiptu', 'taxaiptu' ),

	'dormitorios' => array( 'dormitorios', 'quartos', 'qtdedormitorios', 'numerodormitorios', 'bedrooms', 'dormitorio' ),

	'suites' => array( 'suites', 'qtdesuites', 'numerosuites', 'suite' ),

	'banheiros' => array( 'banheiros', 'qtdebanheiros', 'numerobanheiros', 'bathrooms', 'banheiro' ),

	'vagas' => array( 'vagas', 'garagem', 'vagasgaragem', 'qtdevagas', 'garages', 'numerovagas' ),

	'area_util' => array( 'areautil', 'areaprivativa', 'area', 'usablearea', 'metragem', 'areaconstruida' ),

	'area_total' => array( 'areatotal', 'areaterreno', 'totalarea', 'areatotalterreno' ),

	'tipo' => array( 'tipoimovel', 'tipo', 'categoria', 'subtipo', 'propertytype', 'tipo_imovel' ),

	'finalidade' => array( 'finalidade', 'transacao', 'operacao', 'transactiontype', 'negocio', 'tiponegocio' ),

	'bairro' => array( 'bairro', 'neighborhood', 'bairrocomercial', 'regiao' ),

	'cidade' => array( 'cidade', 'city', 'municipio' ),

	'uf' => array( 'uf', 'estado', 'state', 'sigla' ),

	'cep' => array( 'cep', 'postalcode', 'zipcode' ),

	'endereco' => array( 'endereco', 'logradouro', 'rua', 'address', 'street' ),

	'condominio' => array( 'nomecondominio', 'condominionome', 'empreendimento', 'nomeedificio' ),

	'latitude' => array( 'latitude', 'lat' ),

	'longitude' => array( 'longitude', 'lng', 'long' ),

	'ano_construcao' => array( 'anoconstrucao', 'ano', 'yearbuilt' ),

	'caracteristicas' => array( 'caracteristicas', 'features', 'itens', 'diferenciais', 'infraestrutura', 'comodidades' ),

	'video_url' => array( 'video', 'videourl', 'linkvideo', 'youtube' ),

	'tour_url' => array( 'tour', 'tourvirtual', 'tour360', 'virtualtour' ),

	'destaque' => array( 'destaque', 'featured', 'superdestaque' ),

	'exclusividade' => array( 'exclusividade', 'exclusivo' ),

	'situacao' => array( 'situacao', 'status', 'disponibilidade', 'ativo' ),

	// Alimentam o "vendido em X dias" da página /vendidos/.
	'data_venda' => array( 'datavenda', 'datadavenda', 'dataventa', 'solddate', 'datafechamento' ),

	'data_captacao' => array( 'datacaptacao', 'datacadastro', 'datainclusao', 'datacriacao', 'createdat', 'datapublicacao' ),
);
