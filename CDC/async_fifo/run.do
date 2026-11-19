# =====================================================================
# ModelSim Simulation Script for tb_async_fifo
# =====================================================================

# 1. Create and map the working library
if [file exists work] {
    vdel -all -lib work
}
vlib work

# 2. Compile RTL and Testbench files
# (Adjust file paths/names if your source files have different names)
vlog -work work rtl/async_fifo.sv
vlog -work work tb/tb_async_fifo.sv

# 3. Load the top-level testbench into the simulator
vsim -voptargs="+acc" work.tb_async_fifo

# 4. Add waves to the waveform window (optional, but helpful)
add wave -r /tb_async_fifo/*

# 5. Run the simulation
run -all

# 6. Zoom out to fit the waveform to the window view
wave zoom full