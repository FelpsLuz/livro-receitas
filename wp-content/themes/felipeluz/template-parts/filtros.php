<?php
/**
 * Filtro da vitrine.
 *
 * Abre fechado, como bottom sheet no mobile — nunca seis selects
 * empilhados ocupando a primeira tela. Construído com <details>, então
 * abre e fecha sem JavaScript e continua funcionando se o script falhar.
 *
 * Formulário GET puro: cada filtro é uma URL, rastreável e compartilhável.
 */

defined( 'ABSPATH' ) || exit;

$filtros = fl_filtros_ativos();
$acao    = get_post_type_archive_link( 'imovel' );
$ativos  = fl_tem_filtro_ativo();

$selects = array(
	'tipo'       => array( 'taxonomia' => 'imovel_tipo', 'rotulo' => 'Tipo', 'vazio' => 'Todos os tipos' ),
	'finalidade' => array( 'taxonomia' => 'imovel_finalidade', 'rotulo' => 'Finalidade', 'vazio' => 'Comprar ou alugar' ),
	'bairro'     => array( 'taxonomia' => 'imovel_bairro', 'rotulo' => 'Bairro', 'vazio' => 'Todos os bairros' ),
);
?>
<details class="fl-filtros" <?php echo $ativos ? 'open' : ''; ?>>
	<summary class="fl-filtros__gatilho">
		<span class="fl-filtros__gatilho-texto">
			<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true">
				<path d="M4 6h16M7 12h10M10 18h4"/>
			</svg>
			Filtrar imóveis
		</span>
		<?php if ( $ativos ) : ?>
			<span class="fl-filtros__marcador">filtro ativo</span>
		<?php endif; ?>
	</summary>

	<form class="fl-filtros__painel" method="get" action="<?php echo esc_url( $acao ); ?>">
		<div class="fl-filtros__campos">
			<?php
			foreach ( $selects as $nome => $config ) :
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
						<option value="<?php echo esc_attr( $n ); ?>" <?php selected( $filtros['dorm'], $n ); ?>><?php echo esc_html( $n ); ?> ou mais</option>
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
				<label for="fl-ordem">Ordenar por</label>
				<select id="fl-ordem" name="ordem">
					<option value="recentes" <?php selected( $filtros['ordem'], 'recentes' ); ?>>Mais recentes</option>
					<option value="preco_asc" <?php selected( $filtros['ordem'], 'preco_asc' ); ?>>Menor preço</option>
					<option value="preco_desc" <?php selected( $filtros['ordem'], 'preco_desc' ); ?>>Maior preço</option>
				</select>
			</div>
		</div>

		<div class="fl-filtros__acoes">
			<button type="submit" class="fl-btn fl-btn--escuro">Ver resultados</button>
			<?php if ( $ativos ) : ?>
				<a class="fl-filtros__limpar" href="<?php echo esc_url( $acao ); ?>">Limpar filtros</a>
			<?php endif; ?>
		</div>
	</form>
</details>
