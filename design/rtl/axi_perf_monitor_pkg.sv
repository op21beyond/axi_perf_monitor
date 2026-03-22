// Package: AXI performance monitor — shared types and helpers
`ifndef AXI_PERF_MONITOR_PKG_SV
`define AXI_PERF_MONITOR_PKG_SV

package axi_perf_monitor_pkg;

  // ---------------------------------------------------------------------------
  // Burst byte count: bytes = (1<<size) * (len+1)
  // ---------------------------------------------------------------------------
  function automatic logic [63:0] burst_bytes(
    logic [2:0] size_i,
    logic [7:0] len_i
  );
    logic [63:0] sz;
    sz = 64'(1) << size_i;
    return sz * (64'(len_i) + 64'd1);
  endfunction

  // Address in [base, base+size) with size>0; if size==0 treat as no range in some modes
  function automatic logic addr_in_range(
    logic [63:0] addr,
    logic [63:0] base,
    logic [63:0] size_i
  );
    if (size_i == 64'd0) return 1'b0;
    return (addr >= base) && (addr < (base + size_i));
  endfunction

endpackage

`endif
