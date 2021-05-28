`include "rtl/config.svi"

module mr_core (
    input clk /* verilator clocker */, rst /* verilator public */,
    
    output bus_err
);        
    // ******************************************************
    // *** Memory Interconnect
    // ******************************************************

    // ifetch wishbone iface sigs
    wire [`XLEN-1:0]   wbm0_adr_i;    // ADR_I() address input
    wire [`XLEN-1:0]   wbm0_dat_i;    // DAT_I() data in
    wire [`XLEN-1:0]   wbm0_dat_o;    // DAT_O() data out
    wire               wbm0_we_i;     // WE_I write enable input
    wire [`XLEN/8-1:0] wbm0_sel_i;    // SEL_I() select input
    wire               wbm0_stb_i;    // STB_I strobe input
    wire               wbm0_ack_o;    // ACK_O acknowledge output
    wire               wbm0_err_o;    // ERR_O error output
    wire               wbm0_cyc_i;    // CYC_I cycle input
    wire               wbm0_stall_o;    // RTY_O retry output

    // LD-ST wishbone iface sigs
    wire [`XLEN-1:0]   wbm1_adr_i;    // ADR_I() address input
    wire [`XLEN-1:0]   wbm1_dat_i;    // DAT_I() data in
    wire [`XLEN-1:0]   wbm1_dat_o;    // DAT_O() data out
    wire               wbm1_we_i;     // WE_I write enable input
    wire [`XLEN/8-1:0] wbm1_sel_i;    // SEL_I() select input
    wire               wbm1_stb_i;    // STB_I strobe input
    wire               wbm1_ack_o;    // ACK_O acknowledge output
    wire               wbm1_err_o;    // ERR_O error output
    wire               wbm1_cyc_i;    // CYC_I cycle input
    wire               wbm1_stall_o;    // RTY_O retry output

    // Wishbone to memory
    wire [`XLEN-1:0]   wbs_adr_o;     // ADR_O() address output
    wire [`XLEN-1:0]   wbs_dat_i;     // DAT_I() data in
    wire [`XLEN-1:0]   wbs_dat_o;     // DAT_O() data out
    wire               wbs_we_o;      // WE_O write enable output
    wire [`XLEN/8-1:0] wbs_sel_o;     // SEL_O() select output
    wire               wbs_stb_o;     // STB_O strobe output
    wire               wbs_ack_i;     // ACK_I acknowledge input
    wire               wbs_err_i;     // ERR_I error input
    wire               wbs_cyc_o;     // CYC_O cycle output
    wire               wbs_stall_i;     // RTY_I retry input

    // Our addresses are aligned
    assign wbs_adr_o[$clog2(`XLEN)-1:0] = 0;
    assign wbm0_adr_i[$clog2(`XLEN)-1:0] = 0;
    assign wbm1_adr_i[$clog2(`XLEN)-1:0] = 0;

    // ******************************************************
    // *** Pipelined regs
    // ******************************************************

    // IF -> ID
    wire [`IMAXLEN-1:0] if_id_inst;
    wire [`XLEN-1:0] if_id_pc;
    wire if_valid;
    wire id_ready;

    // WB -> IF
    wire [`XLEN-1:0] wb_pc;
    wire wb_pc_valid;

    // WB -> ID
    wire wb_reg_valid;
    wire [`REGSEL_BITS-1:0] wb_reg;
    wire [`XLEN-1:0]        wb_reg_data;
    wire jmp_done;


    // ID -> ALU
    wire id_valid;
    wire alu_ready;
    e_brops  id_alu_brop;
    wire [`XLEN-1:0]        id_alu_arg1;
    wire [`XLEN-1:0]        id_alu_arg2;
    wire [`REGSEL_BITS-1:0] id_alu_dst;
    e_aluops id_alu_aluop;

    // ID -> ALU (-> LDST)
    wire id_alu_signed;
    e_memops id_alu_memop;
    e_memsz id_alu_size;
    wire [`XLEN-1:0] id_alu_payload;
    wire [`XLEN-1:0] id_alu_payload2;

    // ALU -> LDST
    wire ls_ready;
    wire alu_ls_valid;
    wire alu_ls_signed;
    wire [`XLEN-1:0]        alu_ls_dest;
    wire [`REGSEL_BITS-1:0] alu_ls_dest_reg;
    e_memops alu_ls_memop;
    e_memsz alu_ls_size;
    wire [`XLEN-1:0]        alu_ls_payload;

    assign wbm0_dat_i = 0;
    assign wbm0_we_i = 0;
    assign wbm0_sel_i = 4'b1111;
    mr_ifetch ifetch(.clk, .rst,

        // memory bus
        .adr_o(wbm0_adr_i[`XLEN-1:`XLEN_GRAN]), .dat_i(wbm0_dat_o), .stb_o(wbm0_stb_i), .ack_i(wbm0_ack_o), .err_i(wbm0_err_o),
        .stall_i(wbm0_stall_o), .cyc_o(wbm0_cyc_i),

        // Forwards to ID
        .inst(if_id_inst), .inst_pc(if_id_pc), .inst_valid(if_valid), .id_ready(id_ready),

        // From WB
        .wb_pc, .wb_pc_valid
    );
    mr_id id(.clk, .rst,

        // Backwards from IF
        .inst(if_id_inst), .inst_pc(if_id_pc), .inst_ready(id_ready), .inst_valid(if_valid),

        // Forwards to ALU
        .alu_valid(id_valid), .alu_ready, .alu_arg1(id_alu_arg1), .alu_arg2(id_alu_arg2), .alu_dst(id_alu_dst),
        .alu_br_op(id_alu_brop), .alu_aluop(id_alu_aluop),

        // Forwards to ALU->LDST
        .alu_memop(id_alu_memop), .alu_size(id_alu_size), .alu_signed(id_alu_signed), .alu_payload(id_alu_payload),
        .alu_payload2(id_alu_payload2),

        // From WB
        .wb_valid(wb_reg_valid), .wb_reg(wb_reg), .wb_val(wb_reg_data), .jmp_done
    );


    mr_alu alu(.clk, .rst,

        // Backwards from ID
        .id_valid(id_valid), .id_ready(alu_ready), .id_arg1(id_alu_arg1), .id_arg2(id_alu_arg2), .id_dest_reg(id_alu_dst),
        .id_br_op(id_alu_brop), .id_aluop(id_alu_aluop),

        // Backwards from ID, passed thru
        .id_memop(id_alu_memop), .id_size(id_alu_size), .id_signed(id_alu_signed), .id_payload(id_alu_payload),
        .id_payload2(id_alu_payload2),

        // Forwards to LDST 
        .ls_valid(alu_ls_valid), .ls_ready(ls_ready), .ls_dest(alu_ls_dest), .ls_dest_reg(alu_ls_dest_reg),
        .ls_memop(alu_ls_memop), .ls_size(alu_ls_size), .ls_signed(alu_ls_signed), .ls_payload(alu_ls_payload),

        // Branching
        .wb_pc_valid, .wb_pc, .jmp_done
    );

    mr_ldst ldst(.clk, .rst,
        // Backwards from ALU
        .ex_valid_i(alu_ls_valid), .ex_ready_o(ls_ready), .ex_addr_i(alu_ls_dest), .ex_dst_reg_i(alu_ls_dest_reg),
        .ex_op_i(alu_ls_memop), .ex_size_i(alu_ls_size), .ex_signed_i(alu_ls_signed), .ex_payload_i(alu_ls_payload),

        // WB registers
        .wb_write(wb_reg_valid), .wb_dst_reg_o(wb_reg), .wb_payload_o(wb_reg_data),

        // Memory iface
        .addr_o(wbm1_adr_i[`XLEN-1:`XLEN_GRAN]), .dat_i(wbm1_dat_o), .dat_o(wbm1_dat_i), .stb_o(wbm1_stb_i), .ack_i(wbm1_ack_o),
        .we_o(wbm1_we_i), .sel_o(wbm1_sel_i), .err_i(wbm1_err_o), .stall_i(wbm1_stall_o), .cyc_o(wbm1_cyc_i)
    );

    simple_mem ram(.clk_i(clk), .rst_i(rst),
                   .addr_i(wbs_adr_o[`XLEN-1:`XLEN_GRAN]),
                   .we_i(wbs_we_o),
                   .sel_i(wbs_sel_o),
                   .dat_i(wbs_dat_o),
                   .stb_i(wbs_stb_o),
                   .cyc_i(wbs_cyc_o),
                   .ack_o(wbs_ack_i),
                   .err_o(wbs_err_i),
                   .dat_o(wbs_dat_i),
                   .stall_o(wbs_stall_i)
                   );

    wbarbiter wb_arb(
        .i_clk(clk), .i_reset(rst),
        // ifetch
        .i_a_adr(wbm0_adr_i), .i_a_dat(wbm0_dat_i), .i_a_we(wbm0_we_i), .i_a_sel(wbm0_sel_i),
        .i_a_stb(wbm0_stb_i), .o_a_ack(wbm0_ack_o), .o_a_err(wbm0_err_o), .o_a_stall(wbm0_stall_o), .i_a_cyc(wbm0_cyc_i),

        // load-store
        .i_b_adr(wbm1_adr_i), .i_b_dat(wbm1_dat_i), .i_b_we(wbm1_we_i), .i_b_sel(wbm1_sel_i),
        .i_b_stb(wbm1_stb_i), .o_b_ack(wbm1_ack_o), .o_b_err(wbm1_err_o), .o_b_stall(wbm1_stall_o), .i_b_cyc(wbm1_cyc_i),

        // memory (slave)
        .o_adr(wbs_adr_o), .o_dat(wbs_dat_o), .o_we(wbs_we_o), .o_sel(wbs_sel_o), .o_stb(wbs_stb_o),
        .i_ack(wbs_ack_i), .i_err(wbs_err_i), .i_stall(wbs_stall_i), .o_cyc(wbs_cyc_o) 
    );

    // Return data path doesn't need a mux
    assign wbm0_dat_o = wbs_dat_i;
    assign wbm1_dat_o = wbs_dat_i;
    
    // Signal error
    assign bus_err = wbs_err_i;
endmodule