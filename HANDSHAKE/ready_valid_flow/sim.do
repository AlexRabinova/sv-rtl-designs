# Create and map the work library
if {[file exists work]} {
    vdel -all
}
vlib work

# Compile RTL and Testbench SystemVerilog files
vlog -sv rtl/vr_register_slice.sv
vlog -sv tb/tb_vr_register_slice.sv

# Load the simulation (adjust top-level module name if needed)
vsim -c -voptargs=+acc work.tb_vr_register_slice

# Enable VCD dumping (or ensure your testbench handles it via $dumpfile / $dumpvars)
# vcd file waveform.vcd
# vcd add -r /tb_vr_register_slice/*

# Run the simulation to completion
run -all

# Exit ModelSim command-line interface
quit