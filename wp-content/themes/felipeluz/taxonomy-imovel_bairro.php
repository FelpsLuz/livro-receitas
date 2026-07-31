<?php
/**
 * Hub do bairro.
 *
 * O texto do bairro mora aqui — uma vez só, na descrição do termo. As
 * fichas linkam para cá em vez de repetir o mesmo parágrafo em doze
 * páginas, que seria conteúdo duplicado.
 *
 * É também onde entra dado proprietário: preço médio por m², tempo médio
 * de venda, o que ninguém mais publica sobre o bairro. Dado com fonte e
 * data é citável por sistemas de IA; adjetivo não é.
 */

defined( 'ABSPATH' ) || exit;

get_header();

$termo     = get_queried_object();
$descricao = term_description( $termo );
?>

<div class="fl-pagina fl-hub-bairro">

	<nav class="fl-trilha" aria-label="Você está em">
		<ol>
			<li><a href="<?php echo esc_url( home_url( '/' ) ); ?>">Início</a></li>
			<li><a href="<?php echo esc_url( get_post_type_archive_link( 'imovel' ) ); ?>">Imóveis</a></li>
			<li><span aria-current="page"><?php echo esc_html( $termo->name ); ?></span></li>
		</ol>
	</nav>

	<header class="fl-cabecalho-secao">
		<h1>Imóveis no <?php echo esc_html( $termo->name ); ?>, <?php echo esc_html( fl_config( 'cidade' ) ); ?></h1>
	</header>

	<?php if ( $descricao ) : ?>
		<div class="fl-hub-bairro__texto">
			<?php echo wp_kses_post( $descricao ); ?>
		</div>
	<?php else : ?>
		<p class="fl-hub-bairro__vazio">
			<?php
			printf(
				/* translators: nome do bairro */
				esc_html__( 'Tenho %1$s imóvel(is) no %2$s. O guia completo do bairro entra aqui — escreva o texto na descrição do termo, em Imóveis › Bairros.', 'felipeluz' ),
				esc_html( number_format_i18n( $termo->count ) ),
				esc_html( $termo->name )
			);
			?>
		</p>
	<?php endif; ?>

	<?php get_template_part( 'template-parts/filtros' ); ?>

	<?php if ( have_posts() ) : ?>

		<h2 class="fl-hub-bairro__titulo-lista">
			<?php
			global $wp_query;
			$total = (int) $wp_query->found_posts;
			printf(
				esc_html( _n( '%1$s imóvel disponível no %2$s', '%1$s imóveis disponíveis no %2$s', $total, 'felipeluz' ) ),
				esc_html( number_format_i18n( $total ) ),
				esc_html( $termo->name )
			);
			?>
		</h2>

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
			<h2>Nenhum imóvel disponível no <?php echo esc_html( $termo->name ); ?> neste momento.</h2>
			<p>
				Trabalho com carteira enxuta, então bairro sem imóvel é rotina — não falta de
				atuação. Me diga o que procura no <?php echo esc_html( $termo->name ); ?> e eu
				busco fora da vitrine.
			</p>
			<p class="fl-vazio__acoes">
				<a class="fl-btn fl-btn--escuro" href="<?php echo esc_url( get_post_type_archive_link( 'imovel' ) ); ?>">Ver todos os imóveis</a>
				<?php $zap = fl_link_whatsapp( 'Olá, Felipe. Procuro imóvel no ' . $termo->name . '.' ); ?>
				<?php if ( $zap ) : ?>
					<a class="fl-btn fl-btn--ouro" href="<?php echo esc_url( $zap ); ?>" target="_blank" rel="noopener"
						data-fl-evento="contato_whatsapp" data-fl-local="hub-bairro">Me chamar no WhatsApp</a>
				<?php endif; ?>
			</p>
		</div>

	<?php endif; ?>

	<aside class="fl-faixa-cta">
		<div>
			<h2>Tem imóvel no <?php echo esc_html( $termo->name ); ?> para vender?</h2>
			<p>Conheço o bairro e sei o que realmente vendeu por aqui nos últimos meses — não o que está anunciado. Avaliação gratuita.</p>
		</div>
		<a class="fl-btn fl-btn--ouro" href="<?php echo esc_url( fl_url_pagina( 'quero-vender' ) ); ?>"
			data-fl-evento="cta_captacao" data-fl-local="hub-bairro">Quero avaliar meu imóvel</a>
	</aside>

</div>

<?php
get_footer();
