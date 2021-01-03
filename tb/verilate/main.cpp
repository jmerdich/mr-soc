// Taken from Verilator manpage (CC0 license).

// stdlib
#include <cstdlib>
#include <cstdio>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <iostream>

// Common verilator headers
#include <verilated.h>
#include <verilated_fst_c.h>

// Other libs
#include <cxxopts.hpp>

// Verilated sources
#include "Vmr_core.h"
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

    cxxopts::Options options(argv[0], "Mr. SOC RISC-V machine");

    options.add_options()
        ("h,help", "Print usage")
        ("f,file", "Binary file to run", cxxopts::value<std::string>())
        ("trace-file", "Output trace file", cxxopts::value<std::string>()->default_value("obj_dir/sim.fst"))
        ("e,entrypoint", "Entrypoint to start execution at", cxxopts::value<uint64_t>()->default_value("0"))
        ("halt-addr", "Address to check to see if finished", cxxopts::value<int64_t>()->default_value("-1"))
        ("t,time-limit", "Time limit in cycles", cxxopts::value<int64_t>()->default_value("10000"))
        ;

    options.allow_unrecognised_options();

    auto result = options.parse(argc, argv);

    if (result.count("help")) {
        std::cout << options.help() << std::endl;
        exit(0);
    }

    top = new Vtop;             // Create instance
    top->trace(tfp, 99);
    tfp->open(result["trace-file"].as<std::string>().c_str());


    memset(top->mr_core->ram->mem, 0x00, sizeof(top->mr_core->ram->mem));
    if (result["file"].count() != 0) {
        // Can I just point out how much easier this is in rust?
        // https://doc.rust-lang.org/std/io/trait.Read.html#examples-2

        int fd = open(result["file"].as<std::string>().c_str(), O_RDONLY);
        if (fd < 0) {
            std::cout << "File failed to open!!!" << std::endl;
            exit(1);
        }
        const uint64_t max_size = 32*1024*1024; // TODO: get this automatically
        struct stat stat_buf = {};
        int retval = fstat(fd, &stat_buf);
        assert(retval == 0);
        assert(stat_buf.st_size <= max_size);
        char* buf = (char*)malloc(stat_buf.st_size);
        size_t cur_loc = 0;
        ssize_t num_xferd = 0;
        while ((cur_loc < stat_buf.st_size) && ((num_xferd = read(fd, &buf[cur_loc], (stat_buf.st_size - cur_loc))) > 0))
        {
            cur_loc += num_xferd;
        }
        assert(num_xferd >= 0);
        assert(cur_loc == stat_buf.st_size);
        memcpy(top->mr_core->ram->mem, buf, stat_buf.st_size);
        free(buf);
    } else {
        // Infinite 'x1 += 1' loop
        for (int i = 0; i < 10; i++) {
            top->mr_core->ram->mem[i] = 0x00108093;
        }
        top->mr_core->ram->mem[10] = 0x00000067;
    }

    uint64_t entrypoint = result["entrypoint"].as<uint64_t>();
    assert((entrypoint & 0x3) == 0); // alignment ok?
    assert((entrypoint == 0) || (entrypoint > 16)); // entrypoint must not overlap our jump stub

    assert(entrypoint == 0); // not implemented :P
    if (entrypoint != 0) {
        // Load then indirect jump
        top->mr_core->ram->mem[0] = 0x00802083; // TODO: 64-bit load if RV64
        top->mr_core->ram->mem[1] = 0x00008067;
        top->mr_core->ram->mem[2] = entrypoint & 0xFFFFFFFF;
        top->mr_core->ram->mem[3] = (entrypoint >> 32) & 0xFFFFFFFF;
    }

    int64_t max_runtime = result["time-limit"].as<int64_t>();
    int64_t halt_addr = result["halt-addr"].as<int64_t>();

    top->rst = 1;           // Set some inputs

    while (!Verilated::gotFinish() &&
           ((max_runtime < 0) || (main_time < max_runtime)) &&
           ((halt_addr < 0) || (top->mr_core->ram->mem[halt_addr/4] == 0))) {
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

    if (Verilated::gotFinish()) {
        std::cout << "Simulation received $finish() after " << main_time << " clocks." << std::endl;
    }
    if ((max_runtime >= 0) && (main_time >= max_runtime)) {
        std::cout << "Simulation timed out after " << main_time << " clocks." << std::endl;
    }
    if ((halt_addr >= 0) && ((top->mr_core->ram->mem[halt_addr/4]) != 0)) {
        std::cout << "Simulation reached halt trigger condition after " << main_time << " clocks." << std::endl;
        std::cout << std::hex;
        std::cout << "  Trigger loc: " << halt_addr << std::endl;
        std::cout << "  Trigger val: " << (top->mr_core->ram->mem[halt_addr/4]) << std::endl;
        std::cout << std::dec;
    }

    delete top;
}