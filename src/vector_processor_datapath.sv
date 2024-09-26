// Author       : Zawaher Bin Asim , UET Lahore
// Date         : 23 Sep 2024
// Description  : This file contains the  datapath of the vector_processor where different units are connnected together 

`include "vector_processor_defs.svh"

module vector_processor_datapth (
    
    input   logic   clk,reset,
    
    // Inputs from the scaler processor 
    input   logic   [`XLEN-1:0] instruction,        // The instruction that is to be executed by the vector processor
    input   logic   [`XLEN-1:0] scaler_input,       // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file

);










vec_regfile VEC_REGISTER_FILE(
    // Inputs
    input   logic                           clk, reset,
    input   logic   [ADDR_WIDTH-1:0]        raddr_1, raddr_2,  // The address of the vector registers to be read
    input   logic   [DATA_WIDTH-1:0]        wdata,             // The vector that is to be written in the vector register
    input   logic   [ADDR_WIDTH-1:0]        waddr,             // The address of the vector register where the vector is written
    input   logic                           wr_en,             // The enable signal to write in the vector register 
    input   logic   [3:0]                   lmul,              // LMUL value (controls register granularity)

    // Outputs 
    output  logic   [DATA_WIDTH-1:0]        rdata_1, rdata_2,  // The read data from the vector register file
    output  logic   [DATA_WIDTH-1:0]        dst_data,          // The data of the destination register that is to be replaced with the data after the opertaion and masking
    output  logic   [VECTOR_LENGTH-1:0]     vector_length,     // Width of the vector depending on LMUL
    output  logic                           wrong_addr         // Signal to indicate an invalid address
);





    
endmodule
