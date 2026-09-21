# Solution: axilite
#
# All three arrays go behind one AXI4-Lite slave. A 16-word array is not
# turned into 16 registers: each array becomes a small memory inside the
# control adapter, with its own address range in the register map, and the
# core reads it through an internal RAM port.
#
# The bundle is named explicitly. Every s_axilite directive in a design must
# name the same bundle, or the tool builds a second AXI4-Lite slave.
#
# Predicted, not yet measured: the core schedule equals base (function
# latency 33) and all of the difference is the adapter, control_s_axi_U.

set_directive_interface -mode s_axilite -bundle control "vadd" a
set_directive_interface -mode s_axilite -bundle control "vadd" b
set_directive_interface -mode s_axilite -bundle control "vadd" y