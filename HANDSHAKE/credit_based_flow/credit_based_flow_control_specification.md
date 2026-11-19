# Credit-Based Flow Control Protocol Specification

## 1. Overview
This document specifies the architecture, interfaces, and behavior for a hardware-level **Credit-Based Flow Control** system designed for lossless, point-to-point packet or flit communication between a Transmitter (Tx) Module and a Receiver (Rx) Module.

The protocol ensures that the Tx module never sends data unless the Rx module has guaranteed buffer space available to accept it, preventing packet loss due to FIFO overflows.

---

## 2. System Architecture

```
+--------------------------+                         +--------------------------+
|        Tx Module         |                         |        Rx Module         |
|                          | -- Data [N-1:0] ------> |                          |
|  +--------------------+  | -- Valid -------------> |  +--------------------+  |
|  | Credit Counter     |  | <-- Ready / Return --- |  | Rx Buffer / FIFO   |  |
|  | Max Credits: M     |  |                         |  | Capacity: M        |  |
|  +--------------------+  | <-- Credit Return Val - |  +--------------------+  |
+--------------------------+                         +--------------------------+
```

---

## 3. Signal Interface Definitions

### 3.1 Data Flow Interface (Tx → Rx)
| Signal Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 bit | System clock signal (synchronous interface). |
| `rst_n` | Input | 1 bit | Active-low asynchronous reset. |
| `tx_data` | Tx → Rx | `DATA_WIDTH` | Payload data (Flit/Packet). |
| `tx_valid` | Tx → Rx | 1 bit | Asserted high when `tx_data` is valid. |

### 3.2 Credit Return Interface (Rx → Tx)
| Signal Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `rx_credit_return` | Rx → Tx | 1 bit | Asserted high when Rx frees a buffer slot. |
| `rx_credit_count` | Rx → Tx | `CREDIT_WIDTH` | Optional: Incremental or absolute credit return count (default: 1 credit per pulse). |

---

## 4. Operational Parameters

| Parameter | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `DATA_WIDTH` | Integer | 64 | Bit-width of the data bus. |
| `MAX_CREDITS` | Integer | 16 | Depth of the Rx buffer (maximum credits held). |
| `CREDIT_WIDTH`| Integer | $\lceil \log_2(\text{MAX\_CREDITS} + 1) \rceil$ | Bit-width required to store maximum credit count. |

---

## 5. Module Specifications

### 5.1 Transmitter (Tx) Module

#### Internal Registers
- **`credit_counter`**: Tracks currently available credits. Initialized to `MAX_CREDITS` (or determined via initial credit exchange sequence).

#### Protocol Rules
1. **Transmission Condition**: Tx can transmit data (`tx_valid = 1`) **if and only if** `credit_counter > 0`.
2. **Decrement Logic**: On every clock cycle where `tx_valid` is asserted and accepted (`tx_valid && credit_counter > 0`), decrement `credit_counter` by 1.
3. **Increment Logic**: On every clock cycle where `rx_credit_return` is asserted, increment `credit_counter` by 1 (or by `rx_credit_count`).
4. **Simultaneous Operation**: If a credit return occurs simultaneously with a transmission:
   $$\text{credit\_counter}_{\text{next}} = \text{credit\_counter} - 1 + 1 = \text{credit\_counter}$$

#### Tx State Machine / Flow
```
                     +-----------------------+
                     |         RESET         |
                     | credit_count = MAX    |
                     +-----------------------+
                                 |
                                 v
+------------------------------------------------------------------+
|                              IDLE                                |
|             Waiting for Tx Data Request / Credit Check           |
+------------------------------------------------------------------+
          |                                            ^
          | (tx_req == 1) && (credit_counter > 0)      | Done / No Req
          v                                            |
+------------------------------------------------------------------+
|                            TRANSMIT                              |
| - Assert tx_valid                                                |
| - Decrement credit_counter                                       |
| - Apply credit_return increment if active                        |
+------------------------------------------------------------------+
```

---

### 5.2 Receiver (Rx) Module

#### Internal Registers & Components
- **`rx_fifo`**: Storage element of depth `MAX_CREDITS`.
- **`read_pointer` / `write_pointer`**: Pointers for FIFO management.

#### Protocol Rules
1. **Ingest Logic**: When `tx_valid` is high, sample `tx_data` and write into the Rx FIFO. Since Tx respects credit limits, buffer overflow is guaranteed not to occur.
2. **Egress / Release Logic**: When downstream logic consumes a data entry from `rx_fifo`, assert `rx_credit_return` for 1 clock cycle to inform Tx that a slot has freed up.
3. **Credit Initialization**: During reset/initialization, Rx must reset its internal FIFO pointers and signal readiness to Tx.

---

## 6. Edge Cases & Handling

### 6.1 Latency Tolerance
Credit-based flow control naturally absorbs round-trip pipeline latency ($L_{RTT}$). 
To prevent throughput degradation, `MAX_CREDITS` must satisfy:
$$\text{MAX\_CREDITS} \ge \text{Rx\_Buffer\_Depth} \ge \text{Bandwidth} \times L_{RTT}$$

### 6.2 Credit Loss / Corruption Prevention
- For high-reliability links, credit counters can periodically synchronize via a full credit refresh or status packet.
- Sideband parity or CRC check on credit return lines is recommended for noisy physical interconnects.

---

## 7. Timing Example

```
Clock            : --_--_--_--_--_--_--_--_--_--_
tx_valid         : ____/'''''''''\_______________
credit_counter   : (16)(15)(14)(13)(13)(14)(15)
rx_credit_return : _______________/'''''\_________
```
* **Cycle 1-3**: Tx sends data, decrementing `credit_counter` from 16 to 13.
* **Cycle 5-6**: Rx processes data, asserting `rx_credit_return`, incrementing `credit_counter` back up.