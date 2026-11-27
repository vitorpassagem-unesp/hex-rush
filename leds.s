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

.include "constants.s"                  /* traz os enderecos dos LEDs */

/* Rotinas visiveis para os outros arquivos */
.global set_ledr_unary                  /* exporta set_ledr_unary */
.global set_ledg_lives                  /* exporta set_ledg_lives */
.global clear_leds                      /* exporta clear_leds */

.text                                   /* monta na secao de codigo */

/* ----------------------------------------------------------------------------
 * set_ledr_unary
 * Mostra n em unario: n LEDs acesos a partir do LEDR0 (regra 5 do
 * enunciado). (1 << n) - 1 gera exatamente n bits 1 sem laco; para n = 0
 * da 0, ou seja, todos apagados.
 * ---------------------------------------------------------------------------- */
set_ledr_unary:
    /* Calcula (1 << n) - 1 */
    andi  r8, r4, 0x1F              /* r8 = n, so 5 bits (o sll so usa 5) */
    movi  r9, 1                     /* r9 = 1 */
    sll   r9, r9, r8                /* r9 = 1 << n */
    subi  r9, r9, 1                 /* r9 = (1 << n) - 1 = n bits 1 */

    /* Escreve nos LEDs vermelhos */
    movia r8, LEDR_BASE             /* r8 = endereco dos LEDR */
    stwio r9, 0(r8)                 /* acende os n primeiros LEDR */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * set_ledg_lives
 * Mesma ideia para as vidas nos LEDs verdes (3 vidas -> 00000111).
 * ---------------------------------------------------------------------------- */
set_ledg_lives:
    /* Calcula (1 << vidas) - 1 */
    andi  r8, r4, 0x1F              /* r8 = vidas, so 5 bits */
    movi  r9, 1                     /* r9 = 1 */
    sll   r9, r9, r8                /* r9 = 1 << vidas */
    subi  r9, r9, 1                 /* r9 = (1 << vidas) - 1 */

    /* Escreve nos LEDs verdes */
    movia r8, LEDG_BASE             /* r8 = endereco dos LEDG */
    stwio r9, 0(r8)                 /* acende um LEDG por vida */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * clear_leds
 * Estados AGUARDANDO e FIM_JOGO: nenhum LED aceso.
 * ---------------------------------------------------------------------------- */
clear_leds:
    movia r8, LEDR_BASE             /* r8 = endereco dos LEDR */
    stwio r0, 0(r8)                 /* apaga todos os LEDR */
    movia r8, LEDG_BASE             /* r8 = endereco dos LEDG */
    stwio r0, 0(r8)                 /* apaga todos os LEDG */
    ret                             /* retorna */
