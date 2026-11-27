/* ============================================================================
 * uart.s - Mensagens no terminal (JTAG UART), so saida
 *
 * Rotinas (convencao Nios II):
 *   uart_putc           r4 = caractere
 *   uart_puts           r4 = endereco de string terminada em 0
 *   uart_put_dec        r4 = valor -> decimal, sem zeros a esquerda
 *   uart_put_hex_digit  r4 = 0..15 -> '0'..'9', 'A'..'F' (maiusculas)
 *   uart_print_wait     "Pressione KEY1 para iniciar"
 *   uart_print_round    r4 = rodada, r5 = alvo, r6 = resposta,
 *                       r7 = pontos (se acerto) ou vidas (se erro)
 *   uart_print_end      r4 = pontos, r5 = numero de rodadas jogadas
 *
 * Formato (igual ao exemplo do enunciado, decisoes do grupo):
 *   Rodada 5 | Alvo: C | Resposta: C | ACERTO | Pontos: 50
 *   Rodada 6 | Alvo: 7 | Resposta: 3 | ERRO   | Vidas: 2
 *   === FIM DE JOGO === Pontuacao final: 80 | Sequencia: 4A9BC73
 *
 * Escrita por polling do WSPACE, igual ao part1.s do lab 6. A FIFO tem 64
 * posicoes, entao uma linha (~55 caracteres) quase nunca espera.
 * Rotinas que chamam outras salvam ra e os r16+ que usam (convencao).
 * ============================================================================ */

.include "constants.s"                  /* traz o endereco da UART */

/* Rotinas visiveis para os outros arquivos */
.global uart_putc                       /* exporta uart_putc */
.global uart_puts                       /* exporta uart_puts */
.global uart_put_dec                    /* exporta uart_put_dec */
.global uart_put_hex_digit              /* exporta uart_put_hex_digit */
.global uart_print_wait                 /* exporta uart_print_wait */
.global uart_print_round                /* exporta uart_print_round */
.global uart_print_end                  /* exporta uart_print_end */

/* Textos fixos das mensagens */
.data                                   /* passa a montar na secao de dados */
DIGITOS_HEX:    .ascii "0123456789ABCDEF"            /* caractere de cada valor 0..15 */
MSG_ESPERA:     .asciz "Pressione KEY1 para iniciar\n"
MSG_RODADA:     .asciz "Rodada "
MSG_ALVO:       .asciz " | Alvo: "
MSG_RESPOSTA:   .asciz " | Resposta: "
MSG_ACERTO:     .asciz " | ACERTO | Pontos: "
MSG_ERRO:       .asciz " | ERRO   | Vidas: "
MSG_FIM:        .asciz "=== FIM DE JOGO === Pontuacao final: "
MSG_SEQUENCIA:  .asciz " | Sequencia: "
MSG_NOVA_LINHA: .asciz "\n"

.text                                   /* volta a montar na secao de codigo */

/* ----------------------------------------------------------------------------
 * uart_putc
 * Espera haver espaco na FIFO de escrita e envia um caractere (r4).
 * ---------------------------------------------------------------------------- */
uart_putc:
    movia r8, JTAG_UART_BASE        /* r8 = endereco da UART */
.Lputc_espera:
    /* Espera WSPACE > 0 (igual ao POLL_WRITE do lab 6) */
    ldwio r9, UART_CTRL_REG(r8)     /* r9 = registrador de controle */
    andhi r9, r9, 0xFFFF            /* r9 = so WSPACE (16 bits de cima) */
    beq   r9, r0, .Lputc_espera     /* se FIFO cheia, espera */

    /* Envia o caractere */
    stwio r4, UART_DATA_REG(r8)     /* escreve o caractere na FIFO */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * uart_puts
 * Envia uma string terminada em 0 (r4 = endereco).
 * ---------------------------------------------------------------------------- */
uart_puts:
    /* Prologo: chama uart_putc, guarda ra e o ponteiro em r16 */
    subi  sp, sp, 8                 /* reserva 2 words na pilha */
    stw   ra, 0(sp)                 /* salva ra */
    stw   r16, 4(sp)                /* salva r16 (vai guardar o ponteiro) */
    mov   r16, r4                   /* r16 = ponteiro para o caractere atual */

.Lputs_laco:
    /* Envia caractere por caractere ate o 0 final */
    ldbu  r4, 0(r16)                /* r4 = caractere atual */
    beq   r4, r0, .Lputs_fim        /* se for 0, acabou a string */
    call  uart_putc                 /* envia o caractere */
    addi  r16, r16, 1               /* aponta para o proximo caractere */
    br    .Lputs_laco               /* repete */

.Lputs_fim:
    /* Epilogo */
    ldw   ra, 0(sp)                 /* restaura ra */
    ldw   r16, 4(sp)                /* restaura r16 */
    addi  sp, sp, 8                 /* libera a pilha */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * uart_put_hex_digit
 * Envia um digito hexadecimal (r4 = 0..15) como caractere maiusculo.
 * ---------------------------------------------------------------------------- */
uart_put_hex_digit:
    /* Prologo: chama uart_putc */
    subi  sp, sp, 4                 /* reserva 1 word na pilha */
    stw   ra, 0(sp)                 /* salva ra */

    /* Converte o valor no caractere pela tabela */
    andi  r8, r4, 0x0F              /* r8 = valor, so 4 bits */
    movia r9, DIGITOS_HEX           /* r9 = endereco da tabela de caracteres */
    add   r9, r9, r8                /* r9 = endereco do caractere do valor */
    ldbu  r4, 0(r9)                 /* r4 = caractere ('0'..'9', 'A'..'F') */
    call  uart_putc                 /* envia o caractere */

    /* Epilogo */
    ldw   ra, 0(sp)                 /* restaura ra */
    addi  sp, sp, 4                 /* libera a pilha */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * uart_put_dec
 * Envia r4 em decimal sem zeros a esquerda (decisao do grupo). Usa to_bcd
 * (utils.s) e pula os nibbles zero da esquerda; o das unidades sai sempre,
 * para que 0 apareca como "0".
 * ---------------------------------------------------------------------------- */
uart_put_dec:
    /* Prologo: chama outras rotinas, guarda ra, r16 e r17 */
    subi  sp, sp, 12                /* reserva 3 words na pilha */
    stw   ra, 0(sp)                 /* salva ra */
    stw   r16, 4(sp)                /* salva r16 (vai guardar o BCD) */
    stw   r17, 8(sp)                /* salva r17 (vai contar os digitos) */

    /* Converte para BCD */
    call  to_bcd                    /* r2 = valor em BCD (8 digitos) */
    mov   r16, r2                   /* r16 = BCD */
    movi  r17, 8                    /* r17 = digitos que faltam olhar */

.Ldec_pula_zeros:
    /* Pula os zeros da esquerda (mas nunca o ultimo digito) */
    movi  r8, 1                     /* r8 = 1 */
    beq   r17, r8, .Ldec_imprime    /* se so falta o das unidades, imprime */
    srli  r8, r16, 28               /* r8 = digito mais a esquerda */
    bne   r8, r0, .Ldec_imprime     /* se nao for zero, comeca a imprimir */
    slli  r16, r16, 4               /* descarta esse zero */
    subi  r17, r17, 1               /* um digito a menos */
    br    .Ldec_pula_zeros          /* olha o proximo */

.Ldec_imprime:
    /* Imprime os digitos restantes, da esquerda para a direita */
    srli  r8, r16, 28               /* r8 = digito mais a esquerda */
    addi  r4, r8, 0x30              /* r4 = caractere do digito (0x30 = '0') */
    call  uart_putc                 /* envia o digito */
    slli  r16, r16, 4               /* traz o proximo digito para o topo */
    subi  r17, r17, 1               /* um digito a menos */
    bne   r17, r0, .Ldec_imprime    /* repete ate o das unidades */

    /* Epilogo */
    ldw   ra, 0(sp)                 /* restaura ra */
    ldw   r16, 4(sp)                /* restaura r16 */
    ldw   r17, 8(sp)                /* restaura r17 */
    addi  sp, sp, 12                /* libera a pilha */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * uart_print_wait
 * Mensagem do estado AGUARDANDO (sai uma vez, ao ligar a placa).
 * ---------------------------------------------------------------------------- */
uart_print_wait:
    /* Prologo */
    subi  sp, sp, 4                 /* reserva 1 word na pilha */
    stw   ra, 0(sp)                 /* salva ra */

    /* Envia a mensagem */
    movia r4, MSG_ESPERA            /* r4 = endereco da mensagem */
    call  uart_puts                 /* envia a mensagem */

    /* Epilogo */
    ldw   ra, 0(sp)                 /* restaura ra */
    addi  sp, sp, 4                 /* libera a pilha */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * uart_print_round
 * Linha de uma rodada. Decide ACERTO/ERRO comparando alvo (r5) e resposta
 * (r6) aqui dentro, para os argumentos caberem em r4-r7 sem usar a pilha.
 * Os argumentos vao para r16-r19 porque cada call pode estragar r4-r7.
 * ---------------------------------------------------------------------------- */
uart_print_round:
    /* Prologo: guarda ra e r16-r19, copia os argumentos para eles */
    subi  sp, sp, 20                /* reserva 5 words na pilha */
    stw   ra, 0(sp)                 /* salva ra */
    stw   r16, 4(sp)                /* salva r16 */
    stw   r17, 8(sp)                /* salva r17 */
    stw   r18, 12(sp)               /* salva r18 */
    stw   r19, 16(sp)               /* salva r19 */
    mov   r16, r4                   /* r16 = rodada */
    mov   r17, r5                   /* r17 = alvo */
    mov   r18, r6                   /* r18 = resposta */
    mov   r19, r7                   /* r19 = pontos ou vidas */

    /* "Rodada N" */
    movia r4, MSG_RODADA            /* r4 = "Rodada " */
    call  uart_puts                 /* envia o texto */
    mov   r4, r16                   /* r4 = numero da rodada */
    call  uart_put_dec              /* envia a rodada em decimal */

    /* " | Alvo: X" */
    movia r4, MSG_ALVO              /* r4 = " | Alvo: " */
    call  uart_puts                 /* envia o texto */
    mov   r4, r17                   /* r4 = alvo */
    call  uart_put_hex_digit        /* envia o alvo em hex */

    /* " | Resposta: Y" */
    movia r4, MSG_RESPOSTA          /* r4 = " | Resposta: " */
    call  uart_puts                 /* envia o texto */
    mov   r4, r18                   /* r4 = resposta */
    call  uart_put_hex_digit        /* envia a resposta em hex */

    /* " | ACERTO | Pontos: " ou " | ERRO   | Vidas: " */
    movia r4, MSG_ACERTO            /* r4 = texto de acerto */
    beq   r17, r18, .Lround_valor   /* se alvo == resposta, mantem acerto */
    movia r4, MSG_ERRO              /* senao, r4 = texto de erro */
.Lround_valor:
    call  uart_puts                 /* envia o texto escolhido */

    /* Valor (pontos ou vidas) e fim da linha */
    mov   r4, r19                   /* r4 = pontos ou vidas */
    call  uart_put_dec              /* envia o valor em decimal */
    movia r4, MSG_NOVA_LINHA        /* r4 = "\n" */
    call  uart_puts                 /* termina a linha */

    /* Epilogo */
    ldw   ra, 0(sp)                 /* restaura ra */
    ldw   r16, 4(sp)                /* restaura r16 */
    ldw   r17, 8(sp)                /* restaura r17 */
    ldw   r18, 12(sp)               /* restaura r18 */
    ldw   r19, 16(sp)               /* restaura r19 */
    addi  sp, sp, 20                /* libera a pilha */
    ret                             /* retorna */

/* ----------------------------------------------------------------------------
 * uart_print_end
 * Linha final. A "Sequencia" sai da propria lista (toda partida comeca no
 * indice 0), entao nao precisa de buffer: e get_target(0..rodadas-1).
 * ---------------------------------------------------------------------------- */
uart_print_end:
    /* Prologo: guarda ra e r16-r17 */
    subi  sp, sp, 12                /* reserva 3 words na pilha */
    stw   ra, 0(sp)                 /* salva ra */
    stw   r16, 4(sp)                /* salva r16 */
    stw   r17, 8(sp)                /* salva r17 */
    mov   r16, r5                   /* r16 = rodadas jogadas */
    mov   r17, r4                   /* r17 = pontos (r4 e usado abaixo) */

    /* "=== FIM DE JOGO === Pontuacao final: P" */
    movia r4, MSG_FIM               /* r4 = texto do fim */
    call  uart_puts                 /* envia o texto */
    mov   r4, r17                   /* r4 = pontos */
    call  uart_put_dec              /* envia os pontos em decimal */

    /* " | Sequencia: " */
    movia r4, MSG_SEQUENCIA         /* r4 = " | Sequencia: " */
    call  uart_puts                 /* envia o texto */

    /* Um digito hex por rodada jogada */
    mov   r17, r0                   /* r17 = indice da rodada (0) */
.Lend_laco:
    beq   r17, r16, .Lend_fim       /* se ja passou por todas, termina */
    mov   r4, r17                   /* r4 = indice */
    call  get_target                /* r2 = alvo desse indice */
    mov   r4, r2                    /* r4 = alvo */
    call  uart_put_hex_digit        /* envia o alvo em hex */
    addi  r17, r17, 1               /* proxima rodada */
    br    .Lend_laco                /* repete */

.Lend_fim:
    /* Fim da linha */
    movia r4, MSG_NOVA_LINHA        /* r4 = "\n" */
    call  uart_puts                 /* termina a linha */

    /* Epilogo */
    ldw   ra, 0(sp)                 /* restaura ra */
    ldw   r16, 4(sp)                /* restaura r16 */
    ldw   r17, 8(sp)                /* restaura r17 */
    addi  sp, sp, 12                /* libera a pilha */
    ret                             /* retorna */
