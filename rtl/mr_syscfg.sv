
`include "config.svi"

module mr_syscfg(
    input clk, rst,

    // Counters
    input [2:0] insts_ret,

    // Traps
    // input has_trap,
    // input e_traptype trap_type,

    // Core control
    // input insts_pending,
    // output stall,

    // TODO: direct core access for debug module and trap handler

    // CSRs
    // Legality and needs-fence must be combinatorial
    input i_csr_valid, i_csr_r, i_csr_w,
    input [`CSRLEN-1:0] i_csr_addr,
    input [`XLEN-1:0] i_csr_data,
    input [`XLEN-1:0] i_csr_wmask,
    output i_csr_ready, i_csr_legal, i_csr_fence,

    // Each recieved+legal CSR gets one output in-order
    output logic o_csr_valid,
    output logic [`XLEN-1:0] o_csr_data

`ifdef RISCV_FORMAL_CSR_MCYCLE
    `rvformal_csr_mcycle_outputs
`endif
);

    // assign stall = 0;

    // If we need to pipeline normal insts with CSRs, add more logic here
    assign i_csr_fence = 0;
    
    // Currently never stalls
    assign i_csr_ready = 1;

    logic i_csr_rcvd;
    assign i_csr_rcvd = i_csr_ready & i_csr_legal & i_csr_valid;


    logic [63:0] cycles;
    always @(posedge clk)
    if (rst)
        cycles <= 0;
    else
        cycles <= cycles + 1;

    logic [63:0] insts;
    always @(posedge clk)
    if (rst)
        insts <= 0;
    else
        insts <= insts + {61'h0, insts_ret};

    logic [11:0] last_csr;
    initial last_csr = 0;
    always @(posedge clk) begin
        if ((i_csr_addr != last_csr) && !csr_exists) begin
            //$display("Unknown CSR 0x%0h", i_csr_addr);
        end
        last_csr <= i_csr_addr;
    end

    logic csr_write_allowed;
    assign csr_write_allowed = (i_csr_addr[11:10] != 3) | !i_csr_w;
    logic csr_priv_allowed = 1;
    logic csr_exists;
    logic [`XLEN-1:0] csr_read_data;
    always @(*) begin
        // All CSR ops must be a read or a write (otherwise it's an ID bug)
        assert(!i_csr_valid || (i_csr_r || i_csr_w));
        csr_exists = 0;
        csr_read_data = 0;

        case (i_csr_addr)
        default: begin
            // ...
        end
        CSR_MISA: begin
            csr_exists = 1;
            csr_read_data = 0; // TODO: add a parameter for this if multi-core
        end
        CSR_MHARTID: begin
            csr_exists = 1;
            csr_read_data = 0; // TODO: add a parameter for this if multi-core
        end
        CSR_MIMPID,
        CSR_MARCHID,
        CSR_MVENDORID: begin
            csr_exists = 1;
            csr_read_data = 0;
        end
        CSR_MCYCLE: begin
            // TODO write logic
            csr_exists = 1;
            csr_read_data = cycles[`XLEN-1:0];
        end
        CSR_MCYCLEH: begin
            // TODO rv64 support?
            csr_exists = 1;
            csr_read_data = cycles[63:`XLEN];
        end
        CSR_MINSTRET: begin
            // TODO write logic
            csr_exists = 1;
            csr_read_data = insts[`XLEN-1:0];
        end
        CSR_MINSTRETH: begin
            // TODO rv64 support?
            csr_exists = 1;
            csr_read_data = insts[63:`XLEN];
        end


        endcase
        
    end
    assign i_csr_legal = csr_exists & csr_write_allowed & csr_priv_allowed;


    logic [`XLEN-1:0] csr_new_val;
    assign csr_new_val = (csr_read_data & ~i_csr_wmask) | (i_csr_data & i_csr_wmask);
    logic got_csr_access;
    assign got_csr_access = i_csr_legal & i_csr_valid & i_csr_ready;
    always @(posedge clk) begin
        if (rst) begin
            o_csr_valid <= 0;
            o_csr_data <= 0;
        end else if (got_csr_access) begin
            if (i_csr_w) begin
                // write logic here
            end
            if (i_csr_r) begin
                // read side effects here.
            end
            o_csr_valid <= 1;
            o_csr_data <= csr_read_data;
        end else begin
            o_csr_valid <= 0;
            o_csr_data <= 0;
        end
    end

endmodule

