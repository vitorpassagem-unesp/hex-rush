/* ============================================================================
 * targets.s - Lista fixa de alvos do jogo
 *
 * Rotina (convencao Nios II):
 *   get_target   r4 = indice -> r2 = lista[indice mod 100]
 *
 * A lista e constante (decisao do grupo: 100 valores escolhidos pelo grupo,
 * no lugar de um gerador aleatorio). E circular: depois do 100o alvo volta
 * ao primeiro. Toda partida comeca no indice 0.
 *
 * Usa so r8-r9 e nao chama ninguem: nao precisa de pilha.
 * ============================================================================ */

.include "constants.s"                  /* traz NUM_ALVOS */

.global get_target                      /* exporta get_target */

/* Lista de alvos: um byte por alvo, mesma ideia da TABELA_HEX do lab 5. */
.data                                   /* passa a montar na secao de dados */
LISTA_ALVOS:                            /* inicio da lista: indice = rodada - 1 */
    .byte 0xE, 0xF, 0x0, 0x5, 0x4, 0x0, 0x3, 0xB, 0x2, 0x5   /* alvos  0- 9 */
    .byte 0x3, 0x4, 0xC, 0x8, 0x7, 0x5, 0xF, 0x8, 0x6, 0x7   /* alvos 10-19 */
    .byte 0xF, 0xE, 0xC, 0x0, 0x1, 0xD, 0x5, 0x9, 0x3, 0x0   /* alvos 20-29 */
    .byte 0xA, 0xE, 0xC, 0x0, 0x8, 0x3, 0xD, 0x3, 0x1, 0x1   /* alvos 30-39 */
    .byte 0x2, 0x0, 0x4, 0x3, 0x1, 0xA, 0xC, 0x0, 0xD, 0x2   /* alvos 40-49 */
    .byte 0xB, 0x8, 0x6, 0x3, 0xE, 0x1, 0x0, 0x2, 0xB, 0xF   /* alvos 50-59 */
    .byte 0x7, 0x0, 0x9, 0x9, 0x1, 0x9, 0x8, 0x9, 0x9, 0x8   /* alvos 60-69 */
    .byte 0x2, 0xE, 0xB, 0x8, 0x3, 0x4, 0x3, 0xB, 0x3, 0xD   /* alvos 70-79 */
    .byte 0x4, 0xC, 0xB, 0xE, 0x6, 0x8, 0xF, 0xD, 0x9, 0x9   /* alvos 80-89 */
    .byte 0xA, 0x9, 0x3, 0x7, 0xB, 0x9, 0xD, 0xA, 0x1, 0x8   /* alvos 90-99 */

.text                                   /* volta a montar na secao de codigo */

/* ----------------------------------------------------------------------------
 * get_target
 * Devolve o alvo de um indice. O indice pode passar de 99 (ex.: proximo
 * alvo do indice 99, ou a "Sequencia" de uma partida longa), entao primeiro
 * reduz mod 100. Sem div na placa, o mod e feito subtraindo 100.
 * ---------------------------------------------------------------------------- */
get_target:
    /* Reduz o indice para 0..99 */
    mov   r8, r4                    /* r8 = indice pedido */
    movi  r9, NUM_ALVOS             /* r9 = 100 */
.Lmod_alvos:
    bltu  r8, r9, .Lle_alvo         /* se indice < 100, ja esta reduzido */
    sub   r8, r8, r9                /* indice = indice - 100 */
    br    .Lmod_alvos               /* testa de novo */

.Lle_alvo:
    /* Le o byte da lista */
    movia r9, LISTA_ALVOS           /* r9 = endereco da lista */
    add   r9, r9, r8                /* r9 = endereco do alvo do indice */
    ldbu  r2, 0(r9)                 /* r2 = alvo (0..15) */
    ret                             /* retorna com o alvo em r2 */
