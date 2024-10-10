// Author       : Zawaher Bin Asim , UET Lahore  <zawaherbinasim.333@gmail.com>
// Date         : 1 Oct 2024
// Description  : This file contains the wrapper of the vector_processor where datapath and controller  are connnected together 

`include "../define/vector_processor_defs.svh"

module vector_processor#(
    parameter SEW = 32
)(

    input   logic   clk,reset,
    
    // Inputs from the scaler processor  --> vector processor
    input   logic   [`XLEN-1:0] instruction,            // The instruction that is to be executed by the vector processor
    input   logic   [`XLEN-1:0] rs1_data,               // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs1 address
    input   logic   [`XLEN-1:0] rs2_data,               // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs2 address

     // scaler_procssor  --> val_ready_controller
    input   logic               inst_valid,             // tells data comming from the saler processor is valid
    input   logic               scalar_pro_ready,       // tells that scaler processor is ready to take output


    // Outputs from vector rocessor --> scaler processor
    output  logic               is_vec,                 // This tells the instruction is a vector instruction or not mean a legal insrtruction or not

    // Output from vector processor lsu --> memory
    output  logic               is_loaded,              // It tells that data is loaded from the memory and ready to be written in register file
    output  logic               ld_inst,                // tells that it is load insruction or store one
  
    //Inputs from main_memory -> vec_lsu
    input   logic   [SEW-1:0]   mem2lsu_data,           // data from the memory to lsu in case of load

    // Output from  vec_lsu -> main_memory
    output  logic   [`XLEN-1:0] lsu2mem_addr,           // address from lsu to memory in case of the load
    
    // csr_regfile -> scalar_processor
    output  logic   [`XLEN-1:0] csr_out,                // read data from the csr registers

    // valready_controller  --> scaler_processor 
    output  logic               vec_pro_ack,            // signal that tells that successfully implemented the previous instruction and ready to  take next iinstruction

    // val_ready_controller --> scaler_processor
    output  logic               vec_pro_ready           // tells that vector processor is ready to take the instruction

);


// vec_control_signals -> vec_decode
logic               vl_sel;             // selection for rs1_data or uimm
logic               vtype_sel;          // selection for rs2_data or zimm
logic               lumop_sel;          // selection lumop
logic               rs1rd_de;           // selection for VLMAX or comparator
logic               rs1_sel;            // selection for rs1_data


// vec_control_signals -> vec_csr
logic                csrwr_en;

// Vec_control_signals -> vec_registerfile
logic                vec_reg_wr_en;      // The enable signal to write in the vector register
logic                mask_operation;     // This signal tell this instruction is going to perform mask register update
logic                mask_wr_en;         // This the enable signal for updating the mask value
logic   [1:0]        data_mux1_sel;      // This the selsction of the mux to select between vec_imm , scaler1 , and vec_data1
logic                data_mux2_sel;      // This the selsction of the mux to select between scaler2 , and vec_data2

// vec_control_signals -> vec_lsu
logic                stride_sel;         // tells that  it is a unit stride or the indexed

// datapath --> val_ready_controller
logic                inst_done;


    vector_processor_datapth DATAPATH(
        
        .clk                (clk            ),
        .reset              (reset          ),
        
        // Inputs from the scaler processor  --> vector processor
        .instruction        (instruction    ),      
        .rs1_data           (rs1_data       ),
        .rs2_data           (rs2_data       ),

        // Outputs from vector rocessor --> scaler processor
        .is_vec             (is_vec         ),
        
        // Output from vector processor lsu --> memory
        .is_loaded          (is_loaded      ),        

        
        //Inputs from main_memory -> vec_lsu
        .mem2lsu_data       (mem2lsu_data   ),

        // Output from  vec_lsu -> main_memory
        .lsu2mem_addr       (lsu2mem_addr   ),

        // csr_regfile -> scalar_processor
        .csr_out            (csr_out        ),

        // datapth  --> val_ready_controller
        .inst_done          (inst_done      ),            

        // Inputs from the controller --> datapath
    
        // vec_control_signals -> vec_decode
        .vl_sel             (vl_sel         ),
        .vtype_sel          (vtype_sel      ),
        .lumop_sel          (lumop_sel      ),
        .rs1rd_de           (rs1rd_de       ),
        .rs1_sel            (rs1_sel        ),

        // vec_control_signals -> vec_csr_regs
        .csrwr_en           (csrwr_en       ),

        // vec_control_signals -> vec_register_file
        .vec_reg_wr_en      (vec_reg_wr_en  ),
        .mask_operation     (mask_operation ),
        .mask_wr_en         (mask_wr_en     ),
        .data_mux1_sel      (data_mux1_sel  ),
        .data_mux2_sel      (data_mux2_sel  ),

        // vec_control_signals -> vec_lsu
        .stride_sel         (stride_sel     ),
        .ld_inst            (ld_inst        ) 

        
    );


    vector_processor_controller CONTROLLER(
        
        // scalar_processor -> vector_extension
        .vec_inst           (instruction    ),

        // Output from  controller --> datapath

        // vec_control_signals -> vec_decode
        .vl_sel             (vl_sel         ),
        .vtype_sel          (vtype_sel      ),
        .lumop_sel          (lumop_sel      ),
        .rs1rd_de           (rs1rd_de       ),
        .rs1_sel            (rs1_sel        ),

        // vec_control_signals -> vec_csr_regs
        .csrwr_en           (csrwr_en       ),

        // vec_control_signals -> vec_register_file
        .vec_reg_wr_en      (vec_reg_wr_en  ),
        .mask_operation     (mask_operation ),
        .mask_wr_en         (mask_wr_en     ),
        .data_mux1_sel      (data_mux1_sel  ),
        .data_mux2_sel      (data_mux2_sel  ),

        // vec_control_signals -> vec_lsu
        .stride_sel         (stride_sel     ),
        .ld_inst            (ld_inst        ) 

    );


    val_ready_controller VAL_READY_INTERFACE(
    
    .clk                (clk                ),
    .reset              (reset              ),

    // scaler_procssor  --> val_ready_controller
    .inst_valid         (inst_valid         ),             // tells data comming from the saler processor is valid
    .scalar_pro_ready   (scalar_pro_ready   ),       // tells that scaler processor is ready to take output
    
    // val_ready_controller --> scaler_processor
    .vec_pro_ready      (vec_pro_ready      ),          // tells that vector processor is ready to take the instruction
    .vec_pro_ack        (vec_pro_ack        ),             // tells that the data comming from the vec_procssor is valid and done with the implementation of instruction 

    // datapath -->   val_ready_controller 
    .inst_done          (inst_done          )
);


endmodule










