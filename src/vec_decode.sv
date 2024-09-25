`include "../define/vec_de_csr_defs.svh"

module vec_decode(
    // scalar_processor -> vec_decode
    input logic [`XLEN-1:0]      vec_inst,
    input logic [`XLEN-1:0]      rs1_i, rs2_i,

    // vec_decode -> scalar_processor
    output logic                is_vec,

    // vec_decode -> vec_regfile
    output logic [4:0]          vec_read_addr_1,        // vs1
    output logic [4:0]          vec_read_addr_2,        // vs2
    //output logic [4:0]          scalar_addr,            // rs1
    output logic [4:0]          vec_write_addr,         // vd
    output logic [4:0]          vec_imm,
    output logic                vec_mask,

    // vec_decode -> csr 
    output logic [`XLEN-1:0]     vtype,                  // vector type
    output logic [`XLEN-1:0]     vl,                     // vector length
    //output logic [4:0]          rd_o,

    // vec_control_signals -> vec_decode
    input logic vl_sel,
    input logic vtype_sel,
    input logic rs1rd_de
);

v_opcode_e      vopcode;
v_func3_e       vfunc3;
logic [1:0]     inst_msb;
logic [4:0]     vs1;
logic [4:0]     vs2;
logic [4:0]     vd;
logic [4:0]     rs1_addr;
logic [4:0]     imm;
logic [4:0]     rd, rd_o;
logic [5:0]     vfunc6;
logic           vm;         // vector mask

// vector configuration 
logic [`XLEN-1:0]     rs1_o, rs2_o;
logic [`XLEN-1:0]     vlen_mux;
logic [10:0]         zimm;          // zero-extended immediate
logic [4:0]          uimm;          // unsigned immediate

assign vopcode  = v_opcode_e'(vec_inst[6:0]);
assign vd       = vec_inst[11:7];
assign vfunc3   = v_func3_e'(vec_inst[14:12]);
assign vs1      = vec_inst[19:15];
assign rs1_addr = vec_inst[19:15];
assign imm      = vec_inst[19:15];
assign vs2      = vec_inst[24:20];
assign vm       = vec_inst[25];
assign func6    = vec_inst[31:26];

// vector instruction msb bits used to select the vector config registers
assign inst_msb = vec_inst[31:30];

// vector config
//assign zimm = vec_inst[30:20];
assign uimm = vec_inst[19:15];

always_comb begin : vec_decode
    is_vec          = '0;
    vec_write_addr  = '0;
    vec_read_addr_1 = '0;
    vec_read_addr_2 = '0;
    vec_imm         = '0;
    //scalar_addr     = '0;
    vec_mask        = '0;
    rs1_o           = '0;
    rs2_o           = '0;
    rd_o            = '0;
    zimm            = '0;
    case (vopcode)

        // vector arithematic and set instructions opcode = 0x57
        V_ARITH: begin
            is_vec          = 1;
            case (vfunc3)
                OPIVV: begin
                    vec_write_addr  = vd;
                    vec_read_addr_1 = vs1;
                    vec_read_addr_2 = vs2;
                    vec_imm         = '0;
                    //scalar_addr     = '0;
                    vec_mask        = vm;
                end
                OPIVI: begin
                    vec_write_addr  = vd;
                    vec_read_addr_1 = '0;
                    vec_read_addr_2 = vs2;
                    vec_imm         = imm;
                    //scalar_addr     = '0;
                    vec_mask        = vm;
                end
                OPIVX: begin
                    vec_write_addr  = vd;
                    vec_read_addr_1 = '0;
                    vec_read_addr_2 = vs2;
                    vec_imm         = '0;
                    vec_mask        = vm;
                    //scalar_addr     = rs1_addr;
                end

                // vector configuration instructions
                CONF: begin
                    case (inst_msb[1])
                    // VSETVLI
                        1'b0: begin
                            rs1_o = rs1_i;
                            rs2_o =  '0; 
                            rd_o  = rd;
                            zimm  = vec_inst [30:20];
                        end
                        1'b1: begin
                            case (inst_msb[0])
                            // VSETIVLI
                                1'b1: begin
                                    rs1_o = '0;
                                    rs2_o = '0;
                                    rd_o  = rd; 
                                    zimm  = {'0,vec_inst [29:20]};
                                end
                            // VSETVL
                                1'b0: begin
                                    rs1_o = rs1_i;
                                    rs2_o = rs2_i;
                                    rd_o  =  rd;
                                    zimm  =  '0;
                                end
                            default: begin
                                rs1_o = '0;
                                rs2_o = '0;
                                rd_o  = '0;
                                zimm  = '0;
                            end
                            endcase
                        end
                        default: begin
                            rs1_o = '0;
                            rs2_o = '0;
                            rd_o  = '0;
                            zimm  = '0;
                        end
                    endcase
                end

                default: begin
                    vec_write_addr  = '0;
                    vec_read_addr_1 = '0;
                    vec_read_addr_2 = '0;
                    vec_imm         = '0;
                    //scalar_addr     = '0;
                    vec_mask        = '0;
                    rs2_o           = '0;
                    rs1_o           = '0;
                    rd_o            = '0;
                    zimm            = '0;
                end
            endcase
        end
        default: begin
            is_vec          = '0;
            vec_write_addr  = '0;
            vec_read_addr_1 = '0;
            vec_read_addr_2 = '0;
            vec_imm         = '0;
            //scalar_addr     = '0;
            vec_mask        = '0;
            rs1_o           = '0;
            rs2_o           = '0;
            rd_o            = '0;
            zimm            = '0;
        end
    endcase
end
    
/* Mux for vector configuration vtype and vl selections*/

// mux for selection of uimm or rs1 for vl
assign vlen_mux = (vl_sel) ? $unsigned(uimm) : rs1_o;

// mux for selection of zimm or rs2 for vtype
assign vtype = (vtype_sel) ? {'0 ,zimm} : rs2_o;

// AVL (application vector lenght) encoding
// comparing rs1 and rd addresses with x0
always_comb begin
    case (rs1rd_de)
        1'b0: vl = VLMAX;         // rs1 == x0
        1'b1: vl = ((vlen_mux > VLMAX) == 1) ? VLMAX : vlen_mux;      // rs1 != x0
        default: vl = vlen_mux;
    endcase
end

endmodule