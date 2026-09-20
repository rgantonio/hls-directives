# 1.5 DEPENDENCE

## 1. Introduction

The `DEPENDENCE` directive gives the scheduler information about dependences that it cannot work out from the code on its own.
A **dependence** exists when one operation must wait for another because they use the same storage, for example when a read must see the value that an earlier write produced.
A **loop-carried dependence**, which UG1399 calls an inter-iteration dependence, is a dependence between operations of different iterations of the same loop.

Loop-carried dependences matter once a loop is pipelined.
**Pipelining** starts a new iteration before the previous one has finished, and the **initiation interval (II)** is the number of clock cycles between the starts of two consecutive iterations.
If iteration `i+1` might read a memory element that iteration `i` writes, the tool must guarantee that the read sees the right value, and the way it does that is to spread the iterations further apart, which raises the II.

When the addresses of the accesses are known only at run time, the tool cannot prove that two iterations touch different elements, so it assumes that they might.
The histogram in this lesson is such a case: iteration `i` updates `acc[x[i]]`, and nothing in the code says whether `x[i+1]` equals `x[i]`.
The directive lets the designer overrule that assumption.
With `-dependent false`, the designer declares that the dependence does not exist, and with `-dependent true` and `-distance`, the designer states how many iterations apart a real dependence is.
The option `-type inter` restricts the statement to dependences between iterations, and `-type intra` restricts it to dependences inside one iteration.
The option `-direction` names the kind of dependence: `RAW` is a read after a write, `WAR` is a write after a read, and `WAW` is a write after a write.

**What improves:** the II of the pipelined loop, and with it the throughput and the latency of the loop.
In this lesson the II of `HIST_LOOP` drops from 2 to 1, the loop module goes from 35 cycles to 20, and the function goes from 102 cycles to 87.

**What it costs:** correctness, if the promise is wrong.
UG1399 warns that declaring a dependence false when it is in fact true can produce incorrect hardware, and Vitis HLS does not check the claim.
This lesson does not leave that as a warning.
The `false_dep` solution is built, simulated against inputs that trigger the dependence, and **fails**: a histogram of sixteen identical samples comes back as 6 instead of 16.
A third solution, `dist2`, shows that the other form of the directive is no safer: it declares a real dependence at the wrong distance, gains no II at all, and still returns 8 instead of 16.

**When to use it:** use it when the log reports a carried dependence that you know cannot occur, for example when two iterations provably access different elements because of how the data is produced.
Use `-dependent true` with `-distance` when the dependence is real but further apart than the tool assumes, and be sure the distance you give is a number of iterations that you have reasoned about, not a number copied out of a message.
The directive has an effect only on a pipelined loop, which is why `PIPELINE` is applied to all three solutions.

The directive does change the hardware, but only indirectly, through the schedule it allows.

Reference: UG1399, [pragma HLS dependence](https://docs.amd.com/r/2023.2-English/ug1399-vitis-hls/pragma-HLS-dependence) and [set_directive_dependence](https://docs.amd.com/r/2023.2-English/ug1399-vitis-hls/set_directive_dependence).

## 2. How it works

A pipelined iteration of `HIST_LOOP` occupies four stages.
Section 7 measures `Depth = 4`, and the stages are:

| Stage | What happens                                                   |
| ----- | -------------------------------------------------------------- |
| 0     | the address `i` goes to the memory `x`                          |
| 1     | `x[i]` arrives; the bin `b` goes to the memory `acc`            |
| 2     | `acc[b]` arrives; the adder computes `acc[b] + 1`               |
| 3     | the new count is written back to `acc[b]`                       |

So an iteration reads `acc` at $t_R = 1$ and writes it at $t_W = 3$, and the **gap** between them is

$$g = t_W - t_R = 2\ \textrm{cycles}.$$

The gap is what the whole lesson turns on.
When iteration `i` reads `acc`, the writes of the iterations that started within the last $g$ cycles have not happened yet, and there are

$$\left\lceil \frac{g}{\textrm{II}} \right\rceil = \left\lceil \frac{2}{\textrm{II}} \right\rceil$$

of them.
At II 2 that is one iteration, and at II 1 it is two.

Vitis HLS answers this with a bypass, and section 7 finds it in the generated Verilog of `base`: a register pair that keeps the bin and the count of the *previous* iteration, a comparator, and a multiplexer that feeds the adder the kept count instead of the stale memory word when the bins match.
One such register pair covers exactly one in-flight iteration.
That accounts for the II that `base` settles on here: at II 2 there is one uncovered iteration and the bypass serves it, while at II 1 there would be two and one register pair cannot serve both.
Take this as the accounting for *this* configuration rather than a general law; section 9 shows a case where the tool evidently builds a deeper bypass.

The tables below use a trip count of 3.
Rows are iterations, columns are clock cycles.
`X` marks the read of `x[i]`, `R` the cycle that sends the bin to `acc`, `+` the cycle that adds, and `W` the write back.
A `!` marks a read whose value is already stale when it is taken.

**`base`, II = 2, the dependence honoured:**

| Iteration | 0  | 1  | 2  | 3  | 4  | 5  | 6  | 7  |
| --------- | -- | -- | -- | -- | -- | -- | -- | -- |
| i=0       | X  | R  | +  | W  |    |    |    |    |
| i=1       |    |    | X  | R  | +  | W  |    |    |
| i=2       |    |    |    |    | X  | R  | +  | W  |

Iteration 1 reads `acc` in cycle 3, the same cycle in which iteration 0 writes it.
One iteration is in flight, and the bypass register holds exactly what iteration 1 needs, so the result is right.

**`false_dep`, II = 1, the dependence denied:**

| Iteration | 0  | 1  | 2  | 3  | 4  | 5  | 6  | 7  |
| --------- | -- | -- | -- | -- | -- | -- | -- | -- |
| i=0       | X  | R  | +  | W  |    |    |    |    |
| i=1       |    | X  | R! | +  | W  |    |    |    |
| i=2       |    |    | X  | R! | +  | W  |    |    |

Iteration 2 reads `acc` in cycle 3, before the writes of iterations 0 and 1 have both landed, and the bypass register is gone because the directive said it was unnecessary.
If those iterations name the same bin, their increments are lost.

**`dist2`, II = 2, the dependence misdescribed:**

The schedule is the same as `base`, because declaring the dependence at a distance of two iterations means the read of iteration `i+2` must follow the write of iteration `i`, which gives $t_R + 2\,\textrm{II} > t_W$ and therefore II $\ge$ 2 again.
What changes is that the directive has told the tool that iterations *one* apart are independent, so the bypass register is not built.
Iteration 1 still reads in the same cycle as the write of iteration 0, and now gets the stale value.
`dist2` pays the full II 2 and is wrong anyway.

## 3. The kernel

`src/hist.h`:

```cpp
const int N    = 16;    // number of samples, trip count of HIST_LOOP
const int BINS = 16;    // number of histogram bins

typedef ap_uint<4> bin_t;   // 4 bits hold 0 to 15, so every sample names a legal bin
typedef int        cnt_t;   // one count per bin
```

`src/hist.cpp`:

```cpp
void hist(const bin_t x[N], cnt_t h[BINS]) {
    cnt_t acc[BINS];

IN_LOOP:
    for (int b = 0; b < BINS; b++) {
        acc[b] = h[b];
    }

HIST_LOOP:
    for (int i = 0; i < N; i++) {
        bin_t b = x[i];
        acc[b] = acc[b] + 1;
    }

OUT_LOOP:
    for (int b = 0; b < BINS; b++) {
        h[b] = acc[b];
    }
}
```

The array `h` is both an input and an output: the caller passes in the current counts, and the kernel adds one to the bin named by each sample.
The counts are accumulated in the **local** array `acc` rather than in `h` directly, and both reasons matter.

A local array becomes a memory *inside* the generated design, so co-simulation drives the real RAM.
If the counts were accumulated straight into the `h` port, the memory would live outside the design and the testbench would supply a model of it, and that model forwards write data to a colliding read.
A design with a broken dependence would then pass co-simulation, and this lesson would be unable to show the failure it is about.

A local array can also be pinned to a storage type with `BIND_STORAGE`, which all three solutions do.
Left to itself, Vitis HLS 2023.2.2 solves this dependence entirely in hardware and reaches II 1 with no directive at all, which leaves `DEPENDENCE` nothing to demonstrate.
Pinning `acc` to an ordinary two-port block RAM is a realistic storage choice that puts the read-to-write gap at two cycles and makes the dependence visible in the schedule.

The type `ap_uint<4>` is an arbitrary-precision unsigned integer of 4 bits from the Vitis HLS library, and it guarantees that every sample is a legal index into `acc`.
Inside one iteration, the read of `acc[b]` must still come before the write of `acc[b]`; that intra-iteration dependence is real, and the directive leaves it alone by using `-type inter`.

## 4. The solutions

| Solution    | Helpers, identical in all three                          | DEPENDENCE on `acc` in `HIST_LOOP`                     |
| ----------- | -------------------------------------------------------- | ------------------------------------------------------ |
| `base`      | `PIPELINE`, `BIND_STORAGE -type RAM_2P -impl BRAM`        | none                                                   |
| `false_dep` | same                                                      | `-type inter -dependent false`                         |
| `dist2`     | same                                                      | `-type inter -dependent true -direction RAW -distance 2` |

`PIPELINE` is given without `-II`, so the scheduler reports the best II it can reach and the log says `Target II = NA`.
`common/part.tcl` still sets `config_compile -pipeline_loops 0`, but an explicit `PIPELINE` directive overrides it for this loop.
`IN_LOOP` and `OUT_LOOP` are left unpipelined in every solution, so they contribute the same fixed number of cycles everywhere and cancel out of the comparison.

The number 2 in `dist2` is not arbitrary: it is copied out of the `II Violation` message that `base` prints, which ends with `distance = 2`.
Copying it is the mistake the solution exists to demonstrate.

**Co-simulation** runs the testbench against the generated register-transfer level (RTL) design, the Verilog that describes the hardware cycle by cycle.
The testbench takes one argument that selects a vector set, and the script runs co-simulation with both sets in all three solutions.
The `unique` set names every bin exactly once per call, so it never triggers the dependence.
The `repeat` set names the same bin several times: sixteen equal samples, two bins that alternate, and eight random draws in which repeats can happen anywhere.

## 5. Predict

Write these numbers down before you run anything.

**Initiation interval.**
With $g = 2$ and the one-deep bypass described in section 2, a schedule is safe when $\lceil g / \textrm{II} \rceil \le 1$, so `base` needs

$$\textrm{II} \ge g = 2.$$

In `false_dep` the constraint is gone and nothing else limits the loop, so the II becomes 1.
In `dist2` the dependence is declared to hold between iterations two apart, so the read of iteration $i+2$ must follow the write of iteration $i$:

$$t_R + 2\,\textrm{II} > t_W \quad\Rightarrow\quad \textrm{II} > \tfrac{g}{2} = 1 \quad\Rightarrow\quad \textrm{II} \ge 2,$$

which is the same II as `base` for none of the safety.

**Latency.**
A pipelined loop of depth $D$ with $N$ iterations takes $D + \textrm{II}\,(N-1)$ cycles, and the module that Vitis wraps around it adds one.
With $D = 4$ and $N = 16$, the `HIST_LOOP` instance should read 35 cycles at II 2 and 20 at II 1.
`IN_LOOP` and `OUT_LOOP` contribute 32 cycles each, and the function adds a few cycles of loop control on top:

$$L \approx 32 + L_{\textrm{HIST}} + 32 + 3,$$

which gives 102 cycles for `base` and `dist2` and 87 for `false_dep`, a saving of exactly $(2-1)(16-1) = 15$ cycles.

**The wrong answers.**
When the bypass is gone, iteration $i$ misses the writes of the $\lceil g / \textrm{II} \rceil$ iterations before it.
For sixteen identical samples, the final count is

$$c_{15} = \left\lceil \frac{N}{\lceil g/\textrm{II} \rceil + 1} \right\rceil .$$

In `false_dep`, $\lceil 2/1 \rceil = 2$, so the count is $\lceil 16/3 \rceil = 6$, and `repeat_alt`, the alternating `3, 7, 3, 7` sequence, also fails because the same bin returns after only two iterations.
In `dist2`, $\lceil 2/2 \rceil = 1$, so the count is $\lceil 16/2 \rceil = 8$, and `repeat_alt` passes, because four cycles separate two uses of the same bin.
Among the random cases, `dist2` should break only where two equal samples are adjacent, and `false_dep` wherever two equal samples fall within two iterations.

| Quantity                        | `base` | `false_dep` | `dist2` |
| ------------------------------- | ------ | ----------- | ------- |
| Achieved II of `HIST_LOOP`      | 2      | 1           | 2       |
| Iteration latency (depth)       | 4      | 4           | 4       |
| `HIST_LOOP` instance latency    | 35     | 20          | 35      |
| Function latency (cycles)       | 102    | 87          | 102     |
| Bypass register in the RTL      | yes    | no          | no      |
| Count of bin 5 in `repeat_same` | 16     | 6           | 8       |
| Co-simulation, `unique` vectors | pass   | pass        | pass    |
| Co-simulation, `repeat` vectors | pass   | fail        | fail    |

## 6. Run

```bash
cd s1_loops/15_dependence
vitis_hls -f run_hls.tcl 2>&1 | tee run.log
```

The same run through the repository Makefile is `make run LESSON=s1_loops/15_dependence`.

Then collect the summary numbers:

```bash
bash ../../common/collect_latency.sh   hist_proj
bash ../../common/collect_resources.sh hist_proj
```

`make check LESSON=s1_loops/15_dependence` runs both scripts.

C simulation runs only in `base`, with both vector sets, because it executes the unchanged C code and passes in every solution.
Co-simulation runs in all three solutions with both vector sets, because `DEPENDENCE` changes the behaviour of the hardware and only the RTL shows it.
A failing co-simulation raises a Tcl error, so the script catches it and prints a summary of all six runs at the end of `run.log`.

## 7. Read the results

### The log

```bash
grep -nE "== solution|Pipelining result|Unable to enforce|214-52|Loop Constraint Status" run.log
```

`base` reports that it could not meet the dependence at II 1, and then settles on II 2:

```text
WARNING: [HLS 200-880] The II Violation in module 'hist_Pipeline_HIST_LOOP' (loop 'HIST_LOOP'):
Unable to enforce a carried dependence constraint (II = 1, distance = 2, offset = 1) between
'store' operation ... on array 'acc' and 'load' operation ... on array 'acc'.
INFO: [HLS 200-1470] Pipelining result : Target II = NA, Final II = 2, Depth = 4, loop 'HIST_LOOP'
INFO: [HLS 200-790] **** Loop Constraint Status: All loop constraints were NOT satisfied.
```

This is the message the directive exists to answer, and it is worth reading closely.
It names the array, it names the two operations, and it states the II at which the constraint failed.
The `distance = 2` at the end is the tool's own measure of the conflict and, as `dist2` shows below, it is **not** the number to hand to `-distance`.
The closing status line says the constraints were not satisfied even though the tool found a legal schedule at II 2; with no `-II` given there was no target to meet, so read the `Final II` and not that line.

`false_dep` prints no violation at all, only an acknowledgement of the promise, and reaches II 1:

```text
WARNING: [ANALYSIS 214-52] Found false inter dependency for variable 'acc' (.../src/hist.cpp:7).
INFO: [HLS 200-1470] Pipelining result : Target II = NA, Final II = 1, Depth = 4, loop 'HIST_LOOP'
INFO: [HLS 200-790] **** Loop Constraint Status: All loop constraints were satisfied.
```

The warning is the tool recording the claim, not checking it.
It is printed during `Architecture Synthesis`, before scheduling starts, which is the point at which the dependence edge is deleted.

`dist2` prints the same `II Violation` as `base` and the same `Final II = 2`.
The directive bought it nothing that the log can see.

### The loop table

`HIST_LOOP` is pipelined, so Vitis lifts it into a module of its own and the loop row moves with it.
The top-level report shows only `IN_LOOP` and `OUT_LOOP`, with the pipelined loop appearing in the `* Instance` table:

```bash
for s in base false_dep dist2; do
    echo -n "$s  "; grep -m 1 "grp_hist_Pipeline_HIST_LOOP_fu" hist_proj/$s/syn/report/hist_csynth.rpt
done
```

```text
base       |grp_hist_Pipeline_HIST_LOOP_fu_108  |hist_Pipeline_HIST_LOOP  |  35|  35| 0.117 us| 0.117 us|  35|  35|  no|
false_dep  |grp_hist_Pipeline_HIST_LOOP_fu_108  |hist_Pipeline_HIST_LOOP  |  20|  20|66.600 ns|66.600 ns|  20|  20|  no|
dist2      |grp_hist_Pipeline_HIST_LOOP_fu_108  |hist_Pipeline_HIST_LOOP  |  35|  35| 0.117 us| 0.117 us|  35|  35|  no|
```

The loop row itself is in the module's own report:

```bash
for s in base false_dep dist2; do
    echo -n "$s  "; grep -- "- HIST_LOOP" hist_proj/$s/syn/report/hist_Pipeline_HIST_LOOP_csynth.rpt
done
```

```text
base       |- HIST_LOOP  |       33|       33|         4|          2|          1|    16|       yes|
false_dep  |- HIST_LOOP  |       18|       18|         4|          1|          1|    16|       yes|
dist2      |- HIST_LOOP  |       33|       33|         4|          2|          1|    16|       yes|
```

The iteration latency is 4 in all three, which agrees with `Depth = 4` in the log and is the $D$ used in section 2.
The two sub-columns of the Initiation Interval differ here, unlike in earlier lessons: the achieved II is 2 in `base` and `dist2` while the target reads 1.
That pair of numbers, 2 achieved against 1 targeted, is the report's way of saying what the `II Violation` said in prose.

The loop latencies of 33 and 18 are one cycle below $D + \textrm{II}\,(N-1)$, which is 34 and 19, the off-by-one that `notes/env.md` records for pipelined loops; the missing cycle reappears in the module latency of 35 and 20.

The function latencies are what the collector prints:

```text
solution         best      worst     ii_min     ii_max   clk_est_ns
base              102        102        103        103        2.253
dist2             102        102        103        103        2.253
false_dep          87         87         88         88        2.253
```

102 and 87 are the predicted numbers, and they account for themselves: $32 + 35 + 32 = 99$ and $32 + 20 + 32 = 84$, each with three cycles of loop control on top.
The estimated clock is 2.253 ns in all three, so the 15 saved cycles are 15 saved nanoseconds and not a longer clock in disguise.

### The co-simulation report

The summary at the end of `run.log` is the point of the lesson:

```text
== cosim base unique PASS
== cosim base repeat PASS
== cosim false_dep unique PASS
== cosim false_dep repeat FAIL
== cosim dist2 unique PASS
== cosim dist2 repeat FAIL
```

Both directives produce hardware that is wrong, and both are wrong only for the `repeat` vectors.
The `unique` vectors pass everywhere, which is exactly why they cannot be used to justify the directive.

The testbench prints the bins that disagree:

```bash
grep -E "got .* expected" run.log
```

In `false_dep`, where two iterations are uncovered:

```text
repeat_same    bin  5: got 6, expected 16
repeat_alt     bin  3: got 4, expected 8
repeat_alt     bin  7: got 4, expected 8
repeat_rand0   bin  3: got 2, expected 3
...
```

In `dist2`, where one iteration is uncovered:

```text
repeat_same    bin  5: got 8, expected 16
repeat_rand1   bin  6: got 2, expected 3
repeat_rand2   bin  1: got 1, expected 2
...
```

Both counts are the predicted ones, $\lceil 16/3 \rceil = 6$ and $\lceil 16/2 \rceil = 8$, and the pattern of failures confirms the model in section 2.
`repeat_alt` fails in `false_dep` and passes in `dist2`, because `3, 7, 3, 7` brings the same bin back after two iterations: two iterations is within reach of the II 1 schedule and out of reach of the II 2 one.
Among the eight random cases, `dist2` fails four, the ones that contain two equal samples next to each other, while `false_dep` fails six, adding the ones whose repeats are two apart.

The co-simulation reports record the measured cycle counts and the verdict:

```bash
for s in base false_dep dist2; do
    echo -n "$s "; grep "Verilog" hist_proj/$s/sim/report/hist_cosim.rpt
done
```

Note that the file holds the *last* co-simulation of each solution, which is the `repeat` run.

Each prints one `Verilog` row; collected, they read:

| Solution    | Status | Latency | Interval | Total execution time |
| ----------- | ------ | ------- | -------- | -------------------- |
| `base`      | Pass   | 100     | 101      | 1009                 |
| `false_dep` | Fail   | 85      | 86       | 859                  |
| `dist2`     | Fail   | 100     | 101      | 1009                 |

`dist2` takes exactly as many cycles as `base` and fails.
That line on its own is the argument against copying a number out of a warning message.

### The Verilog

The pipelined loop is a module of its own, `hist_hist_Pipeline_HIST_LOOP.v`, and the bypass register lives in it:

```bash
for s in base false_dep dist2; do
    echo -n "$s: "; grep -c -E "reuse|addr_cmp" hist_proj/$s/syn/verilog/hist_hist_Pipeline_HIST_LOOP.v
done
```

`base` has 15 matching lines and the other two have none.
The logic in `base` is the forwarding path a hand-written histogram pipeline contains:

```verilog
reg  [63:0] reuse_addr_reg_...;                 // bin of the previous iteration
reg  [31:0] reuse_reg_...;                      // count the previous iteration wrote
assign addr_cmp_...   = ((reuse_addr_reg_... == zext_...) ? 1'b1 : 1'b0);
assign reuse_select_... = ((addr_cmp_reg_... == 1'b1) ? reuse_reg_... : acc_q0);
```

Read it against section 2.
`base` needs II 2 *and* this register: the register covers the one iteration that is still in flight at II 2, and there is no second register to cover the second one that would be in flight at II 1.
`false_dep` and `dist2` both told the tool that iterations one apart are independent, so neither builds the comparator or the multiplexer, and in both the adder is wired straight to the RAM output.

The memory itself is now part of the design, which is what makes co-simulation able to fail:

```bash
grep -n "acc_U\|RAM_2P" hist_proj/base/syn/verilog/hist.v | head -4
```

```verilog
hist_acc_RAM_2P_BRAM_1R1W #(.DataWidth(32), .AddressRange(16), .AddressWidth(4))
acc_U( .clk(ap_clk), ... );
```

`BRAM_18K` reads 1 in all three utilization tables, for this instance.
The `h` port, which is now touched only by `IN_LOOP` and `OUT_LOOP` and never twice in one cycle, has shrunk to a single `ap_memory` port with `h_address0`, `h_ce0`, `h_we0`, `h_d0` and `h_q0`.

### Fill this in

| Quantity                        | Predicted | `base` | `false_dep` | `dist2` |
| ------------------------------- | --------- | ------ | ----------- | ------- |
| Achieved II of `HIST_LOOP`      | 2 / 1 / 2 | 2      | 1           | 2       |
| Iteration latency (depth)       | 4         | 4      | 4           | 4       |
| `HIST_LOOP` loop latency        | 33 / 18   | 33     | 18          | 33      |
| `HIST_LOOP` instance latency    | 35 / 20   | 35     | 20          | 35      |
| Function latency                | 102 / 87  | 102    | 87          | 102     |
| Interval                        | 103 / 88  | 103    | 88          | 103     |
| Estimated clock (ns)            | below 2.43| 2.253  | 2.253       | 2.253   |
| Bypass register in the RTL      | yes/no/no | yes    | no          | no      |
| Count of bin 5 in `repeat_same` | 16 / 6 / 8| 16     | 6           | 8       |
| Cosim `unique`                  | pass      | PASS   | PASS        | PASS    |
| Cosim `repeat`                  | pass/fail/fail | PASS | FAIL     | FAIL    |
| BRAM_18K                        | 1         | 1      | 1           | 1       |
| FF                              |           | 171    | 79          | 74      |
| LUT                             |           | 449    | 313         | 336     |

Every predicted number was met, including both wrong counts.
The relations confirmed are that denying the dependence buys exactly $(2-1)(16-1) = 15$ cycles at the same clock; that the saving comes with a design that fails on any input with a repeated bin within two iterations; and that misdescribing the dependence with `-distance 2` buys nothing at all and fails on any input with two equal samples in a row.

## 8. Hardware implications

The directive itself creates no hardware.
It removes an edge from the dependence graph that the scheduler uses, and everything else follows from the schedule that becomes legal.

The datapath is the same in all three solutions: one 32-bit adder, one 4-bit bin register, the address lines of `x`, `h` and `acc`, and one block RAM for `acc`.
What changes is the control and the bypass.
`base` spends 171 FF and 449 LUT, of which the `HIST_LOOP` module is 144 FF and 246 LUT; `false_dep` spends 79 FF and 313 LUT with 52 FF and 110 LUT in the module; `dist2` spends 74 FF and 336 LUT with 47 FF and 133 LUT in the module.

The 92 flip-flops that separate `base` from `false_dep` inside the loop module are almost entirely the bypass: a 64-bit address register, a 32-bit data register and the registered comparison.
The 64-bit width is an artefact worth noticing, because the address it holds is 4 bits wide; the tool compares the zero-extended 64-bit array index that the front end produced and never narrows it, and the comparator that goes with it is the largest single expression in the design.

So on this kernel the directive removes real hardware as well as cycles, and that is the trap.
The hardware it removes is the hardware that made the answer right.
`base` is the only solution here that computes a histogram; the other two compute something cheaper and faster that is not a histogram.
`dist2` is the worst of the three by every measure: it has the latency of `base` and the correctness of `false_dep`.

The effects carry over to a standard-cell ASIC flow.
The bypass register, the comparator and the multiplexer are ordinary flip-flops and gates, and an ASIC synthesis tool would build or omit exactly the same ones.
`acc` becomes a compiled two-port SRAM macro instead of a block RAM, and the II of the loop still decides how many of its accesses are in flight when a read is taken.
If anything the ASIC case is less forgiving: what a two-port macro returns for a read that collides with a write is decided by the macro compiler, and many declare it illegal outright, whereas the block RAM behaviour on an UltraScale+ device is at least documented (see UG573, the UltraScale memory resources guide).
Only the FF and LUT numbers are specific to the FPGA.

## 9. One common mistake and one question

**The mistake: checking a false dependence with C simulation, or with data that never triggers it.**
C simulation runs the sequential C code, which is always correct, so it passes whatever the directive says; `run.log` shows `base` passing C simulation on both vector sets before a single line of RTL exists.
Co-simulation with the `unique` vectors also passes in all three solutions, because those inputs never name the same bin twice.
Half of the random `repeat` cases pass in `dist2` as well.
A false dependence must be justified by an argument about every possible input, and the testbench must contain the input that would break it.
Here that input is `repeat_same`, sixteen copies of one bin, and it is what turns a plausible directive into a visible failure.

If you cannot make the argument, the dependence is real, and the II of 2 in `base` is the price of a correct design.

There is a second mistake in this lesson, and it is quieter.
`base` prints `distance = 2` in its `II Violation` message, and `dist2` copies that 2 into `-distance`.
The result is hardware with no speed-up and a wrong answer.
The number in the message is the tool's internal measure of the conflict in its own terms; `-distance` wants the number of *iterations* that must separate two accesses to the same element, and in a histogram that number is 1, because any two consecutive samples may name the same bin.
Declaring `-distance 1` is declaring what the tool already assumes, which is why no setting of this directive can make this kernel correct at II 1.

**The question:** `false_dep` returns 6 for a histogram of sixteen identical samples and `dist2` returns 8.
Where do those two numbers come from, and what would `false_dep` return if `acc` were bound to a RAM with a read latency of 2 instead of 1?

<details>
<summary>Answer</summary>

Both numbers come from the same formula.
When the bypass register is absent, iteration $i$ takes a value from `acc` that is missing the writes of the $\lceil g/\textrm{II} \rceil$ iterations immediately before it, where $g = t_W - t_R = 2$ cycles is the read-to-write gap of one iteration.
For $N$ identical samples the counter therefore advances once every $\lceil g/\textrm{II} \rceil + 1$ iterations, and the final count is

$$c_{N-1} = \left\lceil \frac{N}{\lceil g/\textrm{II}\rceil + 1} \right\rceil .$$

In `false_dep`, II is 1, so two iterations are uncovered and the count is $\lceil 16/3 \rceil = 6$.
In `dist2`, II is 2, so one iteration is uncovered and the count is $\lceil 16/2 \rceil = 8$.
The same formula predicts which other cases fail: a bin that recurs after $k$ iterations survives when $k > \lceil g/\textrm{II} \rceil$, which is why the alternating `3, 7, 3, 7` input fails at II 1 and passes at II 2.

A RAM with a read latency of 2 adds a cycle between the read and the arrival of the data, so the depth grows from 4 to 5 and the gap grows from $g = 2$ to $g = 3$.
At II 1 that leaves three uncovered iterations, and the count should become $\lceil 16/4 \rceil = 4$.
Changing `-latency 1` to `-latency 2` in the three directives files and re-running confirms it: `false_dep` still reports `Final II = 1`, now at `Depth = 5`, and `repeat_same` comes back as 4 instead of 6.
The broken design gets more broken as the memory gets slower, because the II stays at 1 while the window of unlanded writes grows.

The second half of the answer is a caution about the model.
`base` at `-latency 2` does **not** slow down: it still reports `Final II = 2`, even though the gap is now 3 cycles and the one-deep bypass of section 2 could not cover the two iterations that II 2 leaves in flight.
Vitis evidently builds a deeper bypass when the schedule needs one.
It does eventually give way: at `-latency 3` the depth reaches 7 and `base` reports `Final II = 3`, while `false_dep` still reports 1.

So the arithmetic in section 2 is a faithful account of the design this lesson builds, and a starting point rather than a law for any other one.
What does generalise is the shape: the cost of a false dependence is not a fixed error but one that grows with how far ahead the pipeline is allowed to run, so a directive that looks harmless on a fast memory can quietly get worse when the memory gets slower, while the honest design absorbs the same change by scheduling around it.

</details>
