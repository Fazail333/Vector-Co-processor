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

    // vec_register_file -> vec_lsu
    input   logic   [`MAX_VLEN-1:0] vs2_data,       // vector register that tell the offset 
    input   logic   [`MAX_VLEN-1:0] vs3_data,       // vector register that tells that data to be stored
    
    // vec_decode -> vec_lsu
    input   logic                   mew,            // Not used in this context
    input   logic   [2:0]           width,          // Memory access width

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
    output  logic                   is_loaded       // Load complete signal

);

    // ADDRESS GENERATION  Signals
    logic [`XLEN-1:0]               stride_mux;                  
    logic [`XLEN-1:0]               stride_value;
    logic [`XLEN-1:0]               unit_const_element_strt;
    logic [`XLEN-1:0]               selected_stride;
    logic                           start_unit_cont;
    logic                           unit_const_str_en;
    logic                           index_str_en;

    // COUNTER SIGNALS
    logic [$clog2(`VLEN):0]         count_el;        // Current element count
    logic [$clog2(`VLEN):0]         add_el;          // Incremented count
    logic                           count_en;
    logic                           is_loaded_reg;

    
    // DATA MANAGEMENT SIGNALS
    logic [2*`XLEN-1:0]             loaded_data [0:`VLEN-1];
    logic                           data_en;         // Data write enable
    logic                           st_data_en;
    logic                           data_en_next;
    

/******************************************* ADDRESS GENERATION ******************************************************/

/******************************************************************************
 * Address Generation Logic for Vector Load/Store Unit (VLSU)
 * 
 * This module computes memory addresses for vector load and store operations, 
 * supporting both unit-stride and indexed-stride configurations. Key features:
 * 
 * 1. **Stride Selection**: Dynamically extracts stride values from the vector 
 *    register (`vs2_data`) based on the element width (`SEW`) and count.
 * 
 * 2. **Stride Value Register**: Stores the active stride value, updated for 
 *    unit-stride or indexed-stride modes based on control signals.
 * 
 * 3. **Base Address Handling**: Uses `rs1_data` as the starting address. 
 *    The address increments by the stride value during subsequent operations.
 * 
 * 4. **Address Computation**: Combines base address, stride, and other inputs 
 *    to calculate the current memory address (`lsu2mem_addr`).
 * 
 * 5. **Element Counter**: Tracks the number of processed elements, resetting 
 *    when all elements are completed. The `is_loaded` signal (delayed by one 
 *    cycle) indicates completion.
 * 
 * This logic ensures efficient and flexible address generation for various 
 * vector operations.
 ******************************************************************************/

    always_comb begin
        case (sew)
            7'd8: begin
                
                selected_stride = vs2_data[(count_el * 8) +: 8];
                add_el = DATA_BUS/8;
            end
            7'd16: begin 
                
                selected_stride = vs2_data[(count_el * 16) +: 16];
                add_el = DATA_BUS/16;
            end
            7'd32: begin
                
                selected_stride = vs2_data[(count_el * 32) +: 32];
                add_el = DATA_BUS/32;
            end
            7'd64: begin 
                if (index_str)begin
                    $error("SEW = 64 is not supported for XLEN = 32 ");
                end
                else begin
                    add_el = DATA_BUS/64;
                end                
            end
            default: begin
                 
                selected_stride = 0;
                add_el = 0;
            end
        endcase
    end

        /* Address Computation */
    assign stride_mux = stride_sel ? (DATA_BUS / 8) : $unsigned(rs2_data[7:0]);
    assign unit_const_element_strt = rs1_data;  // Base address


  
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            stride_value <= 0;
        else if (unit_const_str_en) 
            stride_value <= stride_mux;
        else if (index_str_en)
            stride_value <= selected_stride;
        else 
            stride_value <= stride_value;    
    end

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            lsu2mem_addr <= 0;
        end
        else if (ld_inst && index_str)begin
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
        else if (is_loaded)begin
            count_el <= 0;
        end
        else if (count_en) begin
            if (!index_str && (stride_sel || (!stride_sel && ($unsigned(rs2_data[7:0]) == 1))))
                count_el <= count_el + add_el;
            else
                count_el <= count_el + 1;
        end
    end



    // Register is_loaded and data_en to introduce a one-cycle delay

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            is_loaded_reg <= 1'b0;
            data_en <= 0;
        end
        else begin
            is_loaded_reg <= (count_el == vlmax);
            data_en <= data_en_next;
        end    
    end

    assign is_loaded = is_loaded_reg;


/****************************************** DATA MANGEMENT **********************************************************/

/******************************************************************************
 * Data Management Logic for Vector Load/Store Unit (VLSU)
 * 
 * This section implements the logic for loading data from memory to vector 
 * registers and storing data from vector registers to memory, based on the 
 * current vector configuration and element width (`SEW`).
 * 
 * **1. Load Data Logic**:
 * - **Initialization**: Resets the `loaded_data` buffer on reset.
 * - **Unit vs. Indexed Stride**:
 *   - For unit-stride or single-byte strides (`stride_sel` or `rs2_data[7:0] == 1`), 
 *     multiple elements are loaded from `mem2lsu_data` into `loaded_data`. 
 *     The starting index for each element is calculated based on `count_el` 
 *     and the number of elements to add (`add_el`).
 *   - For indexed-stride, individual elements are loaded into `loaded_data` 
 *     based on the current `count_el`.
 * - **Element Width Handling**:
 *   - Data is extracted from `mem2lsu_data` using `SEW`-specific bit slicing. 
 *     For example, 8-bit, 16-bit, 32-bit, or 64-bit segments are stored in 
 *     `loaded_data` depending on `SEW`.
 * - **Vector Assembly**:
 *   - `vd_data` aggregates all elements from `loaded_data` into a single 
 *     packed vector by left-shifting each element according to its index 
 *     and width (`SEW`).

 * **2. Store Data Logic**:
 * - **Initialization**: Resets `lsu2mem_data` and `wr_strobe` on reset.
 * - **Unit vs. Indexed Stride**:
 *   - For unit-stride or single-byte strides, multiple elements are packed 
 *     into `lsu2mem_data` from `vs3_data`. The starting index for each element 
 *     is calculated based on `count_el` and `add_el`.
 *   - For indexed-stride, individual elements are extracted from `vs3_data` 
 *     based on the current `count_el`.
 * - **Element Width Handling**:
 *   - Elements are sliced from `vs3_data` using `SEW`-specific bit slicing. 
 *     For example, 8-bit, 16-bit, 32-bit, or 64-bit segments are packed into 
 *     `lsu2mem_data` depending on `SEW`.
 * - **Write Strobe Generation**:
 *   - The `wr_strobe` signal is dynamically generated to indicate which bytes 
 *     of `lsu2mem_data` are valid for memory storage. This is determined 
 *     based on `SEW`.

 * This logic enables precise control of data transfer between memory and vector 
 * registers, handling various strides, element widths, and configurations.
 ******************************************************************************/

    /* LOAD DATA */

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            for (int i = 0; i < MAX_VLEN; i++) 
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
                if (ld_inst) begin
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
                else if (st_inst) begin
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
                ld_req              = !is_loaded;  // Assert until all elements are loaded
                
                if (is_loaded) begin

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
                ld_req              = !is_loaded;

                if (is_loaded) begin

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
                st_req              = !is_loaded;  // Assert until all elements are loaded
                
                if (is_loaded) begin

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
                st_req              = !is_loaded;

                if (is_loaded) begin

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

