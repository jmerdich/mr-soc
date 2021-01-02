`include "rtl/config.svi"

module mr_id (
    input clk, rst,

    // From ifetch
    input [`IMAXLEN-1:0] inst,
    input [`XLEN-1:0] inst_pc,
    output inst_ready,
    input inst_valid,

    // To following stages
    output reg alu_valid,
    input alu_ready,
    output reg [`XLEN-1:0] alu_arg1,
    output reg [`XLEN-1:0] alu_arg2,
    output reg [`REGSEL_BITS-1:0] alu_dst,
    output reg [`BR_OP_BITS-1:0] alu_br_op,
    output reg [`ALU_OP_BITS-1:0] alu_aluop,

    output [`MEM_OP_BITS-1:0] alu_memop,
    output [`MEM_SZ_BITS-1:0] alu_size,
    output alu_signed, // ignored on store
    output [`XLEN-1:0] alu_payload,
    output [`XLEN-1:0] alu_payload2,

    // From WB
    input wb_valid,
    input [`REGSEL_BITS-1:0] wb_reg,
    input [`XLEN-1:0] wb_val
);

    assign inst_ready = alu_ready;

    logic [31:1][`XLEN-1:0] regfile;

    logic is_comp = (inst[1:0] != 2'b11);
    logic len_valid = (inst[4:2] != 3'b111) && (!is_comp || (`IALIGN == 16));

    logic [4:0] op = inst[6:2];
    logic [2:0] func3 = inst[14:12];
    logic [6:0] func7 = inst[31:25];
    logic inv = func7[5]; // denotes 'sub' or arith-shift
    logic ext = inst[31];
    logic [4:0] rs2 = inst[24:20];
    logic [4:0] rs1 = inst[19:15];
    logic [4:0] rsd = inst[11:7];

    logic [32-1:0] imm_i_lo = { {21{ext}}, inst[30:25], inst[24:21], inst[20]};
    logic [32-1:0] imm_s_lo = { {21{ext}}, inst[30:25], inst[11:8], inst[7]};
    logic [32-1:0] imm_b_lo = { {20{ext}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    logic [32-1:0] imm_u_lo = { inst[31:12], 12'b0};
    logic [32-1:0] imm_j_lo = { {12{ext}}, inst[19:12], inst[20], inst[30:25], inst[24:21], 1'b0};

    initial begin
        regfile = 0;
    end

    always_ff @(posedge clk) begin
        alu_valid <= len_valid & op_valid & !rst & inst_valid;
        alu_arg1 <= next_arg1;
        alu_arg2 <= next_arg2;
        alu_aluop <= next_alu_op;
        alu_dst <= next_dst;
        alu_size <= next_size;
        alu_signed <= next_signed;
        alu_payload <= next_payload;
        alu_payload2 <= next_payload2;
        if (wb_valid) begin
            regfile[wb_reg] <= wb_val;
        end
    end

    logic [`XLEN-1:0] next_arg1;
    logic [`XLEN-1:0] next_arg2;
    logic [`XLEN-1:0] next_payload;
    logic [`XLEN-1:0] next_payload2;
    logic [`ALU_OP_BITS-1:0] next_alu_op;
    logic [`MEM_SZ_BITS-1:0] next_size;
    logic                    next_signed;
    logic [`MEM_OP_BITS-1:0] next_mem_op;
    logic [`BR_OP_BITS-1:0] next_br_op;
    logic [`REGSEL_BITS-1:0] next_dst;
    logic op_valid;
    always_comb begin 
        // Sane defaults with no side effects
        op_valid = 0;
        next_dst = 0;
        next_mem_op = MEMOP_NONE;
        next_alu_op = ALU_ADD;
        next_br_op = BROP_NEVER;
        next_arg1 = 0;
        next_arg2 = 0;
        next_payload = 0;
        next_payload2 = 0;

        case(op)
        RV_OP_IMM: begin
            op_valid = 1;
            next_arg1 = regfile[rs1];
            next_arg2 = { imm_i_lo};
            next_dst = rsd;
            case (func3)
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
            next_arg1 = regfile[rs1];
            next_arg2 = regfile[rs2];
            next_dst = rsd;
            case (func3)
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
            next_alu_op = ALU_ADD;
        end
        RV_AUIPC: begin
            op_valid = 1;
            next_arg1 = inst_pc;
            next_arg2 = imm_u_lo;
            next_dst = rsd;
            next_alu_op = ALU_ADD;
        end
        RV_STORE: begin
            // sign doesn't make sense for stores, rv64 unsupported
            op_valid = (func3[2] == 0) & (func3 != 3'b011);
            next_arg1 = regfile[rs1];
            next_arg2 = imm_s_lo;
            next_dst = 0;
            next_alu_op = ALU_ADD; // Use ALU for addr calc
            next_payload = regfile[rs2];

            next_mem_op = MEMOP_STORE;
            case (func3)
                RVF3_BYTE: next_size = MEMSZ_1B;
                RVF3_HALF: next_size = MEMSZ_2B;
                RVF3_WORD: next_size = MEMSZ_4B;
                default: begin
                    next_size = 2'bxx;
                    assert(op_valid == 0);
                end
            endcase
        end
        RV_LOAD: begin
            next_arg1 = regfile[rs1];
            next_arg2 = imm_s_lo;
            next_dst = rsd;
            next_alu_op = ALU_ADD; // Use ALU for addr calc
            next_payload = regfile[rs2];

            next_mem_op = MEMOP_STORE;
            case (func3)
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
                default: op_valid = 0;
            endcase
        end
        RV_JAL: begin
            op_valid = 1;
            next_arg1 = inst_pc;
            next_arg2 = imm_j_lo;
            next_dst = rsd;
            next_alu_op = ALU_ADD;
            next_br_op = BROP_ALWAYS;
            next_payload = inst_pc;
        end
        RV_JALR: begin
            op_valid = (func3 == 0);
            next_arg1 = regfile[rs1];
            next_arg2 = imm_i_lo;
            next_dst = rsd;
            next_alu_op = ALU_ADD;
            next_br_op = BROP_ALWAYS;
            next_payload = inst_pc;
        end
        RV_BRANCH: begin
            op_valid = 1;
            next_arg1 = inst_pc;
            next_arg2 = imm_b_lo;
            next_alu_op = ALU_ADD;
            next_payload = regfile[rs1];
            next_payload2 = regfile[rs2];
            case (func3)
                RVF3_BEQ:  next_br_op = BROP_EQ;
                RVF3_BNE:  next_br_op = BROP_NE;
                RVF3_BLT:  next_br_op = BROP_LT;
                RVF3_BGE:  next_br_op = BROP_GE;
                RVF3_BLTU: next_br_op = BROP_LTU;
                RVF3_BGEU: next_br_op = BROP_GEU;
                default: op_valid = 0;
            endcase
        end
        default: begin
            // What is this?
            op_valid = 0;
        end
    endcase
    end

endmodule