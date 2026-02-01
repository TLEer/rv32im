`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/08/2025 05:03:18 PM
// Design Name: 
// Module Name: test
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


module test;

    reg sys_clk_in = 0;
    reg sys_rst_n = 0;
    reg [2:0] btn = 3'b000;

    wire [7:0] seg_cs;
    wire [7:0] seg_data_0;
    wire [7:0] seg_data_1;

    localparam IMEM_WORDS = 128;
    localparam DMEM_WORDS = 128;
    localparam IMEM_INIT  = "D:\\Xilinx\\Projects\\rv32i\\prog.hex";
    
    // DUT
    rv32i #(
        .IMEM_WORDS(IMEM_WORDS),
        .DMEM_WORDS(DMEM_WORDS),
        .IMEM_INIT(IMEM_INIT)
    ) dut (
        .sys_clk_in(sys_clk_in),
        .sys_rst_n(sys_rst_n),
        .btn_pin(btn),
        .seg_cs_pin(seg_cs),
        .seg_data_0_pin(seg_data_0),
        .seg_data_1_pin(seg_data_1)
    );

    // Monitor Fibonacci values
    initial begin
        $monitor("Time=%0t rst_n=%b btn[2]=%b fib_display=%d seg_cs=%b", 
                 $time, sys_rst_n, btn[2], dut.fib_display, seg_cs);
    end

    always #5 sys_clk_in = ~sys_clk_in; // 100MHz clock (10ns period)
    
    task press_btn2;
        begin
            btn[2] = 1'b1;
            #50; 
            btn[2] = 1'b0;
            #50;  
        end
    endtask

    initial begin
        
        sys_rst_n = 0;
        btn = 3'b000;
        #30;
        sys_rst_n = 1;
        #20;        
        press_btn2;
        #100;
        press_btn2;
        #100;
        press_btn2;
        #100;
        press_btn2;
        #100;
        press_btn2;
        #100;
        
        #5000;
        $finish;
    end
endmodule

