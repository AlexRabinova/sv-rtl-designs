@echo off
REM --- Run ModelSim in Batch Mode (No GUI) and Generate Dump ---

echo Compiling and running simulation in background...

REM The -c flag tells vsim to run in console/batch mode without opening the GUI
vsim -c -do sim.do

echo Simulation finished. VCD dump should be ready.
pause