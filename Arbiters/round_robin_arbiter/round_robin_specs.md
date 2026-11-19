# Functional Specification: Parameterized Round-Robin Arbiter (`rr_arbiter`)

## 1. Overview
The `rr_arbiter` is a parameterized, fair-access Round-Robin Arbiter designed in SystemVerilog. It ensures equitable access sharing among multiple requesters by dynamically shifting the priority base after each successful grant. The architecture leverages high-efficiency parallel arithmetic (`x & -x` LSB extraction) combined with a split high/low zone partitioning scheme, avoiding deep priority chains and optimizing critical-path latency.

---

## 2. Module Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `WIDTH` | `int` | `4` | Bit-width of the request, mask, and grant vectors (number of arbitration channels). |

---

## 3. Interface Signals

| Signal Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | `1` | System clock. State updates occur on the positive edge. |
| `rst_n` | Input | `1` | Asynchronous active-low reset. Initializes the rotation pointer. |
| `req` | Input | `WIDTH` | Raw request vector. Each bit represents a requester's access demand. |
| `mask` | Input | `WIDTH` | External qualification/disable mask. Set to all `1`s for unmasked operation. |
| `grant` | Output | `WIDTH` | One-hot encoded grant output vector indicating which requester won access. |

---

## 4. Microarchitecture & Detailed Operation

The arbitration mechanism is divided into six sequential stages within the combinatorial and sequential datapath:

### Step 1: Request Qualification
Incoming requests are qualified against an external enable/disable mask to filter out disabled channels:
$$\text{req\_active} = \text{req} \ \& \ \text{mask}$$

### Step 2: High-Zone Mask Generation
Using the current one-hot pointer (`ptr_oh`), a high-zone mask is generated via two's complement inversion:
$$\text{mask\_hi} = \sim(\text{ptr\_oh} - 1)$$
This mask separates requesters located at or above the current pointer index from those below it.

### Step 3: Zone Partitioning
Active requests are partitioned into two priority groups:
* **High Zone (`req_hi`):** Requesters from the current pointer position up to the MSB.
* **Low Zone (`req_lo`):** Requesters from index 0 up to just below the current pointer position.

$$\text{req\_hi} = \text{req\_active} \ \& \ \text{mask\_hi}$$
$$\text{req\_lo} = \text{req\_active} \ \& \ \sim\text{mask\_hi}$$

### Step 4: Parallel Priority Evaluation (`x & -x`)
Instead of a slow serial `if-else` multiplexer chain, the arbiter uses parallel two's complement arithmetic (`x & -x`) to isolate the lowest set bit (highest priority within each zone):
$$\text{grant\_hi} = \text{req\_hi} \ \& \ (-\text{req\_hi})$$
$$\text{grant\_lo} = \text{req\_lo} \ \& \ (-\text{req\_lo})$$

### Step 5: Final Grant Selection
The arbiter prioritizes the High Zone. If any active request exists in the high zone (`any_hi`), `grant_hi` is selected; otherwise, it falls back to `grant_lo`:
$$\text{any\_hi} = \vert{}\text{req\_hi}$$
$$\text{grant} = \text{any\_hi} \ ? \ \text{grant\_hi} \ : \ \text{grant\_lo}$$

### Step 6: Pointer Update & Rotation Logic
* **Reset State (`rst_n == 0`):** The pointer `ptr_oh` resets to `1'b1` (pointing to index 0 as a one-hot vector).
* **Grant Update (`|grant == 1`):** On the rising edge of `clk`, if a grant was issued, the pointer rotates left with wrap-around, giving priority to the next adjacent channel:
  $$\text{ptr\_oh} \leftarrow \{\text{grant}[WIDTH-2:0], \text{grant}[WIDTH-1]\}$$
* **Idle State (`|grant == 0`):** The pointer holds its current value when no requests are active.

---

## 5. Design Verification & Timing Characteristics
* **Fairness:** Guarantees starvation-free access rotation across all active channels.
* **Combinatorial Depth:** Minimized via parallel bitwise logic and arithmetic carry-chains, ensuring excellent timing closure for wide-bus configurations in ASIC and FPGA environments.