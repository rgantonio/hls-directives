# 3.5 EXPRESSION_BALANCE

## 1. Introduction

EXPRESSION_BALANCE controls whether Vitis HLS may regroup a chain of associative operations, such as a run of additions, into a balanced tree.
An operation is associative when the grouping of its operands does not change the result, so that $(a+b)+c$ equals $a+(b+c)$.
Regrouping operands in this way is called reassociation.
A balanced tree is the grouping in which independent operations sit side by side, so the longest path of dependent operations, called the depth, falls from $n-1$ to $\lceil \log_2 n \rceil$ for $n$ operands.

What improves is latency, meaning the number of clock cycles from start to result, because a shorter dependent path needs fewer states of the finite state machine (FSM) that sequences the design.
What it costs is area.
In a chain, the operations happen one after another, so the tool can let one physical operator serve several of them in turn.
In a tree, several operations happen at the same moment, so each one needs its own operator.
UG1399 puts it directly: expression balancing prohibits sharing and results in increased area.

That is the textbook trade, and this lesson measures a case where only half of it shows up.
The area cost is real and is measured below.
The latency gain is not, because the tool has a second transformation, ternary-adder fusion, which shortens the chain's critical path enough to fit the same number of states as the tree.
Section 7 records the measurement and section 8 draws the rule out of it.

The defaults differ by type, and that difference is the subject of this lesson.
For integers, balancing is on by default, because two's-complement addition is associative even when it overflows and wraps, so every grouping returns the same bits.
For `float` and `double`, balancing is off by default, because IEEE 754 arithmetic rounds after every operation, and rounding at different points gives different answers.
Vitis therefore keeps the order written in the C source for floating-point types, so that the hardware returns exactly what C simulation returns.

Use `-off` when area matters more than latency, or when you want a chain kept so that operators can be shared.
Use the directive without `-off` rarely, because for integers it restates the default.
Use neither form to speed up a floating-point sum without reading section 9 first.

This lesson says plainly where the directive changes nothing.
For the integer half of the kernel, `on` should change nothing compared with `default`, because the default already balances integers.
For the float half, `off` changes nothing compared with `default`, because the default never balances floats.
Whether `on` changes the float half is the one open question, and the measurement answers it: **it does not**, on Vitis HLS 2023.2.

References: UG1399, [Optimizing Logic Expressions](https://docs.amd.com/r/2023.1-English/ug1399-vitis-hls/Optimizing-Logic-Expressions) and [set_directive_expression_balance](https://docs.amd.com/r/2022.2-English/ug1399-vitis-hls/set_directive_expression_balance).
The logic-expressions page names `config_compile -unsafe_math_optimizations` as the way to enable balancing for floating-point types.
The directive page says only that the directive enables balancing in its scope, without saying whether that reaches floats.
Section 7 settles it by measurement rather than by reading.

## 2. How it works

```mermaid
flowchart LR
  subgraph CH["Before: the chain the source writes, depth 7"]
    direction LR
    x0([x0]) --> c1(("+"))
    x1([x1]) --> c1
    c1 --> c2(("+"))
    x2([x2]) --> c2
    c2 --> c3(("+"))
    x3([x3]) --> c3
    c3 --> c4(("+"))
    x4([x4]) --> c4
    c4 --> c5(("+"))
    x5([x5]) --> c5
    c5 --> c6(("+"))
    x6([x6]) --> c6
    c6 --> c7(("+"))
    x7([x7]) --> c7
    c7 --> s1([sum])
  end
  subgraph TR["After: the balanced tree, depth 3"]
    direction LR
    y0([x0]) --> t1(("+"))
    y1([x1]) --> t1
    y2([x2]) --> t2(("+"))
    y3([x3]) --> t2
    y4([x4]) --> t3(("+"))
    y5([x5]) --> t3
    y6([x6]) --> t4(("+"))
    y7([x7]) --> t4
    t1 --> t5(("+"))
    t2 --> t5
    t3 --> t6(("+"))
    t4 --> t6
    t5 --> t7(("+"))
    t6 --> t7
    t7 --> s2([sum])
  end
```

Both graphs contain seven adders and compute the same mathematical sum.
In the chain, every adder waits for the one before it, so the result is seven additions deep.
In the tree, the four first-level adders have no dependence on each other and can all run at once, and the result is only three additions deep.
For an integer adder, depth decides how many clock states the sum spans, because Vitis fits only as many chained adders into one state as the clock budget allows.
For a floating-point adder, depth decides almost everything, because each floating-point addition is a pipelined core that takes eleven states on this part.
For floats, the tree also computes a different number, because the partial sums are rounded at different points.

Two things about this picture do not survive contact with the tool, and both are measured in section 7.

The first is the depth-to-delay step.
Vitis does not build a 32-bit integer addition out of one binary adder per `+`.
It fuses two chained additions into a single three-input adder, a **ternary adder**, whose delay is 0.73 ns against 1.01 ns for one binary adder.
Three of those in series cost 2.19 ns, which is less than the per-state budget, so seven chained additions fit into two states, not four.
The depth of the *dependence graph* is 7, but the depth of the *delay path* the scheduler sees is three ternary adders.

The second is the area claim.
Sharing an operator is only possible when the operations that would share it are scheduled in different states.
When both shapes fit into the same two states, neither shares, and both build all seven additions in hardware.
The chain's advantage is then not that it needs fewer operators but that it needs cheaper ones: a ternary adder does the work of two `+` for less than the price of two binary adders.

## 3. The kernel

`src/sum8.h`:

```cpp
#ifndef SUM8_H
#define SUM8_H

void sum8(int   a0, int   a1, int   a2, int   a3,
          int   a4, int   a5, int   a6, int   a7,
          float f0, float f1, float f2, float f3,
          float f4, float f5, float f6, float f7,
          int *si, float *sf);

#endif
```

`src/sum8.cpp`:

```cpp
 1  #include "sum8.h"
 2
 3  // Two sums with the same shape, one per type. There is no loop, so there is
 4  // nothing to label; the directive's location is the function itself.
 5  void sum8(int   a0, int   a1, int   a2, int   a3,
 6            int   a4, int   a5, int   a6, int   a7,
 7            float f0, float f1, float f2, float f3,
 8            float f4, float f5, float f6, float f7,
 9            int *si, float *sf) {
10      *si = a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;
11      *sf = f0 + f1 + f2 + f3 + f4 + f5 + f6 + f7;
12  }
```

The kernel has no loop, as in lesson 3.2, so the location of every directive is the function `sum8`.
C groups `+` from left to right, so each line is a chain of seven additions exactly as drawn on the left of section 2.
The integer sum is on source line 10 and the float sum on line 11.
The integer operations therefore carry an `_ln10` suffix in the reports, as `add_ln10`, `add_ln10_1` and so on, and the write that raises `si_ap_vld` is `write_ln10`.
The float operations are **not** suffixed the same way: the front end names them `add7`, `add8`, `add9`, `add`, `add1`, `add2`, `add3`, and only the write carries the line, as `write_ln11`.
Both kinds still print the source line in brackets, which is the reliable way to tell them apart.
The balancing message itself reports the location of the *function*, `src/sum8.cpp:5`, not of either expression.

Both sums sit in one function on purpose.
One directive location then governs both expressions, so in every solution the integer and float halves see the same setting, and any difference between them comes from their type alone.

The inputs are scalars on purpose as well.
A scalar argument becomes an `ap_none` port, which is a plain input wire whose value is available in the first state.
An array argument would become an `ap_memory` port that delivers at most two words per cycle, and that staggered arrival would feed the integer chain no faster than a tree could use it, which would hide the effect this lesson measures.
Each pointer becomes an output port with an `ap_vld` strobe, which is a one-cycle valid signal that the FSM raises in the state that writes the output.
The state that raises `si_ap_vld` is how this lesson times the integer half, since the float half sets the function latency.

This is a deviation from the roster, which listed `sum8` with `off` and `default` only.
The scope rule adds `on` for directives that Vitis applies on its own, and `sum8` is a new kernel with scalar inputs rather than the array-based `sum4` of lessons 2.1 and 2.2.

The testbench `tb/sum8_tb.cpp` follows lesson 3.3.
Its reference model adds in the same left-to-right order as the source, and it compares both outputs bit for bit, using `memcpy` into `uint32_t` for the float, with no tolerance.
Before every call, it writes a poison value into both outputs, `0xDEADBEEF` for `si` and the quiet-NaN pattern `0x7FC0DEAD` for `sf`, so an output that is never written cannot pass by accident.
Directed vectors run first, followed by 1000 random vectors from the fixed seed 35, for 1006 calls in all.
It counts errors and returns non-zero if any case fails.
Random integers are drawn from $[-2^{27}, 2^{27})$, so eight of them cannot overflow a signed `int`, whose overflow is undefined behavior in C.
Random floats use magnitudes between $2^{-20}$ and $2^{20}$ with random signs, which mixes scales enough for rounding to matter and keeps clear of subnormal numbers, the tiny values below the normal range whose handling in the FPGA cores is not what this lesson is about.

| directed case      | int inputs                      | float inputs                     | chain result | adjacent-pair tree result |
| ------------------ | ------------------------------- | -------------------------------- | ------------ | ------------------------- |
| `zeros`            | all 0                           | all `+0.0f`                      | `+0.0`       | `+0.0`                    |
| `neg_zeros`        | all 0                           | all `-0.0f`                      | `-0.0`       | `-0.0`                    |
| `extremes`         | all $2^{27}-1$                  | all `1.0f`                       | `8.0`        | `8.0`                     |
| `signs`            | $+k$ and $-k$ alternating       | $+2^{k}$ and $-2^{k}$ alternating | exact        | exact                     |
| `regroup_bait`     | ascending 1 to 8                | $2^{24}$ then seven `1.0f`       | 16777216     | 16777222                  |
| `regroup_bait_rev` | descending 8 to 1               | seven `1.0f` then $2^{24}$       | 16777224     | 16777222                  |

The two `regroup_bait` cases are what detect reassociation.
In the chain, $2^{24}$ absorbs each added 1 one at a time, because the spacing between neighboring floats at $2^{24}$ is 2 and every $2^{24}+1$ is a tie that rounds back to the even neighbor.
In the tree, the ones are first added to each other, so they reach the large value as an exact 2 or 4 and survive.
The reversed case catches a tree that happens to pair the operands differently.
The expected values were checked in single precision with numpy before writing this lesson, and the run confirms them: all six directed cases pass in all three solutions, which is the evidence that no float sum was ever regrouped.

## 4. The solutions

| solution  | directives file         | contents                                     | expected change                          |
| --------- | ----------------------- | -------------------------------------------- | ---------------------------------------- |
| `off`     | `directives_off.tcl`    | `set_directive_expression_balance -off sum8` | integer sum kept as a chain              |
| `default` | `directives_default.tcl`| comment only, no directive                   | integer sum balanced, float sum untouched |
| `on`      | `directives_on.tcl`     | `set_directive_expression_balance sum8`      | the open question: does the float half move? |

All three share `common/part.tcl`, which sets the part, the 3.33 ns clock with 0.90 ns uncertainty, and `config_compile -pipeline_loops 0`.
That last setting has nothing to act on here, because the kernel has no loop.
The project sets no `config_compile -unsafe_math_optimizations`, because that is a configuration, not the directive, and it would apply to every solution.

## 5. Predict

The scheduler plans each state against about 2.431 ns, which is the 3.33 ns clock minus the 0.90 ns uncertainty.
A 32-bit integer adder costs 1.016 ns on this part, so two chained adders fit in one state (2.032 ns) and three do not (3.048 ns).
The default float adder is the 11-stage `FAddSub_fulldsp` core measured in lesson 3.3, so each dependent float addition spans eleven states, and each stage takes 2.262 ns.

That core occupies eleven states and produces its result in the last of them, so the write of `sf` shares the final state rather than needing one of its own.
For the float half, with depth $d_f$:

$$\textrm{states} = 11\,d_f, \qquad L = 11\,d_f - 1, \qquad \textrm{interval} = 11\,d_f$$

For the integer half, with depth $d_i$ and two adders per state, the state that writes `si` is:

$$S_{\textrm{si}} = \left\lceil d_i / 2 \right\rceil$$

**Prediction 1.** The float half is not balanced in any solution, so $d_f = 7$ everywhere, the design has 77 states, and the function latency is **76 cycles** in `off`, `default` and `on`, with interval 77.
If `on` does balance it, $d_f$ becomes 3, the design has 33 states and the latency falls to 32.
In that case, cosim fails on `regroup_bait`, and the failure is the evidence.

**Prediction 2.** `si` is written in **state 4** in `off` ($d_i = 7$) and in **state 2** in `default` and `on` ($d_i = 3$).

The estimated clock should be 2.262 ns, set by the float adder stage, in all three solutions, which leaves a slack of $2.431 - 2.262 = +0.169$ ns.
The integer adders never reach that figure, so the integer change is invisible in the clock as well as in the latency.

Integer half, `off`, as a schedule sketch:

| operation              | state 1 | state 2 | state 3 | state 4      |
| ---------------------- | ------- | ------- | ------- | ------------ |
| `a0 + a1`, then `+ a2` | 2 adds  |         |         |              |
| `+ a3`, then `+ a4`    |         | 2 adds  |         |              |
| `+ a5`, then `+ a6`    |         |         | 2 adds  |              |
| `+ a7`, write `si`     |         |         |         | add, `si_ap_vld` |

Integer half, `default` and `on`:

| operation                        | state 1 | state 2          |
| -------------------------------- | ------- | ---------------- |
| four first-level adds            | 4 adds  |                  |
| two second-level adds            | 2 adds  |                  |
| root add, write `si`             |         | add, `si_ap_vld` |

Float half, all three solutions if the prediction holds:

| operation     | 1 to 11 | 12 to 22 | 23 to 33 | 34 to 44 | 45 to 55 | 56 to 66 | 67 to 77    |
| ------------- | ------- | -------- | -------- | -------- | -------- | -------- | ----------- |
| `f0 + f1`     | fadd    |          |          |          |          |          |             |
| `+ f2`        |         | fadd     |          |          |          |          |             |
| `+ f3`        |         |          | fadd     |          |          |          |             |
| `+ f4`        |         |          |          | fadd     |          |          |             |
| `+ f5`        |         |          |          |          | fadd     |          |             |
| `+ f6`        |         |          |          |          |          | fadd     |             |
| `+ f7`        |         |          |          |          |          |          | fadd        |
| write `sf`    |         |          |          |          |          |          | `sf_ap_vld` in 77 |

Two assumptions in this sketch may not survive the run, and neither does.

First, Vitis can fuse two chained integer additions into one three-input adder, whose root costs only 0.731 ns, which could pack more of the chain into each state and move `off` earlier than state 4.
If that happens, the difference between the solutions shows up in the operation list rather than in the state number.

Second, whether the seven sequential float additions share one adder core or use seven is left to the Instance table.
The chain allows sharing, but it does not force it.
Note that sharing is not free either: a shared core needs a multiplexer on each operand port, and that multiplexer sits in front of the core on the same combinational path, so a shared core makes the estimated clock worse than the bare core delay.
Lesson 3.3 saw exactly that in its `tl_loose` solution, at 2.689 ns against the 2.262 ns of an unshared core.

## 6. Run

```bash
cd s3_parallelism/35_expression_balance
vitis_hls -f run_hls.tcl 2>&1 | tee run.log
bash ../../common/collect_latency.sh   sum8_proj
bash ../../common/collect_resources.sh sum8_proj
```

The solution loop in `run_hls.tcl` is:

```tcl
foreach sol {off default on} {
    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl
    csynth_design
    if {[catch {cosim_design} err]} {
        puts "COSIM FAILED in solution $sol: $err"
    }
}
```

C synthesis and co-simulation run on all three solutions.
Co-simulation, often shortened to cosim, drives the generated RTL with the C testbench and compares its outputs.
It is needed here because this directive can change behavior: integer reassociation cannot alter a result, but float reassociation can, and `on` is the solution where the tool might do it.
The `catch` exists so that a reassociating `on` reports its failure and the run still finishes, instead of the whole script stopping there.
There is no separate `csim_design` call, because `cosim_design` compiles and runs the same testbench, twice per solution.
A clean run therefore prints `TEST PASSED` exactly six times, and this run does.

The two collectors print:

```text
solution         best      worst     ii_min     ii_max   clk_est_ns
default            76         76         77         77        2.665
off                76         76         77         77        2.665
on                 76         76         77         77        2.665

solution   module          BRAM_18K    DSP       FF      LUT   URAM
default    sum8                   0      2      510      952      0
off        sum8                   0      2      510      938      0
on         sum8                   0      2      510      952      0
```

Note that both collectors sort by solution name, so the rows come out in the order `default`, `off`, `on` rather than in the order the solutions were built.
Every column is identical across the three except LUT, where `off` is 14 lower.

## 7. Read the results

### The log

```bash
grep -nE "^== solution|\[XFORM 203-11\]|\[HLS 200-(871|886|1016)\]|Estimated Fmax|TEST PASSED|COSIM FAILED" run.log
```

`XFORM 203-11` is confirmed to be the balancing message: it reads "Balancing expressions in function ..." followed by a count of balanced expressions.
The `HLS 200-871`, `200-886` and `200-1016` identifiers catch a clock violation, and none of the solutions shows one.

```text
24:== solution off
109:INFO: [HLS 200-789] **** Estimated Fmax: 375.21 MHz
122:TEST PASSED
15418:TEST PASSED
15422:== solution default
15460:INFO: [XFORM 203-11] Balancing expressions in function 'sum8' (src/sum8.cpp:5)...7 expression(s) balanced.
15506:INFO: [HLS 200-789] **** Estimated Fmax: 375.21 MHz
15519:TEST PASSED
30815:TEST PASSED
30819:== solution on
30858:INFO: [XFORM 203-11] Balancing expressions in function 'sum8' (src/sum8.cpp:5)...7 expression(s) balanced.
30904:INFO: [HLS 200-789] **** Estimated Fmax: 375.21 MHz
30917:TEST PASSED
46213:TEST PASSED
```

| solution  | `203-11` lines for `sum8` | balanced count | `TEST PASSED` lines | `COSIM FAILED` |
| --------- | ------------------------- | -------------- | ------------------- | -------------- |
| `off`     | none                      | —              | 2                   | none           |
| `default` | 1, at `src/sum8.cpp:5`    | 7              | 2                   | none           |
| `on`      | 1, at `src/sum8.cpp:5`    | 7              | 2                   | none           |

Three readings come out of this block.

The directive works: `off` suppresses the message entirely, and both other solutions print it.
The count is 7, which is the number of integer additions on line 10 and not the fourteen additions in the function, so the message is already telling us that the float sum was left alone.
And `on` prints exactly what `default` prints, which is the first sign that the explicit directive restates the default rather than extending it.

### The performance table

The first four columns come from `== Performance Estimates` in `sum8_proj/<solution>/syn/report/sum8_csynth.rpt`.
The `si` and `sf` states come from the Verilog check below, and the cosim latency comes from `sim/report/sum8_cosim.rpt`.

| solution  | est. clock (ns) | slack (ns) | latency | interval | FSM states | `si` state | `sf` state | cosim latency |
| --------- | --------------- | ---------- | ------- | -------- | ---------- | ---------- | ---------- | ------------- |
| `off`     | 2.665           | **-0.234** | 76      | 77       | 77         | **2**      | 77         | 76            |
| `default` | 2.665           | **-0.234** | 76      | 77       | 77         | 2          | 77         | 76            |
| `on`      | 2.665           | **-0.234** | 76      | 77       | 77         | 2          | 77         | 76            |

Slack is the effective delay budget minus the estimated period, as in lesson 3.3: the budget is the target minus the uncertainty, $3.330 - 0.899 = 2.431$ ns.
The estimated period of 2.665 ns corresponds to the 375.21 MHz that `run.log` reports, and it is 0.234 ns over that budget.
Vitis raises no clock-violation message, because the estimate is still comfortably under the 3.33 ns target itself; the uncertainty is a scheduling margin, not a hard limit the reporter checks.

The cosim latency confirms the synthesis estimate exactly, and the total execution time of 77461 cycles for 1006 calls is $1006 \times 77 - 1$, which is the interval repeated with no trailing cycle on the last call.

**Every row of this table is identical.**
The three solutions have the same latency, the same interval, the same number of states, and the same estimated clock, and the integer result is ready in state 2 in all three.
Prediction 1 holds and Prediction 2 fails, and the schedule says why.

### The schedule

```bash
for s in off default on; do
  echo "== $s"
  grep -nE "^ST_[0-9]+ : Operation .*(= f?add |Write)" \
       sum8_proj/$s/.autopilot/db/sum8.verbose.sched.rpt
done
```

Each line gives the state, the operation and its delay.
The integer operations, with the file paths and the trailing core description trimmed:

```text
== off
ST_1 : (1.01ns)                            %add_ln10   = add i32 %a1_read, i32 %a0_read
ST_2 : (0.00ns) (grouped into TernaryAdder) %add_ln10_1 = add i32 %add_ln10,   i32 %a2_read
ST_2 : (0.73ns) (root node of TernaryAdder) %add_ln10_2 = add i32 %add_ln10_1, i32 %a3_read
ST_2 : (0.00ns) (grouped into TernaryAdder) %add_ln10_3 = add i32 %add_ln10_2, i32 %a4_read
ST_2 : (0.73ns) (root node of TernaryAdder) %add_ln10_4 = add i32 %add_ln10_3, i32 %a5_read
ST_2 : (0.00ns) (grouped into TernaryAdder) %add_ln10_5 = add i32 %add_ln10_4, i32 %a6_read
ST_2 : (0.73ns) (root node of TernaryAdder) %add_ln10_6 = add i32 %add_ln10_5, i32 %a7_read
ST_2 : (0.00ns)                             %write_ln10 = write ... i32 %si, i32 %add_ln10_6

== default, and "on" is identical
ST_1 : (1.01ns)                             %add_ln10_4 = add i32 %a6_read, i32 %a7_read
ST_2 : (1.01ns)                             %add_ln10   = add i32 %a1_read, i32 %a0_read
ST_2 : (1.01ns)                             %add_ln10_1 = add i32 %a2_read, i32 %a3_read
ST_2 : (0.00ns) (grouped into TernaryAdder) %add_ln10_2 = add i32 %add_ln10_1, i32 %add_ln10
ST_2 : (0.00ns) (grouped into TernaryAdder) %add_ln10_3 = add i32 %a4_read,    i32 %a5_read
ST_2 : (0.73ns) (root node of TernaryAdder) %add_ln10_5 = add i32 %add_ln10_4, i32 %add_ln10_3
ST_2 : (0.73ns) (root node of TernaryAdder) %add_ln10_6 = add i32 %add_ln10_5, i32 %add_ln10_2
ST_2 : (0.00ns)                             %write_ln10 = write ... i32 %si, i32 %add_ln10_6
```

The float operations are the same in all three solutions:

```text
ST_1  to ST_11 : (2.26ns)  %add7 = fadd i32 %f0_read, i32 %f1_read     [sum8.cpp:11]
ST_12 to ST_22 : (2.26ns)  %add8 = fadd i32 %add7,    i32 %f2_read
ST_23 to ST_33 : (2.26ns)  %add9 = fadd i32 %add8,    i32 %f3_read
ST_34 to ST_44 : (2.26ns)  %add  = fadd i32 %add9,    i32 %f4_read
ST_45 to ST_55 : (2.26ns)  %add1 = fadd i32 %add,     i32 %f5_read
ST_56 to ST_66 : (2.26ns)  %add2 = fadd i32 %add1,    i32 %f6_read
ST_67 to ST_77 : (2.26ns)  %add3 = fadd i32 %add2,    i32 %f7_read
ST_77          : (0.00ns)  %write_ln11 = write ... i32 %sf, i32 %bitcast_ln11
```

Every `fadd` after the first takes the result of the one before it as its left operand and a fresh input port as its right operand.
That is line 11 exactly as written, in all three solutions.
No `fadd` anywhere takes two input ports except the first, on `f0` and `f1`, so **the float half was never regrouped, not even in `on`**.
That answers the open question of section 1: `set_directive_expression_balance` without `-off` does not reach floating-point expressions in Vitis HLS 2023.2, and `config_compile -unsafe_math_optimizations` remains the only tool-side route.

The integer half is where the directive bites, and the shape is exactly what section 2 draws.
`off` keeps the source order, `((((((a0+a1)+a2)+a3)+a4)+a5)+a6)+a7`, a chain of depth 7.
`default` and `on` build the adjacent-pair tree, `((a6+a7)+(a4+a5)) + ((a2+a3)+(a0+a1))`, a tree of depth 3.
The two halves are swapped at the root relative to the section 2 drawing, which for integers changes nothing.
Note also that `off` matches the chain of section 2 only after one operand swap: the tool emits `a1 + a0` rather than `a0 + a1`, which is a front-end canonicalisation and not balancing.

**Prediction 2 was wrong, and the reason is the first of the two assumptions in section 5.**
Vitis fuses pairs of chained additions into three-input ternary adders, and it does so in both solutions.
In `off` the seven additions become one binary adder followed by three ternary adders in series: 1.01 ns in state 1, then $3 \times 0.73 = 2.19$ ns in state 2.
In `default` the seven additions become three binary adders and two ternary adders, whose longest path is $1.01 + 0.73 = 1.74$ ns in state 2.
Both fit.
The tree's own critical path, $1.01 + 0.73 + 0.73 = 2.47$ ns, would just miss the 2.431 ns budget, which is why the tool hoists one leaf addition, `a6 + a7`, into state 1 in `default`.
`off` hoists one too, `a1 + a0`, for the same reason.
Both solutions therefore spend exactly two states on the integer sum and raise `si_ap_vld` in state 2.

The balancing was applied, it produced the tree it promised, and it bought **zero cycles**.

### The Verilog

```bash
grep -n -B1 "si_ap_vld = 1'b1;" sum8_proj/*/syn/verilog/sum8.v
grep -n -B1 "sf_ap_vld = 1'b1;" sum8_proj/*/syn/verilog/sum8.v
```

```text
sum8_proj/off/syn/verilog/sum8.v-521-    if ((1'b1 == ap_CS_fsm_state2)) begin
sum8_proj/off/syn/verilog/sum8.v:522:        si_ap_vld = 1'b1;
sum8_proj/default/syn/verilog/sum8.v-521-    if ((1'b1 == ap_CS_fsm_state2)) begin
sum8_proj/default/syn/verilog/sum8.v:522:        si_ap_vld = 1'b1;
sum8_proj/on/syn/verilog/sum8.v-521-    if ((1'b1 == ap_CS_fsm_state2)) begin
sum8_proj/on/syn/verilog/sum8.v:522:        si_ap_vld = 1'b1;

sum8_proj/off/syn/verilog/sum8.v-513-    if ((1'b1 == ap_CS_fsm_state77)) begin
sum8_proj/off/syn/verilog/sum8.v:514:        sf_ap_vld = 1'b1;
```

`ap_CS_fsm_state2` in all three, not `state4` in `off`.
`sf_ap_vld` is `ap_CS_fsm_state77` in all three, the same state in which the last `fadd` retires.

The adder structure is visible directly in the generated RTL, which is the cleanest statement of what the directive did:

```verilog
// off: the chain
assign add_ln10_fu_185_p2   = (a1 + a0);                            // state 1, registered
assign add_ln10_1_fu_191_p2 = (add_ln10_reg_242 + a2);
assign add_ln10_2_fu_196_p2 = (add_ln10_1_fu_191_p2 + a3);
assign add_ln10_3_fu_202_p2 = (add_ln10_2_fu_196_p2 + a4);
assign add_ln10_4_fu_208_p2 = (add_ln10_3_fu_202_p2 + a5);
assign add_ln10_5_fu_214_p2 = (add_ln10_4_fu_208_p2 + a6);
assign si                   = (add_ln10_5_fu_214_p2 + a7);

// default and on: the tree
assign add_ln10_4_fu_185_p2 = (a6 + a7);                            // state 1, registered
assign add_ln10_fu_191_p2   = (a1 + a0);
assign add_ln10_1_fu_197_p2 = (a2 + a3);
assign add_ln10_3_fu_209_p2 = (a4 + a5);
assign add_ln10_2_fu_203_p2 = (add_ln10_1_fu_197_p2 + add_ln10_fu_191_p2);
assign add_ln10_5_fu_215_p2 = (add_ln10_4_reg_242  + add_ln10_3_fu_209_p2);
assign si                   = (add_ln10_5_fu_215_p2 + add_ln10_2_fu_203_p2);
```

The float half is one shared core in every solution:

```verilog
sum8_fadd_32ns_32ns_32_11_full_dsp_1 ... grp_fu_168 (.din0(grp_fu_168_p0), .din1(grp_fu_168_p1), .dout(grp_fu_168_p2));
// reg_180 holds the running partial sum
// grp_fu_168_p0 selects between reg_180 and f0
// grp_fu_168_p1 selects between f1, f2, f3, f4, f5, f6, f7
assign sf = grp_fu_168_p2;
```

That multiplexer is where the 2.665 ns comes from.
The core's own delay is 2.262 ns, and the scheduler reports 2.66 ns for the state in which each `fadd` *starts*, against 2.26 ns for its remaining ten states.
The difference, 0.403 ns, is the seven-way operand multiplexer in front of the shared core.
This is the second assumption of section 5 resolved: the chain allowed sharing, the tool took it, and the price of taking it is the estimated clock.

### The resource estimate

The resource figures come from the `== Utilization Estimates` section of `sum8_csynth.rpt`.
They are C synthesis estimates, since this lesson has no `export_syn.tcl`.

| solution  | DSP | FF  | LUT     | Instance LUT | Expression LUT | Multiplexer LUT | Register FF | fadd instances |
| --------- | --- | --- | ------- | ------------ | -------------- | --------------- | ----------- | -------------- |
| `off`     | 2   | 510 | **938** | 236          | **231**        | 471             | 141         | 1              |
| `default` | 2   | 510 | **952** | 236          | **245**        | 471             | 141         | 1              |
| `on`      | 2   | 510 | **952** | 236          | **245**        | 471             | 141         | 1              |

Here DSP means the DSP48E2 slices, which are hard multiply-and-add blocks on this UltraScale+ part, LUT means the look-up tables that implement general logic, and FF means flip-flops.
The fadd instance count is the number of `sum8_fadd_32ns_32ns_32_11_full_dsp_1` instances in the Instance table, and it is **1** in every solution: the seven sequential float additions take turns on one core.

Accounting for the change from `off` to `default` line by line, as in lesson 3.3:

| table       | row name                                    | `off`                 | `default`             | delta   | what it is |
| ----------- | ------------------------------------------- | --------------------- | --------------------- | ------- | ---------- |
| Instance    | `fadd_32ns_32ns_32_11_full_dsp_1_U1`        | 2 DSP, 369 FF, 236 LUT | 2 DSP, 369 FF, 236 LUT | 0      | the one shared float adder core, untouched by the directive |
| Expression  | seven `+` rows on `add_ln10*` and `si`      | 231 LUT               | 245 LUT               | **+14** | 1 binary adder at 39 LUT plus 3 ternary adders at 64 LUT, against 3 binary plus 2 ternary |
| Multiplexer | `ap_NS_fsm`, `grp_fu_168_p0`, `grp_fu_168_p1` | 414 + 14 + 43 = 471 LUT | 414 + 14 + 43 = 471 LUT | 0   | FSM next-state decode and the shared fadd's operand selects |
| Register    | `add_ln10*_reg_242`, `ap_CS_fsm`, `reg_180` | 32 + 77 + 32 = 141 FF | 32 + 77 + 32 = 141 FF | 0       | one 32-bit state-1 spill, the 77-bit one-hot FSM, the fadd partial sum |

The whole difference between the two designs is 14 LUT in one table.

The Expression rows are worth reading closely, because they show how a ternary adder is billed.
A standalone 32-bit binary adder is one row at 39 LUT.
A fused ternary adder appears as two rows at 32 LUT each, the "grouped" operation and the "root node", for 64 LUT.
`off` has one binary adder and three ternary adders: $39 + 3 \times 64 = 231$.
`default` has three binary adders and two ternary adders: $3 \times 39 + 2 \times 64 = 245$.
The delta is $2 \times 39 - 64 = +14$ LUT, which is the cost of trading one ternary adder for two binary ones.

The register table is the surprise.
The chain was expected to carry more partial sums across state boundaries than the tree, but both carry exactly one 32-bit value from state 1 into state 2: `add_ln10_reg_242` holding `a0 + a1` in `off`, and `add_ln10_4_reg_242` holding `a6 + a7` in `default`.
Both designs split the integer sum the same way, so both pay the same one register.
The FSM does not change size either, at 77 one-hot bits, because the float half sets the state count in every solution.

### The normalised diff

```bash
norm() { sed -E 's/_(fu|reg)_[0-9]+/_\1_N/g' "$1"; }
diff <(norm sum8_proj/default/syn/verilog/sum8.v) \
     <(norm sum8_proj/on/syn/verilog/sum8.v) | wc -l
```

| comparison              | raw diff lines | normalised diff lines |
| ----------------------- | -------------- | --------------------- |
| `default` against `on`  | **0**          | **0**                 |
| `off` against `default` | 54             | 46                    |

`default` and `on` are not merely equivalent after normalisation, they are byte-identical, so the normalisation was not even needed.
`set_directive_expression_balance sum8` produced exactly the file the tool produces with no directive at all.

The 46 normalised lines between `off` and `default` are the seven `assign` statements above, the two renamed wires and their register, and one line of the `CORE_GENERATION_INFO` attribute, which records `HLS_SYN_LUT=938` against `HLS_SYN_LUT=952` and is otherwise the same, down to `HLS_SYN_CLOCK=2.665200` and `HLS_SYN_LAT=76`.

### Predicted and measured

| quantity                            | predicted           | `off`        | `default`    | `on`         |
| ----------------------------------- | ------------------- | ------------ | ------------ | ------------ |
| function latency                    | 76, 76, 76          | 76 ✓         | 76 ✓         | 76 ✓         |
| interval                            | 77, 77, 77          | 77 ✓         | 77 ✓         | 77 ✓         |
| estimated clock (ns)                | 2.262 in all three  | **2.665 ✗**  | **2.665 ✗**  | **2.665 ✗**  |
| slack (ns)                          | +0.169 in all three | **-0.234 ✗** | **-0.234 ✗** | **-0.234 ✗** |
| `si` state                          | 4, 2, 2             | **2 ✗**      | 2 ✓          | 2 ✓          |
| `sf` state                          | 77 in all three     | 77 ✓         | 77 ✓         | 77 ✓         |
| `TEST PASSED` lines                 | 2 in each           | 2 ✓          | 2 ✓          | 2 ✓          |
| normalised diff, `default` and `on` | 0                   | —            | 0 ✓          | 0 ✓          |
| fadd instances                      | not predicted       | 1            | 1            | 1            |
| total LUT                           | not predicted       | 938          | 952          | 952          |

Three of the ten rows miss, and the two reasons behind them are the two assumptions section 5 flagged.

**The clock and the slack miss because the float adder is shared.**
A shared core needs an operand multiplexer, the multiplexer is combinational and in series with the core, and the scheduler charges the whole 2.665 ns to the state in which each `fadd` begins.
The prediction of 2.262 ns was the cost of an *unshared* core.
Lesson 3.3 measured the same effect from the other direction: there, `tl_loose` shared an adder and paid 2.689 ns, while the solutions that did not share stayed at 2.262 ns.

**The `si` state misses because of ternary-adder fusion**, which makes the chain three delay levels deep rather than seven, so it needs two states and not four.
This is the more important miss, because it removes the entire reason for using the directive on this kernel.

## 8. Hardware implications

The headline result is a null result, and it is the kind worth keeping.
`EXPRESSION_BALANCE` did exactly what it promises, on the expression it is meant to act on, and the design did not get faster by a single cycle.
It got 14 LUT larger.

Three separate effects conspire to produce that.

**The float half sets the latency, and the directive cannot touch it.**
Seven dependent 11-state additions are 77 states, and the two integer states hide entirely underneath them.
Even a tenfold speedup of the integer sum would be invisible in the function latency, because `sf` is not ready until state 77 and `ap_done` waits for it.
Only `si_ap_vld`, in state 2, times the integer half at all, and a consumer that watches `si_ap_vld` rather than `ap_done` is the only consumer that could ever notice.

**Ternary-adder fusion had already shortened the chain.**
This is the general lesson and it outlives this kernel.
Reassociation reduces depth from $n-1$ to $\lceil \log_2 n \rceil$ *in the dependence graph*, but the scheduler does not count graph depth, it counts nanoseconds.
Vitis maps two chained `+` onto one three-input adder at 0.73 ns, so a chain of $n$ additions is about $n/2$ ternary-adder delays, not $n$ binary-adder delays.
At $n = 8$, three ternary adders at 2.19 ns fit inside one 2.431 ns state, and the balanced tree's 1.74 ns fits inside the same one.
The tree only starts winning states once the chain grows long enough that $n/2$ ternary delays overflow a state, which on this part and this clock means well past eight operands.
Below that, balancing is pure cost.

**Sharing did not happen for the integers in either solution.**
UG1399's warning that balancing "prohibits sharing" is about operations that the scheduler would otherwise have placed in different states.
Here the chain and the tree both land in two states, so all seven integer additions exist simultaneously in both, and the Expression table charges for seven in both.
What changed was not the *number* of operators but their *kind*: `off` gets 1 binary and 3 ternary adders, `default` gets 3 binary and 2 ternary.
A ternary adder does the work of two `+` for 64 LUT, while two binary adders cost 78, so the chain is cheaper by 14 LUT.
That is the whole area delta, and it is the mirror image of the textbook story: the chain is smaller here not because it shares, but because it fuses.

The float half, by contrast, did share, and its Instance table shows one core for seven additions.
That sharing is what makes the estimated clock 2.665 ns instead of 2.262 ns, so it is not free either: the design pays 0.403 ns of multiplexer to save six copies of a 2-DSP, 369-FF, 236-LUT core.
On this kernel that is obviously the right trade, and the tool made it without being asked.

Had `on` balanced the float half, the picture would have changed completely: four float additions would become simultaneous in the first eleven states, which needs at least four adder cores at 2 DSP each, so DSP would have gone from 2 to at least 8, and the latency would have fallen from 76 to 32.
The number the circuit returns would also have changed, which is why cosim is part of this lesson.
None of that happened, and the six `TEST PASSED` lines are the proof that none of it happened.

The decision to balance is taken before any RTL exists, so the adder tree, the state boundaries and the registers carry over unchanged to a standard-cell ASIC flow.
Only part of this analysis is specific to the FPGA, though.
Within a single state, an ASIC logic synthesizer such as Design Compiler or Genus rebuilds a multi-operand integer sum on its own, typically as a carry-save tree, so a chain that stays inside one state would be balanced again downstream; and since both shapes here stay inside two states, the 14 LUT difference is exactly the kind of difference an ASIC synthesizer would erase.
Across state boundaries, logic synthesis cannot help, because it does not move registers between FSM states, so a saving of integer states would be real in both flows — there just is not one to save here.
The 1.016 ns binary and 0.731 ns ternary adder delays that decide how many additions fit in a state reflect the FPGA carry chain and its dedicated `CARRY8` blocks, so an ASIC library would pack the states differently and could well move the crossover point at which balancing starts to pay.
The float cores and their DSP slices are FPGA-only and would become a library floating-point adder in an ASIC.
The rule that float reassociation changes results comes from IEEE 754 arithmetic, not from the technology, so it carries over unchanged.

The practical rule: **do not reach for `EXPRESSION_BALANCE` to make an integer expression faster, because the tool has already balanced it and has other ways to shorten it besides.**
The useful form of the directive is `-off`, on a design where the operators are large enough that keeping them sequential lets the scheduler share them.
The form without `-off` restates a default and, as measured here, is a no-op on the generated RTL down to the byte.

## 9. One common mistake and one question

**The mistake: expecting the directive to speed up a rolled accumulation loop.**
Lesson 3.3's `acc` loop computes `sum += x[i]`, and it looks like a long chain of additions.
Expression balancing works on an expression inside one scope, however, and a rolled loop contains a single addition whose other operand is last iteration's result held in a register.
There is no expression of eight terms to regroup, so the directive has nothing to act on until the loop is unrolled, which is lesson 3.1.
For a `float` sum, even the unrolled expression stays a chain, for the reason this lesson measures.

A second mistake worth naming, since this lesson ran into it: **expecting the state count to follow the depth of the dependence graph.**
It follows the delay of the longest path, and on an integer sum the tool halves that path with ternary adders before the scheduler ever sees it.

**The question.**
You want the float half of `sum8` to become a tree, and you also want cosim to stay bit-exact against C simulation.
What do you change, and why does neither the directive nor `config_compile -unsafe_math_optimizations` meet the second condition?

<details>
<summary>Answer</summary>

Rewrite line 11 as the tree itself:

```cpp
*sf = ((f0 + f1) + (f2 + f3)) + ((f4 + f5) + (f6 + f7));
```

The C source now specifies the tree, so C simulation computes the tree, and Vitis keeps the written order for floats, so the RTL computes the same tree.
The two agree bit for bit, and the design drops from 77 states to 33, so the latency falls from 76 to 32 cycles.
The testbench's reference model has to change with it, and `regroup_bait` then expects 16777222 instead of 16777216, because the tree is a different computation with a different correctly rounded answer.

Expect the area to move as well.
The tree's four first-level additions are simultaneous, so the one shared `fadd` core of section 7 becomes several, and the 2 DSP of every solution here becomes at least 8.
That is the trade this lesson never got to make on the float side: real cycles for real DSP slices.

Any tool-driven reassociation, whether from the directive or from `-unsafe_math_optimizations`, changes the hardware while leaving the C chain as the reference, so a bit-exact testbench fails on `regroup_bait`.
The directive turns out not to offer the option at all — section 7 shows `on` leaving line 11 untouched — so `-unsafe_math_optimizations` is the only tool-side route, and it applies to every function in the solution rather than one scope, which is a second reason this lesson does not use it.
The only reassociation of floats that stays bit-exact against C simulation is one written in the C source.

</details>
