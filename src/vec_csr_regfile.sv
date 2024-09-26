`include "../define/vec_de_csr_defs.svh"

module vec_csr_regfile (
    input logic                 clk,
    input logic                 n_rst,

    // scalar_processor -> csr_regfile
    input logic [`XLEN-1:0]     inst,
    input logic [`XLEN-1:0]     rs1_i,

    // csr_regfile -> scalar_processor
    output logic [`XLEN-1:0]    csr_out,

    // vec_decode -> vec_csr_regs
    input logic [`XLEN-1:0]     vtype_i,
    input logic [`XLEN-1:0]     vl_i,

    // vec_control_signals -> vec_csr_regs
    input logic                 csrwr_en,

    // vec_csr_regs ->
    output logic [3:0]          vlmul,
    output logic [5:0]          sew,
    output logic                vta,    // tail agnostic
    output logic                vma,    // mask agnostic

    output logic [`XLEN-1:0]     vlen
);

csr_vtype_s         csr_vtype_q;
logic [`XLEN-1:0]   csr_vl_q;
logic [`XLEN-1:0]   csr_vstart_d, csr_vstart_q;
logic               illegal_insn;

// instruction decode
logic [6:0]     opcode;
logic [4:0]     rs1_addr;
logic [4:0]     rd_addr;
logic [2:0]     funct3;
csr_reg_e       csr;  

assign opcode   = inst [6:0];
assign rd_addr  = inst [11:7];
assign funct3   = inst [14:12];
assign rs1_addr = inst [19:15];
assign csr      = csr_reg_e'(inst [31:20]);  

// Two vector CSR registers vtype and vl are written by using only one 'vsetvli' instruction
// these two registers are not written by the simple read write csr.
 
// CSR registers vtype and vl (vector length)

////////////////////////////
//  Vector Configuration  //
////////////////////////////

always_ff @(posedge clk, negedge n_rst) begin
    if (!n_rst) begin
        csr_vtype_q.ill       <= 1;
        csr_vtype_q.vma       <= '0;
        csr_vtype_q.reserved  <= '0;
        csr_vtype_q.vta       <= '0;
        csr_vtype_q.vsew      <= '0;
        csr_vtype_q.vlmul     <= '0;
        csr_vl_q              <= '0;
    end
    else if (csrwr_en) begin
        csr_vtype_q.ill   <= '0;
        csr_vtype_q.vma   <= vtype_i[7];
        csr_vtype_q.vta   <= vtype_i[6];
        csr_vtype_q.vsew  <= vtype_i[5:3];
        csr_vtype_q.vlmul <= vtype_i[2:0];
        csr_vl_q          <= vl_i;
    end 
    else begin 
        csr_vtype_q <= csr_vtype_q;
        csr_vl_q    <= csr_vl_q;
    end   
end

// CSR vstart register
always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst)
        csr_vstart_q <= '0;
    else 
        csr_vstart_q <= csr_vstart_d;
end

// vlmul decoding 
always_comb begin
    case(vlmul_e'(csr_vtype_q.vlmul))
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
    case(vew_e'(csr_vtype_q.vsew))
        EW8:    sew = 8;
        EW16:   sew = 16;
        EW32:   sew = 32;
        EW64:   sew = 64;
        EWRSVD: sew = '0;
        default: sew = 32;
    endcase
end

assign vlen = csr_vl_q;
assign vma  = csr_vtype_q.vma;
assign vta  = csr_vtype_q.vta;

////////////////////////////
//  CSR Reads and Writes  //
////////////////////////////

// Converts between the internal representation of `vtype_t` and the full XLEN-bit CSR.
function logic[`XLEN-1:0] xlen_vtype(vtype_t vtype);
  xlen_vtype = {vtype.vill, {23'h000000}, vtype.vma, vtype.vta, vtype.vsew,
    vtype.vlmul[2:0]};
endfunction: xlen_vtype

always_comb begin
    case (opcode) 
        begin
        csr_vstart_d = '0;
        // CSR instructions
        7'h73: begin
            case (funct3)
                3'b001: begin // csrrw
                    // Decode the CSR.
                    case (csr)
                        // Only vstart can be written with CSR instructions.
                        CSR_VSTART: begin
                            csr_vstart_d    = rs1_i;
                            csr_out         = csr_vstart_q;
                        end
                        default: illegal_insn = 1'b1;
                    endcase
                end
                3'b010: begin // csrrs
                    // Decode the CSR.
                    case (csr)
                        CSR_VSTART: begin
                            csr_vstart_d    = csr_vstart_q | rs1_i;
                            csr_out         = csr_vstart_q;
                        end
                        CSR_VTYPE: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = xlen_vtype(csr_vtype_q);
                            else illegal_insn = 1'b1;
                        end
                        CSR_VL: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = csr_vl_q;
                            else illegal_insn = 1'b1;
                        end
                    default: illegal_insn = 1'b1;
                    endcase
                end
                3'b011: begin // csrrc
                    // Decode the CSR.
                    case (csr)
                        CSR_VSTART: begin
                            csr_vstart_d    = csr_vstart_q & ~rs1_i;
                            csr_out         = csr_vstart_q;
                        end
                        CSR_VTYPE: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = xlen_vtype(csr_vtype_q);
                            else illegal_insn = 1'b1;
                        end
                        CSR_VL: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = csr_vl_q;
                            else illegal_insn = 1'b1;
                        end
                    default: illegal_insn = 1'b1;
                    endcase
                end
                3'b101: begin // csrrwi
                    // Decode the CSR.
                    case (csr)
                        // Only vstart can be written with CSR instructions.
                        CSR_VSTART: begin
                            csr_vstart_d    = rs1_i;
                            csr_out         = csr_vstart_q;
                        end
                    default: illegal_insn = 1'b1;
                    endcase
                end
                3'b110: begin // csrrsi
                    // Decode the CSR.
                    case (csr)
                        CSR_VSTART: begin
                            csr_vstart_d  = csr_vstart_q | rs1_i;
                            csr_out       = csr_vstart_q;
                        end
                        CSR_VTYPE: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = xlen_vtype(csr_vtype_q);
                            else illegal_insn = 1'b1;
                        end
                        CSR_VL: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = csr_vl_q;
                            else illegal_insn = 1'b1;
                        end
                    default: illegal_insn = 1'b1;
                    endcase
                end
                3'b111: begin // csrrci
                    // Decode the CSR.
                    case (csr)
                        CSR_VSTART: begin
                            csr_vstart_d = csr_vstart_q & ~rs1_i;
                            csr_out      = csr_vstart_q;
                        end
                        CSR_VTYPE: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = xlen_vtype(csr_vtype_q);
                            else illegal_insn = 1'b1;
                        end
                        CSR_VL: begin
                            // Only reads are allowed
                            if (rs1_addr == '0) csr_out = csr_vl_q;
                            else illegal_insn = 1'b1;
                        end
                    default: illegal_insn= 1'b1;
                    endcase
                end
                default: begin
                    // Trigger an illegal instruction
                    illegal_insn = 1'b1;
                end
            endcase // funct3
            end
        end

        default: begin
        // Trigger an illegal instruction
        illegal_insn = 1'b1;
        end
    endcase
end

endmodule