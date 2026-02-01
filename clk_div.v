`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/18/2025 12:08:12 AM
// Design Name: 
// Module Name: clk_div
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


module clk_div(
    input clk0,
    output reg clk
);  
    parameter N = 32'd100,  WIDTH = 32 - 1;
    reg [WIDTH : 0]  number = 0;
    
    always @(posedge clk0) begin
        if (number == N - 1) begin
           number <=0;
            clk <= ~clk;
        end
        else begin
            number <= number + 1;
        end
    end
    initial begin
    clk=0;
    end
endmodule