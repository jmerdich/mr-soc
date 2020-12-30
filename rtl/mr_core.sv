`include "rtl/config.svi"

module mr_core (
    input clk, rst
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
    wire               wbm0_rty_o;    // RTY_O retry output
    wire               wbm0_cyc_i;    // CYC_I cycle input

    // LD-ST wishbone iface sigs
    wire [`XLEN-1:0]   wbm1_adr_i;    // ADR_I() address input
    wire [`XLEN-1:0]   wbm1_dat_i;    // DAT_I() data in
    wire [`XLEN-1:0]   wbm1_dat_o;    // DAT_O() data out
    wire               wbm1_we_i;     // WE_I write enable input
    wire [`XLEN/8-1:0] wbm1_sel_i;    // SEL_I() select input
    wire               wbm1_stb_i;    // STB_I strobe input
    wire               wbm1_ack_o;    // ACK_O acknowledge output
    wire               wbm1_err_o;    // ERR_O error output
    wire               wbm1_rty_o;    // RTY_O retry output
    wire               wbm1_cyc_i;    // CYC_I cycle input

    // Wishbone to memory
    wire [`XLEN-1:0]   wbs_adr_o;     // ADR_O() address output
    wire [`XLEN-1:0]   wbs_dat_i;     // DAT_I() data in
    wire [`XLEN-1:0]   wbs_dat_o;     // DAT_O() data out
    wire               wbs_we_o;      // WE_O write enable output
    wire [`XLEN/8-1:0] wbs_sel_o;     // SEL_O() select output
    wire               wbs_stb_o;     // STB_O strobe output
    wire               wbs_ack_i;     // ACK_I acknowledge input
    wire               wbs_err_i;     // ERR_I error input
    wire               wbs_rty_i;     // RTY_I retry input
    wire               wbs_cyc_o;     // CYC_O cycle output

    // ******************************************************
    // *** Pipelined regs
    // ******************************************************


    mr_ifetch ifetch(clk, rst);
    mr_id id(clk, rst);
    mr_alu alu(clk, rst);
    mr_ldst ldst(clk, rst);

    simple_mem ram(.clk_i(clk), .rst_i(rst),
                   .addr_i(wbs_adr_o),
                   .we_i(wbs_we_o),
                   .sel_i(wbs_sel_o),
                   .dat_i(wbs_dat_o),
                   .stb_i(wbs_stb_o),
                   .cyc_i(wbs_cyc_o),
                   .ack_o(wbs_ack_i),
                   .err_o(wbs_err_i),
                   .dat_o(wbs_dat_i)
                   );
    assign wbs_rty_i = 0; // Unused sig

    wb_arbiter_2 wb_arb(
        .clk, .rst,
        // ifetch
        .wbm0_adr_i, .wbm0_dat_i, .wbm0_dat_o, .wbm0_we_i, .wbm0_sel_i, .wbm0_stb_i, .wbm0_ack_o, .wbm0_err_o, .wbm0_rty_o, .wbm0_cyc_i,

        // load-store
        .wbm1_adr_i, .wbm1_dat_i, .wbm1_dat_o, .wbm1_we_i, .wbm1_sel_i, .wbm1_stb_i, .wbm1_ack_o, .wbm1_err_o, .wbm1_rty_o, .wbm1_cyc_i,

        // memory
        .wbs_adr_o, .wbs_dat_i, .wbs_dat_o, .wbs_we_o, .wbs_sel_o, .wbs_stb_o, .wbs_ack_i, .wbs_err_i, .wbs_rty_i, .wbs_cyc_o 
    );
    
endmodule