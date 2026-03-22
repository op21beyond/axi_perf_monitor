//-----------------------------------------------------------------------------
// axi_perf_monitor_top.sv
//
// Top-level: optional upstream/downstream AXI slices around axi_perf_monitor_core.
// Slave-facing ports use up_*; master toward memory/interconnect use dn_*.
//
// Designed by Jongchul Shin, Coded by Cursor
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module axi_perf_monitor_top #(
  parameter int AXI_ADDR_WIDTH   = 64,
  parameter int AXI_DATA_WIDTH   = 256,
  parameter int AXI_ID_WIDTH     = 8,
  parameter int AXI_USER_WIDTH   = 1,
  parameter int FIFO_DEPTH       = 32,
  parameter int TIME_WIDTH       = 32,
  parameter int MAX_PENDING_PER_ID = 8,
  parameter bit USE_SLICE_UP     = 1'b0,
  parameter bit USE_SLICE_DN     = 1'b0
)(
  input  logic aclk,
  input  logic aresetn,

  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [15:0] paddr,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,

  output logic irq,

  input  logic [AXI_ADDR_WIDTH-1:0]   up_awaddr,
  input  logic [7:0]                 up_awlen,
  input  logic [2:0]                 up_awsize,
  input  logic [1:0]                 up_awburst,
  input  logic [AXI_ID_WIDTH-1:0]    up_awid,
  input  logic [AXI_USER_WIDTH-1:0]  up_awuser,
  input  logic                       up_awvalid,
  output logic                       up_awready,
  input  logic [AXI_DATA_WIDTH-1:0]  up_wdata,
  input  logic [(AXI_DATA_WIDTH/8)-1:0] up_wstrb,
  input  logic                       up_wlast,
  input  logic [AXI_USER_WIDTH-1:0]  up_wuser,
  input  logic                       up_wvalid,
  output logic                       up_wready,
  output logic [AXI_ID_WIDTH-1:0]    up_bid,
  output logic [1:0]                up_bresp,
  output logic [AXI_USER_WIDTH-1:0]  up_buser,
  output logic                       up_bvalid,
  input  logic                       up_bready,
  input  logic [AXI_ADDR_WIDTH-1:0]  up_araddr,
  input  logic [7:0]                 up_arlen,
  input  logic [2:0]                 up_arsize,
  input  logic [1:0]                 up_arburst,
  input  logic [AXI_ID_WIDTH-1:0]    up_arid,
  input  logic [AXI_USER_WIDTH-1:0]  up_aruser,
  input  logic                       up_arvalid,
  output logic                       up_arready,
  output logic [AXI_ID_WIDTH-1:0]    up_rid,
  output logic [AXI_DATA_WIDTH-1:0] up_rdata,
  output logic [1:0]                up_rresp,
  output logic                       up_rlast,
  output logic [AXI_USER_WIDTH-1:0]  up_ruser,
  output logic                       up_rvalid,
  input  logic                       up_rready,

  output logic [AXI_ADDR_WIDTH-1:0]   dn_awaddr,
  output logic [7:0]                 dn_awlen,
  output logic [2:0]                 dn_awsize,
  output logic [1:0]                 dn_awburst,
  output logic [AXI_ID_WIDTH-1:0]    dn_awid,
  output logic [AXI_USER_WIDTH-1:0]  dn_awuser,
  output logic                       dn_awvalid,
  input  logic                       dn_awready,
  output logic [AXI_DATA_WIDTH-1:0]  dn_wdata,
  output logic [(AXI_DATA_WIDTH/8)-1:0] dn_wstrb,
  output logic                       dn_wlast,
  output logic [AXI_USER_WIDTH-1:0]  dn_wuser,
  output logic                       dn_wvalid,
  input  logic                       dn_wready,
  input  logic [AXI_ID_WIDTH-1:0]    dn_bid,
  input  logic [1:0]                dn_bresp,
  input  logic [AXI_USER_WIDTH-1:0]  dn_buser,
  input  logic                       dn_bvalid,
  output logic                       dn_bready,
  output logic [AXI_ADDR_WIDTH-1:0]  dn_araddr,
  output logic [7:0]                 dn_arlen,
  output logic [2:0]                 dn_arsize,
  output logic [1:0]                 dn_arburst,
  output logic [AXI_ID_WIDTH-1:0]    dn_arid,
  output logic [AXI_USER_WIDTH-1:0]  dn_aruser,
  output logic                       dn_arvalid,
  input  logic                       dn_arready,
  input  logic [AXI_ID_WIDTH-1:0]    dn_rid,
  input  logic [AXI_DATA_WIDTH-1:0] dn_rdata,
  input  logic [1:0]                dn_rresp,
  input  logic                       dn_rlast,
  input  logic [AXI_USER_WIDTH-1:0]  dn_ruser,
  input  logic                       dn_rvalid,
  output logic                       dn_rready
);

  // Core-facing nets: cs_* = core s_axi (from upstream); cm_* = core m_axi (toward downstream)
  logic [AXI_ADDR_WIDTH-1:0]   cs_awaddr, cm_awaddr;
  logic [7:0]                 cs_awlen, cm_awlen;
  logic [2:0]                 cs_awsize, cm_awsize;
  logic [1:0]                 cs_awburst, cm_awburst;
  logic [AXI_ID_WIDTH-1:0]    cs_awid, cm_awid;
  logic [AXI_USER_WIDTH-1:0]  cs_awuser, cm_awuser;
  logic                       cs_awvalid, cm_awvalid;
  logic                       cs_awready, cm_awready;
  logic [AXI_DATA_WIDTH-1:0]  cs_wdata, cm_wdata;
  logic [(AXI_DATA_WIDTH/8)-1:0] cs_wstrb, cm_wstrb;
  logic                       cs_wlast, cm_wlast;
  logic [AXI_USER_WIDTH-1:0]  cs_wuser, cm_wuser;
  logic                       cs_wvalid, cm_wvalid;
  logic                       cs_wready, cm_wready;
  logic [AXI_ID_WIDTH-1:0]    cs_bid, cm_bid;
  logic [1:0]                cs_bresp, cm_bresp;
  logic [AXI_USER_WIDTH-1:0]  cs_buser, cm_buser;
  logic                       cs_bvalid, cm_bvalid;
  logic                       cs_bready, cm_bready;
  logic [AXI_ADDR_WIDTH-1:0]  cs_araddr, cm_araddr;
  logic [7:0]                 cs_arlen, cm_arlen;
  logic [2:0]                 cs_arsize, cm_arsize;
  logic [1:0]                 cs_arburst, cm_arburst;
  logic [AXI_ID_WIDTH-1:0]    cs_arid, cm_arid;
  logic [AXI_USER_WIDTH-1:0]  cs_aruser, cm_aruser;
  logic                       cs_arvalid, cm_arvalid;
  logic                       cs_arready, cm_arready;
  logic [AXI_ID_WIDTH-1:0]    cs_rid, cm_rid;
  logic [AXI_DATA_WIDTH-1:0] cs_rdata, cm_rdata;
  logic [1:0]                cs_rresp, cm_rresp;
  logic                       cs_rlast, cm_rlast;
  logic [AXI_USER_WIDTH-1:0]  cs_ruser, cm_ruser;
  logic                       cs_rvalid, cm_rvalid;
  logic                       cs_rready, cm_rready;

  generate
    if (USE_SLICE_UP) begin : g_sup
      axi_perf_monitor_slice #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .AXI_USER_WIDTH(AXI_USER_WIDTH),
        .USE_PIPELINE(1'b0)
      ) u_slice_up (
        .aclk(aclk), .aresetn(aresetn),
        .s_axi_awaddr (up_awaddr),  .m_axi_awaddr (cs_awaddr),
        .s_axi_awlen  (up_awlen),   .m_axi_awlen  (cs_awlen),
        .s_axi_awsize (up_awsize),  .m_axi_awsize (cs_awsize),
        .s_axi_awburst(up_awburst), .m_axi_awburst(cs_awburst),
        .s_axi_awid   (up_awid),    .m_axi_awid   (cs_awid),
        .s_axi_awuser (up_awuser),  .m_axi_awuser (cs_awuser),
        .s_axi_awvalid(up_awvalid), .m_axi_awvalid(cs_awvalid),
        .s_axi_awready(up_awready), .m_axi_awready(cs_awready),
        .s_axi_wdata  (up_wdata),   .m_axi_wdata  (cs_wdata),
        .s_axi_wstrb  (up_wstrb),   .m_axi_wstrb  (cs_wstrb),
        .s_axi_wlast  (up_wlast),   .m_axi_wlast  (cs_wlast),
        .s_axi_wuser  (up_wuser),   .m_axi_wuser  (cs_wuser),
        .s_axi_wvalid (up_wvalid),  .m_axi_wvalid (cs_wvalid),
        .s_axi_wready (up_wready),  .m_axi_wready (cs_wready),
        .s_axi_bid    (up_bid),     .m_axi_bid    (cs_bid),
        .s_axi_bresp  (up_bresp),   .m_axi_bresp  (cs_bresp),
        .s_axi_buser  (up_buser),   .m_axi_buser  (cs_buser),
        .s_axi_bvalid (up_bvalid),  .m_axi_bvalid (cs_bvalid),
        .s_axi_bready (up_bready),  .m_axi_bready (cs_bready),
        .s_axi_araddr (up_araddr),  .m_axi_araddr (cs_araddr),
        .s_axi_arlen  (up_arlen),   .m_axi_arlen  (cs_arlen),
        .s_axi_arsize (up_arsize),  .m_axi_arsize (cs_arsize),
        .s_axi_arburst(up_arburst), .m_axi_arburst(cs_arburst),
        .s_axi_arid   (up_arid),    .m_axi_arid   (cs_arid),
        .s_axi_aruser (up_aruser),  .m_axi_aruser (cs_aruser),
        .s_axi_arvalid(up_arvalid), .m_axi_arvalid(cs_arvalid),
        .s_axi_arready(up_arready), .m_axi_arready(cs_arready),
        .s_axi_rid    (up_rid),     .m_axi_rid    (cs_rid),
        .s_axi_rdata  (up_rdata),    .m_axi_rdata  (cs_rdata),
        .s_axi_rresp  (up_rresp),   .m_axi_rresp  (cs_rresp),
        .s_axi_rlast  (up_rlast),   .m_axi_rlast  (cs_rlast),
        .s_axi_ruser  (up_ruser),   .m_axi_ruser  (cs_ruser),
        .s_axi_rvalid (up_rvalid),  .m_axi_rvalid (cs_rvalid),
        .s_axi_rready (up_rready),  .m_axi_rready (cs_rready)
      );
    end else begin : g_nosup
      assign cs_awaddr  = up_awaddr;
      assign cs_awlen   = up_awlen;
      assign cs_awsize  = up_awsize;
      assign cs_awburst = up_awburst;
      assign cs_awid    = up_awid;
      assign cs_awuser  = up_awuser;
      assign cs_awvalid = up_awvalid;
      assign up_awready = cs_awready;
      assign cs_wdata   = up_wdata;
      assign cs_wstrb   = up_wstrb;
      assign cs_wlast   = up_wlast;
      assign cs_wuser   = up_wuser;
      assign cs_wvalid  = up_wvalid;
      assign up_wready  = cs_wready;
      assign up_bid     = cs_bid;
      assign up_bresp   = cs_bresp;
      assign up_buser   = cs_buser;
      assign up_bvalid  = cs_bvalid;
      assign cs_bready  = up_bready;
      assign cs_araddr  = up_araddr;
      assign cs_arlen   = up_arlen;
      assign cs_arsize  = up_arsize;
      assign cs_arburst = up_arburst;
      assign cs_arid    = up_arid;
      assign cs_aruser  = up_aruser;
      assign cs_arvalid = up_arvalid;
      assign up_arready = cs_arready;
      assign up_rid     = cs_rid;
      assign up_rdata   = cs_rdata;
      assign up_rresp   = cs_rresp;
      assign up_rlast   = cs_rlast;
      assign up_ruser   = cs_ruser;
      assign up_rvalid  = cs_rvalid;
      assign cs_rready  = up_rready;
    end

    if (USE_SLICE_DN) begin : g_sdn
      axi_perf_monitor_slice #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .AXI_USER_WIDTH(AXI_USER_WIDTH),
        .USE_PIPELINE(1'b0)
      ) u_slice_dn (
        .aclk(aclk), .aresetn(aresetn),
        .s_axi_awaddr (cm_awaddr),  .m_axi_awaddr (dn_awaddr),
        .s_axi_awlen  (cm_awlen),   .m_axi_awlen  (dn_awlen),
        .s_axi_awsize (cm_awsize),  .m_axi_awsize (dn_awsize),
        .s_axi_awburst(cm_awburst), .m_axi_awburst(dn_awburst),
        .s_axi_awid   (cm_awid),    .m_axi_awid   (dn_awid),
        .s_axi_awuser (cm_awuser),  .m_axi_awuser (dn_awuser),
        .s_axi_awvalid(cm_awvalid), .m_axi_awvalid(dn_awvalid),
        .s_axi_awready(cm_awready), .m_axi_awready(dn_awready),
        .s_axi_wdata  (cm_wdata),   .m_axi_wdata  (dn_wdata),
        .s_axi_wstrb  (cm_wstrb),   .m_axi_wstrb  (dn_wstrb),
        .s_axi_wlast  (cm_wlast),   .m_axi_wlast  (dn_wlast),
        .s_axi_wuser  (cm_wuser),   .m_axi_wuser  (dn_wuser),
        .s_axi_wvalid (cm_wvalid),  .m_axi_wvalid (dn_wvalid),
        .s_axi_wready (cm_wready),  .m_axi_wready (dn_wready),
        .s_axi_bid    (cm_bid),     .m_axi_bid    (dn_bid),
        .s_axi_bresp  (cm_bresp),   .m_axi_bresp  (dn_bresp),
        .s_axi_buser  (cm_buser),   .m_axi_buser  (dn_buser),
        .s_axi_bvalid (cm_bvalid),  .m_axi_bvalid (dn_bvalid),
        .s_axi_bready (cm_bready),  .m_axi_bready (dn_bready),
        .s_axi_araddr (cm_araddr),  .m_axi_araddr (dn_araddr),
        .s_axi_arlen  (cm_arlen),   .m_axi_arlen  (dn_arlen),
        .s_axi_arsize (cm_arsize),  .m_axi_arsize (dn_arsize),
        .s_axi_arburst(cm_arburst), .m_axi_arburst(dn_arburst),
        .s_axi_arid   (cm_arid),    .m_axi_arid   (dn_arid),
        .s_axi_aruser (cm_aruser),  .m_axi_aruser (dn_aruser),
        .s_axi_arvalid(cm_arvalid), .m_axi_arvalid(dn_arvalid),
        .s_axi_arready(cm_arready), .m_axi_arready(dn_arready),
        .s_axi_rid    (cm_rid),     .m_axi_rid    (dn_rid),
        .s_axi_rdata  (cm_rdata),    .m_axi_rdata  (dn_rdata),
        .s_axi_rresp  (cm_rresp),   .m_axi_rresp  (dn_rresp),
        .s_axi_rlast  (cm_rlast),   .m_axi_rlast  (dn_rlast),
        .s_axi_ruser  (cm_ruser),   .m_axi_ruser  (dn_ruser),
        .s_axi_rvalid (cm_rvalid),  .m_axi_rvalid (dn_rvalid),
        .s_axi_rready (cm_rready),  .m_axi_rready (dn_rready)
      );
    end else begin : g_nosdn
      assign dn_awaddr  = cm_awaddr;
      assign dn_awlen   = cm_awlen;
      assign dn_awsize  = cm_awsize;
      assign dn_awburst = cm_awburst;
      assign dn_awid    = cm_awid;
      assign dn_awuser  = cm_awuser;
      assign dn_awvalid = cm_awvalid;
      assign cm_awready = dn_awready;
      assign dn_wdata   = cm_wdata;
      assign dn_wstrb   = cm_wstrb;
      assign dn_wlast   = cm_wlast;
      assign dn_wuser   = cm_wuser;
      assign dn_wvalid  = cm_wvalid;
      assign cm_wready  = dn_wready;
      assign cm_bid     = dn_bid;
      assign cm_bresp   = dn_bresp;
      assign cm_buser   = dn_buser;
      assign cm_bvalid  = dn_bvalid;
      assign dn_bready  = cm_bready;
      assign dn_araddr  = cm_araddr;
      assign dn_arlen   = cm_arlen;
      assign dn_arsize  = cm_arsize;
      assign dn_arburst = cm_arburst;
      assign dn_arid    = cm_arid;
      assign dn_aruser  = cm_aruser;
      assign dn_arvalid = cm_arvalid;
      assign cm_arready = dn_arready;
      assign cm_rid     = dn_rid;
      assign cm_rdata   = dn_rdata;
      assign cm_rresp   = dn_rresp;
      assign cm_rlast   = dn_rlast;
      assign cm_ruser   = dn_ruser;
      assign cm_rvalid  = dn_rvalid;
      assign dn_rready  = cm_rready;
    end
  endgenerate

  axi_perf_monitor_core #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_USER_WIDTH(AXI_USER_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH),
    .TIME_WIDTH(TIME_WIDTH),
    .MAX_PENDING_PER_ID(MAX_PENDING_PER_ID)
  ) u_core (
    .aclk(aclk), .aresetn(aresetn),
    .psel(psel), .penable(penable), .pwrite(pwrite),
    .paddr(paddr), .pwdata(pwdata), .prdata(prdata), .pready(pready),
    .irq(irq),
    .s_axi_awaddr (cs_awaddr),  .m_axi_awaddr (cm_awaddr),
    .s_axi_awlen  (cs_awlen),   .m_axi_awlen  (cm_awlen),
    .s_axi_awsize (cs_awsize),  .m_axi_awsize (cm_awsize),
    .s_axi_awburst(cs_awburst), .m_axi_awburst(cm_awburst),
    .s_axi_awid   (cs_awid),    .m_axi_awid   (cm_awid),
    .s_axi_awuser (cs_awuser),  .m_axi_awuser (cm_awuser),
    .s_axi_awvalid(cs_awvalid), .m_axi_awvalid(cm_awvalid),
    .s_axi_awready(cs_awready), .m_axi_awready(cm_awready),
    .s_axi_wdata  (cs_wdata),   .m_axi_wdata  (cm_wdata),
    .s_axi_wstrb  (cs_wstrb),   .m_axi_wstrb  (cm_wstrb),
    .s_axi_wlast  (cs_wlast),   .m_axi_wlast  (cm_wlast),
    .s_axi_wuser  (cs_wuser),   .m_axi_wuser  (cm_wuser),
    .s_axi_wvalid (cs_wvalid),  .m_axi_wvalid (cm_wvalid),
    .s_axi_wready (cs_wready),  .m_axi_wready (cm_wready),
    .s_axi_bid    (cs_bid),     .m_axi_bid    (cm_bid),
    .s_axi_bresp  (cs_bresp),   .m_axi_bresp  (cm_bresp),
    .s_axi_buser  (cs_buser),   .m_axi_buser  (cm_buser),
    .s_axi_bvalid (cs_bvalid),  .m_axi_bvalid (cm_bvalid),
    .s_axi_bready (cs_bready),  .m_axi_bready (cm_bready),
    .s_axi_araddr (cs_araddr),  .m_axi_araddr (cm_araddr),
    .s_axi_arlen  (cs_arlen),   .m_axi_arlen  (cm_arlen),
    .s_axi_arsize (cs_arsize),  .m_axi_arsize (cm_arsize),
    .s_axi_arburst(cs_arburst), .m_axi_arburst(cm_arburst),
    .s_axi_arid   (cs_arid),    .m_axi_arid   (cm_arid),
    .s_axi_aruser (cs_aruser),  .m_axi_aruser (cm_aruser),
    .s_axi_arvalid(cs_arvalid), .m_axi_arvalid(cm_arvalid),
    .s_axi_arready(cs_arready), .m_axi_arready(cm_arready),
    .s_axi_rid    (cs_rid),     .m_axi_rid    (cm_rid),
    .s_axi_rdata  (cs_rdata),    .m_axi_rdata  (cm_rdata),
    .s_axi_rresp  (cs_rresp),   .m_axi_rresp  (cm_rresp),
    .s_axi_rlast  (cs_rlast),   .m_axi_rlast  (cm_rlast),
    .s_axi_ruser  (cs_ruser),   .m_axi_ruser  (cm_ruser),
    .s_axi_rvalid (cs_rvalid),  .m_axi_rvalid (cm_rvalid),
    .s_axi_rready (cs_rready),  .m_axi_rready (cm_rready)
  );

endmodule
