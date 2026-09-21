# hls-directives

One markdown tutorial per Vitis HLS directive.
Each lesson teaches exactly one directive with a very simple kernel, compares a `base` solution against variants that differ in that directive alone, and explains what the directive does to the hardware.

Every lesson has the same nine sections: introduction, how it works, the kernel, the solutions, **predict**, run, read the results, hardware implications, and one common mistake and one question.
The prediction is written down before the tool runs, and section 7 records every place the prediction turned out wrong.
That is deliberate: roughly a third of the lessons here measure a directive doing something other than what its documentation implies.

**For a one-page digest of every directive** — what it does, a figure, and what it gains against what it costs — see [`notes/summary.md`](notes/summary.md).

## Layout

```
hls-directives/
  Makefile                      list / run / check / clean
  common/                       files shared by every lesson
    part.tcl                    part, clock, config_* commands
    collect_latency.sh          latency table, one row per solution
    collect_resources.sh        resource table, one row per solution
  notes/
    env.md                      tool version, conventions, report gotchas
    summary.md                  every directive on one page: idea, figure, gain against cost
  s<N>_<section>/
    <NN>_<directive>/
      README.md                 the lesson
      run_hls.tcl               batch script, all solutions in one project
      directives_<solution>.tcl one file per solution, set_directive_* only
      src/                      synthesizable sources
      tb/                       testbench, added with add_files -tb
```

The folder number `<NN>` is the section digit followed by the lesson digit, so lesson 1.4 lives in `s1_loops/14_loop_merge/`.
Gaps in the numbering (there is no 3.4) are optional lessons that were skipped.

## Environment

Vitis HLS 2023.2.2, part `xcku5p-ffvb676-2-e` at 3.33 ns, Vivado IP flow.
With 0.90 ns of clock uncertainty, a single schedule state may use at most about 2.43 ns; that budget decides several results below.
`common/part.tcl` sets `config_compile -pipeline_loops 0` everywhere, so no loop is pipelined unless a lesson asks for it and `base` is an honest unpipelined reference.
See `notes/env.md` for the full list of conventions and known report quirks.

Where a lesson reports both, **C synthesis** numbers are the tool's estimate and **Vivado** numbers come from logic synthesis. They disagree badly in 2.2, 2.3 and 4.1, and the lessons say which one to believe.

## Running a lesson

```bash
make run   LESSON=s0_setup/01_top
make check LESSON=s0_setup/01_top
make clean LESSON=s0_setup/01_top
```

or, from inside a lesson folder:

```bash
vitis_hls -f run_hls.tcl 2>&1 | tee run.log
```

`make list` prints every lesson folder, and `make clean-all` removes every synthesis output.
Synthesis output directories are named `*_proj` and are not committed.

## Lessons

All twenty-one lessons below are written and measured. The headline is the `base` solution against the variant that makes the point.

### s0 — setup

| Lesson | Directive | Folder | Kernel | Headline result |
| --- | --- | --- | --- | --- |
| 0.1 | TOP | `s0_setup/01_top` | `vadd` | `-name` renames the module and changes nothing else; moving the top down one level is 33 cycles against 66, because less of the program is built |

### s1 — loops

| Lesson | Directive | Folder | Kernel | Headline result |
| --- | --- | --- | --- | --- |
| 1.1 | PIPELINE | `s1_loops/11_pipeline` | `vadd` | II 1 gives 18 cycles against 33, for +11 LUT and no extra FF; II 2 on a depth-2 loop buys nothing |
| 1.2 | LOOP_TRIPCOUNT | `s1_loops/12_loop_tripcount` | `vadd`, run-time `n` | report only: `?` becomes 2–32 cycles, and the normalized Verilog is identical |
| 1.3 | LOOP_FLATTEN | `s1_loops/13_loop_flatten` | `madd`, 8×8 | flattening this unpipelined nest is **slower**: 257 cycles against 209, and +34 LUT |
| 1.4 | LOOP_MERGE | `s1_loops/14_loop_merge` | `two_loops` | the one directive here that is free on both axes: 33 cycles against 66, and 132 LUT against 205 |
| 1.5 | DEPENDENCE | `s1_loops/15_dependence` | `hist` | `-dependent false` reaches II 1 and 87 cycles, and **fails co-simulation**: a bin of 16 comes back as 6 |

### s2 — arrays

| Lesson | Directive | Folder | Kernel | Headline result |
| --- | --- | --- | --- | --- |
| 2.1 | ARRAY_PARTITION | `s2_arrays/21_array_partition` | `sum4` | `cyclic`, factor 4: 13 cycles against 17 **and** 160 LUT against 205; `block` matches the access pattern badly and costs 555 FF |
| 2.2 | ARRAY_RESHAPE | `s2_arrays/22_array_reshape` | `sum4` | same bandwidth through one wide port; a run-time slice becomes a barrel shifter, and `complete` takes 13 cycles where partitioning takes 9 |
| 2.3 | BIND_STORAGE | `s2_arrays/23_bind_storage` | `vadd`, local `a_buf` | `-impl BRAM` frees 34 LUT and 31 FF and costs **16 cycles**, because the scheduler charges a BRAM read 1.237 ns against 0.677; `-latency 2` changes nothing that reaches the chip |

### s3 — parallelism

| Lesson | Directive | Folder | Kernel | Headline result |
| --- | --- | --- | --- | --- |
| 3.1 | UNROLL | `s3_parallelism/31_unroll` | `vadd` | factor 4 on one memory builds two adders, not four, and buys 0.16 cycles per LUT; with matching `cyclic` banks it buys 0.23 and reaches 9 cycles |
| 3.2 | LATENCY | `s3_parallelism/32_latency` | `poly` | a `-min` at or below the natural latency is a no-op; `-max 1` **meets the latency and breaks the clock**, 171 MHz on a 300 MHz target, and still exits 0 |
| 3.3 | PERFORMANCE | `s3_parallelism/33_performance` | `acc`, float | a reachable target of 160 is **refused with one INFO line**; a target of 224 is met in 147 by silently re-binding the float adder |
| 3.5 | EXPRESSION_BALANCE | `s3_parallelism/35_expression_balance` | `sum32`, `fsum8` | on integers the tree is the default: 1 cycle against 5, for 354 FF against 166. It does not reach `float` at all |

### s4 — resources

| Lesson | Directive | Folder | Kernel | Headline result |
| --- | --- | --- | --- | --- |
| 4.1 | BIND_OP | `s4_resources/41_bind_op` | `poly` | `-impl fabric` alone silently picks the **combinational** core: 0 DSP, 3243 LUT, and a clock missed by 1.05 ns |
| 4.2 | ALLOCATION | `s4_resources/42_allocation` | `poly` | `-limit 1` on `mul`: 3 DSP against 9, 234 FF against 596, 178 LUT against 242, same 4 cycles and same clock |
| 4.3 | INLINE | `s4_resources/43_inline` | `calls` | `default` is byte-identical to `on`; `-off` is what costs, at 49 cycles against 33 and +33 FF |

### s5 — interfaces

| Lesson | Directive | Folder | Kernel | Headline result |
| --- | --- | --- | --- | --- |
| 5.1 | INTERFACE | `s5_interfaces/51_interface` | `vadd` | `ap_fifo` keeps 33 cycles and costs +29 LUT, +59 FF; `m_axi` turns 33 cycles into 214 estimated and 298 measured |
| 5.2 | AGGREGATE / DISAGGREGATE | `s5_interfaces/52_aggregate` | `rgb`, RGB565 | the logic is identical in all four solutions, 33 cycles and 54 LUT; only the port shape moves, 16 bits against 24 against six memories |
| 5.3 | RESET | `s5_interfaces/53_reset` | `counter` | resetting a scalar is free to the cell; resetting an 8-word array costs +13 FF, +20 LUT and **zero cycles**, via a ROM and a written-bit vector |

### s6 — dataflow

| Lesson | Directive | Folder | Kernel | Headline result |
| --- | --- | --- | --- | --- |
| 6.1 | DATAFLOW | `s6_dataflow/61_dataflow` | `pipe2` | the tool converts the channel to a FIFO on its own: 51 cycles against 66, interval 50 against 67, for +14 LUT and +39 FF |
| 6.2 | STREAM | `s6_dataflow/62_stream` | `pipe2` | `-type pipo` costs 115 cycles against 83 and leaves the interval at 82; `-depth 2` keeps both and moves the channel off SRLs onto 170 FFs |
