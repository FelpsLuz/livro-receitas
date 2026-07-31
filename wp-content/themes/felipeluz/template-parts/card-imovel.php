<?php
/**
 * Card do imóvel — usado na vitrine, na home e nos relacionados.
 */

defined( 'ABSPATH' ) || exit;

$post_id  = get_the_ID();
$vendido  = fl_esta_vendido( $post_id );
$dias     = $vendido ? fl_dias_para_venda( $post_id ) : 0;
$atributos = fl_atributos( $post_id );
?>
<article class="fl-card<?php echo $vendido ? ' fl-card--vendido' : ''; ?>">
	<a class="fl-card__link" href="<?php the_permalink(); ?>">
		<div class="fl-card__foto">
			<?php if ( has_post_thumbnail() ) : ?>
				<?php the_post_thumbnail( 'fl-card', array( 'loading' => 'lazy', 'alt' => esc_attr( get_the_title() ) ) ); ?>
			<?php else : ?>
				<div class="fl-card__sem-foto" aria-hidden="true"></div>
			<?php endif; ?>

			<?php echo fl_selo( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput ?>

			<?php if ( fl_campo( 'exclusividade', $post_id ) && ! $vendido ) : ?>
				<span class="fl-selo fl-selo--exclusivo">Exclusividade</span>
			<?php endif; ?>
		</div>

		<div class="fl-card__corpo">
			<p class="fl-card__local"><?php echo esc_html( fl_localizacao( $post_id ) ); ?></p>
			<h3 class="fl-card__titulo"><?php the_title(); ?></h3>

			<?php if ( $vendido ) : ?>
				<p class="fl-card__preco fl-card__preco--vendido">
					<?php echo $dias ? esc_html( 'Vendido em ' . $dias . ' dias' ) : 'Vendido'; ?>
				</p>
			<?php else : ?>
				<p class="fl-card__preco"><?php echo esc_html( fl_preco( $post_id ) ); ?></p>
			<?php endif; ?>

			<?php if ( $atributos ) : ?>
				<ul class="fl-card__ficha">
					<?php foreach ( $atributos as $atributo ) : ?>
						<li><strong><?php echo esc_html( $atributo['valor'] ); ?></strong> <?php echo esc_html( $atributo['rotulo'] ); ?></li>
					<?php endforeach; ?>
				</ul>
			<?php endif; ?>
		</div>
	</a>
</article>
