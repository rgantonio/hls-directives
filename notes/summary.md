# Every directive on one page

One entry per lesson: what the directive does, the figure that shows what changed, and what you gain against what it costs.
Every number comes from the measured tables in the lesson READMEs, on `xcku5p-ffvb676-2-e` at 3.33 ns under Vitis HLS 2023.2.2.
Where a lesson reports both, **Vivado** numbers are marked as such; everything else is C synthesis.

A state in these schedules may use about **2.43 ns** (3.33 ns clock minus 0.90 ns of uncertainty). That budget decides more results here than any directive does.

## At a glance

| Directive | You gain | You pay | Free lunch? |
| --- | --- | --- | --- |
| 0.1 TOP | a module name, or a smaller thing to measure | nothing | n/a — it builds no hardware |
| 1.1 PIPELINE | throughput and latency, 18 cycles against 33 | +11 LUT of pipeline control, 0 FF | nearly |
| 1.2 LOOP_TRIPCOUNT | a readable report instead of `?` | nothing in hardware; a wrong number reads as fact | yes, and that is the risk |
| 1.3 LOOP_FLATTEN | control cycles per outer iteration | a wrap mux in front of the address — here **+48 cycles** | **no, it lost** |
| 1.4 LOOP_MERGE | latency, 33 against 66 | nothing here; contention if both bodies share a port | **yes, both axes** |
| 1.5 DEPENDENCE | II 2 → 1, 87 cycles against 102 | **correctness**, if the promise is wrong | no |
| 2.1 ARRAY_PARTITION | memory bandwidth, and through it cycles | ports, wiring, and a mux when the bank is run-time | yes, if the type matches the pattern |
| 2.2 ARRAY_RESHAPE | the same bandwidth through one wide port | a barrel shifter when the slice is run-time — **in cycles** | yes, if the slice is a constant |
| 2.3 BIND_STORAGE | a resource column, or clock headroom | a slower read the scheduler believes — **16 cycles** | no |
| 3.1 UNROLL | cycles, if the operands can arrive together | area, and multiplexing when they cannot | no |
| 3.2 LATENCY (`-min`) | a predictable `ap_done` | 1 FF per added state, nothing in the datapath | cheap, but buys no speed |
| 3.2 LATENCY (`-max`) | a shorter schedule, when one exists | **the clock**, reported as a warning, exit status 0 | no |
| 3.3 PERFORMANCE | a target that survives a change of type, clock or part | control: it may re-bind, over-pipeline, or silently refuse | no |
| 3.5 EXPRESSION_BALANCE | depth, 1 cycle against 5 | registers for the live partials, +188 FF | no |
| 4.1 BIND_OP | DSP slices, or clock headroom | LUTs, cycles, or the clock, depending on the option | no |
| 4.2 ALLOCATION | hard resources, 3 DSP against 9 | a mux per shared input, and possibly cycles | **yes here — it also saved FF and LUT** |
| 4.3 INLINE | a schedule that crosses the boundary, 33 against 49 | one copy of the callee per call site, and a lost module | yes for small callees |
| 5.1 INTERFACE | whatever the surrounding system can actually provide | adapters, and with `m_axi` the latency of a bus | no |
| 5.2 AGGREGATE / DISAGGREGATE | an exact port layout at the boundary | width (padding) or port count, never cycles here | yes, in cycles |
| 5.3 RESET | state that restarts without reprogramming | 0 for a scalar; a ROM and a written-bit vector for an array | nearly |
| 6.1 DATAFLOW | latency **and** interval, 51/50 against 66/67 | one controller per process, +14 LUT, +39 FF | yes here |
| 6.2 STREAM | a channel sized to the slack the producer needs | a PIPO serialises the call, 115 cycles against 83 | no |

---

## 0.1 TOP — `s0_setup/01_top`

**What it does.** Names the one function synthesis starts from. Its arguments become the ports of the generated module, everything it can reach becomes hardware, and everything it cannot — including `main` and the testbench — is compiled for simulation only. `set_directive_top -name` changes only the module's name.

**Figure.**

```text
  top = vadd                                  top = vadd_core
  +-- synthesis boundary -----------+         +-- synthesis boundary --+
  |  vadd()  SCALE_LOOP, t[16], k   |         |  vadd_core()  CORE_LOOP |
  |    +-- vadd_core()  CORE_LOOP   |         +-------------------------+
  +---------------------------------+                   ^
             ^                                          |
   main(), ref_vadd()  = software              main(), vadd(), ref_vadd() = software

  66 cycles, 17 ports, 57 FF, 199 LUT        33 cycles, 16 ports, 13 FF, 93 LUT
```

An array argument does not become a memory inside the block. It becomes address, enable and data pins that expect a RAM outside, meeting the one-cycle read latency the schedule assumes.

**Gain:** a module name that will not collide, or a smaller boundary to characterise on its own.
**Cost:** nothing. `base` and `rename` are bit-for-bit the same design at 66 cycles, 57 FF and 199 LUT. The `sub` solution is smaller only because a smaller piece of the program was built — the `+ k` still has to happen somewhere.

---

## 1.1 PIPELINE — `s1_loops/11_pipeline`

**What it does.** Lets iteration $i+1$ start before iteration $i$ has finished. With depth $D$ and initiation interval II, a loop of $N$ iterations takes $D + \textrm{II}\,(N-1)$ cycles instead of $N \cdot D$.

**Figure.** One iteration of `y[i] = a[i] + b[i]` is RD (drive addresses) then AW (data arrives, add, write), so $D = 2$.

Before — no overlap:

| Iteration | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | -- | -- | -- | -- | -- | -- | -- | -- |
| i = 0 | RD | AW | | | | | | |
| i = 1 | | | RD | AW | | | | |
| i = 2 | | | | | RD | AW | | |
| i = 3 | | | | | | | RD | AW |
| **adder in use** | | x | | x | | x | | x |

After, II = 1 — a new iteration every cycle:

| Iteration | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | -- | -- | -- | -- | -- | -- | -- | -- |
| i = 0 | RD | AW | | | | | | |
| i = 1 | | RD | AW | | | | | |
| i = 2 | | | RD | AW | | | | |
| i = 3 | | | | RD | AW | | | |
| i = 4 | | | | | RD | AW | | |
| i = 5 | | | | | | RD | AW | |
| i = 6 | | | | | | | RD | AW |
| **adder in use** | | x | x | x | x | x | x | x |

Same one adder, same one port per array. What appeared is one valid bit per stage (`ap_enable_reg_pp0_iter1`) and a loop handshake helper.

**Gain:** 18 cycles against 33, a saving of exactly $(D - \textrm{II})(N-1) = 15$.
**Cost:** +11 LUT of pipeline control, and **0 FF** — the two new bits are paid for by the state register shrinking from three bits to one.
**The trap:** II = 2 on a depth-2 loop buys nothing at all (34 cycles against 33) and still pays for the handshake. Pipelining saves $D - \textrm{II}$ per iteration, so it is worth nothing when $\textrm{II} = D$.

---

## 1.2 LOOP_TRIPCOUNT — `s1_loops/12_loop_tripcount`

**What it does.** Tells the latency *estimator* how many times a loop with a run-time bound is expected to run. It is the only directive here that builds no hardware at all.

**Figure.**

```text
                   +--> RTL        counter, comparator against port n,
                   |               adder, FSM   -- IDENTICAL in both solutions
  vadd.cpp ---> scheduler
                   |
                   +--> latency estimate
                              ^
                              |
      LOOP_TRIPCOUNT ---------+      -min 1  -max 16  -avg 8
      the arrow ends at the estimate and never reaches the RTL

  base:  loop latency  ?      function  ?        <- the ? spreads upward
  tc:    loop latency  2..32  function  3..33
```

Normalizing the tool's signal-name suffixes and diffing the two `vadd.v` files prints `identical`.

**Gain:** a report you can compare. Two solutions that both print `?` cannot be compared at all.
**Cost:** zero flip-flops, zero LUTs, zero cycles. The real cost is a risk: the tool never checks the numbers against the code, so a wrong trip count produces a report that looks precise and is simply wrong. The `-max 16` appears nowhere in the hardware — the counter is 5 bits because `x` has 16 elements, and the comparator is 32 bits because `n` is an `int`.

---

## 1.3 LOOP_FLATTEN — `s1_loops/13_loop_flatten`

**What it does.** Replaces a perfect or semi-perfect loop nest with one loop over every combination of the indices, so the controller never leaves one loop and enters another.

**Figure.** One row of a 3-column nest, written as FSM states:

```text
  nested:      H  R A W   R A W   R A W   R       = 1 + 3*3 + 1 = 11 cycles/row
  flattened:      C R A W   C R A W   C R A W     =     3*4     = 12 cycles/row

  H = row header      C = flat header: test, wrap mux, address
  R = read   A = add   W = write

  why the header can no longer share a state with the read:

  nested      j --> address adder --> RAM                  0.78 + 1.24 = 2.0 ns   fits in 2.43
  flattened   j --> (j==8) --> select --> adder --> RAM    0.80+0.28+0.78+1.24 = 3.1 ns   does not
```

Flattening removes the two per-row control states, exactly as promised — and then the wrap multiplexer in front of the address pushes every iteration from 3 states to 4.

**Gain:** on this 8×8 nest, nothing. The nest is 209 cycles and the flattened loop is **257**.
**Cost:** +2 FF, +34 LUT, and +48 cycles.
**When it is actually worth it:** on a nest whose inner loop is pipelined, where a flat loop keeps one pipeline running across all rows instead of draining and refilling it every row. Vitis flattens eligible nests on its own as part of pipelining, which is why the useful form of this directive is `-off`. With `config_compile -pipeline_loops 0` the tool does not flatten by itself, so `default` and `off` are the same hardware.

---

## 1.4 LOOP_MERGE — `s1_loops/14_loop_merge`

**What it does.** Combines consecutive loops inside a region into one loop, so the second loop's iterations stop waiting for the whole of the first.

**Figure.** Trip count 3. `R` issues the reads, `W` computes and writes, `X` is a loop's final exit test.

| Operation | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |
| --- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- |
| add i=0 | R | W | | | | | | | | | | | | |
| add i=1 | | | R | W | | | | | | | | | | |
| add i=2 | | | | | R | W | | | | | | | | |
| add exit | | | | | | | X | | | | | | | |
| sub i=0 | | | | | | | | R | W | | | | | |
| sub i=1 | | | | | | | | | | R | W | | | |
| sub i=2 | | | | | | | | | | | | R | W | |
| sub exit | | | | | | | | | | | | | | X |

| Operation | 0 | 1 | 2 | 3 | 4 | 5 | 6 |
| --- | -- | -- | -- | -- | -- | -- | -- |
| add i=0 | R | W | | | | | |
| **sub i=0** | **R** | **W** | | | | | |
| add i=1 | | | R | W | | | |
| **sub i=1** | | | **R** | **W** | | | |
| add i=2 | | | | | R | W | |
| **sub i=2** | | | | | **R** | **W** | |
| exit | | | | | | | X |

14 cycles become 7. The subtraction for `i = 0` needed nothing the addition produced, and only the loop structure was making it wait until cycle 7.

**Gain:** 33 cycles against 66 — *and* 132 LUT against 205, 13 FF against 25. One loop counter, one exit comparator and one group of FSM states disappear, and both bodies read `a[i]` and `b[i]` in the same cycle so the two reads become one.
**Cost:** nothing on this kernel. The real cost appears when the two bodies need the same single memory port in the same cycle — then the merged iteration grows and part of the saving goes back. Merging also removes the separate loop rows from the report, so each original loop is harder to inspect on its own.

---

## 1.5 DEPENDENCE — `s1_loops/15_dependence`

**What it does.** Overrules what the scheduler assumed about memory dependences it could not prove. In a histogram, iteration $i$ updates `acc[x[i]]` and nothing says whether `x[i+1]` equals `x[i]`, so the tool assumes it might and spreads the iterations apart.

**Figure.** The iteration reads `acc` at stage 1 and writes it at stage 3, a gap of $g = 2$ cycles. `X` reads `x[i]`, `R` sends the bin to `acc`, `+` adds, `W` writes back, `!` marks a read that is already stale.

`base`, II = 2 — the dependence honoured:

| Iteration | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | -- | -- | -- | -- | -- | -- | -- | -- |
| i=0 | X | R | + | W | | | | |
| i=1 | | | X | R | + | W | | |
| i=2 | | | | | X | R | + | W |

`false_dep`, II = 1 — the dependence denied:

| Iteration | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | -- | -- | -- | -- | -- | -- | -- | -- |
| i=0 | X | R | + | W | | | | |
| i=1 | | X | **R!** | + | W | | | |
| i=2 | | | X | **R!** | + | W | | |

In `base` the tool builds a bypass — a register pair holding the previous iteration's bin and count, a comparator and a mux — which covers exactly one in-flight iteration. At II 1 there are two, and the directive has just told the tool not to bother building the bypass at all.

**Gain:** II 2 → 1, loop 20 cycles against 35, function 87 against 102, and 313 LUT against 449.
**Cost:** **correctness.** `false_dep` fails co-simulation: sixteen identical samples come back as a count of 6 instead of 16. `dist2` copies the `distance = 2` out of the tool's own II Violation message, gains no II whatsoever, and still returns 8 instead of 16 — it pays the full II 2 and is wrong anyway.
**Use it** only when two iterations provably cannot touch the same element. Vitis does not check the claim.

---

## 2.1 ARRAY_PARTITION — `s2_arrays/21_array_partition`

**What it does.** Splits one array into several banks, each its own memory with its own ports. A single memory offers at most two ports; partitioning multiplies them, so more elements can be reached in one cycle.

**Figure.** `sum4` reads four neighbouring elements per iteration. Where element $k$ lands with factor 4 — the elements iteration `i = 1` reads are in bold:

**cyclic** — bank $= k \bmod F$, address $= \lfloor k/F \rfloor$

| Bank | addr 0 | addr 1 | addr 2 | addr 3 |
| --- | --- | --- | --- | --- |
| `x_0` | x[0] | **x[4]** | x[8] | x[12] |
| `x_1` | x[1] | **x[5]** | x[9] | x[13] |
| `x_2` | x[2] | **x[6]** | x[10] | x[14] |
| `x_3` | x[3] | **x[7]** | x[11] | x[15] |

**block** — bank $= \lfloor k/S \rfloor$, address $= k \bmod S$

| Bank | addr 0 | addr 1 | addr 2 | addr 3 |
| --- | --- | --- | --- | --- |
| `x_0` | x[0] | x[1] | x[2] | x[3] |
| `x_1` | **x[4]** | **x[5]** | **x[6]** | **x[7]** |
| `x_2` | x[8] | x[9] | x[10] | x[11] |
| `x_3` | x[12] | x[13] | x[14] | x[15] |

```text
  base        x = one memory, 2 ports  -->  4 reads take 2 states
  cyclic4     bank = j (a constant), address = i     four reads, four banks, no mux
  block4      bank = i (run-time!)     every read goes to all four banks + a mux,
                                       and then the addresses are constants, so
                                       16 reads hoist out of the loop entirely
```

**Gain:** `cyclic4` is **13 cycles against 17 and 160 LUT against 205** — faster and smaller at once, because the bank number is a compile-time constant and no address arithmetic is left.
**Cost:** it is entirely a question of whether the type matches the access pattern. `block4` reaches 11 cycles and pays **555 FF and 357 LUT** for it; `complete` reaches 9 cycles with 41 FF but turns a top-level array into 16 separate 32-bit ports that the surrounding system must drive.

| | base | cyclic4 | block4 | complete |
| --- | --- | --- | --- | --- |
| `x` data ports | 2 | 4 | 8 | 16 |
| function latency | 17 | **13** | **11** | **9** |
| FF | 109 | **42** | 555 | 41 |
| LUT | 205 | **160** | 357 | 234 |

---

## 2.2 ARRAY_RESHAPE — `s2_arrays/22_array_reshape`

**What it does.** The partitioning of 2.1 followed by one more step: the banks are placed *side by side in one memory* instead of being kept as separate memories. A bank number becomes a **slice** number inside a wide word. It does not add ports; it makes each port wider.

**Figure.** Same kernel, factor 4. Rows are word addresses, columns are slices, highest bits on the left:

**cyclic** — slice $= k \bmod F$, address $= \lfloor k/F \rfloor$

| Address | slice 3 (127:96) | slice 2 (95:64) | slice 1 (63:32) | slice 0 (31:0) |
| --- | --- | --- | --- | --- |
| 0 | x[3] | x[2] | x[1] | x[0] |
| 1 | **x[7]** | **x[6]** | **x[5]** | **x[4]** |
| 2 | x[11] | x[10] | x[9] | x[8] |
| 3 | x[15] | x[14] | x[13] | x[12] |

**block** — slice $= \lfloor k/S \rfloor$, address $= k \bmod S$

| Address | slice 3 | slice 2 | slice 1 | slice 0 |
| --- | --- | --- | --- | --- |
| 0 | x[12] | x[8] | **x[4]** | x[0] |
| 1 | x[13] | x[9] | **x[5]** | x[1] |
| 2 | x[14] | x[10] | **x[6]** | x[2] |
| 3 | x[15] | x[11] | **x[7]** | x[3] |

```text
  2.1  run-time BANK number  -->  32-bit 4-input multiplexer over separate signals
  2.2  run-time SLICE number -->  word >> (32 * slice), a shifter as wide as the WORD

  Vitis costs that shifter at 1.880 ns and 2171 LUT for one 32-bit field of a 512-bit word.
  Vivado builds the whole complete design in 227 LUT. The area figure was harmless.
  The DELAY figure was not: the scheduler had already spent a cycle on it.
```

**Gain:** with `cyclic`, the same bandwidth as partitioning through **one** memory and one address path: 13 cycles against 17, 160 LUT against 205, identical to 2.1's `cyclic4`. Fewer block RAMs than several small banks would occupy.
**Cost:** a data path as wide as the word, and — when the slice number is only known at run time — a barrel shifter. **`complete` takes 13 cycles where the partitioned equivalent of 2.1 takes 9**, and no downstream tool gives those four cycles back.

> **The real price of a run-time slice is cycles, and the resource column is where you will not find it.** C synthesis reports 8878 LUT for `complete`; Vivado builds it in 227. The number that was right all along was the latency.

**Use it instead of `ARRAY_PARTITION`** when the elements needed together land at the same address *and* each sits in a slice whose number is a compile-time constant. The second condition is the one 2.1 does not have.

---

## 2.3 BIND_STORAGE — `s2_arrays/23_bind_storage`

**What it does.** Picks what a local array's memory is made of (`-impl`), what kind of memory it is (`-type`), and how many cycles pass between address and data (`-latency`).

**Figure.**

```text
  data_t a_buf[16]      16 x 32 bits = 512 bits
        |
        +-- -impl BRAM    --> RAMB18: 18 Kb hard block, 3% used, registered read
        |                     scheduler charges the read 1.237 ns
        +-- -impl LUTRAM  --> LUTs as RAM + 32 FF, asynchronous read
        |                     scheduler charges the read 0.677 ns
        +-- -impl BRAM -latency 2 --> RAMB18 plus its own output register
```

The read port, cycle by cycle from the address cycle:

| Signal | cycle 0 | cycle 1 | cycle 2 |
| --- | --- | --- | --- |
| `a_buf_address0` | i | any | any |
| `a_buf_ce0`, latency 1 | 1 | 0 | 0 |
| `a_buf_q0`, latency 1 | old | **a_buf[i]** | a_buf[i] |
| `a_buf_ce0`, latency 2 | 1 | 1 | 1 |
| `a_buf_q0`, latency 2 | old | old | **a_buf[i]** |

**Gain:** the resource trade is real. Moving the array into block RAM took the design from **85 LUT and 55 FF to 51 and 24** after Vivado synthesis, freeing fabric at the price of one 18 Kb block of which 3 % is used.
**Cost:** **16 cycles per call**, 82 against 66. That 0.56 ns difference in the read delay alone pushed `ADD_LOOP` from two states to three. The cost came from `-impl`, not from `-latency`.

> **`-impl` is not only a resource knob. It changes the delay the scheduler assumes, and a delay change can cost cycles that no later tool gives back.**

**Two things that did not happen.** `-latency 2` cost **no cycles at all** (82 against 82) — the extra cycle went into a state the body already had. And the 32 FF it appears to save are not real: after Vivado synthesis `bram` and `bram_lat2` are the same circuit, because Vivado moves a register sitting behind a block RAM into the block's built-in output register whether or not anyone asked. C synthesis put `base` and `bram` within two LUTs of each other; Vivado put them 34 apart.

| | base | bram | lutram | bram_lat2 |
| --- | --- | --- | --- | --- |
| `ADD_LOOP` iteration latency | 2 | **3** | 2 | **3** |
| function latency | **66** | 82 | **66** | 82 |
| BRAM_18K | 0 | 1 | 0 | 1 |
| Vivado LUT / FF | 85 / 55 | **51 / 24** | 85 / 55 | **51 / 24** |

The tool's own default (`base`) was tied for the fewest cycles and used no block RAM.

---

## 3.1 UNROLL — `s3_parallelism/31_unroll`

**What it does.** Makes $F$ copies of the loop body so several iterations exist as separate hardware, and divides the trip count by $F$.

**Figure.** `R` issues a read, `D` is the cycle its data is available, `A` adds, `W` writes.

Rolled — one pass per element, 2 states:

| Operation | 0 | 1 |
| --- | -- | -- |
| read `a[i]`, `b[i]` | R | D |
| add | | A |
| write `y[i]` | | W |

Unrolled by 4 on the same memories — one pass per four elements, **3 states, not 2**:

| Operation | 0 | 1 | 2 |
| --- | -- | -- | -- |
| read `a[i]`, `a[i+1]`, `b[i]`, `b[i+1]` | R | D | |
| add lanes 0 and 1 | | A | |
| write `y[i]`, `y[i+1]` | | W | |
| read `a[i+2]`, `a[i+3]`, `b[i+2]`, `b[i+3]` | | R | D |
| add lanes 2 and 3 | | | A |
| write `y[i+2]`, `y[i+3]` | | | W |

```text
  base             1 lane  -> 1 adder
  factor4          4 lanes -> 2 ADDERS.  Lanes 2 and 3 run in a state lanes 0 and 1
                   have finished with, so the scheduler reuses their adders.
                   The factor is paid for in PORT MULTIPLEXING (84 of its 221 LUT).
  factor4_cyclic4  4 lanes -> 4 adders.  One bank per lane, all four reads in state 0.
```

> **`UNROLL` multiplies the compute and does nothing whatsoever to the memory bandwidth.** An `ap_memory` argument offers two ports. Four adders that all want an element of `a` in the same cycle cannot be fed — they get built, paid for, and left idle half the time. This is memory port starvation.

**Gain:** cycles, when the operands can actually arrive together. 17 cycles at factor 2, 13 at factor 4, **9** at factor 4 with matching `cyclic` banks.
**Cost:** area, in proportion to the copies that really run in the same cycle. Measured as cycles bought per LUT spent:

| | cycles saved | LUT added | cycles per LUT |
| --- | --- | --- | --- |
| `factor2` | 16 | 30 | **0.53** |
| `factor4` | 20 | 128 | 0.16 |
| `factor4_cyclic4` | 24 | 104 | 0.23 |

Doubling the factor from 2 to 4 on the same memories bought four cycles and spent 98 LUT, almost none of it arithmetic. **A factor matching the accesses available per cycle — 2 here — is often the whole of the available benefit**, unless you partition as well.

---

## 3.2 LATENCY — `s3_parallelism/32_latency`

**What it does.** Puts a lower bound, an upper bound, or both, on the cycles a scope may take. It is a **constraint**, not a transformation: it says what result would be acceptable and leaves the tool to find one.

| Case | What the tool does |
| --- | --- |
| `-max` above the natural latency | nothing; met on arrival |
| `-max` **below** the natural latency | compresses the schedule, re-binds operators, and **breaks the target clock to get there** — warning, not error |
| `-min` below the natural latency | nothing; met on arrival |
| `-min` above the natural latency | keeps the schedule and appends idle states |

**Figure.** `poly` computes `a*x*x + b*x + c`. `X` = multiplier busy, `A` = add, `W` = write, `.` = the design doing nothing.

```text
  base and min4          1  2  3  4  5
  MUL_AX  a*x            X  X
  MUL_Q   (a*x)*x              X  X
  MUL_B   b*x                  X  X
  ADD                                A
  write y                            W
                         5 states, latency 4, clock 2.365 ns, slack +0.06

  min16                  1  2  3  4  5   6..16  17
  ... identical ...      X  X  X  X  A
  write y                            W
  idle                                   . . .   .
                         17 states, latency 16, SAME datapath, same clock

  max1                   1  2
  MUL_AX rebound to a COMBINATIONAL LUT multiplier, chained with half of MUL_Q
                         one state costs 3.479 + 2.365 = 5.844 ns
                         against a 2.431 ns budget  -->  171 MHz on a 300 MHz clock
```

**`-min` gain:** predictability, not speed. A scope whose latency is pinned produces `ap_done` at a time the rest of the system can rely on — which matters for `DATAFLOW` branches staying in step, for external protocols, and for cycle-counting reference models.
**`-min` cost:** the cycles it adds, plus **one flip-flop per added state** in the one-hot FSM and a little next-state logic. `min16` measured +12 FF and +58 LUT, nothing in the datapath. A `-min` at or below the natural latency is byte-identical to `base`.

**`-max` gain:** a shorter schedule, when a shorter schedule exists at the target clock.
**`-max` cost:** **the clock.** `max1` reached latency 1 and a timing slack of **−3.41 ns**, and `vitis_hls` still exited 0. Its real cost is attention.

> The scheduler already produces the shortest schedule it can find at the target clock. Asking for something shorter does not give it a new capability — it tells it the clock is now negotiable.

Use `-max` as a build-time assertion on a latency you have already measured, **together with a check on the log**.

---

## 3.3 PERFORMANCE — `s3_parallelism/33_performance`

**What it does.** States a target and lets the tool choose the transformations. It writes the `PIPELINE` and `BIND_OP` directives you did not write: `INFO: [HLS 214-269] Inferring pragma 'pipeline II=9' ... due to performance pragma`.

**Figure.** `acc` sums 16 floats, so it has a loop-carried dependence that no directive can remove:

```text
   x[i] --> [ FADD ] --> sum
              ^   |
              |   | loop-carried: iteration i+1 needs iteration i's total
              +---+

   II_min = L_fadd + w      and L_fadd is NOT a constant -- it is a property
                            of the core the tool picked:

     FAddSub_fulldsp   11 states, latency 10, 2 DSP, 236 LUT   --> reaches II 10
     FAddSub_nodsp      8 states, latency  7, 0 DSP, 376 LUT   --> reaches II 9
```

Five distinguishable behaviours, all measured on this one kernel (`base` = 225 cycles):

| Target | What the tool did | Latency | Cost |
| --- | --- | --- | --- |
| `tl_slack` 400 (far above) | pipelined anyway, at II 14 — no overlap at all | **226, slower** | +27 LUT |
| `tl_loose` 240 (just above) | pipelined at II 10 | **164** | +61 LUT, **slack −0.258 ns** |
| `tl_reach` 224 (equal) | pipelined at II 9 **and swapped the float adder** | **147** | −2 DSP, +187 LUT, +3 FF |
| `tl_miss` 160 (below, but reachable) | **refused**, one `INFO` line, RTL identical to `base` | 225 | 0 |
| `tl_tight` 20 (impossible) | refused, `INFO` + `WARNING` | 225 | 0 |

> The design it refuses to build for a target of 160 is the same design it happily builds for a target of 224 — and that design finishes in **147**.

**Gain:** a number that survives a change of data type, clock period or part, where `II=1` and `factor 4` do not. It composes across many loops, and it reaches for transformations you might not — `tl_reach` is met by a core swap that by hand is a `BIND_OP`.
**Cost:** control and predictability. **Every failure mode is quiet:** a dropped target prints `INFO`, and a target met by a design that is slower or that breaks the clock also prints `INFO` saying it succeeded. Use it with a build check that greps the log.

The directive itself contributes **no hardware** — everything in the RTL is there because the tool applied `PIPELINE` and picked a binding. But a goal with slack in it is **not** a no-op: `tl_slack` asked for 400 from a loop taking 224 and came out a cycle slower and 27 LUT larger.

---

## 3.5 EXPRESSION_BALANCE — `s3_parallelism/35_expression_balance`

**What it does.** Controls whether the tool may regroup a chain of associative operations into a balanced tree, cutting the dependent path from $n-1$ to $\lceil \log_2 n \rceil$.

**Figure.**

```text
   chain, depth 7 (as written)          balanced tree, depth 3
   x0 x1                                x0 x1   x2 x3   x4 x5   x6 x7
    \ /                                   \ /     \ /     \ /     \ /
     +  x2                                 +       +       +       +
      \ /                                    \   /           \   /
       +  x3                                   +               +
        \ /                                      \           /
         +  ...                                    \       /
          \                                           \ /
           +  x7                                       +
            \ /                                        |
             +                                        sum
             |
            sum
```

Same seven adders either way. But the scheduler counts nanoseconds, not graph depth, and Vitis fuses chained additions into **ternary adders** at 0.731 ns against 1.016 ns for a binary one — so a chain's delay path is about *half* its graph depth:

| operands | chain delay path | chain states | tree states | saved |
| --- | --- | --- | --- | --- |
| 8 | 1.02 + 3 × 0.73 = 3.21 ns | 2 | 2 | **0** |
| 32 | 1.02 + 15 × 0.73 = 11.98 ns | 6 | 2 | **4** |

That is why the kernel sums 32 scalars and not 8 — at 8 operands the directive changes the RTL and buys nothing measurable.

**Gain:** latency. On `sum32`, **1 cycle against 5**.
**Cost:** registers. In a chain one partial sum is alive at a time and one operator can serve several in turn; in a tree several run at once, so each needs its own operator and every partial needs its own register. **166 FF → 354 FF**, and +70 LUT of arithmetic, partly offset by −23 LUT of simpler FSM decode. Net: **+47 LUT, +188 FF**.

**The defaults differ by type, and that is the point.** For integers, balancing is **on** by default, because two's-complement addition is associative even when it wraps — so `default` and `on` are byte-identical and the useful form of the directive is `-off`. For `float` and `double` it is off, because rounding at different points gives different answers.

> Measured: **the directive does not reach floating-point expressions at all.** `fsum8` is identical at 76 cycles in `off`, `default` and `on`. The knob for that is `config_compile -unsafe_math_optimizations`, which is a configuration, not this directive.

---

## 4.1 BIND_OP — `s4_resources/41_bind_op`

**What it does.** Chooses which library *core* implements one arithmetic operation (`-impl`) and how many register stages it contains (`-latency`). One directive binds one operation, so `poly`'s three multiplies need three directives.

**Figure.**

```text
  base: the tool picks the "Multiplier" core, latency 1, on DSP slices

    a,x --> [DSP48E2 aL*xL] --+
        --> [DSP48E2 aH*xL] --+--> post-adders --> [reg, 1 stage] --> a*x
        --> [DSP48E2 aL*xH] --+       (inside the DSPs)
        (aH*xH is a multiple of 2^34 and vanishes mod 2^32)     3 DSP per multiply

  fabric: -impl fabric selects "Mul_LUT", whose latency is 0 unless you say otherwise

    a,x --> [partial products in LUTs] --> [carry-chain adder tree] --> a*x
                                           NO REGISTER.  3.479 ns combinational.
```

> Naming `-impl` without naming `-latency` does not leave the pipelining to the scheduler's timing judgement. It selects a specific library core, and that core is the **combinational** one.

| | base | fabric | lat0 | lat3 |
| --- | --- | --- | --- | --- |
| latency, cycles | 4 | **2** | **2** | **8** |
| DSP | 9 | **0** | 9 | 9 |
| FF | 596 | 99 | 201 | 207 |
| LUT | 242 | **3243** | 225 | 259 |
| estimated clock | 2.365 ns | **3.479, slack −1.05** | **3.330, slack −0.90** | 2.287 ns |

**Gain** depends entirely on which option moves. `-impl fabric` frees **all 9 DSP slices** for the rest of a larger design. `-latency 3` shortens the logic between registers and gives the best clock in the lesson, 2.287 ns. `-latency 0` removes register stages and saves two cycles.
**Cost:** about 1000 LUT per 32-bit multiply moved to fabric (3243 against 242 here), or extra cycles and registers for a higher latency — and, for both `fabric` and `lat0`, **a broken clock**, because the whole multiply then has to fit in one period. As in 3.2, Vitis breaks the clock rather than refusing.

**Use it** when the automatic choice does not suit the system: running out of DSP slices, a Vivado timing path through a multiply, or an operator whose latency must match a hand-written pipeline beside it. If you set `-latency`, pin `-impl` too, so the tool cannot meet an unusual latency by quietly switching resource.

---

## 4.2 ALLOCATION — `s4_resources/42_allocation`

**What it does.** Caps how many hardware *instances* of an operation may exist in a scope. Below the cap, operations must **share** one instance across different clock cycles, and a multiplexer picks the operands each cycle. 4.1 chose *which* core; this chooses *how many copies*.

**Figure.**

```text
  base: three instances, no selection logic at all

    x,a --> [mul U3] --> reg a*x --+
                                   +--> [mul U2] --> reg quad --+
    x -----------------------------+                            +--> [ternary
    b,x --> [mul U1] --> reg lin --------------------------------+     adder] --> y

  limit1: one instance, two operand multiplexers

    x, b, reg ---> {mux din0} --+
                                +--> [mul U1] --> reg (a*x, then quad) --+
    a, x -------> {mux din1} --+                                        +--> [ternary
                                      +-------------> reg lin ----------+    adder] --> y
       FSM state -.-> selects both muxes
```

Two details that are easy to get wrong: **both** inputs need a multiplexer, not one — `x` is an operand of all three multiplies, but the tool does not put it on the same port every time. And **one register can serve several products**, because a shared instance produces them at different times.

| | base | limit2 | limit1 |
| --- | --- | --- | --- |
| multiplier instances | 3 | 2 | **1** |
| DSP | 9 | 6 | **3** |
| FF | 596 | 399 | **234** |
| LUT | 242 | 221 | **178** |
| latency / interval | 4 / 5 | 4 / 5 | **4 / 5** |
| estimated clock | 2.365 ns | 2.365 ns | **2.365 ns** |

**Gain:** 3 DSP slices instead of 9 — and, against the usual expectation, **362 fewer flip-flops and 64 fewer LUTs as well**, because two capture registers disappear with the two instances.
**Cost:** on this kernel, nothing measurable. No cycles, no clock. In principle a mux per shared input sits on the path into the multiplier, and if the shared instance cannot fit all its work into the cycles the original schedule offered, the function needs more cycles. Neither happened here — `poly` had idle multiplier states to spend.

**Use it** when a hard resource is the scarce thing and the function has cycles in which an instance would otherwise sit idle. Do **not** use it on small operators like adders: the multiplexer usually costs more LUTs than the operator it removes.

---

## 4.3 INLINE — `s4_resources/43_inline`

**What it does.** Copies a callee's body into its caller so the call disappears. A function that is *not* inlined becomes its own RTL submodule with its own handshake, and the scheduler treats each call as an opaque operation it cannot see inside. The directive goes on the function that should disappear.

**Figure.**

```text
  off: two submodules, the scheduler cannot look inside either

    calls  (FSM, 4 states, 32-bit tmp_reg)
      |  p = a_q0, q = b_q0          s = tmp_reg, k = c_q0
      +--> [calls_sum2: one 32-bit adder] --> tmp_reg --> [calls_bias: one 32-bit adder] --> y

  default and on: one flat module

    calls  (FSM, 3 states)
      +--> one TERNARY adder  (a + c) + b  --> y
```

| State | `off` | `default` and `on` |
| --- | --- | --- |
| 1 | 0.427 ns, `i = 0` | 0.427 ns, `i = 0` |
| 2 | 1.216 ns, counter | 1.216 ns, counter |
| 3 | 1.693 ns, read `a` + call `sum2` | **2.085 ns, read + ternary adder + write `y`** |
| 4 | **2.370 ns**, read `c` + call `bias` + write `y` | — |

**Gain:** the scheduler sees both sides at once and fuses them. **33 cycles against 49** — a 48 % shorter runtime for the same result — plus a better clock, 2.085 ns against 2.370.
**Cost:** one copy of the callee per call site, and a lost module boundary that made that part easy to find in the reports, simulate alone, or reuse. Here the boundary's price was **+33 FF** (the 32-bit `tmp_reg` carrying the sum from state 3 to state 4, plus one one-hot FSM bit) and only +20 LUT, because the two separate adders (+78 LUT) nearly cancel the ternary adder they replace (−64 LUT).

> **For small functions the plain directive changes nothing**, because Vitis already inlines them: `default` and `on` produce byte-identical Verilog. The setting that changes hardware on a small helper is **`-off`**.

| | off | default | on |
| --- | --- | --- | --- |
| Verilog module files | 3 | 1 | 1 |
| iteration / function latency | 3 / 49 | 2 / 33 | 2 / 33 |
| FF / LUT | 46 / 138 | **13 / 118** | 13 / 118 |

---

## 5.1 INTERFACE — `s5_interfaces/51_interface`

**What it does.** Chooses the port protocol of a top-level argument — the wires that carry it and the rules for which cycle they are valid. Every earlier lesson used the default for arrays, `ap_memory`.

**Figure.**

```text
  base     ap_memory   block drives address0 + ce0, data arrives next cycle
           [outside RAM] <--address0,ce0-- [vadd core] --address0,ce0,we0,d0--> [outside RAM]

  fifo     ap_fifo     no address at all; dout is already waiting
           [outside FIFO] --dout,empty_n--> [vadd core] --read--> ...   --din,write--> [FIFO]

  axilite  s_axilite   an adapter INSIDE the block holds the arrays
           [processor] --AXI4-Lite--> [control adapter: RAMs a,b,y] --RAM port--> [vadd core]

  maxi     m_axi       the block fetches the data itself
           [base addresses in] --> [vadd core] --requests--> [gmem adapter] --AXI4--> [DDR]
```

| | base | fifo | axilite | maxi |
| --- | --- | --- | --- | --- |
| iteration latency | 2 | 2 | 2 | **13** |
| function latency (C synth) | 33 | 33 | 33 | **214** |
| cosim latency min/avg/max | 33/33/33 | 33/33/33 | **355/488/498** | **298** |
| C synth FF / LUT | 13 / 93 | 72 / 122 | 283 / 367 | 1204 / 1067 |
| of which the adapter | — | — | 270 / 274 | 830 / 694 + 4 BRAM |
| Vivado LUT / FF / BRAM | 41 / 12 / 0 | 43 / 72 / 0 | 100 / 58 / 5 | 1254 / 2046 / 2 |

**Gain** depends on the mode: `ap_fifo` removes the address wires and lets you attach a producer instead of a memory; `s_axilite` lets a processor load and read back the arrays with no glue logic; `m_axi` lets the block reach a memory far larger than anything that fits beside it.
**Cost:** logic that appears nowhere in the C. `ap_fifo` is the cheap one at **+29 LUT and +59 FF** — almost all of it the two captured input words and three `*_blk_n` handshake terms — in exchange for 0.139 ns of clock. It did **not** save a cycle: the read and the write still cannot share a state, so the latency stayed at 33 where the prediction said 17.

`s_axilite` leaves the core untouched and puts everything new in one adapter instance. `m_axi` grows the core itself: the arithmetic the C asks for is 39 LUT, and **the arithmetic the interface asks for is 140 LUT** — two 63-bit byte-address adders that exist only because the read bursts were dropped. Its cosim latency, 298, is a property of the system, not the kernel.

---

## 5.2 AGGREGATE and DISAGGREGATE — `s5_interfaces/52_aggregate`

**What it does.** Decides how a struct argument's fields become wires. `AGGREGATE` packs all fields into one wide word; `DISAGGREGATE` splits the struct so each field gets its own port. `-compact bit` packs back to back, `-compact byte` starts every field on a byte boundary.

**Figure.** An RGB565 pixel, `r:5 g:6 b:5`:

```text
  base / aggregate_bit      one 16-bit word, fields packed
     15          11 10        5 4           0
    +--------------+-----------+-------------+
    |    b (5)     |   g (6)   |    r (5)    |     src memory: 16 x 16 bits
    +--------------+-----------+-------------+

  aggregate_byte            one 24-bit word, each field byte-aligned
     23      19 18   16 15      10 9  8 7       3 2  0
    +----------+-------+----------+-----+---------+----+
    |  b (5)   |  pad  |  g (6)   | pad |  r (5)  |pad |   src memory: 16 x 24 bits
    +----------+-------+----------+-----+---------+----+

  disaggregate              one memory per field, six interfaces in all
    src_r 16x5 --+                          +--> dst_r 16x5
    src_g 16x6 --+--> [rgb block]  (swap) --+--> dst_g 16x6
    src_b 16x5 --+                          +--> dst_b 16x5
```

**Gain:** control over the exact bit layout at the boundary. An aggregated word lets a caller move a whole pixel in one access and a bit-packed word wastes no memory width; a disaggregated struct lets each field live in its own memory, which is what a downstream block that consumes one channel wants.
**Cost:** width or port count — **never cycles here.** Every field sits at a compile-time bit offset, so reading or writing one is a constant selection of wires, and all four solutions are identical inside: **33 cycles, 13 FF, 54 LUT, 1.354 ns**. Byte alignment widens every word by the padding (16 bits → 24); disaggregation multiplies address, enable and data ports (2 memory interfaces → 6).

Measured: the default for an `ap_memory` port is **bit** alignment — `base` and `aggregate_bit` are the same RTL. And the padding bits of the output are not zeroed; they are copied from the input word.

---

## 5.3 RESET — `s5_interfaces/53_reset`

**What it does.** Decides whether one static or global variable returns to its C initial value when `ap_rst` is asserted. Power-up and reset are different events: Vitis writes the C value into the bitstream at power-up, but a register returns there on reset only if the RTL contains a branch that drives it. The default `config_rtl -reset control` resets the FSM and handshake registers and **leaves static variables alone**.

**Figure.** A scalar is one extra branch. An array is a rebuilt illusion, because a RAM has no reset pin:

```text
  scalar, base                      scalar, reset_cnt
    INIT=100 ....> [cnt, 8 FF]        INIT=100 ....> [cnt, 8 FF]
                     ^   |                             ^   |
                     |   v                             |   v
                   [ cnt + 1 ]                       [ cnt + 1 ]
                     ^                                 |
                     +-- write enable (FSM)          {ap_rst?} <-- constant 100
                                                       ^
                                                       +-- write enable (FSM)

  array, base                       array, reset_hist
    .dat ....> [ram[8]]               address0,d0,we0 --+--> [ram[8]]   (no INIT)
    addr,d0,we0 --> ram --> q0                          +--> [rom0[8] = {1..8}] --+
                                                        +--> [written[8]] --+     |
                                                              cleared by ap_rst   |
                                                              set on each write   |
                                                                    | selects     |
                                                                    v             v
                                                                 { q0_sel } <-----+
                                                                    |
                                                                    v  q0
```

After a reset every `written` bit is 0, so every address reads back its C initial value — and it costs **zero cycles**, because nothing has to be rewritten.

**Gain:** the kernel restarts from its power-up state without the bitstream being reloaded. In an ASIC flow this is not optional: there is no power-up value at all.
**Cost:** for a scalar, **nothing on this FPGA** — every flip-flop already has a set/reset pin, and `reset_cnt` has exactly the same cell count as `base`, with three FDRE cells simply becoming FDSE. For an 8-word array, **+13 FF and +20 LUT** (Vivado) and still **zero cycles**: latency 1 and interval 2 in all three solutions.

**It changes hardware only when the variable was not already reset.** Under `config_rtl -reset state` or `all`, every static is reset already, and only `-off` would change the RTL.

---

## 6.1 DATAFLOW — `s6_dataflow/61_dataflow`

**What it does.** Turns the functions and loops inside one function into **processes** — independent blocks with their own controllers — connected by **channels**. Without it, one controller walks the stages in order.

Which number improves depends on the channel:
- a **ping-pong buffer (PIPO)** holds a whole array in each of two banks, and releases the consumer only when the producer has finished the entire array. The **interval** improves, the latency does not.
- a **FIFO** passes one element at a time and releases the consumer as soon as the first element arrives. The stages overlap *inside* one call, so the **latency** improves too.

**Figure.**

```text
  base: one module, one FSM, five states, t is a RAM

    [a port] --> LOAD_LOOP states --> [t_U: RAM, 16 x 32] --> STORE_LOOP states --> [y]
                                                                   ^
                                                              [b port]
      While the FSM is in STORE_LOOP, the LOAD hardware sits idle.

  dataflow: two modules, two FSMs, t is a FIFO the tool chose on its own

    [a] --> (Loop_LOAD_LOOP_proc, own FSM, 3 states/iter)
                 |  write, blocks while t_full_n = 0
                 v
            [t_U: fifo_w32_d16_S, 16 x 32, SRL]
                 |  read, blocks while t_empty_n = 0
                 v
            (Loop_STORE_LOOP_proc, own FSM, 2 states/iter) --> [y]    <-- [b]
```

`INFO: [XFORM 203-721] Change variable 't' to FIFO automatically.` The default channel is a PIPO, but both ends here touch the array strictly in order, so the tool converts it. That is the whole synchronisation: no global schedule, two machines waiting on a queue.

**Gain:** **latency 51 against 66 and interval 50 against 67.** Over 16 calls, co-simulation measured 831 cycles against 1071.
**Cost:** one controller per process, channel status logic, and top-level handshake combining — **+14 LUT and +39 FF** after Vivado synthesis. The channel itself got *cheaper*: a 16-deep shift-register FIFO replaced a 16-word distributed RAM with its address decoding and output register.

The LOAD body grew from 2 states to 3, because a FIFO write can stall and so needs a state of its own with the value already registered. That extra state is why the interval lands at 50 and not 34.

**Use it** when a function is stages that each consume what the previous stage produced. It is useless for a stage that reads its whole input before producing anything, and it cannot help beyond the slowest process, which alone sets the interval.

---

## 6.2 STREAM — `s6_dataflow/62_stream`

**What it does.** Chooses the channel a DATAFLOW region builds between two processes: `-type fifo` with a `-depth`, or `-type pipo`. The kernel is 6.1's `pipe2` with `STORE_LOOP` multiplying instead of adding, so that the **consumer** is the slower side and the FIFO actually fills.

**Figure.**

```text
  pipo: two full banks; the handshake moves ONCE PER CALL

    [LOAD_LOOP proc] --t_address0,t_we0,t_d0--> ( bank iptr,  16 x 32 )
                     ...ap_done releases the bank...  ( bank iptr^1, 16 x 32 )
                                                          |
                     STORE_LOOP's ap_start is gated by t_empty_n, so it cannot
                     begin until LOAD has FINISHED. The two run one after the
                     other inside a call, and overlap only across two calls.

  base and d2: a FIFO; the handshake moves ONCE PER ELEMENT

    [LOAD_LOOP proc] --if_din, if_write--> ( FIFO, depth 16 or 2 ) --if_dout, if_empty_n--> [STORE_LOOP proc]
                     <--if_full_n---------                        <--if_read---------------
                     Both processes are always free to run at the same time.
```

| | base (FIFO, 16) | pipo | d2 (FIFO, 2) |
| --- | --- | --- | --- |
| LOAD process latency | 49 | **33** | 49 |
| STORE process latency | 81 | 81 | 81 |
| function latency | **83** | **115** | **83** |
| interval | 82 | 82 | 82 |
| cosim, 16 calls | 1343 | **1855** | 1343 |
| Vivado FF | 114 | **85** | **176** |
| Vivado LUT | 113 | **97** | 109 |
| channel primitives | 32 × SRL16E | 20 × LUTRAM | 170 × FDRE |

**Gain:** a FIFO lets the consumer start on the first element instead of the whole array, and holds only the elements in flight rather than two whole copies. `-depth` buys the producer exactly as much slack as it needs and no more.
**Cost:** a strict access rule — both processes must touch the array in the same sequential order, each element exactly once — and, for a shallow FIFO, a producer that stalls whenever it is full. In `d2` the producer stalls 2 cycles in every 5 from cycle 47 onward.

**What moved and what did not.** The PIPO costs **115 cycles against 83** and does not change the **interval**, which is 82 in all three: the interval is set by the slower process, and no channel choice changes that. Depth 2 changed neither latency nor interval — it changed *where the producer waits* and which primitives the channel lands on, trading 32 shift-register LUTs for 170 flip-flops.

An explicit `-depth 16`, or `-type fifo` with no depth, reproduces `base`: a converted array keeps its size as its depth.
