module rvfi_wrapper (
	input         clock,
	input         reset,
	`RVFI_OUTPUTS
);

	mr_core uut (
		.clk(clock),
		.rst(reset),

		`RVFI_CONN
	);

endmodule