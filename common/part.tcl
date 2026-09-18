# common/part.tcl
#
# Shared solution settings for every lesson in this repository. Source this from
# inside an open solution, before the lesson's own directives file.
#
# Only config_* commands belong here. Every set_directive_* command belongs in a
# lesson's directives_<solution>.tcl file, so that a lesson always shows exactly
# one directive changing.

set_part {xcku5p-ffvb676-2-e}
create_clock -period 3.33 -name default

# Vitis HLS pipelines short loops on its own. That would silently optimize the
# baseline of almost every lesson, so automatic loop pipelining is switched off
# here and each lesson asks for pipelining explicitly when it needs it.
config_compile -pipeline_loops 0