
`include "config.svi"

module mr_ldst(
    input clk, rst,

    // From prev
    input [`MEM_OP_BITS-1:0] ex_op_i,
    input [`MEM_SZ_BITS-1:0] ex_size_i,
    input ex_signed_i,
    input [`XLEN-1:0] ex_addr_i,
    input [`XLEN-1:0] ex_payload_i,
    input [`REGSEL_BITS-1:0] ex_dst_reg_i,
    input ex_valid_i,
    output ex_ready_o,

    // To WB
    output reg wb_write,
    output reg [`XLEN-1:0] wb_payload_o,
    output reg [`REGSEL_BITS-1:0] wb_dst_reg_o,
    // assume no stall for WB stage

    // Wishbone master
    output reg [`XLEN-1:`XLEN_GRAN] addr_o,
    output reg we_o,
    output reg [`XLEN/8-1:0] sel_o,
    output reg [`XLEN-1:0] dat_o,
    output reg stb_o,
    output reg cyc_o,

    input ack_i,
    input err_i,
    input stall_i,
    input [`XLEN-1:0] dat_i
);

// Metadata on active transaction
logic [`MEM_SZ_BITS-1:0] size_pending;
logic signed_pending;
logic [`REGSEL_BITS-1:0] dst_reg_pending;

initial cyc_o = 0;
initial stb_o = 0;
always_ff @(posedge clk) begin
    if (reset | err_i) begin
        // Reset or bus error
        // TODO: bus fault trap logic. For now, bus error == nasal demons.
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

        if (ex_valid_i && (ex_op_i != MEMOP_NONE)) begin
            // New memory req!
            cyc_o <= 1;
            stb_o <= 1;
        end
    end
end

assign ex_ready_o = !cyc_o;

wire [`XLEN/8-1:0] sel = 4'b1111; // TODO: handle non-dwords
wire [`XLEN-1:0] shifted_dat_i = dat_i; // TODO: shifts and sign-ext

// Data sending logic
always_ff @(posedge clk) begin
    if (!reset & !cyc_o & ex_valid_i & ex_op_i != MEMOP_NONE) begin
        addr_o <= ex_addr_i[`XLEN-1:`XLEN_GRAN];
        we_o <= (ex_op_i == MEMOP_STORE);
        sel_o <= sel;
        dat_o <= ex_payload_i;
        dst_reg_pending <= ex_dst_reg_i;
    end
end


// Handle returning the data when the r/w clears
always_ff @(posedge clk) begin
    if (reset) begin 
        wb_write <= 0;
    end else if (ack_i & (!stb_o | !stall_i)) begin
        wb_write <= 1;
        wb_payload_o <= shifted_dat_i;
        wb_dst_reg_o <= dst_reg_pending;
    end else if (!cyc_o & ex_valid_i & (ex_op_i == MEMOP_NONE)) begin
        wb_write <= 1;
        wb_payload_o <= ex_addr_i;
        wb_dst_reg_o <= ex_dst_reg_i;
    end else begin
        wb_write <= 0;
    end
end


// Formal wants a initial reset. 
logic reset;
initial reset = 1;
always @(posedge clk) reset <= reset & rst;

`ifdef FORMAL
    wire [(4-1):0]	f_nreqs, f_nacks, f_outstanding;
    fwb_master tester(
        .i_clk(clk), .i_reset(reset),
		// The Wishbone bus
		.i_wb_cyc(cyc_o), .i_wb_stb(stb_o), .i_wb_we(we_o), .i_wb_addr(addr_o), .i_wb_data(dat_o), .i_wb_sel(sel_o),
			.i_wb_ack(ack_i), .i_wb_stall(stall_i), .i_wb_idata(dat_i), .i_wb_err(err_i),
		// Some convenience output parameters
		.f_nreqs, .f_nacks, .f_outstanding
    );
`endif

endmodule