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
- A balanced sum of four values is bound to one two-input adder plus one three-input adder (`TAddSub`), and the whole tree fits in a single state at 3.33 ns.
  The extra state that follows it is the RAM write of the result, not a second level of addition.
- `ARRAY_RESHAPE` logs the same message ID as `ARRAY_PARTITION`, `HLS 214-248`, with the verb changed: `Applying array_reshape to 'x': Cyclic reshaping with factor 4 on dimension 1.`
- A completely reshaped top-level array argument becomes one wide `ap_none` input port, C type `pointer`, not a memory of depth 1.
  Lesson 2.2 `complete` gives a single 512-bit port for 16 elements of 32 bits.
- Selecting a slice of a reshaped array with a run-time index is not emitted as a multiplexer.
  Vitis writes `word >> (32 * index)`, a variable shifter as wide as the whole word, and both prices and schedules it as a general shifter even though the shift amount is always a multiple of the element width and only the low element is used.
  Measured in lesson 2.2: 1.510 ns and 423 LUT for a 128-bit word, 1.880 ns and 2171 LUT for a 512-bit word, against 0.525 ns and 20 LUT for the `sparsemux` that `ARRAY_PARTITION` generates for the same selection in lesson 2.1.
  No `sparsemux` module is generated for a reshaped array.
- Both of those shifter figures are wrong, and they fail differently, which is the lesson of 2.2:
  - The **area** figure is discarded downstream. Vivado sees the constant low bits of the shift amount and the unused high bits of the result and builds the multiplexer: lesson 2.2 `complete` is 8878 LUT estimated and 227 LUT implemented, against 234 estimated and 386 implemented for the partitioned equivalent. The estimate does not just exaggerate, it ranks the two designs the wrong way round.
  - The **delay** figure is spent before anyone can check it. The scheduler used 1.880 ns to give the loop body a third state, so `complete` is 13 cycles where the partitioned design is 9, and the implemented critical path is 0.621 ns with the shifter nowhere in the ten worst paths. Re-synthesising the same directive at a 5 ns clock gives 9 cycles and leaves the LUT estimate at ~8870, which isolates the cause.
  Take latency from C synthesis and area from `export_design -flow syn`; never rank directives on the C synthesis LUT column when the difference is an operator the estimator models pessimistically.
- Flip-flop estimates, unlike LUT estimates, track implementation closely on these designs — within one or two in every solution of lessons 2.1 and 2.2 — because registers follow from the schedule.
- An `array_partition` whose bank index is a run-time value but whose address inside the bank is a compile-time constant lets Vitis read every bank at every address before the loop and keep the whole array in registers, which removes the reads from the loop body altogether.
  Lesson 2.1 `block4` does this: sixteen loads hoisted, 512 flip-flops, and a lower function latency than the `cyclic` solution that the access pattern was supposed to favour.
  The latency table alone does not show it; the register table of the utilization report does.

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