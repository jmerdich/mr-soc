
`include "config.svi"

module mr_ldst(
    input clk, rst,

    // From prev
    input [`INSTID_BITS-1:0] ex_instid_i,
    input e_memops ex_op_i,
    input e_memsz ex_size_i,
    input ex_signed_i,
    input ex_jump_taken_i,
    input ex_jump_predicted_i,
    input ex_is_jump_i,
    input [`XLEN-1:0] ex_addr_i,
    input [`XLEN-1:0] ex_payload_i,
    input e_payload ex_payload_kind_i,
    input [`REGSEL_BITS-1:0] ex_dst_reg_i,
    input ex_valid_i,
    output ex_ready_o,

    // To WB
    output reg wb_write,
    output reg [`INSTID_BITS-1:0] wb_instid_o,
    output reg [`XLEN-1:0] wb_data_o,
    output reg [`REGSEL_BITS-1:0] wb_dst_reg_o,
    output reg [`XLEN-1:0] wb_payload_o,
    output e_payload wb_payload_kind_o,
    output wb_jump_taken_o,
    output wb_is_jump_o,
    output wb_jump_predicted_o,
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

    // To CSR unit
    output csr_valid;
    output csr_read;
    output csr_write;
    output [`CSRLEN-1:0] csr_addr,
    output [`XLEN-1:0] csr_data,
    output [`XLEN-1:0] csr_wmask,

    // Each recieved+legal CSR gets one output in-order
    input i_csr_ready, i_csr_legal, i_csr_fence,
    input logic i_csr_valid,
    input logic [`XLEN-1:0] i_csr_data
);
logic reset;

// Metadata on active transaction
e_memsz size_pending;
logic signed_pending;
logic [`REGSEL_BITS-1:0] dst_reg_pending;
logic [`XLEN_GRAN-1:0] shift_pending;
logic [`XLEN-1:0] payload_pending;
e_payload payload_kind_pending;
logic [`INSTID_BITS-1:0] instid_pending;

logic got_mem_req;
assign got_mem_req = (ex_op_i == MEMOP_LOAD_MEM || ex_op_i == MEMOP_STORE_MEM);
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

        if (ex_valid_i && got_mem_req) begin
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
always_comb case(ex_size_i)
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
always_comb case(shift_pending)
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
    if (!reset & !cyc_o & ex_valid_i & got_mem_req) begin
        addr_o <= ex_addr_i[`XLEN-1:`XLEN_GRAN];
        we_o <= (ex_op_i == MEMOP_STORE_MEM);
        sel_o <= sel;
        dat_o <= shifted_dat_o;
        dst_reg_pending <= ex_dst_reg_i;
        size_pending <= ex_size_i;
        signed_pending <= ex_signed_i;
        shift_pending <= shift_bits_o;
        payload_pending <= ex_payload_i;
        payload_kind_pending <= ex_payload_kind_i;
        instid_pending <= ex_instid_i;
        assert(ex_jump_taken_i == 0);
        assert(ex_jump_predicted_i == 0);
        assert(ex_is_jump_i == 0);
    end
end


// Handle returning the data when the r/w clears
always_ff @(posedge clk) begin
    wb_jump_taken_o <= 0;
    wb_jump_predicted_o <= 0;
    wb_is_jump_o <= 0;
    if (reset) begin 
        wb_write <= 0;
    end else if (ack_i & (!stb_o | !stall_i)) begin
        wb_write <= 1;
        wb_data_o <= shifted_dat_i;
        wb_dst_reg_o <= dst_reg_pending;
        wb_payload_o <= payload_pending;
        wb_payload_kind_o <= payload_kind_pending;
        wb_instid_o <= instid_pending;
    end else if (!cyc_o & ex_valid_i & (ex_op_i == MEMOP_NONE)) begin
        wb_write <= 1;
        wb_data_o <= ex_addr_i;
        wb_dst_reg_o <= ex_dst_reg_i;
        wb_payload_o <= ex_payload_i;
        wb_payload_kind_o <= ex_payload_kind_i;
        wb_instid_o <= ex_instid_i;
        wb_jump_taken_o <= ex_jump_taken_i;
        wb_jump_predicted_o <= ex_jump_predicted_i;
        wb_is_jump_o <= ex_is_jump_i;
    end else begin
        wb_write <= 0;
    end
end

logic got_csr_req = (ex_op_i == MEMOP_CSR_RW) ||
                    (ex_op_i == MEMOP_CSR_READ) ||
                    (ex_op_i == MEMOP_CSR_SETBITS) ||
                    (ex_op_i == MEMOP_CSR_CLEARBITS);

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

