`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/12/2025 04:59:00 PM
// Design Name: 
// Module Name: alu
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


module alu(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] y
);
    always @(*) begin
        case (alu_ctrl)
            4'b0000: y = a + b;                       // ADD
            4'b0001: y = a - b;                       // SUB
            4'b0010: y = a & b;                       // AND
            4'b0011: y = a | b;                       // OR
            4'b0100: y = a ^ b;                       // XOR
            4'b0101: y = a << b[4:0];                 // SLL
            4'b0110: y = a >> b[4:0];                 // SRL
            4'b0111: y = $signed(a) >>> b[4:0];       // SRA
            4'b1000: y = ($signed(a) < $signed(b));   // SLT
            4'b1001: y = (a < b);                     // SLTU
            default: y = 32'h3f3f3f3f;
        endcase
    end
endmodule
