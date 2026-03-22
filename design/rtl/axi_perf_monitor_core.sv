// AXI performance monitor — datapath + CSR + logging + throttle
// Sample FIFO: raw bytes, latency sums/counts, period cycles/txns (no dividers).
`timescale 1ns/1ps

import axi_perf_monitor_pkg::*;

module axi_perf_monitor_core #(
  parameter int AXI_ADDR_WIDTH   = 64,
  parameter int AXI_DATA_WIDTH   = 256,
  parameter int AXI_ID_WIDTH     = 8,
  parameter int AXI_USER_WIDTH   = 1,
  parameter int FIFO_DEPTH       = 32,
  parameter int TIME_WIDTH       = 32,
  parameter int MAX_PENDING_PER_ID = 8
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

  localparam int PID   = 1 << AXI_ID_WIDTH;
  localparam int PTRW  = $clog2(FIFO_DEPTH);
  localparam int SAMPLE_W = 480;

  localparam logic [15:0] OFF_CTRL           = 16'h0000;
  localparam logic [15:0] OFF_BW_EN          = 16'h0004;
  localparam logic [15:0] OFF_LAT_EN         = 16'h0008;
  localparam logic [15:0] OFF_THR_EN         = 16'h000C;
  localparam logic [15:0] OFF_PERIOD_MODE    = 16'h0010;
  localparam logic [15:0] OFF_PERIOD_VAL     = 16'h0014;
  localparam logic [15:0] OFF_N_SWITCH       = 16'h0018;
  localparam logic [15:0] OFF_INT_EN         = 16'h001C;
  localparam logic [15:0] OFF_INT_CLR        = 16'h0020;
  localparam logic [15:0] OFF_ADDR_START_LO  = 16'h0024;
  localparam logic [15:0] OFF_ADDR_START_HI  = 16'h0028;
  localparam logic [15:0] OFF_ADDR_SIZE_LO   = 16'h002C;
  localparam logic [15:0] OFF_ADDR_SIZE_HI   = 16'h0030;
  localparam logic [15:0] OFF_THR_PERIOD     = 16'h0034;
  localparam logic [15:0] OFF_THR_MAX_BYTES  = 16'h0038;
  localparam logic [15:0] OFF_THR_AW_DELAY   = 16'h003C;
  localparam logic [15:0] OFF_THR_AR_DELAY    = 16'h0040;
  localparam logic [15:0] OFF_STATUS         = 16'h0044;
  localparam logic [15:0] OFF_SAMPLE_EVEN_POP = 16'h0048;
  localparam logic [15:0] OFF_SAMPLE_ODD_POP  = 16'h004C;
  localparam logic [15:0] OFF_SHADOW_BASE    = 16'h0050;
  localparam logic [15:0] OFF_SHADOW_LAST    = 16'h008C;
  localparam logic [15:0] OFF_FIFO_FLUSH     = 16'h0090;

  logic [31:0] r_ctrl;
  logic [31:0] r_bw_en, r_lat_en, r_thr_en;
  logic [31:0] r_period_mode;
  logic [31:0] r_period_val;
  logic [31:0] r_n_switch;
  logic [31:0] r_int_en;
  logic [31:0] r_addr_start_lo, r_addr_start_hi;
  logic [31:0] r_addr_size_lo, r_addr_size_hi;
  logic [31:0] r_thr_period;
  logic [31:0] r_thr_max_bytes;
  logic [31:0] r_thr_aw_delay;
  logic [31:0] r_thr_ar_delay;

  logic        irq_pending;
  logic        irq_pulse;

  wire csr_module_en      = r_ctrl[0];
  wire csr_sw_rst         = r_ctrl[1];
  wire csr_addr_filter_en = r_ctrl[2];
  wire csr_bw_en          = r_bw_en[0];
  wire csr_lat_en         = r_lat_en[0];
  wire csr_thr_en         = r_thr_en[0];
  wire csr_period_mode    = r_period_mode[0];
  wire [31:0] csr_period_val = (r_period_val == 32'd0) ? 32'd1 : r_period_val;
  wire [31:0] csr_n_switch   = (r_n_switch == 32'd0) ? 32'd1 : r_n_switch;
  wire        csr_int_en     = r_int_en[0];
  wire [63:0] csr_addr_start = {r_addr_start_hi, r_addr_start_lo};
  wire [63:0] csr_addr_size  = {r_addr_size_hi, r_addr_size_lo};
  wire [31:0] csr_thr_period = (r_thr_period == 32'd0) ? 32'd1 : r_thr_period;

  logic [TIME_WIDTH-1:0] time_ctr;

  function automatic logic addr_ok(input logic [63:0] a);
    if (!csr_addr_filter_en) return 1'b1;
    if (csr_addr_size == 64'd0) return 1'b0;
    return addr_in_range(a, csr_addr_start, csr_addr_size);
  endfunction

  function automatic logic addr_ok_thr(input logic [63:0] a);
    if (csr_addr_size == 64'd0) return 1'b0;
    return addr_in_range(a, csr_addr_start, csr_addr_size);
  endfunction

  logic [31:0] thr_ctr;
  logic [63:0] thr_bytes;
  logic        thr_apply_reg;

  logic [15:0] aw_gap_cnt;
  logic [15:0] ar_gap_cnt;
  wire         aw_gap_block = (aw_gap_cnt != 16'd0);
  wire         ar_gap_block = (ar_gap_cnt != 16'd0);

  assign m_axi_awaddr  = s_axi_awaddr;
  assign m_axi_awlen   = s_axi_awlen;
  assign m_axi_awsize  = s_axi_awsize;
  assign m_axi_awburst = s_axi_awburst;
  assign m_axi_awid    = s_axi_awid;
  assign m_axi_awuser  = s_axi_awuser;
  assign m_axi_wdata   = s_axi_wdata;
  assign m_axi_wstrb   = s_axi_wstrb;
  assign m_axi_wlast   = s_axi_wlast;
  assign m_axi_wuser   = s_axi_wuser;
  assign m_axi_araddr  = s_axi_araddr;
  assign m_axi_arlen   = s_axi_arlen;
  assign m_axi_arsize  = s_axi_arsize;
  assign m_axi_arburst = s_axi_arburst;
  assign m_axi_arid    = s_axi_arid;
  assign m_axi_aruser  = s_axi_aruser;

  assign m_axi_awvalid = s_axi_awvalid;
  assign m_axi_wvalid  = s_axi_wvalid;
  assign m_axi_arvalid = s_axi_arvalid;

  assign s_axi_bid    = m_axi_bid;
  assign s_axi_bresp  = m_axi_bresp;
  assign s_axi_buser  = m_axi_buser;
  assign s_axi_bvalid = m_axi_bvalid;
  assign m_axi_bready = s_axi_bready;

  assign s_axi_rid    = m_axi_rid;
  assign s_axi_rdata  = m_axi_rdata;
  assign s_axi_rresp  = m_axi_rresp;
  assign s_axi_rlast  = m_axi_rlast;
  assign s_axi_ruser  = m_axi_ruser;
  assign s_axi_rvalid = m_axi_rvalid;
  assign m_axi_rready = s_axi_rready;

  wire aw_hand = s_axi_awvalid && s_axi_awready;
  wire ar_hand = s_axi_arvalid && s_axi_arready;
  wire b_hand  = s_axi_bvalid  && s_axi_bready;
  wire r_hand  = s_axi_rvalid  && s_axi_rready;

  assign s_axi_awready = m_axi_awready & !aw_gap_block & csr_module_en;
  assign s_axi_arready = m_axi_arready & !ar_gap_block & csr_module_en;

  wire log_en = csr_module_en & (csr_bw_en | csr_lat_en);

  logic [31:0] period_cycle_ctr;
  logic [31:0] period_txn_ctr;
  logic [31:0] period_elapsed_cycles;
  logic [31:0] n_period_ctr;
  logic        write_bank;
  logic        last_int_bank;

  wire aw_trk = aw_hand && addr_ok(s_axi_awaddr);
  wire ar_trk = ar_hand && addr_ok(s_axi_araddr);
  wire [31:0] txn_inc = (aw_trk ? 32'd1 : 32'd0) + (ar_trk ? 32'd1 : 32'd0);
  wire [31:0] txn_next = period_txn_ctr + txn_inc;

  wire period_end_cycle = log_en & !csr_period_mode &
    (period_cycle_ctr == csr_period_val - 32'd1);
  wire period_end_txn   = log_en & csr_period_mode & (txn_next >= csr_period_val);
  wire period_end = period_end_cycle | period_end_txn;

  logic [63:0] acc_wr_bytes;
  logic [63:0] acc_rd_bytes;

  logic [63:0] lat_sum_wr;
  logic [63:0] lat_sum_rf;
  logic [63:0] lat_sum_rl;
  logic [31:0] lat_cnt_wr;
  logic [31:0] lat_cnt_rf;
  logic [31:0] lat_cnt_rl;

  logic [SAMPLE_W-1:0] sample_even [0:FIFO_DEPTH-1];
  logic [SAMPLE_W-1:0] sample_odd  [0:FIFO_DEPTH-1];
  logic [PTRW-1:0] smp_wptr_e, smp_rptr_e;
  logic [PTRW-1:0] smp_wptr_o, smp_rptr_o;
  logic sample_ovf;

  logic [31:0] sh_word [0:14];

  typedef struct packed {
    logic [TIME_WIDTH-1:0] t;
  } aw_ent_t;
  aw_ent_t aw_q [PID-1:0][MAX_PENDING_PER_ID-1:0];
  logic [$clog2(MAX_PENDING_PER_ID+1)-1:0] aw_qlen [PID-1:0];

  typedef struct packed {
    logic [TIME_WIDTH-1:0] t_ar;
    logic [7:0]            beats_total;
    logic [7:0]            beats_rem;
  } rd_ent_t;
  rd_ent_t ar_q [PID-1:0][MAX_PENDING_PER_ID-1:0];
  logic [$clog2(MAX_PENDING_PER_ID+1)-1:0] ar_qlen [PID-1:0];

  function automatic logic fifo_full(input logic [PTRW-1:0] w,
                                     input logic [PTRW-1:0] r);
    logic [PTRW-1:0] wn;
    wn = w + PTRW'(1);
    return (wn == r);
  endfunction

  wire [63:0] aw_bytes = burst_bytes(s_axi_awsize, s_axi_awlen);
  wire [63:0] ar_bytes = burst_bytes(s_axi_arsize, s_axi_arlen);

  wire [31:0] snap_period_cycles = csr_period_mode ? (period_elapsed_cycles + 32'd1) : csr_period_val;
  wire [31:0] snap_period_txns   = txn_next;

  wire [SAMPLE_W-1:0] push_packed =
    { snap_period_txns, snap_period_cycles,
      lat_cnt_rl, lat_sum_rl, lat_cnt_rf, lat_sum_rf,
      lat_cnt_wr, lat_sum_wr, acc_rd_bytes, acc_wr_bytes };

  integer ii, jj;
  int unsigned bi;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      time_ctr <= '0;
      thr_ctr <= 32'd0;
      thr_bytes <= '0;
      thr_apply_reg <= 1'b0;
      aw_gap_cnt <= 16'd0;
      ar_gap_cnt <= 16'd0;
      period_cycle_ctr <= 32'd0;
      period_txn_ctr <= 32'd0;
      period_elapsed_cycles <= 32'd0;
      n_period_ctr <= 32'd0;
      acc_wr_bytes <= 64'd0;
      acc_rd_bytes <= 64'd0;
      lat_sum_wr <= 64'd0;
      lat_sum_rf <= 64'd0;
      lat_sum_rl <= 64'd0;
      lat_cnt_wr <= 32'd0;
      lat_cnt_rf <= 32'd0;
      lat_cnt_rl <= 32'd0;
      smp_wptr_e <= '0; smp_rptr_e <= '0;
      smp_wptr_o <= '0; smp_rptr_o <= '0;
      sample_ovf <= 1'b0;
      write_bank <= 1'b0;
      last_int_bank <= 1'b0;
      irq_pending <= 1'b0;
      irq_pulse <= 1'b0;
      r_ctrl <= 32'h0;
      r_bw_en <= 32'h0;
      r_lat_en <= 32'h0;
      r_thr_en <= 32'h0;
      r_period_mode <= 32'h0;
      r_period_val <= 32'd1000;
      r_n_switch <= 32'd8;
      r_int_en <= 32'h0;
      r_addr_start_lo <= '0;
      r_addr_start_hi <= '0;
      r_addr_size_lo <= '0;
      r_addr_size_hi <= '0;
      r_thr_period <= 32'd1000;
      r_thr_max_bytes <= 32'hFFFF_FFFF;
      r_thr_aw_delay <= 32'd0;
      r_thr_ar_delay <= 32'd0;
      for (ii = 0; ii < PID; ii++) begin
        aw_qlen[ii] <= '0;
        ar_qlen[ii] <= '0;
        for (jj = 0; jj < MAX_PENDING_PER_ID; jj++) begin
          aw_q[ii][jj] <= '0;
          ar_q[ii][jj] <= '0;
        end
      end
    end else begin
      irq_pulse <= 1'b0;
      time_ctr <= time_ctr + 1'b1;

      if (csr_sw_rst) begin
        period_cycle_ctr <= 32'd0;
        period_txn_ctr <= 32'd0;
        period_elapsed_cycles <= 32'd0;
        n_period_ctr <= 32'd0;
        acc_wr_bytes <= 64'd0;
        acc_rd_bytes <= 64'd0;
        lat_sum_wr <= 64'd0;
        lat_sum_rf <= 64'd0;
        lat_sum_rl <= 64'd0;
        lat_cnt_wr <= 32'd0;
        lat_cnt_rf <= 32'd0;
        lat_cnt_rl <= 32'd0;
        thr_bytes <= 64'd0;
        thr_ctr <= 32'd0;
      end

      if (csr_module_en && csr_thr_en) begin
        if (thr_ctr == csr_thr_period - 32'd1) begin
          thr_ctr <= 32'd0;
          thr_apply_reg <= (thr_bytes > {32'd0, r_thr_max_bytes});
          thr_bytes <= 64'd0;
        end else begin
          thr_ctr <= thr_ctr + 32'd1;
        end
      end else begin
        thr_ctr <= 32'd0;
        thr_bytes <= 64'd0;
        thr_apply_reg <= 1'b0;
      end

      if (csr_module_en && csr_thr_en) begin
        if (aw_hand && addr_ok_thr(s_axi_awaddr))
          thr_bytes <= thr_bytes + aw_bytes;
        if (ar_hand && addr_ok_thr(s_axi_araddr))
          thr_bytes <= thr_bytes + ar_bytes;
      end

      if (aw_gap_cnt != 16'd0)
        aw_gap_cnt <= aw_gap_cnt - 16'd1;
      if (csr_module_en && csr_thr_en && thr_apply_reg && aw_hand)
        aw_gap_cnt <= r_thr_aw_delay[15:0];

      if (ar_gap_cnt != 16'd0)
        ar_gap_cnt <= ar_gap_cnt - 16'd1;
      if (csr_module_en && csr_thr_en && thr_apply_reg && ar_hand)
        ar_gap_cnt <= r_thr_ar_delay[15:0];

      if (log_en && !csr_period_mode) begin
        if (period_end_cycle) period_cycle_ctr <= 32'd0;
        else period_cycle_ctr <= period_cycle_ctr + 32'd1;
      end else if (!log_en || csr_period_mode) begin
        period_cycle_ctr <= 32'd0;
      end

      if (log_en && period_end) begin
        period_elapsed_cycles <= 32'd0;
      end else if (log_en) begin
        period_elapsed_cycles <= period_elapsed_cycles + 32'd1;
      end else begin
        period_elapsed_cycles <= 32'd0;
      end

      if (log_en) begin
        if (aw_trk) acc_wr_bytes <= acc_wr_bytes + aw_bytes;
        if (ar_trk) acc_rd_bytes <= acc_rd_bytes + ar_bytes;
      end
      if (log_en && period_end) begin
        period_txn_ctr <= 32'd0;
      end else if (log_en) begin
        period_txn_ctr <= txn_next;
      end else begin
        period_txn_ctr <= 32'd0;
      end

      if (csr_module_en && csr_lat_en && aw_hand && addr_ok(s_axi_awaddr)) begin
        bi = s_axi_awid;
        if (aw_qlen[bi] != MAX_PENDING_PER_ID) begin
          aw_q[bi][aw_qlen[bi]].t <= time_ctr;
          aw_qlen[bi] <= aw_qlen[bi] + 1'b1;
        end else sample_ovf <= 1'b1;
      end

      if (csr_module_en && csr_lat_en && b_hand) begin
        bi = s_axi_bid;
        if (aw_qlen[bi] != 0) begin
          lat_sum_wr <= lat_sum_wr + (64'(time_ctr) - 64'(aw_q[bi][0].t));
          lat_cnt_wr <= lat_cnt_wr + 32'd1;
          for (jj = 0; jj < MAX_PENDING_PER_ID-1; jj++)
            aw_q[bi][jj] <= aw_q[bi][jj+1];
          aw_qlen[bi] <= aw_qlen[bi] - 1'b1;
        end
      end

      if (csr_module_en && csr_lat_en && ar_hand && addr_ok(s_axi_araddr)) begin
        bi = s_axi_arid;
        if (ar_qlen[bi] != MAX_PENDING_PER_ID) begin
          ar_q[bi][ar_qlen[bi]] <= '{t_ar: time_ctr,
            beats_total: s_axi_arlen + 8'd1, beats_rem: s_axi_arlen + 8'd1};
          ar_qlen[bi] <= ar_qlen[bi] + 1'b1;
        end else sample_ovf <= 1'b1;
      end

      if (csr_module_en && csr_lat_en && r_hand) begin
        bi = s_axi_rid;
        if (ar_qlen[bi] != 0) begin
          if (ar_q[bi][0].beats_rem == ar_q[bi][0].beats_total) begin
            lat_sum_rf <= lat_sum_rf + (64'(time_ctr) - 64'(ar_q[bi][0].t_ar));
            lat_cnt_rf <= lat_cnt_rf + 32'd1;
          end
          if (ar_q[bi][0].beats_rem == 8'd1) begin
            lat_sum_rl <= lat_sum_rl + (64'(time_ctr) - 64'(ar_q[bi][0].t_ar));
            lat_cnt_rl <= lat_cnt_rl + 32'd1;
            for (jj = 0; jj < MAX_PENDING_PER_ID-1; jj++)
              ar_q[bi][jj] <= ar_q[bi][jj+1];
            ar_qlen[bi] <= ar_qlen[bi] - 1'b1;
          end else begin
            ar_q[bi][0] <= '{
              t_ar: ar_q[bi][0].t_ar,
              beats_total: ar_q[bi][0].beats_total,
              beats_rem: ar_q[bi][0].beats_rem - 8'd1
            };
          end
        end
      end

      if (log_en && period_end) begin
        if (write_bank == 1'b0) begin
          if (!fifo_full(smp_wptr_e, smp_rptr_e)) begin
            sample_even[smp_wptr_e] <= push_packed;
            smp_wptr_e <= smp_wptr_e + PTRW'(1);
          end else sample_ovf <= 1'b1;
        end else begin
          if (!fifo_full(smp_wptr_o, smp_rptr_o)) begin
            sample_odd[smp_wptr_o] <= push_packed;
            smp_wptr_o <= smp_wptr_o + PTRW'(1);
          end else sample_ovf <= 1'b1;
        end

        acc_wr_bytes <= 64'd0;
        acc_rd_bytes <= 64'd0;
        lat_sum_wr <= 64'd0;
        lat_sum_rf <= 64'd0;
        lat_sum_rl <= 64'd0;
        lat_cnt_wr <= 32'd0;
        lat_cnt_rf <= 32'd0;
        lat_cnt_rl <= 32'd0;

        if (n_period_ctr == csr_n_switch - 32'd1) begin
          n_period_ctr <= 32'd0;
          last_int_bank <= write_bank;
          write_bank <= ~write_bank;
          irq_pulse <= csr_int_en;
        end else begin
          n_period_ctr <= n_period_ctr + 32'd1;
        end
      end

      if (irq_pulse) irq_pending <= 1'b1;
      if (psel && penable && pwrite && (paddr == OFF_INT_CLR) && pwdata[0])
        irq_pending <= 1'b0;

      if (psel && penable && pwrite) begin
        unique case (paddr)
          OFF_CTRL: begin
            r_ctrl[0] <= pwdata[0];
            r_ctrl[1] <= pwdata[1];
            r_ctrl[2] <= pwdata[2];
          end
          OFF_BW_EN:  r_bw_en[0] <= pwdata[0];
          OFF_LAT_EN: r_lat_en[0] <= pwdata[0];
          OFF_THR_EN: r_thr_en[0] <= pwdata[0];
          OFF_PERIOD_MODE: r_period_mode[0] <= pwdata[0];
          OFF_PERIOD_VAL:  r_period_val <= pwdata;
          OFF_N_SWITCH:    r_n_switch <= pwdata;
          OFF_INT_EN:      r_int_en[0] <= pwdata[0];
          OFF_ADDR_START_LO: r_addr_start_lo <= pwdata;
          OFF_ADDR_START_HI: r_addr_start_hi <= pwdata;
          OFF_ADDR_SIZE_LO:  r_addr_size_lo <= pwdata;
          OFF_ADDR_SIZE_HI:  r_addr_size_hi <= pwdata;
          OFF_THR_PERIOD:    r_thr_period <= pwdata;
          OFF_THR_MAX_BYTES: r_thr_max_bytes <= pwdata;
          OFF_THR_AW_DELAY:  r_thr_aw_delay <= pwdata;
          OFF_THR_AR_DELAY:  r_thr_ar_delay <= pwdata;
          OFF_FIFO_FLUSH: begin
            if (pwdata[0]) smp_wptr_e <= smp_rptr_e;
            if (pwdata[1]) smp_wptr_o <= smp_rptr_o;
          end
          default: ;
        endcase
      end
    end
  end

  assign irq = irq_pending & csr_int_en;

  assign pready = psel & penable;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      prdata <= 32'h0;
      sh_word[0]  <= 32'h0; sh_word[1]  <= 32'h0; sh_word[2]  <= 32'h0;
      sh_word[3]  <= 32'h0; sh_word[4]  <= 32'h0; sh_word[5]  <= 32'h0;
      sh_word[6]  <= 32'h0; sh_word[7]  <= 32'h0; sh_word[8]  <= 32'h0;
      sh_word[9]  <= 32'h0; sh_word[10] <= 32'h0; sh_word[11] <= 32'h0;
      sh_word[12] <= 32'h0; sh_word[13] <= 32'h0; sh_word[14] <= 32'h0;
    end else if (psel && penable && !pwrite) begin
      unique case (paddr)
        OFF_CTRL:          prdata <= r_ctrl;
        OFF_BW_EN:         prdata <= r_bw_en;
        OFF_LAT_EN:        prdata <= r_lat_en;
        OFF_THR_EN:        prdata <= r_thr_en;
        OFF_PERIOD_MODE:   prdata <= r_period_mode;
        OFF_PERIOD_VAL:    prdata <= r_period_val;
        OFF_N_SWITCH:      prdata <= r_n_switch;
        OFF_INT_EN:        prdata <= r_int_en;
        OFF_INT_CLR:       prdata <= 32'h0;
        OFF_ADDR_START_LO: prdata <= r_addr_start_lo;
        OFF_ADDR_START_HI: prdata <= r_addr_start_hi;
        OFF_ADDR_SIZE_LO:  prdata <= r_addr_size_lo;
        OFF_ADDR_SIZE_HI:  prdata <= r_addr_size_hi;
        OFF_THR_PERIOD:    prdata <= r_thr_period;
        OFF_THR_MAX_BYTES: prdata <= r_thr_max_bytes;
        OFF_THR_AW_DELAY:  prdata <= r_thr_aw_delay;
        OFF_THR_AR_DELAY:  prdata <= r_thr_ar_delay;
        OFF_FIFO_FLUSH:    prdata <= 32'h0;
        OFF_STATUS:        prdata <= {28'd0, sample_ovf, last_int_bank, write_bank};
        OFF_SAMPLE_EVEN_POP: begin
          if (smp_rptr_e != smp_wptr_e) begin
            begin
              automatic logic [SAMPLE_W-1:0] ent;
              automatic int sk;
              ent = sample_even[smp_rptr_e];
              for (sk = 0; sk < 15; sk++)
                sh_word[sk] = ent[32*sk +: 32];
            end
            prdata <= sample_even[smp_rptr_e][31:0];
            smp_rptr_e <= smp_rptr_e + PTRW'(1);
          end else prdata <= 32'h0;
        end
        OFF_SAMPLE_ODD_POP: begin
          if (smp_rptr_o != smp_wptr_o) begin
            begin
              automatic logic [SAMPLE_W-1:0] ent;
              automatic int sk;
              ent = sample_odd[smp_rptr_o];
              for (sk = 0; sk < 15; sk++)
                sh_word[sk] = ent[32*sk +: 32];
            end
            prdata <= sample_odd[smp_rptr_o][31:0];
            smp_rptr_o <= smp_rptr_o + PTRW'(1);
          end else prdata <= 32'h0;
        end
        default: begin
          if (paddr >= OFF_SHADOW_BASE && paddr <= OFF_SHADOW_LAST && ((paddr - OFF_SHADOW_BASE) & 16'h3) == 16'h0) begin
            prdata <= sh_word[(paddr - OFF_SHADOW_BASE) >> 2];
          end else prdata <= 32'hBAD0_C0DE;
        end
      endcase
    end
  end

`ifdef AXI_PERF_MONITOR_ASSERT
  always_ff @(posedge aclk) begin
    if (aresetn && r_n_switch != 32'd0) begin
      assert (r_n_switch < FIFO_DEPTH) else
        $error("N_SWITCH must be < FIFO_DEPTH");
    end
  end
`endif

endmodule
