`include "rtl/config.svi"

module mr_alu (
    input clk, rst,

    // From ID
    input [`XLEN-1:0] id_arg1,
    input [`XLEN-1:0] id_arg2,
    input e_aluops id_aluop,
    input [`REGSEL_BITS-1:0] id_dest_reg,
    input id_dst_pc,

    input [`MEM_OP_BITS-1:0] id_memop,
    input [`MEM_SZ_BITS-1:0] id_size,
    input id_signed,
    input [`XLEN-1:0] id_payload,

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
    output [`XLEN-1:0] ls_payload
);

logic [`XLEN-1:0] next_dest;

assign id_ready = ls_ready; // We always take one clock... for now.

always @(posedge clk) begin
    if (rst) begin 
        ls_valid <= 0;
    end else if (ls_ready) begin
        ls_dest <= next_dest;
        ls_valid <= id_valid;
        // passthru
        ls_dest_reg <= id_dest_reg;
        ls_memop <= id_memop;
        ls_size <= id_size;
        ls_signed <= id_signed;
        ls_payload <= id_payload;
    end else begin
        ls_valid <= 0;
    end
end

always_comb begin 
    unique case (id_aluop)
        ALU_ADD: next_dest = id_arg1 + id_arg2;
        ALU_SUB: next_dest = id_arg1 - id_arg2;
        ALU_AND: next_dest = id_arg1 & id_arg2;
        ALU_OR:  next_dest = id_arg1 | id_arg2;
        ALU_XOR: next_dest = id_arg1 ^ id_arg2;
        ALU_SH_L: next_dest = id_arg1 << id_arg2;
        ALU_SH_RA: next_dest = id_arg1 >>> id_arg2;
        ALU_SH_RL: next_dest = id_arg1 >> id_arg2;
        ALU_CMP_LTU: begin
           next_dest[`XLEN-1:1] = 0;
           next_dest[0] = (id_arg1 < id_arg2);
        end
        ALU_CMP_LT: begin
           next_dest[`XLEN-1:1] = 0;
           next_dest[0] = ($signed(id_arg1) < $signed(id_arg2));
        end
        default: next_dest = 0;
    endcase
end


    
endmodule