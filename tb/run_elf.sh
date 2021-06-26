#!/bin/bash

if [ $# -ne 1 ]
then
    echo Usage: $0 progname
    exit 1
fi

REPO_ROOT="$(dirname ${BASH_SOURCE[0]})/.."
PROGFILE="$1"

SIM=${REPO_ROOT}/obj_dir/Vmr_core

RISCV_TOOLS_DIR=/opt/riscv32/bin
DEFAULT_XLEN=32

RISCV_PREFIX=${RISCV_TOOLS_DIR}/riscv${DEFAULT_XLEN}-unknown-elf-
RISCV_GCC=${RISCV_PREFIX}gcc
RISCV_OBJDUMP=${RISCV_PREFIX}objdump
RISCV_OBJCOPY=${RISCV_PREFIX}objcopy
RISCV_READELF=${RISCV_PREFIX}readelf

if [[ "$PROGFILE" == *.elf ]]
then
    PROGFILENOEXT="${PROGFILE%.elf}"
else
    PROGFILENOEXT="${PROGFILE}"
fi


set -e 
echo Building model...
make --no-print-directory --quiet -C $REPO_ROOT ver

echo Massaging ELFs...
$RISCV_OBJCOPY -O binary "$PROGFILE" "$PROGFILENOEXT.bin"
$RISCV_OBJDUMP $PROGFILE -D > $PROGFILENOEXT.objdump

START_ADDR=$(${RISCV_READELF} -s "$PROGFILE" | grep "\b_start\b" | tr -s ' ' | cut -d " " -f 3 )
PUTC_ADDR=$(${RISCV_READELF} -s "$PROGFILE" | grep tohost | tr -s ' ' | cut -d " " -f 3 )
HALT_ADDR=$(${RISCV_READELF} -s "$PROGFILE" | grep hosthalt | tr -s ' ' | cut -d " " -f 3 )
TIME_LIMIT=-1

RUN_ARGS="--file $PROGFILE.bin --time-limit=$TIME_LIMIT -e 0x$START_ADDR --trace-file=$PROGFILENOEXT.fst --putc-addr 0x$PUTC_ADDR --halt-addr 0x$HALT_ADDR"

echo ${SIM} ${RUN_ARGS}
echo Running!
echo ==============================================================
${SIM} ${RUN_ARGS} |& tee $PROGFILENOEXT.log
