`include "rtl/config.svi"

module mr_soc (
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
    assign wbm0_adr_i[`XLEN_GRAN-1:0] = 0;
    assign wbm1_adr_i[`XLEN_GRAN-1:0] = 0;

    mr_core core(
        .clk, .rst,

        .wbm0_adr_o(wbm0_adr_i[`XLEN-1:`XLEN_GRAN]),
        .wbm0_dat_i(wbm0_dat_o),
        .wbm0_dat_o(wbm0_dat_i),
        .wbm0_we_o(wbm0_we_i),
        .wbm0_sel_o(wbm0_sel_i),
        .wbm0_stb_o(wbm0_stb_i),
        .wbm0_ack_i(wbm0_ack_o),
        .wbm0_err_i(wbm0_err_o),
        .wbm0_cyc_o(wbm0_cyc_i),
        .wbm0_stall_i(wbm0_stall_o),

        .wbm1_adr_o(wbm1_adr_i[`XLEN-1:`XLEN_GRAN]),
        .wbm1_dat_i(wbm1_dat_o),
        .wbm1_dat_o(wbm1_dat_i),
        .wbm1_we_o(wbm1_we_i),
        .wbm1_sel_o(wbm1_sel_i),
        .wbm1_stb_o(wbm1_stb_i),
        .wbm1_ack_i(wbm1_ack_o),
        .wbm1_err_i(wbm1_err_o),
        .wbm1_cyc_o(wbm1_cyc_i),
        .wbm1_stall_i(wbm1_stall_o)
    );


`ifdef VIVADO
    simple_bram ram(.clk_i(clk), .rst_i(rst),
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
`else
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
`endif

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

