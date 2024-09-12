`include "vector_processor_defs.svh"

`ifndef vec_regfile_defs
`define vec_regfile_defs

// LMUL to increase the venctor register length so that more vectors cna be stored  set it to 2 , 4   
`define LMUL 1

// The number of vectors that one vector register should store
`define LENGTH_OF_VECREG  256

// The number of vector registers the register file will have
parameter VECTOR_REGISTERS = (1/LMUL) * 32 ;

// This is the width of the vector register
parameter VLEN = `LMUL * LENGTH_OF_VECREG ;

// No of vector registers
// If LMUL is 2 the size of the vector register length increases but the number of the vector registers decreases by that factor
parameter NO_OF_VEC_REGISTERS = (1/`LMUL) * 32 ;


// The width of the address based on the architecture of the instruction
parameter   ADDR_WIDTH = `XLEN ;

parameter   DATA_WIDTH = VLEN ;


`endif