// Taken from Verilator manpage (CC0 license).

#include <verilated.h>          // Defines common routines
#include <verilated_fst_c.h>          // Defines common routines
#include <iostream>             // Need std::cout
#include "Vmr_core.h"               // From Verilating "top.v"

#include "Vmr_core_mr_core.h"
#include "Vmr_core_simple_mem.h"

#define Vtop Vmr_core

Vtop *top;                      // Instantiation of module

vluint64_t main_time = 0;       // Current simulation time
// This is a 64-bit integer to reduce wrap over issues and
// allow modulus.  This is in units of the timeprecision
// used in Verilog (or from --timescale-override)

double sc_time_stamp () {       // Called by $time in Verilog
    return main_time;           // converts to double, to match
                                // what SystemC does
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);   // Remember args
    Verilated::traceEverOn(true);
    VerilatedFstC* tfp = new VerilatedFstC;

    top = new Vtop;             // Create instance
    top->trace(tfp, 99);
    tfp->open("obj_dir/sim.fst");

    memset(top->mr_core->ram->mem, 0xff, sizeof(top->mr_core->ram->mem));
    for (int i = 0; i < 10; i++) {
        top->mr_core->ram->mem[i] = 0x00108093;
    }
    top->mr_core->ram->mem[10] = 0x00000067;

    vluint64_t max_runtime = 10000;

    top->rst = 1;           // Set some inputs

    while (!Verilated::gotFinish() && (main_time < max_runtime)) {
        if (main_time > 10) {
            top->rst = 0;   // Deassert reset
        }
        if ((main_time % 10) == 1) {
            top->clk = 1;       // Toggle clock
        }
        if ((main_time % 10) == 6) {
            top->clk = 0;
        }
        top->eval();            // Evaluate model
        tfp->dump(main_time);
        main_time++;            // Time passes...
    }

    tfp->close();
    top->final();               // Done simulating
    //    // (Though this example doesn't get here)
    delete top;
}