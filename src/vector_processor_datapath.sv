// Author       : Zawaher Bin Asim , UET Lahore  <zawaherbinasim.333@gmail.com>
// Date         : 23 Sep 2024
// Description  : This file contains the  datapath of the vector_processor where different units are connnected together 

`include "../define/vector_processor_defs.svh"
`include "../define/vec_regfile_defs.svh"

module vector_processor_datapth (
    
    input   logic   clk,reset,
    
    // Inputs from the scaler processor  --> vector processor
    input   logic   [`XLEN-1:0]             instruction,        // The instruction that is to be executed by the vector processor
    input   logic   [`XLEN-1:0]             rs1_data,           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs1 address
    input   logic   [`XLEN-1:0]             rs2_data,           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs2 address

    //Inputs from main_memory -> vec_lsu
    input   logic   [`XLEN-1:0]             mem2lsu_data,

    // Output from  vec_lsu -> main_memory
    output  logic   [`XLEN-1:0]             lsu2mem_addr,       // Gives the memory address to load or store data
    output  logic                           ld_req,             // load request signal to the memory
    //output  logic                           st_req,             // store request signal to the memory

    // Outputs from vector rocessor --> scaler processor
    output  logic                           is_vec,             // This tells the instruction is a vector instruction or not mean a legal insrtruction or not
    
    
    // csr_regfile -> scalar_processor
    output  logic   [`XLEN-1:0]             csr_out,            

    // datapth  --> scaler_processor 
    output  logic                           inst_done,          // signal that tells that successfully implemented the previous instruction and ready to  take next iinstruction


    // Inputs from the controller --> datapath
    
    // vec_control_signals -> vec_decode
    input   logic                           vl_sel,             // selection for rs1_data or uimm
    input   logic                           vtype_sel,          // selection for rs2_data or zimm
    input   logic                           lumop_sel,          // selection lumop
    input   logic                           rs1rd_de,           // selection for VLMAX or comparator
    input   logic                           rs1_sel,            // selection for rs1_data

    // vec_control_signals -> vec_csr_regs
    input   logic                           csrwr_en,

    // vec_control_signals -> vec_register_file
    input   logic                           vec_reg_wr_en,     // The enable signal to write in the vector register
    input   logic                           mask_operation,    // This signal tell this instruction is going to perform mask register update
    input   logic                           mask_wr_en,        // This the enable signal for updating the mask value

    input   logic   [1:0]                   data_mux1_sel,     // This the selsction of the mux to select between vec_imm , scaler1 , and vec_data1
    input   logic                           data_mux2_sel,     // This the selsction of the mux to select between scaler2 , and vec_data2

    // vec_control_signals -> vec_lsu
    input   logic                           stride_sel,         // tells that  it is a unit stride or the indexed
    input   logic                           ld_inst             // tells that it is load insruction or store one

);


// Read and Write address from Decode --> Vector Register file 
logic   [`XLEN-1:0] vec_read_addr_1  , vec_read_addr_2 , vec_write_addr;

// Vector Immediate from the decode 
logic   [`MAX_VLEN-1:0] vec_imm;

// signal that tells that if the masking is  enabled or not
logic  vec_mask;

// The enable  signal for the vec_register file after the load of the data from the memory
logic   vec_wr_en;

// The width of the memory element that has to be loaded from the memory
logic   [2:0] width;

// it tells the selection between  the floating point  and the integer
logic   mew;

// number of fields in case of the load
logic   [2:0] nf;

// vec-csr-dec -> vec-csr / vec-regfile
// The scaler output from the decode that could be imm ,rs1_data ,rs2_data and address in case of the load based on the instruction 
logic   [`XLEN-1:0] scalar1;
logic   [`XLEN-1:0] scalar2;

// Output from vector processor lsu --> lsu mux
logic                           is_loaded;              // It tells that data is loaded from the memory and ready to be written in register file

// The extended scaler 1 and scaler 2 upto MAX_VLEN
logic   [`MAX_VLEN-1:0] scaler1_extended ,scaler2_extended; 

// The vector data that is to be written\
logic   [`MAX_VLEN-1:0] vec_wr_data;

// vec_csr_regs ->
logic   [3:0]                   vlmul;                  // Gives the value of the lmul that is to used  in the procesor
logic   [6:0]                   sew;                    // Gives the standard element width 
logic   [9:0]                   vlmax;                  // the maximum number of elements vector will contain based on the lmul and sew and vlen
logic                           tail_agnostic;          // vector tail agnostic
logic                           mask_agnostic;          // vector mask agnostic
logic   [`XLEN-1:0]             vec_length;             // Gives the length of the vector onwhich maskng operation is to performed
logic   [`XLEN-1:0]             start_element;          // Gives the start elemnet of the vector from where the masking is to be started

 // Output from csr_reg--> datapath (done signal)
 logic                          csr_done;               // This signal tells that csr instruction has been implemented successfully

// vec_registerfile --> next moduels and data selection muxes
logic   [DATA_WIDTH-1:0]        vec_data_1, vec_data_2; // The read data from the vector register file
logic   [DATA_WIDTH-1:0]        dst_vec_data;           // The data of the destination register that is to be replaced with the data after the opertaion and masking
logic   [VECTOR_LENGTH-1:0]     vector_length;          // Width of the vector depending on LMUL
logic                           wrong_addr;             // Signal to indicate an invalid address
logic   [`VLEN-1:0]             v0_mask_data;           // The data of the mask register that is v0 in register file 
logic                           data_written;           // tells that data is written to the register file

// Outputs of the data selection muxes after register file
logic   [`MAX_VLEN-1:0]         data_mux1_out;          // selection between the vec_reg_data_1 , vec_imm , scalar1
logic   [`MAX_VLEN-1:0]         data_mux2_out;          // selection between the vec_reg_data_2 , scaler2



assign inst_done = data_written || csr_done;

             //////////////////////
            //      DECODE      //
           //////////////////////          

    vec_decode DECODER(
        // scalar_processor -> vec_decode
        .vec_inst           (instruction    ),
        .rs1_data           (rs1_data       ), 
        .rs2_data           (rs2_data       ),

        // vec_decode -> scalar_processor
        .is_vec             (is_vec         ),
        
        // vec_decode -> vec_regfile
        .vec_read_addr_1    (vec_read_addr_1),      
        .vec_read_addr_2    (vec_read_addr_2),      
        .vec_write_addr     (vec_write_addr ),      
        .vec_imm            (vec_imm        ),
        .vec_mask           (vec_mask       ),

        // vec_decode -> vector load
        .width              (width          ),             
        .mew                (mew            ),             
        .nf                 (nf             ),                       

        // vec_decode -> csr 
        .scalar2            (scalar2        ),             
        .scalar1            (scalar1        ),             

        // vec_control_signals -> vec_decode
        .vl_sel             (vl_sel         ),             
        .vtype_sel          (vtype_sel      ),             
        .lumop_sel          (lumop_sel      ),             
        .rs1rd_de           (rs1rd_de       ),             
        .rs1_sel            (rs1_sel        )              
    );


             /////////////////////
            //   CSR REGFILE   //
           /////////////////////


    vec_csr_regfile CSR_REGFILE(
        .clk                    (clk            ),
        .n_rst                  (reset          ),

        // scalar_processor -> csr_regfile
        .inst                   (instruction   ),

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
        .vlmax                  (vlmax          ),
        .tail_agnostic          (tail_agnostic  ), 
        .mask_agnostic          (mask_agnostic  ), 

        .vec_length             (vec_length     ),
        .start_element          (start_element  ),

        .csr_done               (csr_done       )
    );



             /////////////////////
            //   VEC REGFILE   //
           /////////////////////


    vec_regfile VEC_REGFILE(
        // Inputs
        .clk            (clk            ), 
        .reset          (reset          ),
        .raddr_1        (vec_read_addr_1), 
        .raddr_2        (vec_read_addr_2),  
        .wdata          (vec_wr_data    ),          
        .waddr          (vec_write_addr ),
        .wr_en          (vec_wr_en      ), 
        .lmul           (vlmul          ),
        .mask_operation (mask_operation ), 
        .mask_wr_en     (mask_wr_en     ),                                                
        
        // Outputs 
        .rdata_1        (vec_data_1     ),
        .rdata_2        (vec_data_2     ),
        .dst_data       (dst_vec_data   ),
        .vector_length  (vector_length  ),
        .wrong_addr     (wrong_addr     ),
        .v0_mask_data   (v0_mask_data   ),
        .data_written   (data_written   )  
    );


             /////////////////////
            //    DATA_1 MUX   //
           /////////////////////

     // Zero-extend  scalar1 dynamically
    assign scaler1_extended = {{`MAX_VLEN-`XLEN{1'b0}}, scalar1[`XLEN-1:0]};

    
    // Zero-extend  scalar1 dynamically
    assign scaler2_extended = {{`MAX_VLEN-`XLEN{1'b0}}, scalar2[`XLEN-1:0]};

    

    data_mux_3x1 #(.width(`MAX_VLEN)) DATA1_MUX( 
        
        .operand1       (vec_data_1         ),
        .operand2       (scaler1_extended   ),
        .operand3       (vec_imm            ),
        .sel            (data_mux1_sel      ),
        .mux_out        (data_mux1_out      )     
    );

             /////////////////////
            //    DATA_2 MUX   //
           /////////////////////

    data_mux_2x1 #(.width(`MAX_VLEN)) DATA2_MUX( 
        
        .operand1       (vec_data_2         ),
        .operand2       (scaler2_extended   ),
        .sel            (data_mux2_sel      ),
        .mux_out        (data_mux2_out      )     
    );

             //////////////////////
            //      VLSU        //
           //////////////////////          


    vec_lsu VLSU(
        .clk            (clk                        ),
        .n_rst          (reset                      ),

        // scalar-processor -> vec_lsu
        .rs1_data       (data_mux1_out[`XLEN-1:0]   ),  
        .rs2_data       (data_mux2_out[`XLEN-1:0]   ),

        // vector_processor_controller -> vec_lsu
        .stride_sel     (stride_sel                 ), 
        .ld_inst        (ld_inst                    ),      

        // vec_decode -> vec_lsu
        .mew            (mew                        ),          
        .width          (width                      ),

        // vec_csr --> vec_lsu
        .sew            (sew                        ),
        .vlmax          (vlmax                      ),      

        // vec_lsu -> main_memory
        .lsu2mem_addr   (lsu2mem_addr               ),
        .ld_req         (ld_req                     ),
      //.st_req         (st_req                     ),

        // main_memory -> vec_lsu
        .mem2lsu_data   (mem2lsu_data               ),

        // vec_lsu  -> vec_register_file
        .vd_data        (vec_wr_data                ), 
        .is_loaded      (is_loaded                  )  
    );


    data_mux_2x1 #(.width(1'b1)) VLSU_DATA_MUX(
        
        .operand1       (1'b0             ),
        .operand2       (vec_reg_wr_en    ),
        .sel            (is_loaded        ),
        .mux_out        (vec_wr_en        )     
    
    );
    




endmodule


module data_mux_2x1 #(
   parameter width = 32
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


module data_mux_3x1 #(
   parameter width = 32
) ( 
    
    input   logic   [width-1:0] operand1,
    input   logic   [width-1:0] operand2,
    input   logic   [width-1:0] operand3,
    input   logic   [1:0]       sel,
    output  logic   [width-1:0] mux_out     
);
    always_comb begin 
        case (sel)
           2'b00 : mux_out = operand1;
           2'b01 : mux_out = operand2;
           2'b10 : mux_out = operand3;
            default: mux_out = 'h0;
        endcase        
    end
    
endmodule