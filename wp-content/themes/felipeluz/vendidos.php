<?php
/**
 * Template Name: Vendidos (prova social)
 *
 * A página mais subestimada do setor. Cada imóvel vendido fica no ar
 * para sempre — é o que prova que você vende, não que você anuncia.
 */

defined( 'ABSPATH' ) || exit;

get_header();

$stats    = fl_estatisticas();
$vendidos = fl_query_vendidos( 24 );
?>

<div class="fl-pagina fl-vendidos">

	<header class="fl-cabecalho-secao">
		<h1>Vendidos</h1>
		<p class="fl-cabecalho-secao__apoio">
			Todo imóvel que passou pela minha carteira e encontrou dono continua aqui.
			Não apago histórico — ele é o argumento.
		</p>
	</header>

	<?php if ( $stats['vendidos'] > 0 ) : ?>
		<section class="fl-numeros" aria-label="Resumo das vendas">
			<div><strong><?php echo (int) $stats['vendidos']; ?></strong><span>imóveis vendidos</span></div>
			<?php if ( $stats['dias_medio'] > 0 ) : ?>
				<div><strong><?php echo (int) $stats['dias_medio']; ?> dias</strong><span>média entre captação e venda</span></div>
			<?php endif; ?>
			<?php if ( $stats['ticket_medio'] > 0 ) : ?>
				<div><strong><?php echo esc_html( fl_valor_brl( $stats['ticket_medio'] ) ); ?></strong><span>ticket médio negociado</span></div>
			<?php endif; ?>
		</section>
	<?php endif; ?>

	<?php if ( $vendidos->have_posts() ) : ?>

		<div class="fl-grade">
			<?php
			while ( $vendidos->have_posts() ) :
				$vendidos->the_post();
				get_template_part( 'template-parts/card-imovel' );
			endwhile;
			?>
		</div>

		<?php
		echo paginate_links(
			array(
				'total'     => $vendidos->max_num_pages,
				'current'   => max( 1, get_query_var( 'paged' ), get_query_var( 'page' ) ),
				'prev_text' => 'Anterior',
				'next_text' => 'Próxima',
			)
		); // phpcs:ignore WordPress.Security.EscapeOutput
		wp_reset_postdata();
		?>

	<?php else : ?>

		<div class="fl-vazio">
			<h2>O histórico começa a aparecer aqui.</h2>
			<p>
				Assim que o primeiro imóvel da carteira for marcado como vendido no painel,
				ele passa a viver nesta página — com o tempo que levou até a assinatura.
			</p>
		</div>

	<?php endif; ?>

	<aside class="fl-faixa-cta">
		<div>
			<h2>Seu imóvel pode ser o próximo desta página.</h2>
			<p>Avaliação gratuita, com comparativo real do seu bairro. Sem compromisso e sem discurso pronto.</p>
		</div>
		<a class="fl-btn fl-btn--ouro" href="<?php echo esc_url( fl_url_pagina( 'quero-vender' ) ); ?>">Quero avaliar meu imóvel</a>
	</aside>

</div>

<?php
get_footer();
