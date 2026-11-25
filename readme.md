# sv-rtl-designs

A personal study repository of Verilog and SystemVerilog RTL designs, testbenches, specifications, and simulation setups built as I develop foundational skills for a future career in digital design and verification.

## About This Repository & Workflow

* **Learning & Career Focus:** Each module and folder represents a concept I wanted to explore and implement hands-on—such as arbiters, clock-domain crossing (CDC), handshaking and flow control, bus protocols, state machines, and smaller RTL building blocks.
* **AI-Assisted Implementation:** The design intent, architectural goals, and learning direction come from my studies, while AI is used as a collaborative assistant to help draft and refactor SystemVerilog code, explain trade-offs, and troubleshoot—paired with my own simulation runs, waveform inspection, and iterative refinement.
* **Work in Progress:** Because this is a learning archive rather than a production IP library, designs reflect ongoing study milestones and may be revisited, refined, or expanded as my skills grow.

---

## Generic RTL Simulation Framework (`TEMPLATE/`)

A lightweight, automated command-line simulation setup for SystemVerilog and Verilog designs using AMD/Xilinx Vivado CLI tools (`xvlog`, `xelab`, `xsim`) on Windows. It helps keep project folders tidy by isolating compilation and simulation outputs inside a dedicated build directory.

### Required Project Directory Structure

When starting a new design from `TEMPLATE/`, organize your project folder using this layout:

```text
my_rtl_project/
│
├── rtl/               # Design Under Test (DUT) source files (.sv, .v)
├── tb/                # Testbench files (.sv, .v)
├── sim_build/         # Workspace for compilation and simulation artifacts (logs, .pb, .wdb, xsim.dir)
├── compile.prj        # Vivado project file listing RTL and testbench source paths
├── run.bat            # Automated build and simulation batch script
└── README.md          # Module-level notes or documentation