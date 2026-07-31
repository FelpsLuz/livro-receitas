<?php
/**
 * Home.
 *
 * Momento 1 (0–3s): rosto, nome, CRECI, posicionamento e dois botões
 * distintos. Sem carrossel, sem popup, sem interstitial.
 * Momento 2 (3–15s): a decisão de confiar — CRECI visível, números
 * concretos e avaliações reais.
 */

defined( 'ABSPATH' ) || exit;

get_header();

$stats     = fl_estatisticas();
$anos      = fl_anos_de_atuacao();
$avaliacoes = fl_avaliacoes( 3 );
$destaques = fl_query_destaques( 6 );
$vendidos  = fl_query_vendidos( 3 );
?>

<div class="fl-pagina fl-home">

	<section class="fl-hero">
		<div class="fl-hero__conteudo">
			<div class="fl-hero__texto">
				<p class="fl-hero__sobre">
					<?php echo esc_html( fl_config( 'papel' ) ); ?> em <?php echo esc_html( fl_config( 'cidade' ) ); ?>
					<?php if ( fl_config( 'creci' ) ) : ?>
						<span class="fl-hero__creci"><?php echo esc_html( fl_config( 'creci' ) ); ?></span>
					<?php endif; ?>
				</p>

				<h1>Sua confiança,<br>minha dedicação.</h1>

				<p class="fl-hero__apoio">
					Sou <strong><?php echo esc_html( fl_config( 'nome' ) ); ?></strong>. Trabalho com uma carteira
					curta, que conheço de cor, e com proprietários que querem vender de verdade —
					não apenas anunciar. Estratégia, visão de mercado e cuidado em cada detalhe.
				</p>

				<p class="fl-hero__acoes">
					<a class="fl-btn fl-btn--ouro" href="<?php echo esc_url( fl_url_pagina( 'quero-vender' ) ); ?>"
						data-fl-evento="cta_captacao" data-fl-local="hero">Quero vender meu imóvel</a>
					<a class="fl-btn fl-btn--linha-clara" href="<?php echo esc_url( get_post_type_archive_link( 'imovel' ) ); ?>"
						data-fl-evento="cta_vitrine" data-fl-local="hero">Ver imóveis</a>
				</p>
			</div>

			<div class="fl-hero__foto">
				<?php fl_imagem_hero(); ?>
			</div>
		</div>
	</section>

	<?php
	/* Momento 2 — a decisão de confiar. */
	$provas = array();
	if ( $stats['vendidos'] > 0 ) {
		$provas[] = array( $stats['vendidos'], 'imóveis vendidos' );
	}
	if ( $anos > 0 ) {
		$provas[] = array( $anos, 1 === $anos ? 'ano no mercado imobiliário' : 'anos no mercado imobiliário' );
	}
	if ( $stats['dias_medio'] > 0 ) {
		$provas[] = array( $stats['dias_medio'], 'dias, em média, da captação à venda' );
	}
	if ( $stats['ativos'] > 0 ) {
		$provas[] = array( $stats['ativos'], 'imóveis na carteira ativa' );
	}

	if ( $provas ) :
		?>
		<section class="fl-numeros" aria-label="Números do trabalho">
			<?php foreach ( $provas as $prova ) : ?>
				<div>
					<strong><?php echo esc_html( number_format_i18n( $prova[0] ) ); ?></strong>
					<span><?php echo esc_html( $prova[1] ); ?></span>
				</div>
			<?php endforeach; ?>
		</section>
	<?php endif; ?>

	<?php if ( $avaliacoes ) : ?>
		<section class="fl-secao fl-avaliacoes">
			<header class="fl-cabecalho-secao">
				<h2>O que dizem quem já passou por aqui</h2>
				<?php if ( fl_config( 'google' ) ) : ?>
					<a class="fl-link-secao" href="<?php echo esc_url( fl_config( 'google' ) ); ?>" target="_blank" rel="noopener">Ver no Google</a>
				<?php endif; ?>
			</header>
			<div class="fl-avaliacoes__grade">
				<?php
				foreach ( $avaliacoes as $avaliacao ) :
					$nota = (int) get_post_meta( $avaliacao->ID, 'fl_nota', true );
					$nota = $nota ? $nota : 5;
					?>
					<figure class="fl-avaliacao">
						<p class="fl-avaliacao__estrelas" aria-label="<?php echo esc_attr( $nota . ' de 5 estrelas' ); ?>">
							<?php echo esc_html( str_repeat( '★', $nota ) . str_repeat( '☆', 5 - $nota ) ); ?>
						</p>
						<blockquote><?php echo esc_html( wp_strip_all_tags( $avaliacao->post_content ) ); ?></blockquote>
						<figcaption>
							<?php echo esc_html( $avaliacao->post_title ); ?>
							<?php if ( 'google' === get_post_meta( $avaliacao->ID, 'fl_origem', true ) ) : ?>
								<small>avaliação no Google</small>
							<?php endif; ?>
						</figcaption>
					</figure>
				<?php endforeach; ?>
			</div>
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
			<a class="fl-btn fl-btn--ouro" href="<?php echo esc_url( fl_url_pagina( 'quero-vender' ) ); ?>"
				data-fl-evento="cta_captacao" data-fl-local="metodo">Quero uma avaliação do meu imóvel</a>
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
