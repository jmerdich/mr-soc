`include "rtl/config.svi"

// TODO: handle IALIGN==16 and XLEN==64

module mr_ifetch(
    input clk, rst,

    // Mem
    output reg [`XLEN-1:0] adr_o,
    // unpop: dat_o
    input [`XLEN-1:0] dat_i,
    // unpop: we_o
    // unpop: sel_o
    output reg stb_o,
    input ack_i,
    input err_i,
    input stall_i,
    output reg cyc_i,

    // To ID
    output reg [`IMAXLEN-1:0] inst,
    output reg [`XLEN-1:0] inst_pc,
    output reg inst_valid,
    input id_ready,

    // From WB
    input [`XLEN-1:0] wb_pc,
    input wb_pc_valid
);

    reg [`XLEN-1:0] pc;
    initial begin
        pc = `RESET_VEC;
    end

    logic [`XLEN-1:0] pc_offset = 4;

    always_ff @(posedge clk) begin
        if (rst)
            pc <= `RESET_VEC;
        else if (wb_pc_valid)
            pc <= wb_pc;
        else if (id_ready & inst_valid)
            pc <= pc + pc_offset;
        else
            pc <= pc;
    end


    always_ff @(posedge clk) begin
        if (req && data_valid) begin
            inst <= data;
            inst_pc <= pc;
            inst_valid <= 1;
            req <= 0;
        end else if (!req) begin
            addr <= pc;
            req <= 1;
        end
    end

endmodule