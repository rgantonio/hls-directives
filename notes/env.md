# Environment and tool notes

These notes hold everything that is true for every lesson in this repository, so that no lesson has to repeat it.

## Tool and target

| item | value |
| --- | --- |
| Tool | Vitis HLS v2023.2.2 |
| Part | `xcku5p-ffvb676-2-e` (Kintex UltraScale+) |
| Clock period | 3.33 ns, which is 300 MHz |
| Clock uncertainty | the default 0.90 ns, which is 27 percent of the period |
| Effective scheduling target | about 2.43 ns, because the scheduler subtracts the uncertainty |
| Flow target | `vivado`, which is the Vivado IP flow rather than the Vitis kernel flow |

The clock uncertainty is the margin the scheduler keeps for effects that high level synthesis cannot see yet, such as routing delay.
It means the scheduler refuses to put more than roughly 2.43 ns of logic between two registers, even though the clock period is 3.33 ns.

## How every lesson is run

Everything runs from a Tcl batch script, never from the graphical interface:

```bash
vitis_hls -f run_hls.tcl 2>&1 | tee run.log
```

Conventions that hold everywhere:

- `open_project -reset` and `open_solution -reset`, so that a run never inherits state from a previous run.
- Every `set_directive_*` command lives in `directives_<solution>.tcl`.
- Every `config_*` command lives in `common/part.tcl`.
- `config_compile -pipeline_loops 0` is set in `common/part.tcl`.
  On this install Vitis starts pipelining loops on its own below about 63 trips, which is one less than the documented threshold of 64, and that would quietly optimize most baselines.
- Every loop carries a label, because the loop tables in the reports are indexed by label.
- Several solutions share one project, so that reports sit side by side.

## Testbench shape

Every testbench uses a reference model that shares no code with the kernel, writes a poison value into the outputs before calling the kernel, runs directed vectors first and fixed-seed random vectors afterwards, counts errors and returns a non-zero exit code on any failure.
C simulation and co-simulation both treat a non-zero return value as a failure.

## Report gotchas collected so far

- In the loop table of a pipelined loop, the Iteration Latency column reads one cycle higher than the real value.
- For a pipelined loop, the Iteration Latency column matched the depth from the `Pipelining result` log line in lesson 1.1, but the loop Latency column read one cycle below $D + II \cdot (N - 1)$ for II of 1, and the missing cycle appeared in the function latency instead. Compare function latencies, and take the depth from the log line.
- The Initiation Interval column of the loop table has two sub-columns, the achieved value and the target value.
  They are not always equal.
- The Bind Op Report, which says which operator went into which hardware resource, only appears in `<solution>/syn/report/csynth.rpt`.
- An array argument on an `ap_memory` interface can receive two ports rather than one when the schedule wants two accesses in the same cycle.
  Pinning the storage type to a single port RAM is what forces one port.
- The macro `__RTL_SIMULATION__` is not defined for the testbench during co-simulation on this install, so it cannot be used to change testbench behavior between C simulation and co-simulation.
- An `m_axi` interface with `-offset slave` creates a second AXI-Lite bundle unless the same arguments also carry `s_axilite -bundle control`.

## Directory layout

```
hls-directives/
  Makefile
  common/            part.tcl, collect_latency.sh, collect_resources.sh
  notes/             env.md
  s0_setup/01_top/   README.md, run_hls.tcl, directives_*.tcl, src/, tb/
  s1_loops/11_pipeline/
  ...
```

## Cosmetic warnings to expect

- `g++` and the C simulation compiler both warn that a loop label is defined but not used, because a C label with no `goto` pointing at it is dead code as far as the host compiler is concerned.
  Vitis HLS reads those labels anyway and uses them to name the rows of the loop tables, so the warning is expected and harmless.