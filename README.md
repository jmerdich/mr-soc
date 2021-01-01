Mr. SOC - Merdich RISC-V SOC
============================

This is a simple pipelined RISC-V core used mainly as a personal project. This is VERY WIP, not particularly efficient,
and probably non-functional (TODO: change that) but the goal is to eventually have something that can boot linux.

The core uses a 5ish-stage in-order pipeline connected to a wishbone bus. It currently only supports RV32I, with hopes
to eventually support RV64GC+priv and boot stock Debian/Fedora (modulo kernel drivers).


REQUIRED DEPENDENCIES:
----------------------

- extern/wb2axip, Apache License, Gisselquist Technology, LLC

OPTIONAL DEPENDENCIES:
----------------------

- extern/zip-formal, GPLv3, Gisselquist Technology, LLC
  > Distribution/use with a copy of this library makes the combined work
  > licensed under GPLv3