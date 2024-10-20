module vec_lsu #(
    XLEN    = 32,       // scalar processor width
    VLEN    = 512,      // 512-bits in a vector register
    MAX_VLEN = 4096
) (
    input logic                     clk,
    input logic                     n_rst,

    // scalar-processor -> vec_lsu
    input logic [XLEN-1:0]          rs1_data,       // base_address
    input logic [XLEN-1:0]          rs2_data,       // constant strided number

    // csr_regfile --> vec_lsu
    input logic [9:0]               vlmax,          // maximum no. of elements in a vector
    input logic [6:0]               sew,

    // vector_processor_controller -> vec_lsu
    input logic                     stride_sel,     // selection for unit strided load
    input logic                     ld_inst,        // 

    // vec_decode -> vec_lsu
    input logic                     mew,            // 0 because of fractional point
    input logic  [2:0]              width,          // memory data size 

    // vec_lsu -> main_memory
    output logic [XLEN-1:0]         lsu2mem_addr,
    output logic                    ld_req,         // request the memory to load data
    
    
    // main_memory -> vec_lsu
    input logic [XLEN-1:0]           mem2lsu_data,

    // vec_lsu  -> vec_register_file
    output logic [MAX_VLEN-1:0]     vd_data,         // destination vector data
    output logic                    is_loaded        // after getting the total elements is_loaded must on
);

logic [XLEN-1:0]                stride_mux;
logic [XLEN-1:0]                stride_add;
logic [XLEN-1:0]                element_strt;

logic [$clog2(VLEN):0]        count_el;           // count elements
logic [$clog2(VLEN):0]        add_el;             // add 1 in count elements
logic                           count_en;           // start counting the elements when load instruction
logic                           data_en;
logic                           stride_en;
logic [XLEN-1:0]                stride_value;

logic [XLEN-1:0]                loaded_data [0:VLEN-1];

// store overall data in some buffur
always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst) begin
        for (int i=0; i<MAX_VLEN; i++) begin
            loaded_data[i] <= '0;
        end
    end
    else if (data_en) begin
        case (sew)
            7'd8: loaded_data[count_el] <= mem2lsu_data[7:0];
            7'd16:loaded_data[count_el] <= mem2lsu_data[15:0];
            7'd32:loaded_data[count_el] <= mem2lsu_data[31:0];
            //7'd64:loaded_data[count_el] <= mem2lsu_data;
            default: loaded_data[count_el] <= mem2lsu_data;
        endcase
    end
    else begin
        for (int i=0; i<vlmax; i++) begin
            loaded_data[i] <= loaded_data[i];
        end
    end
end

always_comb begin
    if (is_loaded) begin
        for (int i=0; i<vlmax; i++) begin
            vd_data = vd_data | (loaded_data[i] << (i*sew));
        end
    end
    else begin
        vd_data = '0;
    end
end

/*  Datapath    */
// mux for unit/constant strided
assign stride_mux = (stride_sel) ? (sew/8) : $unsigned(rs2_data[7:0]);

// stride register retain the value of stride
always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst)
        stride_value <= '0;
    else if (stride_en)
        stride_value <= stride_mux;
    else 
        stride_value <= stride_value;
end

// first element address 
assign element_strt = stride_mux + rs1_data;

// adder for making the memory addresses
assign stride_add = stride_value + lsu2mem_addr;

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
assign is_loaded = (count_el == vlmax) ? 1 : 0;

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
            stride_en = 1'b1;
            if (ld_inst) begin 
                count_en  = 1'b1;
                ld_req    = 1'b1;
            end
            else         begin 
                count_en  = 1'b0;
                ld_req    = 1'b0;
            end 
        end
        LOAD: begin
            data_en = 1'b1;
            stride_en = 1'b0;
            if (is_loaded)  begin 
                count_en  = 1'b0;
                ld_req    = 1'b0;
            end
            else begin 
                count_en  = 1'b1;
                ld_req    = 1'b1;
            end
        end
        default: begin
            count_en  = 1'b0;
            data_en   = 1'b0;
            count_en  = 1'b0;
            stride_en = 1'b0;
            ld_req    = 1'b0;
        end 
    endcase
end

endmodule