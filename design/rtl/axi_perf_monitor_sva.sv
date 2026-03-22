// Optional bind-in checks for this IP only (no up/down AXI protocol checking).
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
