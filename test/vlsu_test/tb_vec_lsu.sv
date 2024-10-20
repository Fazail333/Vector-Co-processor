module tb_vec_lsu #(
    XLEN    = 32,   // scalar processor width
    VLEN    = 512,  // 512-bits in a vector register
    MAX_VLEN = 4096
)();

logic                     clk;
logic                     n_rst;

// scalar-processor -> vec_lsu
logic [XLEN-1:0]          rs1_data;         // base_address
logic [XLEN-1:0]          rs2_data;         // constant strided number

// 
logic [9:0]               vlmax;
logic [6:0]               sew;

// vector_processor_controller -> vec_lsu
logic                     stride_sel;       // selection for unit strided load
logic                     ld_inst;          // 

// vec_decode -> vec_lsu
logic                     mew;              // 0 because of fractional point
logic  [2:0]              width;            // memory data size 

// vec_lsu -> main_memory
logic [XLEN-1:0]         lsu2mem_addr;

// main_memory -> vec_lsu
logic [32-1:0]           mem2lsu_data;

// vec_lsu  -> vec_register_file
logic [MAX_VLEN-1:0]     vd_data;           // destination vector data
logic                    is_loaded;

// word addressable dumpy memory
logic [8-1:0]         dumpy_mem  [65536-1:0];         // dumpy memory

initial begin
    clk = 1;
    forever begin
        clk  = #20 ~clk;
    end
end

vec_lsu vector_LSU (
    .clk(clk),  .n_rst(n_rst),

    // scalar-processor -> vec_lsu
    .rs1_data(rs1_data), .rs2_data(rs2_data),

    // 
    .vlmax(vlmax), .sew(sew),

    // vector_processor_controller -> vec_lsu
    .stride_sel(stride_sel), .ld_inst(ld_inst),

    // vec_decode -> vec_lsu
    .mew(mew),  .width(width),

    // vec_lsu -> main_memory
    .lsu2mem_addr(lsu2mem_addr),
    .ld_req      (ld_req),

    // main_memory -> vec_lsu
    .mem2lsu_data(mem2lsu_data),

    // vec_lsu -> vec_register_file
    .vd_data(vd_data),  .is_loaded(is_loaded)
);

always_comb begin
    for (int i=0; i<65535; i++)
        dumpy_mem [i] = $urandom;
end

initial begin
    init_signals;
    reset_sequence;
    //  lmul = 1
    // directed_test(7'd8, 1'b1, 1'b1, 32'h200, 2, 64);
    // directed_test(7'd16, 1'b1, 1'b1, 32'h300, 2, 32);
    // directed_test(7'd32, 1'b1, 1'b1, 32'h400, 2, 16);
    // //  lmul = 2
    // directed_test(7'd8, 1'b1, 1'b1, 32'h200, 2, 128);
    // directed_test(7'd16, 1'b1, 1'b1, 32'h300, 2, 64);
    // directed_test(7'd32, 1'b1, 1'b1, 32'h400, 2, 32);
    // //  lmul = 4
    // directed_test(7'd8, 1'b1, 1'b1, 32'h200, 2, 256);
    // directed_test(7'd16, 1'b1, 1'b1, 32'h300, 2, 128);
    // directed_test(7'd32, 1'b1, 1'b1, 32'h400, 2, 64);
    // //  lmul = 8
    // directed_test(7'd8, 1'b1, 1'b1, 32'h200, 2, 512);
    // directed_test(7'd16, 1'b1, 1'b1, 32'h300, 2, 256);
    // directed_test(7'd32, 1'b1, 1'b1, 32'h400, 2, 128);
    // constant stride
    directed_test(7'd32, 1'b1, 1'b0, 32'h400, 12, 16);
    //directed_test(7'd32, 1'b1, 1'b1, 32'h600, 2, 128);

    @(posedge clk);
    $stop;
end

task init_signals;
    n_rst = 1;  
    rs1_data   = '0; rs2_data = '0;
    stride_sel = '0; ld_inst  = '0;
    mem2lsu_data = '0; mew = '0;
    width   = '0;
endtask

task reset_sequence;
    @(posedge clk);
    n_rst = '0;
    @(posedge clk);
    n_rst = 1;
endtask

task directed_test (
    input logic [6:0] sew_value,
    input logic load, unit_stride, 
    input logic [XLEN-1:0] base_address,
    input logic [XLEN-1:0] constant_strided,
    input logic [9:0]      max_ele);
    @(posedge clk);
    sew <= sew_value;
    rs1_data <= base_address;
    rs2_data <= constant_strided;
    stride_sel <= unit_stride;
    vlmax <= max_ele;
    @(posedge clk);
    ld_inst <= load;
    @(posedge clk);
    ld_inst <= '0;
    stride_sel <= '0;
    while (!is_loaded) begin
        mem2lsu_data = {dumpy_mem [lsu2mem_addr+3], dumpy_mem [lsu2mem_addr+2], 
                        dumpy_mem [lsu2mem_addr+1], dumpy_mem [lsu2mem_addr]}; 
       @(posedge clk);
    end
    @(posedge clk);
    ld_inst <= '0;
endtask
endmodule