/**
 * Galeria + lightbox. Sem biblioteca — são 40 linhas.
 */
( function () {
	'use strict';

	var galeria = document.querySelector( '[data-fl-galeria]' );
	if ( ! galeria ) {
		return;
	}

	var principal   = document.getElementById( 'fl-galeria-principal' );
	var miniaturas  = Array.prototype.slice.call( galeria.querySelectorAll( '[data-fl-mini]' ) );
	var lightbox    = document.querySelector( '[data-fl-lightbox]' );
	var atual       = 0;
	var fotos       = [];

	if ( lightbox ) {
		var dados = lightbox.querySelector( '[data-fl-fotos]' );
		try {
			fotos = JSON.parse( dados.textContent );
		} catch ( e ) {
			fotos = [];
		}
	}

	// Troca a foto principal ao clicar na miniatura.
	miniaturas.forEach( function ( botao ) {
		botao.addEventListener( 'click', function () {
			var url = botao.getAttribute( 'data-fl-mini' );
			if ( principal && url ) {
				principal.src = url;
				principal.removeAttribute( 'srcset' );
			}
			miniaturas.forEach( function ( b ) {
				b.classList.remove( 'esta-ativa' );
			} );
			botao.classList.add( 'esta-ativa' );
			atual = parseInt( botao.getAttribute( 'data-fl-indice' ), 10 ) || 0;
		} );
	} );

	if ( ! lightbox || ! fotos.length ) {
		return;
	}

	var imagem    = lightbox.querySelector( '[data-fl-img]' );
	var contador  = lightbox.querySelector( '[data-fl-contador]' );
	var focoAnterior = null;

	function mostrar( indice ) {
		atual = ( indice + fotos.length ) % fotos.length;
		imagem.src = fotos[ atual ];
		contador.textContent = ( atual + 1 ) + ' de ' + fotos.length;
	}

	function abrir() {
		focoAnterior = document.activeElement;
		lightbox.hidden = false;
		document.body.style.overflow = 'hidden';
		mostrar( atual );
		lightbox.querySelector( '[data-fl-fechar]' ).focus();
	}

	function fechar() {
		lightbox.hidden = true;
		document.body.style.overflow = '';
		if ( focoAnterior ) {
			focoAnterior.focus();
		}
	}

	var abrirBotao = galeria.querySelector( '[data-fl-abrir]' );
	if ( abrirBotao ) {
		abrirBotao.addEventListener( 'click', abrir );
	}
	if ( principal ) {
		principal.style.cursor = 'zoom-in';
		principal.addEventListener( 'click', abrir );
	}

	lightbox.querySelector( '[data-fl-fechar]' ).addEventListener( 'click', fechar );
	lightbox.querySelector( '[data-fl-ant]' ).addEventListener( 'click', function () { mostrar( atual - 1 ); } );
	lightbox.querySelector( '[data-fl-prox]' ).addEventListener( 'click', function () { mostrar( atual + 1 ); } );

	lightbox.addEventListener( 'click', function ( evento ) {
		if ( evento.target === lightbox ) {
			fechar();
		}
	} );

	document.addEventListener( 'keydown', function ( evento ) {
		if ( lightbox.hidden ) {
			return;
		}
		if ( 'Escape' === evento.key ) { fechar(); }
		if ( 'ArrowLeft' === evento.key ) { mostrar( atual - 1 ); }
		if ( 'ArrowRight' === evento.key ) { mostrar( atual + 1 ); }
	} );
}() );
