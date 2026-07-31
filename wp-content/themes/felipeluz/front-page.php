<?php
/**
 * Home. Duas portas: quem compra e quem vende.
 * A porta que paga a conta é a segunda.
 */

defined( 'ABSPATH' ) || exit;

get_header();

$stats     = fl_estatisticas();
$destaques = fl_query_destaques( 6 );
$vendidos  = fl_query_vendidos( 3 );
?>

<div class="fl-pagina fl-home">

	<section class="fl-hero">
		<div class="fl-hero__texto">
			<p class="fl-hero__sobre">
				<?php echo esc_html( fl_config( 'cidade' ) ? fl_config( 'cidade' ) . ' · ' : '' ); ?>Corretor de imóveis<?php echo fl_config( 'creci' ) ? esc_html( ' · CRECI ' . fl_config( 'creci' ) ) : ''; ?>
			</p>
			<h1>Poucos imóveis por vez.<br>Atenção integral em cada um.</h1>
			<p class="fl-hero__apoio">
				Não trabalho com volume. Trabalho com uma carteira curta, que eu conheço de cor,
				e com proprietários que querem vender de verdade — não apenas anunciar.
			</p>
			<p class="fl-hero__acoes">
				<a class="fl-btn fl-btn--ouro" href="<?php echo esc_url( fl_url_pagina( 'quero-vender' ) ); ?>">Quero vender meu imóvel</a>
				<a class="fl-btn fl-btn--linha-clara" href="<?php echo esc_url( get_post_type_archive_link( 'imovel' ) ); ?>">Ver imóveis disponíveis</a>
			</p>
		</div>
	</section>

	<?php if ( $stats['vendidos'] > 0 || $stats['ativos'] > 0 ) : ?>
		<section class="fl-numeros" aria-label="Números do trabalho">
			<?php if ( $stats['vendidos'] > 0 ) : ?>
				<div><strong><?php echo (int) $stats['vendidos']; ?></strong><span>imóveis vendidos</span></div>
			<?php endif; ?>
			<?php if ( $stats['dias_medio'] > 0 ) : ?>
				<div><strong><?php echo (int) $stats['dias_medio']; ?></strong><span>dias, em média, da captação à venda</span></div>
			<?php endif; ?>
			<?php if ( $stats['ativos'] > 0 ) : ?>
				<div><strong><?php echo (int) $stats['ativos']; ?></strong><span>imóveis na carteira ativa</span></div>
			<?php endif; ?>
			<?php if ( $stats['ticket_medio'] > 0 ) : ?>
				<div><strong><?php echo esc_html( fl_valor_brl( $stats['ticket_medio'] ) ); ?></strong><span>ticket médio negociado</span></div>
			<?php endif; ?>
		</section>
	<?php endif; ?>

	<?php if ( $destaques->have_posts() ) : ?>
		<section class="fl-secao">
			<header class="fl-cabecalho-secao">
				<h2>Na carteira agora</h2>
				<a class="fl-link-secao" href="<?php echo esc_url( get_post_type_archive_link( 'imovel' ) ); ?>">Ver todos</a>
			</header>
			<div class="fl-grade fl-grade--3">
				<?php
				while ( $destaques->have_posts() ) :
					$destaques->the_post();
					get_template_part( 'template-parts/card-imovel' );
				endwhile;
				wp_reset_postdata();
				?>
			</div>
		</section>
	<?php endif; ?>

	<section class="fl-secao fl-metodo">
		<header class="fl-cabecalho-secao">
			<h2>Como eu vendo um imóvel</h2>
			<p class="fl-cabecalho-secao__apoio">Proprietário não compra simpatia. Compra processo.</p>
		</header>
		<ol class="fl-etapas">
			<li>
				<span class="fl-etapas__numero">01</span>
				<h3>Avaliação com dados</h3>
				<p>Comparativo de mercado do seu bairro, não chute. Você vai saber por que o preço é aquele — e o que acontece se insistir em outro.</p>
			</li>
			<li>
				<span class="fl-etapas__numero">02</span>
				<h3>Preparação do imóvel</h3>
				<p>Fotografia profissional, ajustes que valorizam e documentação conferida antes de ir ao mercado. Imóvel só estreia uma vez.</p>
			</li>
			<li>
				<span class="fl-etapas__numero">03</span>
				<h3>Divulgação dirigida</h3>
				<p>Portais, minha base de compradores e rede de corretores parceiros. Visita filtrada: quem entra na sua casa tem perfil e condição.</p>
			</li>
			<li>
				<span class="fl-etapas__numero">04</span>
				<h3>Negociação e fechamento</h3>
				<p>Eu negocio, você decide. Acompanho proposta, financiamento, cartório e chaves — sem você precisar entender de nada disso.</p>
			</li>
		</ol>
		<p class="fl-metodo__cta">
			<a class="fl-btn fl-btn--ouro" href="<?php echo esc_url( fl_url_pagina( 'quero-vender' ) ); ?>">Quero uma avaliação do meu imóvel</a>
		</p>
	</section>

	<?php if ( $vendidos->have_posts() ) : ?>
		<section class="fl-secao fl-secao--escura">
			<header class="fl-cabecalho-secao">
				<h2>Vendidos recentemente</h2>
				<a class="fl-link-secao" href="<?php echo esc_url( fl_url_pagina( 'vendidos' ) ); ?>">Ver todos os vendidos</a>
			</header>
			<div class="fl-grade fl-grade--3">
				<?php
				while ( $vendidos->have_posts() ) :
					$vendidos->the_post();
					get_template_part( 'template-parts/card-imovel' );
				endwhile;
				wp_reset_postdata();
				?>
			</div>
		</section>
	<?php endif; ?>

	<?php
	// A home também captura. Formulário curto: o longo mora na LP.
	get_template_part(
		'template-parts/form-lead',
		null,
		array(
			'origem' => 'contato',
			'titulo' => 'Vamos conversar',
			'texto'  => 'Comprando, vendendo ou só querendo entender o mercado do seu bairro. Respondo pessoalmente.',
			'botao'  => 'Enviar mensagem',
			'campos' => array( 'mensagem' ),
		)
	);
	?>

</div>

<?php
get_footer();
