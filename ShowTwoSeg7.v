`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/17/2025 11:58:08 PM
// Design Name: 
// Module Name: ShowTwoSeg7
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


module ShowTwoSeg7(
clk, seg0, seg1, seg2, seg3, seg4, seg5, seg6, seg7, select, seg, segg
);
input wire clk;
input wire [3:0] seg0, seg1, seg2, seg3, seg4, seg5, seg6, seg7;
output reg [7:0] select, seg, segg; 
reg[2:0]  pos; 
reg[3:0]  bcd;
    always @(posedge clk) begin 
        pos <= pos + 1'b1;
    end  
    always @(*) begin 
        case(pos) 
            3'b000: begin 
                select = 8'b00000001; 
                bcd = seg7; 
            end 
            3'b001: begin 
                select = 8'b00000010; 
                bcd = seg6; 
            end
            3'b010: begin
                select = 8'b00000100; 
                bcd = seg5; 
            end 
            3'b011: begin 
                select = 8'b00001000; 
                bcd = seg4; 
            end
            3'b100: begin 
                select = 8'b00010000; 
                bcd = seg3; 
            end 
            3'b101: begin 
                select = 8'b00100000; 
                bcd = seg2; 
            end
            3'b110: begin 
                select = 8'b01000000; 
                bcd = seg1; 
            end 
            3'b111: begin 
                select = 8'b10000000; 
                bcd = seg0; 
            end 
        endcase 
end 
//8421BCD码bcd与一位数码管的8段A、B、C、D、E、F、G、DP之间的对应关系 
    always @(*) begin 
            case(bcd)  
                4'h0: seg = 8'hfc; 
                4'h1: seg = 8'h60; 
                4'h2: seg = 8'hda; 
                4'h3: seg = 8'hf2; 
                4'h4: seg = 8'h66; 
                4'h5: seg = 8'hb6; 
                4'h6: seg = 8'hbe;
                4'h7: seg = 8'he0; 
                4'h8: seg = 8'hfe; 
                4'h9: seg = 8'hf6; 
                4'ha: seg = 8'hee; 
                4'hb: seg = 8'h3e; 
                4'hc: seg = 8'h9c; 
                4'hd: seg = 8'h7a; 
                4'he: seg = 8'h9e; 
                4'hf: seg = 8'h8e; 
                default: seg = 8'hfc;      //八段全熄灭   
            endcase
            segg = seg;
        end 
initial begin 
pos=0; 
end 
endmodule 