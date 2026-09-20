# 1.4 LOOP_MERGE

## 1. Introduction

The `LOOP_MERGE` directive combines consecutive loops into a single loop.
Without it, Vitis HLS runs the loops of a function one after the other: the second loop starts only after the last iteration of the first loop has finished.
When the loops do not depend on each other, that waiting is unnecessary, and merging lets the bodies of both loops execute in the same iterations.

The directive is placed on a region, which is a function or a loop body, and it merges the loops inside that region.
UG1399 lists the rules that decide whether a merge is legal.
If the loop bounds are variables, they must have the same value.
If the loop bounds are constants, the largest bound becomes the bound of the merged loop, and the shorter body is guarded so that it still runs only as often as before.
Loops with a variable bound cannot be merged with loops that have a constant bound.
Code between the loops must give the same result when it is executed more than once, so `a = b` is allowed but `a = a + 1` is not.
Loops that read from a FIFO cannot be merged, because merging would change the order of the reads.

**What improves:** latency, and to a smaller degree area.
The iterations of the second loop no longer wait for the whole first loop, so on this kernel the loop part of the latency is roughly halved.
One loop control disappears, and with it one counter, one exit comparator and the states of the finite state machine that belonged to the second loop.
When both bodies read the same array element in the same iteration, the tool can also serve both with one read.

**What it costs:** the merged body does the work of both loops in the same clock cycles, so everything both bodies need must be available at the same time.
On this kernel the two bodies write to different outputs, so nothing competes.
If both bodies had to use the same single memory port, the merged iteration would grow longer and part of the saving would be lost.
The merge also removes the separate loop rows from the report, which makes each original loop harder to inspect on its own.

**When to use it:** use it on consecutive loops that have the same trip count and that either do not depend on each other or depend on each other only at the same index.
Vitis HLS does not merge loops on its own, which is why this lesson compares a `base` solution without the directive against a `merge` solution with it.
The directive does change the hardware.

Reference: UG1399, [pragma HLS loop_merge](https://docs.amd.com/r/2023.2-English/ug1399-vitis-hls/pragma-HLS-loop_merge) and [set_directive_loop_merge](https://docs.amd.com/r/2023.2-English/ug1399-vitis-hls/set_directive_loop_merge).
The same pages describe the `-force` option, which is the subject of the common mistake in section 9.

## 2. How it works

The tables below use a small trip count of 3, so that the whole schedule fits on the page.
Rows are operations of one iteration, and columns are clock cycles.
`R` marks the cycle that reads `a` and `b`, and `W` marks the cycle that computes the result and writes it.
`X` marks a cycle that only runs the final exit test of a loop.

**Two loops (`base`):**

| Operation | 0  | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 |
| --------- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- |
| add i=0   | R  | W  |    |    |    |    |    |    |    |    |    |    |    |    |
| add i=1   |    |    | R  | W  |    |    |    |    |    |    |    |    |    |    |
| add i=2   |    |    |    |    | R  | W  |    |    |    |    |    |    |    |    |
| add exit  |    |    |    |    |    |    | X  |    |    |    |    |    |    |    |
| sub i=0   |    |    |    |    |    |    |    | R  | W  |    |    |    |    |    |
| sub i=1   |    |    |    |    |    |    |    |    |    | R  | W  |    |    |    |
| sub i=2   |    |    |    |    |    |    |    |    |    |    |    | R  | W  |    |
| sub exit  |    |    |    |    |    |    |    |    |    |    |    |    |    | X  |

**One merged loop (`merge`):**

| Operation | 0  | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 |
| --------- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- |
| add i=0   | R  | W  |    |    |    |    |    |    |    |    |    |    |    |    |
| sub i=0   | R  | W  |    |    |    |    |    |    |    |    |    |    |    |    |
| add i=1   |    |    | R  | W  |    |    |    |    |    |    |    |    |    |    |
| sub i=1   |    |    | R  | W  |    |    |    |    |    |    |    |    |    |    |
| add i=2   |    |    |    |    | R  | W  |    |    |    |    |    |    |    |    |
| sub i=2   |    |    |    |    | R  | W  |    |    |    |    |    |    |    |    |
| exit      |    |    |    |    |    |    | X  |    |    |    |    |    |    |    |

The controller of an unpipelined loop is a **finite state machine (FSM)**, a circuit that steps through a fixed set of states and chooses the next state from the current state and a few conditions.
In `base`, each loop owns its own states, its own counter and its own exit test.
The FSM finishes every iteration of `ADD_LOOP`, spends one cycle on its final exit test, and only then enters `SUB_LOOP`.
The subtraction for `i = 0` could have run in cycle 0, because it needs nothing that the addition produces, but the loop structure forces it to wait until cycle 7.
In `merge`, one counter drives both bodies.
The addition and the subtraction use separate operators and write to separate outputs, so they fit in the same two states, and the schedule shrinks from 14 cycles to 7.
Both bodies read `a[i]` and `b[i]` in the same cycle, so the two `R` entries of one iteration can become a single physical read, and section 7 shows that on this kernel they do.
The generated RTL places each exit test in the same state that issues the reads, so the `X` cycle is really a last visit to the `R` state rather than a state of its own.
The count of one extra cycle per loop is what the diagram is for, and section 7 reads the states back out of the Verilog.

## 3. The kernel

```cpp
#include "two_loops.h"

// Two independent loops over the same inputs. ADD_LOOP writes only y and
// SUB_LOOP writes only z, so neither loop needs a result of the other.
// Solution merge places LOOP_MERGE on the function, the region that holds
// both loops.
void two_loops(const data_t a[N], const data_t b[N], data_t y[N], data_t z[N]) {
ADD_LOOP:
    for (int i = 0; i < N; i++) {
        y[i] = a[i] + b[i];
    }
SUB_LOOP:
    for (int i = 0; i < N; i++) {
        z[i] = a[i] - b[i];
    }
}
```

The header sets `N = 16`, so each loop has a **trip count**, the number of times its body executes, of 16.
Each body is the same kind of operation as `vadd` in lesson 1.1 on the same 16-word arrays, so the **iteration latency**, the number of cycles one pass through the body takes, is expected to be 2 in both loops.
The two loops have the same constant bound and no code between them, and neither reads what the other writes, so every rule from section 1 is satisfied.

## 4. The solutions

| Solution | Directive in `directives_<solution>.tcl` | Expected loop structure              |
| -------- | ---------------------------------------- | ------------------------------------ |
| `base`   | none                                     | `ADD_LOOP`, then `SUB_LOOP`          |
| `merge`  | `set_directive_loop_merge "two_loops"`   | one loop that holds both bodies      |

The directive names the function `two_loops` because that function is the region that contains both loops.
No other directive is needed for the merge to have an effect, so `base` has an empty directives file.
`common/part.tcl` still sets `config_compile -pipeline_loops 0`, so neither the separate loops nor the merged loop is pipelined.

## 5. Predict

Write these numbers down before running anything.

With $L_{\textrm{it}} = 2$ and $N = 16$, each loop in `base` spends $N\,L_{\textrm{it}}$ cycles in its body and one cycle in its final exit test, and the two loops run one after the other:

$$L_{\textrm{base}} = 2\,\bigl(N\,L_{\textrm{it}} + 1\bigr) = 2\,(16 \cdot 2 + 1) = 66\ \textrm{cycles}.$$

In `merge`, there is one loop, one body of 2 cycles, and one exit test:

$$L_{\textrm{merge}} = N\,L_{\textrm{it}} + 1 = 16 \cdot 2 + 1 = 33\ \textrm{cycles}.$$

Both numbers are function latencies.
The loop rows of the report do not include the exit-test cycle, as lessons 1.2 and 1.3 showed, and the interval is expected to be one more than the function latency.

| Quantity                | `base`                  | `merge` |
| ----------------------- | ----------------------- | ------- |
| Loop rows in the report | 2, `ADD_LOOP` and `SUB_LOOP` | 1  |
| Trip count              | 16 and 16               | 16      |
| Iteration latency       | 2 and 2                 | 2       |
| Loop latency            | 32 and 32               | 32      |
| Function latency        | 66                      | 33      |
| Interval                | 67                      | 34      |
| Loop exit comparators   | 2                       | 1       |

The saving is

$$\frac{L_{\textrm{base}} - L_{\textrm{merge}}}{L_{\textrm{base}}} = \frac{N\,L_{\textrm{it}} + 1}{2\,\bigl(N\,L_{\textrm{it}} + 1\bigr)} = \frac{1}{2} = 50\%.$$

The result is exactly one half because the two loops have the same trip count and the merged body is no longer than either original body.
If the merged iteration needed a third cycle, the saving would fall to $1 - 49/66 \approx 26\%$, and section 7 shows how to check the state delays if that happens.

## 6. Run

Merging changes the order in which memory is accessed.
In `base`, every element of `y` is written before any element of `z`, and each input element is read twice at widely separated times.
In `merge`, `y[i]` and `z[i]` are produced in the same iteration, and each input element is read inside that one iteration instead of twice at widely separated times.
C simulation runs the original C code, so it cannot detect a mistake in that reordering.
The script therefore runs **C and RTL co-simulation (cosim)** for both solutions, which drives the same testbench through the generated register-transfer level (RTL) design.
C simulation runs once, in `base`, to prove that the testbench itself passes.

```bash
cd s1_loops/14_loop_merge
vitis_hls -f run_hls.tcl 2>&1 | tee run.log
```

The same run through the repository Makefile is `make run LESSON=s1_loops/14_loop_merge`.

Then collect the summary numbers:

```bash
bash ../../common/collect_latency.sh   two_loops_proj
bash ../../common/collect_resources.sh two_loops_proj
```

You can also run `make check LESSON=s1_loops/14_loop_merge`, which runs both scripts.

## 7. Read the results

### The log

The solution banners from `run_hls.tcl` show which solution each message belongs to:

```bash
grep -nE "== solution|[Mm]erg|TEST (PASSED|FAILED)|C/RTL co-simulation finished" run.log
```

Only `merge` prints a merge message:

```text
INFO: [XFORM 203-521] Merging 2 loops (.../src/two_loops.cpp:9, .../src/two_loops.cpp:13) in function 'two_loops'
as directed by loop_merge pragma(.../directives_merge.tcl:7). Note that Vitis HLS does not verify the
correctness of the merged loop.
```

Two details in it are worth keeping.
It names both source lines, 9 and 13, which are the two `for` statements, and it names the directive file and line that asked for the merge, which is how to tell an intended merge from one caused by a directive left over from another solution.
The closing sentence appears even though this merge is legal and needs no `-force`, so it is a standing disclaimer and not a warning about this design; section 9 comes back to it.

Both solutions report `TEST PASSED` and `*** C/RTL co-simulation finished: PASS ***`, and `base` reports `TEST PASSED` once more from its C simulation.

### The loop table

Open `two_loops_proj/<solution>/syn/report/two_loops_csynth.rpt` and find the section headed `== Performance Estimates`, subsection `+ Detail`, table `* Loop`:

```bash
for s in base merge; do
    echo "== $s"; grep -A 7 "\* Loop:" two_loops_proj/$s/syn/report/two_loops_csynth.rpt
done
```

`base` shows two rows at the same level, each with a trip count of 16, an iteration latency of 2 and a loop latency of 32:

```text
|- ADD_LOOP  |       32|       32|         2|          -|          -|    16|        no|
|- SUB_LOOP  |       32|       32|         2|          -|          -|    16|        no|
```

`merge` shows one row with the same three numbers:

```text
|- ADD_LOOP  |       32|       32|         2|          -|          -|    16|        no|
```

The merged loop keeps the label of the first loop, and `SUB_LOOP` disappears from the report.
This is the cost named in section 1: the surviving row does not say that a second body runs inside it, so after a merge the label alone is misleading and the source has to be read alongside the table.

The function latencies in the `* Summary` table read 66 and 33 and the intervals 67 and 34, which are the predicted numbers.
The estimated clock is 2.370 ns in both solutions, so the halved cycle count is a halved run time and not a longer clock in disguise.

The merged iteration latency reads 2, so the merged body did fit in two states.
Had it read 3, the per-state delays in `two_loops_proj/merge/.autopilot/db/two_loops.verbose.sched.rpt` would show which operation was pushed into the extra state.

### The co-simulation report

Open `two_loops_proj/<solution>/sim/report/two_loops_cosim.rpt`.
It reports the latency that the RTL actually took while the testbench ran.
Because every call has the same trip count, the minimum, average and maximum are equal, and here they match the C synthesis numbers exactly, with no off-by-one:

```text
solution   status   latency   interval   total execution time
base       Pass          66         67                   1741
merge      Pass          33         34                    883
```

Both solutions pass, which is the point of running cosim in this lesson: the merged loop touches the memories in a different order and still produces the same `y` and `z`.
The testbench makes 26 calls, and 26 x 67 = 1742 and 26 x 34 = 884 bracket the reported totals to within one cycle, so the whole simulation, not only one call, runs in half the time.

### The Verilog

Each loop has an exit comparator named after the source line of its `for` statement.
Counting them shows how many loops are left:

```bash
grep -n "assign icmp_ln" two_loops_proj/*/syn/verilog/two_loops.v
```

`merge` has one and `base` has two, each comparing its own 5 bit counter with `5'd16`:

```verilog
// merge
assign icmp_ln7_fu_108_p2  = ((i_fu_44   == 5'd16) ? 1'b1 : 1'b0);
// base
assign icmp_ln9_fu_128_p2  = ((i_fu_44   == 5'd16) ? 1'b1 : 1'b0);
assign icmp_ln13_fu_166_p2 = ((i_1_fu_48 == 5'd16) ? 1'b1 : 1'b0);
```

The merged design keeps one counter, `i_fu_44`, and the second counter `i_1_fu_48` is gone.
The line number in the merged name is 7, the line of the function, rather than 9 or 13, the lines of the two `for` statements, which is a second sign that the merged loop is a new loop and not either original one.

The finite state machine shrinks with it:

```bash
grep -n "parameter    ap_ST_fsm_state" two_loops_proj/*/syn/verilog/two_loops.v
```

`base` has five states and `merge` has three, and the next-state logic says what they do.
In `base`, state 1 waits for `ap_start`, states 2 and 3 are the body of `ADD_LOOP` and states 4 and 5 are the body of `SUB_LOOP`; states 2 and 4 also hold the exit test of their own loop, so the last visit to each is the one extra cycle per loop that section 5 predicted.
In `merge`, state 1 waits for `ap_start`, state 2 reads `a` and `b` and holds the single exit test, and state 3 writes both `y` and `z`.

To see whether the two reads of `a[i]` became one, look at the FSM states that enable the read port of `a`:

```bash
for s in base merge; do
    echo "== $s"; grep -B 3 "a_ce0 = 1'b1" two_loops_proj/$s/syn/verilog/two_loops.v
done
```

Two states enable it in `base`, one per loop, and one state enables it in `merge`:

```verilog
// base
if (((1'b1 == ap_CS_fsm_state4) | (1'b1 == ap_CS_fsm_state2))) begin a_ce0 = 1'b1;
// merge
if ((1'b1 == ap_CS_fsm_state2)) begin a_ce0 = 1'b1;
```

`b_ce0` follows the same pattern, and the interface table of both reports lists only port 0 for `a` and for `b`, so the merged design shared the two reads rather than asking for a second port.
Had the reads not been shared, Vitis would have given `a` a second port, `a_ce1` with `a_q1`, which is the behaviour `notes/env.md` records for arrays whose accesses land in the same cycle.

The address logic says the same thing more directly:

```bash
grep -nE "a_address0|y_address0|z_address0" two_loops_proj/*/syn/verilog/two_loops.v
```

In `base`, `a_address0` is driven by a three way multiplexer that picks between the two loop counters and `'bx`, and `y` and `z` have separate address registers.
In `merge`, all four addresses come straight from the one counter, with no multiplexer at all:

```verilog
assign a_address0 = zext_ln9_fu_114_p1;   // the counter itself
assign y_address0 = zext_ln9_reg_155;
assign z_address0 = zext_ln9_reg_155;
```

### Fill this in

| Solution           | Loop rows                    | Loop latency | Function latency | Cosim latency | FF     | LUT    |
| ------------------ | ---------------------------- | ------------ | ---------------- | ------------- | ------ | ------ |
| `base`, predicted  | 2                            | 32 and 32    | 66               | 66 or 65      | higher | higher |
| `merge`, predicted | 1                            | 32           | 33               | 33 or 32      | lower  | lower  |
| `base`, measured   | 2, `ADD_LOOP` and `SUB_LOOP` | 32 and 32    | 66               | 66            | 25     | 205    |
| `merge`, measured  | 1, `ADD_LOOP`                | 32           | 33               | 33            | 13     | 132    |

Every predicted number was met.
The relations confirmed are that `merge` takes exactly half the cycles of `base`, 33 against 66, at the same estimated clock of 2.370 ns; that both solutions pass co-simulation with a measured latency equal to the synthesis estimate; and that `merge` uses less logic rather than more, 12 fewer FF and 73 fewer LUT, which section 8 accounts for line by line.

## 8. Hardware implications

What disappeared is the entire control of the second loop: its counter, which the tool sizes to 5 bits to reach 16, its increment adder, its exit comparator and its FSM states, and with them the exit-test cycle between the two loops.
The flip-flop count (FF) and the look-up table count (LUT), which measure the basic storage and logic cells of the FPGA fabric, fall from 25 to 13 and from 205 to 132.
The utilization tables in the two reports account for all of it.

The 12 flip-flops are the second counter `i_1` (5), the second address register `zext_ln13_reg` (5), and two bits of the one-hot FSM register, which goes from 5 states to 3.
Of the 73 look-up tables, 25 sit in the expression table, the second increment adder (12) and the second exit comparator (13), and 48 sit in the multiplexer table: the address multiplexers on `a` and `b` (14 each) disappear because one counter now drives those addresses with nothing to choose between, the `ap_NS_fsm` multiplexer shrinks from 31 to 20 LUT with the two states, and the multiplexer that fed the second counter (9) goes with the counter.

The reads were shared, so half of the reads from `a` and `b` disappeared as well: the design performs 16 reads of each input instead of 32.
Note how large this saving is in relative terms, about half the FF and a third of the LUT, and how small it is in absolute terms.
This kernel is almost nothing but loop control, so removing one loop removes a large fraction of it.
On a kernel with a real datapath the same directive would remove the same few cells and the percentage would be negligible; latency is the reason to merge, and area is a side effect.

What stayed is the datapath.
The adder and the subtractor were separate operators in `base` as well, because Vitis does not usually share a cheap adder between two loops, and they are still separate in `merge`: `y_d0` and `z_d0` each cost 39 LUT in both reports, unchanged.
The difference is that they now work in the same cycle instead of in different phases of the FSM.
The outputs `y` and `z` are both written in state 3 of the merged FSM, which is possible only because they are separate memories with separate ports.

For a standard cell ASIC flow, everything in this lesson carries over.
The FSM, the counters and the comparators are ordinary registers and gates, so an ASIC synthesis tool would remove the same control logic, and the halved latency counts clock cycles rather than FPGA cells.
The shared reads carry over as well, and they matter more in an ASIC, where each read from an SRAM macro costs a noticeable amount of energy.
Only the FF and LUT numbers remain specific to the FPGA.

## 9. One common mistake and one question

**The mistake: forcing a merge that changes the result.**
Suppose `SUB_LOOP` is changed to `z[i] = y[N - 1 - i] - b[i];`, so that it reads an element of `y` that `ADD_LOOP` writes in a later iteration.
Merging these loops would make iteration 0 read `y[15]` before anything has written it, so the tool refuses the merge and reports that it cannot merge the loops.
That variant is not built in this lesson, so build it if you want the exact message on this install.
The `-force` option of the directive tells the tool to merge anyway, and UG1399 states that you then carry the responsibility for correctness.
The dangerous part is that C simulation still passes, because it runs the unchanged C code, and C synthesis still succeeds.
Only co-simulation shows the wrong values in `z`.
Treat a refused merge as information about a real dependence between the loops, and use `-force` only when you can explain why the warning does not apply, followed by a co-simulation that proves it.
Section 7 showed the other half of this: the log prints `Note that Vitis HLS does not verify the correctness of the merged loop` even for the legal merge in this lesson.
The sentence is a standing disclaimer, not a clearance, so a merge that runs without complaint is not by itself evidence that the merge is safe.

**The question:** Suppose `SUB_LOOP` runs only 12 iterations while `ADD_LOOP` still runs 16, and both bodies still take 2 cycles.
What function latency do you expect for `base` and for `merge`, and why does the saving shrink?

<details>
<summary>Answer</summary>

In `base`, the two loops still run one after the other, each with its own exit cycle:

$$L_{\textrm{base}} = (16 \cdot 2 + 1) + (12 \cdot 2 + 1) = 33 + 25 = 58\ \textrm{cycles}.$$

In `merge`, UG1399 says that the merged loop takes the largest constant bound, which is 16, and that the subtraction is guarded so that it runs only for the first 12 iterations:

$$L_{\textrm{merge}} = 16 \cdot 2 + 1 = 33\ \textrm{cycles}.$$

The saving is 25 cycles, which is about 43% instead of 50%.
Merging hides the shorter loop inside the longer one, so the cycles saved equal the cycles of the shorter loop, and the longer loop sets the latency.
This assumes that the guard, a comparison of the counter with 12 that decides whether `z` is written, fits in the existing states and does not lengthen the iteration.

</details>