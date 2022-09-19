
`include "config.svi"

module mr_wb(
    input clk, rst,

    // Inst alloc logic
    output inst_buffer_full,
    input inst_in,
    input [`XLEN-1:0] inst_pc,
    output logic [`INSTID_BITS-1:0] next_inst_id, // only valid if not full

    // Insts to retire from pipeline
    input ret_valid,
    input [`INSTID_BITS-1:0] ret_id,
    input [`REGSEL_BITS-1:0] ret_dst,
    input [`XLEN-1:0] ret_data,
    input [`XLEN-1:0] ret_payload,
    input e_payload ret_payload_kind,
    input is_jump, // in jumps, data is dst addr instead. WB knows the PC for JAL and untaken branches.
    input jump_taken, // if not taken, dst is nextpc
    input jump_predicted, // if doesn't match taken, need a pipe flush
    // todo: exceptions, explicit flush
    output is_spectulating, // if true, ldst must stall.

    // WB to regfile (no backpressure)
    output reg_wb_valid,
    output [`REGSEL_BITS-1:0] reg_wb_dst,
    output [`XLEN-1:0] reg_wb_data,

    // Reset pipe for flush or jump.
    //  - Each flush *must* include an unpredicted jump so we know where to resume
    //  - Predicted jumps don't need this
    //  - For pure mispredicts, we replay the inst and use the resolved predictions
    output flush_pipe_to_pc,
    output [`XLEN-1:0] flush_pc
    // TODO: hookups to relevant CSRs and debug signals
);

logic [`RETQUEUE_SIZE-1:0] inst_valid;
logic [`RETQUEUE_SIZE-1:0][`IMAXLEN-1:0] inst_pcs;

logic ret_is_ok = (jump_taken == jump_predicted); // Add exception logic later
assign is_spectulating = !ret_is_ok;

always @(posedge clk) if (rst) begin
    for (integer i = 0; i < `RETQUEUE_SIZE; i++) begin
        // The rest can be garbage
        inst_valid[i] <= 0;
    end
end else if (ret_valid && !ret_is_ok) begin
    // Start pipe flush, takes precedence over everything else.
    if (jump_taken != jump_predicted) begin
        flush_pipe_to_pc <= 1;
        if (is_jump) begin
            flush_pc <= ret_data;
        end else if (!jump_taken) begin
            flush_pc <= inst_pcs[ret_id] + 4;
        end else begin
            assert(ret_payload_kind == PAYLOAD_BRANCHOFFSET);
            flush_pc <= inst_pcs[ret_id] + ret_payload;
        end
    end else begin
        assert(0); // How did we get here?
    end
    for (integer i = 0; i < `RETQUEUE_SIZE; i++) begin
        // The rest can be garbage
        inst_valid[i] <= 0;
    end
end else begin
    assert(!(inst_in && ret_valid) || (next_inst_id != ret_id));
    if (inst_in) begin
        assert(!inst_buffer_full);
        inst_valid[next_inst_id] <= 1;
        inst_pcs[next_inst_id] <= inst_pc;
    end
    if (ret_valid) begin
        assert(inst_valid[ret_id]);
        inst_valid[ret_id] <= 0;
    end
end

assign reg_wb_valid = (ret_valid && ret_is_ok);
assign reg_wb_dst = ret_dst;
assign reg_wb_data = (is_jump ? (inst_pcs[ret_id] + 4) : ret_data);

always_comb begin
    next_inst_id = 0;
    for (integer i = 0; i < `RETQUEUE_SIZE; i++) begin
        if (!inst_valid[i]) begin
            next_inst_id = `INSTID_BITS'(i);
            break;
        end
    end
end
assign inst_buffer_full = &inst_valid;

endmodule
