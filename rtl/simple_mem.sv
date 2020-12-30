`include "config.svi"

module simple_mem(
    input clk_i, rst_i,
    input [`XLEN-1:$clog2(`XLEN)-1] addr_i,
    input we_i,
    input [`XLEN/8-1:0] sel_i,
    input [`XLEN-1:0] dat_i,
    input stb_i,
    input cyc_i,

    output reg ack_o,
    output reg err_o,
    output stall_o,
    output reg [`XLEN-1:0] dat_o
);

    reg [`XLEN-1:0] mem [`MEMSIZE-1:($clog2(`XLEN)-$clog2(8))];
    assign stall_o = 0;

    integer mem_idx = 0;
    initial begin
        for (mem_idx = 0; mem_idx < `MEMSIZE; mem_idx++) begin
            mem[mem_idx] = 0;
        end
    end
    logic [`XLEN-1:0] wmask;
    integer mask_idx = 0;
    always_comb begin:wmaskgen
        for (mask_idx = 0; mask_idx < `XLEN/8; mask_idx++) begin
            wmask[mask_idx*8+:8] = { 8{sel_i[mask_idx]}};
        end
    end

    // Writes
    always_ff @(posedge clk_i)
        if (stb_i && we_i && !stall_o) begin
            mem[addr_i] <= (mem[addr_i] & ~wmask) | (dat_i & wmask);
        end

    // Reads
    always_ff @(posedge clk_i)
        dat_o <= mem[addr_i];

    initial begin
        ack_o = 0;
        err_o = 0;
    end

    always_ff @(posedge clk_i) begin 
        if (rst_i)  begin
            ack_o <= 0;
            err_o <= 0;
        end else begin
            ack_o <= (stb_i) && (addr_i < `MEMSIZE) && (!stall_o);
            err_o <= (stb_i) && (addr_i >= `MEMSIZE) && (!stall_o);
        end
    end

`ifdef FORMAL
    wire [(4-1):0]	f_nreqs, f_nacks, f_outstanding;
    fwb_slave tester(
        .i_clk(clk_i), .i_reset(rst_i),
		// The Wishbone bus
		.i_wb_cyc(cyc_i), .i_wb_stb(stb_i), .i_wb_we(we_i), .i_wb_addr(addr_i), .i_wb_data(dat_o), .i_wb_sel(sel_i),
			.i_wb_ack(ack_o), .i_wb_stall(stall_o), .i_wb_idata(dat_i), .i_wb_err(err_o),
		// Some convenience output parameters
		.f_nreqs, .f_nacks, .f_outstanding
    );
`endif

endmodule