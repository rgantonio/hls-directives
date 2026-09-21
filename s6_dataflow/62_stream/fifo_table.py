#!/usr/bin/env python3
# fifo_table.py <vcd> [cycles] [before]
#
# Prints a markdown waveform table of the channel FIFO t_U from the VCD that
# dump_fifo_vcd.tcl writes. Rows are signals and columns are clock edges.
# Each column holds the values sampled just before a rising edge of clk, which
# are the values the registers capture at that edge.
# The window starts <before> edges ahead of the first edge at which the FIFO
# is full (if_full_n is 0) outside reset, and it is <cycles> edges wide.

import sys

SCOPE = "t_U"
ROWS = ["if_full_n", "if_write", "if_din",
        "if_num_data_valid", "if_empty_n", "if_read"]


def parse(path):
    code_names = {}
    scope = []
    samples = []
    cur = {}
    with open(path) as f:
        for line in f:
            tok = line.split()
            if not tok:
                continue
            if tok[0] == "$scope":
                scope.append(tok[2])
            elif tok[0] == "$upscope":
                scope.pop()
            elif tok[0] == "$var":
                if scope and scope[-1] == SCOPE:
                    code_names.setdefault(tok[3], []).append(tok[4])
            elif tok[0] == "$enddefinitions":
                break
        block = []

        def apply(block):
            rising = any(n == "clk" and v == "1" and cur.get("clk") == "0"
                         for n, v in block)
            if rising:
                samples.append(dict(cur))
            for n, v in block:
                cur[n] = v

        for line in f:
            s = line.strip()
            if not s or s.startswith("$"):
                continue
            if s[0] == "#":
                apply(block)
                block = []
                continue
            if s[0] in "bBrR":
                val, code = s[1:].split()
            else:
                val, code = s[0], s[1:]
            for n in code_names.get(code, []):
                block.append((n, val))
        apply(block)
    return samples


def show(v, name):
    if v is None:
        return "-"
    if name == "if_din" and all(c in "01" for c in v):
        return "0x%x" % int(v, 2)
    if len(v) > 1 and all(c in "01" for c in v):
        return str(int(v, 2))
    return v


def main():
    path = sys.argv[1]
    cycles = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    before = int(sys.argv[3]) if len(sys.argv) > 3 else 2
    samples = parse(path)
    first = None
    for k, s in enumerate(samples):
        if s.get("reset", "0") == "0" and s.get("if_full_n") == "0" \
                and s.get("if_empty_n") == "1":
            first = k
            break
    if first is None:
        print("The FIFO never became full in this trace.")
        return 1
    lo = max(0, first - before)
    win = samples[lo:lo + cycles]
    rows = [r for r in ROWS if any(r in s for s in win)]
    head = ["signal"] + ["c%d" % (lo + j) for j in range(len(win))]
    table = [head] + [[r] + [show(s.get(r), r) for s in win] for r in rows]
    w = [max(len(row[c]) for row in table) for c in range(len(head))]
    for i, row in enumerate(table):
        print("| " + " | ".join(x.ljust(w[c]) for c, x in enumerate(row)) + " |")
        if i == 0:
            print("|" + "|".join("-" * (x + 2) for x in w) + "|")
    print("\nFirst full edge: c%d of %d edges." % (first, len(samples)))
    return 0


if __name__ == "__main__":
    sys.exit(main())