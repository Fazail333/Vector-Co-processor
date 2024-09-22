module vec_csr_dec #(
    XLEN = 32,
    VLMAX = 512
) (
    input logic             clk,
    input logic             n_rst,

    // testbench -> vector_extension
    input logic [XLEN-1:0]  vec_inst,
    input logic [XLEN-1:0]  rs1_i,
    input logic [XLEN-1:0]  rs2_i,

    // vector_extension -> testbench
    output logic            is_vec_inst

);

// vec_decode -> regfiles
logic [4:0]         vs1_addr, vs2_addr, vd_addr;
logic [4:0]         rs1_addr, rs2_addr, rd_addr;
logic [4:0]         imm;
logic               vm;     // vector mask 

// vec_decode -> vec_csr
logic [XLEN-1:0]    vtype_data;
logic [XLEN-1:0]    vl_data;

// vec_control_signals -> vec_decode
logic               vl_sel;
logic               vtype_sel;
logic               rs1rd_de;

// vec_control_signals -> vec_csr
logic               csrwr_en;

// vec_csr_regs ->
logic [3:0]         vlmul;
logic [5:0]         sew;
logic               vta;    // vector tail agnostic 
logic               vma;    // vector mask agnostic
logic [XLEN-1:0]    vlen;



// vector decode instruction
// TODO implement instructions of load/store
// implemented for the vector configuration registers
vec_decode vector_decode (

    // scalar_processor -> vec_decode
        .vec_inst           (vec_inst),
        .rs1_i              (rs1_i),
        .rs2_i              (rs2_i),

    // vec_decode -> scalar_processor
        .is_vec             (is_vec_inst),

    // vec_decode -> vec_regfile
        .vec_read_addr_1    (vs1_addr),
        .vec_read_addr_2    (vs2_addr),

        .scalar_addr        (rs1_addr),
        .vec_write_addr     (vd_addr),
        .vec_imm            (imm),
        .vec_mask           (vm),

    // vec_decode -> csr
        .vtype              (vtype_data),
        .vl                 (vl_data),

        .rd_o               (rd_addr),

    // vec_control_signals -> vec_decode
        .vl_sel             (vl_sel),
        .vtype_sel          (vtype_sel),
        .rs1rd_de           (rs1rd_de)
);

// implemented only for vectror configuration instructions
vec_processor_controller vector_controller (
    // scalar_processor -> vector_exctension
        .vec_inst           (vec_inst),

    // vec_control_signasl -> vec_decode 
        .vl_sel             (vl_sel),
        .vtype_sel          (vtype_sel),
        .rs1rd_de           (rs1rd_de),

    // vec_control_signals -> csr
        .csrwr_en           (csrwr_en)          
);

// CSR registers vtype and vl
vec_csr_regfile vec_csr_regfile (
        .clk                (clk),
        .n_rst              (n_rst),

    // vec_decode -> vec_csr_regs
        .vtype_i            (vtype_data),
        .vl_i               (vl_data),

    // vec_control_signals -> vec_csr_regs
        .csrwr_en           (csrwr_en),

    // vec_csr_regs -> 
        .vlmul              (vlmul),
        .sew                (sew),
        .vta                (vta),
        .vma                (vma),

        .vlen               (vlen) 
);

endmodule