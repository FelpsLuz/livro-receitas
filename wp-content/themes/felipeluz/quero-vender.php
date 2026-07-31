<?php
/**
 * Template Name: Quero vender (captação)
 *
 * A página de maior valor comercial do site. Tudo aqui existe para
 * transformar um proprietário indeciso em uma conversa.
 */

defined( 'ABSPATH' ) || exit;

get_header();

$stats    = fl_estatisticas();
$vendidos = fl_query_vendidos( 6 );
?>

<div class="fl-pagina fl-lp">

	<section class="fl-lp__hero">
		<h1>Seu imóvel está parado há meses?</h1>
		<p class="fl-lp__subtitulo">
			Anúncio disputado por cinco corretores, visita que não volta, proposta que nunca chega.
			O problema quase nunca é o imóvel — é a forma como ele foi colocado no mercado.
		</p>
		<p class="fl-lp__acoes">
			<a class="fl-btn fl-btn--ouro" href="#formulario">Quero uma avaliação gratuita</a>
			<?php $zap = fl_link_whatsapp( 'Olá, Felipe. Quero avaliar meu imóvel para venda.' ); ?>
			<?php if ( $zap ) : ?>
				<a class="fl-btn fl-btn--linha-clara" href="<?php echo esc_url( $zap ); ?>" target="_blank" rel="noopener">Falar agora no WhatsApp</a>
			<?php endif; ?>
		</p>
	</section>

	<?php if ( $stats['vendidos'] > 0 ) : ?>
		<section class="fl-numeros fl-numeros--lp" aria-label="Resultados">
			<div><strong><?php echo (int) $stats['vendidos']; ?></strong><span>imóveis vendidos</span></div>
			<?php if ( $stats['dias_medio'] > 0 ) : ?>
				<div><strong><?php echo (int) $stats['dias_medio']; ?> dias</strong><span>média entre captação e venda</span></div>
			<?php endif; ?>
			<?php if ( $stats['ticket_medio'] > 0 ) : ?>
				<div><strong><?php echo esc_html( fl_valor_brl( $stats['ticket_medio'] ) ); ?></strong><span>ticket médio negociado</span></div>
			<?php endif; ?>
			<div><strong>1 a 1</strong><span>eu mesmo conduzo, do começo ao fim</span></div>
		</section>
	<?php endif; ?>

	<section class="fl-secao fl-metodo">
		<header class="fl-cabecalho-secao">
			<h2>O método</h2>
			<p class="fl-cabecalho-secao__apoio">Quatro etapas. Você sabe exatamente onde seu imóvel está em cada uma delas.</p>
		</header>
		<ol class="fl-etapas">
			<li>
				<span class="fl-etapas__numero">01</span>
				<h3>Avaliação</h3>
				<p>Visito o imóvel e monto um comparativo com o que realmente vendeu no seu bairro nos últimos meses — não com o que está anunciado. Preço de anúncio não é preço de venda.</p>
			</li>
			<li>
				<span class="fl-etapas__numero">02</span>
				<h3>Preparação</h3>
				<p>Fotografia profissional por minha conta, orientação sobre os ajustes que pagam a si mesmos e checagem da documentação antes de anunciar. Imóvel com pendência trava na reta final.</p>
			</li>
			<li>
				<span class="fl-etapas__numero">03</span>
				<h3>Divulgação</h3>
				<p>Portais, minha base de compradores ativos e rede de parceiros. Filtro as visitas: quem entra na sua casa tem perfil e condição de compra confirmada.</p>
			</li>
			<li>
				<span class="fl-etapas__numero">04</span>
				<h3>Negociação</h3>
				<p>Conduzo a proposta, o financiamento e o cartório. Você recebe o resumo, decide, e assina. Sem grupo de WhatsApp com sete corretores.</p>
			</li>
		</ol>
	</section>

	<section class="fl-secao fl-diferenciais">
		<header class="fl-cabecalho-secao">
			<h2>Por que dar exclusividade a um corretor só</h2>
		</header>
		<div class="fl-diferenciais__grade">
			<div>
				<h3>Imóvel em cinco lugares vale menos</h3>
				<p>O comprador que vê o mesmo imóvel anunciado por cinco corretores, com cinco preços, entende uma coisa só: dá para pechinchar. Anúncio disperso derruba o valor final.</p>
			</div>
			<div>
				<h3>Investimento de verdade na sua venda</h3>
				<p>Fotografia profissional, tráfego pago e tempo de agenda custam caro. Nenhum corretor investe assim em imóvel que pode ser vendido por outro amanhã.</p>
			</div>
			<div>
				<h3>Um interlocutor, uma versão</h3>
				<p>Você não precisa repetir a mesma história para cinco pessoas nem descobrir por terceiros que houve uma visita. Um responsável, um relatório, uma linha de negociação.</p>
			</div>
			<div>
				<h3>Prazo com hora marcada</h3>
				<p>Contrato de exclusividade com prazo definido. Se eu não entregar, você está livre. O risco é meu, não seu.</p>
			</div>
		</div>
	</section>

	<?php if ( $vendidos->have_posts() ) : ?>
		<section class="fl-secao fl-secao--escura">
			<header class="fl-cabecalho-secao">
				<h2>Não é promessa. É histórico.</h2>
				<p class="fl-cabecalho-secao__apoio">Cada um destes imóveis já foi um proprietário na mesma dúvida que você está agora.</p>
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
			<p class="fl-secao__rodape">
				<a class="fl-link-secao" href="<?php echo esc_url( fl_url_pagina( 'vendidos' ) ); ?>">Ver o histórico completo</a>
			</p>
		</section>
	<?php endif; ?>

	<?php
	get_template_part(
		'template-parts/form-lead',
		null,
		array(
			'origem' => 'quero-vender',
			'titulo' => 'Avaliação gratuita, sem compromisso',
			'texto'  => 'Cinco campos. Retorno em até 1 dia útil com uma faixa de preço realista para o seu imóvel.',
			'botao'  => 'Quero avaliar meu imóvel',
			'campos' => array( 'tipo_imovel', 'bairro', 'motivo', 'prazo' ),
		)
	);
	?>

	<?php
	// O conteúdo editável da página entra aqui, se houver.
	while ( have_posts() ) :
		the_post();
		$conteudo = trim( get_the_content() );
		if ( $conteudo ) :
			?>
			<section class="fl-secao fl-conteudo-editorial"><?php the_content(); ?></section>
			<?php
		endif;
	endwhile;
	?>

	<?php if ( fl_config( 'creci' ) ) : ?>
		<p class="fl-lp__creci">Felipe Luz · Corretor de imóveis · CRECI <?php echo esc_html( fl_config( 'creci' ) ); ?></p>
	<?php endif; ?>

</div>

<?php
get_footer();
