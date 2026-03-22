//-----------------------------------------------------------------------------
// axi_perf_monitor_sva.sv
//
// Optional assertions bound into the IP (e.g. internal FIFO index sanity). Does not
// check full upstream/downstream AXI protocol. Enable with AXI_PERF_MONITOR_SVA.
//
// Designed by Jongchul Shin, Coded by Cursor
//-----------------------------------------------------------------------------
`ifdef AXI_PERF_MONITOR_SVA
`timescale 1ns/1ps

module axi_perf_monitor_sva (
  input logic aclk,
  input logic aresetn,
  input logic [31:0] r_n_switch,
  input int         fifo_depth
);

  property p_n_switch_range;
    @(posedge aclk) disable iff (!aresetn)
      (r_n_switch < fifo_depth) || (r_n_switch == 32'd0);
  endproperty

  assert property (p_n_switch_range);

endmodule
`endif
