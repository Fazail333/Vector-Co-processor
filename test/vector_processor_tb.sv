// Author       : Zawaher Bin Asim , UET Lahore <zawaherbinasim.333@gmail.com>
// Date         : 1 Oct 2024
// Description  : This file contains the testbench of the vector_processor


`include "../define/vector_processor_defs.svh"
`include "../define/vec_de_csr_defs.svh"

module vector_processor_tb ();


// Depth of the instruction memory 
parameter  depth = 512;
parameter   SEW  = 32;

logic   clk,reset;
        
// Inputs from the scaler processor  --> vector processor
logic   [`XLEN-1:0]         instruction;        // The instruction that is to be executed by the vector processor
logic   [`XLEN-1:0]         rs1_data;           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs1 address
logic   [`XLEN-1:0]         rs2_data;           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs2 address

// Outputs from vector rocessor --> scaler processor
logic                       is_vec;             // This tells the instruction is a vector instruction or not mean a legal instruction or not
        
// csr_regfile -> scalar_processor
logic   [`XLEN-1:0]         csr_out;            

// addresses of the scaler register
logic   [4:0]               rs1_addr;
logic   [4:0]               rs2_addr;

 //Inputs from main_memory -> vec_lsu
logic   [`DATA_BUS-1:0]     mem2lsu_data;

// Output from  vec_lsu -> main_memory
logic   [`XLEN-1:0]         lsu2mem_addr,           // Gives the memory address to load or store data
logic                       ld_req,                 // load request signal to the memory
logic                       st_req,                 // store request signal to the memory
logic   [`DATA_BUS-1:0]     lsu2mem_data,           // Data to be stored
logic   [WR_STROB-1:0]      wr_strobe,              // THE bytes of the DATA_BUS that contains the actual data 

   
// Register file to hold scalar register values (can be initialized as needed)
logic   [`XLEN-1:0] scalar_regfile [31:0];

// Instruction memory
logic   [`XLEN-1:0] inst_mem    [depth-1:0];

//  Dummy Memory for testing
logic   [7:0]   dummy_mem   [depth-1:0];
logic   [7:0]   test_mem    [depth-1:0];
logic   [`XLEN-1:0] addr_array [depth-1:0]




/*************************************** VAL READY INTERFACE SIGNALS *********************************************************/

logic               vec_pro_ack;            // signal that tells that successfully implemented the previous instruction 

logic               vec_pro_ready;          // tells that vector processor is ready to take the instruction

logic               scalar_pro_ready;       // tells that scaler processor is  ready to take output from the vector processor 

logic               inst_valid;             // tells that instruction and data related to instruction is valid

/*****************************************************************************************************************************/


/***************************************** FLAGS FOR THE LOAD ****************************************************************/
int i = 0; // Declare i globally or persist across loads
bit step1_done = 0;
bit step3_done = 0;
logic [`XLEN-1:0] current_instruction = 'h0;        // Keep track of the current instruction
logic [`MAX_VLEN-1:0]loaded_data;                   // loaded data for comparison
/****************************************************************************************************************************/

v_opcode_e      vopcode;
v_func3_e       vfunc3;
assign vopcode  = v_opcode_e'(VECTOR_PROCESSOR.inst_reg_instruction[6:0]);
assign vfunc3   = v_func3_e'(VECTOR_PROCESSOR.inst_reg_instruction[14:12]);


    vector_processor VECTOR_PROCESSOR(

        .clk                (clk                ),
        .reset              (reset              ),
        
        // Inputs from the scaler processor  --> vector processor
        .instruction        (instruction        ),
        .rs1_data           (rs1_data           ),
        .rs2_data           (rs2_data           ),

        // scaler_procssor  --> val_ready_controller
        .inst_valid         (inst_valid         ),             // tells data comming from the saler processor is valid
        .scalar_pro_ready   (scalar_pro_ready   ),       // tells that scaler processor is ready to take output
    

        // Outputs from vector rocessor --> scaler processor
        .is_vec             (is_vec             ),

        // Output from vector processor lsu --> memory
        .lsu2mem_addr       (lsu2mem_addr       ),           
        .ld_req             (ld_req             ),                 
        .st_req             (st_req             ),                 
        .lsu2mem_data       (lsu2mem_data       ),       
        .wr_strobe          (wr_strobe          ),       
        
        //Inputs from main_memory -> vec_lsu
        .mem2lsu_data       (mem2lsu_data       ),

        
        // csr_regfile -> scalar_processor
        .csr_out            (csr_out            ),

        // datapth  --> scaler_processor
        .vec_pro_ack        (vec_pro_ack        ),

        // controller --> scaler_processor
        .vec_pro_ready      (vec_pro_ready      )
            


    );



    initial begin
    // Clock generation
        clk <= 0;
        forever #5 clk <= ~clk;
    end

    /***********************************************  MAIN test bench ****************************************************************/
    initial begin

        // Reading the instruction memory
        
        // Initializing the signals 
        init_signals();

        @(posedge clk);

        // Applying Reset
        reset_sequence();

        // Initiating the dummy memories

        dummy_mem_reg_init();
        
        @(posedge clk);
        
        for (int i = 0 ; i < depth ; i++)begin

            fork
                
                driver(i);
                monitor();
                
            join
        end

        $finish;
    end

    /********************************************************************************************************************************/

    // Initializing the  signals
    task  init_signals();
        rs1_data        = 'h0;
        rs2_data        = 'h0;
        instruction    	= 'h0;


    endtask 

    // Reset task
    task reset_sequence();
        begin
            reset <= 1;
            @(posedge clk);
            reset <= 0;
            @(posedge clk);
            reset <= 1;
            @(posedge clk);
        end
    endtask
    

    task  dummy_mem_reg_init();
        begin
            // initializing the instruction memory and the dummy memory
            for (int i  = 0 ; i < depth ; i++ ) begin
                inst_mem[i] = 'h0;
                test_mem[i] = 'h0;
                addr_array[i] = 'h0;
                dummy_mem[i]= $random;
            end
            scalar_regfile[0] = 16;
            for (int j = 1 ; j < 32 ; j++)begin
                scalar_regfile[j] = 'h0;
            end
        end
    endtask

 

/********************************************** MEMORY DATA FETCHING  AND CALCULATING THE LOADED DATA *************************************************************/

    // if load_instruction and the masking is enabled it sees  see start_element number from the csr_file
    // and  before that start element it should copy the elements from the destination register and 
    // paste them before the start element based on the sew in the csr file and
    // from start element it should see the mask register bit value having index corresponding to the start element number .
    // if the bit is zero it  should see the mask_agnostic value .
    // if  1 it should replace that element with sew number of  1s and 
    // if the mask agnostic is 0 it  should  replace it with the value with destination register element
    // that corresponds   to that mask register bit based on the sew . 
    // if the mask register bit is 1 then value of the element will be same as the data fetched from the memory. 
    // and do the same till the value of the vl from the csr_register file and then after the vl value till vlmax
    // it should see whether the tail agnostic policy is active or not 
    // if yes then it should replace ecah element of the loaded data from the vl to vlmax with sew number of 1s .
    // and if not then it should replace each element with the destination register element corresponding to that element based on the sew .

    task memory_data_fetch();
    
        int sew;
        logic unit_stride , const_stride , index_stride;                                            // Element width (from CSR)
        sew = VECTOR_PROCESSOR.DATAPATH.VLSU.sew;    
        unit_stride = VECTOR_PROCESSOR.DATAPATH.VLSU.stride_sel;
        const_stride = !(VECTOR_PROCESSOR.DATAPATH.VLSU.stride_sel);
        index_stride = VECTOR_PROCESSOR.DATAPATH.VLSU.index_str;

        // New load instruction detected: reset step flags and loop index
        if ((VECTOR_PROCESSOR.DATAPATH.VLSU.ld_inst) && (VECTOR_PROCESSOR.inst_reg_instruction != current_instruction)) begin
            step1_done = 0;
            step3_done = 0;
            i = 0;
            current_instruction = instruction; // Update to the new instruction
           
        end
        
        if (VECTOR_PROCESSOR.DATAPATH.VLSU.ld_inst)begin
            $display("Entering Load");
            // If the masking is enabled 
            if (!VECTOR_PROCESSOR.inst_reg_instruction[25])begin
                $display("Load with masking");
                while (!(VECTOR_PROCESSOR.DATAPATH.VLSU.is_loaded))begin
                    @(posedge clk);
                    if (ld_req)begin
                        mem2lsu_data = {dummy_mem[lsu2mem_addr + 15], dummy_mem[lsu2mem_addr + 14], 
                                        dummy_mem[lsu2mem_addr + 13], dummy_mem[lsu2mem_addr + 12],
                                        dummy_mem[lsu2mem_addr + 11], dummy_mem[lsu2mem_addr + 10],
                                        dummy_mem[lsu2mem_addr + 9],  dummy_mem[lsu2mem_addr + 8],
                                        dummy_mem[lsu2mem_addr + 7],  dummy_mem[lsu2mem_addr + 6],
                                        dummy_mem[lsu2mem_addr + 5],  dummy_mem[lsu2mem_addr + 4],
                                        dummy_mem[lsu2mem_addr + 3],  dummy_mem[lsu2mem_addr + 2], 
                                        dummy_mem[lsu2mem_addr + 1],  dummy_mem[lsu2mem_addr]};

                       // $display("LSU Address: %0h, Dummy Mem Contents: %h %h %h %h", lsu2mem_addr,
                        //dummy_mem[lsu2mem_addr+3], dummy_mem[lsu2mem_addr+2],
                         //dummy_mem[lsu2mem_addr+1], dummy_mem[lsu2mem_addr]);
                        
                    


                        vector_load_with_masking();
                    end
                end
            end
            // If masking is not enabled
            else begin

                $display("Load with not masking");
                   
               while (!(VECTOR_PROCESSOR.DATAPATH.VLSU.is_loaded)) begin
                    // Monitor the load request (ld_req) at every positive edge of the clock
                   //@(posedge clk);

                    if (ld_req) begin
                        // Fetch the memory data for the current address immediately
                        mem2lsu_data = {dummy_mem[lsu2mem_addr + 15], dummy_mem[lsu2mem_addr + 14], 
                                        dummy_mem[lsu2mem_addr + 13], dummy_mem[lsu2mem_addr + 12],
                                        dummy_mem[lsu2mem_addr + 11], dummy_mem[lsu2mem_addr + 10],
                                        dummy_mem[lsu2mem_addr + 9],  dummy_mem[lsu2mem_addr + 8],
                                        dummy_mem[lsu2mem_addr + 7],  dummy_mem[lsu2mem_addr + 6],
                                        dummy_mem[lsu2mem_addr + 5],  dummy_mem[lsu2mem_addr + 4],
                                        dummy_mem[lsu2mem_addr + 3],  dummy_mem[lsu2mem_addr + 2], 
                                        dummy_mem[lsu2mem_addr + 1],  dummy_mem[lsu2mem_addr]};

                        // Display memory fetch information for verification
                        $display("LSU Address: %0h, Dummy Mem Contents: %h %h %h %h", lsu2mem_addr,
                                dummy_mem[lsu2mem_addr+3], dummy_mem[lsu2mem_addr+2],
                                dummy_mem[lsu2mem_addr+1], dummy_mem[lsu2mem_addr]);

                        // Load each bit from the fetched data into `loaded_data`
                        
                        // Define an index to track the next position in `addr_array`
                        int addr_array_index = 0;

                        if (!index_stride && (unit_stride || (const_stride && ($unsigned(rs2_data[7:0]) == 1)))) begin
                            // Handle unit stride or constant stride with a stride of 1
                            for (int i = 0; i < `DATA_BUS / 8; i++) begin
                                test_mem[lsu2mem_addr + i] <= mem2lsu_data[8 * i +: 8];
                                addr_array[addr_array_index] <= lsu2mem_addr + i; // Store each address in the next index
                                addr_array_index++; // Increment the index for the next address
                            end
                        end else begin
                            // Handle other cases based on SEW
                            case (sew)
                                7'd8: begin
                                    test_mem[lsu2mem_addr] <= mem2lsu_data[7:0];
                                    addr_array[addr_array_index] <= lsu2mem_addr;  // Store address
                                    addr_array_index++; // Increment index
                                end
                                7'd16: begin
                                    test_mem[lsu2mem_addr] <= mem2lsu_data[7:0];
                                    test_mem[lsu2mem_addr + 1] <= mem2lsu_data[15:8];
                                    addr_array[addr_array_index] <= lsu2mem_addr;
                                    addr_array_index++;
                                    addr_array[addr_array_index] <= lsu2mem_addr + 1;
                                    addr_array_index++;
                                end
                                7'd32: begin
                                    test_mem[lsu2mem_addr]     <= mem2lsu_data[7:0];
                                    test_mem[lsu2mem_addr + 1] <= mem2lsu_data[15:8];
                                    test_mem[lsu2mem_addr + 2] <= mem2lsu_data[23:16];
                                    test_mem[lsu2mem_addr + 3] <= mem2lsu_data[31:24];
                                    addr_array[addr_array_index] <= lsu2mem_addr;
                                    addr_array_index++;
                                    addr_array[addr_array_index] <= lsu2mem_addr + 1;
                                    addr_array_index++;
                                    addr_array[addr_array_index] <= lsu2mem_addr + 2;
                                    addr_array_index++;
                                    addr_array[addr_array_index] <= lsu2mem_addr + 3;
                                    addr_array_index++;
                                end
                                7'd64: begin
                                    test_mem[lsu2mem_addr] <= mem2lsu_data[7:0];
                                    test_mem[lsu2mem_addr + 1] <= mem2lsu_data[15:8];
                                    test_mem[lsu2mem_addr + 2] <= mem2lsu_data[23:16];
                                    test_mem[lsu2mem_addr + 3] <= mem2lsu_data[31:24];
                                    test_mem[lsu2mem_addr + 4] <= mem2lsu_data[39:32];
                                    test_mem[lsu2mem_addr + 5] <= mem2lsu_data[47:40];
                                    test_mem[lsu2mem_addr + 6] <= mem2lsu_data[55:48];
                                    test_mem[lsu2mem_addr + 7] <= mem2lsu_data[63:56];
                                    addr_array[addr_array_index] <= lsu2mem_addr;
                                    addr_array_index++;
                                    addr_array[addr_array_index] <= lsu2mem_addr + 1;
                                    addr_array_index++;
                                    addr_array[addr_array_index] <= lsu2mem_addr + 2;
                                    addr_array_index++;
                                    addr_array[addr_array_index] <= lsu2mem_addr + 3;
                                    addr_array_index++;
                                    addr_array[addr_array_index] <= lsu2mem_addr + 4;
                                    addr_array_index++;
                                    addr_array[addr_array_index] <= lsu2mem_addr + 5;
                                    addr_array_index++;
                                    addr_array[addr_array_index] <= lsu2mem_addr + 6;
                                    addr_array_index++;
                                    addr_array[addr_array_index] <= lsu2mem_addr + 7;
                                    addr_array_index++;
                                end
                                default: begin
                                    test_mem[lsu2mem_addr] <= mem2lsu_data;
                                    addr_array[addr_array_index] <= lsu2mem_addr;
                                    addr_array_index++;
                                end
                            endcase
                        end
                    end
                end
            end      
        end
        
    endtask

    task vector_load_with_masking();
        // Assuming the following values are available:
        logic [`MAX_VLEN-1:0] destination_reg;    // Destination register file
        logic [`VLEN-1:0] mask_reg;               // Mask register (v0 register)
        logic [`MAX_VLEN-1:0] loaded_data;        // Loaded data from memory
        logic [31:0] mem_data;                    // Fetched data from memory
        int vl;                                   // Vector length (from CSR)
        int sew;                                  // Element width (from CSR)
        int vlmax;                                // maximum number of elements
        int start_elem;                           // Start element (from CSR)
        bit mask_agnostic;                        // Mask agnostic flag (from CSR)
        bit tail_agnostic;                        // Tail agnostic flag (from CSR)
                    
        
        // Get  sew,VL,vlmax , start_elem, mask_agnostic, and tail_agnostic from the CSR
        sew = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.sew;                    
        vl = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vec_length;
        vlmax = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlmax;
        start_elem = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.start_element;   
        mask_agnostic = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.mask_agnostic;
        tail_agnostic = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.tail_agnostic;

        case (VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.lmul)
                
            4'b0001: begin // LMUL = 1
                destination_reg = VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7]];
            end
            4'b0010: begin // LMUL = 2
        
                destination_reg = {VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 1],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7]]};
            end

            4'b0100: begin // LMUL = 4
                destination_reg = {VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 3], 
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 2],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 1],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7]]};
            end

            4'b1000: begin // LMUL = 8
                destination_reg = {VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 7], 
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 6],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 5],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 4],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 3], 
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 2],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7] + 1],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[instruction[11:7]]};
            end
            default: begin 
                destination_reg = 'h0;
            end
        endcase

        // v0 as mask register
        mask_reg = VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[0];

        // Step 1: Before the start element, copy elements from the destination register
        // Step 1: Handle elements before the start element, runs once
        if (!step1_done) begin
            for (i = 0; i < start_elem; i++) begin
                for (int idx = 0; idx < sew; idx++) begin
                    loaded_data[(i * sew) + idx] = destination_reg[(i * sew) + idx];
                end
            end
            step1_done = 1; // Mark step1 as done
        end        


        // Step 3: From VL to VLMAX, handle tail agnostic logic
        // Step 3: Handle elements after VL, runs once
        if (!step3_done && i >= vl) begin
            for (i = vl; i < vlmax; i++) begin
                for (int idx = 0; idx < sew; idx++) begin
                    if (tail_agnostic) begin
                        loaded_data[(i * sew) + idx] = 1'b1; // Tail agnostic: fill with 1's
                    end else begin
                        loaded_data[(i * sew) + idx] = destination_reg[(i * sew) + idx];
                    end
                end
            end
            step3_done = 1;
        end

        // Step 2: Incrementally process masked elements between start_elem and VL
        if (ld_req && i >= start_elem && i < vl) begin
            for (int idx = 0; idx < sew; idx++) begin
                if (mask_reg[i] == 1'b0) begin
                    loaded_data[(i * sew) + idx] = mask_agnostic ? 1'b1 : destination_reg[(i * sew) + idx];
                end else begin
                    loaded_data[(i * sew) + idx] = mem2lsu_data[idx];
                end
            end
            i++; // Increment index for next element on subsequent load
        end
    endtask


/******************************************************** MEMORY STORE OPERATION *********************************************************/
    
    task memory_data_store();
        
        if (VECTOR_PROCESSOR.DATAPATH.VLSU.st_inst)begin
            $display("Entering STORE");
            // If the masking is enabled 
            if (!instruction[25])begin
                $display("STORE with masking");
                while (!(VECTOR_PROCESSOR.DATAPATH.VLSU.is_loaded))begin
                    @(posedge clk);
                    if (st_req)begin
                                // Process each byte conditionally based on the write_strobe signal
                        if (wr_strobe[0]) dumpy_mem[lsu2mem_addr]     = lsu2mem_data[7:0];
                        if (wr_strobe[1]) dumpy_mem[lsu2mem_addr + 1] = lsu2mem_data[15:8];
                        if (wr_strobe[2]) dumpy_mem[lsu2mem_addr + 2] = lsu2mem_data[23:16];
                        if (wr_strobe[3]) dumpy_mem[lsu2mem_addr + 3] = lsu2mem_data[31:24];
                        if (wr_strobe[4]) dumpy_mem[lsu2mem_addr + 4] = lsu2mem_data[39:32];
                        if (wr_strobe[5]) dumpy_mem[lsu2mem_addr + 5] = lsu2mem_data[47:40];
                        if (wr_strobe[6]) dumpy_mem[lsu2mem_addr + 6] = lsu2mem_data[55:48];
                        if (wr_strobe[7]) dumpy_mem[lsu2mem_addr + 7] = lsu2mem_data[63:56];
                        if (wr_strobe[8]) dumpy_mem[lsu2mem_addr + 8] = lsu2mem_data[71:64];
                        if (wr_strobe[9]) dumpy_mem[lsu2mem_addr + 9] = lsu2mem_data[79:72];
                        if (wr_strobe[10]) dumpy_mem[lsu2mem_addr + 10] = lsu2mem_data[87:80];
                        if (wr_strobe[11]) dumpy_mem[lsu2mem_addr + 11] = lsu2mem_data[95:88];
                        if (wr_strobe[12]) dumpy_mem[lsu2mem_addr + 12] = lsu2mem_data[103:96];
                        if (wr_strobe[13]) dumpy_mem[lsu2mem_addr + 13] = lsu2mem_data[111:104];
                        if (wr_strobe[14]) dumpy_mem[lsu2mem_addr + 14] = lsu2mem_data[119:112];
                        if (wr_strobe[15]) dumpy_mem[lsu2mem_addr + 15] = lsu2mem_data[127:120];      
                    end
                end
            end
            // If masking is not enabled
            else begin

                $display("STORE with not masking");
                   
               while (!(VECTOR_PROCESSOR.DATAPATH.VLSU.is_loaded)) begin
                    // Monitor the load request (st_req) at every positive edge of the clock
                    @(posedge clk);

                    if (st_req) begin
                        
                       // Process each byte conditionally based on the write_strobe signal
                        if (wr_strobe[0]) dumpy_mem[lsu2mem_addr]     = lsu2mem_data[7:0];
                        if (wr_strobe[1]) dumpy_mem[lsu2mem_addr + 1] = lsu2mem_data[15:8];
                        if (wr_strobe[2]) dumpy_mem[lsu2mem_addr + 2] = lsu2mem_data[23:16];
                        if (wr_strobe[3]) dumpy_mem[lsu2mem_addr + 3] = lsu2mem_data[31:24];
                        if (wr_strobe[4]) dumpy_mem[lsu2mem_addr + 4] = lsu2mem_data[39:32];
                        if (wr_strobe[5]) dumpy_mem[lsu2mem_addr + 5] = lsu2mem_data[47:40];
                        if (wr_strobe[6]) dumpy_mem[lsu2mem_addr + 6] = lsu2mem_data[55:48];
                        if (wr_strobe[7]) dumpy_mem[lsu2mem_addr + 7] = lsu2mem_data[63:56];
                        if (wr_strobe[8]) dumpy_mem[lsu2mem_addr + 8] = lsu2mem_data[71:64];
                        if (wr_strobe[9]) dumpy_mem[lsu2mem_addr + 9] = lsu2mem_data[79:72];
                        if (wr_strobe[10]) dumpy_mem[lsu2mem_addr + 10] = lsu2mem_data[87:80];
                        if (wr_strobe[11]) dumpy_mem[lsu2mem_addr + 11] = lsu2mem_data[95:88];
                        if (wr_strobe[12]) dumpy_mem[lsu2mem_addr + 12] = lsu2mem_data[103:96];
                        if (wr_strobe[13]) dumpy_mem[lsu2mem_addr + 13] = lsu2mem_data[111:104];
                        if (wr_strobe[14]) dumpy_mem[lsu2mem_addr + 14] = lsu2mem_data[119:112];
                        if (wr_strobe[15]) dumpy_mem[lsu2mem_addr + 15] = lsu2mem_data[127:120];
            
                    end
                end
            end      
        end    
    endtask

/*********************************************************************************************************************************************************/


/*********************************************************** DRIVER TASKS *******************************************************************************/
     // Instruction Memory
    task instruction_fetch(input logic [`XLEN-1:0]address );
    
        begin
            $readmemh("/home/zawaher-bin-asim/Vector-Co-processor/test/instruction_mem.txt", inst_mem);
            $display("Next Instruction");
            instruction = inst_mem[address];        // Fetch instruction from memory
            rs1_addr = instruction[19:15];          // Decode rs1 address
            rs2_addr = instruction[24:20];          // Decode rs2 address
            rs1_data = scalar_regfile[rs1_addr];    // Fetch rs1 data
            rs2_data = scalar_regfile[rs2_addr];    // Fetch rs2 data
        end

    endtask

    // It will issue the instruction
    task  instruction_issue(input int z);


        // Fetching the instruction + data
        instruction_fetch(z);

        // Making the inst_valid 1
        inst_valid <= 1'b1;
        @(posedge clk);
        // Wait for the vector processor to be ready to take instruction
        while (!vec_pro_ready)begin
            @(posedge clk );
        end
        inst_valid <= 1'b0;

    
    endtask

    task driver(input int i );
        
        instruction_issue(i);
        memory_data_fetch();
        memory_data_store();

       
    endtask
 
/*******************************************************************************************************************************************************/


/*********************************************************** MONITOR TASK *****************************************************************************/

    task monitor ();
        logic [4:0]vec_reg_addr ;
        
        logic [`MAX_VLEN-1:0] vec_reg_data;

        assign vec_reg_addr =  VECTOR_PROCESSOR.inst_reg_instruction[11:7];

        @(posedge clk);
        if (!is_vec)begin
            $error("ILLEGAL INSTRUCTION OR NOT A VECTOR INSTRUCTION");
        end
        else begin
            // Tell that scaler_porcessor is ready  to take the response
            scalar_pro_ready <= 1'b1;

            @(posedge clk);
            //Wait for the acknowledgement from the vector processor 
            while (!vec_pro_ack)begin
                @(posedge clk);
            end 

            scalar_pro_ready <= 1'b0;
    
            $display("Start monitoring");
    
         // Lets monitor the output by looking into the registers whether the instruction has been successfully implemented or not

            case (vopcode)
            // vector arithematic and set instructions opcode = 0x57
                V_ARITH: begin

                    case (vfunc3)
                        
                        // vector configuration instructions
                        CONF: begin
                            case (VECTOR_PROCESSOR.inst_reg_instruction[31]== 1)
                            // VSETVLI
                                1'b0: begin
                                    if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == VECTOR_PROCESSOR.inst_reg_instruction[30:20]) && (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == VECTOR_PROCESSOR.inst_reg_rs1_data) )begin
                                        $display("======================= TEST PASSED ==========================");
                                        $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                        $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                    end
                                    else begin
                                        $display("======================= TEST FAILED ==========================");
                                        $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                        $display("EXPECTED_VTYPE Value : %d",VECTOR_PROCESSOR.inst_reg_instruction[30:20]);
                                        $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                        $display("EXPECTED_VL Value : %d",VECTOR_PROCESSOR.inst_reg_rs1_data);
                                        
                                    end
                                    
                                end
                                1'b1: begin
                                    case (VECTOR_PROCESSOR.inst_reg_instruction[30]== 1)
                                    // VSETIVLI
                                        1'b1: begin
                                            if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == VECTOR_PROCESSOR.inst_reg_instruction[29:20]) && (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == VECTOR_PROCESSOR.inst_reg_instruction[19:15]) )begin
                                                $display("======================= TEST PASSED ==========================");
                                                $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                            end
                                            else begin
                                                $display("======================= TEST FAILED ==========================");
                                                $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                $display("EXPECTED_VTYPE Value : %d",VECTOR_PROCESSOR.inst_reg_instruction[29:20]);
                                                $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                $display("EXPECTED_VL Value : %d",VECTOR_PROCESSOR.inst_reg_instruction[19:15]);
                                                
                                            end

                                        end
                                    // VSETVL
                                        1'b0: begin
                                            
                                            if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == VECTOR_PROCESSOR.inst_reg_rs2_data) && (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == VECTOR_PROCESSOR.inst_reg_rs1_data) )begin
                                                $display("======================= TEST PASSED ==========================");
                                                $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                            end
                                            else begin
                                                $display("======================= TEST FAILED ==========================");
                                                $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                $display("EXPECTED_VTYPE Value : %d",VECTOR_PROCESSOR.inst_reg_rs2_data);
                                                $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                $display("EXPECTED_VL Value : %d",VECTOR_PROCESSOR.inst_reg_rs1_data);
                                                
                                            end
                                            
                                        end
                                    default: ;
                                    endcase
                                end
                                default: ;
                            endcase
                        end

                        default: ;
                    endcase
                end

                // Vector load instructions
                V_LOAD: begin
                                
                $display("======================= LOAD COMPLETE ==========================");
                        
                end

                V_STORE: begin
                    for (int i = 0 ; i < ; i++)begin
                        if (test_mem(addr_array[i]) != dummy_mem(addr_arrayi))begin
                            $display("======================= LOAD STORE TEST FAILED ==========================");
                            $display("LOAD VALUE : %h",test_mem(addr_array[i]));
                            $display("STORE VALUE : %h",dummy_mem(addr_array[i]));
                            $display("ADDRESS : %h",addr_array[i]);
                            break;         
                        end
                    end
                    $display("======================= LOAD STORE TEST PASS  ==========================");
                end 
                default:  ;  
            endcase
            $display("END MONITORING");
            
        end
    endtask



endmodule