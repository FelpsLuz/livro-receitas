<?php
/**
 * Filtro da vitrine: formulário GET puro.
 */

defined( 'ABSPATH' ) || exit;

$filtros = fl_filtros_ativos();
$acao    = get_post_type_archive_link( 'imovel' );

$selects = array(
	'tipo'       => array( 'taxonomia' => 'imovel_tipo', 'rotulo' => 'Tipo', 'vazio' => 'Todos os tipos' ),
	'finalidade' => array( 'taxonomia' => 'imovel_finalidade', 'rotulo' => 'Finalidade', 'vazio' => 'Comprar ou alugar' ),
	'bairro'     => array( 'taxonomia' => 'imovel_bairro', 'rotulo' => 'Bairro', 'vazio' => 'Todos os bairros' ),
);
?>
<form class="fl-filtros" method="get" action="<?php echo esc_url( $acao ); ?>">
	<?php foreach ( $selects as $nome => $config ) :
		$termos = get_terms(
			array(
				'taxonomy'   => $config['taxonomia'],
				'hide_empty' => true,
			)
		);
		if ( is_wp_error( $termos ) || ! $termos ) {
			continue;
		}
		?>
		<div class="fl-filtros__campo">
			<label for="fl-<?php echo esc_attr( $nome ); ?>"><?php echo esc_html( $config['rotulo'] ); ?></label>
			<select id="fl-<?php echo esc_attr( $nome ); ?>" name="<?php echo esc_attr( $nome ); ?>">
				<option value=""><?php echo esc_html( $config['vazio'] ); ?></option>
				<?php foreach ( $termos as $termo ) : ?>
					<option value="<?php echo esc_attr( $termo->slug ); ?>" <?php selected( $filtros[ $nome ], $termo->slug ); ?>>
						<?php echo esc_html( $termo->name ); ?>
					</option>
				<?php endforeach; ?>
			</select>
		</div>
	<?php endforeach; ?>

	<div class="fl-filtros__campo">
		<label for="fl-dorm">Dormitórios</label>
		<select id="fl-dorm" name="dorm">
			<option value="">Qualquer</option>
			<?php foreach ( array( 1, 2, 3, 4 ) as $n ) : ?>
				<option value="<?php echo esc_attr( $n ); ?>" <?php selected( $filtros['dorm'], $n ); ?>><?php echo esc_html( $n ); ?>+</option>
			<?php endforeach; ?>
		</select>
	</div>

	<div class="fl-filtros__campo">
		<label for="fl-preco-max">Até</label>
		<select id="fl-preco-max" name="preco_max">
			<option value="">Sem limite</option>
			<?php foreach ( array( 300000, 500000, 800000, 1200000, 2000000, 3000000 ) as $faixa ) : ?>
				<option value="<?php echo esc_attr( $faixa ); ?>" <?php selected( (int) $filtros['preco_max'], $faixa ); ?>>
					<?php echo esc_html( fl_valor_brl( $faixa ) ); ?>
				</option>
			<?php endforeach; ?>
		</select>
	</div>

	<div class="fl-filtros__campo">
		<label for="fl-ordem">Ordenar</label>
		<select id="fl-ordem" name="ordem">
			<option value="recentes" <?php selected( $filtros['ordem'], 'recentes' ); ?>>Mais recentes</option>
			<option value="preco_asc" <?php selected( $filtros['ordem'], 'preco_asc' ); ?>>Menor preço</option>
			<option value="preco_desc" <?php selected( $filtros['ordem'], 'preco_desc' ); ?>>Maior preço</option>
		</select>
	</div>

	<div class="fl-filtros__acoes">
		<button type="submit" class="fl-btn fl-btn--escuro">Filtrar</button>
		<?php if ( fl_tem_filtro_ativo() ) : ?>
			<a class="fl-filtros__limpar" href="<?php echo esc_url( $acao ); ?>">Limpar</a>
		<?php endif; ?>
	</div>
</form>
