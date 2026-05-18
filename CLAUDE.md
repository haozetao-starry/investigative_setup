# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

FPGA-based unknown filter identification and emulation system (Cyclone IV E, EP4CE15F17C8). Sweeps 20Hz–20kHz sine through a DUT via DAC, captures response via ADC, runs FFT to get frequency response, estimates biquad IIR coefficients via RLS, classifies filter type (LP/HP/BP/Notch/Allpass), displays result on I2C OLED, then emulates the identified filter in real-time.

**Sweep parameters:** 20Hz–20kHz, 200Hz step (~100 points, 3 decades). STOP_WORD = 1,717,987. Suitable for RLC filter identification with fc ∈ [300Hz, 8kHz].

**Two project directories co-exist:**

| Directory | Purpose |
|---|---|
| `C:\Users\Lenovo\Desktop\investigative_setup` | **Full system** — all 14 Verilog modules + Altera FFT/RAM IP cores. Synthesizable. |
| `C:\Users\Lenovo\Desktop\investigative_test` | **Simulation subset** — DDS, ADC, classifier only. No FFT IP. For ModelSim verification. |

The current worktree is inside `investigative_setup\.claude\worktrees\`.

## Build (Quartus synthesis)

```powershell
# Open project in Quartus Prime 18.0 Standard Edition
quartus_map investigative_setup
quartus_fit investigative_setup
quartus_asm investigative_setup
```

Top-level entity: `investigative_setup` in `src/top/investigative_setup.v`. The `.qsf` file lists all source files and IP `.qip` references.

## Simulation (ModelSim)

All sim files live in `C:\Users\Lenovo\Desktop\investigative_test\src\sim\`. Each sim has a `*_tb.v` testbench and a `sim_*.do` script. Run from that directory:

```powershell
cd C:\Users\Lenovo\Desktop\investigative_test\src\sim

# DDS sweep test
& /d/intelFPGA/18.0/modelsim_ase/win32aloem/vsim -do sim_dds_sweep.do

# ADC adaptive sampling test
& /d/intelFPGA/18.0/modelsim_ase/win32aloem/vsim -do sim_ad_wave_rec.do

# Filter classifier test (6 filter types)
& /d/intelFPGA/18.0/modelsim_ase/win32aloem/vsim -do sim_filter_classifier.do
```

Simulation support models in `src/sim/`:
- `sin_sim.v` — behavioral replacement for Altera sin ROM IP
- `ADC_RAM_sim.v` — behavioral replacement for Altera ADC_RAM IP

## Module architecture (identification pipeline)

The system is orchestrated by `acq_ctrl` (6-state FSM in `src/adc_acq/acq_ctrl.v`):

```
IDLE → PULSE_ACQ → WAIT_BUF → WAIT_FFT → WAIT_RLS → [WAIT_CLASSIFY | IDLE]
```

**Signal generation:** `dds_sweep_ctrl` → `dds_top` (phase acc → sin ROM → amp scale) → `da_wave_send`

**Acquisition:** `ad_wave_rec` captures 1024 samples of both ref (dds_wave) and response (ADC data) into dual-port RAMs. Uses 2-stage synchronizers for external ADC and adaptive sampling divider (smp_div: 0/9/99/999 based on frequency).

**FFT:** `fft_processor` time-multiplexes the Altera FFT MegaCore (1024-pt streaming): Frame 0 finds peak bin in reference, Frame 1 reads same bin in response. Computes H_mag (Q16) and H_phase (Q8°) with linear-approximation atan2.

**RLS:** `rls_estimator` — currently simplified to mean-gain estimation (b0 = avg H_mag, b1=b2=a1=a2=0). Architecture supports expansion to full 5-parameter RLS with covariance matrix P and Kalman gain.

**Classification:** `filter_classifier` scans `sweep_result_store` (128-entry register array, zero-latency combinational read) and applies heuristic rules: ALLPASS (flat) → BANDPASS (center peak) → NOTCH (center trough) → LOWPASS → HIGHPASS → UNKNOWN.

**Emulation:** `biquad_emulator` — Direct Form I IIR, Q16 fixed-point, 64-bit accumulator.

**OLED Display:** I2C SSD1306 128x64 OLED via `src/display/` modules:
- `i2c_master.v` — 400kHz I2C controller, byte-stream interface
- `ssd1306_cmd.v` — init sequence + framebuffer refresh over I2C
- `font_8x16.v` — 8×16 bitmap font ROM (ASCII, ~40 glyphs)
- `oled_display.v` — renders filter_type name to framebuffer on model_valid
- `fb_ram.v` — 1024×8-bit dual-port framebuffer BRAM

OLED shows filter type text when `model_valid` asserts after identification completes.

## Key conventions

- **Timescale:** `1ns/1ps` in all testbenches
- **Clock:** 50MHz (CLK_HALF_NS=10)
- **VCD dump:** all testbenches dump `$dumpvars(0, tb_module)`
- **CSV logging:** one row per clock cycle, `$fdisplay` to `*_wave.csv`
- **Timeout pattern:** `fork/wait/join_any disable fork` with MAX_SIM_CYCLES
- **DO files:** compile dependencies leaf-first, `vsim -voptargs=+acc`, wave groups with `-divider`, `run -all`

## When adding new RTL for simulation to investigative_test

1. Copy the Verilog source from `investigative_setup` worktree `src/` into `investigative_test/src/` under the matching subdirectory.
2. Check for Altera IP dependencies — if the module instantiates `altsyncram`, `altera_fft`, etc., a behavioral simulation model is needed (see `sin_sim.v`, `ADC_RAM_sim.v` pattern).
3. Create `*_tb.v` and `sim_*.do` in `src/sim/` following the existing pattern.
4. The FFT MegaCore (`FFT` module) is encrypted and requires Altera simulation libraries — do not attempt standalone simulation without compiling the Quartus device libraries into ModelSim first.
