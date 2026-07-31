<?php
/**
 * Mapa de 301: caminho antigo (sem domínio, minúsculo) => caminho novo.
 *
 * Preencha com as URLs reais do site da Code 49 antes de virar o DNS.
 * Para levantá-las: Google `site:felipeluzbroker.com.br`, Search Console
 * (Páginas > Indexadas) e o sitemap.xml atual.
 *
 * As fichas de imóvel geralmente não precisam entrar aqui: o
 * includes/redirects.php já tenta casar a referência do imóvel
 * (ex.: /imovel/AP1234) com o campo "Ref." importado do XML.
 *
 * Exemplo:
 *   '/quem-somos'   => '/sobre/',
 *   '/fale-conosco' => '/contato/',
 */

defined( 'ABSPATH' ) || exit;

return array(
	// '/caminho-antigo' => '/caminho-novo/',
);
