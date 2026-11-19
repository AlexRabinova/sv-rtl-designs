@echo off
REM =====================================================================
REM Batch Script to Run ModelSim Simulation for Async FIFO
REM =====================================================================

echo Starting ModelSim simulation...

REM Run ModelSim in batch mode (-c) and execute the .do script
vsim -c -do run.do

echo Simulation finished.
pause