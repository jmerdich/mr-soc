`include "rtl/config.svi"

module mr_id (
    input clk, rst,

    // From ifetch
    input [`IMAXLEN-1:0] inst,
    input [`XLEN-1:0] inst_pc,
    input [`INSTID_BITS-1:0] inst_id,
    input inst_br_predicted,
    output inst_ready,
    input inst_valid,

    // To following stages
    output reg alu_valid,
    input alu_ready,
    output reg [`INSTID_BITS-1:0] alu_inst_id,
    output reg [`XLEN-1:0] alu_arg1,
    output reg [`XLEN-1:0] alu_arg2,
    output reg [`REGSEL_BITS-1:0] alu_dst,
    output e_brops alu_br_op,
    output e_aluops alu_aluop,

    output e_memops alu_memop,
    output e_memsz alu_size,
    output reg alu_signed, // ignored on store
    output reg [`XLEN-1:0] alu_payload, // can be *many* things
    output e_payload alu_payload_kind, // debug only :P
    output alu_br_predicted,

    // From WB
    input wb_valid,
    input [`REGSEL_BITS-1:0] wb_reg,
    input [`XLEN-1:0] wb_val
);

    logic [1:0] rs1_writes_pending;
    logic [1:0] rs2_writes_pending;
    logic rs1_data_hazard;
    logic rs2_data_hazard;
    logic [`XLEN-1:0] next_arg1;
    logic [`XLEN-1:0] next_arg2;
    logic [`XLEN-1:0] next_payload;
    e_payload next_payload_kind;
    e_aluops next_alu_op;
    e_memsz next_size;
    logic   next_signed;
    e_memops next_mem_op;
    e_brops next_br_op;
    logic   next_br_predicted;
    logic [`INSTID_BITS-1:0] next_inst_id;
    logic [`REGSEL_BITS-1:0] next_dst;
    logic next_uses_rs1;
    logic next_uses_rs2;
    logic next_uses_rsd;
    logic op_valid;
    logic data_hazard;

    logic [2:0] func3 = inst[14:12];
    logic [6:0] func7 = inst[31:25];
    logic inv = func7[5]; // denotes 'sub' or arith-shift
    logic ext = inst[31];
    logic [4:0] rs2 = inst[24:20];
    logic [4:0] rs1 = inst[19:15];
    logic [4:0] rsd = inst[11:7];

    logic next_stg_ready;
    assign next_stg_ready = alu_ready;
    assign inst_ready = next_stg_ready & !rst & (!inst_valid | !data_hazard);

    logic [`XLEN-1:0] regfile[31:1];
    logic [1:0] reg_writes_pending[31:1];

    logic [`XLEN-1:0] rs1_data;
    assign rs1_data = (rs1 != 0) ? regfile[rs1] : 0;
    logic [`XLEN-1:0] rs2_data;
    assign rs2_data = (rs2 != 0) ? regfile[rs2] : 0;
    // hazard detection

    assign rs1_writes_pending = reg_writes_pending[rs1];
    assign rs2_writes_pending = reg_writes_pending[rs2];
    assign rs1_data_hazard = (next_uses_rs1 & (rs1 != 0) & (rs1_writes_pending != 0));
    assign rs2_data_hazard = (next_uses_rs2 & (rs2 != 0) & (rs2_writes_pending != 0));

    logic dest_may_have_hazard;
    assign dest_may_have_hazard = next_uses_rsd & (reg_writes_pending[rsd] != 0) & (rst != 0);
    // Only assume RAW hazards are an issue. Side effects from others are handled by WB unit.
    logic wb_dest_hazard;
    assign wb_dest_hazard = dest_may_have_hazard;

    logic dest_hazard;
    assign dest_hazard =  wb_dest_hazard;

    assign data_hazard = rs1_data_hazard || rs2_data_hazard || dest_hazard;

    logic is_comp;
    assign is_comp = (inst[1:0] != 2'b11);
    logic len_valid;
    assign len_valid = (inst[4:2] != 3'b111) && (!is_comp || (`IALIGN == 16));

    e_rvop op;
    e_rvf3_alu func3_alu;
    e_rvf3_mem func3_mem;
    e_rvf3_br  func3_br;
    e_rvf3_sys func3_sys;
    
    always_comb begin
        op = `TYPECAST(e_rvop, (inst[6:2]));
        func3_alu = `TYPECAST(e_rvf3_alu, (inst[14:12]));
        func3_mem = `TYPECAST(e_rvf3_mem, (inst[14:12]));
        func3_br  = `TYPECAST(e_rvf3_br, (inst[14:12]));
        func3_sys = `TYPECAST(e_rvf3_sys, (inst[14:12]));
    end
   
    logic [32-1:0] imm_i_lo;
    assign imm_i_lo = { {21{ext}}, inst[30:25], inst[24:21], inst[20]};
    logic [32-1:0] imm_s_lo;
    assign imm_s_lo = { {21{ext}}, inst[30:25], inst[11:8], inst[7]};
    logic [32-1:0] imm_b_lo;
    assign imm_b_lo = { {20{ext}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    logic [32-1:0] imm_u_lo;
    assign imm_u_lo = { inst[31:12], 12'b0};
    logic [32-1:0] imm_j_lo;
    assign imm_j_lo = { {12{ext}}, inst[19:12], inst[20], inst[30:25], inst[24:21], 1'b0};
    logic [`CSRLEN-1:0] imm_csr;
    assign imm_csr = inst[31:20];
    logic [`XLEN-1:0] imm_csr_data;
    logic [`XLEN-6:0] imm_csr_hi = 0;
    assign imm_csr_data = {imm_csr_hi, inst[19:15]};

    initial begin
        for (integer i=1; i < 32; i++) begin
            regfile[i] = 0;
            reg_writes_pending[i] = 0;
        end
    end

    assign alu_inst_id = next_inst_id;
    assign alu_br_predicted = next_br_predicted;
    assign alu_arg1 = next_arg1;
    assign alu_arg2 = next_arg2;
    assign alu_aluop = next_alu_op;
    assign alu_br_op = next_br_op;
    assign alu_memop = next_mem_op;
    assign alu_dst = next_dst;
    assign alu_size = next_size;
    assign alu_signed = next_signed;
    assign alu_payload = next_payload;
    assign alu_payload_kind = next_payload_kind;
    assign alu_valid = next_inst_valid;

    logic inst_dispatching;
    assign inst_dispatching = (alu_valid & alu_ready);
    logic write_dispatching;
    assign write_dispatching = inst_dispatching & next_uses_rsd & (rsd != 0);

    logic next_inst_valid;
    assign next_inst_valid = len_valid & op_valid & !rst & inst_valid & !data_hazard;
    always_ff @(posedge clk) begin
        if (rst) begin
            for (integer i=1; i < 32; i++) begin
                regfile[i] <= 0;
                reg_writes_pending[i] <= 0;
            end
        end
        else begin
`ifndef SYNTHESIS
            if (inst_valid  & inst_ready & !op_valid)
                $display("Illegal OP! Time=%0t, Inst: %0h, PC: %0h", $time, inst, inst_pc);
`endif

            if (write_dispatching) begin
                assert(reg_writes_pending[rsd] != 2'b11);
                reg_writes_pending[rsd] <= reg_writes_pending[rsd] + 1;
            end
            if (wb_valid && (wb_reg != 0)) begin
                assert(reg_writes_pending[wb_reg] != 0);
                regfile[wb_reg] <= wb_val;
                reg_writes_pending[wb_reg] <= reg_writes_pending[wb_reg] - 1;
            end

            // simultaneous inc and dec hazard counter to same register
            if (write_dispatching & (wb_valid & wb_reg != 0 & wb_reg == rsd)) begin
                reg_writes_pending[wb_reg] <= reg_writes_pending[wb_reg];
            end
        end
    end


    always_comb begin 
        // Sane defaults with no side effects
        op_valid = 0;
        next_dst = 0;
        next_mem_op = MEMOP_NONE;
        next_alu_op = ALU_ADD;
        next_br_op = BROP_NEVER;
        next_size = MEMSZ_1B;
        next_arg1 = 0;
        next_arg2 = 0;
        next_payload = 0;
        next_payload_kind = PAYLOAD_NONE;
        next_uses_rs1 = 0;
        next_uses_rs2 = 0;
        next_uses_rsd = 0;
        next_signed = 0;
        next_inst_id = inst_id;
        next_br_predicted = inst_br_predicted;
        // csr_r = 0;
        // csr_w = 0;
        // csr_addr = 0;
        // csr_data = 0;
        // csr_wmask = 0;

        case(op)
        RV_OP_IMM: begin
            op_valid = 1;
            next_arg1 = rs1_data; 
            next_uses_rs1 = 1;
            next_arg2 = { imm_i_lo};
            next_dst = rsd;
            next_uses_rsd = 1;
            case (func3_alu)
                RVF3_ADD: next_alu_op = ALU_ADD; // Note no subtract here
                RVF3_SLT: next_alu_op = ALU_CMP_LT;
                RVF3_SLTU: next_alu_op = ALU_CMP_LTU;
                RVF3_XOR: next_alu_op = ALU_XOR;
                RVF3_OR: next_alu_op = ALU_OR;
                RVF3_AND: next_alu_op = ALU_AND;
                RVF3_SL: next_alu_op = ALU_SH_L;
                RVF3_SR: next_alu_op = (inv ? ALU_SH_RA : ALU_SH_RL);
            endcase
        end
        RV_OP: begin
            op_valid = (func7[4:0] == 5'b00000) && (func7[6] == 0);
            next_arg1 = rs1_data;
            next_arg2 = rs2_data;
            next_dst = rsd;
            next_uses_rs1 = 1;
            next_uses_rs2 = 1;
            next_uses_rsd = 1;
            case (func3_alu)
                RVF3_ADD: next_alu_op = (inv ? ALU_SUB : ALU_ADD);
                RVF3_SLT: next_alu_op = ALU_CMP_LT;
                RVF3_SLTU: next_alu_op = ALU_CMP_LTU;
                RVF3_XOR: next_alu_op = ALU_XOR;
                RVF3_OR: next_alu_op = ALU_OR;
                RVF3_AND: next_alu_op = ALU_AND;
                RVF3_SL: next_alu_op = ALU_SH_L;
                RVF3_SR: next_alu_op = (inv ? ALU_SH_RA : ALU_SH_RL);
            endcase
        end
        RV_LUI: begin
            op_valid = 1;
            next_arg1 = 0;
            next_arg2 = imm_u_lo;
            next_dst = rsd;
            next_uses_rsd = 1;
            next_alu_op = ALU_ADD;
        end
        RV_AUIPC: begin
            op_valid = 1;
            next_arg1 = inst_pc;
            next_arg2 = imm_u_lo;
            next_dst = rsd;
            next_uses_rsd = 1;
            next_alu_op = ALU_ADD;
        end
        RV_STORE: begin
            // sign doesn't make sense for stores, rv64 unsupported
            op_valid = (func3[2] == 0) & (func3 != 3'b011);
            next_arg1 = rs1_data;
            next_uses_rs1 = 1;
            next_arg2 = imm_s_lo;
            next_dst = 0;
            next_alu_op = ALU_ADD; // Use ALU for addr calc
            next_payload = rs2_data;
            next_payload_kind = PAYLOAD_STOREDATA;
            next_uses_rs2 = 1;

            next_mem_op = MEMOP_STORE_MEM;
            case (func3_mem)
                RVF3_BYTE: next_size = MEMSZ_1B;
                RVF3_HALF: next_size = MEMSZ_2B;
                RVF3_WORD: next_size = MEMSZ_4B;
                default: begin 
                    assert(op_valid == 0);
                end
            endcase
        end
        RV_LOAD: begin
            next_arg1 = rs1_data;
            next_uses_rs1 = 1;
            next_arg2 = imm_i_lo;
            next_dst = rsd;
            next_uses_rsd = 1;
            next_alu_op = ALU_ADD; // Use ALU for addr calc

            next_mem_op = MEMOP_LOAD_MEM;
            case (func3_mem)
                RVF3_BYTE: begin
                    next_size = MEMSZ_1B;
                    next_signed = 1;
                    op_valid = 1;
                end
                RVF3_UBYTE: begin
                    next_size = MEMSZ_1B;
                    next_signed = 0;
                    op_valid = 1;
                end
                RVF3_HALF: begin
                    next_size = MEMSZ_2B;
                    next_signed = 1;
                    op_valid = 1;
                end
                RVF3_UHALF: begin
                    next_size = MEMSZ_2B;
                    next_signed = 0;
                    op_valid = 1;
                end
                RVF3_WORD: begin
                    next_size = MEMSZ_4B;
                    next_signed = 0;
                    op_valid = 1;
                end
                default: begin
                    op_valid = 0;
                end
            endcase
        end
        RV_JAL: begin
            op_valid = 1;
            next_arg1 = inst_pc;
            next_arg2 = imm_j_lo;
            next_dst = rsd;
            next_uses_rsd = 1;
            next_alu_op = ALU_ADD;
            next_br_op = BROP_ALWAYS;
        end
        RV_JALR: begin
            op_valid = (func3 == 0);
            next_arg1 = rs1_data;
            next_uses_rs1 = 1;
            next_arg2 = imm_i_lo;
            next_dst = rsd;
            next_uses_rsd = 1;
            next_alu_op = ALU_ADD;
            next_br_op = BROP_ALWAYS;
        end
        RV_BRANCH: begin
            op_valid = 1;
            next_arg1 = rs1_data;
            next_arg2 = rs2_data;
            next_uses_rs1 = 1;
            next_uses_rs2 = 1;
            next_payload = imm_b_lo;
            next_payload_kind = PAYLOAD_BRANCHOFFSET;
            case (func3_br)
                RVF3_BEQ:  next_br_op = BROP_EQ;
                RVF3_BNE:  next_br_op = BROP_NE;
                RVF3_BLT:  next_br_op = BROP_LT;
                RVF3_BGE:  next_br_op = BROP_GE;
                RVF3_BLTU: next_br_op = BROP_LTU;
                RVF3_BGEU: next_br_op = BROP_GEU;
                default: op_valid = 0;
            endcase
        end
`ifdef NEVER
        // TODO: rework all of this into ldst
        RV_SYSTEM: begin
            op_valid = 1;
            // hack: all CSRs and breaks are nops!
            if (func3[1:0] != 0) begin
                assert(!csr_fence); // not implemented yet :(
                op_valid = csr_legal;
                csr_addr = imm_csr;
                next_uses_rsd = 1;
                case (func3_sys)
                    RVF3_CSRRW: begin
                        csr_wmask = -1;
                        csr_data = rs1_data;
                        csr_r = rsd != 0;
                        csr_w = 1;
                        next_uses_rs1 = 1;
                    end
                    RVF3_CSRRS, RVF3_CSRRC: begin
                        csr_wmask = rs1_data;
                        csr_data = (func3_sys == RVF3_CSRRC) ? 0 : -1;
                        csr_r = 1;
                        csr_w = rs1 != 0;
                        next_uses_rs1 = 1;
                    end
                    RVF3_CSRRWI: begin
                        csr_wmask = -1;
                        csr_data = imm_csr_data;
                        csr_r = rsd != 0;
                        csr_w = 1;
                    end
                    RVF3_CSRRSI, RVF3_CSRRCI: begin
                        csr_wmask = imm_csr_data;
                        csr_data = (func3_sys == RVF3_CSRRCI) ? 0 : -1;
                        csr_r = 1;
                        csr_w = imm_csr_data != 0;
                    end

                    default: op_valid = 0;
                endcase
            end else begin
`ifndef SYNTHESIS
            if (inst_valid)
                $display("Unrecognized SYSTEM inst (NOP'd)! Time=%0t, Inst: %0h, PC: %0h", $time, inst, inst_pc);
`endif
            end
        end
`endif
        default: begin
            // What is this?
            op_valid = 0;
        end
    endcase
    end

endmodule

