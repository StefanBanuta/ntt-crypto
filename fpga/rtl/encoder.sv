`timescale 1ns/1ps
`include "params.svh"

module encoder #(
    parameter integer N = `N_TARGET,
    parameter integer Q = `Q_TARGET,
    parameter integer MAX_PAYLOAD = `MAX_PAYLOAD,
    parameter integer COEFF_W = `COEFF_W
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire [7:0]  payload_len,
    input  wire [7:0]  payload_data [0:MAX_PAYLOAD-1],

    output reg         done,
    output reg  [COEFF_W-1:0] m_poly [0:N-1]
);

    localparam integer DELTA = Q / 2;

    integer i;
    integer byte_idx;
    integer bit_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;

            for (i = 0; i < N; i = i + 1) begin
                m_poly[i] <= {COEFF_W{1'b0}};
            end
        end else begin
            done <= 1'b0;

            if (start) begin
                for (i = 0; i < N; i = i + 1) begin
                    byte_idx = i / 8;
                    bit_idx  = 7 - (i % 8);

                    if (byte_idx < payload_len) begin
                        if (payload_data[byte_idx][bit_idx]) begin
                            m_poly[i] <= DELTA[COEFF_W-1:0];
                        end else begin
                            m_poly[i] <= {COEFF_W{1'b0}};
                        end
                    end else begin
                        m_poly[i] <= {COEFF_W{1'b0}};
                    end
                end

                done <= 1'b1;
            end
        end
    end

endmodule
