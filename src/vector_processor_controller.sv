`include "../define/vec_de_csr_defs.svh"

module vec_processor_controller #(
    XLEN = 32
)(
    // scalar_processor -> vector_extension
    input logic [XLEN-1:0]      vec_inst,

    // vec_control_signals -> vec_decode
    output logic                vl_sel,
    output logic                vtype_sel,
    output logic                rs1rd_de,
    output logic                lumop_sel, 

    // vec_control_signals -> vec_csr
    output logic                csrwr_en
);

v_opcode_e      vopcode;
v_func3_e       vfunc3;
v_conf_e        inst_msb;
logic [1:0]     mop;

assign vopcode  = v_opcode_e'(vec_inst[6:0]);

// vfunc3 for differentiate between arithematic and configuration instructions
assign vfunc3   = v_func3_e'(vec_inst[14:12]);

// instruction decide's the vector configuration registers
assign inst_msb = v_conf_e'(vec_inst[31:30]);

// vector load instruction
assign mop      = vec_inst[27:26];

assign rs1_addr = vec_inst[19:15];
assign rd_addr = vec_inst[11:7];

always_comb begin
    lumop_sel = '0;
    case (vopcode)
    V_ARITH: begin
        case (vfunc3)
            CONF: 
            begin
                csrwr_en = 1;
                case(vec_inst[31])
                // VSETVLI
                    1'b0: begin
                        vl_sel    = '0;
                        vtype_sel =  1;     //zimm selection
                        if ((rs1_addr == '0) && (rd_addr == '0))
                            rs1rd_de = '0;
                        else 
                            rs1rd_de = 1;
                    end
                    1'b1: begin
                        case (vec_inst[30])
                    // VSETIVLI
                        1'b1: begin
                            vl_sel    = 1;
                            vtype_sel = 1;
                            rs1rd_de  = 1;
                        end
                    // VSETIVL
                        1'b0: begin
                            vl_sel    = '0;
                            vtype_sel = '0;
                            if ((rs1_addr == '0) && (rd_addr == '0))
                                rs1rd_de = '0;
                            else 
                                rs1rd_de = 1;
                        end
                        default: begin
                            vl_sel    = '0;
                            vtype_sel = '0;
                            rs1rd_de  = 1;
                        end
                        endcase
                    end
                    default: begin
                        vl_sel    = '0;
                        vtype_sel = '0;
                        rs1rd_de  = 1;
                    end
                endcase
            end
            default: 
            begin
                csrwr_en  = '0;
                vl_sel    = '0;
                vtype_sel = '0;
                rs1rd_de  =  1;
            end
        endcase
    end
    V_LOAD: begin
        csrwr_en = '0;
        vl_sel = '0;
        case (mop)
            2'b00: begin
                vtype_sel = 1;       // 1 or 0 don't care
                lumop_sel = 1;
            end
            2'b01: begin
                // TODO vs2 -> mux in zawaher's part
                vtype_sel = 1;       // 1 or 0 don't care
                lumop_sel = 1;       // 1 or 0 don't care
            end
            2'b10: begin
                vtype_sel = '0;
                lumop_sel = '0;
            end
            2'b11: begin
                // TODO vs2 -> mux in zawaher's part
                vtype_sel = 1;       // 1 or 0 don't care
                lumop_sel = 1;       // 1 or 0 don't care
            end
            default: begin
                
            end
            default:
        endcase
    end
    default: begin
        csrwr_en  = '0;
        vl_sel    = '0;
        vtype_sel = '0;
        rs1rd_de  =  1;
        lumop_sel = '0
    end
    endcase    
end

endmodule