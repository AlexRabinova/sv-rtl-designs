# Hardware Design Specification: Asynchronous FIFO (`async_fifo`)

## 1. Overview & Architecture
The `async_fifo` module provides a safe, robust data buffering mechanism for passing multi-bit data words between two independent, asynchronous clock domains (the Write Clock Domain and the Read Clock Domain).

To guarantee reliable data transfer and prevent metastability during Clock Domain Crossing (CDC), the architecture utilizes:
* **Gray code pointer encoding** to ensure only a single bit changes between adjacent pointer increments.
* **2-stage synchronizer chains** to safely cross pointers between asynchronous domains.
* Combinatorial pointer comparisons to determine full and empty status flags with conservative safety margins.

---

## 2. Interface Signals

| Signal Name | Direction | Clock Domain | Width | Description |
| :--- | :---: | :---: | :---: | :--- |
| **`wclk`** | Input | - | 1 | Write clock domain reference. |
| **`wrst_n`** | Input | `wclk` | 1 | Active-low asynchronous reset for the write domain. |
| **`winc`** | Input | `wclk` | 1 | Write increment control (Push). Active high when valid data is present on `wdata`. |
| **`wdata`** | Input | `wclk` | `DATA_WIDTH` | Data input bus written into the FIFO. |
| **`wfull`** | Output | `wclk` | 1 | FIFO full flag. High when no more writes are permitted. |
| **`rclk`** | Input | - | 1 | Read clock domain reference. |
| **`rrst_n`** | Input | `rclk` | 1 | Active-low asynchronous reset for the read domain. |
| **`rinc`** | Input | `rclk` | 1 | Read increment control (Pop). Active high to request the next data item. |
| **`rdata`** | Output | `rclk` | `DATA_WIDTH` | Data output bus. Valid when `rempty` is low. |
| **`rempty`** | Output | `rclk` | 1 | FIFO empty flag. High when no data is available to read. |

---

## 3. Parameters

| Parameter Name | Default Value | Description |
| :--- | :---: | :--- |
| **`DATA_WIDTH`** | `32` | Width of the data bus in bits. |
| **`ADDR_WIDTH`** | `4` | Width of the FIFO pointer addresses, determining a depth of $2^{ADDR\_WIDTH}$ (default depth = 16). |

---

## 4. Functional Behavior & Rules

### 4.1 Reset Behavior
* Both write and read domains feature asynchronous assertion and synchronous deassertion (`async_reset, sync_release`) via their respective reset inputs (`wrst_n`, `rrst_n`).
* Upon reset, all internal read/write binary and Gray pointers, synchronizer registers, and status flags (`wfull`, `rempty`) are cleared to zero.

### 4.2 Write Operation (`wclk` Domain)
* A write operation occurs when **`winc` is asserted (HIGH)** and the FIFO is **not full (`wfull` is LOW)**.
* When active, `wdata` is written into the internal dual-port RAM array at the address specified by the lower bits of the binary write pointer.
* The binary write pointer increments by 1, and its Gray-code equivalent is registered and synchronized across to the read domain.
* If `winc` is asserted while `wfull` is HIGH, the write request is ignored to prevent memory overflow.

### 4.3 Read Operation (`rclk` Domain)
* A read operation occurs when **`rinc` is asserted (HIGH)** and the FIFO is **not empty (`rempty` is LOW)**.
* When active, `rdata` outputs the word stored at the address indicated by the lower bits of the binary read pointer.
* The binary read pointer increments by 1, and its Gray-code equivalent is registered and synchronized across to the write domain.
* If `rinc` is asserted while `rempty` is HIGH, the read request is ignored to prevent memory underflow.

---

## 5. Status Flag Generation & CDC Rules

### 5.1 Empty Flag (`rempty`) Logic
* **Condition:** The FIFO is empty when the synchronized write pointer equals the current read pointer ($Gray\_WPtr_{sync} == Gray\_RPtr$).
* **Behavior:** Asserted combinationally in the `rclk` domain. 

### 5.2 Full Flag (`wfull`) Logic
* **Condition:** The FIFO is full when the synchronized read pointer matches the inverted upper two bits of the write pointer while keeping the remaining bits identical ($Gray\_RPtr_{sync} == \sim WPtr[ADDR:ADDR-1] \ \& \ WPtr[ADDR-2:0]$).
* **Behavior:** Asserted combinationally in the `wclk` domain.

### 5.3 Latency & Safety Margins
* **Write-to-Read Latency:** Due to the 2-stage synchronizer delay, `rempty` deassertion lags a write operation by 2 to 3 `rclk` cycles. This is safe because it only delays data availability slightly rather than corrupting data.
* **Read-to-Write Latency:** `wfull` deassertion lags a read operation by 2 to 3 `wclk` cycles. This introduces conservative safety latency (the write side may temporarily think the FIFO is full a few cycles longer than it actually is, safely preventing overflow).

---

## 6. Verification & Corner Cases

* **Underflow / Overflow Protection:** Verify that asserting `winc` while `wfull=1` does not corrupt pointers or overwrite unread data. Verify that asserting `rinc` while `rempty=1` does not alter `rdata` or corrupt pointers.
* **Asynchronous Frequency Ratios:** Test across various clock frequency ratios ($f_{wclk} \gg f_{rclk}$, $f_{rclk} \gg f_{wclk}$, and near-equal frequencies with phase drift).
* **Simultaneous Read & Write:** Ensure correct behavior when a push and pop occur on the exact same clock cycle under half-full conditions.