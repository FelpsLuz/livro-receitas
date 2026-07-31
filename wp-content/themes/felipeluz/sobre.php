<?php
/**
 * Template Name: Sobre (autoridade)
 *
 * O conteúdo abaixo é o padrão. Qualquer texto escrito no editor da
 * página substitui o bloco de biografia — o resto (números, formação,
 * CRECI, CTA) continua sendo montado a partir das configurações.
 */

defined( 'ABSPATH' ) || exit;

get_header();

$stats   = fl_estatisticas();
$anos    = fl_anos_de_atuacao();
$retrato = fl_id_retrato();
?>

<div class="fl-pagina fl-sobre">

	<nav class="fl-trilha" aria-label="Você está em">
		<ol>
			<li><a href="<?php echo esc_url( home_url( '/' ) ); ?>">Início</a></li>
			<li><span aria-current="page">Sobre</span></li>
		</ol>
	</nav>

	<section class="fl-sobre__topo">
		<?php if ( $retrato ) : ?>
			<div class="fl-sobre__foto">
				<?php
				echo wp_get_attachment_image( // phpcs:ignore WordPress.Security.EscapeOutput
					$retrato,
					'fl-card',
					false,
					array(
						'alt'           => sprintf( '%s, %s em %s', fl_config( 'nome' ), strtolower( fl_config( 'papel' ) ), fl_config( 'cidade' ) ),
						'loading'       => 'eager',
						'fetchpriority' => 'high',
						'sizes'         => '(max-width: 700px) 100vw, 380px',
					)
				);
				?>
			</div>
		<?php endif; ?>

		<div class="fl-sobre__texto">
			<h1>Sua confiança, minha dedicação.</h1>

			<?php
			while ( have_posts() ) :
				the_post();
				$conteudo = trim( get_the_content() );
			endwhile;
			rewind_posts();

			if ( ! empty( $conteudo ) ) :
				?>
				<div class="fl-sobre__bio">
					<?php
					while ( have_posts() ) :
						the_post();
						the_content();
					endwhile;
					?>
				</div>
			<?php else : ?>
				<div class="fl-sobre__bio">
					<p>
						Olá, sou <strong><?php echo esc_html( fl_config( 'nome' ) ); ?></strong>, seu
						<?php echo esc_html( strtolower( fl_config( 'papel' ) ) ); ?> em
						<?php echo esc_html( fl_config( 'cidade' ) ); ?>.
					</p>
					<p>
						Com 13 anos em vendas B2B/B2C e 3 anos atuando no mercado imobiliário, sou
						Técnico em Administração, Técnico em Transações Imobiliárias e formado em
						Gestão Comercial pela PUCRS. Tenho verdadeira paixão pelo mercado imobiliário
						de <?php echo esc_html( fl_config( 'cidade' ) ); ?> e um compromisso inabalável
						com a excelência. Minha missão é simplificar e aprimorar sua experiência de
						compra, venda ou investimento em imóveis, sempre com estratégia, visão de
						mercado e cuidado em cada detalhe.
					</p>
					<p>
						Mais do que um corretor, sou seu consultor estratégico, aliado e defensor em
						cada negociação. Também sou empreendedor e apaixonado por transformar projetos
						em realidade, garantindo que cada transação seja tão gratificante quanto o seu
						novo lar ou investimento.
					</p>
					<p>
						Fora do trabalho, tenho meu maior tesouro: sou pai de duas lindas meninas e um
						marido apaixonado, encontrando na família a inspiração diária para oferecer o
						meu melhor em tudo o que faço.
					</p>
				</div>
			<?php endif; ?>

			<ul class="fl-sobre__credenciais">
				<?php if ( fl_config( 'creci' ) ) : ?>
					<li><strong><?php echo esc_html( fl_config( 'creci' ) ); ?></strong><span>Registro profissional</span></li>
				<?php endif; ?>
				<li><strong>Especialista em <?php echo esc_html( fl_config( 'cidade' ) ); ?></strong><span>Mercado de atuação</span></li>
				<li><strong>Gestão Comercial — PUCRS</strong><span>Formação</span></li>
				<li><strong>Técnico em Transações Imobiliárias</strong><span>Formação</span></li>
			</ul>
		</div>
	</section>

	<?php
	$provas = array();
	if ( $stats['vendidos'] > 0 ) {
		$provas[] = array( number_format_i18n( $stats['vendidos'] ), 'imóveis vendidos' );
	}
	if ( $anos > 0 ) {
		$provas[] = array( $anos, 1 === $anos ? 'ano no mercado imobiliário' : 'anos no mercado imobiliário' );
	}
	if ( $stats['dias_medio'] > 0 ) {
		$provas[] = array( $stats['dias_medio'], 'dias, em média, da captação à venda' );
	}
	if ( $stats['ticket_medio'] > 0 ) {
		$provas[] = array( fl_valor_brl( $stats['ticket_medio'] ), 'ticket médio negociado' );
	}

	if ( $provas ) :
		?>
		<section class="fl-numeros" aria-label="Números do trabalho">
			<?php foreach ( $provas as $prova ) : ?>
				<div><strong><?php echo esc_html( $prova[0] ); ?></strong><span><?php echo esc_html( $prova[1] ); ?></span></div>
			<?php endforeach; ?>
		</section>
	<?php endif; ?>

	<?php
	$perfis = array(
		'google'    => 'Google Business Profile',
		'instagram' => 'Instagram',
		'linkedin'  => 'LinkedIn',
	);
	$links = array();
	foreach ( $perfis as $chave => $rotulo ) {
		$url = fl_config( $chave );
		if ( $url ) {
			$links[ $rotulo ] = $url;
		}
	}

	if ( $links ) :
		?>
		<section class="fl-secao fl-sobre__perfis">
			<h2>Onde mais me encontrar</h2>
			<ul>
				<?php foreach ( $links as $rotulo => $url ) : ?>
					<li><a href="<?php echo esc_url( $url ); ?>" target="_blank" rel="noopener me"><?php echo esc_html( $rotulo ); ?></a></li>
				<?php endforeach; ?>
			</ul>
		</section>
	<?php endif; ?>

	<aside class="fl-faixa-cta">
		<div>
			<h2>Quer conversar sobre o seu imóvel?</h2>
			<p>Avaliação gratuita, com comparativo real do seu bairro. Sem compromisso e sem discurso pronto.</p>
		</div>
		<a class="fl-btn fl-btn--ouro" href="<?php echo esc_url( fl_url_pagina( 'quero-vender' ) ); ?>"
			data-fl-evento="cta_captacao" data-fl-local="sobre">Quero uma avaliação</a>
	</aside>

</div>

<?php
get_footer();
