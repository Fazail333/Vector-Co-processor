//Author        : Zawaher Bin Asim , UET Lahore       <zawaherbinasim.333@gmail.com>
//                Fazail Ali Butt , UET Lahore        <fazailbutt25@gmail.com>

//Description   : This is the load store unit of the vector processor containing the 
//                Addess Generation Unit , Load Store Controller , Memory DATA Management for Load and Store

// Date         : 15 Jan , 2025.




`include "../define/vec_regfile_defs.svh"

module vec_lsu #(
    
    parameter WR_STROB = $clog2(`DATA_BUS/8)
) (
    input   logic                   clk,
    input   logic                   n_rst,

    // Scalar Processor -> vec_lsu
    input   logic   [`XLEN-1:0]     rs1_data,       // Base address
    input   logic   [`XLEN-1:0]     rs2_data,       // Stride

    // CSR Register File -> vec_lsu
    input   logic   [9:0]           vlmax,          // Max number of elements in a vector
    input   logic   [6:0]           sew,            // Element width

    // Vector Processor Controller -> vec_lsu
    input   logic                   stride_sel,     // Unit stride select
    input   logic                   ld_inst,        // Load instruction
    input   logic                   st_inst,        // Store instruction
    input   logic                   index_str,      // tells about index stride
    input   logic                   index_unordered,// tells about index unordered stride
 
    // vec_register_file -> vec_lsu
    input   logic   [`MAX_VLEN-1:0] vs2_data,       // vector register that tell the offset 
    input   logic   [`MAX_VLEN-1:0] vs3_data,       // vector register that tells that data to be stored
    
    // vec_decode -> vec_lsu
    input   logic                   mew,            // Not used in this context
    input   logic   [2:0]           width,          // Memory access width

    // datapath ---> vec_lsu
    input   logic                   inst_done,      // tells  load inst or the store inst completed

    // vec_lsu -> Main Memory
    output  logic   [`XLEN-1:0]     lsu2mem_addr,   // Memory address
    output  logic   [`DATA_BUS-1:0] lsu2mem_data,   // Stored Data
    output  logic                   ld_req,         // Load request
    output  logic                   st_req,         // Store request
    output  logic   [WR_STROB-1:0]  wr_strobe,      // THE bytes of the DATA_BUS that contains the actual data 

    // Main Memory -> vec_lsu
    input   logic   [`DATA_BUS-1:0]  mem2lsu_data,   // Memory data

    // vec_lsu -> Vector Register File
    output  logic   [`MAX_VLEN-1:0] vd_data,        // Destination vector data
    output  logic                   is_loaded,      // Load data complete signal
    output  logic                   is_stored       // Store data complete signal

);
    logic                           new_inst;       // tells the initiation of new instruction

 // ADDRESS GENERATION  Signals
    logic [`XLEN-1:0]               stride_mux;                  
    logic [`XLEN-1:0]               stride_value;
    logic [`XLEN-1:0]               unit_const_element_strt;
    logic [`XLEN-1:0]               selected_stride;
    logic                           start_unit_cont;
    logic                           unit_const_str_en;
    logic                           index_str_en;

    // UORDERED ADDRESS GENERATION
    logic [$clog2(`VLEN)-1:0]       random_index, unorder_idx_counter;
    logic [`XLEN-1:0] random_str_array [`VLEN-1:0];
    logic [`XLEN-1:0]               random_stride;
    logic [`VLEN-1:0]               index_used;
    logic                           valid_entry;
    logic [$clog2(`VLEN):0]         lfsr_seed;
    logic [$clog2(`VLEN):0]         scan_index;
    logic                           all_indices_used;

    // COUNTER SIGNALS
    logic [$clog2(`VLEN)-1:0]       count_el;        // Current element count
    logic [$clog2(`VLEN)-1:0]       add_el;          // Incremented count
    logic                           count_en;
    logic                           is_loaded_reg;

    
    // DATA MANAGEMENT SIGNALS
    logic [2*`XLEN-1:0]             loaded_data [0:`VLEN-1];
    logic                           data_en;         // Data write enable
    logic                           st_data_en;
    logic                           data_en_next;

/******************************************* ADDRESS GENERATION ******************************************************/

/******************************************************************************
 /*
 * Address Generation Logic Description:
 * 
 * This module implements the address generation for a vector load/store unit (VLSU). It supports
 * three types of address generation modes: 
 * 1. **Unit Constant Address Generation**: 
 *    - The base address is directly taken from the input `rs1_data`, and a constant stride is applied to it. 
 *    - The stride can either be selected based on a predefined width (`stride_sel`) or set through an explicit 
 *      value in `rs2_data[7:0]`. This mode is useful when each element has a fixed address offset.
 * 
 * 2. **Index-Ordered Address Generation**:
 *    - This mode generates addresses based on a simple sequential pattern of indices.
 *    - The `count_el` value is incremented by a fixed stride width (`add_el`) to generate the address 
 *      of the next element in a sequential fashion.
 *    - The stride used is either derived from `vs2_data` or a fixed value depending on the width configuration.
 *    - The `count_el` value is incremented in steps based on the element size (8, 16, 32, or 64 bits), 
 *      with different `add_el` values for each stride width.
 * 
 * 3. **Index-Unordered Address Generation**:
 *    - This mode generates addresses by randomly selecting an index from a pool of available indices.
 *    - A Linear Feedback Shift Register (LFSR) is used to generate random numbers. 
 *    - If the generated index has already been used, the next index in sequence is checked until an unused index 
 *      is found.
 *    - Once a valid index is found, the corresponding data for the generated index is extracted from `vs2_data` 
 *      and used as the stride for address computation.
 *    - The `index_used` array tracks which indices have been used to prevent repetition.
 *    - The `unorder_idx_counter` ensures that the stride for each element is placed in the correct location.
 * 
 * Address Calculation:
 * 1. For **Unit Constant Mode**, the address is computed using:
 *    `address = rs1_data + stride_value`
 *    Where `stride_value` is either constant or derived from `rs2_data` depending on the configuration.
 * 2. For **Index-Ordered Mode**, the address is computed using:
 *    `address = rs1_data +  stride_value`
 * 3. For **Index-Unordered Mode**, the address is computed using:
 *    `address = rs1_data + random_stride`
 *    Where `random_stride` is selected from the array `random_str_array`, based on a random index and the stride 
 *    value corresponding to the selected element.
 
 ******************************************************************************/



    // Generate a unique random index in a single cycle (Index Unordered Stride)
    always_comb begin
        valid_entry   = 0;
        random_stride = 0;
        lfsr_seed     = 'h1;
        scan_index    = 0;

        all_indices_used = &vlmax; // If all bits are set, all indices are used

        if (index_unordered && !all_indices_used) begin
            // LFSR-based pseudo-random number generation
            lfsr_seed = {lfsr_seed[$clog2(`VLEN)-2:0], 
                        lfsr_seed[$clog2(`VLEN)-1] ^ 
                        lfsr_seed[$clog2(`VLEN)-3] ^ 
                        lfsr_seed[$clog2(`VLEN)-2] ^ 1'b1};
            
            random_index = lfsr_seed % vlmax;  // Ensure within range

            // If the generated index is used, scan sequentially to find the next available index
            for (int i = 0; i < vlmax; i++) begin
                if (!index_used[random_index]) begin
                    valid_entry = 1;
                end else begin
                    random_index = (random_index + 1) % vlmax;
                end
            end

            // Extract stride data based on unique random index
            if (valid_entry) begin
                case (width)
                    3'b000: random_stride = vs2_data[(random_index * 8) +: 8];
                    3'b101: random_stride = vs2_data[(random_index * 16) +: 16];
                    3'b110: random_stride = vs2_data[(random_index * 32) +: 32];
                    3'b111: begin 
                        if (index_str) 
                            $fatal("SEW = 64 is not supported for XLEN = 32");
                        random_stride = 0;
                    end
                    default: random_stride = 0;
                endcase
            end
        end
    end

    // Store the unique random index on clock edge
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            unorder_idx_counter <= 0; 
            index_used          <= 0;  // Reset tracking array
            for (int i = 0; i < `VLEN; i++) begin
                random_str_array[i] <= 0;
            end
        end else begin
            if (is_loaded) begin
                index_used <= '0;
                for (int i = 0; i < `VLEN; i++) begin
                    random_str_array[i] <= 0;
                end
            end
            else if (index_unordered && valid_entry) begin
                random_str_array[unorder_idx_counter] <= random_stride;
                index_used[random_index]              <= 1'b1;  // Mark index as used
                unorder_idx_counter                   <= (unorder_idx_counter == vlmax-1) ? 0 : unorder_idx_counter + 1;
            end
        end
    end


    // Index Orderded Stride Computation
    always_comb begin
        case (width)
            3'b000: begin
                selected_stride = vs2_data[(count_el * 8) +: 8];
                add_el = `DATA_BUS/8;
            end
            3'b101: begin 
                selected_stride = vs2_data[(count_el * 16) +: 16];
                add_el = `DATA_BUS/16;
            end
            3'b110: begin
                selected_stride = vs2_data[(count_el * 32) +: 32];
                add_el = `DATA_BUS/32;
            end
            3'b111: begin 
                if (index_str)begin
                    $error("SEW = 64 is not supported for XLEN = 32 ");
                end
                else begin
                    add_el = `DATA_BUS/64;
                end                
            end
            default: begin
                selected_stride = 0;
                add_el = 0;
            end
        endcase
    end

        /* Unit and Constant Stride */
    assign stride_mux = stride_sel ? (`DATA_BUS / 8) : $unsigned(rs2_data[7:0]);
    assign unit_const_element_strt = rs1_data;  // Base address


  // STRIDE VALUE CALCULATION
    always_comb  begin
         if (unit_const_str_en) 
            stride_value = stride_mux;
        else if (index_str_en) begin
            if (index_unordered)begin
                stride_value = random_str_array[count_el];
            end
            else begin
                stride_value = selected_stride;    
            end
        end
        else 
            stride_value = stride_value;    
    end

    // LSU2MEM ADDRESS GENERATION
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            lsu2mem_addr <= 0;
        end
        else if ((st_inst ||ld_inst) && index_str)begin
            if (count_en) begin
                lsu2mem_addr <= rs1_data + stride_value;
            end                
        end
        else begin
            if(start_unit_cont)begin
                lsu2mem_addr <= unit_const_element_strt;
            end
            else if (count_en)begin
                lsu2mem_addr <= lsu2mem_addr + stride_value;
            end    
        end        
    end 

  
    /* Element Counter */
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            count_el <= 0;
        else if (is_loaded_reg || is_stored)begin
            count_el <= 0;
        end
        else if (count_en) begin
            if (!index_str && (stride_sel || (!stride_sel && ($unsigned(rs2_data[7:0]) == 1))))
                count_el <= count_el + add_el;
            else
                count_el <= count_el + 1;
        end
        else begin
            count_el <= count_el;
        end
    end

    always_ff @( posedge clk or negedge n_rst ) begin 
        if (!n_rst)begin
            new_inst <= 1;
        end
        else if ((is_loaded_reg || is_stored) && !inst_done)begin
            new_inst <= 0;
        end
        else if (inst_done)begin
            new_inst <= 1;
        end
        
    end


    // Register is_loaded and data_en to introduce a one-cycle delay

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            data_en       <= 0;
            is_loaded     <= 0;
        end
        else begin
            data_en       <= data_en_next;
            is_loaded     <= is_loaded_reg;
        end    
    end


    always_comb begin
        if (ld_inst)begin
           if (!index_str && (stride_sel || (!stride_sel && ($unsigned(rs2_data[7:0]) == 1))))
                is_loaded_reg = (count_el == vlmax + add_el);
            else 
                is_loaded_reg = (count_el == vlmax + 1);
        end
        else if (st_inst)begin
            if (!index_str && (stride_sel || (!stride_sel && ($unsigned(rs2_data[7:0]) == 1))))
                is_stored = (count_el == vlmax + add_el);
            else 
                is_stored = (count_el == vlmax + 1);
        end
        else begin
            is_loaded_reg = 1'b0;
            is_stored     = 1'b0;
        end 
    end


    

/****************************************** DATA MANGEMENT **********************************************************/

/******************************************************************************
 /*
 * Data Management Logic Description:
 *
 * This section handles the loading and storing of data in the vector load/store unit (VLSU).
 * It supports various configurations for loading and storing data based on the vector element width (`sew`),
 * stride selection (`stride_sel`), and whether the operation is index-ordered or index-unordered.
 * 
 * 1. **Load Data (loading data from memory to the vector register file)**:
 *    - **Index-Ordered Load**:
 *      - If `index_str` is false, the data is loaded sequentially from memory.
 *      - The stride is either selected based on `stride_sel` or explicitly set using the value in `rs2_data[7:0]`.
 *      - A loop iterates over the elements, loading them into `loaded_data` based on the element width (`sew`).
 *      - The base index is computed using the `count_el` value, adjusted by the stride value (`add_el`).
 *      - The data is packed into the corresponding element width (8, 16, 32, or 64 bits) and stored in `loaded_data`.
 * 
 *    - **Index-Unordered Load**:
 *      - If `index_str` is true and `index_unordered` is set, the data is loaded from memory based on randomly selected indices.
 *      - A random index is picked, and the corresponding data from `mem2lsu_data` is loaded and stored in `loaded_data`.
 *      - The stride is derived from the selected random index and used for the data load.
 *      - If the stride is not set for `index_unordered`, the data is loaded from sequential indices instead.
 * 
 * 2. **Store Data (storing data from the vector register file to memory)**:
 *    - **Index-Ordered Store**:
 *      - If `index_str` is false, the data is stored sequentially to memory.
 *      - The stride is either selected based on `stride_sel` or explicitly set using the value in `rs2_data[7:0]`.
 *      - A loop iterates over the elements, selecting the appropriate data from `vs3_data` based on the element width (`sew`).
 *      - The data is packed and stored into `lsu2mem_data` to be written to memory.
 *      - The `wr_strobe` signal is set to indicate the valid store operation.
 * 
 *    - **Index-Unordered Store**:
 *      - If `index_str` is true and `index_unordered` is set, the data is stored based on randomly selected indices.
 *      - A random index is picked from `random_str_array`, and the corresponding data from `vs3_data` is stored in memory.
 *      - The data is packed into the correct element width and stored in `lsu2mem_data`.
 *      - The `wr_strobe` signal is updated to indicate which bytes of the `lsu2mem_data` are valid for the store operation.
 * 
 * Data packing is done based on the element width `sew` (8, 16, 32, or 64 bits). Depending on the configuration, the `wr_strobe`
 * signal is set to indicate which byte lanes are being written to memory. This enables partial writes for wider data elements.
 * 
 * Additionally, data is loaded or stored for each element in the vector register file, depending on whether it is sequential 
 * (index-ordered) or randomized (index-unordered).
 ******************************************************************************/

    /* LOAD DATA */

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            for (int i = 0; i < `MAX_VLEN; i++) 
                loaded_data[i] <= 0;
        end
        else if (data_en) begin
            if (!index_str && (stride_sel || (!stride_sel && ($unsigned(rs2_data[7:0]) == 1))))begin
                for (int i = 0; i < add_el; i++) begin
                    automatic int base_index = (count_el - 2*add_el) + i; // Calculate the row index in the 2D array
                    case (sew)
                        7'd8:  loaded_data[base_index] <= mem2lsu_data[(8 * i) +: 8];   
                        7'd16: loaded_data[base_index] <= mem2lsu_data[(16 * i) +: 16]; 
                        7'd32: loaded_data[base_index] <= mem2lsu_data[(32 * i) +: 32]; 
                        7'd64: loaded_data[base_index] <= mem2lsu_data[(64 * i) +: 64]; 
                        default: loaded_data[base_index] <= 'h0; 
                    endcase
                end
            end
            else begin     
                case (sew)
                    7'd8:  loaded_data[count_el-2] <= mem2lsu_data[7:0];
                    7'd16: loaded_data[count_el-2] <= mem2lsu_data[15:0];
                    7'd32: loaded_data[count_el-2] <= mem2lsu_data[31:0];
                    7'd64: loaded_data[count_el-2] <= mem2lsu_data[64:0];
                    default: loaded_data[count_el-2] <= mem2lsu_data;
            endcase
            end
        end
    end


    always_comb begin
        vd_data = 0;
        for (int i = 0; i < vlmax; i++) 
            vd_data = vd_data | (loaded_data[i] << (i * sew));
    end


// STORE DATA
   
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            lsu2mem_data <= 'h0;
        end
        else if (st_data_en) begin
            if (!index_str && (stride_sel || (!stride_sel && ($unsigned(rs2_data[7:0]) == 1))))begin
                for (int i = 0; i < add_el; i++) begin
                    automatic int base_index = (count_el  + i); // Calculate the row index in the 2D array
                    case (sew)
                        7'd8:  lsu2mem_data[(8 * i) +: 8] = vs3_data[(base_index * 8) +: 8];   // Pack 8-bit elements
                        7'd16: lsu2mem_data[(16 * i) +: 16] = vs3_data[(base_index * 16) +: 16]; // Pack 16-bit elements
                        7'd32: lsu2mem_data[(32 * i) +: 32] = vs3_data[(base_index * 32) +: 32]; // Pack 32-bit elements
                        7'd64: lsu2mem_data[(64 * i) +: 64] = vs3_data[(base_index * 64) +: 64]; // Pack 64-bit elements
                        default: lsu2mem_data = 0; 
                    endcase
                end
                wr_strobe <= {WR_STROB{1'b1}};
            end
            else begin
                if (index_str && index_unordered)begin
                    case (sew)
                        7'd8: begin
                            lsu2mem_data[7:0]  <= vs3_data[random_str_array[count_el] +: 8];
                            wr_strobe <= 'b1;
                        end 
                        7'd16: begin
                            lsu2mem_data[15:0] <= vs3_data[random_str_array[count_el] +: 16];
                            wr_strobe <= 'b11;
                        end
                        7'd32: begin
                            lsu2mem_data[31:0] <= vs3_data[random_str_array[count_el] +: 32];
                            wr_strobe <= 'b1111;
                        end
                        7'd64: begin
                            lsu2mem_data[63:0] <= vs3_data[random_str_array[count_el] +: 64];
                            wr_strobe <= 'b11111111;
                        end
                        default: lsu2mem_data <= 'h0;
                    endcase
                end
                else begin     
                    case (sew)
                        7'd8: begin
                            lsu2mem_data[7:0]  <= vs3_data[(count_el) * 8 +: 8];
                            wr_strobe <= 'b1;
                        end 
                        7'd16: begin
                            lsu2mem_data[15:0] <= vs3_data[(count_el) * 16 +: 16];
                            wr_strobe <= 'b11;
                        end
                        7'd32: begin
                            lsu2mem_data[31:0] <= vs3_data[(count_el) * 32 +: 32];
                            wr_strobe <= 'b1111;
                        end
                        7'd64: begin
                            lsu2mem_data[63:0] <= vs3_data[(count_el) * 64 +: 64];
                            wr_strobe <= 'b11111111;
                        end
                        default: lsu2mem_data <= 'h0;
                    endcase
                end   
            end
        end
    end


/****************************************************** CONTROLLER *****************************************************/

    typedef enum logic [2:0]{IDLE, 
                            LOAD_UNIT_CONST,
                            LOAD_INDEX, 
                            STORE_UNIT_CONST, 
                            STORE_INDEX
                            } lsu_state_e;
    
    lsu_state_e c_state, n_state;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            c_state <= IDLE;
        else
            c_state <= n_state;
    end

    always_comb begin
        n_state             = c_state;
        data_en_next        = 0;
        count_en            = 0;
        ld_req              = 0;
        st_req              = 0;
        start_unit_cont     = 1;
        index_str_en        = 0;
        unit_const_str_en   = 0;
        st_data_en          = 0;

        case (c_state)
            IDLE: begin
                
                start_unit_cont = 1;
                if (ld_inst && new_inst) begin
                    if (index_str)begin

                        n_state             = LOAD_INDEX;
                        index_str_en        = 1'b1;
                        count_en            = 1; 
                    
                    end
                    else begin

                        n_state             = LOAD_UNIT_CONST;
                        unit_const_str_en   = 1;
                        count_en            = 1;
                    
                    end
                end
                else if (st_inst && new_inst) begin
                    if (index_str)begin

                        n_state             = STORE_INDEX;
                        index_str_en        = 1'b1;
                        count_en            = 1;
                        st_data_en          = 1; 
                    
                    end
                    else begin

                        n_state             = STORE_UNIT_CONST;
                        unit_const_str_en   = 1;
                        count_en            = 1;
                        st_data_en          = 1;
                    end
                end
            end
            LOAD_UNIT_CONST: begin

                data_en_next        = 1;
                count_en            = 1;
                unit_const_str_en   = 0;
                start_unit_cont     = 0;
                ld_req              = !is_loaded_reg;  // Assert until all elements are loaded
                
                if (is_loaded_reg) begin

                    n_state         = IDLE;
                    ld_req          = 0;
                    data_en_next    = 0;
                    count_en        = 0;
                
                end
            end
            LOAD_INDEX : begin

                data_en_next        = 1;
                count_en            = 1;
                index_str_en        = 1;
                start_unit_cont     = 0;
                ld_req              = !is_loaded_reg;

                if (is_loaded_reg) begin

                    n_state         = IDLE;
                    ld_req          = 0;
                    index_str_en    = 0;
                    data_en_next    = 0;
                    count_en        = 0;
                end
            end

            STORE_UNIT_CONST: begin

                count_en            = 1;
                st_data_en          = 1;
                unit_const_str_en   = 0;
                start_unit_cont     = 0;
                st_req              = !is_stored;  // Assert until all elements are stored
                
                if (is_stored) begin

                    n_state         = IDLE;
                    st_req          = 0;
                    st_data_en      = 0;
                    count_en        = 0;
                end
            end
            STORE_INDEX : begin

                count_en            = 1;
                st_data_en          = 1;
                index_str_en        = 1;
                start_unit_cont     = 0;
                st_req              = !is_stored;

                if (is_stored) begin

                    n_state         = IDLE;
                    st_req          = 0;
                    index_str_en    = 0;
                    st_data_en      = 0;
                    count_en        = 0;
                end
            end
        endcase
    end
endmodule

