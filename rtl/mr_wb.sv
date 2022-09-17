
`include "config.svi"

module mr_wb(
    input clk, rst,


    // Inst alloc logic
    output inst_buffer_full,
    input inst_in,
    input [`IMAXLEN-1:0] inst_pc,
    output [`INSTID_BITS-1:0] next_inst_id // only valid if not full
);

logic [`RETQUEUE_SIZE-1:0] inst_valid;
logic [`RETQUEUE_SIZE-1:0][`IMAXLEN-1:0] inst_pcs;

always @(posedge clk) if (rst) begin
    for (integer i = 0; i < `RETQUEUE_SIZE; i++) begin
        // The rest can be garbage
        inst_valid[i] <= 0;
    end
end else if (inst_in) begin
    assert(!inst_buffer_full);
    inst_valid[next_inst_id] <= 1;
    inst_pcs[next_inst_id] <= inst_pc;
end

always_comb begin
    next_inst_id = 0;
    for (integer i = 0; i < `RETQUEUE_SIZE; i++) begin
        if (!inst_valid[i]) begin
            next_inst_id = i;
            break;
        end
    end
end
assign inst_buffer_full = &inst_valid;

endmodule