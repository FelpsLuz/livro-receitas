<?php
/**
 * Formulário de captação.
 *
 * Detalhes que não são detalhe no mobile:
 *  - font-size 16px nos inputs (abaixo disso o iOS dá zoom e quebra a tela)
 *  - inputmode para abrir o teclado certo
 *  - alvo de toque de 44px
 *  - nenhum CAPTCHA visível: honeypot + armadilha de tempo, no servidor
 *
 * Recebe $args: origem, titulo, texto, botao, campos[], imovel_id.
 */

defined( 'ABSPATH' ) || exit;

$origem    = $args['origem'] ?? 'contato';
$titulo    = $args['titulo'] ?? 'Fale comigo';
$texto     = $args['texto'] ?? '';
$botao     = $args['botao'] ?? 'Enviar';
$campos    = $args['campos'] ?? array( 'mensagem' );
$imovel_id = (int) ( $args['imovel_id'] ?? 0 );
$id        = 'fl-' . $origem;
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
			<label for="<?php echo esc_attr( $id ); ?>-nome">Nome <span aria-hidden="true">*</span></label>
			<input type="text" id="<?php echo esc_attr( $id ); ?>-nome" name="nome" required
				autocomplete="name" inputmode="text" enterkeyhint="next">
		</p>

		<p class="fl-campo">
			<label for="<?php echo esc_attr( $id ); ?>-tel">WhatsApp <span aria-hidden="true">*</span></label>
			<input type="tel" id="<?php echo esc_attr( $id ); ?>-tel" name="telefone" required
				autocomplete="tel" inputmode="tel" enterkeyhint="next" placeholder="(15) 90000-0000">
		</p>

		<?php if ( in_array( 'melhor_horario', $campos, true ) ) : ?>
			<p class="fl-campo">
				<label for="<?php echo esc_attr( $id ); ?>-horario">Melhor horário para eu ligar</label>
				<select id="<?php echo esc_attr( $id ); ?>-horario" name="melhor_horario">
					<option value="">Qualquer horário</option>
					<?php foreach ( array( 'Manhã (8h às 12h)', 'Tarde (12h às 18h)', 'Noite (18h às 21h)', 'Prefiro só mensagem' ) as $opcao ) : ?>
						<option value="<?php echo esc_attr( $opcao ); ?>"><?php echo esc_html( $opcao ); ?></option>
					<?php endforeach; ?>
				</select>
			</p>
		<?php else : ?>
			<p class="fl-campo">
				<label for="<?php echo esc_attr( $id ); ?>-email">E-mail</label>
				<input type="email" id="<?php echo esc_attr( $id ); ?>-email" name="email"
					autocomplete="email" inputmode="email" enterkeyhint="next">
			</p>
		<?php endif; ?>

		<?php if ( in_array( 'tipo_imovel', $campos, true ) ) : ?>
			<p class="fl-campo">
				<label for="<?php echo esc_attr( $id ); ?>-tipo">Tipo de imóvel</label>
				<select id="<?php echo esc_attr( $id ); ?>-tipo" name="tipo_imovel">
					<option value="">Selecione</option>
					<?php foreach ( array( 'Apartamento', 'Casa', 'Casa em condomínio', 'Cobertura', 'Terreno', 'Comercial', 'Outro' ) as $opcao ) : ?>
						<option value="<?php echo esc_attr( $opcao ); ?>"><?php echo esc_html( $opcao ); ?></option>
					<?php endforeach; ?>
				</select>
			</p>
		<?php endif; ?>

		<?php if ( in_array( 'bairro', $campos, true ) ) : ?>
			<p class="fl-campo">
				<label for="<?php echo esc_attr( $id ); ?>-bairro">Bairro do imóvel</label>
				<input type="text" id="<?php echo esc_attr( $id ); ?>-bairro" name="bairro" inputmode="text">
			</p>
		<?php endif; ?>

		<?php if ( in_array( 'motivo', $campos, true ) ) : ?>
			<p class="fl-campo">
				<label for="<?php echo esc_attr( $id ); ?>-motivo">Motivo da venda</label>
				<select id="<?php echo esc_attr( $id ); ?>-motivo" name="motivo">
					<option value="">Selecione</option>
					<?php foreach ( array( 'Mudança de cidade', 'Troca por imóvel maior', 'Troca por imóvel menor', 'Investimento', 'Inventário / partilha', 'Outro' ) as $opcao ) : ?>
						<option value="<?php echo esc_attr( $opcao ); ?>"><?php echo esc_html( $opcao ); ?></option>
					<?php endforeach; ?>
				</select>
			</p>
		<?php endif; ?>

		<?php if ( in_array( 'prazo', $campos, true ) ) : ?>
			<p class="fl-campo">
				<label for="<?php echo esc_attr( $id ); ?>-prazo">Em quanto tempo pretende vender?</label>
				<select id="<?php echo esc_attr( $id ); ?>-prazo" name="prazo">
					<option value="">Selecione</option>
					<?php foreach ( array( 'O quanto antes', 'Até 3 meses', 'Até 6 meses', 'Sem pressa, quero avaliar' ) as $opcao ) : ?>
						<option value="<?php echo esc_attr( $opcao ); ?>"><?php echo esc_html( $opcao ); ?></option>
					<?php endforeach; ?>
				</select>
			</p>
		<?php endif; ?>

		<?php if ( in_array( 'mensagem', $campos, true ) ) : ?>
			<p class="fl-campo fl-campo--largo">
				<label for="<?php echo esc_attr( $id ); ?>-msg">Mensagem</label>
				<textarea id="<?php echo esc_attr( $id ); ?>-msg" name="mensagem" rows="4" enterkeyhint="send"></textarea>
			</p>
		<?php endif; ?>

		<p class="fl-campo fl-campo--largo fl-campo--acao">
			<button type="submit" class="fl-btn fl-btn--ouro"><?php echo esc_html( $botao ); ?></button>
			<span class="fl-form__nota">Seus dados ficam comigo. Sem disparo de lista, sem repasse a terceiros.</span>
		</p>
	</form>
</section>
