#![no_std]

use core::fmt::{Result, Write};
use core::panic::PanicInfo;

pub use riscv_rt::entry;

extern "C" {
    pub static mut tohost: u32;
    pub static mut hosthalt: u32;
}

pub struct TestBenchIo {}
impl Write for TestBenchIo {
    fn write_str(&mut self, s: &str) -> Result {
        unsafe {
            let putc_addr: *mut u32 = &mut tohost;
            for b in s.bytes() {
                putc_addr.write_volatile(b as u32);
            }
        }
        Ok(())
    }
}

#[macro_export]
macro_rules! print
{
	($($args:tt)+) => ({
            #[allow(unused_imports)]
			use core::fmt::Write;
			let _ = write!($crate::TestBenchIo{}, $($args)+);
	});
}
#[macro_export]
macro_rules! println
{
	() => ({
		$crate::print!("\n")
	});
	($fmt:expr) => ({
		$crate::print!(concat!($fmt, "\n"))
	});
	($fmt:expr, $($args:tt)+) => ({
		$crate::print!(concat!($fmt, "\n"), $($args)+)
	});
}

#[panic_handler]
pub fn handle_panic(info: &PanicInfo) -> ! {
    if let Some(loc) = info.location() {
        println!("Panic encountered at {}:{}!", loc.file(), loc.line());
    } else {
        println!("Panic encountered!");
    }
    if let Some(s) = info.payload().downcast_ref::<&str>() {
        println!("Info: '{}'", s);
    }
    halt();
}

pub fn halt() -> ! {
    unsafe {
        let halt_addr: *mut u32 = &mut hosthalt;
        halt_addr.write_volatile(1);
    }
    loop {}
}

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
