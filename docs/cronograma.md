# HexRush – Cronograma (6.1.3)

Entrega: **03/12/2026**. Três semanas a partir de 12/11, uma a menos que a sugestão do enunciado; as semanas 3 e 4 do enunciado foram juntadas na S3.

A divisão é uma proposta. Tudo que mexe com interrupção (RTI, ISRs, timer, pausa) ficou com a mesma pessoa, para que o salvamento de registradores seja consistente.

| Pessoa | Foco |
|---|---|
| Gustavo Gomes | displays, deslocamento do alvo, fim de jogo e tela `GO  XXXX` |
| Gustavo Varjão | chaves e LEDs, comparação, lista de alvos, testes de casos-limite |
| Moisés | RTI, ISRs, timer, pausa e aceleração |
| Vitor | repositório, UART e conversão decimal, laço principal, mensagens |

Snapshot de 26/11. A versão viva, com status editável, está na planilha do grupo.

| # | Sem. | Tarefa | Responsável | Início | Prazo | Depende de | Critério de pronto |
|---|---|---|---|---|---|---|---|
| 1 | S1 | Fechar decisões pendentes e congelar a especificação | Todos | 12/11 | 13/11 | — | Lista de decisões fechada em `docs/especificacao.md` |
| 2 | S1 | Repositório, estrutura de arquivos e `constants.s` (endereços, período inicial, vidas) | Vitor | 13/11 | 14/11 | 1 | Projeto monta no Monitor Program a partir do repo |
| 3 | S1 | Interfaces das sub-rotinas: parâmetros, retorno e registradores preservados (6.1.5) | Todos | 14/11 | 15/11 | 1 | Tabela de interfaces aprovada pelos 4 |
| 4 | S1 | Displays: tabela 7 seg (0–F, G, O, apagado) e rotina que escreve um dígito em HEXn | Gustavo Gomes | 15/11 | 18/11 | 3 | Teste isolado na placa: qualquer dígito em qualquer HEX |
| 5 | S1 | Chaves e LEDs: ler SW[17:14], LEDR em unário, LEDG com vidas | Gustavo Varjão | 15/11 | 18/11 | 3 | Teste isolado: SW aparece em LEDR unário |
| 6 | S1 | RTI + ISR de KEY1/KEY2 (salva e restaura registradores, só levanta flags) | Moisés | 15/11 | 18/11 | 3 | Flags mudam sem corromper o laço principal |
| 7 | S1 | Timer + ISR: 1 s, reprogramar período, STOP/START para a pausa | Moisés | 15/11 | 18/11 | 3, 6 | Tick a cada 1 s medido na placa; pausa preserva tempo restante |
| 8 | S1 | UART: caractere e string por polling + conversão decimal (2 e 4 dígitos) | Vitor | 15/11 | 18/11 | 3 | Imprime `Rodada 07 \| Pontos: 0042` com valores de teste |
| 9 | S2 | Laço principal e esqueleto da FSM (prioridade KEY1 > KEY2 > tick) | Vitor | 19/11 | 21/11 | 6, 7 | Transições aparecem na UART como debug |
| 10 | S2 | Deslocamento do alvo HEX7 → HEX1 a cada tick | Gustavo Gomes | 19/11 | 22/11 | 4, 9 | Alvo percorre os 7 displays e some no passo seguinte |
| 11 | S2 | HEX0 contínuo com SW + leitura e comparação na chegada do alvo | Gustavo Varjão | 19/11 | 22/11 | 4, 5, 9 | ACERTO/ERRO correto nos 16 valores |
| 12 | S2 | Lista de alvos (`.byte`) + alvo atual/próximo + LEDR com o próximo | Gustavo Varjão | 21/11 | 23/11 | 5, 11 | Sequência segue a lista; LEDR sempre mostra o próximo |
| 13 | S2 | Pausa (KEY2) e reinício (KEY1) integrados à FSM | Moisés | 21/11 | 24/11 | 7, 9 | Pausa congela tudo; KEY1 reinicia do zero |
| 14 | S2 | Integração da semana 2 e teste na placa | Todos | 25/11 | 25/11 | 10–13 | Rodadas completas funcionando (sem pontuação final) |
| 15 | S3 | Pontos, vidas, fim de jogo e tela `GO  XXXX` | Gustavo Gomes | 26/11 | 28/11 | 14 | Jogo termina com 0 vidas e mostra placar com zeros à esquerda |
| 16 | S3 | Aceleração: `p = p − p/20` e reprogramação do timer | Moisés | 26/11 | 27/11 | 14 | Período medido cai 5% por acerto |
| 17 | S3 | Mensagens da UART por rodada + linha final com a sequência | Vitor | 26/11 | 28/11 | 8, 14 | Formato igual ao do enunciado |
| 18 | S3 | Testes de casos-limite (KEY1/KEY2 simultâneos, pausa no fim da rodada, fim da lista, muitos acertos) | Gustavo Varjão | 28/11 | 01/12 | 15–17 | Checklist de testes registrado no relatório |
| 19 | S3 | Revisão dos comentários (explicar o porquê) e organização dos arquivos | Todos | 30/11 | 01/12 | 15–17 | Cada arquivo revisado por outra pessoa |
| 20 | S3 | Relatório em markdown: decisões, justificativas e dificuldades | Todos | 28/11 | 02/12 | 18 | `RELATORIO.md` completo no repo |
| 21 | S3 | Folga + entrega final | Todos | 02/12 | 03/12 | 19, 20 | Commit final no GitHub |
