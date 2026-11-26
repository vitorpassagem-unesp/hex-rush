/* ============================================================================
 * leds.s - LEDs vermelhos (proximo alvo) e verdes (vidas)
 *
 * Rotinas (convencao Nios II):
 *   set_ledr_unary   r4 = n (0..15) -> acende LEDR[n-1:0]
 *   set_ledg_lives   r4 = vidas     -> acende LEDG[vidas-1:0]
 *   clear_leds       apaga LEDR e LEDG
 *
 * Usam so r8-r9 e nao chamam ninguem: nao precisam de pilha.
 * ============================================================================ */

.include "constants.s"

.global set_ledr_unary
.global set_ledg_lives
.global clear_leds

.text

/* ----------------------------------------------------------------------------
 * set_ledr_unary
 * Mostra n em unario: n LEDs acesos a partir do LEDR0 (regra 5 do
 * enunciado). (1 << n) - 1 gera exatamente n bits 1 sem laco; para n = 0
 * da 0, ou seja, todos apagados.
 * ---------------------------------------------------------------------------- */
set_ledr_unary:
    andi  r8, r4, 0x1F              /* sll so usa 5 bits; evita surpresa */
    movi  r9, 1
    sll   r9, r9, r8
    subi  r9, r9, 1
    movia r8, LEDR_BASE
    stwio r9, 0(r8)
    ret

/* ----------------------------------------------------------------------------
 * set_ledg_lives
 * Mesma ideia para as vidas nos LEDs verdes (3 vidas -> 00000111).
 * ---------------------------------------------------------------------------- */
set_ledg_lives:
    andi  r8, r4, 0x1F
    movi  r9, 1
    sll   r9, r9, r8
    subi  r9, r9, 1
    movia r8, LEDG_BASE
    stwio r9, 0(r8)
    ret

/* ----------------------------------------------------------------------------
 * clear_leds
 * Estados AGUARDANDO e FIM_JOGO: nenhum LED aceso.
 * ---------------------------------------------------------------------------- */
clear_leds:
    movia r8, LEDR_BASE
    stwio r0, 0(r8)
    movia r8, LEDG_BASE
    stwio r0, 0(r8)
    ret
