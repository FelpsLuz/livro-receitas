<?php
/**
 * Plugin Name:       FL Imóveis
 * Plugin URI:        https://felipeluzbroker.com.br/
 * Description:       Carteira de imóveis, prova social de vendidos, captação de leads e importador de XML para o portfólio Felipe Luz Broker.
 * Version:           1.0.0
 * Requires at least: 6.0
 * Requires PHP:      7.4
 * Author:            Felipe Luz
 * License:           GPL-2.0-or-later
 */

defined( 'ABSPATH' ) || exit;

define( 'FL_IMOVEIS_VERSION', '1.0.0' );
define( 'FL_IMOVEIS_DIR', plugin_dir_path( __FILE__ ) );
define( 'FL_IMOVEIS_URL', plugin_dir_url( __FILE__ ) );

require_once FL_IMOVEIS_DIR . 'includes/post-types.php';
require_once FL_IMOVEIS_DIR . 'includes/taxonomies.php';
require_once FL_IMOVEIS_DIR . 'includes/helpers.php';
require_once FL_IMOVEIS_DIR . 'includes/fields.php';
require_once FL_IMOVEIS_DIR . 'includes/query.php';
require_once FL_IMOVEIS_DIR . 'includes/leads.php';
require_once FL_IMOVEIS_DIR . 'includes/schema.php';
require_once FL_IMOVEIS_DIR . 'includes/seo.php';
require_once FL_IMOVEIS_DIR . 'includes/redirects.php';
require_once FL_IMOVEIS_DIR . 'includes/admin.php';

if ( defined( 'WP_CLI' ) && WP_CLI ) {
	require_once FL_IMOVEIS_DIR . 'includes/importer.php';
	require_once FL_IMOVEIS_DIR . 'includes/cli.php';
}

/**
 * Na ativação registra tudo e regrava as regras de rewrite, senão
 * /imoveis/ e /imovel/slug/ retornam 404 até alguém salvar os permalinks.
 */
register_activation_hook(
	__FILE__,
	function () {
		fl_registrar_post_types();
		fl_registrar_taxonomias();
		flush_rewrite_rules();
	}
);

register_deactivation_hook( __FILE__, 'flush_rewrite_rules' );

/**
 * Os campos do imóvel são editados via Meta Box (versão gratuita).
 * O site funciona em leitura sem ele, mas ninguém consegue cadastrar nada.
 */
add_action(
	'admin_notices',
	function () {
		if ( function_exists( 'rwmb_meta' ) || ! current_user_can( 'install_plugins' ) ) {
			return;
		}
		$url = admin_url( 'plugin-install.php?s=meta+box&tab=search&type=term' );
		printf(
			'<div class="notice notice-error"><p><strong>FL Imóveis:</strong> o plugin <em>Meta Box</em> (gratuito) não está ativo. Sem ele não é possível editar os campos dos imóveis. <a href="%s">Instalar agora</a>.</p></div>',
			esc_url( $url )
		);
	}
);
