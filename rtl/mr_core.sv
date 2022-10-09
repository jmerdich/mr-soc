`include "rtl/config.svi"

module mr_core 
#(
    parameter RESET_VEC = 0
)
(
    input clk /* verilator clocker */, rst /* verilator public */,

`ifdef RISCV_FORMAL
    `RVFI_OUTPUTS,
`endif
    
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
    wire [`INSTID_BITS-1:0] if_id_inst_id;
    wire if_id_br_predicted;
    wire if_valid;
    wire id_ready;
    wire id_alu_jump_prediction;

    // WB -> IF
    wire [`XLEN-1:0] wb_pc;
    wire wb_pc_valid;
    wire if_wb_alloc;
    wire [`XLEN-1:0] if_wb_alloc_pc;
    wire [`INSTID_BITS-1:0] wb_if_next_inst_id;
    wire wb_if_inst_buffer_full;

    // WB -> ID
    wire wb_reg_valid;
    wire [`REGSEL_BITS-1:0] wb_reg;
    wire [`XLEN-1:0]        wb_reg_data;

    // ID -> ALU
    wire id_valid;
    wire alu_ready;
    e_brops  id_alu_brop;
    wire [`INSTID_BITS-1:0] id_alu_inst_id;
    wire [`XLEN-1:0]        id_alu_arg1;
    wire [`XLEN-1:0]        id_alu_arg2;
    wire [`REGSEL_BITS-1:0] id_alu_dst;
    e_aluops id_alu_aluop;
    e_payload id_alu_payload_kind;
    wire id_alu_jump_prediction;

    // ID -> ALU (-> LDST)
    wire id_alu_signed;
    e_memops id_alu_memop;
    e_memsz id_alu_size;
    wire [`XLEN-1:0] id_alu_payload;
    wire [`XLEN-1:0] id_alu_payload2;

    // ALU -> LDST
    wire ls_ready;
    wire [`INSTID_BITS-1:0] alu_ls_inst_id;
    wire alu_ls_valid;
    wire alu_ls_signed;
    wire alu_ls_branch_taken;
    wire alu_ls_is_jump;
    wire [`XLEN-1:0]        alu_ls_dest;
    wire [`REGSEL_BITS-1:0] alu_ls_dest_reg;
    e_memops alu_ls_memop;
    e_memsz alu_ls_size;
    wire [`XLEN-1:0]        alu_ls_payload;
    e_payload alu_ls_payload_kind;
    wire alu_ls_jump_predicted;

    // LDST -> WB
    wire ls_wb_valid;
    wire [`XLEN-1:0]        ls_wb_dest;
    wire [`REGSEL_BITS-1:0] ls_wb_dest_reg;
    wire [`INSTID_BITS-1:0] ls_wb_inst_id;
    wire [`XLEN-1:0]        ls_wb_payload;
    e_payload ls_wb_payload_kind;
    wire ls_wb_is_jump;
    wire ls_wb_jump_taken;
    wire ls_wb_jump_predicted;
    wire ls_wb_unpredicted_jump;
    wire ls_wb_has_trap;
    wire [`E_TRAPTYPE_BITS-1:0] trapval;
`ifdef RISCV_FORMAL

`endif
    wire wb_ls_is_speculating;

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

    // Pipe-wide regs
    wire flush_pipe_to_pc;
    wire [`XLEN-1:0] flush_pc;

    // Misc system
    wire [2:0] insts_ret;

    assign wbm0_dat_o = 0;
    assign wbm0_we_o = 0;
    assign wbm0_sel_o = 4'b1111;
    mr_ifetch #( .RESET_VEC(RESET_VEC)) ifetch(
        .clk, .rst,

        // memory bus
        .adr_o(wbm0_adr_o[`XLEN-`XLEN_GRAN-1:0]), .dat_i(wbm0_dat_i), .stb_o(wbm0_stb_o), .ack_i(wbm0_ack_i), .err_i(wbm0_err_i),
        .stall_i(wbm0_stall_i), .cyc_o(wbm0_cyc_o),

        // Forwards to ID
        .inst(if_id_inst), .inst_pc(if_id_pc), .inst_id(if_id_inst_id), .inst_valid(if_valid), .id_ready(id_ready), .inst_br_predicted(if_id_br_predicted),

        // From WB
        .wb_pc, .wb_pc_valid,
        .inst_alloc(if_wb_alloc), 
        .inst_alloc_pc(if_wb_alloc_pc), 
        .inst_buffer_full(wb_if_inst_buffer_full), 
        .next_inst_id(wb_if_next_inst_id)
    );
    mr_id id(.clk, .rst,
        // Backwards from IF
        .inst(if_id_inst), .inst_pc(if_id_pc), .inst_ready(id_ready), .inst_valid(if_valid), .inst_id(if_id_inst_id),
        .inst_br_predicted(if_id_br_predicted),

        // Forwards to ALU
        .alu_valid(id_valid), .alu_ready, .alu_arg1(id_alu_arg1), .alu_arg2(id_alu_arg2), .alu_dst(id_alu_dst),
        .alu_br_op(id_alu_brop), .alu_aluop(id_alu_aluop), .alu_inst_id(id_alu_inst_id), .alu_payload_kind(id_alu_payload_kind),
        .alu_br_predicted(id_alu_jump_prediction),

        // Forwards to ALU->LDST
        .alu_memop(id_alu_memop), .alu_size(id_alu_size), .alu_signed(id_alu_signed), .alu_payload(id_alu_payload),

        // From WB
        .wb_valid(wb_reg_valid), .wb_reg(wb_reg), .wb_val(wb_reg_data), .wb_pipe_flush(flush_pipe_to_pc)
    );

`ifdef NEVER
    mr_syscfg sys(.clk, .rst,
    
        .insts_ret,

        .i_csr_valid(csr_valid), .i_csr_r(csr_r), .i_csr_addr(csr_addr), .i_csr_data(csr_data), .i_csr_wmask(csr_wmask),
        .i_csr_ready(csr_ready), .i_csr_legal(csr_legal), .i_csr_fence(csr_fence), .i_csr_w(csr_w),

        .o_csr_valid(csr_ret_valid), .o_csr_data(csr_ret_data)

`ifdef RISCV_FORMAL_CSR_MCYCLE
        `rvformal_csr_mcycle_conn
`endif
    );
`endif


    mr_alu alu(.clk, .rst,

        // Backwards from ID
        .id_valid(id_valid), .id_ready(alu_ready), .id_arg1(id_alu_arg1), .id_arg2(id_alu_arg2), .id_dest_reg(id_alu_dst),
        .id_br_op(id_alu_brop), .id_aluop(id_alu_aluop), .id_branch_predicted(id_alu_jump_prediction), .id_inst_id(id_alu_inst_id),

        // Backwards from ID, passed thru
        .id_memop(id_alu_memop), .id_size(id_alu_size), .id_signed(id_alu_signed), .id_payload(id_alu_payload), .id_payload_kind(id_alu_payload_kind),

        // Forwards to LDST 
        .ls_valid(alu_ls_valid), .ls_ready(ls_ready), .ls_dest(alu_ls_dest), .ls_dest_reg(alu_ls_dest_reg),
        .ls_memop(alu_ls_memop), .ls_size(alu_ls_size), .ls_signed(alu_ls_signed), .ls_payload(alu_ls_payload),
        .ls_branch_taken(alu_ls_branch_taken), .ls_is_jump(alu_ls_is_jump), .ls_payload_kind(alu_ls_payload_kind),
        .ls_inst_id(alu_ls_inst_id), .ls_branch_predicted(alu_ls_jump_predicted)
    );

    mr_ldst ldst(.clk, .rst,
        // Backwards from ALU
        .ex_valid_i(alu_ls_valid), .ex_ready_o(ls_ready), .ex_addr_i(alu_ls_dest), .ex_dst_reg_i(alu_ls_dest_reg),
        .ex_op_i(alu_ls_memop), .ex_size_i(alu_ls_size), .ex_signed_i(alu_ls_signed), .ex_payload_i(alu_ls_payload),
        .ex_jump_taken_i(alu_ls_branch_taken), .ex_payload_kind_i(alu_ls_payload_kind), .ex_instid_i(alu_ls_inst_id),
        .ex_jump_predicted_i(alu_ls_jump_predicted), .ex_is_jump_i(alu_ls_is_jump),

        // WB registers
        .wb_write(ls_wb_valid), .wb_dst_reg_o(ls_wb_dest_reg), .wb_data_o(ls_wb_dest), .wb_payload_o(ls_wb_payload),
        .wb_payload_kind_o(ls_wb_payload_kind), .wb_jump_taken_o(ls_wb_jump_taken), .wb_instid_o(ls_wb_inst_id),
        .wb_is_jump_o(ls_wb_is_jump), .wb_jump_predicted_o(ls_wb_jump_predicted),

        // Memory iface
        .addr_o(wbm1_adr_o[`XLEN-`XLEN_GRAN-1:0]), .dat_i(wbm1_dat_i), .dat_o(wbm1_dat_o), .stb_o(wbm1_stb_o), .ack_i(wbm1_ack_i),
        .we_o(wbm1_we_o), .sel_o(wbm1_sel_o), .err_i(wbm1_err_i), .stall_i(wbm1_stall_i), .cyc_o(wbm1_cyc_o)
    );

    mr_wb wb(.clk, .rst,

        // Alloc logic
        .inst_in(if_wb_alloc), .inst_pc(if_wb_alloc_pc), .inst_buffer_full(wb_if_inst_buffer_full), .next_inst_id(wb_if_next_inst_id),

        // Retiring insts
        .ret_valid(ls_wb_valid), .ret_id(ls_wb_inst_id), .ret_dst(ls_wb_dest_reg), .ret_data(ls_wb_dest), .is_jump(ls_wb_is_jump), .jump_taken(ls_wb_jump_taken),
        .jump_predicted(ls_wb_jump_predicted), .is_spectulating(wb_ls_is_speculating), .ret_payload(ls_wb_payload), .ret_payload_kind(ls_wb_payload_kind),

        // WB to regfile
        .reg_wb_valid(wb_reg_valid), .reg_wb_dst(wb_reg), .reg_wb_data(wb_reg_data), 

        // Pipe flush (or any unpredicted branch)
        .flush_pipe_to_pc, .flush_pc
    );
    assign wb_pc = flush_pc;
    assign wb_pc_valid = flush_pipe_to_pc;

endmodule
