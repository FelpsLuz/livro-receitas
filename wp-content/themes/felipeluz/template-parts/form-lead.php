<?php
/**
 * Formulário de captação. Recebe $args:
 *   origem     string  identificador do lead (quero-vender, imovel, contato)
 *   titulo     string
 *   texto      string
 *   botao      string
 *   campos     array   quais campos exibir além de nome/telefone/e-mail
 *   imovel_id  int
 */

defined( 'ABSPATH' ) || exit;

$origem    = $args['origem'] ?? 'contato';
$titulo    = $args['titulo'] ?? 'Fale comigo';
$texto     = $args['texto'] ?? '';
$botao     = $args['botao'] ?? 'Enviar';
$campos    = $args['campos'] ?? array( 'mensagem' );
$imovel_id = (int) ( $args['imovel_id'] ?? 0 );
?>
<section class="fl-form" id="formulario">
	<div class="fl-form__cabecalho">
		<h2><?php echo esc_html( $titulo ); ?></h2>
		<?php if ( $texto ) : ?>
			<p><?php echo esc_html( $texto ); ?></p>
		<?php endif; ?>
	</div>

	<?php fl_aviso_formulario(); ?>

	<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="fl-form__campos">
		<?php fl_campos_ocultos( $origem, $imovel_id ); ?>

		<p class="fl-campo">
			<label for="fl-nome-<?php echo esc_attr( $origem ); ?>">Nome <span aria-hidden="true">*</span></label>
			<input type="text" id="fl-nome-<?php echo esc_attr( $origem ); ?>" name="nome" required autocomplete="name">
		</p>

		<p class="fl-campo">
			<label for="fl-tel-<?php echo esc_attr( $origem ); ?>">WhatsApp <span aria-hidden="true">*</span></label>
			<input type="tel" id="fl-tel-<?php echo esc_attr( $origem ); ?>" name="telefone" required autocomplete="tel" placeholder="(11) 90000-0000">
		</p>

		<p class="fl-campo">
			<label for="fl-email-<?php echo esc_attr( $origem ); ?>">E-mail</label>
			<input type="email" id="fl-email-<?php echo esc_attr( $origem ); ?>" name="email" autocomplete="email">
		</p>

		<?php if ( in_array( 'tipo_imovel', $campos, true ) ) : ?>
			<p class="fl-campo">
				<label for="fl-tipo-<?php echo esc_attr( $origem ); ?>">Tipo de imóvel</label>
				<select id="fl-tipo-<?php echo esc_attr( $origem ); ?>" name="tipo_imovel">
					<option value="">Selecione</option>
					<?php foreach ( array( 'Apartamento', 'Casa', 'Casa em condomínio', 'Cobertura', 'Terreno', 'Comercial', 'Outro' ) as $opcao ) : ?>
						<option value="<?php echo esc_attr( $opcao ); ?>"><?php echo esc_html( $opcao ); ?></option>
					<?php endforeach; ?>
				</select>
			</p>
		<?php endif; ?>

		<?php if ( in_array( 'bairro', $campos, true ) ) : ?>
			<p class="fl-campo">
				<label for="fl-bairro-<?php echo esc_attr( $origem ); ?>">Bairro do imóvel</label>
				<input type="text" id="fl-bairro-<?php echo esc_attr( $origem ); ?>" name="bairro">
			</p>
		<?php endif; ?>

		<?php if ( in_array( 'motivo', $campos, true ) ) : ?>
			<p class="fl-campo">
				<label for="fl-motivo-<?php echo esc_attr( $origem ); ?>">Motivo da venda</label>
				<select id="fl-motivo-<?php echo esc_attr( $origem ); ?>" name="motivo">
					<option value="">Selecione</option>
					<?php foreach ( array( 'Mudança de cidade', 'Troca por imóvel maior', 'Troca por imóvel menor', 'Investimento', 'Inventário / partilha', 'Outro' ) as $opcao ) : ?>
						<option value="<?php echo esc_attr( $opcao ); ?>"><?php echo esc_html( $opcao ); ?></option>
					<?php endforeach; ?>
				</select>
			</p>
		<?php endif; ?>

		<?php if ( in_array( 'prazo', $campos, true ) ) : ?>
			<p class="fl-campo">
				<label for="fl-prazo-<?php echo esc_attr( $origem ); ?>">Em quanto tempo pretende vender?</label>
				<select id="fl-prazo-<?php echo esc_attr( $origem ); ?>" name="prazo">
					<option value="">Selecione</option>
					<?php foreach ( array( 'O quanto antes', 'Até 3 meses', 'Até 6 meses', 'Sem pressa, quero avaliar' ) as $opcao ) : ?>
						<option value="<?php echo esc_attr( $opcao ); ?>"><?php echo esc_html( $opcao ); ?></option>
					<?php endforeach; ?>
				</select>
			</p>
		<?php endif; ?>

		<?php if ( in_array( 'mensagem', $campos, true ) ) : ?>
			<p class="fl-campo fl-campo--largo">
				<label for="fl-msg-<?php echo esc_attr( $origem ); ?>">Mensagem</label>
				<textarea id="fl-msg-<?php echo esc_attr( $origem ); ?>" name="mensagem" rows="4"></textarea>
			</p>
		<?php endif; ?>

		<p class="fl-campo fl-campo--largo fl-campo--acao">
			<button type="submit" class="fl-btn fl-btn--ouro"><?php echo esc_html( $botao ); ?></button>
			<span class="fl-form__nota">Seus dados ficam comigo. Sem disparo de lista, sem repasse a terceiros.</span>
		</p>
	</form>
</section>
