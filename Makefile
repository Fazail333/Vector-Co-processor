# ========= FILE LISTS ===========

PKG_SV := ./AXI-4/define/axi_4_pkg.sv
SRC_PKG_HDR := \
	./define/vec_de_csr_defs.svh \
	./define/vec_regfile_defs.svh \
	./define/vector_processor_defs.svh \
	./AXI-4/define/axi_4_defs.svh

SRC_SV := ./src/val_ready_controller.sv \
		  ./src/vec_csr_dec.sv \
		  ./src/vec_lsu.sv \
		  ./src/vec_regfile.sv \
		  ./src/vec_csr_regfile.sv \
		  ./src/vec_decode.sv \
		  ./src/vec_mask_unit.sv \
		  ./src/vector_processor_controller.sv \
		  ./src/vector_processor.sv \
		  ./src/vector_processor_datapath.sv \
		  ./test/vector_processor_tb.sv \
		  ./AXI-4/src/axi_4_master_controller.sv \
		  ./AXI-4/src/axi_4_master.sv \
		  ./AXI-4/src/axi_4_slave_controller.sv \
		  ./AXI-4/src/axi_4_slave_mem.sv

INCLUDE_DIRS := \
	+incdir+$(PWD)/define \
	+incdir+$(PWD)/AXI-4/define \
	+incdir+$(PWD)/src \
	+incdir+$(PWD)/AXI-4/src \
	+incdir+$(PWD)/test

WORK_DIR := work
TB_TOP := vector_processor_tb
MODULE := vector_processor_tb
COMP_OPTS_SV := --incr --relax

# ========= VIVADO FLOW ===========

.PHONY: vivado viv_elaborate viv_compile viv_waves clean vsim vsim_compile simulate

vivado: $(TB_TOP)_snapshot.wdb

viv_waves: $(TB_TOP)_snapshot.wdb
	@echo "### OPENING VIVADO WAVES ###"
	xsim --gui $(TB_TOP)_snapshot.wdb

$(TB_TOP)_snapshot.wdb: .elab.timestamp
	@echo "### RUNNING SIMULATION ###"
	xsim $(TB_TOP)_snapshot --tclbatch xsim_cfg.tcl

.elab.timestamp: .comp_pkg_sv.timestamp .comp_sv.timestamp
	@echo "### ELABORATION ###"
	xelab -debug all -top $(TB_TOP) -snapshot $(TB_TOP)_snapshot
	touch $@

.comp_pkg_sv.timestamp: $(PKG_SV)
	@echo "### COMPILING PACKAGES ###"
	xvlog -sv $(COMP_OPTS_SV) $(INCLUDE_DIRS) $(PKG_SV)
	touch $@

.comp_sv.timestamp: $(SRC_SV)
	@echo "### COMPILING SV SOURCES ###"
	rm -f xsim_cfg.tcl
	echo "log_wave -recursive *" > xsim_cfg.tcl
	echo "run all" >> xsim_cfg.tcl
	echo "exit" >> xsim_cfg.tcl
	xvlog -sv $(COMP_OPTS_SV) $(INCLUDE_DIRS) $(SRC_SV)
	touch $@

# ========= MODELSIM FLOW ===========

vsim: vsim_compile simulate

vsim_compile:
	@echo "### COMPILING FOR MODELSIM ###"
	vlib $(WORK_DIR)
	vlog -work $(WORK_DIR) -sv $(INCLUDE_DIRS) $(PKG_SV)
	vlog -work $(WORK_DIR) -sv $(INCLUDE_DIRS) $(SRC_SV)

simulate:
	@echo "### RUNNING MODELSIM ###"
	vsim -L $(WORK_DIR) $(MODULE) -do "add wave -radix Unsigned sim:/$(MODULE)/VECTOR_PROCESSOR/*; run -all"

# ========= CLEANUP ===========

clean:
	@echo "Cleaning..."
	rm -rf ./test/__pycache__ ./test/sim_build
	rm -rf ./test/*.vcd ./test/*.xml ./test/*.log
	rm -rf $(WORK_DIR) transcript vsim.wlf
	rm -rf *.jou *.log *.pb *.wdb xsim.dir *.str
	rm -rf .*.timestamp *.tcl *.vcd .*.verilate
	rm -rf obj_dir .Xil
