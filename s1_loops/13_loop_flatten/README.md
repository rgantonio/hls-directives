# 1.3 LOOP_FLATTEN

## 1. Introduction

The `LOOP_FLATTEN` directive turns a loop nest into a single loop.
A **loop nest** is a loop that contains another loop, such as a row loop that contains a column loop.
In the generated hardware, each loop of a nest has its own control, and moving from the inner loop back to the outer loop and into the inner loop again costs extra clock cycles.
Flattening replaces the two loops with one loop that runs over every combination of the two indices, so the control never has to leave one loop and enter another.

A nest can be flattened only when it is **perfect** or **semi-perfect**.
In a perfect nest, all the work sits in the innermost loop body, no code sits between the loop statements, and every loop bound is a constant.
A semi-perfect nest is the same, except that the outermost loop may have a bound that is only known at run time.

**What it is meant to improve:** latency.
The cycles spent on each transition between the inner and the outer loop disappear, so the saving is a fixed number of cycles per outer iteration.
The real payoff comes when the inner loop is pipelined, because a flattened loop keeps one pipeline running across all rows instead of draining and refilling it at the start of every row.
That combination is not part of this lesson, because only the taught directive may vary here.

**What it costs:** control logic, and sometimes cycles.
The flattened loop needs one wider counter that covers every combination of the indices, together with a comparator and a multiplexer that decides when the column index wraps and the row index steps.
That multiplexer sits in front of the memory address, and in an unpipelined loop it can lengthen every single iteration.
This is exactly what happens in this lesson: the flattened loop is **slower** than the nest, as section 7 shows.
Flattening also requires the nest to be perfect or semi-perfect, and code that breaks this rule silently prevents it.

**When to use it:** on a nest whose inner loop is pipelined, where Vitis HLS flattens eligible nests on its own and the `-off` option keeps a nest intact when you want the loops to stay separate.
On an unpipelined nest like this one, Vitis HLS 2023.2 does **not** flatten on its own, so `default` produces exactly the same hardware as `off`, and the explicit directive is the only way to get a flattened loop.
The lesson checks both claims with the normalized Verilog diff from lesson 1.2.

Reference: UG1399, [pragma HLS loop_flatten](https://docs.amd.com/r/2023.2-English/ug1399-vitis-hls/pragma-HLS-loop_flatten) and [set_directive_loop_flatten](https://docs.amd.com/r/2023.2-English/ug1399-vitis-hls/set_directive_loop_flatten).
UG1399 states that the directive belongs on the innermost loop of the nest and that it flattens that loop together with the loops above it.

## 2. How it works

Both versions are small **finite state machines (FSMs)**, circuits that step through a fixed set of states and choose the next state from the current state and a few conditions.
Each state is one clock cycle.
The tables below list the states that Vitis HLS actually built for this kernel, taken from `madd_proj/<solution>/.autopilot/db/madd.verbose.sched.rpt`.
The delay column is the longest combinational path in the state; with a 3.33 ns clock and 0.90 ns of uncertainty, a state may use at most about 2.43 ns.

**Nested (`off` and `default`):**

| State | Role                    | Work in the state                                                           | Delay   | Next                 |
| ----- | ----------------------- | --------------------------------------------------------------------------- | ------- | -------------------- |
| S1    | entry                   | `i = 0`                                                                     | 0.43 ns | S2                   |
| S2    | `ROW_LOOP` header (`H`) | test `i == 8`, compute `i + 1` and the row base `i*8`, set `j = 0`          | 0.79 ns | S3, or exit          |
| S3    | `COL_LOOP` header + read (`R`) | test `j == 8`, compute `j + 1` and the address `i*8 + j`, start the reads of `a` and `b` | 2.01 ns | S4, or back to S2 |
| S4    | add (`A`)               | finish the reads, add                                                       | 2.25 ns | S5                   |
| S5    | write (`W`)             | write `y`                                                                   | 1.23 ns | S3                   |

**Flattened (`on`):**

| State | Role                   | Work in the state                                                                                   | Delay   | Next        |
| ----- | ---------------------- | --------------------------------------------------------------------------------------------------- | ------- | ----------- |
| S1    | entry                  | `indvar_flatten = 0`, `i = 0`, `j = 0`                                                              | 0.43 ns | S2          |
| S2    | flat header (`C`)      | test `indvar_flatten == 64`; test `j == 8` and select `j` → 0, `i` → `i + 1`; compute the address `i*8 + j` | 2.30 ns | S3, or exit |
| S3    | read (`R`)             | start the reads of `a` and `b`                                                                      | 1.24 ns | S4          |
| S4    | add (`A`)              | finish the reads, add                                                                               | 2.25 ns | S5          |
| S5    | write (`W`)            | write `y`                                                                                           | 1.23 ns | S2          |

Written as a sequence of states, one row of a small 3 column nest looks like this:

```text
nested:     H  R A W  R A W  R A W  R            = 1 + 3*3 + 1 = 11 cycles per row
flattened:     C R A W  C R A W  C R A W         =     3*4     = 12 cycles per row
```

In the nested version, every row pays two control states: the row header `H`, and one last pass through `S3` in which the test `j == 8` succeeds and the FSM leaves the inner loop.
The body itself costs 3 states, because the column header shares `S3` with the start of the reads.

In the flattened version, the two per-row states are gone, which is the saving flattening promises.
The price is that the header can no longer share a state with the reads.
The column index used in the address now comes out of the wrap multiplexer, so the path from the `j` register to the memory is

$$0.80\ (\texttt{j == 8}) + 0.28\ (\text{select}) + 0.78\ (i \cdot 8 + j) + 1.24\ (\text{RAM read}) \approx 3.1\ \text{ns},$$

which does not fit into the 2.43 ns budget of one state.
The scheduler therefore gives the header its own state `C` and pushes the reads into the next state, so every iteration becomes 4 cycles instead of 3.
In the nested version, `j` goes straight from its register into the address adder, and the same path is only 0.78 + 1.24 ≈ 2.0 ns.

## 3. The kernel

```cpp
#include "madd.h"

// Element-wise addition of two R by C matrices. ROW_LOOP and COL_LOOP form a
// perfect loop nest: all work sits in the inner body and both bounds are
// constants. COL_LOOP carries the LOOP_FLATTEN directive in off and on.
void madd(const data_t a[R][C], const data_t b[R][C], data_t y[R][C]) {
ROW_LOOP:
    for (int i = 0; i < R; i++) {
    COL_LOOP:
        for (int j = 0; j < C; j++) {
            y[i][j] = a[i][j] + b[i][j];
        }
    }
}
```

The header sets `R = 8` and `C = 8`, so the nest runs 64 iterations in total.
The body is the same addition as `vadd` in lesson 1.1, but its **iteration latency**, the number of cycles one pass through the body takes, is 3 here and not 2.
The arrays hold 64 words instead of 16, and the larger memories have a read delay of 1.24 ns instead of 0.67 ns.
In `vadd`, the read, the add and the write fit into one state; here, read plus add already take 2.25 ns, so the write moves into a state of its own.
This is a useful reminder that the iteration latency depends on the memories and the clock, not only on the C++ body.

## 4. The solutions

| Solution  | Directive in `directives_<solution>.tcl`          | Measured loop structure |
| --------- | ------------------------------------------------- | ----------------------- |
| `off`     | `set_directive_loop_flatten -off "madd/COL_LOOP"` | nested                  |
| `default` | none                                              | nested, same as `off`   |
| `on`      | `set_directive_loop_flatten "madd/COL_LOOP"`      | flattened               |

Because loop flattening is something the tool may do on its own, this lesson uses `off`, `default` and `on` instead of a `base` solution.
The directive sits on `COL_LOOP` in both variants, since UG1399 places it on the innermost loop.
`common/part.tcl` sets `config_compile -pipeline_loops 0`, which matters more here than in earlier lessons.
Vitis HLS flattens a nest automatically as part of pipelining it, so with automatic pipelining switched off, the tool leaves this nest alone and `default` is nested.

## 5. Predict

Write these numbers down before running anything, using the state tables of section 2.

With $L_{\textrm{it}}$ for the iteration latency, the nested version spends $C\,L_{\textrm{it}}$ cycles on the body of one row, plus 2 control cycles for the row header and the inner exit test.
With $L_{\textrm{it}} = 3$, the loop latency of the nest is

$$L_{\textrm{off}} = R\,\bigl(C\,L_{\textrm{it}} + 2\bigr) = 8\,(8 \cdot 3 + 2) = 208\ \textrm{cycles}.$$

In the flattened version, there are 64 iterations and no row transitions, but each iteration costs $L_{\textrm{it}} + 1 = 4$ cycles:

$$L_{\textrm{on}} = R\,C\,\bigl(L_{\textrm{it}} + 1\bigr) = 8 \cdot 8 \cdot 4 = 256\ \textrm{cycles}.$$

As in lesson 1.2, the function latency is one cycle more than the loop latency, for the entry state `S1`.

| Quantity                | `off` and `default`   | `on`                   |
| ----------------------- | --------------------- | ---------------------- |
| Loop rows in the report | 2, nested             | 1, `ROW_LOOP_COL_LOOP` |
| Trip count              | 8 and 8               | 64                     |
| Iteration latency       | 26 (outer), 3 (inner) | 4                      |
| Loop latency            | 208                   | 256                    |
| Function latency        | 209                   | 257                    |

The **trip count** is the number of times a loop body executes.
The iteration latency of the outer loop in `off` is the row header, the whole inner loop of 8 · 3 = 24 cycles, and the inner exit test, so 1 + 24 + 1 = 26.
The report lists the inner loop latency as 24, because it does not count the final exit test.

Flattening removes $2R = 16$ control cycles but adds $R\,C = 64$ cycles, one per iteration, so the net change is

$$L_{\textrm{on}} - L_{\textrm{off}} = R\,C - 2R = 64 - 16 = +48\ \textrm{cycles} \approx +23\%.$$

A naive model, in which flattening only removes one transition cycle per row and the wrap multiplexer is free, predicts the opposite: 136 cycles nested, 128 flattened.
That model ignores the clock period, and it is a common trap; section 2 shows where it breaks.

The second prediction is that `default` produces the same hardware as `off`, because nothing in this lesson is pipelined.

## 6. Run

Flattening changes the schedule and the loop control, but it does not change what the function computes.
For that reason, the script runs C simulation once, in `off`, to prove that the testbench passes, and runs only C synthesis for all three solutions.

```bash
cd s1_loops/13_loop_flatten
vitis_hls -f run_hls.tcl 2>&1 | tee run.log
```

The same run through the repository Makefile is `make run LESSON=s1_loops/13_loop_flatten`.

Then collect the summary numbers:

```bash
bash ../../common/collect_latency.sh   madd_proj
bash ../../common/collect_resources.sh madd_proj
```

You can also run `make check LESSON=s1_loops/13_loop_flatten`, which runs both scripts.
On Vitis HLS 2023.2.2 with the part and clock from `common/part.tcl`, they print:

```text
solution         best      worst     ii_min     ii_max   clk_est_ns
default           209        209        210        210        2.253
off               209        209        210        210        2.253
on                257        257        258        258        2.303

solution   module          BRAM_18K    DSP       FF      LUT   URAM
default    madd                   0      0       62      149      0
off        madd                   0      0       62      149      0
on         madd                   0      0       64      183      0
```

## 7. Read the results

### The log

The tool announces each flattened nest in the log.
The solution banners from `run_hls.tcl` show which solution each message belongs to:

```bash
grep -nE "== solution|[Ff]latten" run.log
```

Only the `on` solution prints the messages:

```text
INFO: [HLS 200-2061] Successfully converted nested loops 'ROW_LOOP'(.../madd.cpp:8:5) and 'COL_LOOP'(.../madd.cpp:10:9) in function 'madd' into perfectly nested loops.
INFO: [XFORM 203-541] Flattening a loop nest 'ROW_LOOP' (.../madd.cpp:8:5) in function 'madd'.
```

No such message appears under `off`, as expected, and none appears under `default` either.
This is the first sign that the tool does not flatten an unpipelined nest on its own.

### The loop table

Open `madd_proj/<solution>/syn/report/madd_csynth.rpt` and find the section headed `== Performance Estimates`, subsection `+ Detail`, table `* Loop`:

```bash
for s in off default on; do
    echo "== $s"; grep -A 7 "\* Loop:" madd_proj/$s/syn/report/madd_csynth.rpt
done
```

`off` and `default` show the same nest:

```text
|- ROW_LOOP   |      208|      208|        26|          -|          -|     8|        no|
| + COL_LOOP  |       24|       24|         3|          -|          -|     8|        no|
```

`on` shows a single flattened loop:

```text
|- ROW_LOOP_COL_LOOP  |      256|      256|         4|          -|          -|    64|        no|
```

The short summary `csynth.rpt` shows the same structure in its `Modules & Loops` table.
Compare the function latencies from the `* Summary` table, as in lesson 1.1, because the loop row and the function row differ by the entry cycle.

### The Verilog

The flattened loop needs a combined counter, which the tool names `indvar_flatten`.
Counting its occurrences shows at a glance which solutions were flattened:

```bash
grep -c "indvar_flatten" madd_proj/*/syn/verilog/madd.v
```

The count is 6 for `on` and 0 for `off` and `default`.
The one line worth reading is the exit test of the flattened loop:

```bash
grep -n "indvar_flatten.*==" madd_proj/on/syn/verilog/madd.v
```

It compares the 7 bit counter with `7'd64`:

```verilog
assign icmp_ln8_fu_119_p2 = ((indvar_flatten_fu_58 == 7'd64) ? 1'b1 : 1'b0);
```

In `off`, the corresponding tests compare the 4 bit counters `i` and `j` with 8, and their names carry the source line of each loop, `icmp_ln8` and `icmp_ln10`:

```verilog
assign icmp_ln10_fu_132_p2 = ((j_reg_89 == 4'd8) ? 1'b1 : 1'b0);
assign icmp_ln8_fu_112_p2  = ((i_fu_46  == 4'd8) ? 1'b1 : 1'b0);
```

To test which solutions share hardware, use the normalized diff from lesson 1.2, which hides the signal suffixes that shift between solutions:

```bash
norm(){ sed -E 's/_(fu|reg)_[0-9]+/_\1_N/g; s/HLS_SYN_LAT=[-0-9]+/HLS_SYN_LAT=X/' "$1"; }
diff <(norm madd_proj/default/syn/verilog/madd.v) <(norm madd_proj/off/syn/verilog/madd.v)
diff <(norm madd_proj/off/syn/verilog/madd.v)     <(norm madd_proj/on/syn/verilog/madd.v) | head -40
```

The first diff is empty, so `default` and `off` are the same hardware.
The second diff shows the removed separate `i` and `j` exit tests and the added `indvar_flatten` counter, comparator and `select_ln8` multiplexers.

### Fill this in

| Solution             | Loop rows | Trip count | Loop latency | Function latency | FF       | LUT      |
| -------------------- | --------- | ---------- | ------------ | ---------------- | -------- | -------- |
| `off`, predicted     | 2 nested  | 8 and 8    | 208          | 209              | lower    | lower    |
| `default`, predicted | 2 nested  | 8 and 8    | 208          | 209              | as `off` | as `off` |
| `on`, predicted      | 1         | 64         | 256          | 257              | higher   | higher   |
| `off`, measured      | 2 nested  | 8 and 8    | 208          | 209              | 62       | 149      |
| `default`, measured  | 2 nested  | 8 and 8    | 208          | 209              | 62       | 149      |
| `on`, measured       | 1         | 64         | 256          | 257              | 64       | 183      |

The relations confirmed are that `default` and `off` match exactly, that `on` is 48 cycles slower, and that `on` uses more logic: 2 more FF and 34 more LUT.
The estimated clock also gets slightly worse, from 2.253 ns to 2.303 ns, because the header state `C` now holds the longest path.

## 8. Hardware implications

What disappeared is the outer loop header in the FSM and the extra pass through the inner header at the end of each row.
In `off`, both are visited once per row, which costs 16 cycles over the whole nest.
The two small counters, `i` and `j`, each 4 bits wide because the tool sizes them to reach 8, are replaced as loop controls by one 7 bit counter that reaches 64.

What appeared is that 7 bit counter, its adder, its comparator against 64, and two multiplexers that either increment `j` or reset it to zero while stepping `i`.
In the report, the expression LUTs rise from 100 to 125 and the multiplexer LUTs from 49 to 58, so the look-up table count (LUT) grows from 149 to 183, and the flip-flop count (FF) from 62 to 64.
FF and LUT measure the basic storage and logic cells of the FPGA fabric.
The addition itself, the memories and the memory ports are untouched, because flattening only rewrites control.

The more important implication is the timing effect from section 2.
The multiplexer adds about 0.3 ns and the second comparator sits in front of it, and that is enough to push the memory read into a new state on every iteration.
Flattening therefore traded 16 control cycles for 64 extra body cycles.
In a pipelined loop, the same extra state would only add one cycle of pipeline depth, once, and flattening would win; without pipelining, it is paid 64 times.

One detail is worth checking in the flattened Verilog.
Since `C` is a power of two, the memory address of `y[i][j]` is exactly the flat index, so the tool could drive the address straight from the combined counter and skip the multiplexer on the address path.
It does not: the `select_ln` signals show that Vitis keeps separate `i` and `j` registers next to `indvar_flatten` and builds the address from them.

```bash
grep -n "select_ln" madd_proj/on/syn/verilog/madd.v | head
```

```verilog
assign select_ln8_1_fu_157_p3 = ((icmp_ln10_fu_143_p2[0:0] == 1'b1) ? add_ln8_fu_137_p2 : i_fu_54);
assign select_ln8_fu_149_p3   = ((icmp_ln10_fu_143_p2[0:0] == 1'b1) ? 4'd0 : j_fu_50);
```

For a standard cell ASIC flow, the structure of this lesson carries over.
Flattening is a change to the FSM and its counters, which are ordinary registers and gates rather than FPGA-specific cells, so an ASIC synthesis tool would build the same trade of control states for a wider counter and a multiplexer.
Whether the multiplexer costs an extra state depends on the gate and memory delays against the clock period, so the cycle counts, like the FF and LUT numbers, are specific to this target.

## 9. One common mistake and one question

**The mistake: breaking the perfect nest without noticing.**
Suppose the kernel also clears a per-row value before the inner loop, for example `s[i] = 0;` placed between `ROW_LOOP` and `COL_LOOP`.
That statement is code between the loop statements, so the nest is no longer perfect, and the tool cannot flatten it even with the directive.
Synthesis still succeeds, and the only sign is a warning in the log that the nest could not be flattened, followed by a report that quietly shows two nested loops again.
The usual repair is to move the statement into the inner body under a condition such as `if (j == 0)`, which restores a perfect nest.
After any change to a nest, check the log line from section 7 rather than assuming that the directive took effect, and check the latency rather than assuming that flattening helped.

**The question:** Two kernels process the same 64 elements with the same schedules as in this lesson: 3 cycles per iteration and 2 control cycles per row when nested, 4 cycles per iteration when flattened.
Kernel A has 32 rows of 2 columns, and kernel B has 2 rows of 32 columns.
For which kernel does flattening hurt less, and is there a shape for which it helps?

<details>
<summary>Answer</summary>

The flattened latency is $64 \cdot 4 = 256$ cycles for both kernels, because it does not depend on the shape.

For kernel A, the nested latency is $32\,(2 \cdot 3 + 2) = 256$ cycles, so flattening changes nothing: the 64 cycles it removes (2 per row) equal the 64 cycles it adds (1 per iteration).

For kernel B, the nested latency is $2\,(32 \cdot 3 + 2) = 196$ cycles, so flattening costs 60 cycles, about 31% more.

The general rule is $L_{\textrm{on}} - L_{\textrm{off}} = R\,C - 2R = R\,(C - 2)$.
Flattening an unpipelined nest with this schedule helps only when the inner loop has fewer than 2 iterations, breaks even at 2, and hurts more the longer the inner loop is.
The lesson to keep is that an unpipelined loop pays every extra state once per iteration, so a directive that saves cycles per row can still lose if it adds a state to the body.

</details>
