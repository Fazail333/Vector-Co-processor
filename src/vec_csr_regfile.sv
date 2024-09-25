`include "../define/vec_de_csr_defs.svh"

module vec_csr_regfile (
    input logic                 clk,
    input logic                 n_rst,

    // vec_decode -> vec_csr_regs
    input logic [`XLEN-1:0]      vtype_i,
    input logic [`XLEN-1:0]      vl_i,

    // vec_control_signals -> vec_csr_regs
    input logic                 csrwr_en,

    // vec_csr_regs ->
    output logic [3:0]          vlmul,
    output logic [5:0]          sew,
    output logic                vta,    // tail agnostic
    output logic                vma,    // mask agnostic

    output logic [`XLEN-1:0]     vlen
);

csr_vtype_s csr_vtype;
logic [`XLEN-1:0] csr_vl;

// CSR registers vtype and vl (vector length)
always_ff @(posedge clk, negedge n_rst) begin
    if (!n_rst) begin
        csr_vtype.ill   <= 1;
        csr_vtype.vma   <= '0;
        csr_vtype.reserved <= '0;
        csr_vtype.vta   <= '0;
        csr_vtype.vsew  <= '0;
        csr_vtype.vlmul <= '0;
        csr_vl    <= '0;
    end
    else if (csrwr_en) begin
        csr_vtype.ill   <= '0;
        csr_vtype.vma   <= vtype_i[7];
        csr_vtype.vta   <= vtype_i[6];
        csr_vtype.vsew  <= vtype_i[5:3];
        csr_vtype.vlmul <= vtype_i[2:0];
        csr_vl          <= vl_i;
    end 
    else begin 
        csr_vtype <= csr_vtype;
        csr_vl    <= csr_vl;
    end   
end

// vlmul decoding 
always_comb begin
    case(vlmul_e'(csr_vtype.vlmul))
        LMUL_1:     vlmul = 1;
        LMUL_2:     vlmul = 2;
        LMUL_4:     vlmul = 4;
        LMUL_8:     vlmul = 8;
        LMUL_RSVD:  vlmul = 1;
        default:    vlmul = 1;
    endcase
end

// sew decoding 
always_comb begin
    case(vew_e'(csr_vtype.vsew))
        EW8:    sew = 8;
        EW16:   sew = 16;
        EW32:   sew = 32;
        EW64:   sew = 64;
        EWRSVD: sew = '0;
        default: sew = 32;
    endcase
end

assign vlen = csr_vl;
assign vma  = csr_vtype.vma;
assign vta  = csr_vtype.vta;

endmodule