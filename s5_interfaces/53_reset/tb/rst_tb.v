`timescale 1ns/1ps
// Lesson 5.3: drives ap_rst in the middle of a run, which co-simulation
// cannot do. Three calls, a two-cycle reset, three more calls, all on slot 0.
// Prints one line per call and writes rst_tb.vcd for a waveform viewer.
module rst_tb;
  reg        ap_clk = 1'b0, ap_rst = 1'b1, ap_start = 1'b0;
  reg  [2:0] slot = 3'd0;
  wire       ap_done, ap_idle, ap_ready, hits_ap_vld;
  wire [7:0] hits, ap_return;
  integer    cyc = 0;

  counter dut (.ap_clk(ap_clk), .ap_rst(ap_rst), .ap_start(ap_start),
               .ap_done(ap_done), .ap_idle(ap_idle), .ap_ready(ap_ready),
               .slot(slot), .hits(hits), .hits_ap_vld(hits_ap_vld),
               .ap_return(ap_return));

  always #1.665 ap_clk = ~ap_clk;            // 3.33 ns
  always @(posedge ap_clk) cyc <= cyc + 1;

  // Inputs change and outputs are sampled on falling edges, away from the
  // rising edges where the RTL registers update.
  task call(input integer n);
    integer lat, r, h, done;
    begin
      @(negedge ap_clk); ap_start = 1'b1; lat = 0; done = 0; h = -1;
      while (!done) begin
        @(negedge ap_clk); lat = lat + 1;
        if (hits_ap_vld) h = hits;
        if (ap_done) begin r = ap_return; done = 1; end
      end
      ap_start = 1'b0;
      $display("call %0d  cycle %0d  total %0d  hits %0d  start-to-done %0d",
               n, cyc, r, h, lat);
    end
  endtask

  task pulse_reset(input integer n);
    begin
      @(negedge ap_clk); ap_rst = 1'b1;
      repeat (n) @(negedge ap_clk);
      ap_rst = 1'b0;
    end
  endtask

  initial begin
    $dumpfile("rst_tb.vcd");
    $dumpvars(0, rst_tb);
    repeat (2) @(negedge ap_clk);            // time-zero reset, as in cosim
    ap_rst = 1'b0;
    call(1); call(2); call(3);
    $display("-- reset --");
    pulse_reset(2);
    call(4); call(5); call(6);
    $finish;
  end
endmodule