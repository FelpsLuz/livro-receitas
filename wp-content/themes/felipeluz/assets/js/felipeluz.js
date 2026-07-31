/**
 * Galeria (scroll-snap nativo), lightbox e mapa sob demanda.
 *
 * A galeria funciona sem este arquivo: o swipe é CSS puro. O script só
 * acrescenta contador, zoom e teclado. Se ele falhar, ninguém perde nada
 * essencial — e o mapa é o segundo maior vilão de performance depois da
 * imagem, então ele só existe depois do clique.
 */
( function () {
	'use strict';

	/* ---------------------------------------------------------------
	 * Mapa: carrega o iframe só quando o visitante pede
	 * ------------------------------------------------------------- */

	document.querySelectorAll( '[data-fl-mapa]' ).forEach( function ( caixa ) {
		var botao = caixa.querySelector( '[data-fl-mapa-abrir]' );
		if ( ! botao ) {
			return;
		}

		botao.addEventListener( 'click', function () {
			var consulta = caixa.getAttribute( 'data-fl-consulta' ) || '';
			var iframe   = document.createElement( 'iframe' );

			iframe.src = 'https://www.google.com/maps?q=' + encodeURIComponent( consulta ) + '&output=embed';
			iframe.loading = 'lazy';
			iframe.title = 'Mapa da região do imóvel';
			iframe.referrerPolicy = 'no-referrer-when-downgrade';
			iframe.setAttribute( 'allowfullscreen', '' );

			caixa.innerHTML = '';
			caixa.appendChild( iframe );
		} );
	} );

	/* ---------------------------------------------------------------
	 * Galeria
	 * ------------------------------------------------------------- */

	var trilho = document.querySelector( '[data-fl-trilho]' );
	if ( ! trilho ) {
		return;
	}

	var slides   = Array.prototype.slice.call( trilho.querySelectorAll( '[data-fl-slide]' ) );
	var contador = document.querySelector( '[data-fl-contador-trilho]' );
	var lightbox = document.querySelector( '[data-fl-lightbox]' );
	var atual    = 0;
	var fotos    = [];

	if ( lightbox ) {
		try {
			fotos = JSON.parse( lightbox.querySelector( '[data-fl-fotos]' ).textContent );
		} catch ( e ) {
			fotos = [];
		}
	}

	/* Contador acompanha o swipe. IntersectionObserver evita ouvir scroll. */
	if ( contador && slides.length > 1 && 'IntersectionObserver' in window ) {
		var observador = new IntersectionObserver( function ( entradas ) {
			entradas.forEach( function ( entrada ) {
				if ( entrada.isIntersecting ) {
					atual = parseInt( entrada.target.getAttribute( 'data-fl-slide' ), 10 ) || 0;
					contador.textContent = ( atual + 1 ) + ' / ' + slides.length;
				}
			} );
		}, { root: trilho, threshold: 0.6 } );

		slides.forEach( function ( slide ) {
			observador.observe( slide );
		} );
	}

	if ( ! lightbox || ! fotos.length ) {
		return;
	}

	var imagem       = lightbox.querySelector( '[data-fl-img]' );
	var contadorLb   = lightbox.querySelector( '[data-fl-contador]' );
	var focoAnterior = null;

	function mostrar( indice ) {
		atual = ( indice + fotos.length ) % fotos.length;
		imagem.src = fotos[ atual ].src;
		imagem.alt = fotos[ atual ].alt || '';
		contadorLb.textContent = ( atual + 1 ) + ' de ' + fotos.length;
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

		// Devolve o trilho à foto que estava aberta no lightbox.
		if ( slides[ atual ] ) {
			slides[ atual ].scrollIntoView( { behavior: 'auto', block: 'nearest', inline: 'center' } );
		}
		if ( focoAnterior ) {
			focoAnterior.focus();
		}
	}

	var botaoAbrir = document.querySelector( '[data-fl-abrir]' );
	if ( botaoAbrir ) {
		botaoAbrir.addEventListener( 'click', abrir );
	}

	slides.forEach( function ( slide ) {
		slide.addEventListener( 'click', abrir );
	} );

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
