# test_my_design.py (extended)

import cocotb
from cocotb.triggers import Timer
from cocotb.triggers import FallingEdge
from cocotb.binary import BinaryValue


async def generate_clock(dut):
    """Generate clock pulses."""

    for cycle in range(10):
        dut.clk.value = 0
        await Timer(1, units="ns")
        dut.clk.value = 1
        await Timer(1, units="ns")

def fill_memory(dut, loc, b):
    """ Write bytes into memory at loc """
    for i in range(0, len(b), 4):
        dut.ram.mem[loc+i] = BinaryValue(value=b[i:i+4])


@cocotb.test()
async def my_second_test(dut):
    """Try accessing the design."""

    await cocotb.start(generate_clock(dut))  # run the clock "in the background"

    fill_memory(dut, 0, b'12345')

    await Timer(5, units="ns")  # wait a bit
    await FallingEdge(dut.clk)  # wait for falling edge/"negedge"
