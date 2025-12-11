`timescale 1ns/1ps

module tb_projeto_ula;

    // --- 1. SINAIS DE LIGAÇÃO ---
    reg CLOCK_50;
    reg [2:0] SW;
    reg [0:0] KEY; // Definido como vetor para corresponder à entrada do módulo

    // Saídas (Fios para observar)
    wire [6:0] HEX0;
    wire [6:0] HEX1;
    wire [6:0] HEX2;
    wire [6:0] HEX3;
    wire [6:0] HEX4;
    wire [6:0] HEX5;
    wire [9:0] LEDR;

    // --- 2. INSTÂNCIA DO DUT (Device Under Test) ---
    projeto_ula_fsm DUT (
        .CLOCK_50(CLOCK_50),
        .SW(SW),
        .KEY(KEY),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .LEDR(LEDR)
    );

    // --- 3. GERADOR DE CLOCK (50MHz) ---
    always #10 CLOCK_50 = ~CLOCK_50; // Período de 20ns

    // --- 4. TAREFA PARA SIMULAR O CLIQUE NO BOTÃO ---
    // Simula o comportamento físico de pressionar e soltar
    task clicar_botao;
        begin
            @(negedge CLOCK_50);
            KEY[0] = 1'b0; // Pressiona (Active Low)
            #60;           // Segura durante alguns ciclos de clock
            @(negedge CLOCK_50);
            KEY[0] = 1'b1; // Solta
            #60;           // Espera antes da próxima ação
        end
    endtask

    // --- 5. CENÁRIO DE TESTE ---
    initial begin
        // Configuração para o GTKWave
        $dumpfile("ondas_ula.vcd");
        $dumpvars(0, tb_projeto_ula);

        // Inicialização
        CLOCK_50 = 0;
        KEY[0] = 1; // Botão solto (nível alto)
        SW = 0;
        
        $display("=== INICIO DA SIMULACAO ===");
        #100; // Tempo para estabilização

        // ESTADO 0 -> 1: Ir para Load A
        $display("Tempo: %0t | Acao: Iniciar (Ir para Load A)", $time);
        clicar_botao();

        // -----------------------------------------------------------
        // ESTADO 1: Carregar A = 5 (101 binário)
        // -----------------------------------------------------------
        #20;
        SW = 3'b101; 
        #20;
        $display("Tempo: %0t | Acao: Definir A=5 e confirmar", $time);
        // Nota: Neste momento, no GTKWave, deves ver o HEX5 a mudar
        clicar_botao(); 

        // -----------------------------------------------------------
        // ESTADO 2: Carregar B = 3 (011 binário)
        // -----------------------------------------------------------
        #20;
        SW = 3'b011;
        #20;
        $display("Tempo: %0t | Acao: Definir B=3 e confirmar", $time);
        // Nota: Neste momento, deves ver o HEX3 a mudar
        clicar_botao();

        // -----------------------------------------------------------
        // ESTADO 3: Carregar OP = Multiplicação (010 binário)
        // -----------------------------------------------------------
        #20;
        SW = 3'b010; // Código para Multiplicação
        #20;
        $display("Tempo: %0t | Acao: Definir OP=Mult e Executar", $time);
        clicar_botao();

        // -----------------------------------------------------------
        // ESTADO 4: Execução
        // Esperado: 5 * 3 = 15
        // 15 em decimal é '1' no HEX1 e '5' no HEX0
        // 15 em binário é 001111 (visível nos LEDR)
        // -----------------------------------------------------------
        #100;
        $display("Tempo: %0t | RESULTADO CALCULADO", $time);
        
        // Verifica se a flag Zero acendeu incorretamente
        if (LEDR[6] == 1) $display("ERRO: Flag Zero ativa incorretamente.");
        else $display("SUCESSO: Flag Zero inativa.");

        // Verifica o resultado binário nos LEDs (bits 0 a 5)
        if (LEDR[5:0] == 6'd15) $display("SUCESSO: Resultado Binário = 15.");
        else $display("ERRO: Resultado inesperado: %d", LEDR[5:0]);

        // -----------------------------------------------------------
        // TESTE DE RESET
        // -----------------------------------------------------------
        #50;
        $display("Tempo: %0t | Acao: Resetar o sistema", $time);
        clicar_botao();

        #100;
        $finish;
    end

endmodule