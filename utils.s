/* ============================================================================
 * utils.s - Rotinas usadas por mais de um modulo
 *
 *   to_bcd   r4 = valor (0..99.999.999) -> r2 = valor em BCD compactado
 *
 * Usada pela tela "GO  dddd" (display.s) e pelos numeros da UART (uart.s),
 * para que a conversao para decimal exista em um lugar so.
 * ============================================================================ */

.include "constants.s"

.global to_bcd

.text

/* ----------------------------------------------------------------------------
 * to_bcd
 * Converte r4 para BCD compactado: cada nibble de r2 guarda um digito
 * decimal, o das unidades no nibble 0. Ex.: 507 -> 0x00000507.
 *
 * Assim quem usa so precisa deslocar e mascarar nibbles: a tela GO pega os
 * 4 de baixo (com zeros) e a UART pula os zeros da esquerda.
 *
 * Divide por 10 repetidamente. O resto e calculado como n - q*10 com
 * deslocamentos (q*8 + q*2) para nao depender tambem do multiplicador.
 * Para em 8 digitos (32 bits / 4): acima disso o nibble nao caberia em r2.
 * ---------------------------------------------------------------------------- */
to_bcd:
    mov   r2, r0                    /* resultado */
    mov   r8, r4                    /* parte ainda nao convertida */
    mov   r9, r0                    /* deslocamento do nibble: 0, 4, 8, ... */
    movi  r10, 10
    movi  r14, 32                   /* limite: 8 nibbles */

.Lbcd_digito:
    divu  r11, r8, r10              /* q = n / 10 */
    slli  r12, r11, 3               /* q*8 */
    slli  r13, r11, 1               /* q*2 */
    add   r12, r12, r13             /* q*10 */
    sub   r12, r8, r12              /* resto = digito das unidades */

    sll   r12, r12, r9
    or    r2, r2, r12

    mov   r8, r11                   /* continua com o quociente */
    addi  r9, r9, 4
    beq   r9, r14, .Lbcd_fim        /* 8 digitos: acabou o espaco */
    bne   r8, r0, .Lbcd_digito      /* zero sempre gera pelo menos um digito */

.Lbcd_fim:
    ret
