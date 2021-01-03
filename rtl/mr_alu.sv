`include "rtl/config.svi"

module mr_alu (
    input clk, rst,

    // From ID
    input [`XLEN-1:0] id_arg1,
    input [`XLEN-1:0] id_arg2,
    input e_aluops id_aluop,
    input [`REGSEL_BITS-1:0] id_dest_reg,
    input [`BR_OP_BITS-1:0] id_br_op,

    input [`MEM_OP_BITS-1:0] id_memop,
    input [`MEM_SZ_BITS-1:0] id_size,
    input id_signed,
    input [`XLEN-1:0] id_payload,
    input [`XLEN-1:0] id_payload2,

    input id_valid,
    output id_ready,

    // To next stage
    output reg ls_valid,
    input ls_ready,
    output reg [`XLEN-1:0] ls_dest,
    output reg [`REGSEL_BITS-1:0] ls_dest_reg,

    output [`MEM_OP_BITS-1:0] ls_memop,
    output [`MEM_SZ_BITS-1:0] ls_size,
    output ls_signed,
    output [`XLEN-1:0] ls_payload,

    // Branching
    output reg wb_pc_valid,
    output reg [`XLEN-1:0] wb_pc,
    output reg jmp_done
);

logic [`XLEN-1:0] next_dest;
logic [`XLEN-1:0] alu_res;
assign next_dest = (id_br_op == BROP_ALWAYS) ? id_payload + 4 : id_payload;
logic             take_branch;

assign id_ready = ls_ready; // We always take one clock... for now.

always @(posedge clk) begin
    if (rst) begin 
        ls_valid <= 0;
        wb_pc_valid <= 0;
        jmp_done <= 0;
    end else if (ls_ready & id_valid) begin
        ls_dest <= next_dest;
        ls_valid <= id_valid;
        // passthru
        ls_dest_reg <= id_dest_reg;
        ls_memop <= id_memop;
        ls_size <= id_size;
        ls_signed <= id_signed;
        ls_payload <= id_payload;

        wb_pc <= alu_res;
        wb_pc_valid <= take_branch;
        jmp_done <= (id_br_op != BROP_NEVER);
    end else begin
        ls_valid <= 0;
        wb_pc_valid <= 0;
        jmp_done <= 0;
    end
end

always_comb begin 
    unique case (id_aluop)
        ALU_ADD: alu_res = id_arg1 + id_arg2;
        ALU_SUB: alu_res = id_arg1 - id_arg2;
        ALU_AND: alu_res = id_arg1 & id_arg2;
        ALU_OR:  alu_res = id_arg1 | id_arg2;
        ALU_XOR: alu_res = id_arg1 ^ id_arg2;
        ALU_SH_L: alu_res = id_arg1 << id_arg2;
        ALU_SH_RA: alu_res = id_arg1 >>> id_arg2;
        ALU_SH_RL: alu_res = id_arg1 >> id_arg2;
        ALU_CMP_LTU: begin
           alu_res[`XLEN-1:1] = 0;
           alu_res[0] = (id_arg1 < id_arg2);
        end
        ALU_CMP_LT: begin
           alu_res[`XLEN-1:1] = 0;
           alu_res[0] = ($signed(id_arg1) < $signed(id_arg2));
        end
        default: alu_res = 0;
    endcase
end

always_comb case(id_br_op)
    BROP_NEVER: take_branch = 0;
    BROP_ALWAYS: take_branch = 1;
    BROP_EQ: take_branch = (id_payload == id_payload2);
    BROP_NE: take_branch = (id_payload != id_payload2);
    BROP_LT: take_branch = ($signed(id_payload) < $signed(id_payload2));
    BROP_LTU: take_branch = (id_payload < id_payload2);
    BROP_GE: take_branch = ($signed(id_payload) >= $signed(id_payload2));
    BROP_GEU: take_branch = (id_payload >= id_payload2);
endcase


    
endmodule