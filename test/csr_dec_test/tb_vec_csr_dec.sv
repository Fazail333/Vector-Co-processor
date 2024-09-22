<<<<<<< HEAD
module tb_vec_csr_dec #(
=======
module tb_decode #(
>>>>>>> 8339f23 (added unit test for csr and decode)
    XLEN = 32,
    VLMAX = 512
)();

logic               clk;
logic               n_rst;

logic [XLEN-1:0]    vec_inst;
logic [XLEN-1:0]    rs1_i;
logic [XLEN-1:0]    rs2_i;

logic               is_vec_inst;

vec_csr_dec DUT (
    .clk            (clk),
    .n_rst          (n_rst),

    .vec_inst       (vec_inst),
    .rs1_i          (rs1_i),
    .rs2_i          (rs2_i),

    .is_vec_inst    (is_vec_inst)
);

initial begin
        clk = 1;
    forever begin
        clk = #20 ~clk;
    end
end

initial begin
    init_signals;
    reset_sequence;

    // vl=VLMAX , sew = 32, lmul = 1, conf=vsetvli 
    vec_inst <= 32'h01007057;
    rs1_i    <= 32'h0000000f;
    rs2_i    <= 32'h00001200;
    @(posedge clk);
    // vl=uimm , sew = 32, lmul = 1, conf=vsetivli
    vec_inst <= 32'hc1087157;
    @(posedge clk);
    // vl=rs1 , sew = 32, lmul = 1, conf=vetvl
    rs2_i    <= 32'h00000010;
    vec_inst <= 32'h8030f157;
    repeat(2) @(posedge clk);
    $stop;
end

task init_signals;
    rs1_i    <= '0; rs2_i <= '0;
    vec_inst <= '0; n_rst <= 1;
endtask

task reset_sequence;
    @(posedge clk);
    n_rst <= '0;
    @(posedge clk);
    n_rst <=  1;
endtask


endmodule