SRC_SV:= src/val_ready_controller.sv  		\
	 src/vec_csr_dec.sv  					\
	 src/vec_lsu.sv  						\
	 src/vec_regfile.sv  					\
	 src/vec_csr_regfile.sv  				\
	 src/vec_decode.sv  					\
	 src/vec_mask_unit.sv					\
	 src/vector_processor_controller.sv  	\
	 src/vector_processor.sv				\
	 test/vector_processor_tb.sv			\
	 src/vector_processor_datapath.sv

DEFINES_VIV:= define/vec_de_csr_defs.svh 	\
	define/vec_regfile_defs.svh			\
	define/vector_processor_defs.svh

WORK_DIR = work

COMP_OPTS_SV := --incr --relax

TB_TOP := vector_processor_tb
MODULE := vector_processor_tb

#==== Default target - running VIVADO simulation without drawing waveforms ====#
.PHONY: vivado viv_elaborate viv_compile

vivado : $(TB_TOP)_snapshot.wdb

viv_elaborate : .elab.timestamp

viv_compile : .comp_sv.timestamp .comp_v.timestamp .comp_vhdl.timestamp

#==== WAVEFORM DRAWING ====#
.PHONY: viv_waves
viv_waves : $(TB_TOP)_snapshot.wdb
	@echo
	@echo "### OPENING VIVADO WAVES ###"
	xsim --gui $(TB_TOP)_snapshot.wdb

#==== SIMULATION ====#
$(TB_TOP)_snapshot.wdb : .elab.timestamp 
	@echo
	@echo "### RUNNING SIMULATION ###"
	xsim $(TB_TOP)_snapshot --tclbatch xsim_cfg.tcl

#==== ELABORATION ====#
.elab.timestamp : .comp_sv.timestamp .comp_v.timestamp .comp_vhdl.timestamp
	@echo 
	@echo "### ELABORATION ###"
	xelab -debug all -top $(TB_TOP) -snapshot $(TB_TOP)_snapshot
	touch $@	

#==== COMPILING SYSTEMVERILOG ====#	
ifeq ($(SRC_SV),)
.comp_sv.timestamp :
	@echo 
	@echo "### NO SYSTEMVERILOG SOUCES GIVEN ###"
	@echo "### SKIPPED SYSTEMVERILOG COMPILATION ###"
	touch $@
else 
.comp_sv.timestamp : $(SRC_SV)
	@echo
	@echo "### COMPILING SYSTEMVERILOG ###"
	rm -rf xsim_cfg.tcl
	@echo "log_wave -recursive *" > xsim_cfg.tcl
	@echo "run all" >> xsim_cfg.tcl
	@echo "exit" >> xsim_cfg.tcl
	# verilog -VIVADO  
	xvlog -sv -d ROOT_PATH="\"$(PWD)\"" $(COMP_OPTS_SV) $(DEFINES_VIV) $(SRC_SV)
	touch $@
endif

#==== COMPILING VERILOG ====#	
ifeq ($(SRC_V),)
.comp_v.timestamp :
	@echo
	@echo "### NO VERILOG SOURCES GIVEN ###"
	@echo "### SKIPPED VERILOG COMPILATION ###"
	touch $@
else
.comp_v.timestamp : $(SRC_V)
	@echo 
	@echo "### COMPILING VERILOG ###"
	xvlog $(COMP_OPTS_V) $(SRC_V)
	touch $@
endif 

#==== COMPILING VHDL ====#	
ifeq ($(SRC_VHDL),)
.comp_vhdl.timestamp :
	@echo
	@echo "### NO VHDL SOURCES GIVEN ###"
	@echo "### SKIPPED VHDL COMPILATION ###"
	touch $@
else
.comp_vhdl.timestamp : $(SRC_VHDL)
	@echo 
	@echo "### COMPILING VHDL ###"
	xvhdl $(COMP_OPTS) $(SRC_VHDL)
	touch $@
endif

#----------------------#
#----- MODEL SIM ------#
#----------------------#

vsim: vsim_compile simulate

# Create a working library and compile source files
vsim_compile: $(wildcard *.sv)
	@echo "Creating work library..."
	vlib $(WORK_DIR)
	@echo "Compiling source files..."
	vlog -work $(WORK_DIR) +define+ROOT_PATH=\"$(PWD)\" $(SRC_SV)

# Run the simulation and generate WLF file
simulate: vsim_compile
	@echo "Running simulation..."
	vsim -L $(WORK_DIR) $(MODULE) -do "add wave -radix Unsigned sim:/$(MODULE)/VECTOR_PROCESSOR/*; run -all"

.PHONY : clean
clean :
	@echo "Cleaning up..."
	rm -rf ./test/__pycache__ ./test/sim_build
	rm -rf ./test/*.vcd ./test/*.xml ./test/*.log
	rm -rf $(WORK_DIR) transcript vsim.wlf
	rm -rf *.jou *.log *.pb *.wdb xsim.dir *.str
	rm -rf .*.timestamp *.tcl *.vcd .*.verilate
	rm -rf obj_dir .Xil