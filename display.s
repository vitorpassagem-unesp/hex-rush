/* ============================================================================
 * display.s - Modulo dos displays de 7 segmentos (HEX7..HEX0)
 *
 * Criado a partir do teste visual do Gustavo Gomes (set_hex_digit). O teste
 * isolado esta em tests/test_display.s.
 *
 * Rotinas (convencao Nios II: argumentos em r4-r7, retorno em r2):
 *   set_hex_raw     r4 = display 0..7, r5 = padrao de 7 segmentos
 *   set_hex_digit   r4 = display 0..7, r5 = digito 0..15 ou HEX_APAGA
 *   clear_hex       apaga HEX7..HEX0
 *   show_play       HEX7..HEX4 apagados, HEX3..HEX0 = "PLAY"
 *   show_game_over  r4 = pontos -> "GO  dddd" (4 digitos, zeros a esquerda)
 *
 * Nenhuma rotina usa r16-r23, entao nao precisam salva-los. Todas podem
 * alterar r8-r15 (caller-saved).
 * ============================================================================ */

.include "constants.s"                  /* traz enderecos e codigos de letras */

/* Padroes montados de uma vez para escrever 4 displays com um so stwio. */
.equ PADRAO_PLAY, (SEG_P << 24) | (SEG_L << 16) | (SEG_A << 8) | SEG_Y   /* P L A Y em HEX3..HEX0 */
.equ PADRAO_GO,   (SEG_G << 24) | (SEG_O << 16)                          /* G O _ _ em HEX7..HEX4 */

/* Rotinas visiveis para os outros arquivos */
.global set_hex_raw                     /* exporta set_hex_raw */
.global set_hex_digit                   /* exporta set_hex_digit */
.global clear_hex                       /* exporta clear_hex */
.global show_play                       /* exporta show_play */
.global show_game_over                  /* exporta show_game_over */

/* Tabela 7 segmentos (0..F) conforme Tabela 2 do enunciado.
 * Fica em .data (e nao em .rodata) porque e a secao que o Monitor Program
 * sempre posiciona na memoria em projetos so de assembly. */
.data                                   /* passa a montar na secao de dados */
HEX7SEG_TABLE:                          /* inicio da tabela: indice = digito */
    .byte 0x3F  /* 0: abcdef  */
    .byte 0x06  /* 1: bc      */
    .byte 0x5B  /* 2: abdeg   */
    .byte 0x4F  /* 3: abcdg   */
    .byte 0x66  /* 4: bcfg    */
    .byte 0x6D  /* 5: acdfg   */
    .byte 0x7D  /* 6: acdefg  */
    .byte 0x07  /* 7: abc     */
    .byte 0x7F  /* 8: abcdefg */
    .byte 0x6F  /* 9: abcdfg  */
    .byte 0x77  /* A: abcefg  */
    .byte 0x7C  /* b: cdefg   (minusculo para nao confundir com 8) */
    .byte 0x39  /* C: adef    */
    .byte 0x5E  /* d: bcdeg   (minusculo para nao confundir com 0) */
    .byte 0x79  /* E: adefg   */
    .byte 0x71  /* F: aefg    */

.text                                   /* volta a montar na secao de codigo */

/* ----------------------------------------------------------------------------
 * set_hex_raw
 * Escreve um padrao de 7 segmentos qualquer no display r4 (0..7).
 * Usada direto para as letras (G, O, P, L, Y) que nao estao na tabela.
 *
 * Os 4 displays de cada grupo dividem um mesmo registrador de 32 bits, entao
 * e preciso ler, trocar so o byte do display e escrever de volta; senao um
 * display apagaria os outros tres.
 * ---------------------------------------------------------------------------- */
set_hex_raw:
    /* Limpa os argumentos para nao escrever fora do lugar */
    andi  r8, r4, 0x07              /* r8 = indice do display, so 3 bits (0..7) */
    andi  r9, r5, 0xFF              /* r9 = padrao, so o byte de baixo */

    /* Escolhe o registrador do grupo (HEX3..0 ou HEX7..4) e a posicao nele */
    movia r10, HEX3_HEX0_BASE       /* r10 = endereco do grupo HEX3..HEX0 */
    movi  r11, 4                    /* r11 = 4, primeiro display do outro grupo */
    blt   r8, r11, .Lraw_escreve    /* se indice < 4, ja e o grupo certo: pula */
    subi  r8, r8, 4                 /* indice 4..7 vira posicao 0..3 no grupo */
    movia r10, HEX7_HEX4_BASE       /* r10 = endereco do grupo HEX7..HEX4 */

.Lraw_escreve:
    /* Monta a mascara e o padrao deslocados para o byte do display */
    slli  r8, r8, 3                 /* r8 = posicao * 8 = deslocamento em bits */
    movi  r11, 0xFF                 /* r11 = 0xFF (um byte cheio) */
    sll   r11, r11, r8              /* r11 = 0xFF na posicao do display */
    nor   r11, r11, r11             /* r11 = inverte: zeros so no byte do display */
    sll   r9, r9, r8                /* r9 = padrao na posicao do display */

    /* Le os 4 displays, troca so o byte deste e escreve de volta */
    ldwio r12, 0(r10)               /* r12 = conteudo atual dos 4 displays */
    and   r12, r12, r11             /* zera o byte do display escolhido */
    or    r12, r12, r9              /* coloca o padrao novo nesse byte */
    stwio r12, 0(r10)               /* escreve os 4 displays de volta */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * set_hex_digit
 * Escreve um digito hexadecimal (0..15) no display r4 (0..7).
 * r5 == HEX_APAGA apaga o display, para quem chama nao precisar saber o
 * padrao de 7 segmentos.
 * ---------------------------------------------------------------------------- */
set_hex_digit:
    /* Prologo: vai chamar set_hex_raw, entao guarda o ra */
    subi  sp, sp, 4                 /* reserva 1 word na pilha */
    stw   ra, 0(sp)                 /* salva o endereco de retorno */

    /* Caso especial: pedido para apagar */
    movi  r8, HEX_APAGA             /* r8 = codigo de "apagar" (0xFF) */
    beq   r5, r8, .Ldig_apaga       /* se r5 == 0xFF, vai apagar */

    /* Converte o digito no padrao pela tabela */
    andi  r8, r5, 0x0F              /* r8 = digito, so 4 bits (0..15) */
    movia r9, HEX7SEG_TABLE         /* r9 = endereco da tabela */
    add   r9, r9, r8                /* r9 = endereco da entrada do digito */
    ldbu  r5, 0(r9)                 /* r5 = padrao do digito (byte sem sinal) */
    br    .Ldig_escreve             /* pula o caso de apagar */

.Ldig_apaga:
    movi  r5, SEG_APAGADO           /* r5 = padrao com todos os segmentos apagados */

.Ldig_escreve:
    /* Escreve o padrao no display (r4 ainda e o indice) */
    call  set_hex_raw               /* escreve r5 no display r4 */

    /* Epilogo: restaura o ra e devolve a pilha */
    ldw   ra, 0(sp)                 /* recupera o endereco de retorno */
    addi  sp, sp, 4                 /* libera o word da pilha */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * clear_hex
 * Apaga os 8 displays. Escreve os dois words inteiros: mais simples e mais
 * rapido que apagar display por display.
 * ---------------------------------------------------------------------------- */
clear_hex:
    movia r8, HEX3_HEX0_BASE        /* r8 = endereco de HEX3..HEX0 */
    stwio r0, 0(r8)                 /* apaga HEX3..HEX0 */
    movia r8, HEX7_HEX4_BASE        /* r8 = endereco de HEX7..HEX4 */
    stwio r0, 0(r8)                 /* apaga HEX7..HEX4 */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * show_play
 * Tela do estado AGUARDANDO: HEX7..HEX4 apagados e "PLAY" em HEX3..HEX0.
 * ---------------------------------------------------------------------------- */
show_play:
    /* Metade da esquerda apagada */
    movia r8, HEX7_HEX4_BASE        /* r8 = endereco de HEX7..HEX4 */
    stwio r0, 0(r8)                 /* apaga HEX7..HEX4 */

    /* "PLAY" na metade da direita */
    movia r8, HEX3_HEX0_BASE        /* r8 = endereco de HEX3..HEX0 */
    movia r9, PADRAO_PLAY           /* r9 = padroes de P, L, A, Y juntos */
    stwio r9, 0(r8)                 /* escreve PLAY em HEX3..HEX0 */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * show_game_over
 * Tela do estado FIM_JOGO: "GO  dddd" com os pontos (r4) em decimal.
 * Mostra sempre 4 digitos, com zeros a esquerda (decisao do grupo); acima de
 * 9999 aparecem so os 4 digitos de baixo.
 * ---------------------------------------------------------------------------- */
show_game_over:
    /* Prologo: vai chamar to_bcd, entao guarda o ra */
    subi  sp, sp, 4                 /* reserva 1 word na pilha */
    stw   ra, 0(sp)                 /* salva o endereco de retorno */

    /* Converte os pontos para decimal (1 digito por nibble) */
    call  to_bcd                    /* r2 = pontos (r4) em BCD */

    /* "GO" na metade da esquerda */
    movia r8, HEX7_HEX4_BASE        /* r8 = endereco de HEX7..HEX4 */
    movia r9, PADRAO_GO             /* r9 = padroes de G, O e dois apagados */
    stwio r9, 0(r8)                 /* escreve "GO  " em HEX7..HEX4 */

    /* Prepara a montagem dos 4 digitos (mesma ideia do LOOP_HEX do lab 5) */
    movia r10, HEX7SEG_TABLE        /* r10 = endereco da tabela */
    mov   r11, r0                   /* r11 = word montado, comeca zerado */
    mov   r12, r0                   /* r12 = deslocamento do display atual (0) */
    movi  r13, 4                    /* r13 = quantos digitos faltam (4) */

.Lgo_digito:
    /* Converte o digito de baixo e encaixa no byte do display atual */
    andi  r9, r2, 0x0F              /* r9 = digito decimal das unidades atuais */
    add   r9, r10, r9               /* r9 = endereco da entrada do digito */
    ldbu  r9, 0(r9)                 /* r9 = padrao de 7 segmentos do digito */
    sll   r9, r9, r12               /* r9 = padrao na posicao do display */
    or    r11, r11, r9              /* junta o padrao ao word montado */

    /* Avanca para o proximo digito e o proximo display */
    srli  r2, r2, 4                 /* traz o proximo digito para o nibble 0 */
    addi  r12, r12, 8               /* proximo display: 8 bits a esquerda */
    subi  r13, r13, 1               /* um digito a menos */
    bne   r13, r0, .Lgo_digito      /* repete ate fazer os 4 */

    /* Escreve os 4 digitos de uma vez */
    movia r8, HEX3_HEX0_BASE        /* r8 = endereco de HEX3..HEX0 */
    stwio r11, 0(r8)                /* escreve os 4 digitos */

    /* Epilogo */
    ldw   ra, 0(sp)                 /* recupera o endereco de retorno */
    addi  sp, sp, 4                 /* libera o word da pilha */
    ret                             /* retorna */
