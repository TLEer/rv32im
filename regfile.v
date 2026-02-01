`timescale 1ns/1ps

module regfile(
    input  wire        clk,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire        rd_we,
    input  wire [31:0] rd_wdata,
    output wire [31:0] rs1_rdata,
    output wire [31:0] rs2_rdata,
    output wire [31:0] x5   // For debugging
);
    reg [31:0] rf[0:31];

    // R
    assign rs1_rdata = (rs1 == 0) ? 32'b0 : rf[rs1];
    assign rs2_rdata = (rs2 == 0) ? 32'b0 : rf[rs2];
    assign x5 = rf[28];
    // W
    always @(posedge clk) begin
        if (rd_we && (rd != 0))
            rf[rd] <= rd_wdata;
    end

endmodule
