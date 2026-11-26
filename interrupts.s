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

.include "constants.s"

.global interrupts_init

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
.section .exceptions, "ax"
RTI:
    rdctl et, ipending
    beq   et, r0, .Lrti_nao_interrupcao

    subi  ea, ea, 4                 /* interrupcao externa: refazer a instrucao
                                       que foi interrompida antes de terminar */
    subi  sp, sp, 12
    stw   r8, 0(sp)
    stw   r9, 4(sp)
    stw   r10, 8(sp)

    /* ---- IRQ0: timer ---- */
    andi  r8, et, IRQ_TIMER
    beq   r8, r0, .Lrti_keys

    movia r8, TIMER_BASE
    stwio r0, TIMER_STATUS_REG(r8)  /* limpa TO: senao a IRQ continua pendente
                                       e a RTI reentra para sempre */
    movi  r9, 1
    movia r8, FLAG_TICK
    stw   r9, 0(r8)

.Lrti_keys:
    /* ---- IRQ1: push buttons ---- */
    andi  r8, et, IRQ_KEY
    beq   r8, r0, .Lrti_fim

    movia r8, KEY_BASE
    ldwio r9, KEY_EDGE_REG(r8)      /* quais botoes tiveram borda... */
    stwio r0, KEY_EDGE_REG(r8)      /* ...e so depois limpa (mesma ordem do lab 5) */

    movi  r10, 1                    /* valor para levantar os flags */

    andi  r8, r9, KEY1_BIT
    beq   r8, r0, .Lrti_key2
    movia r8, FLAG_KEY1
    stw   r10, 0(r8)

.Lrti_key2:
    /* Os dois botoes podem ter borda na mesma interrupcao: os dois flags
     * sobem e o laco principal decide pela prioridade KEY1 > KEY2. */
    andi  r8, r9, KEY2_BIT
    beq   r8, r0, .Lrti_fim
    movia r8, FLAG_KEY2
    stw   r10, 0(r8)

.Lrti_fim:
    ldw   r8, 0(sp)
    ldw   r9, 4(sp)
    ldw   r10, 8(sp)
    addi  sp, sp, 12
    eret

.Lrti_nao_interrupcao:
    /* O jogo nao usa trap nem instrucoes emuladas: qualquer outra excecao e
     * bug. Acende todos os LEDR e trava, para aparecer na hora na placa
     * (ea aponta para a instrucao seguinte a que causou a excecao). */
    movia et, LEDR_BASE
    movia r8, 0x3FFFF
    stwio r8, 0(et)
.Lrti_trava:
    br    .Lrti_trava

/* ----------------------------------------------------------------------------
 * interrupts_init
 * Ordem: primeiro o dispositivo, depois ienable, por ultimo o PIE, para que
 * nenhuma interrupcao chegue antes de tudo estar configurado. Limpa o
 * edgecapture antes, para que um aperto feito antes do jogo nao vire evento.
 * ---------------------------------------------------------------------------- */
.text
interrupts_init:
    movia r8, KEY_BASE
    stwio r0, KEY_EDGE_REG(r8)
    movi  r9, KEY1_BIT | KEY2_BIT   /* KEY0 e KEY3 nao sao usados */
    stwio r9, KEY_MASK_REG(r8)

    movi  r9, IRQ_TIMER | IRQ_KEY
    wrctl ienable, r9

    movi  r9, 1
    wrctl status, r9                /* PIE = 1 */
    ret
