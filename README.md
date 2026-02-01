# rv32im
My implementation of RV32IM CPU
This is a s**tbox, so this repo is meant for only archiving the code. The implementation is not complete and not all timings have been tested, so there might be bugs in executing some specific instruction sequences.

## What's included?

 - Instructions from RV32I except the one related to Control and Status Register.
 - M-Extension instructions
 - 5-stage pipeline
 - Not-so-good branch predicion (optimization in JAL/JALR and mapping is needed)
 - Hazard Dealing

## What's needed to run this?

You need the vivado as developing environment and add a `Timing Wizard` IP as clock divider(which is used to make it work on the EGO1 FPGA board which has 100 MHz clock input).

Modify the Instruction Mem initialization hex file (hex machine code without the 0x leading lay in there) path in `rv32i.v` and simulation Verilog file.
