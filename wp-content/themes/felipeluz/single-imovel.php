<?php
/**
 * Ficha do imóvel — a peça que faz o SEO.
 *
 * A ordem dos blocos não é estética, é funcional:
 * galeria → resposta direta → preço → tabela → descrição → diferenciais →
 * localização → FAQ → relacionados → CTA fixo.
 *
 * Cada seção é autocontida: sistemas de IA recuperam trechos, não páginas.
 * Um parágrafo que só faz sentido depois de ler os três anteriores é inútil.
 */

defined( 'ABSPATH' ) || exit;

get_header();

while ( have_posts() ) :
	the_post();

	$post_id         = get_the_ID();
	$vendido         = fl_esta_vendido( $post_id );
	$dias            = $vendido ? fl_dias_para_venda( $post_id ) : 0;
	$galeria         = fl_galeria_ids( $post_id );
	$total_fotos     = count( $galeria );
	$caracteristicas = fl_caracteristicas( $post_id );
	$especificacoes  = fl_especificacoes( $post_id );
	$faq             = fl_faq_itens( $post_id );
	$codigo          = fl_campo( 'codigo', $post_id );
	$condominio      = (float) fl_campo( 'valor_condominio', $post_id, 0 );
	$iptu            = (float) fl_campo( 'valor_iptu', $post_id, 0 );
	$depoimento      = fl_campo( 'depoimento', $post_id );
	$bairros         = get_the_terms( $post_id, 'imovel_bairro' );
	$bairro          = ( $bairros && ! is_wp_error( $bairros ) ) ? $bairros[0] : null;
	?>

	<article class="fl-pagina fl-imovel<?php echo $vendido ? ' fl-imovel--vendido' : ''; ?>">

		<?php fl_render_migalhas( $post_id ); ?>

		<?php if ( $vendido ) : ?>
			<div class="fl-faixa-vendido">
				<strong>Vendido<?php echo $dias ? esc_html( ' em ' . $dias . ' dias' ) : ''; ?>.</strong>
				Este imóvel já saiu da carteira — a página fica no ar como registro do trabalho.
				<a href="<?php echo esc_url( fl_url_pagina( 'quero-vender' ) ); ?>">Quero o mesmo resultado no meu imóvel</a>
			</div>
		<?php endif; ?>

		<header class="fl-imovel__cabecalho">
			<p class="fl-imovel__local">
				<?php if ( $bairro ) : ?>
					<a href="<?php echo esc_url( get_term_link( $bairro ) ); ?>"><?php echo esc_html( $bairro->name ); ?></a>,
				<?php endif; ?>
				<?php echo esc_html( fl_campo( 'cidade', $post_id, fl_config( 'cidade' ) ) ); ?>
				<?php if ( $codigo ) : ?>
					<span class="fl-imovel__ref">Ref. <?php echo esc_html( $codigo ); ?></span>
				<?php endif; ?>
			</p>
			<h1><?php the_title(); ?></h1>
		</header>

		<?php
		/* 1. Galeria — swipe nativo com scroll-snap, sem biblioteca. */
		if ( $galeria ) :
			?>
			<section class="fl-galeria" aria-label="Fotos do imóvel">
				<div class="fl-galeria__trilho" data-fl-trilho>
					<?php foreach ( $galeria as $indice => $anexo_id ) : ?>
						<figure class="fl-galeria__slide" data-fl-slide="<?php echo (int) $indice; ?>">
							<?php
							echo wp_get_attachment_image(
								$anexo_id,
								'fl-capa',
								false,
								array(
									'alt'           => fl_alt_foto( $anexo_id, $post_id, $indice, $total_fotos ),
									'loading'       => 0 === $indice ? 'eager' : 'lazy',
									'fetchpriority' => 0 === $indice ? 'high' : 'auto',
									'decoding'      => 0 === $indice ? 'sync' : 'async',
									'sizes'         => '(max-width: 900px) 100vw, 900px',
								)
							);
							?>
						</figure>
					<?php endforeach; ?>
				</div>

				<?php if ( $total_fotos > 1 ) : ?>
					<p class="fl-galeria__contador" data-fl-contador-trilho>1 / <?php echo (int) $total_fotos; ?></p>
					<button type="button" class="fl-galeria__abrir" data-fl-abrir>
						Ver as <?php echo (int) $total_fotos; ?> fotos
					</button>
				<?php endif; ?>
			</section>
		<?php endif; ?>

		<div class="fl-imovel__grade">

			<div class="fl-imovel__principal">

				<?php
				/* 2. Resposta direta — o parágrafo que a IA extrai. */
				$resposta = fl_resposta_direta( $post_id );
				if ( $resposta ) :
					?>
					<p class="fl-resposta-direta"><?php echo esc_html( $resposta ); ?></p>
				<?php endif; ?>

				<?php
				/* 3. Preço, condomínio e IPTU explícitos, nunca "consulte-nos". */
				if ( ! $vendido ) :
					?>
					<section class="fl-precos" aria-label="Valores">
						<div class="fl-precos__principal">
							<span class="fl-precos__rotulo"><?php echo esc_html( fl_finalidade_nome( $post_id ) ?: 'Venda' ); ?></span>
							<strong class="fl-precos__valor"><?php echo esc_html( fl_preco( $post_id ) ); ?></strong>
						</div>
						<?php if ( $condominio > 0 ) : ?>
							<div class="fl-precos__extra">
								<span class="fl-precos__rotulo">Condomínio</span>
								<strong><?php echo esc_html( fl_valor_brl( $condominio ) ); ?><small>/mês</small></strong>
							</div>
						<?php endif; ?>
						<?php if ( $iptu > 0 ) : ?>
							<div class="fl-precos__extra">
								<span class="fl-precos__rotulo">IPTU</span>
								<strong><?php echo esc_html( fl_valor_brl( $iptu ) ); ?><small>/ano</small></strong>
							</div>
						<?php endif; ?>
					</section>
				<?php endif; ?>

				<?php
				/* 4. Tabela de especificações — o formato que LLM extrai melhor. */
				if ( $especificacoes ) :
					?>
					<section class="fl-secao-ficha" id="especificacoes">
						<h2>Ficha técnica</h2>
						<div class="fl-tabela-rolagem">
							<table class="fl-tabela">
								<caption class="fl-oculto">Especificações de <?php the_title_attribute(); ?></caption>
								<tbody>
									<?php foreach ( $especificacoes as $rotulo => $valor ) : ?>
										<tr>
											<th scope="row"><?php echo esc_html( $rotulo ); ?></th>
											<td><?php echo esc_html( $valor ); ?></td>
										</tr>
									<?php endforeach; ?>
								</tbody>
							</table>
						</div>
					</section>
				<?php endif; ?>

				<?php
				/* 5. Descrição própria — 250 a 400 palavras, escritas à mão. */
				$conteudo = trim( get_the_content() );
				if ( $conteudo ) :
					?>
					<section class="fl-secao-ficha" id="descricao">
						<h2>Como é este imóvel</h2>
						<div class="fl-imovel__texto"><?php the_content(); ?></div>
					</section>
				<?php endif; ?>

				<?php
				/* 6. Diferenciais em lista, nunca em parágrafo corrido. */
				if ( $caracteristicas ) :
					?>
					<section class="fl-secao-ficha" id="diferenciais">
						<h2>O que este imóvel tem</h2>
						<ul class="fl-diferenciais-lista">
							<?php foreach ( $caracteristicas as $item ) : ?>
								<li><?php echo esc_html( $item ); ?></li>
							<?php endforeach; ?>
						</ul>
					</section>
				<?php endif; ?>

				<?php
				/**
				 * 7. Localização. O texto do bairro vive uma vez só, no hub —
				 * repeti-lo em 12 fichas do mesmo bairro é conteúdo duplicado.
				 * Aqui vai só o link e o mapa sob clique.
				 */
				$latitude  = fl_campo( 'latitude', $post_id );
				$longitude = fl_campo( 'longitude', $post_id );
				$consulta  = ( $latitude && $longitude )
					? $latitude . ',' . $longitude
					: trim( ( $bairro ? $bairro->name . ', ' : '' ) . fl_campo( 'cidade', $post_id, fl_config( 'cidade' ) ) . ' - ' . fl_campo( 'uf', $post_id, fl_config( 'uf' ) ) );
				?>
				<section class="fl-secao-ficha" id="localizacao">
					<h2>Onde fica</h2>
					<?php if ( $bairro ) : ?>
						<p>
							Este imóvel fica <?php echo esc_html( 'no ' . $bairro->name ); ?>, em
							<?php echo esc_html( fl_campo( 'cidade', $post_id, fl_config( 'cidade' ) ) ); ?>.
							<a href="<?php echo esc_url( get_term_link( $bairro ) ); ?>">Ver o guia do <?php echo esc_html( $bairro->name ); ?> e os outros imóveis do bairro</a>.
						</p>
					<?php endif; ?>

					<?php if ( $consulta ) : ?>
						<div class="fl-mapa" data-fl-mapa data-fl-consulta="<?php echo esc_attr( $consulta ); ?>">
							<button type="button" class="fl-mapa__abrir" data-fl-mapa-abrir>
								Carregar o mapa
								<small>O mapa só carrega quando você pede — assim a página abre rápido.</small>
							</button>
						</div>
					<?php endif; ?>

					<p class="fl-nota">
						A localização exibida é aproximada, no nível do bairro. O endereço exato
						é informado no agendamento da visita.
					</p>
				</section>

				<?php
				/* 8. FAQ — combustível de IA, e não custa nada. */
				if ( $faq ) :
					?>
					<section class="fl-secao-ficha fl-faq" id="perguntas">
						<h2>Perguntas frequentes sobre este imóvel</h2>
						<?php foreach ( $faq as $indice => $item ) : ?>
							<details class="fl-faq__item"<?php echo $indice < 2 ? ' open' : ''; ?>>
								<summary><h3><?php echo esc_html( $item[0] ); ?></h3></summary>
								<p><?php echo esc_html( $item[1] ); ?></p>
							</details>
						<?php endforeach; ?>
					</section>
				<?php endif; ?>

				<?php if ( $depoimento ) : ?>
					<blockquote class="fl-depoimento">
						<p><?php echo esc_html( $depoimento ); ?></p>
						<cite><?php echo esc_html( fl_campo( 'depoimento_autor', $post_id, 'Cliente' ) ); ?></cite>
					</blockquote>
				<?php endif; ?>

				<?php
				$video = fl_campo( 'video_url', $post_id );
				$tour  = fl_campo( 'tour_url', $post_id );
				if ( $video || $tour ) :
					?>
					<section class="fl-secao-ficha fl-midia-extra">
						<h2>Vídeo e tour</h2>
						<?php
						if ( $video ) :
							$incorporado = wp_oembed_get( $video );
							?>
							<div class="fl-video">
								<?php
								echo $incorporado
									? $incorporado // phpcs:ignore WordPress.Security.EscapeOutput
									: '<a href="' . esc_url( $video ) . '" target="_blank" rel="noopener">Ver vídeo do imóvel</a>';
								?>
							</div>
						<?php endif; ?>
						<?php if ( $tour ) : ?>
							<p><a class="fl-btn fl-btn--linha" href="<?php echo esc_url( $tour ); ?>" target="_blank" rel="noopener">Abrir tour 360º</a></p>
						<?php endif; ?>
					</section>
				<?php endif; ?>

			</div>

			<aside class="fl-imovel__lateral">
				<div class="fl-caixa-preco">
					<?php if ( $vendido ) : ?>
						<p class="fl-caixa-preco__rotulo">Situação</p>
						<p class="fl-caixa-preco__valor fl-caixa-preco__valor--vendido">Vendido</p>
						<?php if ( $dias ) : ?>
							<p class="fl-caixa-preco__apoio">Levou <?php echo (int) $dias; ?> dias entre a captação e a assinatura.</p>
						<?php endif; ?>
						<a class="fl-btn fl-btn--ouro fl-btn--bloco" href="<?php echo esc_url( fl_url_pagina( 'quero-vender' ) ); ?>">Avaliar meu imóvel</a>
						<a class="fl-btn fl-btn--linha fl-btn--bloco" href="<?php echo esc_url( get_post_type_archive_link( 'imovel' ) ); ?>">Ver imóveis disponíveis</a>
					<?php else : ?>
						<p class="fl-caixa-preco__rotulo"><?php echo esc_html( fl_finalidade_nome( $post_id ) ?: 'Venda' ); ?></p>
						<p class="fl-caixa-preco__valor"><?php echo esc_html( fl_preco( $post_id ) ); ?></p>
						<?php if ( 'reservado' === fl_situacao( $post_id ) ) : ?>
							<p class="fl-caixa-preco__apoio">Com proposta em análise. Ainda dá para entrar na fila.</p>
						<?php endif; ?>

						<?php $zap = fl_link_whatsapp( '', $post_id ); ?>
						<?php if ( $zap ) : ?>
							<a class="fl-btn fl-btn--ouro fl-btn--bloco" href="<?php echo esc_url( $zap ); ?>"
								target="_blank" rel="noopener"
								data-fl-evento="contato_whatsapp" data-fl-local="lateral">Agendar visita pelo WhatsApp</a>
						<?php endif; ?>
						<a class="fl-btn fl-btn--linha fl-btn--bloco" href="#formulario">Pedir mais informações</a>
					<?php endif; ?>

					<?php if ( fl_config( 'creci' ) ) : ?>
						<p class="fl-caixa-preco__creci">
							<?php echo esc_html( fl_config( 'nome' ) ); ?> — <?php echo esc_html( fl_config( 'creci' ) ); ?>
						</p>
					<?php endif; ?>
				</div>
			</aside>

		</div>

		<?php
		if ( ! $vendido ) {
			get_template_part(
				'template-parts/form-lead',
				null,
				array(
					'origem'    => 'imovel',
					'titulo'    => 'Quer saber mais sobre este imóvel?',
					'texto'     => 'Respondo pessoalmente. Sem central de atendimento, sem robô.',
					'botao'     => 'Quero falar sobre este imóvel',
					'campos'    => array( 'melhor_horario', 'mensagem' ),
					'imovel_id' => $post_id,
				)
			);
		}
		?>

		<?php
		/* 9. Relacionados — link interno e sessão. */
		$relacionados = fl_query_relacionados( $post_id );
		if ( $relacionados->have_posts() ) :
			?>
			<section class="fl-relacionados">
				<h2><?php echo $vendido ? 'Disponíveis agora' : 'Outros imóveis parecidos'; ?></h2>
				<div class="fl-grade fl-grade--3">
					<?php
					while ( $relacionados->have_posts() ) :
						$relacionados->the_post();
						get_template_part( 'template-parts/card-imovel' );
					endwhile;
					wp_reset_postdata();
					?>
				</div>
			</section>
		<?php endif; ?>

	</article>

	<?php
	/* 10. CTA fixo. Sozinho, costuma dobrar a taxa de contato em mobile. */
	$zap_fixo = $vendido ? '' : fl_link_whatsapp( '', $post_id );
	?>
	<div class="fl-cta-fixo">
		<?php if ( $vendido ) : ?>
			<div class="fl-cta-fixo__info">
				<span>Imóvel vendido</span>
				<strong>Quer o mesmo no seu?</strong>
			</div>
			<a class="fl-btn fl-btn--ouro" href="<?php echo esc_url( fl_url_pagina( 'quero-vender' ) ); ?>"
				data-fl-evento="cta_captacao" data-fl-local="fixo">Avaliar meu imóvel</a>
		<?php else : ?>
			<div class="fl-cta-fixo__info">
				<span><?php echo esc_html( fl_finalidade_nome( $post_id ) ?: 'Venda' ); ?></span>
				<strong><?php echo esc_html( fl_preco( $post_id ) ); ?></strong>
			</div>
			<?php if ( $zap_fixo ) : ?>
				<a class="fl-btn fl-btn--ouro" href="<?php echo esc_url( $zap_fixo ); ?>" target="_blank" rel="noopener"
					data-fl-evento="contato_whatsapp" data-fl-local="fixo">Falar agora</a>
			<?php else : ?>
				<a class="fl-btn fl-btn--ouro" href="#formulario" data-fl-evento="cta_formulario" data-fl-local="fixo">Tenho interesse</a>
			<?php endif; ?>
		<?php endif; ?>
	</div>

	<?php if ( $total_fotos > 1 ) : ?>
		<div class="fl-lightbox" data-fl-lightbox hidden>
			<button type="button" class="fl-lightbox__fechar" data-fl-fechar aria-label="Fechar">&times;</button>
			<button type="button" class="fl-lightbox__nav fl-lightbox__nav--ant" data-fl-ant aria-label="Foto anterior">&#8249;</button>
			<img class="fl-lightbox__img" data-fl-img src="" alt="">
			<button type="button" class="fl-lightbox__nav fl-lightbox__nav--prox" data-fl-prox aria-label="Próxima foto">&#8250;</button>
			<p class="fl-lightbox__contador" data-fl-contador></p>
			<script type="application/json" data-fl-fotos>
				<?php
				$fotos = array();
				foreach ( $galeria as $indice => $id ) {
					$url = wp_get_attachment_image_url( $id, 'fl-capa' );
					if ( $url ) {
						$fotos[] = array(
							'src' => $url,
							'alt' => fl_alt_foto( $id, $post_id, $indice, $total_fotos ),
						);
					}
				}
				echo wp_json_encode( $fotos ); // phpcs:ignore WordPress.Security.EscapeOutput
				?>
			</script>
		</div>
	<?php endif; ?>

	<?php
endwhile;

get_footer();
