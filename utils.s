/* ============================================================================
 * utils.s - Rotinas usadas por mais de um modulo
 *
 *   to_bcd   r4 = valor -> r2 = valor em BCD compactado (8 digitos)
 *
 * Usada pela tela "GO  dddd" (display.s) e pelos numeros da UART (uart.s),
 * para que a conversao para decimal exista em um lugar so.
 *
 * O processador da placa NAO tem div nem mul: nada aqui usa essas
 * instrucoes (o divu da primeira versao gerava excecao).
 * ============================================================================ */

.include "constants.s"

.global to_bcd

.equ BCD_MAX, 99999999              /* maior valor que cabe em 8 digitos */

/* Potencias de 10, da maior para a menor: uma por digito de saida. */
.data
.align 2
POTENCIAS_10:
    .word 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1

.text

/* ----------------------------------------------------------------------------
 * to_bcd
 * Converte r4 para BCD compactado: cada nibble de r2 guarda um digito
 * decimal, o das unidades no nibble 0. Ex.: 507 -> 0x00000507.
 *
 * Quem usa so precisa deslocar e mascarar nibbles: a tela GO pega os 4 de
 * baixo (com zeros) e a UART pula os zeros da esquerda.
 *
 * Sem divisao em hardware, cada digito sai contando quantas vezes a
 * potencia de 10 cabe no valor (no maximo 9 subtracoes por digito, 72 no
 * total). Valores acima de 99.999.999 sao limitados a esse maximo, porque
 * o digito mais alto passaria de 9 e invadiria o nibble vizinho.
 * ---------------------------------------------------------------------------- */
to_bcd:
    mov   r2, r0                    /* resultado */
    mov   r8, r4                    /* parte ainda nao convertida */

    movia r13, BCD_MAX
    bleu  r8, r13, .Lbcd_inicio
    mov   r8, r13                   /* satura em vez de gerar BCD invalido */

.Lbcd_inicio:
    movia r9, POTENCIAS_10          /* ponteiro para a potencia atual */
    movi  r10, 8                    /* 8 digitos */

.Lbcd_potencia:
    ldw   r11, 0(r9)                /* potencia de 10 deste digito */
    mov   r12, r0                   /* digito = 0 */

.Lbcd_subtrai:
    bltu  r8, r11, .Lbcd_guarda     /* nao cabe mais: digito pronto */
    sub   r8, r8, r11
    addi  r12, r12, 1
    br    .Lbcd_subtrai

.Lbcd_guarda:
    slli  r2, r2, 4                 /* abre espaco para o novo digito */
    or    r2, r2, r12
    addi  r9, r9, 4                 /* proxima potencia (menor) */
    subi  r10, r10, 1
    bne   r10, r0, .Lbcd_potencia
    ret
