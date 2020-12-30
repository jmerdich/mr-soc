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
    output reg [`XLEN-1:0] dat_o
);

    reg [`XLEN-1:0] mem [`MEMSIZE-1:($clog2(`XLEN)-$clog2(8))];
    wire stall_o = 0;

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
    

    always_ff @(posedge clk_i) begin 
        if (rst_i)  begin
            ack_o <= 0;
            err_o <= 0;
        end else begin
            ack_o <= (stb_i) && (addr_i < `MEMSIZE) && (!stall_o);
            err_o <= (stb_i) && (addr_i >= `MEMSIZE) && (!stall_o);
        end
    end

endmodule