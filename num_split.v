`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/05/2026 01:13:09 AM
// Design Name: 
// Module Name: num_split
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


module num_split(
    input  wire [31:0] in_num,
    input  wire       sp,
    output wire [3:0] d0,
    output wire [3:0] d1,
    output wire [3:0] d2,
    output wire [3:0] d3,
    output wire [3:0] d4,
    output wire [3:0] d5,
    output wire [3:0] d6,
    output wire [3:0] d7
);
    assign d0 = (sp == 0) ? (in_num % 10) : (in_num & 4'hF);
    assign d1 = (sp == 0) ? ((in_num / 10) % 10) : ((in_num >> 4) & 4'hF);
    assign d2 = (sp == 0) ? ((in_num / 100) % 10) : ((in_num >> 8) & 4'hF);
    assign d3 = (sp == 0) ? ((in_num / 1000) % 10) : ((in_num >> 12) & 4'hF);
    assign d4 = (sp == 0) ? ((in_num / 10000) % 10) : ((in_num >> 16) & 4'hF);
    assign d5 = (sp == 0) ? ((in_num / 100000) % 10) : ((in_num >> 20) & 4'hF);
    assign d6 = (sp == 0) ? ((in_num / 1000000) % 10) : ((in_num >> 24) & 4'hF);
    assign d7 = (sp == 0) ? ((in_num / 10000000) % 10) : ((in_num >> 28) & 4'hF);
endmodule
