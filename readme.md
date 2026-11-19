# Generic RTL Simulation Framework (Vivado CLI / XSim)

A lightweight, automated, and clean command-line simulation framework for SystemVerilog and Verilog designs using AMD/Xilinx Vivado tools (`xvlog`, `xelab`, `xsim`) on Windows. 

This framework keeps your project root organized by isolating all simulation artifacts, logs, and cache files inside an automatically managed build folder.

---

## 📂 Required Project Directory Structure

For the automated simulation script to find your files and execute correctly, your project folder must follow this exact layout:

```text
my_rtl_project/
│
├── rtl/               # Design Under Test (DUT) source files (.sv, .v)
├── tb/                # Testbench files (.sv, .v)
├── sim_build/         # Auto-generated workspace for compilation and simulation artifacts (git-ignored)
├── compile.prj        # Vivado project file specifying file compilation paths
├── run.bat            # Automated 4-step build and simulation execution script
└── README.md          # Project documentation