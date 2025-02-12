// Author       : Zawaher Bin Asim , UET Lahore  <zawaherbinasim.333@gmail.com>
// Date         : 1 Oct 2024
// Description  : This file contains the wrapper of the vector_processor where datapath and controller  are connnected together 

`include "../define/vector_processor_defs.svh"

module vector_processor(
    
    input   logic   clk,reset,
    
    // Inputs from the scaler processor  --> vector processor
    input   logic   [`XLEN-1:0]         instruction,            // The instruction that is to be executed by the vector processor
    input   logic   [`XLEN-1:0]         rs1_data,               // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs1 address
    input   logic   [`XLEN-1:0]         rs2_data,               // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs2 address

     // scaler_procssor  --> val_ready_controller
    input   logic                       inst_valid,             // tells data comming from the saler processor is valid
    input   logic                       scalar_pro_ready,       // tells that scaler processor is ready to take output


    // Outputs from vector processor --> scaler processor
    output  logic                       is_vec,                 // This tells the instruction is a vector instruction or not mean a legal insrtruction or not

    // Output from vector processor lsu --> memory
    output  logic   [`XLEN-1:0]         lsu2mem_addr,           // Gives the memory address to load or store data
    output  logic                       ld_req,                 // load request signal to the memory
    output  logic                       st_req,                 // store request signal to the memory
    output  logic   [`DATA_BUS-1:0]     lsu2mem_data,           // Data to be stored
    output  logic   [WR_STROB-1:0]      wr_strobe,              // THE bytes of the DATA_BUS that contains the actual data 


    //Inputs from main_memory -> vec_lsu
    input   logic   [`DATA_BUS-1:0]     mem2lsu_data,           // data from the memory to lsu in case of load

    
    // csr_regfile -> scalar_processor
    output  logic   [`XLEN-1:0]         csr_out,                // read data from the csr registers

    // valready_controller  --> scaler_processor 
    output  logic                       vec_pro_ack,            // signal that tells that successfully implemented the previous instruction and ready to  take next iinstruction

    // val_ready_controller --> scaler_processor
    output  logic                       vec_pro_ready           // tells that vector processor is ready to take the instruction

);


// vec_control_signals -> vec_decode
logic               vl_sel;             // selection for rs1_data or uimm
logic               vtype_sel;          // selection for rs2_data or zimm
logic               lumop_sel;          // selection lumop
logic               rs1rd_de;           // selection for VLMAX or comparator
logic               rs1_sel;            // selection for rs1_data


// vec_control_signals -> vec_csr
logic                csrwr_en;
logic                sew_eew_sel;       // selection for sew_eew mux
logic                vlmax_evlmax_sel;  // selection for vlmax_evlmax
logic                emul_vlmul_sel;    // selection for vlmul_emul m

// Vec_control_signals -> vec_registerfile
logic                vec_reg_wr_en;      // The enable signal to write in the vector register
logic                mask_operation;     // This signal tell this instruction is going to perform mask register update
logic                mask_wr_en;         // This the enable signal for updating the mask value
logic   [1:0]        data_mux1_sel;      // This the selsction of the mux to select between vec_imm , scaler1 , and vec_data1
logic                data_mux2_sel;      // This the selsction of the mux to select between scaler2 , and vec_data2
logic                offset_vec_en;      // Tells the rdata2 vector is offset vector and will be chosen on base of emul
// vec_control_signals -> vec_lsu
logic                stride_sel;         // tells that  it is a unit stride or the constant stride
logic                ld_inst;            // tells about load instruction
logic                st_inst;            // tells about store instruction
logic                index_str;          // tells about indexed strided load/store
logic                index_unordered;    // tells about index unordered stride
// datapath --> val_ready_controller
logic                inst_done;

// val_ready_controller --> datapath
logic               inst_reg_en;

// Instruction Register --> datapath
logic   [`XLEN-1:0]         inst_reg_instruction;            // The instruction that is to be executed by the vector processor
logic   [`XLEN-1:0]         inst_reg_rs1_data;               // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs1 address
logic   [`XLEN-1:0]         inst_reg_rs2_data;               // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs2 address

    vector_processor_datapth DATAPATH(
        
        .clk                (clk            ),
        .reset              (reset          ),
        
        // Inputs from the scaler processor  --> vector processor
        .instruction        (inst_reg_instruction),      
        .rs1_data           (inst_reg_rs1_data   ),
        .rs2_data           (inst_reg_rs2_data   ),

        // Outputs from vector rocessor --> scaler processor
        .is_vec             (is_vec         ),
        
        // Output from vector processor lsu --> memory
        .lsu2mem_addr       (lsu2mem_addr   ),           
        .ld_req             (ld_req         ),                 
        .st_req             (st_req         ),                 
        .lsu2mem_data       (lsu2mem_data   ),       
        .wr_strobe          (wr_strobe      ),       

        
        //Inputs from main_memory -> vec_lsu
        .mem2lsu_data       (mem2lsu_data   ),

       
        // csr_regfile -> scalar_processor
        .csr_out            (csr_out        ),

        // datapth  --> val_ready_controller
        .inst_done          (inst_done      ),            

        // Inputs from the controller --> datapath
        .sew_eew_sel        (sew_eew_sel     ),
        .vlmax_evlmax_sel   (vlmax_evlmax_sel),
        .emul_vlmul_sel     (emul_vlmul_sel  ),

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
        .offset_vec_en      (offset_vec_en  ),

        // vec_control_signals -> vec_lsu
        .stride_sel         (stride_sel     ),
        .ld_inst            (ld_inst        ),
        .st_inst            (st_inst        ),
        .index_str          (index_str      ), 
        .index_unordered    (index_unordered)
        
    );


    vector_processor_controller CONTROLLER(
        
        // scalar_processor -> vector_extension
        .vec_inst           (inst_reg_instruction),

        // Output from  controller --> datapath

        // vec_control_signals -> vec_decode
        .vl_sel             (vl_sel         ),
        .vtype_sel          (vtype_sel      ),
        .lumop_sel          (lumop_sel      ),
        .rs1rd_de           (rs1rd_de       ),
        .rs1_sel            (rs1_sel        ),

        // vec_control_signals -> vec_csr_regs
        .csrwr_en           (csrwr_en        ),
        .sew_eew_sel        (sew_eew_sel     ),
        .vlmax_evlmax_sel   (vlmax_evlmax_sel),
        .emul_vlmul_sel     (emul_vlmul_sel  ),

        // vec_control_signals -> vec_register_file
        .vec_reg_wr_en      (vec_reg_wr_en  ),
        .mask_operation     (mask_operation ),
        .mask_wr_en         (mask_wr_en     ),
        .data_mux1_sel      (data_mux1_sel  ),
        .data_mux2_sel      (data_mux2_sel  ),
        .offset_vec_en      (offset_vec_en  ),

        // vec_control_signals -> vec_lsu
        .stride_sel         (stride_sel     ),
        .ld_inst            (ld_inst        ),
        .st_inst            (st_inst        ),
        .index_str          (index_str      ),
        .index_unordered    (index_unordered)

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

instruction_data_queue INS_DATA_QUEUE(
    .clk                    (clk                ),
    .reset                  (reset              ),
    // Scaler Processor --> Queue 
    .inst_valid             (inst_valid         ), 
    .instruction            (instruction        ), 
    .rs1_data               (rs1_data           ), 
    .rs2_data               (rs2_data           ),  
    
     // VAL_READY_Controller --> Queue
    .vec_pro_ready          (vec_pro_ready      ),  
    
    // Queue --> Vector Processor
    .inst_reg_instruction   (inst_reg_instruction), 
    .inst_reg_rs1_data      (inst_reg_rs1_data   ), 
    .inst_reg_rs2_data      (inst_reg_rs2_data   )  
);

endmodule


/*
Logic Description:

    Bypass Cases:
        Simultaneous Assertion: If inst_valid and vec_pro_ready are asserted in the same cycle, bypass the queue and directly output the data.
        vec_pro_ready Asserted Before inst_valid: If vec_pro_ready was asserted first, 
        and inst_valid is asserted later, bypass the queue and directly output the current data.

    Enqueue Case:
        If inst_valid is asserted and vec_pro_ready is not, enqueue the instruction and data.

    Dequeue Case:
        If inst_valid is already asserted (data is in the queue), and vec_pro_ready becomes asserted, dequeue and output the instruction and data.

*/
module instruction_data_queue #(

    parameter DEPTH = 2    // Queue depth
) (
    input  logic                clk,
    input  logic                reset,
    // Scaler Processor --> Queue 
    input  logic                inst_valid,       // Instruction valid
    input  logic [`XLEN-1:0]    instruction,      // Instruction input
    input  logic [`XLEN-1:0]    rs1_data,         // RS1 data
    input  logic [`XLEN-1:0]    rs2_data,         // RS2 data
    
     // VAL_READY_Controller --> Queue
    input  logic                 vec_pro_ready,   // Vector processor ready
    
    // Queue --> Vector Processor
    output logic [`XLEN-1:0]    inst_reg_instruction,     // Output instruction
    output logic [`XLEN-1:0]    inst_reg_rs1_data,        // Output RS1 data
    output logic [`XLEN-1:0]    inst_reg_rs2_data         // Output RS2 data
);

    logic [`XLEN-1:0]    inst_out_instruction;     // Dummy Output instruction
    logic [`XLEN-1:0]    inst_out_rs1_data;        // Dummy Output RS1 data
    logic [`XLEN-1:0]    inst_out_rs2_data;        // Dummy Output RS2 data

    // FIFO storage for instructions and data
    typedef struct packed {
        logic [`XLEN-1:0] instruction;
        logic [`XLEN-1:0] rs1_data;
        logic [`XLEN-1:0] rs2_data;
    } queue_entry_t;

    queue_entry_t fifo [DEPTH-1:0];

    logic [$clog2(DEPTH):0] write_ptr, read_ptr;
    logic [$clog2(DEPTH+1):0] count;

    // Status flags
    wire full  = (count == DEPTH);
    wire empty = (count == 0);

    // Handshake signal
    logic inst_accepted;
    logic inst_ready;

     // Bypass signals
    logic bypass;
    logic inst_valid_seen;  // Tracks whether inst_valid has been asserted

    always_ff @( posedge clk or negedge clk ) begin 
        if (!reset)begin
            inst_valid_seen <= 1'b0;
        end
        else begin
            if (inst_valid && !vec_pro_ready)begin
                inst_valid_seen <= 1'b1;
            end
            else begin
                inst_valid_seen <= 1'b0;
            end
        end
        
    end


    assign bypass = (inst_valid && vec_pro_ready && !inst_valid_seen);

    // Output logic with bypass handling
   always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            inst_out_instruction <= 0;
            inst_out_rs1_data    <= 0;
            inst_out_rs2_data    <= 0;
            read_ptr             <= 0;
        end else if (bypass) begin
            // Directly bypass the input instruction and data to output
            inst_out_instruction <= instruction;
            inst_out_rs1_data    <= rs1_data;
            inst_out_rs2_data    <= rs2_data;
        end else if (!empty && vec_pro_ready) begin
            // Update read pointer and prepare for next cycle
            read_ptr <= read_ptr + 1;
            count    <= count - 1;
        end
    end

    // Combinational output logic for immediate dequeued data
    always_comb begin
        if (bypass) begin
            // Directly pass the input instruction and data to the output
            inst_reg_instruction = instruction;
            inst_reg_rs1_data    = rs1_data;
            inst_reg_rs2_data    = rs2_data;
        end else if (!empty && vec_pro_ready) begin
            // Directly use the data from the queue for immediate output
            inst_reg_instruction = fifo[read_ptr].instruction;
            inst_reg_rs1_data    = fifo[read_ptr].rs1_data;
            inst_reg_rs2_data    = fifo[read_ptr].rs2_data;
        end else begin
            // Hold the current values
            inst_reg_instruction = inst_out_instruction;
            inst_reg_rs1_data    = inst_out_rs1_data;
            inst_reg_rs2_data    = inst_out_rs2_data;
        end
    end

    // Enqueue logic
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            write_ptr <= 0;
            count <= 0;
            inst_accepted <= 0;
        end else begin
            if (inst_valid && inst_ready && !inst_accepted) begin
                // Store the instruction and data in the queue
                fifo[write_ptr].instruction <= instruction;
                fifo[write_ptr].rs1_data    <= rs1_data;
                fifo[write_ptr].rs2_data    <= rs2_data;
                write_ptr <= write_ptr + 1;
                count <= count + 1;

                // Mark instruction as accepted
                inst_accepted <= 1;
            end else if (!inst_valid) begin
                // Reset the accepted flag when inst_valid deasserts
                inst_accepted <= 0;
            end
        end
    end

    
   
    assign inst_ready = !full && !vec_pro_ready;
    
endmodule









