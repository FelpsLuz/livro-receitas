<?php
/**
 * Ficha do imóvel. Vendido nunca vira 404 — vira prova.
 */

defined( 'ABSPATH' ) || exit;

get_header();

while ( have_posts() ) :
	the_post();

	$post_id         = get_the_ID();
	$vendido         = fl_esta_vendido( $post_id );
	$dias            = $vendido ? fl_dias_para_venda( $post_id ) : 0;
	$galeria         = fl_galeria_ids( $post_id );
	$atributos       = fl_atributos( $post_id );
	$caracteristicas = fl_caracteristicas( $post_id );
	$codigo          = fl_campo( 'codigo', $post_id );
	$condominio      = (float) fl_campo( 'valor_condominio', $post_id, 0 );
	$iptu            = (float) fl_campo( 'valor_iptu', $post_id, 0 );
	$depoimento      = fl_campo( 'depoimento', $post_id );
	?>

	<article class="fl-pagina fl-imovel<?php echo $vendido ? ' fl-imovel--vendido' : ''; ?>">

		<nav class="fl-trilha" aria-label="Você está em">
			<a href="<?php echo esc_url( home_url( '/' ) ); ?>">Início</a>
			<span aria-hidden="true">/</span>
			<a href="<?php echo esc_url( get_post_type_archive_link( 'imovel' ) ); ?>">Imóveis</a>
			<?php if ( $vendido ) : ?>
				<span aria-hidden="true">/</span>
				<a href="<?php echo esc_url( fl_url_pagina( 'vendidos' ) ); ?>">Vendidos</a>
			<?php endif; ?>
		</nav>

		<?php if ( $vendido ) : ?>
			<div class="fl-faixa-vendido">
				<strong>Vendido<?php echo $dias ? esc_html( ' em ' . $dias . ' dias' ) : ''; ?>.</strong>
				Este imóvel já saiu da carteira — a página fica no ar como registro do trabalho.
				<a href="<?php echo esc_url( fl_url_pagina( 'quero-vender' ) ); ?>">Quero o mesmo resultado no meu imóvel</a>
			</div>
		<?php endif; ?>

		<?php if ( $galeria ) : ?>
			<div class="fl-galeria" data-fl-galeria>
				<figure class="fl-galeria__principal">
					<?php echo wp_get_attachment_image( $galeria[0], 'fl-capa', false, array( 'id' => 'fl-galeria-principal', 'alt' => esc_attr( get_the_title() ) ) ); ?>
					<?php if ( count( $galeria ) > 1 ) : ?>
						<button type="button" class="fl-galeria__abrir" data-fl-abrir>Ver <?php echo count( $galeria ); ?> fotos</button>
					<?php endif; ?>
				</figure>

				<?php if ( count( $galeria ) > 1 ) : ?>
					<div class="fl-galeria__miniaturas">
						<?php foreach ( array_slice( $galeria, 0, 8 ) as $indice => $id ) : ?>
							<button type="button" class="fl-galeria__mini<?php echo 0 === $indice ? ' esta-ativa' : ''; ?>"
								data-fl-mini="<?php echo esc_url( wp_get_attachment_image_url( $id, 'fl-capa' ) ); ?>"
								data-fl-indice="<?php echo (int) $indice; ?>">
								<?php echo wp_get_attachment_image( $id, 'fl-miniatura', false, array( 'loading' => 'lazy', 'alt' => '' ) ); ?>
							</button>
						<?php endforeach; ?>
					</div>
				<?php endif; ?>
			</div>
		<?php endif; ?>

		<div class="fl-imovel__grade">

			<div class="fl-imovel__principal">

				<header class="fl-imovel__cabecalho">
					<p class="fl-imovel__local">
						<?php echo esc_html( fl_localizacao( $post_id ) ); ?>
						<?php if ( $codigo ) : ?>
							<span class="fl-imovel__ref">Ref. <?php echo esc_html( $codigo ); ?></span>
						<?php endif; ?>
					</p>
					<h1><?php the_title(); ?></h1>
				</header>

				<?php if ( $atributos ) : ?>
					<ul class="fl-ficha">
						<?php foreach ( $atributos as $atributo ) : ?>
							<li>
								<strong><?php echo esc_html( $atributo['valor'] ); ?></strong>
								<span><?php echo esc_html( $atributo['rotulo'] ); ?></span>
							</li>
						<?php endforeach; ?>
					</ul>
				<?php endif; ?>

				<div class="fl-imovel__texto">
					<?php the_content(); ?>
				</div>

				<?php if ( $caracteristicas ) : ?>
					<section class="fl-caracteristicas">
						<h2>O que este imóvel tem</h2>
						<ul>
							<?php foreach ( $caracteristicas as $item ) : ?>
								<li><?php echo esc_html( $item ); ?></li>
							<?php endforeach; ?>
						</ul>
					</section>
				<?php endif; ?>

				<?php if ( $condominio > 0 || $iptu > 0 ) : ?>
					<section class="fl-custos">
						<h2>Custos mensais</h2>
						<ul>
							<?php if ( $condominio > 0 ) : ?>
								<li><span>Condomínio</span><strong><?php echo esc_html( fl_valor_brl( $condominio ) ); ?>/mês</strong></li>
							<?php endif; ?>
							<?php if ( $iptu > 0 ) : ?>
								<li><span>IPTU</span><strong><?php echo esc_html( fl_valor_brl( $iptu ) ); ?>/ano</strong></li>
							<?php endif; ?>
						</ul>
						<p class="fl-nota">Valores informados pelo proprietário e conferidos na captação. Confirmo tudo por documento antes da proposta.</p>
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
					<section class="fl-midia-extra">
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
							<a class="fl-btn fl-btn--ouro fl-btn--bloco" href="<?php echo esc_url( $zap ); ?>" target="_blank" rel="noopener">Agendar visita pelo WhatsApp</a>
						<?php endif; ?>
						<a class="fl-btn fl-btn--linha fl-btn--bloco" href="#formulario">Pedir mais informações</a>
					<?php endif; ?>

					<?php if ( fl_config( 'creci' ) ) : ?>
						<p class="fl-caixa-preco__creci">Felipe Luz — CRECI <?php echo esc_html( fl_config( 'creci' ) ); ?></p>
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
					'campos'    => array( 'mensagem' ),
					'imovel_id' => $post_id,
				)
			);
		}
		?>

		<?php
		$relacionados = fl_query_relacionados( $post_id );
		if ( $relacionados->have_posts() ) :
			?>
			<section class="fl-relacionados">
				<h2><?php echo $vendido ? 'Disponíveis agora' : 'Talvez estes também sirvam'; ?></h2>
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

	<?php if ( $galeria && count( $galeria ) > 1 ) : ?>
		<div class="fl-lightbox" data-fl-lightbox hidden>
			<button type="button" class="fl-lightbox__fechar" data-fl-fechar aria-label="Fechar">&times;</button>
			<button type="button" class="fl-lightbox__nav fl-lightbox__nav--ant" data-fl-ant aria-label="Foto anterior">&#8249;</button>
			<img class="fl-lightbox__img" data-fl-img src="" alt="">
			<button type="button" class="fl-lightbox__nav fl-lightbox__nav--prox" data-fl-prox aria-label="Próxima foto">&#8250;</button>
			<p class="fl-lightbox__contador" data-fl-contador></p>
			<script type="application/json" data-fl-fotos>
				<?php
				$fotos = array();
				foreach ( $galeria as $id ) {
					$fotos[] = wp_get_attachment_image_url( $id, 'fl-capa' );
				}
				echo wp_json_encode( array_values( array_filter( $fotos ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput
				?>
			</script>
		</div>
	<?php endif; ?>

	<?php
endwhile;

get_footer();
