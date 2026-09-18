# hls-directives

One markdown tutorial per Vitis HLS directive.
Each lesson teaches exactly one directive with a very simple kernel, compares a `base` solution against variants that differ in that directive alone, and explains what the directive does to the hardware.

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
  s<N>_<section>/
    <NN>_<directive>/
      README.md                 the lesson
      run_hls.tcl               batch script, all solutions in one project
      directives_<solution>.tcl one file per solution, set_directive_* only
      src/                      synthesizable sources
      tb/                       testbench, added with add_files -tb
```

The folder number `<NN>` is the section digit followed by the lesson digit, so lesson 1.4 lives in `s1_loops/14_loop_merge/`.

## Environment

Vitis HLS 2023.2.2, part `xcku5p-ffvb676-2-e` at 3.33 ns, Vivado IP flow.
See `notes/env.md` for the full list of conventions and known report quirks.

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

Synthesis output directories are named `*_proj` and are not committed.

## Lessons

| Lesson | Directive | Folder | Status |
| --- | --- | --- | --- |
| 0.1 | TOP, and the project harness | `s0_setup/01_top` | done |
| 1.1 | PIPELINE | `s1_loops/11_pipeline` | planned |
| 1.2 | LOOP_TRIPCOUNT | `s1_loops/12_loop_tripcount` | planned |
| 1.3 | LOOP_FLATTEN | `s1_loops/13_loop_flatten` | planned |
| 1.4 | LOOP_MERGE | `s1_loops/14_loop_merge` | planned |
| 1.5 | DEPENDENCE | `s1_loops/15_dependence` | planned |
| 2.1 | ARRAY_PARTITION | `s2_memory/21_array_partition` | planned |
| 2.2 | ARRAY_RESHAPE | `s2_memory/22_array_reshape` | planned |
| 2.3 | BIND_STORAGE | `s2_memory/23_bind_storage` | planned |
| 3.1 | UNROLL | `s3_parallelism/31_unroll` | planned |
| 3.2 | LATENCY | `s3_parallelism/32_latency` | planned |
| 3.5 | EXPRESSION_BALANCE | `s3_parallelism/35_expression_balance` | planned |
| 4.1 | BIND_OP | `s4_operators/41_bind_op` | planned |
| 4.2 | ALLOCATION | `s4_operators/42_allocation` | planned |
| 4.3 | INLINE | `s4_operators/43_inline` | planned |
| 5.1 | INTERFACE | `s5_interfaces/51_interface` | planned |
| 5.2 | AGGREGATE and DISAGGREGATE | `s5_interfaces/52_aggregate` | planned |
| 5.3 | RESET | `s5_interfaces/53_reset` | planned |
| 6.1 | DATAFLOW | `s6_dataflow/61_dataflow` | planned |
| 6.2 | STREAM | `s6_dataflow/62_stream` | planned |