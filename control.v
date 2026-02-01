`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/12/2025 05:01:01 PM
// Design Name: 
// Module Name: control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module control(
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire       funct7_5,   // instr[30]
    input  wire [6:0] funct7,     // instr[31:25] for RV32M detection
    output reg        reg_write,
    output reg        alu_src,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_to_reg,
    output reg        branch,
    output reg        jump,
    output reg        jalr,
    output reg        is_lui,
    output reg        is_auipc,
    output reg        is_muldiv,  // RV32M instruction
    output reg [3:0]  alu_ctrl
);
    // default values
    always @(*) begin
        reg_write = 1'b0;
        alu_src   = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        mem_to_reg= 1'b0;
        branch    = 1'b0;
        jump      = 1'b0;
        jalr      = 1'b0;
        is_lui    = 1'b0;
        is_auipc  = 1'b0;
        is_muldiv = 1'b0;
        alu_ctrl  = 4'b0000; // ADD by default

        case (opcode)
            7'b0110011: begin // R-type
                // Check if it's RV32M instruction (funct7 = 0000001)
                if (funct7 == 7'b0000001) begin
                    // RV32M: MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
                    reg_write = 1'b1;
                    is_muldiv = 1'b1;
                    alu_src   = 1'b0;
                end else begin
                    // Standard RV32I R-type
                    reg_write = 1'b1;
                    alu_src   = 1'b0;
                    alu_ctrl  = alu_decode(funct3, funct7_5);
                end
            end
            7'b0010011: begin // I-type ALU
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = alu_decode(funct3, 0);
            end
            7'b0000011: begin // LW
                reg_write = 1'b1;
                alu_src   = 1'b1;
                mem_read  = 1'b1;
                mem_to_reg= 1'b1;
                alu_ctrl  = 4'b0000; // ADD for address
            end
            7'b0100011: begin // SW
                reg_write = 1'b0;
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_ctrl  = 4'b0000; // ADD for address
            end
            7'b1100011: begin // Branch
                branch    = 1'b1;
                alu_src   = 1'b0;
                alu_ctrl  = 4'b0001; // SUB (for EQ/NE; compare in branch_unit)
            end
            7'b1101111: begin // JAL
                reg_write = 1'b1;
                jump      = 1'b1;
                alu_ctrl  = 4'b0000;
            end
            7'b1100111: begin // JALR
                reg_write = 1'b1;
                jalr      = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = 4'b0000;
            end
            7'b0110111: begin // LUI
                reg_write = 1'b1;
                is_lui    = 1'b1;
                alu_ctrl  = 4'b0000;
            end
            7'b0010111: begin // AUIPC
                reg_write = 1'b1;
                is_auipc  = 1'b1;
                alu_ctrl  = 4'b0000;
            end
            default: begin
                // todo
            end
        endcase
    end

    function automatic [3:0] alu_decode(
        input [2:0] f3,
        input       f7_5
    );
        case (f3)
            3'b000: alu_decode = f7_5 ? 4'b0001 : 4'b0000; // SUB : ADD
            3'b111: alu_decode = 4'b0010; // AND
            3'b110: alu_decode = 4'b0011; // OR
            3'b100: alu_decode = 4'b0100; // XOR
            3'b001: alu_decode = 4'b0101; // SLL
            3'b101: alu_decode = f7_5 ? 4'b0111 : 4'b0110; // SRA : SRL
            3'b010: alu_decode = 4'b1000; // SLT
            3'b011: alu_decode = 4'b1001; // SLTU
            default: alu_decode = 4'b0000;
        endcase
    endfunction
endmodule
