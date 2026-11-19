# 1. Create and map the working library
vlib work
vmap work work

# 2. Compile RTL files
vlog -sv rtl/axis_skid_buffer_ingress.sv
vlog -sv rtl/axis_skid_buffer_egress.sv
vlog -sv rtl/sync_fifo.sv
vlog -sv rtl/sync_fifo_axis_skid.sv

# 3. Compile Testbench file
vlog -sv tb/tb_axis_fifo_fwft.sv

# 4. Elaborate/Simulate the top testbench module
vsim -c work.tb_axis_fifo_fwft

# 5. Set up VCD dumping (dumps all signals recursively)
vcd file dump.vcd
vcd add -r /tb_axis_fifo_fwft/*

# 6. Run simulation until $finish
run -all

# 7. Quit simulation
quit -f