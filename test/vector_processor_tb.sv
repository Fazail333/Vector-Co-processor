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
logic   [`XLEN-1:0] instruction;        // The instruction that is to be executed by the vector processor
logic   [`XLEN-1:0] rs1_data;           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs1 address
logic   [`XLEN-1:0] rs2_data;           // The scaler input from the scaler processor for the instructon that needs data from the  scaler register file across the rs2 address

// Outputs from vector rocessor --> scaler processor
logic               is_vec;             // This tells the instruction is a vector instruction or not mean a legal insrtruction or not
        
// csr_regfile -> scalar_processor
logic   [`XLEN-1:0] csr_out;            

// addresses of the scaler register
logic   [4:0]       rs1_addr;
logic   [4:0]       rs2_addr;

 //Inputs from main_memory -> vec_lsu
logic   [`MEM_DATA_WIDTH-1:0]   mem2lsu_data;

    // Output from  vec_lsu -> main_memory
logic   [`XLEN-1:0] lsu2mem_addr;
logic               ld_req;           
logic               st_req;           
   
// Register file to hold scalar register values (can be initialized as needed)
logic [`XLEN-1:0] scalar_regfile [31:0];

// Instruction memory
logic [`XLEN-1:0] inst_mem[depth-1:0];

//  Dummy Memory for testing
logic [`MEM_DATA_WIDTH-1:0]dummy_mem[depth-1:0];




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
assign vopcode  = v_opcode_e'(instruction[6:0]);
assign vfunc3   = v_func3_e'(instruction[14:12]);


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
        .ld_req             (ld_req             ),
        .st_req             (st_req             ),
         
        
        //Inputs from main_memory -> vec_lsu
        .mem2lsu_data       (mem2lsu_data       ),

        // Output from  vec_lsu -> main_memory
        .lsu2mem_addr       (lsu2mem_addr       ),

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

    // MAin test bench
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
                memory_data_fetch();
                monitor();

            join
        end

        $finish;
    end



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
        @(posedge clk);
    
    endtask 


    task memory_data_fetch();
        
        int sew;                                            // Element width (from CSR)
        sew = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.sew;    
        

        // New load instruction detected: reset step flags and loop index
        if (VECTOR_PROCESSOR.DATAPATH.VLSU.ld_inst && instruction != current_instruction) begin
            step1_done = 0;
            step3_done = 0;
            i = 0;
            current_instruction = instruction; // Update to the new instruction
            // Initializing loaded data
            loaded_data = 'h0;

        end
        
        if (VECTOR_PROCESSOR.DATAPATH.VLSU.ld_inst)begin
            
            // If the masking is enabled 
            if (!instruction[25])begin
                
                while (!(VECTOR_PROCESSOR.DATAPATH.VLSU.is_loaded))begin
                    if (ld_req)begin
                        mem2lsu_data = dummy_mem[lsu2mem_addr];
                        vector_load_with_masking();
                    end
                end
            end
            // If masking is not enabled
            else begin
                while (!(VECTOR_PROCESSOR.DATAPATH.VLSU.is_loaded))begin
                    if (ld_req)begin
                        mem2lsu_data = dummy_mem[lsu2mem_addr];
                        loaded_data[((i+1)*sew)-1:(i*sew)] = mem2lsu_data ;
                        i++ ;
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
        int vlmax;                                // maximum number of elements
        int start_elem;                           // Start element (from CSR)
        bit mask_agnostic;                        // Mask agnostic flag (from CSR)
        bit tail_agnostic;                        // Tail agnostic flag (from CSR)
                    
        
        // Get SEW, VL, start_elem, mask_agnostic, and tail_agnostic from the CSR
        sew = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.sew;                    
        vl = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vector_length;
        vlmax = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.vlmax;
        start_elem = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.start_element;   
        mask_agnostic = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.mask_agnostic;
        tail_agnostic = VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.tail_agnostic;

        case (VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.lmul)
                
            4'b0001: begin // LMUL = 1
                destination_reg = VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7]];
            end
            4'b0010: begin // LMUL = 2
        
                destination_reg = {VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7] + 1],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7]]};
            end

            4'b0100: begin // LMUL = 4
                destination_reg = {VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7] + 3], 
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7] + 2],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7] + 1],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7]]};
            end

            4'b1000: begin // LMUL = 8
                destination_reg = {VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7] + 7], 
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7] + 6],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7] + 5],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7] + 4]
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7] + 3], 
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7] + 2],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7] + 1],
                                VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[insrtruction[11:7]]};
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
                loaded_data[((i+1)*sew)-1:(i*sew)] = destination_reg[((i+1)*sew)-1:(i*sew)];
            end
            step1_done = 1; // Mark step1 as done
        end        


        // Step 3: From VL to VLMAX, handle tail agnostic logic
        // Step 3: Handle elements after VL, runs once
        if (!step3_done && i >= vl) begin
            for (i = vl; i < MAX_VLEN; i++) begin
                if (tail_agnostic) begin
                    loaded_data[((i+1)*sew)-1:(i*sew)] = {sew{1'b1}}; // SEW number of 1s
                end else begin
                    loaded_data[((i+1)*sew)-1:(i*sew)] = destination_reg[((i+1)*sew)-1:(i*sew)];
                end
            end
            step3_done = 1; // Mark step3 as done
        end

        // Step 2: Incrementally process masked elements between start_elem and VL
        if (ld_req && i >= start_elem && i < vl) begin
            if (mask_reg[i] == 1'b0) begin
                // Mask bit is 0
                if (mask_agnostic) begin
                    loaded_data[((i+1)*sew)-1:(i*sew)] = {sew{1'b1}}; // SEW number of 1s
                end else begin
                    loaded_data[((i+1)*sew)-1:(i*sew)] = destination_reg[((i+1)*sew)-1:(i*sew)];
                end
            end else begin
                // Mask bit is 1, load data from memory
                loaded_data[((i+1)*sew)-1:(i*sew)] = mem2lsu_data;
            end
            i++; // Increment index for next element on subsequent load
        end   
        
    endtask


    task driver(input int i );
        
        instruction_issue(i);
       
    endtask


    task monitor ();
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
            
         // Lets monitor the output by looking into the registers whether the instruction has been successfully implemented or not

            case (vopcode)
            // vector arithematic and set instructions opcode = 0x57
                V_ARITH: begin

                    case (vfunc3)
                        
                        // vector configuration instructions
                        CONF: begin
                            case (instruction[31]== 1)
                            // VSETVLI
                                1'b0: begin
                                    if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == instruction[30:20]) && (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == rs1_data) )begin
                                        $display("======================= TEST PASSED ==========================");
                                        $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                        $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                    end
                                    else begin
                                        $display("======================= TEST FAILED ==========================");
                                        $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                        $display("EXPECTED_VTYPE Value : %d",instruction[30:20]);
                                        $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                        $display("EXPECTED_VL Value : %d",rs1_data);
                                        
                                    end
                                    
                                end
                                1'b1: begin
                                    case (instruction[30]== 1)
                                    // VSETIVLI
                                        1'b1: begin
                                            if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == instruction[29:20]) && (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == instruction[19:15]) )begin
                                                $display("======================= TEST PASSED ==========================");
                                                $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                            end
                                            else begin
                                                $display("======================= TEST FAILED ==========================");
                                                $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                $display("EXPECTED_VTYPE Value : %d",instruction[29:20]);
                                                $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                $display("EXPECTED_VL Value : %d",instruction[19:15]);
                                                
                                            end

                                        end
                                    // VSETVL
                                        1'b0: begin
                                            
                                            if ((VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q == rs2_data) && (VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q == rs1_data) )begin
                                                $display("======================= TEST PASSED ==========================");
                                                $display("VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                $display("VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                            end
                                            else begin
                                                $display("======================= TEST FAILED ==========================");
                                                $display("ACTUAL_VTYPE Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vtype_q);
                                                $display("EXPECTED_VTYPE Value : %d",rs2_data);
                                                $display("ACTUAL_VL Value : %d",VECTOR_PROCESSOR.DATAPATH.CSR_REGFILE.csr_vl_q);
                                                $display("EXPECTED_VL Value : %d",rs1_data);
                                                
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
                    logic vec_reg_addr = instruction[11:7];
                    logic [`MAX_VLEN-1:0] vec_reg_data;


                    case (VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.lmul)
                        
                        4'b0001: begin // LMUL = 1
                            vec_reg_data = VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr];
                        end
                        4'b0010: begin // LMUL = 2
                    
                            vec_reg_data = {VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr + 1],
                                            VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr]};
                        end

                        4'b0100: begin // LMUL = 4
                            vec_reg_data = {VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr + 3], 
                                            VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr + 2],
                                            VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr + 1],
                                            VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr]};
                        end
            
                        4'b1000: begin // LMUL = 8
                            vec_reg_data = {VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr + 7], 
                                            VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr + 6],
                                            VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr + 5],
                                            VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr + 4]
                                            VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr + 3], 
                                            VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr + 2],
                                            VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr + 1],
                                            VECTOR_PROCESSOR.DATAPATH.VEC_REGFILE.vec_regfile[vec_reg_addr]};
                        end
                        default: begin 
                            vec_reg_data = 'h0;
                        end
                    endcase
                    
                    if (loaded_data == vec_reg_data) begin
                        $display("======================= TEST PASSED ==========================");
                        $display("Loaded DATA : %d", vec_reg_data);
                    end
                    else begin
                        $display("======================= TEST FAILED ==========================");
                        $display("ACTUAL LOADED DATA : %d",vec_reg_data);
                        $display("EXPECTED_LOADED DATA : %d",loaded_data);
                        
    
                default: ;  
            endcase
        end
    endtask



endmodule