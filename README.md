# LUT-based NCO

A numerically controlled oscillator (NCO) in VHDL-2008. An N-bit phase accumulator adds
`step_size` on every `clk_en`. The top M bits of the phase address a sine lookup table
(2^M entries, L-bit two's complement), which is stored in block RAM.

Output frequency: `f_out = step_size * f_clk / 2^N`

| File | Contents |
|---|---|
| `src/nco.vhd` | The NCO |
| `src/sine_lut_pkg.vhd` | Function that builds the sine table |
| `src/nco_pkg.vhd` | `C_NCO_LATENCY`, step-size and configuration-check functions for NCO users |
| `tb/nco_tb.vhd` | Self-checking UVVM testbench with a scoreboard |
| `tb/sine_lut_pkg_tb.vhd` | Testbench for the sine table |

Run all testbenches with `make sim-all`.
