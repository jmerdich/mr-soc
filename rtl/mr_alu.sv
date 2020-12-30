`include "rtl/config.svi"

module mr_alu (
    input clk, rst,
    input [`XLEN-1:0] arg1,
    input [`XLEN-1:0] arg2,
    output reg [`XLEN-1:0] dest,
    input e_aluops op
);

logic [`XLEN-1:0] next_dest;

always @(posedge clk) begin
    dest <= next_dest;
end

always_comb begin 
    unique case (op)
        ALU_ADD: next_dest = arg1 + arg2;
        ALU_SUB: next_dest = arg1 - arg2;
        ALU_AND: next_dest = arg1 & arg2;
        ALU_OR:  next_dest = arg1 | arg2;
        ALU_XOR: next_dest = arg1 ^ arg2;
        ALU_SH_L: next_dest = arg1 << arg2;
        ALU_SH_RA: next_dest = arg1 >>> arg2;
        ALU_SH_RL: next_dest = arg1 >> arg2;
        ALU_CMP_LTU: begin
           next_dest[`XLEN-1:1] = 0;
           next_dest[0] = (arg1 < arg2);
        end
        ALU_CMP_LT: begin
           next_dest[`XLEN-1:1] = 0;
           next_dest[0] = ($signed(arg1) < $signed(arg2));
        end
        default: next_dest = 0;
    endcase
end


    
endmodule