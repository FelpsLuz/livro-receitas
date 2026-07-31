<?php
/**
 * Tela de configuração (contato/CRECI), colunas da listagem de imóveis
 * e normalização dos campos no salvamento.
 */

defined( 'ABSPATH' ) || exit;

/**
 * Garante que fl_preco e fl_situacao sempre existam.
 * Sem isso, ordenar por preço some com os imóveis sem valor cadastrado.
 * Prioridade 99: roda depois do Meta Box gravar.
 */
add_action( 'save_post_imovel', 'fl_normalizar_imovel', 99, 3 );

function fl_normalizar_imovel( $post_id, $post, $atualizando ) {
	if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
		return;
	}
	if ( wp_is_post_revision( $post_id ) ) {
		return;
	}

	if ( '' === get_post_meta( $post_id, 'fl_preco', true ) ) {
		update_post_meta( $post_id, 'fl_preco', 0 );
	}

	$situacao = get_post_meta( $post_id, 'fl_situacao', true );
	if ( ! array_key_exists( $situacao, fl_situacoes() ) ) {
		update_post_meta( $post_id, 'fl_situacao', 'disponivel' );
	}

	// Marcou como vendido e esqueceu a data? Assume hoje.
	if ( 'vendido' === get_post_meta( $post_id, 'fl_situacao', true )
		&& ! get_post_meta( $post_id, 'fl_data_venda', true ) ) {
		update_post_meta( $post_id, 'fl_data_venda', current_time( 'Y-m-d' ) );
	}

	// Primeira foto da galeria vira capa se não houver imagem destacada.
	if ( ! has_post_thumbnail( $post_id ) ) {
		$galeria = get_post_meta( $post_id, 'fl_galeria', false );
		$galeria = array_values( array_filter( array_map( 'absint', (array) $galeria ) ) );
		if ( $galeria ) {
			set_post_thumbnail( $post_id, $galeria[0] );
		}
	}

	delete_transient( 'fl_estatisticas' );
}

/**
 * Colunas úteis na listagem de imóveis.
 */
add_filter( 'manage_imovel_posts_columns', 'fl_colunas_imovel' );

function fl_colunas_imovel( $colunas ) {
	$novas = array();
	foreach ( $colunas as $chave => $rotulo ) {
		$novas[ $chave ] = $rotulo;
		if ( 'title' === $chave ) {
			$novas['fl_codigo']   = 'Ref.';
			$novas['fl_preco']    = 'Preço';
			$novas['fl_situacao'] = 'Situação';
		}
	}
	return $novas;
}

add_action( 'manage_imovel_posts_custom_column', 'fl_conteudo_coluna_imovel', 10, 2 );

function fl_conteudo_coluna_imovel( $coluna, $post_id ) {
	switch ( $coluna ) {
		case 'fl_codigo':
			echo esc_html( fl_campo( 'codigo', $post_id, '—' ) );
			break;
		case 'fl_preco':
			echo esc_html( fl_preco( $post_id ) );
			break;
		case 'fl_situacao':
			$situacao = fl_situacao( $post_id );
			$cores    = array( 'disponivel' => '#1a7f37', 'reservado' => '#9a6700', 'vendido' => '#8250df' );
			printf(
				'<span style="display:inline-block;padding:2px 8px;border-radius:99px;font-size:11px;font-weight:600;color:#fff;background:%s">%s</span>',
				esc_attr( $cores[ $situacao ] ),
				esc_html( fl_situacao_rotulo( $post_id ) )
			);
			break;
	}
}

add_filter( 'manage_edit-imovel_sortable_columns', function ( $colunas ) {
	$colunas['fl_preco'] = 'fl_preco';
	return $colunas;
} );

add_action( 'pre_get_posts', function ( $query ) {
	if ( ! is_admin() || ! $query->is_main_query() ) {
		return;
	}
	if ( 'fl_preco' === $query->get( 'orderby' ) ) {
		$query->set( 'meta_key', 'fl_preco' );
		$query->set( 'orderby', 'meta_value_num' );
	}
} );

/**
 * Filtro por situação no topo da listagem.
 */
add_action( 'restrict_manage_posts', function ( $post_type ) {
	if ( 'imovel' !== $post_type ) {
		return;
	}
	$atual = isset( $_GET['fl_situacao'] ) ? sanitize_key( wp_unslash( $_GET['fl_situacao'] ) ) : '';
	echo '<select name="fl_situacao"><option value="">Todas as situações</option>';
	foreach ( fl_situacoes() as $valor => $rotulo ) {
		printf( '<option value="%s"%s>%s</option>', esc_attr( $valor ), selected( $atual, $valor, false ), esc_html( $rotulo ) );
	}
	echo '</select>';
} );

add_action( 'pre_get_posts', function ( $query ) {
	if ( ! is_admin() || ! $query->is_main_query() ) {
		return;
	}
	if ( 'imovel' !== $query->get( 'post_type' ) ) {
		return;
	}
	if ( empty( $_GET['fl_situacao'] ) ) {
		return;
	}
	$query->set(
		'meta_query',
		array(
			array(
				'key'   => 'fl_situacao',
				'value' => sanitize_key( wp_unslash( $_GET['fl_situacao'] ) ),
			),
		)
	);
} );

/**
 * Configurações do site.
 */
add_action( 'admin_menu', function () {
	add_submenu_page(
		'edit.php?post_type=imovel',
		'Configurações',
		'Configurações',
		'manage_options',
		'fl-config',
		'fl_render_config'
	);
} );

function fl_campos_config() {
	return array(
		'identidade' => array(
			'titulo' => 'Identidade',
			'campos' => array(
				'nome'  => array( 'Nome', 'Como você assina. Precisa ser idêntico no Google Business Profile, no Instagram e no LinkedIn — divergência fragmenta sua entidade e é o erro que mais custa em SEO local.' ),
				'papel' => array( 'Como você se apresenta', 'Ex.: Personal Broker Imobiliário' ),
				'creci' => array( 'CRECI', 'Exibido no rodapé e em cada ficha — exigência do COFECI para publicidade imobiliária. Confirme a resolução vigente no CRECI/SP.' ),
				'desde' => array( 'Atuando desde (ano)', 'Vira "X anos de mercado" no bloco de confiança da home.' ),
			),
		),
		'contato'    => array(
			'titulo' => 'Contato',
			'campos' => array(
				'whatsapp' => array( 'WhatsApp', 'Só números, com DDD. Ex.: 15987654321' ),
				'telefone' => array( 'Telefone', '' ),
				'email'    => array( 'E-mail para receber leads', '' ),
				'cidade'   => array( 'Cidade de atuação', '' ),
				'uf'       => array( 'UF', '' ),
			),
		),
		'perfis'     => array(
			'titulo' => 'Perfis externos',
			'campos' => array(
				'google'    => array( 'Google Business Profile', 'URL completa. É a mais importante das três.' ),
				'instagram' => array( 'Instagram', '' ),
				'linkedin'  => array( 'LinkedIn', '' ),
			),
		),
	);
}

add_action( 'admin_init', function () {
	foreach ( fl_campos_config() as $grupo ) {
		foreach ( array_keys( $grupo['campos'] ) as $chave ) {
			register_setting( 'fl_config', 'fl_config_' . $chave, array( 'sanitize_callback' => 'sanitize_text_field' ) );
		}
	}
	register_setting( 'fl_config', 'fl_config_retrato', array( 'sanitize_callback' => 'absint' ) );
} );

add_action( 'admin_enqueue_scripts', function ( $tela ) {
	if ( false !== strpos( (string) $tela, 'fl-config' ) ) {
		wp_enqueue_media();
	}
} );

function fl_render_config() {
	$retrato = (int) get_option( 'fl_config_retrato', 0 );
	?>
	<div class="wrap">
		<h1>Configurações — FL Imóveis</h1>
		<form method="post" action="options.php">
			<?php settings_fields( 'fl_config' ); ?>

			<?php foreach ( fl_campos_config() as $grupo ) : ?>
				<h2><?php echo esc_html( $grupo['titulo'] ); ?></h2>
				<table class="form-table" role="presentation">
					<?php foreach ( $grupo['campos'] as $chave => $info ) : ?>
						<tr>
							<th scope="row"><label for="fl_config_<?php echo esc_attr( $chave ); ?>"><?php echo esc_html( $info[0] ); ?></label></th>
							<td>
								<input type="text" class="regular-text" id="fl_config_<?php echo esc_attr( $chave ); ?>"
									name="fl_config_<?php echo esc_attr( $chave ); ?>"
									value="<?php echo esc_attr( get_option( 'fl_config_' . $chave, '' ) ); ?>"
									placeholder="<?php echo esc_attr( fl_config( $chave ) ); ?>">
								<?php if ( $info[1] ) : ?>
									<p class="description"><?php echo esc_html( $info[1] ); ?></p>
								<?php endif; ?>
							</td>
						</tr>
					<?php endforeach; ?>
				</table>
			<?php endforeach; ?>

			<h2>Sua foto</h2>
			<table class="form-table" role="presentation">
				<tr>
					<th scope="row">Retrato</th>
					<td>
						<div id="fl-retrato-previa">
							<?php if ( $retrato ) : ?>
								<?php echo wp_get_attachment_image( $retrato, 'medium', false, array( 'style' => 'max-width:180px;height:auto;border-radius:4px' ) ); ?>
							<?php endif; ?>
						</div>
						<p>
							<button type="button" class="button" id="fl-escolher-retrato">Escolher imagem</button>
							<button type="button" class="button-link" id="fl-remover-retrato">Remover</button>
						</p>
						<input type="hidden" name="fl_config_retrato" id="fl_config_retrato" value="<?php echo esc_attr( $retrato ); ?>">
						<p class="description">
							Rosto humano real, não banco de imagens. É o que decide se você é sério
							nos primeiros 15 segundos — e vai para o schema como imagem da entidade.
						</p>
					</td>
				</tr>
			</table>

			<?php submit_button(); ?>
		</form>

		<hr>
		<h2>Leads</h2>
		<p>
			<a class="button" href="<?php echo esc_url( wp_nonce_url( admin_url( 'admin-post.php?action=fl_exportar_leads' ), 'fl_exportar_leads' ) ); ?>">
				Exportar leads em CSV
			</a>
		</p>
	</div>

	<script>
	jQuery( function ( $ ) {
		var seletor;

		$( '#fl-escolher-retrato' ).on( 'click', function ( e ) {
			e.preventDefault();
			if ( seletor ) { seletor.open(); return; }
			seletor = wp.media( {
				title: 'Escolha o seu retrato',
				library: { type: 'image' },
				button: { text: 'Usar esta imagem' },
				multiple: false
			} );
			seletor.on( 'select', function () {
				var imagem = seletor.state().get( 'selection' ).first().toJSON();
				$( '#fl_config_retrato' ).val( imagem.id );
				var url = imagem.sizes && imagem.sizes.medium ? imagem.sizes.medium.url : imagem.url;
				$( '#fl-retrato-previa' ).html( '<img src="' + url + '" style="max-width:180px;height:auto;border-radius:4px">' );
			} );
			seletor.open();
		} );

		$( '#fl-remover-retrato' ).on( 'click', function ( e ) {
			e.preventDefault();
			$( '#fl_config_retrato' ).val( '' );
			$( '#fl-retrato-previa' ).empty();
		} );
	} );
	</script>
	<?php
}
