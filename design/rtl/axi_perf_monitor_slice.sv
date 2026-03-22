//-----------------------------------------------------------------------------
// axi_perf_monitor_slice.sv
//
// AXI4 register slice: combinational pass-through (optional pipeline parameter).
// For timing closure, swap in a vendor axi_register_slice with the same port list
// or extend with full skid buffers.
//
// Designed by Jongchul Shin, Coded by Cursor
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module axi_perf_monitor_slice #(
  parameter int AXI_ADDR_WIDTH = 64,
  parameter int AXI_DATA_WIDTH = 256,
  parameter int AXI_ID_WIDTH   = 8,
  parameter int AXI_USER_WIDTH = 1,
  parameter bit USE_PIPELINE   = 1'b0
)(
  input  logic aclk,
  input  logic aresetn,
  input  logic [AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
  input  logic [7:0]                 s_axi_awlen,
  input  logic [2:0]                 s_axi_awsize,
  input  logic [1:0]                 s_axi_awburst,
  input  logic [AXI_ID_WIDTH-1:0]    s_axi_awid,
  input  logic [AXI_USER_WIDTH-1:0]  s_axi_awuser,
  input  logic                       s_axi_awvalid,
  output logic                       s_axi_awready,
  input  logic [AXI_DATA_WIDTH-1:0]  s_axi_wdata,
  input  logic [(AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
  input  logic                       s_axi_wlast,
  input  logic [AXI_USER_WIDTH-1:0]  s_axi_wuser,
  input  logic                       s_axi_wvalid,
  output logic                       s_axi_wready,
  output logic [AXI_ID_WIDTH-1:0]    s_axi_bid,
  output logic [1:0]                s_axi_bresp,
  output logic [AXI_USER_WIDTH-1:0]  s_axi_buser,
  output logic                       s_axi_bvalid,
  input  logic                       s_axi_bready,
  input  logic [AXI_ADDR_WIDTH-1:0]  s_axi_araddr,
  input  logic [7:0]                 s_axi_arlen,
  input  logic [2:0]                 s_axi_arsize,
  input  logic [1:0]                 s_axi_arburst,
  input  logic [AXI_ID_WIDTH-1:0]    s_axi_arid,
  input  logic [AXI_USER_WIDTH-1:0]  s_axi_aruser,
  input  logic                       s_axi_arvalid,
  output logic                       s_axi_arready,
  output logic [AXI_ID_WIDTH-1:0]    s_axi_rid,
  output logic [AXI_DATA_WIDTH-1:0] s_axi_rdata,
  output logic [1:0]                s_axi_rresp,
  output logic                       s_axi_rlast,
  output logic [AXI_USER_WIDTH-1:0]  s_axi_ruser,
  output logic                       s_axi_rvalid,
  input  logic                       s_axi_rready,
  output logic [AXI_ADDR_WIDTH-1:0]   m_axi_awaddr,
  output logic [7:0]                 m_axi_awlen,
  output logic [2:0]                 m_axi_awsize,
  output logic [1:0]                 m_axi_awburst,
  output logic [AXI_ID_WIDTH-1:0]    m_axi_awid,
  output logic [AXI_USER_WIDTH-1:0]  m_axi_awuser,
  output logic                       m_axi_awvalid,
  input  logic                       m_axi_awready,
  output logic [AXI_DATA_WIDTH-1:0]  m_axi_wdata,
  output logic [(AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb,
  output logic                       m_axi_wlast,
  output logic [AXI_USER_WIDTH-1:0]  m_axi_wuser,
  output logic                       m_axi_wvalid,
  input  logic                       m_axi_wready,
  input  logic [AXI_ID_WIDTH-1:0]    m_axi_bid,
  input  logic [1:0]                m_axi_bresp,
  input  logic [AXI_USER_WIDTH-1:0]  m_axi_buser,
  input  logic                       m_axi_bvalid,
  output logic                       m_axi_bready,
  output logic [AXI_ADDR_WIDTH-1:0]  m_axi_araddr,
  output logic [7:0]                 m_axi_arlen,
  output logic [2:0]                 m_axi_arsize,
  output logic [1:0]                 m_axi_arburst,
  output logic [AXI_ID_WIDTH-1:0]    m_axi_arid,
  output logic [AXI_USER_WIDTH-1:0]  m_axi_aruser,
  output logic                       m_axi_arvalid,
  input  logic                       m_axi_arready,
  input  logic [AXI_ID_WIDTH-1:0]    m_axi_rid,
  input  logic [AXI_DATA_WIDTH-1:0] m_axi_rdata,
  input  logic [1:0]                m_axi_rresp,
  input  logic                       m_axi_rlast,
  input  logic [AXI_USER_WIDTH-1:0]  m_axi_ruser,
  input  logic                       m_axi_rvalid,
  output logic                       m_axi_rready
);

  // USE_PIPELINE reserved for drop-in vendor slice; default combinational.
  wire _unused = USE_PIPELINE;

  assign m_axi_awaddr  = s_axi_awaddr;
  assign m_axi_awlen   = s_axi_awlen;
  assign m_axi_awsize  = s_axi_awsize;
  assign m_axi_awburst = s_axi_awburst;
  assign m_axi_awid    = s_axi_awid;
  assign m_axi_awuser  = s_axi_awuser;
  assign m_axi_awvalid = s_axi_awvalid;
  assign s_axi_awready = m_axi_awready;

  assign m_axi_wdata  = s_axi_wdata;
  assign m_axi_wstrb  = s_axi_wstrb;
  assign m_axi_wlast  = s_axi_wlast;
  assign m_axi_wuser  = s_axi_wuser;
  assign m_axi_wvalid = s_axi_wvalid;
  assign s_axi_wready = m_axi_wready;

  assign s_axi_bid   = m_axi_bid;
  assign s_axi_bresp = m_axi_bresp;
  assign s_axi_buser = m_axi_buser;
  assign s_axi_bvalid= m_axi_bvalid;
  assign m_axi_bready= s_axi_bready;

  assign m_axi_araddr  = s_axi_araddr;
  assign m_axi_arlen   = s_axi_arlen;
  assign m_axi_arsize  = s_axi_arsize;
  assign m_axi_arburst = s_axi_arburst;
  assign m_axi_arid    = s_axi_arid;
  assign m_axi_aruser  = s_axi_aruser;
  assign m_axi_arvalid = s_axi_arvalid;
  assign s_axi_arready = m_axi_arready;

  assign s_axi_rid   = m_axi_rid;
  assign s_axi_rdata = m_axi_rdata;
  assign s_axi_rresp = m_axi_rresp;
  assign s_axi_rlast = m_axi_rlast;
  assign s_axi_ruser = m_axi_ruser;
  assign s_axi_rvalid= m_axi_rvalid;
  assign m_axi_rready= s_axi_rready;

endmodule
