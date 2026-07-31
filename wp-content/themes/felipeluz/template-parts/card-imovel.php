<?php
/**
 * Card do imóvel. Coluna única no mobile, foto 4:3, preço em destaque,
 * bairro e três dados: dormitórios, vagas e metragem. Nada além disso —
 * card é para decidir se vale abrir, não para decidir a compra.
 */

defined( 'ABSPATH' ) || exit;

$post_id  = get_the_ID();
$vendido  = fl_esta_vendido( $post_id );
$dias     = $vendido ? fl_dias_para_venda( $post_id ) : 0;
$capa_id  = get_post_thumbnail_id( $post_id );

$dados = array(
	array( 'dormitorios', 'dorm.', 'quarto' ),
	array( 'vagas', 'vagas', 'vaga' ),
	array( 'area_util', 'm²', 'area' ),
);
?>
<article class="fl-card<?php echo $vendido ? ' fl-card--vendido' : ''; ?>">
	<a class="fl-card__link" href="<?php the_permalink(); ?>">
		<div class="fl-card__foto">
			<?php if ( $capa_id ) : ?>
				<?php
				echo wp_get_attachment_image( // phpcs:ignore WordPress.Security.EscapeOutput
					$capa_id,
					'fl-card',
					false,
					array(
						'alt'      => fl_alt_foto( $capa_id, $post_id ),
						'loading'  => 'lazy',
						'decoding' => 'async',
						'sizes'    => '(max-width: 700px) 100vw, 380px',
					)
				);
				?>
			<?php else : ?>
				<div class="fl-card__sem-foto" aria-hidden="true"></div>
			<?php endif; ?>

			<?php echo fl_selo( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput ?>

			<?php if ( fl_campo( 'exclusividade', $post_id ) && ! $vendido ) : ?>
				<span class="fl-selo fl-selo--exclusivo">Exclusividade</span>
			<?php endif; ?>
		</div>

		<div class="fl-card__corpo">
			<?php if ( $vendido ) : ?>
				<p class="fl-card__preco fl-card__preco--vendido">
					<?php echo $dias ? esc_html( 'Vendido em ' . $dias . ' dias' ) : 'Vendido'; ?>
				</p>
			<?php else : ?>
				<p class="fl-card__preco"><?php echo esc_html( fl_preco( $post_id ) ); ?></p>
			<?php endif; ?>

			<p class="fl-card__local"><?php echo esc_html( fl_localizacao( $post_id ) ); ?></p>
			<h3 class="fl-card__titulo"><?php the_title(); ?></h3>

			<ul class="fl-card__dados">
				<?php
				foreach ( $dados as $dado ) :
					$valor = (float) fl_campo( $dado[0], $post_id, 0 );
					if ( $valor <= 0 ) {
						continue;
					}
					?>
					<li>
						<?php fl_icone( $dado[2] ); ?>
						<span><?php echo esc_html( fl_numero( $valor ) . ( 'area_util' === $dado[0] ? ' ' : ' ' ) . $dado[1] ); ?></span>
					</li>
				<?php endforeach; ?>
			</ul>
		</div>
	</a>
</article>
