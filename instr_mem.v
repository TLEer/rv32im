`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/12/2025 05:02:03 PM
// Design Name: 
// Module Name: instr_mem
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


module instr_mem #(
    parameter IMEM_WORDS = 256,
    parameter IMEM_INIT  = ""
)(
    input  wire [$clog2(IMEM_WORDS)-1:0] addr,
    output wire [31:0] rdata,
    output wire [31:0] debug_instr0  // debug
);
    reg [31:0] mem[0:IMEM_WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < IMEM_WORDS; i = i + 1)
            mem[i] = 32'h00000000;   // default
        if (IMEM_INIT != "")
            $readmemh(IMEM_INIT, mem);
    end

    assign rdata = mem[addr];
    assign debug_instr0 = mem[0]; 
endmodule
