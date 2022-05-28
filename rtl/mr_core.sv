`include "rtl/config.svi"

module mr_core 
#(
    parameter RESET_VEC = 0
)
(
    input clk /* verilator clocker */, rst /* verilator public */,
    
    // ******************************************************
    // *** Memory Interconnect
    // ******************************************************

    // ifetch wishbone iface sigs
    output [`XLEN-`XLEN_GRAN-1:0]   wbm0_adr_o,    // ADR() address
    input  [`XLEN-1:0]   wbm0_dat_i,    // DAT_I() data in
    output [`XLEN-1:0]   wbm0_dat_o,    // DAT_O() data out
    output               wbm0_we_o,     // WE write enable
    output [`XLEN/8-1:0] wbm0_sel_o,    // SEL() select
    output               wbm0_stb_o,    // STB strobe
    input                wbm0_ack_i,    // ACK acknowledge
    input                wbm0_err_i,    // ERR error
    output               wbm0_cyc_o,    // CYC cycle
    input                wbm0_stall_i,  // RTY retry

    // LD-ST wishbone iface sigs
    output [`XLEN-`XLEN_GRAN-1:0]   wbm1_adr_o,    // ADR() address
    input  [`XLEN-1:0]   wbm1_dat_i,    // DAT_I() data in
    output [`XLEN-1:0]   wbm1_dat_o,    // DAT_O() data out
    output               wbm1_we_o,     // WE write enable
    output [`XLEN/8-1:0] wbm1_sel_o,    // SEL() select
    output               wbm1_stb_o,    // STB strobe
    input                wbm1_ack_i,    // ACK acknowledge
    input                wbm1_err_i,    // ERR error
    output               wbm1_cyc_o,    // CYC cycle
    input                wbm1_stall_i   // RTY retry
);        


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

    // CSR bus
    wire csr_valid, csr_r, csr_w, csr_ready, csr_fence;
    wire [`CSRLEN-1:0] csr_addr;
    wire [`XLEN-1:0] csr_data;
    wire [`XLEN-1:0] csr_wmask;
    wire csr_ret_valid;
    wire [`XLEN-1:0] csr_ret_data;
    /* verilator lint_off UNOPTFLAT */
    wire csr_legal;
    /* verilator lint_on UNOPTFLAT */

    // Misc system
    wire [2:0] insts_ret;

    assign wbm0_dat_o = 0;
    assign wbm0_we_o = 0;
    assign wbm0_sel_o = 4'b1111;
    mr_ifetch #( .RESET_VEC ) ifetch(.clk, .rst,

        // memory bus
        .adr_o(wbm0_adr_o[`XLEN-`XLEN_GRAN-1:0]), .dat_i(wbm0_dat_i), .stb_o(wbm0_stb_o), .ack_i(wbm0_ack_i), .err_i(wbm0_err_i),
        .stall_i(wbm0_stall_i), .cyc_o(wbm0_cyc_o),

        // Forwards to ID
        .inst(if_id_inst), .inst_pc(if_id_pc), .inst_valid(if_valid), .id_ready(id_ready),

        // From WB
        .wb_pc, .wb_pc_valid
    );
    mr_id id(.clk, .rst,

        .insts_ret,

        // Backwards from IF
        .inst(if_id_inst), .inst_pc(if_id_pc), .inst_ready(id_ready), .inst_valid(if_valid),

        // Forwards to ALU
        .alu_valid(id_valid), .alu_ready, .alu_arg1(id_alu_arg1), .alu_arg2(id_alu_arg2), .alu_dst(id_alu_dst),
        .alu_br_op(id_alu_brop), .alu_aluop(id_alu_aluop),

        // Forwards to ALU->LDST
        .alu_memop(id_alu_memop), .alu_size(id_alu_size), .alu_signed(id_alu_signed), .alu_payload(id_alu_payload),
        .alu_payload2(id_alu_payload2),

        // From WB
        .wb_valid(wb_reg_valid), .wb_reg(wb_reg), .wb_val(wb_reg_data), .jmp_done,

        // CSR bus
        .csr_valid, .csr_ready, .csr_r, .csr_addr, .csr_w, .csr_data, .csr_wmask, .csr_legal, .csr_fence,
        .csr_ret_valid, .csr_ret_data
    );

    mr_syscfg sys(.clk, .rst,
    
        .insts_ret,

        .i_csr_valid(csr_valid), .i_csr_r(csr_r), .i_csr_addr(csr_addr), .i_csr_data(csr_data), .i_csr_wmask(csr_wmask),
        .i_csr_ready(csr_ready), .i_csr_legal(csr_legal), .i_csr_fence(csr_fence), .i_csr_w(csr_w),

        .o_csr_valid(csr_ret_valid), .o_csr_data(csr_ret_data)


    
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
        .addr_o(wbm1_adr_o[`XLEN-`XLEN_GRAN-1:0]), .dat_i(wbm1_dat_i), .dat_o(wbm1_dat_o), .stb_o(wbm1_stb_o), .ack_i(wbm1_ack_i),
        .we_o(wbm1_we_o), .sel_o(wbm1_sel_o), .err_i(wbm1_err_i), .stall_i(wbm1_stall_i), .cyc_o(wbm1_cyc_o)
    );

endmodule
