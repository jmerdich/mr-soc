#![no_std]
#![no_main]

use mrsoc_rt::{entry, halt, println};
use riscv::register as csr;

#[entry]
fn main() -> ! {
    println!("Hello, world!");

    println!("Insts: {}, Cycles: {}", csr::minstret::read(), csr::mcycle::read());
    halt();
}
