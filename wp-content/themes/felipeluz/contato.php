<?php
/**
 * Template Name: Contato
 */

defined( 'ABSPATH' ) || exit;

get_header();

$zap      = fl_link_whatsapp( 'Olá, Felipe. Vim pelo site.' );
$telefone = fl_config( 'telefone' );
$email    = fl_config( 'email' );
?>

<div class="fl-pagina fl-contato">

	<header class="fl-cabecalho-secao">
		<h1>Contato</h1>
		<p class="fl-cabecalho-secao__apoio">Sem central de atendimento. Quem responde sou eu.</p>
	</header>

	<div class="fl-contato__canais">
		<?php if ( $zap ) : ?>
			<a class="fl-contato__canal" href="<?php echo esc_url( $zap ); ?>" target="_blank" rel="noopener">
				<span>WhatsApp</span>
				<strong><?php echo esc_html( fl_config( 'whatsapp' ) ); ?></strong>
			</a>
		<?php endif; ?>

		<?php if ( $telefone ) : ?>
			<a class="fl-contato__canal" href="tel:<?php echo esc_attr( preg_replace( '/\D/', '', $telefone ) ); ?>">
				<span>Telefone</span>
				<strong><?php echo esc_html( $telefone ); ?></strong>
			</a>
		<?php endif; ?>

		<?php if ( $email ) : ?>
			<a class="fl-contato__canal" href="mailto:<?php echo esc_attr( $email ); ?>">
				<span>E-mail</span>
				<strong><?php echo esc_html( $email ); ?></strong>
			</a>
		<?php endif; ?>
	</div>

	<?php
	while ( have_posts() ) :
		the_post();
		$conteudo = trim( get_the_content() );
		if ( $conteudo ) :
			?>
			<section class="fl-conteudo-editorial"><?php the_content(); ?></section>
			<?php
		endif;
	endwhile;
	?>

	<?php
	get_template_part(
		'template-parts/form-lead',
		null,
		array(
			'origem' => 'contato',
			'titulo' => 'Mande sua mensagem',
			'texto'  => 'Respondo em até 1 dia útil.',
			'botao'  => 'Enviar',
			'campos' => array( 'mensagem' ),
		)
	);
	?>

	<?php if ( fl_config( 'creci' ) ) : ?>
		<p class="fl-lp__creci">Felipe Luz · Corretor de imóveis · CRECI <?php echo esc_html( fl_config( 'creci' ) ); ?></p>
	<?php endif; ?>

</div>

<?php
get_footer();
