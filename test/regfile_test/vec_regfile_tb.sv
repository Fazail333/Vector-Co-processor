//Author        : Zawaher Bin Asim , UET Lahore
//Description   : This is the testbench for the register file of the vector processor
// Date         : 13 Sep, 2024.

module vec_regfile_tb(
    
    `ifdef Verilator
        input logic clk
    `endif 

);
    `define VLEN 512

    // Parameters
    parameter ADDR_WIDTH = 32;           // 32 registers, hence 5 bits for address
    parameter MAX_VLEN = 4096;          // Maximum vector length
    parameter MAX_VEC_REGISTERS = 32;   // Maximum number of vector registers
    parameter DATA_WIDTH = MAX_VLEN;
    parameter VECTOR_LENGTH = $clog2(MAX_VLEN);

    // Inputs
    `ifndef Verilator
    logic                       clk;
    `endif 

    logic                       reset;
    logic   [ADDR_WIDTH-1:0]    raddr_1, raddr_2;
    logic   [DATA_WIDTH-1:0]    wdata;
    logic   [ADDR_WIDTH-1:0]    waddr;
    logic                       wr_en;
    logic   [3:0]               lmul;

    // Outputs
    logic   [DATA_WIDTH-1:0]    rdata_1;
    logic   [DATA_WIDTH-1:0]    rdata_2;
    logic   [VECTOR_LENGTH-1:0] vector_length;
    logic                       wrong_addr;  // Added for address validation

    // Vector Register File instantiation
    vec_regfile uut (
        .clk(clk),
        .reset(reset),
        .raddr_1(raddr_1),
        .raddr_2(raddr_2),
        .wdata(wdata),
        .waddr(waddr),
        .wr_en(wr_en),
        .lmul(lmul),
        .rdata_1(rdata_1),
        .rdata_2(rdata_2),
        .vector_length(vector_length),
        .wrong_addr(wrong_addr)  // Connect wrong_addr to the module
    );

    // Testbench Variables
    integer i;
    logic [`VLEN-1:0] expected_data [MAX_VEC_REGISTERS-1:0];  // Expected data array for comparison
    logic [DATA_WIDTH-1:0] read_data_1, read_data_2;
    logic operation;

    `ifndef Verilator
    initial begin
        // Clock generation
        clk <= 0;
        forever #5 clk <= ~clk;
    end
    `endif 
    
    // Main Testbench
    initial begin
        init_signals ();
        @(posedge clk);

        // Resetting the unit
        reset_sequence();
        @(posedge clk);
        
        // Resetting the dummy register file  
        for (i = 0 ; i < MAX_VEC_REGISTERS ; i++) begin
            expected_data[i] <= 'h0;
        end

        @(posedge clk);

        // Run the directed test
        directed_test();

        $display("======= Starting Random Tests =======");
        
        repeat(50)begin
            
            // Driving the inputs
            lmul_selection ();
            $display("LMUL value at the start = %0d", lmul);
            @(posedge clk);

            
                
                fork
                    driver ();
                    monitor ();
                    dummy_regfile_write();    
                join
                
                
            
           
            
        end
        $finish;
    end

    // Initialize signals
    task init_signals();
        raddr_1 = 'h0;
        raddr_2 = 'h0;
        wr_en   = 'h0;
        waddr   = 'h0;
        lmul    = 'h1;
        wdata   = 'h0;
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

    task lmul_selection();
        logic [1:0] random_lmul ;
        random_lmul = $urandom_range(0,3);
        case (random_lmul) 
            2'b00 : lmul = 1;
            2'b01 : lmul = 2;
            2'b10 : lmul = 4;
            2'b11 : lmul = 8;
            default : lmul = 1;
        endcase
    endtask  

    task driver ();
        operation = $urandom_range(0,1);
        if (operation == 0) begin
            raddr_1 = $urandom_range(0,31);
            raddr_2 = $urandom_range(0,31);
        end else begin
            waddr                = $urandom_range(0,31);
            wdata                = $random;
             @(negedge clk);  // Write on negative edge
            wr_en                = 1'b1;
            @(negedge clk);
            wr_en                = 1'b0;
        end
    endtask
    
    task monitor ();
        logic [DATA_WIDTH-1:0] read_data_1, read_data_2,read_writedata_1;

        @(posedge clk);  //Check on the posedge after the wr_en signal if the wrong_addr signal is high or not
        
        if (wrong_addr) begin
            $display("======= Invalid Address Detected =======");
            $display("raddr_1 = %0d, raddr_2 = %0d, waddr = %0d", raddr_1, raddr_2, waddr);
            $display("LMUL = %0d", lmul);
            $display("operation = %s", operation ? "write" : "read");
        end else begin
            
            read_data_1 = rdata_1;
            read_data_2 = rdata_2;
    

            if (operation == 0) begin
                // Read operation
                logic [DATA_WIDTH-1:0] expected_data_1, expected_data_2;

                // Determine expected data based on lmul
                case(lmul)
                    1: begin
                        expected_data_1 = expected_data[raddr_1];
                        expected_data_2 = expected_data[raddr_2];
                    end
                    2: begin
                        expected_data_1 = {expected_data[raddr_1 + 1], expected_data[raddr_1]};
                        expected_data_2 = {expected_data[raddr_2 + 1], expected_data[raddr_2]};
                    end
                    4: begin
                        expected_data_1 = {expected_data[raddr_1 + 3], expected_data[raddr_1 + 2], expected_data[raddr_1 + 1], expected_data[raddr_1]};
                        expected_data_2 = {expected_data[raddr_2 + 3], expected_data[raddr_2 + 2], expected_data[raddr_2 + 1], expected_data[raddr_2]};
                    end
                    8: begin
                        expected_data_1 = {expected_data[raddr_1 + 7], expected_data[raddr_1 + 6], expected_data[raddr_1 + 5], expected_data[raddr_1 + 4],
                                            expected_data[raddr_1 + 3], expected_data[raddr_1 + 2], expected_data[raddr_1 + 1], expected_data[raddr_1]};
                        expected_data_2 = {expected_data[raddr_2 + 7], expected_data[raddr_2 + 6], expected_data[raddr_2 + 5], expected_data[raddr_2 + 4],
                                            expected_data[raddr_2 + 3], expected_data[raddr_2 + 2], expected_data[raddr_2 + 1], expected_data[raddr_2]};
                    end
                endcase

                // Compare expected and actual data
                if ((expected_data_1 == read_data_1) && (expected_data_2 == read_data_2)) begin
                    $display("================== Read Test Passed ==================");
                    $display("raddr_1 = %0d, raddr_2 = %0d", raddr_1, raddr_2);
                    $display("read_data_1 = %0d", $signed(read_data_1));
                    $display("read_data_2 = %0d", $signed(read_data_2));
                    $display("LMUL = %d ", lmul);

                end else begin
                    $display("================== Read Test Failed ==================");
                    $display("raddr_1 = %0d, raddr_2 = %0d", raddr_1, raddr_2);
                    $display("read_data_1 = %0h, expected_data_1 = %0h", read_data_1, expected_data_1);
                    $display("read_data_2 = %0h, expected_data_2 = %0h", read_data_2, expected_data_2);
                    $display("LMUL = %d ", lmul);
                end
            end else begin
                // Write operation check
                logic [DATA_WIDTH-1:0] expected_written_data;

                // Correct read-back comparison with expected data based on LMUL
                case(lmul)
                    1: expected_written_data = expected_data[waddr];
                    2: expected_written_data = {expected_data[waddr + 1], expected_data[waddr]};
                    4: expected_written_data = {expected_data[waddr + 3], expected_data[waddr + 2], expected_data[waddr + 1], expected_data[waddr]};
                    8: expected_written_data = {expected_data[waddr + 7], expected_data[waddr + 6], expected_data[waddr + 5], expected_data[waddr + 4], 
                                                expected_data[waddr + 3], expected_data[waddr + 2], expected_data[waddr + 1], expected_data[waddr]};
                endcase


                // In order to check the data is written or not i am readig the data from the same write address and comparing it with the expected data
                @(posedge clk);
                raddr_1     = waddr;
                @(posedge clk);

                read_writedata_1 = rdata_1;
                @(posedge clk);

                if (expected_written_data == read_writedata_1) begin
                    $display("================== Write Test Passed ==================");
                    $display("write_data = %d", $signed(wdata));
                    $display("LMUL = %d ", lmul);
                    $display("write_addr = %d ", waddr);

                end else begin
                    $display("================== Write Test Failed ==================");
                    $display("expected_write_data = %0d", $signed(expected_written_data));
                    $display("actual_write_data = %0d", $signed(read_writedata_1));
                    $display("write_addr = %d ", waddr);
                    $display("LMUL = %d ", lmul);

                end
            end
        end
    endtask

    task dummy_regfile_write();
        @(posedge clk); // Writing at the posedge after the the wr_en (that is at the negative edge of previous cycle)
        if (wr_en)begin
            if (!wrong_addr)begin
                
                case(lmul)
                    1: begin
                        expected_data[waddr] = wdata[`VLEN-1:0];
                    end
                    2: begin
                        expected_data[waddr]     = wdata[`VLEN-1:0];
                        expected_data[waddr + 1] = wdata[2*`VLEN-1:`VLEN];
                    end
                    4: begin
                        expected_data[waddr]     = wdata[`VLEN-1:0];
                        expected_data[waddr + 1] = wdata[2*`VLEN-1:`VLEN];
                        expected_data[waddr + 2] = wdata[3*`VLEN-1:2*`VLEN];
                        expected_data[waddr + 3] = wdata[4*`VLEN-1:3*`VLEN];
                    end
                    8: begin
                        expected_data[waddr]     = wdata[`VLEN-1:0];
                        expected_data[waddr + 1] = wdata[2*`VLEN-1:`VLEN];
                        expected_data[waddr + 2] = wdata[3*`VLEN-1:2*`VLEN];
                        expected_data[waddr + 3] = wdata[4*`VLEN-1:3*`VLEN];
                        expected_data[waddr + 4] = wdata[5*`VLEN-1:4*`VLEN];
                        expected_data[waddr + 5] = wdata[6*`VLEN-1:5*`VLEN];
                        expected_data[waddr + 6] = wdata[7*`VLEN-1:6*`VLEN];
                        expected_data[waddr + 7] = wdata[8*`VLEN-1:7*`VLEN];
                    end
                endcase
            end
            else begin
                $display("Skipping the write in dummy regfile due to invalid address");
            end
        end 
    endtask

    task directed_test();
        $display("======= Starting Directed Test =======");

        // Initialize with a known value
        waddr = 5;
        wdata = 32'hDEADBEEF;
        wr_en = 1'b1;
        @(negedge clk);
        wr_en = 1'b0;
        expected_data[waddr] = wdata;

        // Read the value back
        raddr_1 = waddr;
        @(posedge clk);
        monitor();
    endtask
    
endmodule