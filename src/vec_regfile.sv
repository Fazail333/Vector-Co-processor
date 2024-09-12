//Author        : Zawaher Bin Asim , UET Lahore
//Description   : This the register file of the vector processor
// Date         : 7 Sep, 2024.

`include "vec_regfile_defs.svh"

module vec_regfile (
    // Inputs
    input   logic                       clk,reset,
    input   logic   [ADDR_WIDTH-1:0]    raddr_1,raddr_2,                // The address of the vector registers to be read for the elements of the vectors
    input   logic   [DATA_WIDTH-1:0]    wdata,                          // The vector that is to be written in the vector register
    input   logic   [ADDR_WIDTH-1:0]    waddr,                          // The address of the vector register where the vector is written
    input   logic                       wr_en,                          // The enable signal to write in the vector register 

    // Outputs 
    output  logic   [DATA_WIDTH-1:0]    rdata_1,rdata_2                 // The read data from the vector register file 
);

// Vector Register File 
logic   [VLEN-1:0]vec_regfile[NO_OF_VEC_REGISTERS-1:0];


// This always block is for the data read from the vector register file 
always_comb begin    

    rdata_1 = vec_regfile[raddr_1];
    rdata_2 = vec_regfile[raddr_2];

end

// This alaways block implementing the write logic to the vector register file 
// we are writing at the negative edge of the clk 
// The logic behind is that when data comes from the lanes on the positive edge of the cycle it will be written back on the negedge of the same cycle . In this way we save one cycle 
always_ff @( negedge clk or negedge reset ) begin 
    if (!reset)begin

        for (int i = 0 ; i < NO_OF_VEC_REGISTERS ; i++)begin
            vec_regfile[i] <= 'h0;
        end

    end

    else begin
        
        if(wr_en)begin

            vec_regfile[waddr] <= wdata;
        
        end

    end

end
    
endmodule