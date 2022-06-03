# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

RTL_DIR=$(PWD)/../../rtl
WB2AXI_DIR=$(PWD)/../../extern/wb2axip/rtl/

#VERILOG_INCLUDE_DIR += $(RTL_DIR)
COMPILE_ARGS += -I$(RTL_DIR) -I$(RTL_DIR)/..
VERILOG_SOURCES += $(wildcard $(RTL_DIR)/*.sv) $(WB2AXI_DIR)/wbarbiter.v
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = mr_soc

# MODULE is the basename of the Python test file
MODULE = test_core_sanity

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
