`include "config.svi"

module simple_bram(
    input clk_i, rst_i,
    input [`XLEN-1:`XLEN_GRAN] addr_i,
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
    parameter READ_LATENCY = 4;
    logic [READ_LATENCY:0] pending_acks;

    logic recv_ok;
    assign recv_ok = stb_i & !stall_o;
    logic recv_bad;
    assign recv_bad = stb_i & !stall_o & (addr_i >= `MEMSIZE);

    assign stall_o = err_o;

    wire [$clog2(`MEMSIZE/`XLEN_BYTES)-1:0] addr;
    assign addr = addr_i[$clog2(`MEMSIZE)-1:`XLEN_GRAN];

    initial begin
        ack_o = 0;
        err_o = 0;
        pending_acks = 0;
    end

    always_ff @(posedge clk_i) begin 
        if (rst_i || !cyc_i)  begin
            ack_o <= 0;
            err_o <= 0;
            pending_acks <= 0;
        end else begin
            pending_acks <= {recv_ok, pending_acks[READ_LATENCY:1]};
            ack_o <= pending_acks[0] & !recv_bad & !err_o;
            err_o <= recv_bad || err_o;
        end
    end

// XPM_MEMORY instantiation template for Single Port RAM configurations
// Refer to the targeted device family architecture libraries guide for XPM_MEMORY documentation
// =======================================================================================================================

// Parameter usage table, organized as follows:
// +---------------------------------------------------------------------------------------------------------------------+
// | Parameter name       | Data type          | Restrictions, if applicable                                             |
// |---------------------------------------------------------------------------------------------------------------------|
// | Description                                                                                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// +---------------------------------------------------------------------------------------------------------------------+
// | ADDR_WIDTH_A         | Integer            | Range: 1 - 20. Default value = 6.                                       |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify the width of the port A address port addra, in bits.                                                        |
// | Must be large enough to access the entire memory from port A, i.e. >= $clog2(MEMORY_SIZE/[WRITE|READ]_DATA_WIDTH_A).|
// +---------------------------------------------------------------------------------------------------------------------+
// | AUTO_SLEEP_TIME      | Integer            | Range: 0 - 15. Default value = 0.                                       |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify the number of clka cycles to auto-sleep, if feature is available in architecture.                           |
// |                                                                                                                     |
// | 0 - Disable auto-sleep feature                                                                                      |
// | 3-15 - Number of auto-sleep latency cycles                                                                          |
// |                                                                                                                     |
// | Do not change from the value provided in the template instantiation.                                                |
// +---------------------------------------------------------------------------------------------------------------------+
// | BYTE_WRITE_WIDTH_A   | Integer            | Range: 1 - 4608. Default value = 32.                                    |
// |---------------------------------------------------------------------------------------------------------------------|
// | To enable byte-wide writes on port A, specify the byte width, in bits.                                              |
// |                                                                                                                     |
// | 8- 8-bit byte-wide writes, legal when WRITE_DATA_WIDTH_A is an integer multiple of 8                                |
// | 9- 9-bit byte-wide writes, legal when WRITE_DATA_WIDTH_A is an integer multiple of 9                                |
// |                                                                                                                     |
// | Or to enable word-wide writes on port A, specify the same value as for WRITE_DATA_WIDTH_A.                          |
// +---------------------------------------------------------------------------------------------------------------------+
// | CASCADE_HEIGHT       | Integer            | Range: 0 - 64. Default value = 0.                                       |
// |---------------------------------------------------------------------------------------------------------------------|
// | 0- No Cascade Height, Allow Vivado Synthesis to choose.                                                             |
// | 1 or more - Vivado Synthesis sets the specified value as Cascade Height.                                            |
// +---------------------------------------------------------------------------------------------------------------------+
// | ECC_MODE             | String             | Allowed values: no_ecc, both_encode_and_decode, decode_only, encode_only. Default value = no_ecc.|
// |---------------------------------------------------------------------------------------------------------------------|
// |                                                                                                                     |
// |   "no_ecc" - Disables ECC                                                                                           |
// |   "encode_only" - Enables ECC Encoder only                                                                          |
// |   "decode_only" - Enables ECC Decoder only                                                                          |
// |   "both_encode_and_decode" - Enables both ECC Encoder and Decoder                                                   |
// +---------------------------------------------------------------------------------------------------------------------+
// | MEMORY_INIT_FILE     | String             | Default value = none.                                                   |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify "none" (including quotes) for no memory initialization, or specify the name of a memory initialization file-|
// | Enter only the name of the file with .mem extension, including quotes but without path (e.g. "my_file.mem").        |
// | File format must be ASCII and consist of only hexadecimal values organized into the specified depth by              |
// | narrowest data width generic value of the memory. See the Memory File (MEM) section for more                        |
// | information on the syntax. Initialization of memory happens through the file name specified only when parameter     |
// | MEMORY_INIT_PARAM value is equal to "".                                                                             |
// | When using XPM_MEMORY in a project, add the specified file to the Vivado project as a design source.                |
// +---------------------------------------------------------------------------------------------------------------------+
// | MEMORY_INIT_PARAM    | String             | Default value = 0.                                                      |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify "" or "0" (including quotes) for no memory initialization through parameter, or specify the string          |
// | containing the hex characters. Enter only hex characters with each location separated by delimiter (,).             |
// | Parameter format must be ASCII and consist of only hexadecimal values organized into the specified depth by         |
// | narrowest data width generic value of the memory.For example, if the narrowest data width is 8, and the depth of    |
// | memory is 8 locations, then the parameter value should be passed as shown below.                                    |
// | parameter MEMORY_INIT_PARAM = "AB,CD,EF,1,2,34,56,78"                                                               |
// | Where "AB" is the 0th location and "78" is the 7th location.                                                        |
// +---------------------------------------------------------------------------------------------------------------------+
// | MEMORY_OPTIMIZATION  | String             | Allowed values: true, false. Default value = true.                      |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify "true" to enable the optimization of unused memory or bits in the memory structure. Specify "false" to      |
// | disable the optimization of unused memory or bits in the memory structure.                                          |
// +---------------------------------------------------------------------------------------------------------------------+
// | MEMORY_PRIMITIVE     | String             | Allowed values: auto, block, distributed, ultra. Default value = auto.  |
// |---------------------------------------------------------------------------------------------------------------------|
// | Designate the memory primitive (resource type) to use.                                                              |
// |                                                                                                                     |
// |   "auto"- Allow Vivado Synthesis to choose                                                                          |
// |   "distributed"- Distributed memory                                                                                 |
// |   "block"- Block memory                                                                                             |
// |   "ultra"- Ultra RAM memory                                                                                         |
// |                                                                                                                     |
// | NOTE: There may be a behavior mismatch if Block RAM or Ultra RAM specific features, like ECC or Asymmetry, are selected with MEMORY_PRIMITIVE set to "auto".|
// +---------------------------------------------------------------------------------------------------------------------+
// | MEMORY_SIZE          | Integer            | Range: 2 - 150994944. Default value = 2048.                             |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify the total memory array size, in bits.                                                                       |
// | For example, enter 65536 for a 2kx32 RAM.                                                                           |
// |                                                                                                                     |
// |   When ECC is enabled and set to "encode_only", then the memory size has to be multiples of READ_DATA_WIDTH_A       |
// |   When ECC is enabled and set to "decode_only", then the memory size has to be multiples of WRITE_DATA_WIDTH_A      |
// +---------------------------------------------------------------------------------------------------------------------+
// | MESSAGE_CONTROL      | Integer            | Range: 0 - 1. Default value = 0.                                        |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify 1 to enable the dynamic message reporting such as collision warnings, and 0 to disable the message reporting|
// +---------------------------------------------------------------------------------------------------------------------+
// | READ_DATA_WIDTH_A    | Integer            | Range: 1 - 4608. Default value = 32.                                    |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify the width of the port A read data output port douta, in bits.                                               |
// | The values of READ_DATA_WIDTH_A and WRITE_DATA_WIDTH_A must be equal.                                               |
// | When ECC is enabled and set to "encode_only", then READ_DATA_WIDTH_A has to be multiples of 72-bits.                |
// | When ECC is enabled and set to "decode_only" or "both_encode_and_decode", then READ_DATA_WIDTH_A has to be          |
// | multiples of 64-bits.                                                                                               |
// +---------------------------------------------------------------------------------------------------------------------+
// | READ_LATENCY_A       | Integer            | Range: 0 - 100. Default value = 2.                                      |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify the number of register stages in the port A read data pipeline. Read data output to port douta takes this   |
// | number of clka cycles.                                                                                              |
// |                                                                                                                     |
// | To target block memory, a value of 1 or larger is required- 1 causes use of memory latch only; 2 causes use of      |
// | output register.                                                                                                    |
// | To target distributed memory, a value of 0 or larger is required- 0 indicates combinatorial output.                 |
// | Values larger than 2 synthesize additional flip-flops that are not retimed into memory primitives.                  |
// +---------------------------------------------------------------------------------------------------------------------+
// | READ_RESET_VALUE_A   | String             | Default value = 0.                                                      |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify the reset value of the port A final output register stage in response to rsta input port is assertion.      |
// | Since this parameter is a string, you must specify the hex values inside double quotes. For example,                |
// | If the read data width is 8, then specify READ_RESET_VALUE_A = "EA";                                                |
// | When ECC is enabled, then reset value is not supported.                                                             |
// +---------------------------------------------------------------------------------------------------------------------+
// | RST_MODE_A           | String             | Allowed values: SYNC, ASYNC. Default value = SYNC.                      |
// |---------------------------------------------------------------------------------------------------------------------|
// | Describes the behaviour of the reset                                                                                |
// |                                                                                                                     |
// |   "SYNC" - when reset is applied, synchronously resets output port douta to the value specified by parameter READ_RESET_VALUE_A|
// |   "ASYNC" - when reset is applied, asynchronously resets output port douta to zero                                  |
// +---------------------------------------------------------------------------------------------------------------------+
// | SIM_ASSERT_CHK       | Integer            | Range: 0 - 1. Default value = 0.                                        |
// |---------------------------------------------------------------------------------------------------------------------|
// | 0- Disable simulation message reporting. Messages related to potential misuse will not be reported.                 |
// | 1- Enable simulation message reporting. Messages related to potential misuse will be reported.                      |
// +---------------------------------------------------------------------------------------------------------------------+
// | USE_MEM_INIT         | Integer            | Range: 0 - 1. Default value = 1.                                        |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify 1 to enable the generation of below message and 0 to disable generation of the following message completely.|
// | "INFO - MEMORY_INIT_FILE and MEMORY_INIT_PARAM together specifies no memory initialization.                         |
// | Initial memory contents will be all 0s."                                                                            |
// | NOTE: This message gets generated only when there is no Memory Initialization specified either through file or      |
// | Parameter.                                                                                                          |
// +---------------------------------------------------------------------------------------------------------------------+
// | WAKEUP_TIME          | String             | Allowed values: disable_sleep, use_sleep_pin. Default value = disable_sleep.|
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify "disable_sleep" to disable dynamic power saving option, and specify "use_sleep_pin" to enable the           |
// | dynamic power saving option                                                                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// | WRITE_DATA_WIDTH_A   | Integer            | Range: 1 - 4608. Default value = 32.                                    |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify the width of the port A write data input port dina, in bits.                                                |
// | The values of WRITE_DATA_WIDTH_A and READ_DATA_WIDTH_A must be equal.                                               |
// | When ECC is enabled and set to "encode_only" or "both_encode_and_decode", then WRITE_DATA_WIDTH_A must be           |
// | multiples of 64-bits.                                                                                               |
// | When ECC is enabled and set to "decode_only", then WRITE_DATA_WIDTH_A must be multiples of 72-bits.                 |
// +---------------------------------------------------------------------------------------------------------------------+
// | WRITE_MODE_A         | String             | Allowed values: read_first, no_change, write_first. Default value = read_first.|
// |---------------------------------------------------------------------------------------------------------------------|
// | Write mode behavior for port A output data port, douta.                                                             |
// +---------------------------------------------------------------------------------------------------------------------+

// Port usage table, organized as follows:
// +---------------------------------------------------------------------------------------------------------------------+
// | Port name      | Direction | Size, in bits                         | Domain  | Sense       | Handling if unused     |
// |---------------------------------------------------------------------------------------------------------------------|
// | Description                                                                                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// +---------------------------------------------------------------------------------------------------------------------+
// | addra          | Input     | ADDR_WIDTH_A                          | clka    | NA          | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Address for port A write and read operations.                                                                       |
// +---------------------------------------------------------------------------------------------------------------------+
// | clka           | Input     | 1                                     | NA      | Rising edge | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Clock signal for port A.                                                                                            |
// +---------------------------------------------------------------------------------------------------------------------+
// | dbiterra       | Output    | 1                                     | clka    | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Status signal to indicate double bit error occurrence on the data output of port A.                                 |
// +---------------------------------------------------------------------------------------------------------------------+
// | dina           | Input     | WRITE_DATA_WIDTH_A                    | clka    | NA          | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Data input for port A write operations.                                                                             |
// +---------------------------------------------------------------------------------------------------------------------+
// | douta          | Output    | READ_DATA_WIDTH_A                     | clka    | NA          | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Data output for port A read operations.                                                                             |
// +---------------------------------------------------------------------------------------------------------------------+
// | ena            | Input     | 1                                     | clka    | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Memory enable signal for port A.                                                                                    |
// | Must be high on clock cycles when read or write operations are initiated. Pipelined internally.                     |
// +---------------------------------------------------------------------------------------------------------------------+
// | injectdbiterra | Input     | 1                                     | clka    | Active-high | Tie to 1'b0            |
// |---------------------------------------------------------------------------------------------------------------------|
// | Controls double bit error injection on input data when ECC enabled (Error injection capability is not available in  |
// | "decode_only" mode).                                                                                                |
// +---------------------------------------------------------------------------------------------------------------------+
// | injectsbiterra | Input     | 1                                     | clka    | Active-high | Tie to 1'b0            |
// |---------------------------------------------------------------------------------------------------------------------|
// | Controls single bit error injection on input data when ECC enabled (Error injection capability is not available in  |
// | "decode_only" mode).                                                                                                |
// +---------------------------------------------------------------------------------------------------------------------+
// | regcea         | Input     | 1                                     | clka    | Active-high | Tie to 1'b1            |
// |---------------------------------------------------------------------------------------------------------------------|
// | Clock Enable for the last register stage on the output data path.                                                   |
// +---------------------------------------------------------------------------------------------------------------------+
// | rsta           | Input     | 1                                     | clka    | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Reset signal for the final port A output register stage.                                                            |
// | Synchronously resets output port douta to the value specified by parameter READ_RESET_VALUE_A.                      |
// +---------------------------------------------------------------------------------------------------------------------+
// | sbiterra       | Output    | 1                                     | clka    | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Status signal to indicate single bit error occurrence on the data output of port A.                                 |
// +---------------------------------------------------------------------------------------------------------------------+
// | sleep          | Input     | 1                                     | NA      | Active-high | Tie to 1'b0            |
// |---------------------------------------------------------------------------------------------------------------------|
// | sleep signal to enable the dynamic power saving feature.                                                            |
// +---------------------------------------------------------------------------------------------------------------------+
// | wea            | Input     | WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A | clka    | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write enable vector for port A input data port dina. 1 bit wide when word-wide writes are used.                     |
// | In byte-wide write configurations, each bit controls the writing one byte of dina to address addra.                 |
// | For example, to synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A is 32, wea would be 4'b0010.   |
// +---------------------------------------------------------------------------------------------------------------------+


// xpm_memory_spram : In order to incorporate this function into the design,
//     Verilog      : the following instance declaration needs to be placed
//     instance     : in the body of the design code.  The instance name
//   declaration    : (xpm_memory_spram_inst) and/or the port declarations within the
//       code       : parenthesis may be changed to properly reference and
//                  : connect this function to the design.  All inputs
//                  : and outputs must be connected.

//  Please reference the appropriate libraries guide for additional information on the XPM modules.

//  <-----Cut code below this line---->

   // xpm_memory_spram: Single Port RAM
   // Xilinx Parameterized Macro, version 2020.2

    logic dbiterra, sbiterra, injectdbiterra, injectsbiterra, sleep, regcea;
    assign sleep = 0;
    assign injectsbiterra = 0;
    assign injectdbiterra = 0;
    assign regcea = 1'b1;
    logic [`XLEN/8-1:0] we_bytes;
    assign we_bytes =  we_i ? sel_i : 0;

   xpm_memory_spram #(
      .ADDR_WIDTH_A($clog2(`MEMSIZE/`XLEN_BYTES)),              // DECIMAL
      .AUTO_SLEEP_TIME(0),           // DECIMAL
      .BYTE_WRITE_WIDTH_A(8),        // DECIMAL
      .CASCADE_HEIGHT(0),            // DECIMAL
      .ECC_MODE("no_ecc"),           // String
      .MEMORY_INIT_FILE("none"),     // String
      .MEMORY_INIT_PARAM("0"),       // String
      .MEMORY_OPTIMIZATION("true"),  // String
      .MEMORY_PRIMITIVE("auto"),     // String
      .MEMORY_SIZE(`MEMSIZE * 8),    // DECIMAL
      .MESSAGE_CONTROL(0),           // DECIMAL
      .READ_DATA_WIDTH_A(`XLEN),     // DECIMAL
      .READ_LATENCY_A(READ_LATENCY),            // DECIMAL
      .READ_RESET_VALUE_A("0"),      // String
      .RST_MODE_A("SYNC"),           // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_MEM_INIT(1),              // DECIMAL
      .WAKEUP_TIME("disable_sleep"), // String
      .WRITE_DATA_WIDTH_A(`XLEN),    // DECIMAL
      .WRITE_MODE_A("read_first")    // String
   )
   xpm_memory_spram_inst (
      .dbiterra(dbiterra),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(dat_o),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .sbiterra(sbiterra),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .addra(addr),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .clka(clk_i),                     // 1-bit input: Clock signal for port A.
      .dina(dat_i),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(recv_ok),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .injectdbiterra(injectdbiterra), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(injectsbiterra), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regcea(regcea),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(rst_i),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .sleep(sleep),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(we_bytes)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

   // End of xpm_memory_spram_inst instantiation
				
				

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