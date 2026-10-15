# RAM128 SystemVerilog Testbench

A 128 x 8-bit RAM built from four 32 x 8 blocks, verified with a class-based SystemVerilog testbench.

## Design (design.sv)
- `ram32`: 32 x 8 memory with write enable and block enable
- `ram128`: four `ram32` blocks; the upper 2 address bits select the block

## Testbench (testbench.sv)
Generator -> mailbox -> Driver -> DUT -> Monitor -> mailbox -> Scoreboard

- Interface with a virtual interface handle in the classes
- Randomized transactions covering all 4 RAM blocks
- Scoreboard with a reference memory model; prints FAIL for mismatches and a final summary

## How to run
1. Open https://www.edaplayground.com
2. Paste `design.sv` into the design window and `testbench.sv` into the testbench window
3. Choose Verilator and click Run

Expected output: `SUMMARY: pass=... fail=0`

## Notes
This is a learning project. The free simulator used here has no constraint solver, so `post_randomize()` is used instead of `constraint` blocks. Constrained-random with `constraint`, functional coverage and UVM are the next steps.
