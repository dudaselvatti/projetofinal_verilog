/*
******************************************************************************
Projeto: ULA de 3 Bits com FSM e Visualização em 6 Displays
Placa: DE1-SoC (Cyclone V) ou DE2-115 (Cyclone IV)
******************************************************************************
*/

module projeto_ula_completo (
    input  wire        CLOCK_50, // Clock 50MHz
    input  wire [2:0]  SW,       // SW[2], SW[1], SW[0] para dados
    input  wire [0:0]  KEY,      // KEY[0] para avançar etapas
    // Saídas para os 6 Displays (Active Low)
    output wire [6:0]  HEX0,     // Resultado (Unidade)
    output wire [6:0]  HEX1,     // Resultado (Dezena)
    output wire [6:0]  HEX2,     // Espaço (Apagado)
    output wire [6:0]  HEX3,     // Operando B
    output wire [6:0]  HEX4,     // Espaço (Apagado)
    output wire [6:0]  HEX5,     // Operando A
    // LEDs de Status
    output reg  [9:0]  LEDR      // LEDR[0-5] Resultado binário, LEDR[6] Zero, etc.
);

    // --- 1. DEFINIÇÃO DE ESTADOS E REGISTRADORES ---
    parameter ESTADO_RESET   = 0;
    parameter ESTADO_LOAD_A  = 1;
    parameter ESTADO_LOAD_B  = 2;
    parameter ESTADO_LOAD_OP = 3;
    parameter ESTADO_EXEC    = 4;

    reg [2:0] estado_atual = ESTADO_RESET;
    reg [2:0] reg_a;
    reg [2:0] reg_b;
    reg [2:0] reg_op;

    // --- 2. DETECTOR DE BORDA DO BOTÃO ---
    reg btn_prev;
    wire btn_clicado;
    
    always @(posedge CLOCK_50) begin
        btn_prev <= KEY[0];
    end
    // Detecta transição de solto (1) para apertado (0)
    assign btn_clicado = (btn_prev == 1'b1 && KEY[0] == 1'b0);

    // --- 3. MÁQUINA DE ESTADOS (FSM) ---
    always @(posedge CLOCK_50) begin
        if (btn_clicado) begin
            case (estado_atual)
                ESTADO_RESET:   estado_atual <= ESTADO_LOAD_A;
                ESTADO_LOAD_A: begin
                    reg_a <= SW; // Grava A
                    estado_atual <= ESTADO_LOAD_B;
                end
                ESTADO_LOAD_B: begin
                    reg_b <= SW; // Grava B
                    estado_atual <= ESTADO_LOAD_OP;
                end
                ESTADO_LOAD_OP: begin
                    reg_op <= SW; // Grava OP
                    estado_atual <= ESTADO_EXEC;
                end
                ESTADO_EXEC: begin
                    reg_a <= 0; reg_b <= 0; reg_op <= 0;
                    estado_atual <= ESTADO_RESET;
                end
                default: estado_atual <= ESTADO_RESET;
            endcase
        end
    end

    // --- 4. LÓGICA DA ULA ---
    reg [6:0] resultado_calc;
    reg flag_zero, flag_neg, flag_over;

    always @(*) begin
        // Valores padrão
        resultado_calc = 0;
        flag_neg = 0; flag_over = 0; flag_zero = 0;
        
        // Só calcula se estiver no estado de execução (ou mostra prévia)
        case (reg_op)
            3'b000: resultado_calc = reg_a + reg_b; // Soma
            3'b001: begin // Subtração
                if (reg_b > reg_a) begin
                    resultado_calc = reg_b - reg_a;
                    flag_neg = 1;
                end else begin
                    resultado_calc = reg_a - reg_b;
                end
            end
            3'b010: resultado_calc = reg_a * reg_b; // Multiplicação
            3'b011: begin // Divisão
                if (reg_b == 0) begin
                    resultado_calc = 0; flag_over = 1;
                end else begin
                    resultado_calc = reg_a / reg_b;
                end
            end
            3'b100: resultado_calc = reg_a & reg_b; // AND
            3'b101: resultado_calc = reg_a | reg_b; // OR
            3'b110: resultado_calc = reg_a ^ reg_b; // XOR
            default: resultado_calc = 0;
        endcase

        if (resultado_calc == 0) flag_zero = 1;
        if (resultado_calc > 40) flag_over = 1;
    end

    // --- 5. CONTROLE DOS LEDS (LEDR) ---
    always @(*) begin
        if (estado_atual == ESTADO_EXEC) begin
            LEDR[5:0] = resultado_calc[5:0]; // Resultado Binário
            LEDR[6]   = flag_zero;
            LEDR[7]   = flag_neg;
            LEDR[8]   = flag_over;
            LEDR[9]   = 1; // LED aceso indica "Fim/Resultado Pronto"
        end else begin
            // Durante configuração, mostra o estado atual nos LEDs
            LEDR = 0;
            LEDR[2:0] = estado_atual; 
        end
    end

    // --- 6. CONTROLE DOS DISPLAYS (HEX) ---
    
    // Variáveis para separar dezena e unidade do resultado
    wire [3:0] res_unidade = (estado_atual == ESTADO_EXEC) ? (resultado_calc % 10) : 0;
    wire [3:0] res_dezena  = (estado_atual == ESTADO_EXEC) ? (resultado_calc / 10) : 0;

    // Lógica visual: Enquanto estiver carregando A, mostra o Switch no display A. 
    // Depois de gravado, mostra o valor do registrador.
    wire [3:0] disp_a_val = (estado_atual == ESTADO_LOAD_A) ? SW : reg_a;
    wire [3:0] disp_b_val = (estado_atual == ESTADO_LOAD_B) ? SW : reg_b;

    // --- INSTÂNCIA DOS DECODIFICADORES ---
    
    // HEX5: Mostra A
    decodificador_7seg display_A (
        .numero(disp_a_val), 
        .habilitar(estado_atual >= ESTADO_LOAD_A), // Só acende a partir do estado 1
        .seg(HEX5)
    );

    // HEX4: Em branco
    assign HEX4 = 7'b1111111; 

    // HEX3: Mostra B
    decodificador_7seg display_B (
        .numero(disp_b_val), 
        .habilitar(estado_atual >= ESTADO_LOAD_B), // Só acende a partir do estado 2
        .seg(HEX3)
    );

    // HEX2: Em branco
    assign HEX2 = 7'b1111111;

    // HEX1: Resultado (Dezena)
    decodificador_7seg display_res_dez (
        .numero(res_dezena), 
        .habilitar(estado_atual == ESTADO_EXEC), // Só acende no final
        .seg(HEX1)
    );

    // HEX0: Resultado (Unidade)
    decodificador_7seg display_res_uni (
        .numero(res_unidade), 
        .habilitar(estado_atual == ESTADO_EXEC), // Só acende no final
        .seg(HEX0)
    );

endmodule


// --- MÓDULO AUXILIAR: DECODIFICADOR 7 SEGMENTOS ---
// Este módulo converte um número de 4 bits para o desenho no display
module decodificador_7seg (
    input [3:0] numero,
    input habilitar,
    output reg [6:0] seg
);
    always @(*) begin
        if (!habilitar) begin
            seg = 7'b1111111; // Apagado
        end else begin
            case (numero)
                // Lógica Inversa (0 acende, 1 apaga) para DE1-SoC
                4'h0: seg = 7'b1000000;
                4'h1: seg = 7'b1111001;
                4'h2: seg = 7'b0100100;
                4'h3: seg = 7'b0110000;
                4'h4: seg = 7'b0011001;
                4'h5: seg = 7'b0010010;
                4'h6: seg = 7'b0000010;
                4'h7: seg = 7'b1111000;
                4'h8: seg = 7'b0000000;
                4'h9: seg = 7'b0010000;
                4'hA: seg = 7'b0001000;
                4'hB: seg = 7'b0000011;
                4'hC: seg = 7'b1000110;
                4'hD: seg = 7'b0100001;
                4'hE: seg = 7'b0000110;
                4'hF: seg = 7'b0001110;
                default: seg = 7'b1111111;
            endcase
        end
    end
endmodule