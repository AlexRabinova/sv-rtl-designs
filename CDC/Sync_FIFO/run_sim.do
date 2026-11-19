vlib work
vmap work work

# 2. Compile Design RTL and Testbench
vlog -sv rtl/non_pow2_fifo_fsm.sv
vlog -sv tb/tb_non_pow2_fifo_fsm.sv

# 3. Optimize and Start Simulation
vsim -voptargs="+acc" work.tb_non_pow2_fifo_fsm

# 4. Configure VCD File Generation
vcd file dump1.vcd
vcd add -r /tb_non_pow2_fifo_fsm/*

# 6. Run Simulation until $finish
run -all

# 7. Flush and close VCD file safely
vcd flush dump1.vcd

# Zoom full in Wave window
wave zoom full