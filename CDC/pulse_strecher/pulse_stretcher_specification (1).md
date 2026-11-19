# Specification: Pulse Stretcher (CDC Module)

## 1. Overview
The `pulse_stretcher` module is a robust clock domain crossing (CDC) component designed to stretch a narrow pulse from a source clock domain (`clk_src`) so that it can be reliably sampled and captured in a destination clock domain (`clk_dst`). 

This module prevents data loss that typically occurs when a destination clock is slower than the source pulse width, or when asynchronous pulses are too narrow to meet setup/hold times of standard synchronizers.

---

## 2. Features
* **Asynchronous Pulse Support:** Safely stretches single-cycle pulses across clock domains.
* **Configurable Stretch Count:** Parameterizable number of destination clock cycles for the stretched output.
* **Glitch-Free Output:** Ensures clean, synchronized transitions without metastable states propagating to the logic.
* **Fully Synchronous Design:** Built with standard multi-stage flip-flop synchronizers.

---

## 3. Interface Signals

| Signal Name | Direction | Clock Domain | Description |
| :--- | :--- | :--- | :--- |
| `clk_src` | Input | Source | Source clock domain |
| `rst_src_n` | Input | Source | Asynchronous active-low reset for source logic |
| `pulse_in` | Input | Source | Input pulse to be stretched (active high, 1 cycle wide) |
| `clk_dst` | Input | Destination | Destination clock domain |
| `rst_dst_n` | Input | Destination | Asynchronous active-low reset for destination logic |
| `pulse_out` | Output | Destination | Stretched pulse output in destination domain |

---

## 4. Parameters

| Parameter Name | Default | Description |
| :--- | :--- | :--- |
| `STRETCH_CYCLES` | `3` | Number of destination clock cycles the output remains high. |

---

## 5. Functional Description

1. **Pulse Toggle / Handshake (Source Domain):** 
   * The incoming `pulse_in` toggles a register in the `clk_src` domain to ensure the transition is captured regardless of pulse width.
2. **Clock Domain Crossing (Synchronizer):**
   * The toggled signal passes through a multi-stage synchronizer (typically 2 or 3 flip-flops) clocked by `clk_dst` to eliminate metastability.
3. **Edge Detection & Counter (Destination Domain):**
   * An edge detector identifies transitions in the synchronized signal.
   * Upon detecting a transition, a down-counter starts and holds `pulse_out` high for `STRETCH_CYCLES` duration in the `clk_dst` domain.

---

## 6. Sizing and Safety Rules for `STRETCH_CYCLES`

To guarantee that the destination clock domain's sequential logic reliably samples the pulse without missing it, the stretched pulse width must satisfy safety constraints:

$$\text{Destination Clock Period} < \text{Stretched Pulse Width}$$

$$\text{Stretched Pulse Width} \ge 1.5 \times T_{\text{dest}} + \text{Synchronizer Delay}$$

* **Shannon-Nyquist / Sampling Rule:** If the destination clock is slower than or asynchronous to the source clock, a narrow pulse could land right on the edge of a destination clock cycle and be missed. Stretching ensures it bridges at least one full $clk_{dst}$ rising edge.
* **Synchronizer Delay:** Multi-stage synchronizer chains (e.g., 2FF or 3FF) take multiple $clk_{dst}$ cycles just to pass the signal cleanly. 
* **Baseline Recommendation:** Setting `STRETCH_CYCLES = 3` is the industry-standard baseline for general-purpose asynchronous pulses to ensure safe synchronization and a robust capture window for downstream logic.

---

## 7. Timing & Waveform Expectations

```text
clk_src     _¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_
pulse_in    ___¯|______________________________
clk_dst     _¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_¯_
pulse_out   _______¯¯¯¯¯¯¯¯|___________________
                    <----> STRETCH_CYCLES
```

---

## 8. Verification & CDC Guidelines
* **Linting / CDC Checks:** Ensure formal CDC tools (like SpyGlass or Questa CDC) recognize the synchronizer chain and flag no asynchronous convergence or un-synchronized paths.
* **Constraints:** Define false paths or asynchronous clock group constraints between `clk_src` and `clk_dst` in the Synopsys Design Constraints (SDC).