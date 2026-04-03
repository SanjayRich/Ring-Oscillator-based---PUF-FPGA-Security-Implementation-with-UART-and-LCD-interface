# Ring-Oscillator-based---PUF-FPGA-Security-Implementation-with-UART-and-LCD-interface

> **Your `.bit` file got stolen. Your design is cloned. Your IP is on AliExpress.**
> 
> *What if the chip itself could refuse to boot on the wrong board?*

That's exactly what a **Physical Unclonable Function (PUF)** does — and this project implements one, in silicon, on a real FPGA.

---

##  The Idea: Silicon Has a Fingerprint

When a semiconductor fab manufactures chips, no two come out identical. Tiny, nanometer-scale variations in gate delays, oxide thickness, and transistor geometry are **unavoidable** — and completely **uncontrollable**.

These imperfections are usually a headache. Here, they're the secret key.

A **Ring Oscillator PUF** exploits this: two physically identical inverter loops will oscillate at *slightly different frequencies* on every chip, because of those manufacturing differences. Compare the two speeds → you get a bit. Run 16 such comparisons → you get a **16-bit identity string unique to that exact piece of silicon**.

No memory. No stored secret. No NVM. The key *is* the chip.

Clone the bitstream? The PUF ID won't match. Flash it on a counterfeit board? Authentication fails. The silicon fingerprint can't be copied.

---

##  Architecture

<img width="1408" height="647" alt="Gemini_Generated_Image_lakxkylakxkylakx" src="https://github.com/user-attachments/assets/04792bac-9246-460c-85de-d1545ca9fc1a" />



##  Project Structure

```
Ring-Oscillator-based---PUF/
├── RTL/
│   ├── ring_osc.v          # 5-stage inverter ring (single oscillator)
│   ├── ro_puf_bit.v         # One PUF bit: RO-A vs RO-B frequency race
│   ├── puf_16bit.v          # 16 parallel PUF bits → full ID
│   ├── auth_top.v           # Top-level: XOR auth, LEDs, 7-seg, LCD
│   ├── hex_decoder.v        # 4-bit → 7-segment display driver
│   └── lcd_controller.v     # 16×2 LCD state machine
├── CHIP PLANNER/
│   └── ro_placement.tcl     # Quartus TCL: manually pins all 16 RO pairs
└── output files/
    ├── fpga output1.jpeg    # Init: generating key
    ├── fpga output2.jpeg    # Auth success
    ├── fpga output3.jpeg    # Auth failure
    └── fpga output4.jpeg    # PUF disabled / bypass mode
```

---

##  Module Breakdown

### `ring_osc.v` — The Oscillator
A 5-inverter feedback loop. When `enable` is high, it oscillates. The `(* keep *)` pragma stops Quartus from collapsing the inverter chain during synthesis — without it, the optimizer removes the "redundant" logic and the PUF stops working.

### `ro_puf_bit.v` — One PUF Bit
Instantiates two ring oscillators (RO_A and RO_B) and counts their output pulses over a **65,535-clock window**. After the window:
```
puf_bit = (count_A > count_B) ? 1 : 0
```
Because manufacturing variation makes RO_A and RO_B run at slightly different speeds on every chip, this bit is deterministic per-device but unpredictable across devices.

### `puf_16bit.v` — 16-Bit PUF Array
Spawns 16 `ro_puf_bit` instances in parallel using `generate`/`genvar`. When **all 16** report `valid`, the 16-bit `puf_id` is latched and `puf_valid` is asserted.

### `auth_top.v` — Authentication Engine
The top-level integrator. Core logic:
```verilog
assign xor_result = puf_id ^ GOLDEN_HASH;   // 16'h5982 after enrollment
wire auth_ok   = puf_valid & (xor_result == 16'h0000);
wire auth_fail = puf_valid & (xor_result != 16'h0000);
```
- **Green LED** (`LEDG0`) → authenticated
- **Red LED** (`LEDR0`) → wrong chip
- **HEX0–HEX3** → live PUF ID (hex)
- **HEX4–HEX7** → XOR result (should be `0000` on enrolled board)
- `SW[0]` disables PUF mode (for testing / second board)

### `hex_decoder.v` — 7-Segment Driver
Combinational 4-bit to 7-segment lookup table. Instantiated eight times to drive all HEX displays.

### `lcd_controller.v` — LCD State Machine
Drives a **16×2 character LCD** over parallel interface. Displays one of four messages based on system state:

| State | Line 1 | Line 2 |
|---|---|---|
| Initialising | `  PUF SECURITY  ` | ` GENERATING KEY ` |
| Auth OK | `** AUTHENTICATED` | `  FPGA 1 OK     ` |
| Auth FAIL | `!! AUTH FAILED!` | ` WRONG FPGA CHIP` |
| PUF Disabled | ` PUF DISABLED   ` | `WELCOME: FPGA-2 ` |

### `ro_placement.tcl` — Chip Planner Script
The **most critical** file for reliable PUF behaviour. Manually constrains every inverter in all 16 RO pairs to specific Logic Element (LE) slots on the EP4CE115 fabric:

- RO_A → N0 to N4 of a given LAB
- RO_B → N5 to N9 of the **same LAB**

Placing both oscillators in the same LAB ensures symmetric routing. If they're placed far apart, routing delay dominates over manufacturing variation and the PUF becomes unstable or biased.

---

##  Getting Started

### Prerequisites
- Intel/Altera **DE2-115** development board (EP4CE115F29C7)
- **Quartus Prime** (Lite or Standard) — tested on 18.1
- USB-Blaster or equivalent JTAG programmer

### Step 1 — Clone & Open
```bash
git clone https://github.com/<your-username>/Ring-Oscillator-PUF.git
cd Ring-Oscillator-PUF
```
Open `output files/puf_auth.qpf` in Quartus Prime.

### Step 2 — Run Placement Script
Before compiling, apply the manual RO placement constraints:
```
Tools → Tcl Scripts → ro_placement.tcl → Run
```
This locks all 16 RO pairs to their designated LE locations.

### Step 3 — Compile
```
Processing → Start Compilation
```

### Step 4 — Program the Board
```
Tools → Programmer → Add File → puf_auth.sof → Start
```

### Step 5 — Enroll the Device
On first boot, read the PUF ID from **HEX0–HEX3**. Update `auth_top.v`:
```verilog
parameter [15:0] GOLDEN_HASH = 16'hXXXX;  // ← your chip's PUF ID
```
Recompile and reprogram. This board is now the **enrolled device**.

---

##  FPGA Output

| | |
|---|---|
| ![Init](output%20files/fpga%20output1.jpeg) | **Output 1 — Initialising:** LCD shows `PUF SECURITY / GENERATING KEY`. The system is still sampling ring oscillators and counting cycles. `puf_valid` is not yet asserted. |
| ![Auth OK](output%20files/fpga%20output2.jpeg) | **Output 2 — Authenticated:** LCD shows `** AUTHENTICATED / FPGA 1 OK`. Green LED on. HEX4–7 display `0000` — XOR result is zero, identity confirmed. This is the enrolled board. |
| ![Auth Fail](output%20files/fpga%20output3.jpeg) | **Output 3 — Auth Failed:** LCD shows `!! AUTH FAILED / WRONG FPGA CHIP`. Red LED on. HEX4–7 show a non-zero value — the PUF ID doesn't match the golden hash. Cloned bitstream, different chip. |
| ![Disabled](output%20files/fpga%20output4.jpeg) | **Output 4 — PUF Disabled:** `SW[0]` is toggled. LCD shows `PUF DISABLED / WELCOME: FPGA-2`. Used for testing the second board without authentication enforced. |

---

##  How PUF Bits Are Generated

```
enable ──► [Inverter 1] ──► [Inverter 2] ──► [Inverter 3] ──► [Inverter 4] ──► [Inverter 5] ──┐
                                                                                                  │
           ◄────────────────────────────── feedback ──────────────────────────────────────────────┘

Two of these loops (RO_A and RO_B) race for 65,535 clock cycles.
Counters track how many times each loop toggles.
Winner determines the bit: faster = 1, slower = 0.
```

The frequency difference is typically **< 0.1%** — invisible to copy, measurable by silicon.

---

##  Known Limitations

- **Temperature & Voltage Sensitivity:** PUF responses can drift under extreme temperature or voltage variation. Production systems use error-correcting codes (BCH, Reed-Solomon) with a helper data scheme to stabilise the response.
- **Single Challenge:** This implementation generates one fixed 16-bit response. A full PUF system supports a **Challenge-Response Pair (CRP)** space for richer authentication protocols.
- **No Fuzzy Extractor:** Raw PUF bits are used directly. A production implementation would apply a fuzzy extractor to handle bit flips across power cycles.
- **Bitstream Security:** The GOLDEN_HASH is stored in the bitstream. Full IP protection requires combining PUF authentication with bitstream encryption (Quartus supports AES-128 for this).

---

## Tools Used

| Tool | Purpose |
|---|---|
| Quartus Prime 18.1 | Synthesis, P&R, programming |
| Chip Planner | Manual LE placement for RO pairs |
| ModelSim | Functional simulation |
| DE2-115 (EP4CE115) | Target hardware |
| Verilog (RTL) | Hardware description |
| Tcl | Placement automation |

---

##  References

- Suh, G. E., & Devadas, S. (2007). *Physical Unclonable Functions for Device Authentication and Secret Key Generation.* DAC 2007.
- Maiti, A., & Schaumont, P. (2011). *Improving the Quality of a Physical Unclonable Function Using Configurable Ring Oscillators.* FPL 2009.
- Intel/Altera EP4CE115 Device Handbook

---

##  License

MIT License — see `LICENSE` for details.

---

*Built with silicon, inverters, and a healthy distrust of software-only security.*
