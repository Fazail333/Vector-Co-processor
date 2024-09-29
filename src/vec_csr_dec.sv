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
logic [XLEN-1:0]    scalar1, csr_out;
logic [XLEN-1:0]    scalar2;

// vec_control_signals -> vec_decode
logic               vl_sel;
logic               vtype_sel;
logic               rs1rd_de;
logic               lumop_sel

logic [4:0]         rd, rd_o;
logic [5:0]         vfunc6;
logic               vm;         // vector mask

// vec_decode -> vector load
logic [2:0]         width;
logic               mew;
logic [2:0]         nf;
logic [XLEN-1:0]    rs1_o;

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

    // vec_decode -> vector_load
        .width              (width),
        .mew                (mew),
        .nf                 (nf),
        .rs1_o              (rs1_o),

    // vec_decode -> csr
        .scalar1            (scalar1),
        .scalar2            (scalar2),

        //.rd_o               (rd_addr),

    // vec_control_signals -> vec_decode
        .vl_sel             (vl_sel),
        .vtype_sel          (vtype_sel),
        .rs1rd_de           (rs1rd_de),
        .lumop_sel          (lumop_sel)
);

// implemented only for vectror configuration instructions
vector_processor_controller vector_controller (
    // scalar_processor -> vector_exctension
        .vec_inst           (vec_inst),

    // vec_control_signasl -> vec_decode 
        .vl_sel             (vl_sel),
        .vtype_sel          (vtype_sel),
        .rs1rd_de           (rs1rd_de),
        .lumop_sel          (lumop_sel),

    // vec_control_signals -> csr
        .csrwr_en           (csrwr_en)          
);

// CSR registers vtype and vl
vec_csr_regfile vec_csr_regfile (
        .clk                (clk),
        .n_rst              (n_rst),

    // scalar_processor -> csr_regfile
        .inst               (vec_inst),
        .rs1_i              (scalar1),

    // vec_decode -> vec_csr_regs
        .vtype_i            (scalar1),
        .vl_i               (scalar2),

    // vec_control_signals -> vec_csr_regs
        .csrwr_en           (csrwr_en),

    // vec_csr_regs -> 
        .vlmul              (vlmul),
        .sew                (sew),
        .vta                (vta),
        .vma                (vma),

        .vlen               (vlen),
        .csr_out            (csr_out)
);

endmodule