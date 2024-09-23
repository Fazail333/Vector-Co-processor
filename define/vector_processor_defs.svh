`ifndef vector_processor_defs
`define vector_processor_defs

// The architecture of the processor 32 bit or 64 bit 
`define XLEN 32
 
// The width of the vector register in the register file inspite of the lmul  
`define VLEN 512
// The width of the data signals . it depends  upon the "VLEN * max(lmul)" here the max of lmul is 8 
`define MAX_VLEN 4096

`endif
