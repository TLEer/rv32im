`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/05/2026 06:49:56 PM
// Design Name: 
// Module Name: mult
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: RV32M Multiplication and Division Unit
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module mult(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start, // Start operation
    input  wire [2:0]  funct3,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] result,
    output wire        busy
);

    // 000: MUL    - lower 32 bits of s * s
    // 001: MULH   - upper 32 bits of s * s
    // 010: MULHSU - upper 32 bits of s * uns
    // 011: MULHU  - upper 32 bits of uns * uns
    // 100: DIV    - s division
    // 101: DIVU   - uns division
    // 110: REM    - s rem
    // 111: REMU   - uns rem

    reg [31:0] result_reg;
    reg busy_reg;
    reg [5:0] cycle_count;
    
    reg [63:0] prod;
    reg [31:0] quot, rem;
    reg [31:0] a_abs, b_abs;
    reg        sign_a, sign_b, sign_result;
    
    localparam IDLE = 2'b00;
    localparam MULT = 2'b01;
    localparam DIV  = 2'b10;
    localparam DONE = 2'b11;
    
    reg [1:0] state;
    reg [2:0] op_type;
    
    // Division algorithm registers
    reg [63:0] dividend_ext;
    reg [31:0] divisor;
    
    assign result = result_reg;
    assign busy = busy_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_reg <= 32'h0;
            busy_reg <= 1'b0;
            state <= IDLE;
            cycle_count <= 6'd0;
            prod <= 64'h0;
            quot <= 32'h0;
            rem <= 32'h0;
            op_type <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        busy_reg <= 1'b1;
                        op_type <= funct3;
                        cycle_count <= 6'd0;
                        
                        // Determine if multiplication or division
                        if (funct3[2] == 1'b0) begin
                            // Multiplication operations (MUL, MULH, MULHSU, MULHU)
                            state <= MULT;
                            
                            case (funct3[1:0])
                                2'b00, 2'b01: begin // MUL, MULH (s * s)
                                    sign_a = a[31];
                                    sign_b = b[31];
                                    a_abs = sign_a ? -a : a;
                                    b_abs = sign_b ? -b : b;
                                    prod <= {32'h0, a_abs} * {32'h0, b_abs};
                                    sign_result = sign_a ^ sign_b;
                                end
                                2'b10: begin // MULHSU (s * uns)
                                    sign_a = a[31];
                                    a_abs = sign_a ? -a : a;
                                    prod <= {32'h0, a_abs} * {32'h0, b};
                                    sign_result = sign_a;
                                end
                                2'b11: begin // MULHU (uns * uns)
                                    prod <= {32'h0, a} * {32'h0, b};
                                    sign_result = 1'b0;
                                end
                            endcase
                        end else begin
                            // Division operations (DIV, DIVU, REM, REMU)
                            state <= DIV;
                            
                            if (funct3[0] == 1'b0) begin // DIV, REM (s)
                                sign_a = a[31];
                                sign_b = b[31];
                                a_abs = sign_a ? -a : a;
                                b_abs = sign_b ? -b : b;
                                dividend_ext <= {32'h0, a_abs};
                                divisor <= b_abs;
                                sign_result = sign_a ^ sign_b;
                            end else begin // DIVU, REMU (uns)
                                dividend_ext <= {32'h0, a};
                                divisor <= b;
                                sign_result = 1'b0;
                            end
                            quot <= 32'h0;
                            rem <= 32'h0;
                        end
                    end
                end
                
                MULT: begin
                    // Multiplication completes in 1 cycle
                    if (sign_result && prod != 64'h0)
                        prod <= -prod;
                    
                    if (op_type[1:0] == 2'b00) // MUL
                        result_reg <= prod[31:0];
                    else // MULH, MULHSU, MULHU
                        result_reg <= prod[63:32];
                    
                    state <= DONE;
                end
                
                DIV: begin
                    // Restoring division algorithm
                    if (cycle_count < 32) begin
                        if (divisor == 32'h0) begin
                            // Division by zero
                            quot <= 32'hFFFFFFFF;
                            rem <= a_abs;
                            cycle_count <= 6'd32;
                        end else begin
                            if (dividend_ext[62:31] >= divisor) begin
                                // Shift and subtract
                                dividend_ext <= {dividend_ext[62:31] - divisor, dividend_ext[30:0], 1'b0};
                                quot <= {quot[30:0], 1'b1};
                            end else begin
                                // Just shift
                                dividend_ext <= {dividend_ext[62:0], 1'b0};
                                quot <= {quot[30:0], 1'b0};
                            end
                            cycle_count <= cycle_count + 1;
                        end
                    end else begin
                        // Division complete
                        rem <= dividend_ext[63:32];
                        
                        // Signs
                        if (op_type[0] == 1'b0) begin // DIV, REM (s)
                            if (op_type[1] == 1'b0) begin // DIV
                                if (sign_result && quot != 32'h0)
                                    result_reg <= -quot;
                                else
                                    result_reg <= quot;
                            end else begin // REM
                                if (sign_a && rem != 32'h0)
                                    result_reg <= -rem;
                                else
                                    result_reg <= rem;
                            end
                        end else begin // DIVU, REMU (uns)
                            if (op_type[1] == 1'b0) // DIVU
                                result_reg <= quot;
                            else // REMU
                                result_reg <= rem;
                        end
                        
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    busy_reg <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule