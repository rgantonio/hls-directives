# Target: mid-size Kintex UltraScale+, speed grade -2, 300 MHz.
set_part xcku5p-ffvb676-2-e
create_clock -period 3.33 -name default

# Baseline policy for this repo: the tool must not pipeline anything
# unless an exercise explicitly asks for it. See Step 7, probe D.
config_compile -pipeline_loops 0