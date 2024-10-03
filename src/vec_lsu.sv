module vec_lsu #(
    XLEN    = 32,   // scalar processor width
    VLEN    = 512,  // 512-bits in a vector register
    VLMAX   = 16,   // Max. number of elements
    SEW     = 32,   // 32-bits per element
    LMUL    = 1,    // grouping

    DATAWIDTH = $clog2(SEW)
) (
    input logic                     clk,
    input logic                     n_rst,

    // scalar-processor -> vec_lsu
    input logic [XLEN-1:0]          rs1_data,       // base_address
    input logic [XLEN-1:0]          rs2_data,       // constant strided number

    // vector_processor_controller -> vec_lsu
    input logic                     stride_sel,     // selection for unit strided load
    input logic                     ld_inst,        // 

    // vec_decode -> vec_lsu
    input logic                     mew,            // 0 because of fractional point
    input logic  [2:0]              width,          // memory data size 

    // vec_lsu -> main_memory
    output logic [XLEN-1:0]         lsu2mem_addr,

    // main_memory -> vec_lsu
    input logic [SEW-1:0]           mem2lsu_data,

    // vec_lsu  -> vec_register_file
    output logic [(VLEN*LMUL)-1:0]  vd_data,         // destination vector data
    output logic                    is_loaded        // after getting the total elements is_loaded must on
);

logic [XLEN-1:0]                stride_mux;
logic [XLEN-1:0]                stride_add;
logic [XLEN-1:0]                element_strt;

logic [((VLEN/SEW)*LMUL)-1:0]   count_el;           // count elements
logic [((VLEN/SEW)*LMUL)-1:0]   add_el;             // add 1 in count elements
//logic                           is_loaded;          // after getting the total elements is_loaded must on
logic                           count_en;           // start counting the elements when load instruction
logic                           data_en;

logic [XLEN-1:0]                loaded_data [0:VLMAX-1];

// store overall data in some buffur
always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst) begin
        for (int i=0; i<VLMAX; i++) begin
            loaded_data[i] <= '0;
        end
    end
    else if (data_en) begin
        loaded_data[count_el] <= mem2lsu_data;  //TODO first element issue
    end
    else begin
        for (int i=0; i<VLMAX; i++) begin
            loaded_data[i] <= loaded_data[i];
        end
    end
end

//assign vd_data = (is_loaded) ? loaded_data[] :  '0;
always_comb begin
    if (is_loaded) begin
        vd_data = { loaded_data[15], loaded_data[14], loaded_data[13], loaded_data[12],
                    loaded_data[11], loaded_data[10], loaded_data[09], loaded_data[08],
                    loaded_data[07], loaded_data[06], loaded_data[05], loaded_data[04],
                    loaded_data[03], loaded_data[02], loaded_data[01], loaded_data[00]};
    end
    else begin
        vd_data = '0;
    end
end

/*  Datapath    */
// mux for unit/constant strided
assign stride_mux = (stride_sel) ? (SEW/8) : rs2_data;

// first element address 
assign element_strt = stride_mux + rs1_data;

// adder for making the memory addresses
assign stride_add = stride_mux + lsu2mem_addr;

// register for memory addresses
always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst)
        lsu2mem_addr <= '0;
    else if (count_en)
        lsu2mem_addr <= stride_add;
    else 
        lsu2mem_addr <= element_strt;
end

// counter for counting the number of elements
always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst)
        count_el <= '0;
    else if (data_en)
        count_el <= add_el;
    else 
        count_el <= '0;
end
// adder for elements count
assign add_el = count_el + 1;
// comparator to check that the elements are loaded
assign is_loaded = (count_el == VLMAX) ? 1 : 0;
//assign is_loaded = (count_el == (((VLEN/SEW)*LMUL)-1)) ? 1 : 0; 

/*  Controller  */
typedef enum logic {IDLE, LOAD} lsu_state_e;
lsu_state_e c_state, n_state;

always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst)
        c_state <= IDLE;
    else 
        c_state <= n_state;
end

always_comb begin
    case (c_state)
        IDLE: begin
            if (ld_inst) n_state = LOAD;
            else         n_state = IDLE;
        end
        LOAD: begin
            if (is_loaded)  n_state = IDLE;
            else            n_state = LOAD;
        end
        default: begin
            n_state = IDLE;
        end
    endcase
end

always_comb begin
    case (c_state)
        IDLE: begin
            data_en  = 1'b0;
            if (ld_inst) begin 
                count_en = 1'b1;
            //    data_en  = 1'b0;
            end
            else         begin 
                data_en  = 1'b0;
            //    count_en = 1'b0;
            end 
        end
        LOAD: begin
            data_en = 1'b1;
            if (is_loaded)  begin 
                count_en = 1'b0;
            end
            else begin 
                count_en = 1'b1;
            end
        end
        default: begin
            count_en = 1'b0;
        end 
    endcase
end

endmodule