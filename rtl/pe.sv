`ifndef PE_V
`define PE_V

`timescale 1ns/1ps

module pe #(
  parameter  QI = 8,
  parameter  QF = 8,
  localparam DW = QI + QF
)(
  input  logic                 clk,
  input  logic                 rst,

  // north
  input  logic signed [DW-1:0] pe_psum_in,
  input  logic signed [DW-1:0] pe_weight_in,
  input  logic                 pe_accept_w_in,

  // west
  input  logic signed [DW-1:0] pe_input_in,
  input  logic                 pe_valid_in,
  input  logic                 pe_switch_in,
  input  logic                 pe_enabled,

  // south
  output logic signed [DW-1:0] pe_psum_out,
  output logic signed [DW-1:0] pe_weight_out,

  // east
  output logic signed [DW-1:0] pe_input_out,
  output logic                 pe_valid_out,
  output logic                 pe_switch_out
);

  // Weight storage
  logic signed [DW-1:0] weight_bg;
  logic signed [DW-1:0] weight_fg;
  logic signed [DW-1:0] weight_active;

  // MAC
  logic signed [DW-1:0] mult_out;
  logic signed [DW-1:0] mac_out;

  // Fixed-point multiply: mult_out = weight_active * pe_input_in
  fxp_mul #(QI,QF) u_mul (
    .ina(weight_active),
    .inb(pe_input_in),
    .out(mult_out),
    .overflow()
  );

  // Fixed-point add: mac_out = pe_psum_in + mult_out
  fxp_add #(QI,QF) u_add (
    .ina(pe_psum_in),
    .inb(mult_out),
    .out(mac_out),
    .overflow()
  );

  // combinational promotion: if pe_switch_in is high then weight_bg is forwarded,
  // which anyways becomes weight_fg in the next cycle
  always_comb begin
    weight_active = ( pe_switch_in && pe_enabled ) ? weight_bg : weight_fg;
  end

  // weight_bg gets pe_weight_in on pe_accept_w_in
  // weight_fg gets weight_bg (promotion) on pe_switch_in
  always_ff @( posedge clk or posedge rst ) begin
    if ( rst ) begin
      weight_bg <= '0;
      weight_fg <= '0;
    end else if ( pe_enabled ) begin
      if (pe_accept_w_in) weight_bg <= pe_weight_in;
      if (pe_switch_in) weight_fg <= weight_bg;
    end
  end

  // Update outputs on reset and input signals
  always_ff @( posedge clk or posedge rst ) begin
    if ( rst ) begin
      pe_psum_out   <= '0;
      pe_weight_out <= '0;
      pe_input_out  <= '0;
      pe_valid_out  <= 1'b0;
      pe_switch_out <= 1'b0;
    end
    else if ( pe_enabled ) begin
      pe_psum_out   <= ( pe_valid_in ) ? mac_out : '0;
      pe_weight_out <= ( pe_accept_w_in ) ? pe_weight_in : '0;
      pe_input_out  <= ( pe_valid_in ) ? pe_input_in : '0;
      pe_valid_out  <= pe_valid_in;
      pe_switch_out <= pe_switch_in;
    end
  end

endmodule

`endif
