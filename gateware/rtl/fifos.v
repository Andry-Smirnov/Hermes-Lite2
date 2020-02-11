
module dsiq_fifo (
  wr_clk,
  wr_tdata,
  wr_tvalid,
  wr_tready,
  wr_tlast,

  rd_clk,
  rd_tdata,
  rd_tvalid,
  rd_tready,
  rd_sample,
  rd_status,
  rd_msec_pulse
);

input         wr_clk;
input [8:0]   wr_tdata;
input         wr_tvalid;
output        wr_tready;
input         wr_tlast;

input         rd_clk;
output [35:0] rd_tdata;
output        rd_tvalid;
input         rd_tready;
input         rd_sample;
output [7:0]  rd_status;
input         rd_msec_pulse;

parameter     depth   = 8192;

// Write and read limite at 8 ms,
localparam    wrbits  = (depth == 16384) ? 14 : 13;
// Start to allow push again when 1/4 full (10ms) to accomodate software
// that sends 20ms at a time
localparam    wrlimit = (depth == 16384) ? 14'h1000 : 13'h0800;

localparam    rdbits  = (depth == 16384) ? 12 : 11;
// Start to allow pop when 1/8 full 5ms
localparam    rdlimit = (depth == 16384) ? 12'h0200 : 11'h0100;

logic [35:0]  ird_tdata;

logic         wr_treadyn;
logic         rd_tvalidn;

logic         allow_push = 1'b1;
logic [(wrbits-1):0]  wr_tlength;

logic         allow_pop  = 1'b0;
logic [(rdbits-1):0]  rd_tlength;

logic   [6:0] rd_count = 7'h00;
logic         recovery_flag, recovery_flag_d1;

logic [2:0]   msec_cnt = 3'h4;

// If FIFO fills, drop write data
// again until only half full
always @ (posedge wr_clk) begin
  if (wr_treadyn) begin
    allow_push <= 1'b0;
  end else if (wr_tlast & (wr_tlength <= wrlimit)) begin
    allow_push <= 1'b1;
  end
end

dcfifo_mixed_widths #(
  .intended_device_family("Cyclone IV E"),
  .lpm_numwords(depth),
  .lpm_showahead ("ON"),
  .lpm_type("dcfifo_mixed_widths"),
  .lpm_width(9),
  .lpm_widthu(wrbits),
  .lpm_widthu_r(rdbits),
  .lpm_width_r(36),
  .overflow_checking("ON"),
  .rdsync_delaypipe(4),
  .underflow_checking("ON"),
  .use_eab("ON"),
  .wrsync_delaypipe(4)
) fifo_i (
  .wrclk (wr_clk),
  .wrreq (wr_tvalid & allow_push),
  .wrfull (wr_treadyn),
  .wrempty (),
  .wrusedw (wr_tlength),
  .data (wr_tdata),

  .rdclk (rd_clk),
  .rdreq (rd_tready & allow_pop),
  .rdfull (),
  .rdempty (rd_tvalidn),
  .rdusedw (rd_tlength),
  .q (ird_tdata),

  .aclr (1'b0),
  .eccstatus ()
);

always @ (posedge rd_clk) begin
  if (rd_tvalidn) begin
    allow_pop <= 1'b0;
    msec_cnt <= 3'h4;
  end else if (~allow_pop) begin
    // Count msec_cnt down when rd_telngth is greater than rdlimit
    // Allow pop again after 4-5 msec, this is to handle cases
    // When 20ms of data is sent at once
    if ((rd_tlength >= rdlimit) & (rd_msec_pulse)) msec_cnt <= msec_cnt - 1;
    if (~(|msec_cnt)) allow_pop <= 1'b1;
  end
end
// Allow CWX bit through early to start tx on via tx_hang
assign rd_tdata = allow_pop ? ird_tdata : 36'h0;


assign wr_tready = ~wr_treadyn & allow_push;
assign rd_tvalid = ~rd_tvalidn & allow_pop;

assign rd_underflow = ~allow_pop;

always @ (posedge rd_clk) begin
  if (rd_sample) begin
    rd_count <= rd_tlength[(rdbits-1):(rdbits-7)];
    recovery_flag <= 1'b0;
    recovery_flag_d1 <= recovery_flag;
  end else if (~allow_pop | ~allow_push) begin
    // Known CDC with allow_push, but okay since just status
    recovery_flag <= 1'b1;
  end
end

assign rd_status = {recovery_flag_d1,rd_count};

endmodule



module dslr_fifo (
  wr_clk,
  wr_tdata,
  wr_tvalid,
  wr_tready,

  rd_clk,
  rd_tdata,
  rd_tvalid,
  rd_tready
);

input         wr_clk;
input [7:0]   wr_tdata;
input         wr_tvalid;
output        wr_tready;

input         rd_clk;
output [31:0] rd_tdata;
output        rd_tvalid;
input         rd_tready;

logic         wr_treadyn;
logic         rd_tvalidn;

dcfifo_mixed_widths #(
  .intended_device_family("Cyclone IV E"),
  .lpm_numwords(8192),
  .lpm_showahead ("ON"),
  .lpm_type("dcfifo_mixed_widths"),
  .lpm_width(8),
  .lpm_widthu(13),
  .lpm_widthu_r(11),
  .lpm_width_r(32),
  .overflow_checking("ON"),
  .rdsync_delaypipe(4),
  .underflow_checking("ON"),
  .use_eab("ON"),
  .wrsync_delaypipe(4)
) fifo_i (
  .wrclk (wr_clk),
  .wrreq (wr_tvalid),
  .wrfull (wr_treadyn),
  .wrempty (),
  .wrusedw (),
  .data (wr_tdata),

  .rdclk (rd_clk),
  .rdreq (rd_tready),
  .rdfull (),
  .rdempty (rd_tvalidn),
  .rdusedw (),
  .q (rd_tdata),

  .aclr (1'b0),
  .eccstatus ()
);

assign wr_tready = ~wr_treadyn;
assign rd_tvalid = ~rd_tvalidn;

endmodule



module usiq_fifo (
  wr_clk,
  wr_tdata,
  wr_tvalid,
  wr_tready,
  wr_tlast,
  wr_tuser,

  rd_clk,
  rd_tdata,
  rd_tvalid,
  rd_tready,
  rd_tlast,
  rd_tuser,
  rd_tlength
);

input         wr_clk;
input [23:0]  wr_tdata;
input         wr_tvalid;
output        wr_tready;
input         wr_tlast;
input [1:0]   wr_tuser;

input         rd_clk;
output [23:0] rd_tdata;
output        rd_tvalid;
input         rd_tready;
output        rd_tlast;
output [1:0]  rd_tuser;
output [10:0] rd_tlength;

logic         wr_treadyn;
logic [10:0]  wr_tlength;
logic         rd_tvalidn;
logic  [26:0] rd_data;

dcfifo #(
  .add_usedw_msb_bit("ON"),
  .intended_device_family("Cyclone IV E"),
  .lpm_numwords(1024),
  .lpm_showahead ("ON"),
  .lpm_type("dcfifo"),
  .lpm_width(27),
  .lpm_widthu(11),
  .overflow_checking("ON"),
  .rdsync_delaypipe(4),
  .underflow_checking("ON"),
  .use_eab("ON"),
  .wrsync_delaypipe(4)
) fifo_i (
  .wrclk (wr_clk),
  .wrreq (wr_tvalid),
  .wrfull (wr_treadyn),
  .wrempty (),
  .wrusedw (wr_tlength),
  .data ({wr_tuser,wr_tlast,wr_tdata}),

  .rdclk (rd_clk),
  .rdreq (rd_tready),
  .rdfull (),
  .rdempty (rd_tvalidn),
  .rdusedw (rd_tlength),
  .q (rd_data),

  .aclr (1'b0),
  .eccstatus ()
);

assign wr_tready = (wr_tlength > 11'd1012) ? 1'b0: 1'b1;
//assign wr_tready = ~wr_treadyn;
assign rd_tvalid = ~rd_tvalidn;
assign rd_tlast  = rd_data[24];
assign rd_tdata  = rd_data[23:0];
assign rd_tuser  = rd_data[26:25];

endmodule



module usbs_fifo (
  wr_clk,
  wr_tdata,
  wr_tvalid,
  wr_tready,

  rd_clk,
  rd_tdata,
  rd_tvalid,
  rd_tready
);

input         wr_clk;
input [11:0]  wr_tdata;
input         wr_tvalid;
output        wr_tready;

input         rd_clk;
output [11:0] rd_tdata;
output logic  rd_tvalid = 1'b0;
input         rd_tready;

logic         rd_tvalidn;

logic         bs_ad9866_full, bs_ad9866_empty;
logic         bs_ad9866_push = 1'b0;

logic         bs_full, bs_empty;


// BS AD9866 State
always @ (posedge wr_clk) begin
  if (bs_ad9866_empty) begin
    bs_ad9866_push <= 1'b1;
  end else if (bs_ad9866_full) begin
    bs_ad9866_push <= 1'b0;
  end
end

assign wr_tready = bs_ad9866_push & ~bs_ad9866_full;

dcfifo #(
  .intended_device_family("Cyclone IV E"),
  .lpm_numwords(2048),
  .lpm_showahead ("ON"),
  .lpm_type("dcfifo"),
  .lpm_width(12),
  .lpm_widthu(11),
  .overflow_checking("ON"),
  .rdsync_delaypipe(4),
  .underflow_checking("ON"),
  .use_eab("ON"),
  .wrsync_delaypipe(4)
) fifo_i (
  .wrclk (wr_clk),
  .wrreq (bs_ad9866_push & ~bs_ad9866_full),
  .wrfull (bs_ad9866_full),
  .wrempty (bs_ad9866_empty),
  .wrusedw (),
  .data (wr_tdata),

  .rdclk (rd_clk),
  .rdreq (rd_tready),
  .rdfull (bs_full),
  .rdempty (bs_empty),
  .rdusedw (),
  .q (rd_tdata),

  .aclr (1'b0),
  .eccstatus ()
);

// BS State
always @ (posedge rd_clk) begin
  if (bs_full) begin
    rd_tvalid <= 1'b1;
  end else if (bs_empty) begin
    rd_tvalid <= 1'b0;
  end
end

endmodule



module asmi_fifo (
  aclr,
  data,
  rdclk,
  rdreq,
  wrclk,
  wrreq,
  q,
  rdusedw);

  input   aclr;
  input [7:0]  data;
  input   rdclk;
  input   rdreq;
  input   wrclk;
  input   wrreq;
  output  [7:0]  q;
  output  [9:0]  rdusedw;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
  tri0    aclr;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

  wire [7:0] sub_wire0;
  wire [9:0] sub_wire1;
  wire [7:0] q = sub_wire0[7:0];
  wire [9:0] rdusedw = sub_wire1[9:0];

  dcfifo  dcfifo_component (
        .wrclk (wrclk),
        .rdreq (rdreq),
        .aclr (aclr),
        .rdclk (rdclk),
        .wrreq (wrreq),
        .data (data),
        .q (sub_wire0),
        .rdusedw (sub_wire1)
        // synopsys translate_off
        ,
        .rdempty (),
        .rdfull (),
        .wrempty (),
        .wrfull (),
        .wrusedw ()
        // synopsys translate_on
        );
  defparam
    dcfifo_component.intended_device_family = "Cyclone IV E",
    dcfifo_component.lpm_numwords = 1024,
    dcfifo_component.lpm_showahead = "OFF",
    dcfifo_component.lpm_type = "dcfifo",
    dcfifo_component.lpm_width = 8,
    dcfifo_component.lpm_widthu = 10,
    dcfifo_component.overflow_checking = "ON",
    dcfifo_component.rdsync_delaypipe = 4,
    dcfifo_component.underflow_checking = "ON",
    dcfifo_component.use_eab = "ON",
    dcfifo_component.write_aclr_synch = "OFF",
    dcfifo_component.wrsync_delaypipe = 4;


endmodule