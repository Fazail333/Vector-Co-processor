// Author       : Zawaher Bin Asim , UET Lahore
// Date         : 1 Oct 2024
// Description  : This file contains the testbench of the vector_processor


`include "../define/vector_processor_defs.svh"

module vector_processor_tb ();


// Depth of the instruction memory 
parameter  depth = 512;
parameter   SEW  = 32;

logic   clk,reset;
        
// Inputs from the scaler processor  --> vector processor
logic   [`XLEN-1:0] instruction;        // The instruction that is to be executed by the vector processor
logic   [`XLEN-1:0] rs1_data;           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs1 address
logic   [`XLEN-1:0] rs2_data;           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs2 address

// Outputs from vector rocessor --> scaler processor
logic               is_vec;             // This tells the instruction is a vector instruction or not mean a legal insrtruction or not
        
// Output from vector processor lsu --> memory
logic               is_loaded;          // It tells that data is loaded from the memory and ready to be written in register file
logic               ld_inst;            // tells that it is load insruction or store one
  
// csr_regfile -> scalar_processor
logic   [`XLEN-1:0] csr_out;            

// addresses of the scaler register
logic   [4:0]       rs1_addr;
logic   [4:0]       rs2_addr;

 //Inputs from main_memory -> vec_lsu
logic   [SEW-1:0]   mem2lsu_data;

    // Output from  vec_lsu -> main_memory
logic   [`XLEN-1:0] lsu2mem_addr;
   
// Register file to hold scalar register values (can be initialized as needed)
logic [`XLEN-1:0] scalar_regfile [31:0];

// Instruction memory
logic [`XLEN-1:0] inst_mem[depth-1:0];

//  Dummy Memory for testing
logic [7:0]dummy_mem[depth-1:0];




    vector_processor VECTOR_PROCESSOR(

        .clk            (clk        ),
        .reset          (reset      ),
        
        // Inputs from the scaler processor  --> vector processor
        .instruction    (instruction),
        .rs1_data       (rs1_data   ),
        .rs2_data       (rs2_data   ),

        // Outputs from vector rocessor --> scaler processor
        .is_vec         (is_vec     ),

        // Output from vector processor lsu --> memory
        .is_loaded      (is_loaded  ),        
        .ld_inst        (ld_inst    ), 
        
        //Inputs from main_memory -> vec_lsu
        .mem2lsu_data   (mem2lsu_data),

        // Output from  vec_lsu -> main_memory
        .lsu2mem_addr   (lsu2mem_addr),

        // csr_regfile -> scalar_processor
        .csr_out        (csr_out    )

    );



    initial begin
    // Clock generation
        clk <= 0;
        forever #5 clk <= ~clk;
    end

    // MAin test bench
    initial begin

        // Reading the instruction memory
        
        // Initializing the signals 
        init_signals();

        @(posedge clk);

        // Applying Reset
        reset_sequence();
        
        @(posedge clk);

        dummy_mem_reg_init();

        @(posedge clk);
        fork
            
            instruction_issue();
            memory_data_fetch();
        join
       

    end



    // Initializing the  signals
    task  init_signals();
        rs1_data        = 'h0;
        rs2_data        = 'h0;
       // instruction    	= 'h0;

    endtask 

    // Reset task
    task reset_sequence();
        begin
            reset <= 1;
            @(posedge clk);
            reset <= 0;
            @(posedge clk);
            reset <= 1;
        end
    endtask

    task  dummy_mem_reg_init();
        begin
            // initializing the instruction memory and the dummy memory
            for (int i  = 0 ; i < depth ; i++ ) begin
                inst_mem[i] = 'h0;
                dummy_mem[i]= $random;
            end
            scalar_regfile[0] = 16;
            for (int j = 1 ; j < 32 ; j++)begin
                scalar_regfile[j] = 'h0;
            end
        end
    endtask



    // Instruction Memory
    task instruction_fetch(input logic [`XLEN-1:0]address );
    
        begin
            $readmemh("/home/zawaher-bin-asim/Vector-Co-processor/test/instruction_mem.txt", inst_mem);
            instruction = inst_mem[address];        // Fetch instruction from memory
            rs1_addr = instruction[19:15];          // Decode rs1 address
            rs2_addr = instruction[24:20];          // Decode rs2 address
            rs1_data = scalar_regfile[rs1_addr];    // Fetch rs1 data
            rs2_data = scalar_regfile[rs2_addr];    // Fetch rs2 data
        end

    endtask

    // It will issue the instruction
    task  instruction_issue();
        for (int z = 0 ; z < depth  ; z++ ) begin
            instruction_fetch(z);
	        @(posedge clk);
        end
    endtask 

    task memory_data_fetch();
        if (ld_inst) begin
            // Keep ld_inst high until is_loaded signal is asserted
            while (!is_loaded) begin
                mem2lsu_data = {dummy_mem[lsu2mem_addr + 3], dummy_mem[lsu2mem_addr + 2], 
                                dummy_mem[lsu2mem_addr + 1], dummy_mem[lsu2mem_addr]};
                @(posedge clk);
                ld_inst <= 1;  // Keep ld_inst asserted until is_loaded is high
            end
            ld_inst <= 0;  // Deassert ld_inst once load is complete
        end
    endtask


endmodule