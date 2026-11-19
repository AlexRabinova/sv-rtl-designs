# Valid-Ready Register Slice & Skid Buffer

A high-performance, fully pipelined **valid-ready register slice** with a **skid buffer** implemented in SystemVerilog. 

This module acts as an isolation barrier between an upstream producer and a downstream consumer in handshake-based streaming architectures (such as AXI4-Stream). It breaks critical combinatorial timing paths while maintaining **zero-bubble throughput** and lossless backpressure handling.

---

## Features

* **Combinational Path Isolation:** The upstream ready signal (`s_ready`) depends solely on internal buffer state, completely decoupling it from downstream ready (`m_ready`) backpressure.
* **Zero-Latency Pass-Through:** When the downstream consumer is ready and the backup buffer is clear, data flows straight through with minimal latency penalty.
* **Lossless Backpressure (Skid Buffer):** Safely captures and holds incoming upstream data if a sudden downstream stall occurs while the main register is occupied.
* **Parameterized Width:** Configurable data path width (`DATA_WIDTH`).

---

## Interface Signals

| Signal Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | Clock |
| `rst_n` | Input | 1 | Active-low asynchronous reset |
| `s_valid` | Input | 1 | Upstream valid handshake |
| `s_ready` | Output | 1 | Upstream ready handshake |
| `s_data` | Input | `DATA_WIDTH` | Upstream data payload |
| `m_valid` | Output | 1 | Downstream valid handshake |
| `m_ready` | Input | 1 | Downstream ready handshake |
| `m_data` | Output | `DATA_WIDTH` | Downstream data payload |

---

## Architecture & How It Works

The design consists of two storage layers:
1. **Main Output Register (`m_data`, `m_valid`):** The primary channel feeding the downstream consumer.
2. **Skid Buffer (`reg_data`, `reg_valid`):** A backup holding cell used when downstream stalls and upstream keeps sending data.

### Pass-Through Mode
When `m_ready = 1` and `reg_valid = 0`:
* `s_ready` is high (`1`), telling the producer it can send data.
* Data streams directly from upstream to downstream with a standard single-stage register latency.

### Backpressure & Skid Action
When downstream drops `m_ready = 0` (stalling) while upstream sends a valid item (`s_valid = 1`):
1. Because the skid buffer was empty, `s_ready` was high, meaning the producer successfully transmitted a final item.
2. The main register holds its current valid data because the consumer cannot accept it.
3. The incoming data is caught and stored ("skidded") into `reg_data`, and `reg_valid` is asserted.
4. On the next cycle, `s_ready` drops to `0`, successfully halting the upstream producer without data loss or overwriting.

### Recovery
When downstream re-asserts `m_ready = 1`:
1. The data waiting in the skid buffer is promoted to the main output register (`m_data`).
2. `reg_valid` is cleared.
3. `s_ready` returns to high (`1`), allowing the producer to resume transmission.

---

## Performance Trade-offs

| Advantage / Benefit | Disadvantage / Cost |
| :--- | :--- |
| **Timing Isolation:** Eliminates long combinatorial paths between input ready and output ready, boosting maximum clock frequency ($F_{max}$). | **Area Overhead:** Requires double data storage registers (main + skid) alongside multiplexing control logic. |
| **Full Throughput:** Sustains a 1 item per clock cycle transfer rate under normal streaming conditions. | **Design Complexity:** Control state transitions (pass-through, capture, promotion) require careful verification. |
| **Lossless Handshaking:** Perfectly handles abrupt downstream stalls without dropping data packets. | |

---

## Simulation & Testbench

A comprehensive, self-checking testbench (`tb_vr_register_slice.sv`) is included to stress-test the module. It features:
* **AXI-Style Handshaking:** Models realistic upstream traffic with random gaps.
* **Aggressive Random Backpressure:** Randomly asserts and deasserts `m_ready` (introducing 25%+ stall rates) to force frequent skid and recovery cycles.
* **Automated Scoreboarding:** Uses a reference queue to monitor transactions and ensure zero data corruption or loss across thousands of cycles.

### Running the Simulation
Compile and run the files using any standard SystemVerilog simulator (e.g., ModelSim, VCS, Xcelium, or open-source Verilator):
```bash
vlog vr_register_slice.sv tb_vr_register_slice.sv
vsim -c tb_vr_register_slice -run