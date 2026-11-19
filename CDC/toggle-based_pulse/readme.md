# Specification: Toggle-Based Pulse Synchronizer (CDC Module)

## 1. Overview
The `pulse_synchronizer` module is a robust clock domain crossing (CDC) component designed to safely transfer a single-cycle pulse from a source clock domain (`clk_src`) to a destination clock domain (`clk_dst`). 

Unlike a pulse stretcher that extends a signal into a multi-cycle level window, this module uses an **edge-to-level toggle mechanism** to bridge the asynchronous boundary safely and then converts the transition back into a clean, single-cycle pulse in the destination domain.

---

## 2. Architecture & Operation Principle

The module operates in three distinct stages:

1. **Source Domain (Edge to Level - Toggle):**
   * When a narrow `pulse_in` arrives, it flips a toggle register (`toggle_src <= ~toggle_src`). This transforms a temporary transient pulse into a stable level change.
2. **Clock Domain Crossing (Synchronizer Chain):**
   * The stable toggle signal passes through a multi-stage flip-flop synchronizer chain (typically 2 or 3 stages) clocked by `clk_dst` to eliminate metastability risks.
3. **Destination Domain (Level to Edge - Pulse Generation):**
   * An edge detector in the destination domain compares the current synchronized signal with its previous cycle value. Whenever a transition (rising or falling edge) is detected, it generates a clean, single-cycle `pulse_out` synchronized to `clk_dst`.

---

## 3. Interface Signals

| Signal Name | Direction | Clock Domain | Description |
| :--- | :--- | :--- | :--- |
| `clk_src` | Input | Source | Source clock domain |
| `rst_src_n` | Input | Source | Asynchronous active-low reset for source logic |
| `pulse_in` | Input | Source | Input pulse to be transferred (active high, 1 cycle wide) |
| `clk_dst` | Input | Destination | Destination clock domain |
| `rst_dst_n` | Input | Destination | Asynchronous active-low reset for destination logic |
| `pulse_out` | Output | Destination | Clean single-cycle output pulse in destination domain |

---

## 4. Parameters

| Parameter Name | Default | Description |
| :--- | :--- | :--- |
| `SYNC_STAGES` | `2` | Number of synchronizer flip-flop stages (minimum 2 for metastability protection). |

---

## 5. Design Guidelines & Limitations

* **Throughput / Handshake Constraint:** Because this module relies on toggling a state, back-to-back pulses in the source domain cannot be sent faster than the round-trip synchronization latency without a proper feedback handshake (e.g., a full request-acknowledgement handshake circuit). 
* **Minimum Pulse Width:** The input `pulse_in` must remain high for at least **one full cycle of `clk_src`** to ensure the toggle register reliably captures the event.
* **CDC Verification:** Ensure formal CDC tools (such as SpyGlass or Questa CDC) recognize the synchronizer chain and verify that proper constraints (such as asynchronous clock groups or false paths) are applied between `clk_src` and `clk_dst`.

---

## 6. Timing Waveform Example

```text
clk_src       _¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_
pulse_in      ___¯|______________________________
toggle_src    ________¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯_
clk_dst       _¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_
sync_chain[1] ___________¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯_
pulse_out     ___________¯|______________________