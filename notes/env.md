# Probe A: Version

```bash
****** Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2023.2.2 (64-bit)
  **** SW Build 4101106 on Feb  9 2024
  **** IP Build 4126054 on Fri Feb  9 11:39:09 MST 2024
  **** SharedData Build 4115275 on Tue Jan 30 00:40:57 MST 2024
    ** Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
    ** Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
```

# Probe B: Part

Note that the `xcku5p-ffvb676-2-e` exists in the system.

```bash
INFO: [HLS 200-1510] Running: set_part xcku5p-ffvb676-2-e 
INFO: [HLS 200-1611] Setting target device to 'xcku5p-ffvb676-2-e'
INFO: [HLS 200-1510] Running: create_clock -period 3.33 -name default 
INFO: [SYN 201-201] Setting up clock 'default' with a period of 3.33ns.
INFO: [HLS 200-1510] Running: config_compile -pipeline_loops 0 
INFO: [HLS 200-1510] Running: csim_design 
```

# Probe C: Clock Uncertainty

You get this from `*_csynth.rpt`. So we have enough uncertainty.
Note that this example was taken from `tiny_csynth.rpt`

```bash
+ Timing: 
    * Summary: 
    +--------+---------+----------+------------+
    |  Clock |  Target | Estimated| Uncertainty|
    +--------+---------+----------+------------+
    |ap_clk  |  3.33 ns|  1.016 ns|     0.90 ns|
    +--------+---------+----------+------------+
```

# Probe D: 

Check the `run_hls_probe.tcl` inside the `hls-exercises/s0_flow/01_project_anatomy` and you will see the comparison with and without the `config_compile -pipeline_loops 0`.

# You can probe or see the RTL schematic in vivado

Try:

```tcl
# schem.tcl
# vivado -mode batch -source schem.tcl -tclargs fir_proj/pipe fir3
set sol [lindex $argv 0]
set top [lindex $argv 1]
read_verilog [glob $sol/syn/verilog/*.v]
synth_design -rtl -top $top -part xcku5p-ffvb676-2-e
# Line below only works when available
# write_schematic -format pdf -force $sol/${top}_rtl.pdf
start_gui
```


# Probe E: `__RTL_SIMULATION__` in cosim

Not defined for the testbench on 2023.2.2. In S2.1.1 the testbench guarded `N_RANDOM` with `#ifdef __RTL_SIMULATION__` (1 in cosim, 16 in csim). Cosim still printed `N_RANDOM=16` and ran 20 transactions (`// RTL Simulation : 0 / 20`), and the preprocessed copy in `<proj>/<sol>/sim/wrapc/*_pre.cpp.tb.cpp` holds `N_RANDOM = 16`. Use one constant sized for cosim instead of the `#ifdef`. Confirmed again in S2.1.3: every cosim ran 68 transactions (4 directed + 64 random) although the `#ifdef` asked for 4 random vectors.
