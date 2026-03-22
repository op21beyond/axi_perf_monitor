// Minimal testbench — tie-offs only; extend with AXI master/slave BFMs
`timescale 1ns/1ps

module tb_axi_perf_monitor;

  localparam int AW = 64;
  localparam int DW = 256;
  localparam int IW = 4;
  localparam int UW = 1;
  localparam int SW = DW/8;

  logic aclk;
  logic aresetn;

  initial begin
    aclk = 1'b0;
    forever #5ns aclk = ~aclk;
  end

  initial begin
    aresetn = 1'b0;
    repeat (4) @(posedge aclk);
    aresetn = 1'b1;
  end

  logic        psel, penable, pwrite;
  logic [15:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        irq;

  logic [AW-1:0] up_awaddr, up_araddr;
  logic [7:0]    up_awlen, up_arlen;
  logic [2:0]    up_awsize, up_arsize;
  logic [1:0]    up_awburst, up_arburst;
  logic [IW-1:0] up_awid, up_arid;
  logic [UW-1:0] up_awuser, up_wuser, up_aruser;
  logic          up_awvalid, up_wvalid, up_arvalid;
  logic          up_awready, up_wready, up_arready;
  logic [DW-1:0] up_wdata;
  logic [SW-1:0] up_wstrb;
  logic          up_wlast;
  logic          up_bready, up_rready;
  logic [IW-1:0] up_bid, up_rid;
  logic [1:0]    up_bresp, up_rresp;
  logic [UW-1:0] up_buser, up_ruser;
  logic          up_bvalid, up_rvalid;
  logic          up_rlast;

  logic [AW-1:0] dn_awaddr, dn_araddr;
  logic [7:0]    dn_awlen, dn_arlen;
  logic [2:0]    dn_awsize, dn_arsize;
  logic [1:0]    dn_awburst, dn_arburst;
  logic [IW-1:0] dn_awid, dn_arid;
  logic [UW-1:0] dn_awuser, dn_wuser, dn_aruser;
  logic          dn_awvalid, dn_wvalid, dn_arvalid;
  logic          dn_awready, dn_wready, dn_arready;
  logic [DW-1:0] dn_wdata;
  logic [SW-1:0] dn_wstrb;
  logic          dn_wlast;
  logic          dn_bready, dn_rready;
  logic [IW-1:0] dn_bid, dn_rid;
  logic [1:0]    dn_bresp, dn_rresp;
  logic [UW-1:0] dn_buser, dn_ruser;
  logic          dn_bvalid, dn_rvalid;
  logic          dn_rlast;

  assign up_awaddr = '0;
  assign up_awlen  = '0;
  assign up_awsize = 3'd6; // 256-bit
  assign up_awburst= 2'b01;
  assign up_awid   = '0;
  assign up_awuser = '0;
  assign up_awvalid= 1'b0;
  assign up_wdata  = '0;
  assign up_wstrb  = '0;
  assign up_wlast  = 1'b0;
  assign up_wuser  = '0;
  assign up_wvalid = 1'b0;
  assign up_bready = 1'b1;
  assign up_araddr = '0;
  assign up_arlen  = '0;
  assign up_arsize = 3'd6;
  assign up_arburst= 2'b01;
  assign up_arid   = '0;
  assign up_aruser = '0;
  assign up_arvalid= 1'b0;
  assign up_rready = 1'b1;

  assign dn_awready = 1'b1;
  assign dn_wready  = 1'b1;
  assign dn_bid     = '0;
  assign dn_bresp   = 2'b00;
  assign dn_buser   = '0;
  assign dn_bvalid  = 1'b0;
  assign dn_arready = 1'b1;
  assign dn_rid     = '0;
  assign dn_rdata   = '0;
  assign dn_rresp   = 2'b00;
  assign dn_rlast   = 1'b0;
  assign dn_ruser   = '0;
  assign dn_rvalid  = 1'b0;

  axi_perf_monitor_top #(
    .AXI_ADDR_WIDTH(AW),
    .AXI_DATA_WIDTH(DW),
    .AXI_ID_WIDTH(IW),
    .AXI_USER_WIDTH(UW),
    .FIFO_DEPTH(32),
    .USE_SLICE_UP(1'b0),
    .USE_SLICE_DN(1'b0)
  ) dut (
    .aclk(aclk), .aresetn(aresetn),
    .psel(psel), .penable(penable), .pwrite(pwrite),
    .paddr(paddr), .pwdata(pwdata), .prdata(prdata), .pready(pready),
    .irq(irq),
    .up_awaddr(up_awaddr), .up_awlen(up_awlen), .up_awsize(up_awsize), .up_awburst(up_awburst),
    .up_awid(up_awid), .up_awuser(up_awuser), .up_awvalid(up_awvalid), .up_awready(up_awready),
    .up_wdata(up_wdata), .up_wstrb(up_wstrb), .up_wlast(up_wlast), .up_wuser(up_wuser),
    .up_wvalid(up_wvalid), .up_wready(up_wready),
    .up_bid(up_bid), .up_bresp(up_bresp), .up_buser(up_buser), .up_bvalid(up_bvalid), .up_bready(up_bready),
    .up_araddr(up_araddr), .up_arlen(up_arlen), .up_arsize(up_arsize), .up_arburst(up_arburst),
    .up_arid(up_arid), .up_aruser(up_aruser), .up_arvalid(up_arvalid), .up_arready(up_arready),
    .up_rid(up_rid), .up_rdata(up_rdata), .up_rresp(up_rresp), .up_rlast(up_rlast), .up_ruser(up_ruser),
    .up_rvalid(up_rvalid), .up_rready(up_rready),
    .dn_awaddr(dn_awaddr), .dn_awlen(dn_awlen), .dn_awsize(dn_awsize), .dn_awburst(dn_awburst),
    .dn_awid(dn_awid), .dn_awuser(dn_awuser), .dn_awvalid(dn_awvalid), .dn_awready(dn_awready),
    .dn_wdata(dn_wdata), .dn_wstrb(dn_wstrb), .dn_wlast(dn_wlast), .dn_wuser(dn_wuser),
    .dn_wvalid(dn_wvalid), .dn_wready(dn_wready),
    .dn_bid(dn_bid), .dn_bresp(dn_bresp), .dn_buser(dn_buser), .dn_bvalid(dn_bvalid), .dn_bready(dn_bready),
    .dn_araddr(dn_araddr), .dn_arlen(dn_arlen), .dn_arsize(dn_arsize), .dn_arburst(dn_arburst),
    .dn_arid(dn_arid), .dn_aruser(dn_aruser), .dn_arvalid(dn_arvalid), .dn_arready(dn_arready),
    .dn_rid(dn_rid), .dn_rdata(dn_rdata), .dn_rresp(dn_rresp), .dn_rlast(dn_rlast), .dn_ruser(dn_ruser),
    .dn_rvalid(dn_rvalid), .dn_rready(dn_rready)
  );

  initial begin
    psel = 1'b0;
    penable = 1'b0;
    pwrite = 1'b0;
    paddr = 16'h0;
    pwdata = 32'h0;
    #1000ns;
    $finish;
  end

endmodule
