`timescale 1ns / 1ps

module rv32i #(
    parameter IMEM_WORDS = 256,
    parameter DMEM_WORDS = 256,
    parameter IMEM_INIT  = "/home/wrenley/Verilog/rv32i/prog.hex"
)(
    input  wire        sys_clk_in,
    input  wire        sys_rst_n,
    input  wire [2:0]  btn_pin,
    output wire [7:0]  seg_cs_pin,
    output wire [7:0]  seg_data_0_pin,
    output wire [7:0]  seg_data_1_pin,
    output wire        indic,
    output wire        indbtn
);

    // Internal signals
    wire clk;
    // wire clk = sys_clk_in
    wire clk_disp;
    wire locked;
    wire rst_n = sys_rst_n & locked;
    clk_wiz_0 u_clk_wiz (
        .clk_in1 (sys_clk_in),
        .clk_out1(clk),
        .reset   (~sys_rst_n),
        .locked  (locked)
    );
    clk_div #(
        .N(32'd10000)
    ) u_clk_div (
        .clk0(clk),
        .clk (clk_disp)
    );

    // Button debounce
    localparam integer DEBOUNCE_BITS = 18;
    reg [2:0] btn_sync0, btn_sync1;
    reg [2:0] btn_stable, btn_prev;
    reg [DEBOUNCE_BITS-1:0] btn_cnt [0:2];
    wire btn2_rising = btn_stable[2] & ~btn_prev[2];

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync0   <= 3'b0;
            btn_sync1   <= 3'b0;
            btn_stable  <= 3'b0;
            btn_prev    <= 3'b0;
            for (k = 0; k < 3; k = k + 1)
                btn_cnt[k] <= {DEBOUNCE_BITS{1'b0}};
        end else begin
            btn_sync0  <= btn_pin;
            btn_sync1  <= btn_sync0;
            btn_prev   <= btn_stable;
            for (k = 0; k < 3; k = k + 1) begin
                if (btn_sync1[k] == btn_stable[k])
                    btn_cnt[k] <= {DEBOUNCE_BITS{1'b0}};
                else begin
                    btn_cnt[k] <= btn_cnt[k] + 1'b1;
                    if (&btn_cnt[k]) begin
                        btn_stable[k] <= btn_sync1[k];
                        btn_cnt[k]    <= {DEBOUNCE_BITS{1'b0}};
                    end
                end
            end
        end
    end

    localparam IMEM_ADDR_W = $clog2(IMEM_WORDS);
    localparam DMEM_ADDR_W = $clog2(DMEM_WORDS);

    // Branch predictor parameters
    localparam BP_ENTRIES = 64;
    localparam BP_IDX_W   = $clog2(BP_ENTRIES);

    // ----------------------------------------------------------------------
    // Front-end: PC, predictor, prefetch (next-PC driven by predictor)
    reg [31:0] pc_f;

    reg [1:0]  bht_state   [0:BP_ENTRIES-1]; // 00 SN, 01 WN, 10 WT, 11 ST
    reg [31:0] btb_target  [0:BP_ENTRIES-1];

    wire [BP_IDX_W-1:0] bp_idx_f    = pc_f[BP_IDX_W+1:2];
    wire                pred_taken_f= bht_state[bp_idx_f][1];
    wire [31:0]         pred_tgt_f  = btb_target[bp_idx_f];
    wire [31:0]         pc_plus4_f  = pc_f + 32'd4;
    wire [31:0]         pc_pred_f   = pred_taken_f ? pred_tgt_f : pc_plus4_f;

    wire [31:0] instr_f;
    wire [31:0] debug_instr0;

    instr_mem #(
        .IMEM_WORDS(IMEM_WORDS),
        .IMEM_INIT(IMEM_INIT)
    ) u_imem (
        .addr(pc_f[IMEM_ADDR_W+1:2]),
        .rdata(instr_f),
        .debug_instr0(debug_instr0)  // DDEEBBUUGG
    );

    // ----------------------------------------------------------------------
    // IF/ID pipeline register
    reg        if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instr;
    reg        if_id_pred_taken;
    reg [31:0] if_id_pred_target;

    // Decode
    wire [4:0] if_id_rs1 = if_id_instr[19:15];
    wire [4:0] if_id_rs2 = if_id_instr[24:20];
    wire [4:0] if_id_rd  = if_id_instr[11:7];
    wire [2:0] if_id_funct3 = if_id_instr[14:12];
    wire       if_id_funct7_5 = if_id_instr[30];

    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    imm_gen u_imm (
        .instr(if_id_instr),
        .imm_i(imm_i),
        .imm_s(imm_s),
        .imm_b(imm_b),
        .imm_u(imm_u),
        .imm_j(imm_j)
    );

    wire        dec_reg_write;
    wire        dec_alu_src;
    wire        dec_mem_read;
    wire        dec_mem_write;
    wire        dec_mem_to_reg;
    wire        dec_branch;
    wire        dec_jump;
    wire        dec_jalr;
    wire        dec_is_lui;
    wire        dec_is_auipc;
    wire        dec_is_muldiv;
    wire [3:0]  dec_alu_ctrl;
    control u_ctrl (
        .opcode(if_id_instr[6:0]),
        .funct3(if_id_funct3),
        .funct7_5(if_id_funct7_5),
        .funct7(if_id_instr[31:25]),
        .reg_write(dec_reg_write),
        .alu_src(dec_alu_src),
        .mem_read(dec_mem_read),
        .mem_write(dec_mem_write),
        .mem_to_reg(dec_mem_to_reg),
        .branch(dec_branch),
        .jump(dec_jump),
        .jalr(dec_jalr),
        .is_lui(dec_is_lui),
        .is_auipc(dec_is_auipc),
        .is_muldiv(dec_is_muldiv),
        .alu_ctrl(dec_alu_ctrl)
    );

    // Forward declaration of MEM/WB pipeline state (writeback source)
    reg        mem_wb_valid;
    reg [31:0] mem_wb_pc;
    reg [31:0] mem_wb_pc_plus4;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_rdata;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_mem_to_reg, mem_wb_reg_write;
    reg        mem_wb_is_lui, mem_wb_is_auipc;
    reg [31:0] mem_wb_imm_u;
    reg        mem_wb_jal_or_jalr;

    // Register file (writeback comes from MEM/WB)
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] wb_data;
    wire [31:0] x5;
    regfile u_regfile (
        .clk(clk),
        .rs1(if_id_rs1),
        .rs2(if_id_rs2),
        .rd(mem_wb_rd),
        .rd_we(mem_wb_reg_write),
        .rd_wdata(wb_data),
        .rs1_rdata(rs1_data),
        .rs2_rdata(rs2_data),
        .x5(x5) // DDEEBBUUGG
    );
    // ----------------------------------------------------------------------
    // ID/EX pipeline register
    reg        id_ex_valid;
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_pc_plus4;
    reg [31:0] id_ex_instr;
    reg [4:0]  id_ex_rs1, id_ex_rs2, id_ex_rd;
    reg [2:0]  id_ex_funct3;
    reg        id_ex_funct7_5;
    reg [31:0] id_ex_imm_i, id_ex_imm_s, id_ex_imm_b, id_ex_imm_u, id_ex_imm_j;
    reg [31:0] id_ex_rs1_data, id_ex_rs2_data;
    reg        id_ex_reg_write, id_ex_alu_src, id_ex_mem_read, id_ex_mem_write, id_ex_mem_to_reg;
    reg        id_ex_branch, id_ex_jump, id_ex_jalr, id_ex_is_lui, id_ex_is_auipc;
    reg        id_ex_is_muldiv;
    reg [3:0]  id_ex_alu_ctrl;
    reg        id_ex_pred_taken;
    reg [31:0] id_ex_pred_target;

    // ----------------------------------------------------------------------
    // Hazard detection: load-use
    wire hazard_load_use = id_ex_valid && id_ex_mem_read && (id_ex_rd != 5'b0) &&
                           ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));
    wire stall_loaduse = hazard_load_use;
    
    // Hazard detection: multiply/divide unit busy
    reg        muldiv_start;
    wire [31:0] muldiv_result;
    wire        muldiv_busy;
    
    reg        muldiv_active; 
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            muldiv_active <= 1'b0;
        else if (id_ex_valid && id_ex_is_muldiv) begin
            if (!muldiv_active)
                muldiv_active <= 1'b1; // First cycle: Activate state
            else if (!muldiv_busy)
                muldiv_active <= 1'b0; // Completion
        end else begin
            muldiv_active <= 1'b0;
        end
    end

    // Hazard is false if: Active and Not Busy (Result ready)
    wire hazard_muldiv = (id_ex_valid && id_ex_is_muldiv) && (!muldiv_active || muldiv_busy);

    always @(*) begin
        muldiv_start = id_ex_valid && id_ex_is_muldiv && !muldiv_active && !muldiv_busy;
    end

    // EX stage (with forwarding)
    reg        ex_mem_valid;
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_rs2_fwd;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_mem_read, ex_mem_mem_write, ex_mem_mem_to_reg, ex_mem_reg_write;
    reg        ex_mem_is_lui, ex_mem_is_auipc;
    reg [31:0] ex_mem_imm_u;
    reg [31:0] ex_mem_pc_plus4;
    reg        ex_mem_jal_or_jalr;

    // Hazard detection: Data
    // Forwarding muxes
    wire [31:0] forward_rs1;
    wire [31:0] forward_rs2;

    // If the instruction in MEM is LUI/AUIPC/JAL, the result is not in ex_mem_alu_result
    wire [31:0] ex_mem_forward_data;
    assign ex_mem_forward_data = ex_mem_is_lui      ? ex_mem_imm_u :
                                 ex_mem_is_auipc    ? (ex_mem_pc + ex_mem_imm_u) :
                                 ex_mem_jal_or_jalr ? ex_mem_pc_plus4 :
                                 ex_mem_alu_result;

    assign forward_rs1 = (ex_mem_valid && ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1)) ? ex_mem_forward_data : // Use correct forward data
                         (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1)) ? wb_data :
                         id_ex_rs1_data;

    assign forward_rs2 = (ex_mem_valid && ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2)) ? ex_mem_forward_data : // Use correct forward data
                         (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2)) ? wb_data :
                         id_ex_rs2_data;


    // ALU operand B selection
    wire [31:0] ex_alu_op_b = id_ex_alu_src ? (id_ex_mem_write ? id_ex_imm_s : id_ex_imm_i) : forward_rs2;

    wire [31:0] alu_result;
    alu u_alu (
        .a(forward_rs1),
        .b(ex_alu_op_b),
        .alu_ctrl(id_ex_alu_ctrl),
        .y(alu_result)
    );

    // RV32M
    mult u_mult (
        .clk(clk),
        .rst_n(rst_n),
        .start(muldiv_start),
        .funct3(id_ex_funct3),
        .a(forward_rs1),
        .b(forward_rs2),
        .result(muldiv_result),
        .busy(muldiv_busy)
    );
    
    // Select between ALU and MULDIV result
    wire [31:0] ex_result = id_ex_is_muldiv ? muldiv_result : alu_result;

    // Branch decision with forwarded operands
    wire take_branch;
    branch_unit u_branch (
        .funct3(id_ex_funct3),
        .rs1(forward_rs1),
        .rs2(forward_rs2),
        .take_branch(take_branch)
    );

    wire [31:0] branch_target = id_ex_pc + id_ex_imm_b;
    wire [31:0] jal_target    = id_ex_pc + id_ex_imm_j;
    wire [31:0] jalr_target   = (forward_rs1 + id_ex_imm_i) & ~32'd1;

    // Branch/jump resolution
    wire ex_branch_resolved = id_ex_valid && (id_ex_branch || id_ex_jump || id_ex_jalr);
    wire ex_take_branch     = id_ex_branch && take_branch;
    wire [31:0] ex_pc_correct = id_ex_jump  ? jal_target   :
                                id_ex_jalr ? jalr_target  :
                                ex_take_branch ? branch_target : id_ex_pc_plus4;
    // Hazard detection: Mispredict
    wire ex_mispredict = ex_branch_resolved && (
                            id_ex_jump || id_ex_jalr ||
                            (id_ex_branch && ((ex_take_branch != id_ex_pred_taken) || (ex_take_branch && (branch_target != id_ex_pred_target))))
                         );

    // ----------------------------------------------------------------------
    // MEM stage with MMIO
    reg [31:0] fib_display;
    wire       mmio_led_we;
    wire [31:0] mmio_led_out;
    reg ween = 0;

    

    // Display the fib value
    wire [31:0] display_value = btn_stable[1] ? 
                                (btn_stable[0] ? debug_instr0 : 32'h19260817) : (btn_stable[0] ?  x5 : fib_display)
                                ;
    
    wire [3:0] digit0, digit1, digit2, digit3, digit4, digit5, digit6, digit7;
    num_split u_num_split (
        .in_num(display_value),
        .sp(btn_stable[1]),
        .d0(digit0),
        .d1(digit1),
        .d2(digit2),
        .d3(digit3),
        .d4(digit4),
        .d5(digit5),
        .d6(digit6),
        .d7(digit7)
    );
    // 7-segment display module
    ShowTwoSeg7 u_seg7 (
        .clk(clk_disp),
        .seg0(digit7),
        .seg1(digit6),
        .seg2(digit5),
        .seg3(digit4),
        .seg4(digit3),
        .seg5(digit2),
        .seg6(digit1),
        .seg7(digit0),
        .select(seg_cs_pin),
        .seg(seg_data_0_pin),
        .segg(seg_data_1_pin)
    );
    wire [31:0] dmem_rdata;
    data_mem #(
        .DMEM_WORDS(DMEM_WORDS)
    ) u_dmem (
        .clk(clk),
        .addr(ex_mem_alu_result),
        .wdata(ex_mem_rs2_fwd),
        .we(ex_mem_mem_write && ex_mem_valid),
        .rdata(dmem_rdata),
        // MMIO connections
        .mmio_btn(btn_stable),
        .mmio_led_out(mmio_led_out),
        .mmio_led_we(mmio_led_we)
    );
    
    assign indic = locked;
    assign indbtn = btn_stable[2];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fib_display <= 32'd0;
        end else begin
            ween <= 1;
            fib_display <= mmio_led_out;
        end
    end
    // Writeback mux
    assign wb_data = mem_wb_is_lui      ? mem_wb_imm_u :
                     mem_wb_is_auipc    ? (mem_wb_pc + mem_wb_imm_u) :
                     mem_wb_mem_to_reg  ? mem_wb_mem_rdata :
                     mem_wb_jal_or_jalr ? mem_wb_pc_plus4 :
                     mem_wb_alu_result;

    // ----------------------------------------------------------------------
    // Sequential logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_f <= 32'h0;
            if_id_valid <= 1'b0;
             if_id_pc          <= 32'h0;
            if_id_instr       <= 32'h0;
            if_id_pred_taken  <= 1'b0;
            if_id_pred_target <= 32'h0;
            id_ex_valid <= 1'b0;
            ex_mem_valid<= 1'b0;
            mem_wb_valid<= 1'b0;
                id_ex_pc         <= 32'h0;
                id_ex_pc_plus4   <= 32'h4;
                id_ex_instr      <= 32'h0;
                id_ex_rs1        <= 5'h0;
                id_ex_rs2        <= 5'h0;
                id_ex_rd         <= 5'h0;
                id_ex_funct3     <= 3'h0;
                id_ex_funct7_5   <= 1'b0;
                id_ex_imm_i      <= 32'h0;
                id_ex_imm_s      <= 32'h0;
                id_ex_imm_b      <= 32'h0;
                id_ex_imm_u      <= 32'h0;
                id_ex_imm_j      <= 32'h0;
                id_ex_rs1_data   <= 32'h0;
                id_ex_rs2_data   <= 32'h0;
                id_ex_reg_write  <= 1'b0;
                id_ex_alu_src    <= 1'b0;
                id_ex_mem_read   <= 1'b0;
                id_ex_mem_write  <= 1'b0;
                id_ex_mem_to_reg <= 1'b0;
                id_ex_branch     <= 1'b0;
                id_ex_jump       <= 1'b0;
                id_ex_jalr       <= 1'b0;
                id_ex_is_lui     <= 1'b0;
                id_ex_is_auipc   <= 1'b0;
                id_ex_is_muldiv  <= 1'b0;
                id_ex_alu_ctrl   <= 4'h0;
                id_ex_pred_taken <= 1'b0;
                id_ex_pred_target<= 32'h0;
            mem_wb_pc         <= 32'h0;
            mem_wb_pc_plus4   <= 32'h0;
            mem_wb_alu_result <= 32'h0;
            mem_wb_mem_rdata  <= 32'h0;
            mem_wb_rd         <= 5'h0;
            mem_wb_mem_to_reg <= 1'b0;
            mem_wb_reg_write  <= 1'b0;
            mem_wb_is_lui     <= 1'b0;
            mem_wb_is_auipc   <= 1'b0;
            mem_wb_imm_u      <= 32'h0;
            mem_wb_jal_or_jalr<= 1'b0;
                ex_mem_pc         <= 32'h0;
                ex_mem_alu_result <= 32'h0;
                ex_mem_rs2_fwd    <= 32'h0;
                ex_mem_rd         <= 5'h0;
                ex_mem_mem_read   <= 1'b0;
                ex_mem_mem_write  <= 1'b0;
                ex_mem_mem_to_reg <= 1'b0;
                ex_mem_reg_write  <= 1'b0;
                ex_mem_is_lui     <= 1'b0;
                ex_mem_is_auipc   <= 1'b0;
                ex_mem_imm_u      <= 32'h0;
                ex_mem_pc_plus4   <= 32'h0;
                ex_mem_jal_or_jalr<= 1'b0;
            for (i = 0; i < BP_ENTRIES; i = i + 1) begin
                bht_state[i]  <= 2'b01; // weakly not taken 
                btb_target[i] <= 32'h0;
            end
        end else begin
            // Branch predictor update (on branch resolution)
            if (ex_branch_resolved && id_ex_branch) begin
                // 2-bit saturating counter update
                if (ex_take_branch && bht_state[id_ex_pc[BP_IDX_W+1:2]] != 2'b11)
                    bht_state[id_ex_pc[BP_IDX_W+1:2]] <= bht_state[id_ex_pc[BP_IDX_W+1:2]] + 2'b01;
                else if (!ex_take_branch && bht_state[id_ex_pc[BP_IDX_W+1:2]] != 2'b00)
                    bht_state[id_ex_pc[BP_IDX_W+1:2]] <= bht_state[id_ex_pc[BP_IDX_W+1:2]] - 2'b01;
                btb_target[id_ex_pc[BP_IDX_W+1:2]] <= branch_target;
            end
            if (ex_branch_resolved && (id_ex_jump || id_ex_jalr)) begin
                bht_state[id_ex_pc[BP_IDX_W+1:2]]  <= 2'b11; // JAL/JALR forced taken
                btb_target[id_ex_pc[BP_IDX_W+1:2]] <= ex_pc_correct;
            end

            // PC update (prefetch driven by predictor)
            if (ex_mispredict) begin
                pc_f <= ex_pc_correct;
            end else if (!stall_loaduse && !hazard_muldiv) begin
                pc_f <= pc_pred_f;
            end

            // IF/ID pipeline reg
            if (ex_mispredict) begin
                if_id_valid <= 1'b0;
                if_id_pc          <= 32'h0;
                if_id_instr       <= 32'h0;
                if_id_pred_taken  <= 1'b0;
                if_id_pred_target <= 32'h0;
            end else if (stall_loaduse || hazard_muldiv) begin
                if_id_valid       <= if_id_valid;
                if_id_pc          <= if_id_pc;
                if_id_instr       <= if_id_instr;   
                if_id_pred_taken  <= if_id_pred_taken;
                if_id_pred_target <= if_id_pred_target;
            end else begin
                if_id_valid <= 1'b1;
                if_id_pc    <= pc_f;
                if_id_instr <= instr_f;
                if_id_pred_taken  <= pred_taken_f;
                if_id_pred_target <= pred_tgt_f;
            end

            // ID/EX pipeline reg (bubble on load-use stall)
            if (ex_mispredict) begin
                id_ex_valid <= 1'b0;
                
            end else if (stall_loaduse) begin
                id_ex_valid <= 1'b0;
                id_ex_reg_write  <= 1'b0;
                id_ex_mem_read   <= 1'b0;
                id_ex_mem_write  <= 1'b0;
                id_ex_mem_to_reg <= 1'b0;
                id_ex_branch     <= 1'b0;
                id_ex_jump       <= 1'b0;
                id_ex_jalr       <= 1'b0;
                id_ex_is_lui     <= 1'b0;
                id_ex_is_auipc   <= 1'b0;
                id_ex_is_muldiv  <= 1'b0;
                id_ex_alu_ctrl   <= 4'h0;
            end else if (hazard_muldiv) begin
                id_ex_valid <= id_ex_valid;
            end else begin
                id_ex_valid      <= if_id_valid;
                id_ex_pc         <= if_id_pc;
                id_ex_pc_plus4   <= if_id_pc + 32'd4;
                id_ex_instr      <= if_id_instr;
                id_ex_rs1        <= if_id_rs1;
                id_ex_rs2        <= if_id_rs2;
                id_ex_rd         <= if_id_rd;
                id_ex_funct3     <= if_id_funct3;
                id_ex_funct7_5   <= if_id_funct7_5;
                id_ex_imm_i      <= imm_i;
                id_ex_imm_s      <= imm_s;
                id_ex_imm_b      <= imm_b;
                id_ex_imm_u      <= imm_u;
                id_ex_imm_j      <= imm_j;
                // WB-to-ID forwarding for rs1
                id_ex_rs1_data   <= (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == if_id_rs1)) ? wb_data : rs1_data;
                // WB-to-ID forwarding for rs2  
                id_ex_rs2_data   <= (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == if_id_rs2)) ? wb_data : rs2_data;
                id_ex_reg_write  <= dec_reg_write;
                id_ex_alu_src    <= dec_alu_src;
                id_ex_mem_read   <= dec_mem_read;
                id_ex_mem_write  <= dec_mem_write;
                id_ex_mem_to_reg <= dec_mem_to_reg;
                id_ex_branch     <= dec_branch;
                id_ex_jump       <= dec_jump;
                id_ex_jalr       <= dec_jalr;
                id_ex_is_lui     <= dec_is_lui;
                id_ex_is_auipc   <= dec_is_auipc;
                id_ex_is_muldiv  <= dec_is_muldiv;
                id_ex_alu_ctrl   <= dec_alu_ctrl;
                id_ex_pred_taken <= if_id_pred_taken;
                id_ex_pred_target<= if_id_pred_target;
            end

            // EX/MEM pipeline reg
                // ex_mem_valid <= 1'b0;
            if (!hazard_muldiv) begin
                ex_mem_valid      <= id_ex_valid;
                ex_mem_pc         <= id_ex_pc;
                ex_mem_alu_result <= ex_result;
                ex_mem_rs2_fwd    <= forward_rs2;
                ex_mem_rd         <= id_ex_rd;
                ex_mem_mem_read   <= id_ex_mem_read;
                ex_mem_mem_write  <= id_ex_mem_write;
                ex_mem_mem_to_reg <= id_ex_mem_to_reg;
                ex_mem_reg_write  <= id_ex_reg_write;
                ex_mem_is_lui     <= id_ex_is_lui;
                ex_mem_is_auipc   <= id_ex_is_auipc;
                ex_mem_imm_u      <= id_ex_imm_u;
                ex_mem_pc_plus4   <= id_ex_pc_plus4;
                ex_mem_jal_or_jalr<= (id_ex_jump | id_ex_jalr);
            end

            // MEM/WB pipeline reg
            mem_wb_valid      <= ex_mem_valid;
            mem_wb_pc         <= ex_mem_pc;
            mem_wb_pc_plus4   <= ex_mem_pc_plus4;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_rdata  <= dmem_rdata;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
            mem_wb_reg_write  <= ex_mem_reg_write;
            mem_wb_is_lui     <= ex_mem_is_lui;
            mem_wb_is_auipc   <= ex_mem_is_auipc;
            mem_wb_imm_u      <= ex_mem_imm_u;
            mem_wb_jal_or_jalr<= ex_mem_jal_or_jalr;
        end
    end
    
endmodule

/* 
00500113 # 0x00 addi x2, x0, 5
00500193 # 0x04 addi x3, x0, 5
00200293 # 0x08 addi x5, x0, 2
023100b3 # 0x0c mul x1, x2, x3
00208233 # 0x10 addi x4, x1, 2
0000006f # 0x14 jal x0, 0


7897e0b7 # 0x00 lui x1 493950
98c08093 # 0x04 addi x1 x1 -1652
00200113 # 0x08 addi x2 x0 2
0200c1b3 # 0x0c div x3 x1 x0
0220c1b3 # 0x10 div x3 x1 x2
0000006f # 0x14

22400093 # 0x00 addi x1 x0 548 
0240f113 # 0x04 andi x2 x1 36
402080b3 # 0x08 sub x1 x1 x2
00415113 # 0x0c srli x2 x2 4
002090b3 # 0x10 sll x1 x1 x2
0020e0b3 # 0x14 or x1 x1 x2
0020c0b3 # 0x18 xor x1 x1 x2
ffd00193 # 0x1c addi x3 x0 -3
4021d1b3 # 0x20 sra x3 x3 x2
0021d1b3 # 0x24 srl x3 x3 x2
45000217 # 0x28 auipc x4 282624
0000006f

7897e0b7 # 0x00 lui x1 493950
98c08093 # 0x04 addi x1 x1 -1652
02108133 # 0x08 mul x2 x1 x1
021091b3 # 0x0c mulh x3 x1 x1
0000006f

00500513 #0x00 addi x10, x0, 5
00300593 #0x04 addi x11, x0, 3
00000297 #0x08 auipc x5, 0
01028293 #0x0C addi x5, x5, 16
000280E7 #0x10 jalr x1, x5, 0
0080006F #0x14 jal x0, 8 (j end_loop)
00B50533 #0x18 add x10, x10, x11
00008067 #0x1C jalr x0, x1, 0
00000063 #0x20 beq x0, x0, 0

*/