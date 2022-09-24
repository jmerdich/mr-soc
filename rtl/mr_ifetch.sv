`include "rtl/config.svi"

// TODO:
//  - handle IALIGN==16 and XLEN==64
//  - start next req before ID ack's   
//  - handle jump hazards

module mr_ifetch
    #(
    parameter RESET_VEC = 0
    ) 
    (
    input clk, rst,

    // Mem
    output reg [`XLEN-1:`XLEN_GRAN] adr_o,
    // unpop: dat_o
    input [`XLEN-1:0] dat_i,
    // unpop: we_o
    // unpop: sel_o
    output reg stb_o,
    input ack_i,
    input err_i,
    input stall_i,
    output reg cyc_o,

    // To ID
    output reg [`IMAXLEN-1:0] inst,
    output reg [`XLEN-1:0] inst_pc,
    output reg [`INSTID_BITS-1:0] inst_id,
    output reg inst_valid,
    output inst_br_predicted,
    input id_ready,

    // From WB (pipe flush/jump)
    input [`XLEN-1:0] wb_pc,
    input wb_pc_valid,

    // To WB (retqueue alloc)
    input inst_buffer_full,
    output reg inst_alloc,
    output reg [`XLEN-1:0] inst_alloc_pc,
    input [`INSTID_BITS-1:0] next_inst_id // only valid if not full
);
    assign inst_br_predicted = 0; // world's worst branch predictor!
    assign inst_id = next_inst_id;

    reg [`XLEN-1:0] pc;
    initial begin
        pc = RESET_VEC;
    end

    logic dispatching;
    assign dispatching = !inst_buffer_full & id_ready & inst_valid;

    assign inst_alloc = dispatching;
    assign inst_alloc_pc = inst_pc;

    logic [`XLEN-1:0] pc_offset;
    assign pc_offset = 4;

    logic [`XLEN-1:0] nextpc;
    assign nextpc = pc + pc_offset;

    logic addr_changed; // true if we need to discard the current req
    always_ff @(posedge clk) begin
        addr_changed <= addr_changed & !stb_o;
        if (rst) begin
            pc <= RESET_VEC;
            addr_changed <= 0;
        end else if (wb_pc_valid) begin
            pc <= wb_pc;
            addr_changed <= cyc_o;
        end else if (dispatching)
            pc <= nextpc;
        else
            pc <= pc;
    end

`ifdef HAVE_DISASS
    string inst_disass;
    initial begin
        inst_disass = "";
    end
`endif

    logic reset;
    initial reset = 1;
    always @(posedge clk) reset <= reset & rst;

    always_ff @(posedge clk) begin
        inst <= inst;
        inst_pc <= inst_pc;
        if (reset) begin
            inst_valid <= 0;
        end else if (ack_i & (!stb_o | !stall_i)) begin
            inst_valid <= !addr_changed & !inst_buffer_full;
            inst_pc <= pc;
            inst <= dat_i;
`ifdef HAVE_DISASS
            inst_disass <= rv_disass(dat_i);
`endif
        end else if (id_ready) begin
            inst_valid <= 0;
        end else begin
            inst_valid <= inst_valid;
        end
    end

    initial cyc_o = 0;
    initial stb_o = 0;
    always_ff @(posedge clk) begin
        if (reset | err_i) begin
            // Reset or bus error
            // TODO: bus fault trap logic. For now, bus error == nasal demons.
            assert(!err_i);
            cyc_o <= 0;
            stb_o <= 0;
        end else if (stb_o) begin
            // We have an active request pending, the recp hasn't latched yet

            // de-assert once un-stalled
            if (!stall_i)
                stb_o <= 0;

            // handle ridiculously fast acks
            if (!stall_i & ack_i)
                cyc_o <= 0;
        end else if (cyc_o) begin
            // Waiting for response

            if (ack_i)
                cyc_o <= 0;
        end else begin
            // Idle

            if ((inst_pc != pc) || !inst_valid) begin
                // New memory req!
                cyc_o <= 1;
                stb_o <= 1;
                adr_o <= wb_pc_valid ? wb_pc[`XLEN-1:`XLEN_GRAN] : pc[`XLEN-1:`XLEN_GRAN];
            end
        end
    end

endmodule

