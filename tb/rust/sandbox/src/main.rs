#![no_std]
#![no_main]

use mrsoc_rt::{entry, halt, println};

#[entry]
fn main() -> ! {
    println!("Hello, world!");
    halt();
}
