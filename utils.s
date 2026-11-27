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

.include "constants.s"                  /* traz as constantes do projeto */

.global to_bcd                          /* exporta to_bcd */

.equ BCD_MAX, 99999999                  /* maior valor que cabe em 8 digitos */

/* Potencias de 10, da maior para a menor: uma por digito de saida. */
.data                                   /* passa a montar na secao de dados */
.align 2                                /* alinha em 4 bytes (words) */
POTENCIAS_10:                           /* tabela de 8 potencias de 10 */
    .word 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1

.text                                   /* volta a montar na secao de codigo */

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
    /* Inicializa o resultado e a parte a converter */
    mov   r2, r0                    /* r2 = resultado, comeca zerado */
    mov   r8, r4                    /* r8 = parte do valor ainda nao convertida */

    /* Satura valores que nao cabem em 8 digitos */
    movia r13, BCD_MAX              /* r13 = 99.999.999 */
    bleu  r8, r13, .Lbcd_inicio     /* se valor <= maximo, segue normal */
    mov   r8, r13                   /* senao, usa o maximo no lugar do valor */

.Lbcd_inicio:
    /* Prepara o percurso pela tabela de potencias */
    movia r9, POTENCIAS_10          /* r9 = endereco da primeira potencia */
    movi  r10, 8                    /* r10 = digitos que faltam (8) */

.Lbcd_potencia:
    /* Comeca um digito novo */
    ldw   r11, 0(r9)                /* r11 = potencia de 10 deste digito */
    mov   r12, r0                   /* r12 = digito, comeca em 0 */

.Lbcd_subtrai:
    /* Conta quantas vezes a potencia cabe no valor */
    bltu  r8, r11, .Lbcd_guarda     /* se valor < potencia, digito pronto */
    sub   r8, r8, r11               /* tira uma potencia do valor */
    addi  r12, r12, 1               /* soma 1 ao digito */
    br    .Lbcd_subtrai             /* tenta tirar de novo */

.Lbcd_guarda:
    /* Guarda o digito e passa para a proxima potencia */
    slli  r2, r2, 4                 /* abre um nibble vazio a direita */
    or    r2, r2, r12               /* coloca o digito nesse nibble */
    addi  r9, r9, 4                 /* r9 = endereco da proxima potencia */
    subi  r10, r10, 1               /* um digito a menos */
    bne   r10, r0, .Lbcd_potencia   /* repete ate fazer os 8 */
    ret                             /* retorna com o BCD em r2 */
