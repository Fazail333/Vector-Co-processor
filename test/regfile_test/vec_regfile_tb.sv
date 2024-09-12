//Author        : Zawaher Bin Asim , UET Lahore
//Description   : This the test bench to test register file of the vector processor
// Date         : 8 Sep, 2024.

`include "vec_regfile_defs.svh"

module vec_regfile_tb;


logic   clk ,reset;
logic   [ADDR_WIDTH-1:0]raddr_1,raddr_2; 
logic   wdata; 

vec_regfile (
    // Inputs
    input   logic                       clk,reset,
    input   logic   [ADDR_WIDTH-1:0]    raddr_1,raddr_2,                // The address of the vector registers to be read for the elements of the vectors
    input   logic   [DATA_WIDTH-1:0]    wdata,                          // The vector that is to be written in the vector register
    input   logic   [ADDR_WIDTH-1:0]    waddr,                          // The address of the vector register where the vector is written
    input   logic                       wr_en,                          // The enable signal to write in the vector register 

    // Outputs 
    output  logic   [DATA_WIDTH-1:0]    rdata_1,rdata_2                 // The read data from the vector register file 
);



endmodule