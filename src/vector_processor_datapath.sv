// Author       : Zawaher Bin Asim , UET Lahore
// Date         : 23 Sep 2024
// Description  : This file contains the  datapath of the vector_processor where different units are connnected together 

`include "../define/vector_processor_defs.svh"
`include "../define/vec_regfile_defs.svh"

module vector_processor_datapth (
    
    input   logic   clk,reset,
    
    // Inputs from the scaler processor  --> vector processor
    input   logic   [`XLEN-1:0] instruction,        // The instruction that is to be executed by the vector processor
    input   logic   [`XLEN-1:0] rs1_data,           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs1 address
    input   logic   [`XLEN-1:0] rs2_data,           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs2 address

    // Outputs from vector rocessor --> scaler processor
    output  logic               is_vec,             // This tells the instruction is a vector instruction or not mean a legal insrtruction or not
    
    // csr_regfile -> scalar_processor
    output  logic   [`XLEN-1:0] csr_out,            // 


    // Inputs from the controller --> datapath
    
    // vec_control_signals -> vec_decode
    input   logic               vl_sel,             // selection for rs1_data or uimm
    input   logic               vtype_sel,          // selection for rs2_data or zimm
    input   logic               lumop_sel,          // selection lumop
    input   logic               rs1rd_de,           // selection for VLMAX or comparator
    input   logic               rs1_sel             // selection for rs1_data

    // vec_control_signals -> vec_csr_regs
    input   logic               csrwr_en,

    // vec_control_signals -> vec_register_file
    input   logic                vec_reg_wr_en,     // The enable signal to write in the vector register
    input   logic                mask_operation,    // This signal tell this instruction is going to perform mask register update
    input   logic                mask_wr_en         // This the enable signal for updating the mask value

    input   logic   [1:0]        data_mux1_sel,     // This the selsction of the mux to select between vec_imm , scaler1 , and vec_data1
    input   logic                data_mux2_sel,     // This the selsction of the mux to select between scaler2 , and vec_data2


);

// Read and Write address from Decode --> Vector Register file 
logic   [`XLEN-1:0] vec_read_addr_1  , vec_read_addr_2 , vec_write_addr;

// Vector Immediate from the decode 
logic   [`MAX_VLEN-1:0] vec_imm;

// signal that tells that if the masking is  enabled or not
logic  vec_mask;

// The width of the memory element that has to be loaded from the memory
logic   [2:0] width;

// it tells the selection between  the floating point  and the integer
logic   mew;

// number of fields in case of the load
logic   [2:0] nf;

// vec-csr-dec -> vec-csr / vec-regfile
// The scaler output from the decode that could be imm ,rs1_data ,rs2_data and address in case of the load based on the instruction 
logic   [XLEN-1:0] scalar1;
logic   [XLEN-1:0] scalar2;

// vec_csr_regs ->
logic   [3:0]                   vlmul;                  // Gives the value of the lmul that is to used  in the procesor
logic   [5:0]                   sew;                    // Gives the standard element width 
logic                           tail_agnostic;          // vector tail agnostic
logic                           mask_agnostic;          // vector mask agnostic
logic   [`XLEN-1:0]             vec_length;             // Gives the length of the vector onwhich maskng operation is to performed
logic   [`XLEN-1:0]             start_element;          // Gives the start elemnet of the vector from where the masking is to be started

// vec_registerfile --> next moduels and data selection muxes
logic   [DATA_WIDTH-1:0]        vec_data_1, vec_data_2; // The read data from the vector register file
logic   [DATA_WIDTH-1:0]        dst_vec_data;           // The data of the destination register that is to be replaced with the data after the opertaion and masking
logic   [VECTOR_LENGTH-1:0]     vector_length;          // Width of the vector depending on LMUL
logic                           wrong_addr;             // Signal to indicate an invalid address
logic   [`VLEN-1:0]             v0_mask_data;           // The data of the mask register that is v0 in register file 

// Outputs of the data selection muxes after register file
logic   [`MAX_VLEN-1:0]         data_mux1_out,          // selection between the vec_reg_data_1 , vec_imm , scalar1
logic   [`MAX_VLEN-1:0]         data_mux2_out,          // selection between the vec_reg_data_2 , scaler2


             //////////////////////
            //      DECODE      //
           //////////////////////          

    vec_decode(
        // scalar_processor -> vec_decode
        .vec_inst(instruction),
        .rs1_data(rs1_data), 
        .rs2_data(rs2_data),

        // vec_decode -> scalar_processor
        .is_vec(is_vec),
        
        // vec_decode -> vec_regfile
        .vec_read_addr_1(vec_read_addr_1),        // vs1_addr
        .vec_read_addr_2(vec_read_addr_2),        // vs2_addr
        .vec_write_addr(vec_write_addr),         // vd_addr
        .vec_imm(vec_imm),
        .vec_mask(vec_mask),

        // vec_decode -> vector load
        .width(width),                  // width of memory element
        .mew(mew),                    // selection bwtween fp or integer
        .nf(nf),                     // number of fields          

        // vec_decode -> csr 
        .scalar2(scalar2),               // vector type or rs2
        .scalar1(scalar1),               // vector length or rs1 (base address)

        // vec_control_signals -> vec_decode
        .vl_sel(vl_sel),                 // selection for rs1_data or uimm
        .vtype_sel(vtype_sel),              // selection for rs2_data or zimm
        .lumop_sel(lumop_sel),              // selection lumop
        .rs1rd_de(rs1rd_de),               // selection for VLMAX or comparator
        .rs1_sel(rs1_sel)                 // selection for rs1_data
    );


             /////////////////////
            //   CSR REGFILE   //
           /////////////////////


    vec_csr_regfile (
        .clk                    (clk            ),
        .n_rst                  (reset          ),

        // scalar_processor -> csr_regfile
        .inst                   (insrtruction   ),

        // csr_regfile -> scalar_processor
        .csr_out                (csr_out        ),

        // vec_decode -> vec_csr_regs
        .scalar2                (scalar2        ), 
        .scalar1                (scalar1        ), 

        // vec_control_signals -> vec_csr_regs
        .csrwr_en               (csrwr_en       ),

        // vec_csr_regs ->
        .vlmul                  (vlmul          ),
        .sew                    (sew            ),
        .tail_agnostic          (tail_agnostic  ), 
        .mask_agnostic          (mask_agnostic  ), 

        .vec_length             (vec_length     ),
        .start_element          (start_element  )
    );



             /////////////////////
            //   VEC REGFILE   //
           /////////////////////


    vec_regfile (
        // Inputs
        .clk            (clk            ), 
        .reset          (reset          ),
        .raddr_1        (vec_read_addr_1), 
        .raddr_2        (vec_read_addr_2),  
        wdata,          
        .waddr          (vec_write_addr ),
        .wr_en          (vec_reg_wr_en  ), 
        .lmul           (vlmul          ),
        .mask_operation (mask_operation ), 
        .mask_wr_en     (mask_wr_en     ),                                                
        
        // Outputs 
        .rdata_1        (vec_data_1     ),
        .rdata_2        (vec_data_2     ),
        .dst_data       (dst_vec_data   ),
        .vector_length  (vector_length  ),
        .wrong_addr     (wrong_addr     ),
        .v0_mask_data   (v0_mask_data   )  
    );


             /////////////////////
            //    DATA_1 MUX   //
           /////////////////////

     // Zero-extend or truncate scalar1 dynamically
    assign scaler1_extended = { {(MAX_VLEN-$bits(scalar1)){1'b0}}, scalar1[$bits(scalar1)-1:0] };

    // $bits() tells the number of bits of the data
    // Zero-extend or truncate scalar1 dynamically
    assign scaler2_extended = { {(MAX_VLEN-$bits(scalar2)){1'b0}}, scalar2[$bits(scalar2)-1:0] };

    // Zero-extend or truncate vec_imm dynamically
    assign vec_imm_extended = { {(MAX_VLEN-$bits(vec_imm)){1'b0}}, vec_imm[$bits(vec_imm)-1:0] };


    mux3x1 #(.width(MAX_VLEN))( 
        
        .operand1       (vec_data_1         ),
        .operand2       (scaler1_extended   ),
        .operand3       (vec_imm_extended   ),
        .sel            (data_mux1_sel      ),
        .mux_out        (data_mux1_out      )     
    );

             /////////////////////
            //    DATA_2 MUX   //
           /////////////////////

    mux2x1 #(.width(MAX_VLEN)) ( 
        
        .operand1       (vec_data_2         ),
        .operand2       (scaler2_extended   ),
        .sel            (data_mux2_sel      ),
        .mux_out        (data_mux2_out      )     
    );

    




endmodule


module mux2x1 #(
   parameter width = 32;
) ( 
    
    input   logic   [width-1:0] operand1,
    input   logic   [width-1:0] operand2,
    input   logic               sel,
    output  logic   [width-1:0] mux_out     
);
    always_comb begin 
        case (sel)
           1'b0 : mux_out = operand1;
           1'b1 : mux_out = operand2;
            default: mux_out = 'h0;
        endcase        
    end
    
endmodule


module mux3x1 #(
   parameter width = 32;
) ( 
    
    input   logic   [width-1:0] operand1,
    input   logic   [width-1:0] operand2,
    input   logic   [width-1:0] operand3,
    input   logic   [1:0]       sel,
    output  logic   [width-1:0] mux_out     
);
    always_comb begin 
        case (sel)
           1'b00 : mux_out = operand1;
           1'b01 : mux_out = operand2;
           1'b10 : mux_out = operand3;
            default: mux_out = 'h0;
        endcase        
    end
    
endmodule