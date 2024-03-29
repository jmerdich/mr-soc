
# TOOLS:
VERILATOR = verilator
RISCV_TOOLS_DIR ?= /opt/riscv32/bin

export PATH:=${RISCV_TOOLS_DIR}:${PATH}

# ENV/CONFIG
VERILATOR_ARGS = --top-module ${TOP_MODULE} ${VERILATOR_WARNS} $(addprefix -I,${V_INCLUDE_DIRS})
VERILATOR_WARNS = -Wall -Wno-unused
VERILATOR_LINT_ARGS = --lint-only
VERILATOR_VER_ARGS = --cc --build --exe --assert -Wno-undriven --trace-fst --trace-structs -CFLAGS "-ggdb $(addprefix -I../,${CXX_INCLUDE_DIRS})"

OUTFILE = obj_dir/V${TOP_MODULE}

TOP_MODULE = mr_soc

# C++ SOURCES
VERILATOR_CXX_SOURCES = tb/verilate/main.cpp
CXX_INCLUDE_DIRS = extern/cxxopts/include

# SOURCES
V_INCLUDE_DIRS = rtl extern/wb2axip/rtl
V_HEADERS = rtl/config.svi
V_SOURCES = rtl/mr_soc.sv rtl/mr_core.sv rtl/mr_alu.sv rtl/mr_id.sv rtl/mr_ifetch.sv rtl/mr_ldst.sv  rtl/simple_mem.sv

.PHONY: check
check: ${V_HEADERS} ${V_SOURCES}
	${VERILATOR} ${VERILATOR_ARGS} ${VERILATOR_LINT_ARGS} ${V_HEADERS} ${V_SOURCES}


${OUTFILE}: ${V_HEADERS} ${V_SOURCES} ${VERILATOR_CXX_SOURCES} Makefile
	${VERILATOR} ${VERILATOR_ARGS} ${VERILATOR_VER_ARGS} ${V_HEADERS} ${V_SOURCES} ${VERILATOR_CXX_SOURCES}

.PHONY: ver
ver: ${OUTFILE}

.PHONY: run
run: ver
	./${OUTFILE} ${RUNARGS}

.PHONY: compclean
compclean:
	rm -rf extern/riscv-compliance/work

.PHONY: clean
clean:
	rm -rf obj_dir
	rm -rf extern/riscv-compliance/work

.PHONY: comp
comp: ver
	${MAKE} -C extern/riscv-compliance TARGETDIR=$(abspath tb/compliance) RISCV_TARGET=mr_soc XLEN=32 TARGET_SIM=$(abspath ${OUTFILE}) VERBOSE=1
