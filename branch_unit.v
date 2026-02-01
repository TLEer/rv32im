`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/08/2025 05:01:27 PM
// Design Name: 
// Module Name: branch_unit
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


module branch_unit(
    input  wire [2:0]  funct3,
    input  wire [31:0] rs1,
    input  wire [31:0] rs2,
    output reg         take_branch
);
    always @(*) begin
        case (funct3)
            3'b000: take_branch = (rs1 == rs2);                       // BEQ
            3'b001: take_branch = (rs1 != rs2);                       // BNE
            3'b100: take_branch = ($signed(rs1) <  $signed(rs2));     // BLT
            3'b101: take_branch = ($signed(rs1) >= $signed(rs2));     // BGE
            3'b110: take_branch = (rs1 < rs2);                        // BLTU
            3'b111: take_branch = (rs1 >= rs2);                       // BGEU
            default: take_branch = 1'b0;
        endcase
    end
endmodule

