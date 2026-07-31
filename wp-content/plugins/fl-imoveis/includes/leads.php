<?php
/**
 * Captação: formulários nativos, leads gravados no banco e e-mail de aviso.
 * Sem depender de plugin de formulário — o lead é o ativo do site.
 */

defined( 'ABSPATH' ) || exit;

/**
 * Campos aceitos por origem. Nada fora desta lista é gravado.
 */
function fl_campos_lead() {
	return array(
		'nome'         => 'Nome',
		'telefone'     => 'Telefone',
		'email'        => 'E-mail',
		'mensagem'     => 'Mensagem',
		'tipo_imovel'  => 'Tipo de imóvel',
		'bairro'       => 'Bairro',
		'motivo'       => 'Motivo da venda',
		'prazo'        => 'Prazo desejado',
		'valor_desejado' => 'Valor pretendido',
	);
}

add_action( 'admin_post_nopriv_fl_lead', 'fl_processar_lead' );
add_action( 'admin_post_fl_lead', 'fl_processar_lead' );

function fl_processar_lead() {

	$retorno = isset( $_POST['fl_retorno'] ) ? esc_url_raw( wp_unslash( $_POST['fl_retorno'] ) ) : home_url( '/' );
	$retorno = wp_validate_redirect( $retorno, home_url( '/' ) );

	$falhar = function ( $motivo ) use ( $retorno ) {
		wp_safe_redirect( add_query_arg( 'fl_erro', $motivo, $retorno ) . '#formulario' );
		exit;
	};

	/**
	 * Nonce vencido é rotina em página com cache — o HTML fica guardado
	 * e o token envelhece junto. Rejeitar isso significa perder lead por
	 * motivo técnico, o pior jeito de perder lead.
	 *
	 * Para visitante anônimo não há sessão a proteger contra CSRF: o pior
	 * cenário é spam, e disso cuidam o honeypot e a armadilha de tempo.
	 * Nesse caso basta a requisição ter partido do próprio site.
	 * Usuário logado continua exigindo nonce válido.
	 */
	$nonce_ok = isset( $_POST['fl_nonce'] ) && wp_verify_nonce( wp_unslash( $_POST['fl_nonce'] ), 'fl_lead' );

	if ( ! $nonce_ok ) {
		if ( is_user_logged_in() ) {
			$falhar( 'sessao' );
		}

		$origem_http = wp_get_referer();
		$mesmo_site  = $origem_http
			&& wp_parse_url( $origem_http, PHP_URL_HOST ) === wp_parse_url( home_url(), PHP_URL_HOST );

		if ( ! $mesmo_site ) {
			$falhar( 'sessao' );
		}
	}

	// Honeypot: campo escondido que só robô preenche.
	if ( ! empty( $_POST['fl_site'] ) ) {
		wp_safe_redirect( add_query_arg( 'fl_ok', '1', $retorno ) . '#formulario' );
		exit;
	}

	// Armadilha de tempo: humano não envia em menos de 3 segundos.
	$carregado = isset( $_POST['fl_t'] ) ? absint( $_POST['fl_t'] ) : 0;
	if ( $carregado && ( time() - $carregado ) < 3 ) {
		$falhar( 'rapido' );
	}

	$dados = array();
	foreach ( fl_campos_lead() as $chave => $rotulo ) {
		if ( ! isset( $_POST[ $chave ] ) ) {
			continue;
		}
		$valor = wp_unslash( $_POST[ $chave ] );
		$dados[ $chave ] = ( 'mensagem' === $chave )
			? sanitize_textarea_field( $valor )
			: sanitize_text_field( $valor );
	}

	if ( empty( $dados['nome'] ) ) {
		$falhar( 'nome' );
	}

	if ( empty( $dados['telefone'] ) && empty( $dados['email'] ) ) {
		$falhar( 'contato' );
	}

	if ( ! empty( $dados['email'] ) && ! is_email( $dados['email'] ) ) {
		$falhar( 'email' );
	}

	$origem    = isset( $_POST['fl_origem'] ) ? sanitize_key( wp_unslash( $_POST['fl_origem'] ) ) : 'site';
	$imovel_id = isset( $_POST['fl_imovel'] ) ? absint( $_POST['fl_imovel'] ) : 0;

	$titulo = $dados['nome'];
	if ( $imovel_id ) {
		$titulo .= ' — ' . get_the_title( $imovel_id );
	}

	$lead_id = wp_insert_post(
		array(
			'post_type'   => 'fl_lead',
			'post_status' => 'publish',
			'post_title'  => wp_strip_all_tags( $titulo ),
		),
		true
	);

	if ( is_wp_error( $lead_id ) ) {
		$falhar( 'salvar' );
	}

	foreach ( $dados as $chave => $valor ) {
		update_post_meta( $lead_id, 'fl_' . $chave, $valor );
	}

	update_post_meta( $lead_id, 'fl_origem', $origem );
	update_post_meta( $lead_id, 'fl_status', 'novo' );
	update_post_meta( $lead_id, 'fl_pagina', $retorno );
	if ( $imovel_id ) {
		update_post_meta( $lead_id, 'fl_imovel_id', $imovel_id );
	}

	fl_notificar_lead( $lead_id, $dados, $origem, $imovel_id );

	wp_safe_redirect( add_query_arg( 'fl_ok', '1', $retorno ) . '#formulario' );
	exit;
}

function fl_notificar_lead( $lead_id, $dados, $origem, $imovel_id ) {

	$para = fl_config( 'email', get_option( 'admin_email' ) );

	$assunto = sprintf(
		'[%s] Novo lead: %s',
		wp_specialchars_decode( get_bloginfo( 'name' ), ENT_QUOTES ),
		$dados['nome']
	);

	$linhas   = array();
	$rotulos  = fl_campos_lead();
	foreach ( $dados as $chave => $valor ) {
		if ( '' === $valor ) {
			continue;
		}
		$linhas[] = $rotulos[ $chave ] . ': ' . $valor;
	}

	$linhas[] = '';
	$linhas[] = 'Origem: ' . $origem;
	if ( $imovel_id ) {
		$linhas[] = 'Imóvel: ' . get_the_title( $imovel_id ) . ' — ' . get_permalink( $imovel_id );
	}
	$linhas[] = 'Ver no painel: ' . admin_url( 'post.php?post=' . $lead_id . '&action=edit' );

	wp_mail( $para, $assunto, implode( "\n", $linhas ) );
}

/**
 * Colunas da listagem de leads — o painel precisa ser útil em 5 segundos.
 */
add_filter( 'manage_fl_lead_posts_columns', 'fl_colunas_lead' );

function fl_colunas_lead( $colunas ) {
	return array(
		'cb'       => $colunas['cb'],
		'title'    => 'Lead',
		'contato'  => 'Contato',
		'origem'   => 'Origem',
		'resumo'   => 'Resumo',
		'status'   => 'Status',
		'date'     => 'Recebido',
	);
}

add_action( 'manage_fl_lead_posts_custom_column', 'fl_conteudo_coluna_lead', 10, 2 );

function fl_conteudo_coluna_lead( $coluna, $post_id ) {
	switch ( $coluna ) {
		case 'contato':
			$tel   = get_post_meta( $post_id, 'fl_telefone', true );
			$email = get_post_meta( $post_id, 'fl_email', true );
			if ( $tel ) {
				$zap = 'https://wa.me/55' . preg_replace( '/\D/', '', $tel );
				printf( '<a href="%s" target="_blank" rel="noopener">%s</a><br>', esc_url( $zap ), esc_html( $tel ) );
			}
			if ( $email ) {
				printf( '<a href="mailto:%1$s">%1$s</a>', esc_attr( $email ) );
			}
			break;

		case 'origem':
			$origem = get_post_meta( $post_id, 'fl_origem', true );
			$mapa   = array(
				'quero-vender' => 'Proprietário',
				'imovel'       => 'Imóvel',
				'contato'      => 'Contato',
			);
			echo esc_html( $mapa[ $origem ] ?? $origem );
			break;

		case 'resumo':
			$partes = array_filter(
				array(
					get_post_meta( $post_id, 'fl_tipo_imovel', true ),
					get_post_meta( $post_id, 'fl_bairro', true ),
					get_post_meta( $post_id, 'fl_prazo', true ),
				)
			);
			echo esc_html( implode( ' · ', $partes ) );
			$msg = get_post_meta( $post_id, 'fl_mensagem', true );
			if ( $msg ) {
				echo '<br><em>' . esc_html( wp_trim_words( $msg, 14 ) ) . '</em>';
			}
			break;

		case 'status':
			$status = get_post_meta( $post_id, 'fl_status', true ) ?: 'novo';
			echo esc_html( ucfirst( $status ) );
			break;
	}
}

/**
 * Metabox de leitura do lead + controle de status.
 */
add_action( 'add_meta_boxes_fl_lead', 'fl_metabox_lead' );

function fl_metabox_lead() {
	add_meta_box( 'fl_lead_dados', 'Dados recebidos', 'fl_render_metabox_lead', 'fl_lead', 'normal', 'high' );
}

function fl_render_metabox_lead( $post ) {
	wp_nonce_field( 'fl_lead_status', 'fl_lead_status_nonce' );

	echo '<table class="widefat striped"><tbody>';
	foreach ( fl_campos_lead() as $chave => $rotulo ) {
		$valor = get_post_meta( $post->ID, 'fl_' . $chave, true );
		if ( '' === $valor ) {
			continue;
		}
		printf( '<tr><th style="width:180px">%s</th><td>%s</td></tr>', esc_html( $rotulo ), nl2br( esc_html( $valor ) ) );
	}

	$imovel_id = (int) get_post_meta( $post->ID, 'fl_imovel_id', true );
	if ( $imovel_id ) {
		printf(
			'<tr><th>Imóvel</th><td><a href="%s" target="_blank" rel="noopener">%s</a></td></tr>',
			esc_url( get_permalink( $imovel_id ) ),
			esc_html( get_the_title( $imovel_id ) )
		);
	}

	printf( '<tr><th>Página de origem</th><td>%s</td></tr>', esc_html( get_post_meta( $post->ID, 'fl_pagina', true ) ) );
	echo '</tbody></table>';

	$status  = get_post_meta( $post->ID, 'fl_status', true ) ?: 'novo';
	$opcoes  = array( 'novo' => 'Novo', 'contatado' => 'Contatado', 'reuniao' => 'Reunião marcada', 'captado' => 'Captado', 'perdido' => 'Perdido' );

	echo '<p><label for="fl_status"><strong>Status</strong></label><br><select name="fl_status" id="fl_status">';
	foreach ( $opcoes as $valor => $rotulo ) {
		printf( '<option value="%s"%s>%s</option>', esc_attr( $valor ), selected( $status, $valor, false ), esc_html( $rotulo ) );
	}
	echo '</select></p>';

	$notas = get_post_meta( $post->ID, 'fl_notas', true );
	echo '<p><label for="fl_notas"><strong>Anotações</strong></label><br>';
	printf( '<textarea name="fl_notas" id="fl_notas" rows="4" style="width:100%%">%s</textarea></p>', esc_textarea( $notas ) );
}

add_action( 'save_post_fl_lead', 'fl_salvar_status_lead' );

function fl_salvar_status_lead( $post_id ) {
	if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
		return;
	}
	if ( ! isset( $_POST['fl_lead_status_nonce'] ) || ! wp_verify_nonce( wp_unslash( $_POST['fl_lead_status_nonce'] ), 'fl_lead_status' ) ) {
		return;
	}
	if ( ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}
	if ( isset( $_POST['fl_status'] ) ) {
		update_post_meta( $post_id, 'fl_status', sanitize_key( wp_unslash( $_POST['fl_status'] ) ) );
	}
	if ( isset( $_POST['fl_notas'] ) ) {
		update_post_meta( $post_id, 'fl_notas', sanitize_textarea_field( wp_unslash( $_POST['fl_notas'] ) ) );
	}
}

/**
 * Exportação CSV dos leads, para quem preferir trabalhar em planilha.
 */
add_action( 'admin_post_fl_exportar_leads', 'fl_exportar_leads' );

function fl_exportar_leads() {
	if ( ! current_user_can( 'edit_posts' ) ) {
		wp_die( 'Sem permissão.' );
	}
	check_admin_referer( 'fl_exportar_leads' );

	$leads = get_posts(
		array(
			'post_type'      => 'fl_lead',
			'posts_per_page' => -1,
			'post_status'    => 'publish',
		)
	);

	header( 'Content-Type: text/csv; charset=utf-8' );
	header( 'Content-Disposition: attachment; filename=leads-' . gmdate( 'Y-m-d' ) . '.csv' );

	$saida  = fopen( 'php://output', 'w' );
	$campos = fl_campos_lead();

	fputcsv( $saida, array_merge( array( 'Data', 'Origem', 'Status' ), array_values( $campos ) ) );

	foreach ( $leads as $lead ) {
		$linha = array(
			get_the_date( 'Y-m-d H:i', $lead ),
			get_post_meta( $lead->ID, 'fl_origem', true ),
			get_post_meta( $lead->ID, 'fl_status', true ),
		);
		foreach ( array_keys( $campos ) as $chave ) {
			$linha[] = get_post_meta( $lead->ID, 'fl_' . $chave, true );
		}
		fputcsv( $saida, $linha );
	}

	fclose( $saida );
	exit;
}
