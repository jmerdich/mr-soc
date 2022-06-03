
`include "config.svi"

module mr_ldst(
    input clk, rst,

    // From prev
    input e_memops ex_op_i,
    input e_memsz ex_size_i,
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
logic reset;

// Metadata on active transaction
e_memsz size_pending;
logic signed_pending;
logic [`REGSEL_BITS-1:0] dst_reg_pending;
logic [`XLEN_GRAN-1:0] shift_pending;

initial cyc_o = 0;
initial stb_o = 0;
`ALWAYS_FF_ICARUS_159 @(posedge clk) begin
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

        if (ex_valid_i && (ex_op_i != MEMOP_NONE)) begin
            // New memory req!
            cyc_o <= 1;
            stb_o <= 1;
        end
    end
end

assign ex_ready_o = !cyc_o;

// Send path shifting
logic [`XLEN/8-1:0] sel;
reg [`XLEN-1:0] shifted_dat_o;
wire [`XLEN_GRAN-1:0] shift_bits_o = ex_addr_i[`XLEN_GRAN-1:0];
`ALWAYS_COMB_ICARUS_159 case(ex_size_i)
    MEMSZ_8B: begin
        shifted_dat_o = ex_payload_i;
        sel = 4'b1111;
    end
    MEMSZ_4B: begin
        shifted_dat_o = ex_payload_i;
        sel = 4'b1111;
    end
    MEMSZ_2B: begin
        shifted_dat_o = { ex_payload_i[15:0], ex_payload_i[15:0]};
        sel[3:2] = (shift_bits_o == 2'b1X) ? 2'b11 : 2'b00;
        sel[1:0] = (shift_bits_o == 2'b0X) ? 2'b11 : 2'b00;
    end
    MEMSZ_1B: begin
        shifted_dat_o = { ex_payload_i[7:0], ex_payload_i[7:0], ex_payload_i[7:0], ex_payload_i[7:0]};
        sel[3] = (shift_bits_o == 2'b11);
        sel[2] = (shift_bits_o == 2'b10);
        sel[1] = (shift_bits_o == 2'b01);
        sel[0] = (shift_bits_o == 2'b00);
    end
endcase


// Return path shifting/value-decoding
reg [`XLEN-1:0] shifted_dat_i;
wire [16-1:0] shifted_2b_i;
wire shifted_2b_sign_i;
assign shifted_2b_i = ((shift_pending & 2'b10) != 0) ? dat_i[31:16] : dat_i[15:0];
assign shifted_2b_sign_i = signed_pending ? shifted_2b_i[15] : 0;

reg [8-1:0] shifted_1b_i;
wire shifted_1b_sign_i;
assign shifted_1b_sign_i = signed_pending ? shifted_2b_i[7] : 0;
`ALWAYS_COMB_ICARUS_159 case(shift_pending)
    0: shifted_1b_i = dat_i[7:0];
    1: shifted_1b_i = dat_i[15:8];
    2: shifted_1b_i = dat_i[23:16];
    3: shifted_1b_i = dat_i[31:24];
endcase

always_comb case(size_pending) 
    MEMSZ_8B: shifted_dat_i = dat_i; // Who cares?
    MEMSZ_4B: shifted_dat_i = dat_i;
    MEMSZ_2B: shifted_dat_i = {{16{shifted_2b_sign_i}}, shifted_2b_i};
    MEMSZ_1B: shifted_dat_i = {{24{shifted_1b_sign_i}}, shifted_1b_i};
endcase


// Data sending logic
always_ff @(posedge clk) begin
    if (!reset & !cyc_o & ex_valid_i & ex_op_i != MEMOP_NONE) begin
        addr_o <= ex_addr_i[`XLEN-1:`XLEN_GRAN];
        we_o <= (ex_op_i == MEMOP_STORE);
        sel_o <= sel;
        dat_o <= shifted_dat_o;
        dst_reg_pending <= ex_dst_reg_i;
        size_pending <= ex_size_i;
        signed_pending <= ex_signed_i;
        shift_pending <= shift_bits_o;
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

