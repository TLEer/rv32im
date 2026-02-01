`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/12/2025 05:02:34 PM
// Design Name: 
// Module Name: data_mem
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


// MMIO Address Map:
// 0x000 - 0x0FC: Data Memory (word addresses 0x00-0x3F)
// 0x100: Button status (read-only)  - bits [2:0] = btn[2:0]
// 0x104: LED display output (write-only) - 32-bit value for 7-seg

module data_mem #(
    parameter DMEM_WORDS = 256
)(
    input  wire         clk,
    input  wire [31:0]  addr,
    input  wire [31:0]  wdata,
    input  wire         we,
    output reg  [31:0]  rdata,
    // MMIO ports
    input  wire [2:0]   mmio_btn,
    output reg  [31:0]  mmio_led_out,
    output reg          mmio_led_we
);
    localparam DMEM_ADDR_W = $clog2(DMEM_WORDS);
    
    // MMIO address constants
    localparam MMIO_BTN_ADDR = 32'h100;
    localparam MMIO_LED_ADDR = 32'h104;
    
    reg [31:0] mem[0:DMEM_WORDS-1];
    
    // Address decode
    wire is_mmio_region = (addr >= 32'h100);
    wire is_btn_addr    = (addr == MMIO_BTN_ADDR);
    wire is_led_addr    = (addr == MMIO_LED_ADDR);
    wire is_mem_addr    = !is_mmio_region;
    
    // Read mux
    always @(*) begin
        if (is_btn_addr)
            rdata = {29'b0, mmio_btn};
        else if (is_mem_addr)
            rdata = mem[addr[DMEM_ADDR_W+1:2]];
        else
            rdata = 32'h0;
    end

    // Memory write
    always @(posedge clk) begin
        if (we && is_mem_addr)
            mem[addr[DMEM_ADDR_W+1:2]] <= wdata;
    end
    
    // MMIO LED write
    always @(posedge clk) begin
        mmio_led_we <= 1'b0;
        if (we && is_led_addr) begin
            mmio_led_out <= wdata;
            mmio_led_we  <= 1'b1;
        end
    end
endmodule

`default_nettype wire
