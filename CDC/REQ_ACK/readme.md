# Specification: CDC Handshake Synchronizer (Request-Acknowledge)

## 1. Overview & Purpose
The **CDC Handshake Synchronizer** is a synchronization mechanism used to safely transfer control signals or low-frequency configuration data between two asynchronous clock domains (`clk_src` and `clk_dst`). 

Unlike multi-bit streams that require an Asynchronous FIFO, this design uses a **Request-Acknowledge (Req/Ack) toggle handshake protocol** to guarantee that a transaction is fully recognized and acknowledged by the destination domain before the source domain initiates a new transfer.

---

## 2. Target Use Cases (When to Use)
* **Single-Bit Control Signals:** Safely crossing triggers, start/stop commands, interrupts, or enable flags from one clock domain to another.
* **Low-Frequency Configuration / Status Regs:** Infrequently changing control words where throughput is not a bottleneck and data can be held statically stable.
* **Low-Resource Environments:** Systems where an Asynchronous FIFO is too heavy or resource-intensive for simple control plane messaging.

### ⚠️ Important Limitations (Multi-Bit Data Warning)
* **Control vs. Data:** While the *control handshake* (request and acknowledge paths) is fully synchronized and safe, using this mechanism to directly cross a raw multi-bit data bus (`data_src_i` to `data_dst_o`) introduces risks of **spatial routing skew**. 
* **Rule of Thumb:** For continuous, high-throughput, or high-speed multi-bit data streams, **always use an Asynchronous FIFO** instead of a handshake synchronizer. If a handshake is used for multi-bit configuration, strict **Static Timing Analysis (STA) multicycle constraints** must be applied to ensure the source data remains statically stable while crossing.

---

## 3. Architecture & Handshake Protocol
1. **Request Phase:** The source domain asserts a request by toggling a request bit (`req_toggle_src`) and locking the data bus (`busy` goes high, halting new requests).
2. **Synchronization Phase:** The request signal passes through a standard 2-stage flip-flop synchronizer in the destination domain.
3. **Acknowledge Phase:** Upon detecting the synchronized request pulse, the destination domain captures the data, asserts/toggles an acknowledge signal (`ack_toggle_dst`), and pulses `valid_dst_o`.
4. **Completion Phase:** The acknowledge signal passes back through a 2-stage synchronizer in the source domain. Once received, the source drops its `busy` flag and becomes `ready_src_o` for the next request.

---

## 4. Pinout & Interface Definition

| Signal Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| **Source Domain Signals** | | | |
| `clk_src` | Input | 1 | Source clock domain |
| `rst_src_n` | Input | 1 | Asynchronous active-low reset (Source domain) |
| `valid_src_i` | Input | 1 | Request pulse to initiate a transfer |
| `data_src_i` | Input | `DATA_WIDTH` | Data payload to transfer |
| `ready_src_o` | Output | 1 | High when the synchronizer is ready for a new request |
| **Destination Domain Signals** | | | |
| `clk_dst` | Input | 1 | Destination clock domain |
| `rst_dst_n` | Input | 1 | Asynchronous active-low reset (Destination domain) |
| `valid_dst_o` | Output | 1 | Single-cycle pulse indicating new valid data has arrived |
| `data_dst_o` | Output | `DATA_WIDTH` | Synchronized data payload in the destination domain |

---

## 5. Parameters

* `DATA_WIDTH`: Integer parameter defining the width of the data payload bus (Default: `8`).

---

## 6. Verification & CDC Guidelines
* **Lint & CDC Tools:** Industrial CDC tools (e.g., SpyGlass CDC, Questa CDC) will flag direct register-to-register multi-bit bus paths. Waivers or structural multi-cycle path constraints (`set_multicycle_path`) must be enforced if data is bundled with the handshake.
* **Metastability Protection:** All asynchronous crossings (`req` into `clk_dst` and `ack` into `clk_src`) utilize mandatory 2-stage D flip-flop synchronizers to reduce Mean Time Between Failures (MTBF) due to metastability to acceptable levels.