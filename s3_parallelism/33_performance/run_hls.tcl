# Lesson 3.3 - PERFORMANCE
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Six solutions live in one project. Only the PERFORMANCE directive on
# ACC_LOOP differs between them, and the targets walk downwards:
#
#   base      no directive, the natural unpipelined loop, 224 cycles
#   tl_slack  -target_tl 400, far above the latency the loop already has
#   tl_loose  -target_tl 240, just above it
#   tl_reach  -target_tl 224, equal to it, and the tightest target accepted
#   tl_miss   -target_tl 160, below it, and reachable in fact but refused
#   tl_tight  -target_tl 20,  below anything the recurrence permits
#
# The point of the lesson is that none of these five names a transformation.
# They name a number of cycles, and the tool decides whether to pipeline, to
# unroll, to re-bind an operator, or to decline the request altogether. Read
# run.log for "214-269" (the tool writing the pipeline pragma you did not
# write), "200-1470" (what it achieved) and "200-1957" (whether the target was
# applied at all) in solutions whose directives file contains no PIPELINE and
# no UNROLL directive.
#
# The measured outcomes are not the intuitive ones, and section 7 of README.md
# reports them in full:
#
#   * tl_slack and tl_loose have targets the loop ALREADY meets, and the tool
#     pipelines anyway. A slack target is not a no-op.
#   * tl_loose meets its target in cycles and breaks the clock doing it.
#   * tl_reach re-binds the adder from a DSP core to a fabric core in order to
#     reach the initiation interval it derived.
#   * tl_miss asks for 160 cycles, which tl_reach demonstrably achieves at 147,
#     and is refused with nothing louder than an INFO line.
#
# tl_miss and tl_tight are expected to produce the same hardware as base,
# because a refused performance pragma leaves the loop exactly as it found it.
# README.md section 7 checks that with a normalised diff rather than asserting
# it.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

# This directive is newer than most of the ones taught in this repository, so
# fail loudly here rather than silently synthesizing six identical solutions
# if the installation does not carry it.
if {[info commands set_directive_performance] eq ""} {
    puts "ERROR: set_directive_performance is not available in this Vitis HLS installation."
    exit 1
}

open_project -reset acc_proj
set_top acc

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/acc.cpp   -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/acc_tb.cpp -cflags "-I$lesson_dir/src"

foreach sol {base tl_slack tl_loose tl_reach tl_miss tl_tight} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    csynth_design

    # Co-simulation runs on EVERY solution here, which is a departure from the
    # rule the repository usually follows.
    #
    # The rule is that co-simulation is run when a directive can change
    # behaviour. LATENCY in lesson 3.2 cannot, because moving a state boundary
    # does not change which operand reaches which operator. PERFORMANCE makes
    # no such promise: it does not say what the tool will do, and this lesson
    # measures it doing two things that touch the arithmetic -- re-binding the
    # floating-point adder to a completely different implementation in
    # tl_reach, and it could in principle have split the accumulation into
    # partial sums, which would change the result because floating-point
    # addition is not associative.
    #
    # The testbench compares bit for bit, with no tolerance, so a regrouped sum
    # or a sloppier adder fails rather than passing within epsilon. The
    # re-bound eight-stage fabric adder of tl_reach is a real test of that: it
    # is a different circuit and it must still return the identical bits.
    #
    # There is no separate csim_design call. cosim_design compiles and runs the
    # same testbench, twice per solution, so the whole run prints TEST PASSED
    # exactly twelve times. Anything other than twelve is a failure even if no
    # line says FAILED.
    cosim_design
}

exit
