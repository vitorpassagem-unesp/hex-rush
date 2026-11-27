/* ============================================================================
 * interrupts.s - Rotina de tratamento de interrupcoes (RTI) e inicializacao
 *
 * Modelo do projeto: as ISRs so LEVANTAM FLAGS na memoria; todo o trabalho
 * (mover alvo, comparar, UART) fica no laco principal. Assim a RTI e curta
 * e nunca chama a UART, que pode demorar.
 *
 * Flags (declarados em main.s, ou no arquivo de teste):
 *   FLAG_TICK  <- timeout do timer (IRQ0)
 *   FLAG_KEY1  <- borda em KEY1   (IRQ1)
 *   FLAG_KEY2  <- borda em KEY2   (IRQ1)
 * Cada um vale 0 ou 1 (decisao do grupo: um tick extra antes de o laco
 * consumir o anterior se perde, em vez de acumular).
 *
 * Rotina publica:
 *   interrupts_init   habilita KEY1/KEY2, IRQ0/IRQ1 e o PIE
 * O timer ja liga o proprio ITO em timer_start (timer.s).
 * ============================================================================ */

.include "constants.s"                  /* traz enderecos, bits e IRQs */

.global interrupts_init                 /* exporta interrupts_init */

/* ----------------------------------------------------------------------------
 * RTI
 * A secao .exceptions e posicionada pelo Monitor Program no endereco de
 * excecao do processador (0x20), qualquer que seja a ordem dos arquivos no
 * projeto.
 *
 * O codigo interrompido pode estar usando qualquer registrador, entao a RTI
 * salva na pilha tudo o que usa alem de et (r8, r9, r10) e restaura antes do
 * eret. Nao usa call: chamar uma sub-rotina estragaria o ra do codigo
 * interrompido (problema que existia nas RTIs dos labs).
 * ---------------------------------------------------------------------------- */
.section .exceptions, "ax"              /* monta no endereco de excecao (0x20) */
RTI:
    /* Separa interrupcao de outras excecoes */
    rdctl et, ipending              /* et = interrupcoes pendentes */
    beq   et, r0, .Lrti_nao_interrupcao /* se nenhuma, e outra excecao */

    /* Interrupcao: ajusta o retorno e salva os registradores usados */
    subi  ea, ea, 4                 /* volta ea para a instrucao interrompida */
    subi  sp, sp, 12                /* reserva 3 words na pilha */
    stw   r8, 0(sp)                 /* salva r8 */
    stw   r9, 4(sp)                 /* salva r9 */
    stw   r10, 8(sp)                /* salva r10 */

    /* IRQ0 (timer): confirma o timeout e levanta FLAG_TICK */
    andi  r8, et, IRQ_TIMER         /* r8 = bit da IRQ do timer */
    beq   r8, r0, .Lrti_keys        /* se o timer nao pediu, vai para os botoes */
    movia r8, TIMER_BASE            /* r8 = endereco do timer */
    stwio r0, TIMER_STATUS_REG(r8)  /* limpa TO (senao a IRQ fica pendente para sempre) */
    movi  r9, 1                     /* r9 = 1 */
    movia r8, FLAG_TICK             /* r8 = endereco de FLAG_TICK */
    stw   r9, 0(r8)                 /* FLAG_TICK = 1 */

.Lrti_keys:
    /* IRQ1 (botoes): descobre quais tiveram borda e limpa o edgecapture */
    andi  r8, et, IRQ_KEY           /* r8 = bit da IRQ dos botoes */
    beq   r8, r0, .Lrti_fim         /* se os botoes nao pediram, termina */
    movia r8, KEY_BASE              /* r8 = endereco dos botoes */
    ldwio r9, KEY_EDGE_REG(r8)      /* r9 = quais botoes tiveram borda */
    stwio r0, KEY_EDGE_REG(r8)      /* limpa o edgecapture (depois de ler) */
    movi  r10, 1                    /* r10 = 1, valor para levantar flags */

    /* KEY1: levanta FLAG_KEY1 */
    andi  r8, r9, KEY1_BIT          /* r8 = bit do KEY1 */
    beq   r8, r0, .Lrti_key2        /* se KEY1 nao foi apertado, pula */
    movia r8, FLAG_KEY1             /* r8 = endereco de FLAG_KEY1 */
    stw   r10, 0(r8)                /* FLAG_KEY1 = 1 */

.Lrti_key2:
    /* KEY2: levanta FLAG_KEY2 (os dois podem subir juntos; o laco
     * principal decide pela prioridade KEY1 > KEY2) */
    andi  r8, r9, KEY2_BIT          /* r8 = bit do KEY2 */
    beq   r8, r0, .Lrti_fim         /* se KEY2 nao foi apertado, pula */
    movia r8, FLAG_KEY2             /* r8 = endereco de FLAG_KEY2 */
    stw   r10, 0(r8)                /* FLAG_KEY2 = 1 */

.Lrti_fim:
    /* Restaura os registradores e volta ao codigo interrompido */
    ldw   r8, 0(sp)                 /* restaura r8 */
    ldw   r9, 4(sp)                 /* restaura r9 */
    ldw   r10, 8(sp)                /* restaura r10 */
    addi  sp, sp, 12                /* libera os 3 words da pilha */
    eret                            /* retorna da excecao */

.Lrti_nao_interrupcao:
    /* Outra excecao (o jogo nao usa nenhuma): e bug. Acende todos os LEDR
     * e trava, para aparecer na placa; ea aponta para a instrucao seguinte
     * a que causou a excecao. */
    movia et, LEDR_BASE             /* et = endereco dos LEDR */
    movia r8, 0x3FFFF               /* r8 = 18 bits 1 (LEDR[17:0]) */
    stwio r8, 0(et)                 /* acende todos os LEDR */
.Lrti_trava:
    br    .Lrti_trava               /* fica parado aqui para sempre */

/* ----------------------------------------------------------------------------
 * interrupts_init
 * Ordem: primeiro o dispositivo, depois ienable, por ultimo o PIE, para que
 * nenhuma interrupcao chegue antes de tudo estar configurado. Limpa o
 * edgecapture antes, para que um aperto feito antes do jogo nao vire evento.
 * ---------------------------------------------------------------------------- */
.text                                   /* volta a montar na secao de codigo */
interrupts_init:
    /* Dispositivo: botoes KEY1 e KEY2 geram interrupcao */
    movia r8, KEY_BASE              /* r8 = endereco dos botoes */
    stwio r0, KEY_EDGE_REG(r8)      /* limpa apertos antigos do edgecapture */
    movi  r9, KEY1_BIT | KEY2_BIT   /* r9 = mascara de KEY1 e KEY2 */
    stwio r9, KEY_MASK_REG(r8)      /* habilita interrupcao so desses dois */

    /* Processador: aceita IRQ0 (timer) e IRQ1 (botoes) */
    movi  r9, IRQ_TIMER | IRQ_KEY   /* r9 = bits das IRQs 0 e 1 */
    wrctl ienable, r9               /* habilita essas IRQs no processador */

    /* Processador: liga as interrupcoes de forma global */
    movi  r9, 1                     /* r9 = 1 (bit PIE) */
    wrctl status, r9                /* PIE = 1 */
    ret                             /* retorna */
