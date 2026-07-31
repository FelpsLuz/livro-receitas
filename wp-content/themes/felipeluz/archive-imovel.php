<?php
/**
 * Vitrine da carteira ativa. Também atende os arquivos de tipo, finalidade e bairro.
 */

defined( 'ABSPATH' ) || exit;

get_header();
?>

<div class="fl-pagina fl-pagina--vitrine">

	<header class="fl-cabecalho-secao">
		<h1><?php echo esc_html( get_the_archive_title() ); ?></h1>
		<p class="fl-cabecalho-secao__apoio">
			Carteira selecionada. Cada imóvel aqui eu conheço pessoalmente — visitei, fotografei e sei o que o vizinho paga de condomínio.
		</p>
	</header>

	<?php get_template_part( 'template-parts/filtros' ); ?>

	<?php if ( have_posts() ) : ?>

		<p class="fl-resultado-total">
			<?php
			global $wp_query;
			$total = (int) $wp_query->found_posts;
			printf(
				esc_html( _n( '%s imóvel encontrado', '%s imóveis encontrados', $total, 'felipeluz' ) ),
				esc_html( number_format_i18n( $total ) )
			);
			?>
		</p>

		<div class="fl-grade">
			<?php
			while ( have_posts() ) :
				the_post();
				get_template_part( 'template-parts/card-imovel' );
			endwhile;
			?>
		</div>

		<?php
		the_posts_pagination(
			array(
				'mid_size'  => 2,
				'prev_text' => 'Anterior',
				'next_text' => 'Próxima',
			)
		);
		?>

	<?php else : ?>

		<div class="fl-vazio">
			<h2>Nada bateu com esse filtro.</h2>
			<p>
				Minha carteira é enxuta de propósito — trabalho com poucos imóveis por vez para
				dar atenção real a cada um. Me diga o que você procura e eu busco fora da vitrine.
			</p>
			<p class="fl-vazio__acoes">
				<a class="fl-btn fl-btn--escuro" href="<?php echo esc_url( get_post_type_archive_link( 'imovel' ) ); ?>">Ver todos os imóveis</a>
				<?php $zap = fl_link_whatsapp( 'Olá, Felipe. Procuro um imóvel e não achei na sua vitrine.' ); ?>
				<?php if ( $zap ) : ?>
					<a class="fl-btn fl-btn--ouro" href="<?php echo esc_url( $zap ); ?>" target="_blank" rel="noopener">Me chamar no WhatsApp</a>
				<?php endif; ?>
			</p>
		</div>

	<?php endif; ?>

	<?php
	$stats = fl_estatisticas();
	if ( $stats['vendidos'] > 0 ) :
		?>
		<aside class="fl-faixa-cta">
			<div>
				<h2>Tem um imóvel para vender?</h2>
				<p>
					<?php
					printf(
						esc_html( 'Já são %d imóveis vendidos%s. Avaliação sem compromisso.' ),
						(int) $stats['vendidos'],
						$stats['dias_medio'] ? esc_html( ', com média de ' . $stats['dias_medio'] . ' dias entre a captação e a assinatura' ) : ''
					);
					?>
				</p>
			</div>
			<a class="fl-btn fl-btn--ouro" href="<?php echo esc_url( fl_url_pagina( 'quero-vender' ) ); ?>">Quero uma avaliação</a>
		</aside>
	<?php endif; ?>

</div>

<?php
get_footer();
