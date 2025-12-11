`timescale 1ns/1ps

module tb_projeto_ula;

    // --- SINAIS DE CONEXÃO ---
    reg clk;
    reg [2:0] sw_entrada;
    reg botao_prox; // Simula o KEY[0]

    // Saídas para observar
    wire [6:0] seg;
    wire [1:0] an;
    wire led_over;
    wire led_zero;
    wire led_neg;
    wire [2:0] leds_debug; // Para ver o estado (0, 1, 2, 3, 4)

    // --- INSTÂNCIA DO SEU PROJETO (DUT - Device Under Test) ---
    projeto_ula_fsm DUT (
        .clk(clk),
        .sw_entrada(sw_entrada),
        .botao_prox(botao_prox),
        .seg(seg),
        .an(an),
        .led_over(led_over),
        .led_zero(led_zero),
        .led_neg(led_neg),
        .leds_debug(leds_debug)
    );

    // --- GERADOR DE CLOCK (50MHz) ---
    always #10 clk = ~clk; // Inverte a cada 10ns (Período = 20ns)

    // --- TAREFA PARA SIMULAR O CLIQUE NO BOTÃO ---
    // Como seu código tem detector de borda, precisamos simular o aperto e soltura
    task apertar_botao;
        begin
            @(negedge clk);
            botao_prox = 0; // Pressiona (Active Low)
            #100;           // Segura um pouco
            @(negedge clk);
            botao_prox = 1; // Solta
            #100;           // Espera um pouco antes do próximo passo
        end
    endtask

    // --- CENÁRIO DE TESTE ---
    initial begin
        $dumpfile("ondas.vcd");       // Nome do arquivo de ondas que será gerado
        $dumpvars(0, tb_projeto_ula);
        // 1. Inicialização
        clk = 0;
        botao_prox = 1; // Botão solto
        sw_entrada = 0;
        
        $display("--- INICIO DA SIMULACAO ---");
        #100; // Espera estabilizar

        // O sistema começa no Estado 0 (Reset).
        // Vamos realizar a operação: 3 + 1 = 4
        
        // -------------------------------------------------------
        // PASSO 1: Sair do Reset -> Ir para Load A
        $display("Tempo: %0t | Estado: %d | Acao: Clicar para ir para Load A", $time, leds_debug);
        apertar_botao(); 

        // -------------------------------------------------------
        // PASSO 2: Carregar A = 3 (011)
        #50;
        sw_entrada = 3'b011; // Coloca 3 nos switches
        #50;
        $display("Tempo: %0t | Estado: %d | Acao: Carregando A=3", $time, leds_debug);
        apertar_botao(); // Grava A e vai para Load B

        // -------------------------------------------------------
        // PASSO 3: Carregar B = 1 (001)
        #50;
        sw_entrada = 3'b001; // Coloca 1 nos switches
        #50;
        $display("Tempo: %0t | Estado: %d | Acao: Carregando B=1", $time, leds_debug);
        apertar_botao(); // Grava B e vai para Load OP

        // -------------------------------------------------------
        // PASSO 4: Carregar OP = SOMA (000)
        #50;
        sw_entrada = 3'b000; // Opção 000 é soma
        #50;
        $display("Tempo: %0t | Estado: %d | Acao: Carregando OP=Soma", $time, leds_debug);
        apertar_botao(); // Grava OP e vai para EXECUÇÃO

        // -------------------------------------------------------
        // PASSO 5: Execução e Verificação
        #100;
        $display("Tempo: %0t | Estado: %d | RESULTADO NOS LEDS (Esperado 4)", $time, leds_debug);
        
        // Dica: No visualizador de ondas, olhe para a variável interna 'resultado_final'
        // pois ler os segmentos 'seg' visualmente é difícil.
        
        // -------------------------------------------------------
        // TESTE EXTRA: Resetar e fazer uma Subtração Negativa (2 - 5)
        apertar_botao(); // Volta para Reset
        
        $display("--- Teste 2: Subtracao Negativa (2 - 5) ---");
        apertar_botao(); // Vai para Load A
        
        sw_entrada = 3'b010; // A = 2
        apertar_botao();     // Grava A
        
        sw_entrada = 3'b101; // B = 5
        apertar_botao();     // Grava B
        
        sw_entrada = 3'b001; // OP = Subtração
        apertar_botao();     // Executa
        
        #100;
        // Esperado: Resultado 3 (magnitude) e LED_NEG acesso
        if (led_neg == 1) $display("SUCESSO: Flag Negativo acendeu!");
        else $display("ERRO: Flag Negativo falhou.");

        #200;
        $stop;
    end

endmodule