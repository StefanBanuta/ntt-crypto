`timescale 1ns/1ps
`include "params.svh"

module top #(
    parameter integer N = `N_TARGET,
    parameter integer Q = `Q_TARGET,
    parameter integer COEFF_W = `COEFF_W,
    parameter integer MAX_PAYLOAD = `MAX_PAYLOAD
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       in_valid,
    input  wire [7:0] in_data,

    output reg        done,
    output wire       frame_error,

    output wire [7:0] payload_type,
    output wire [7:0] payload_len,

    output wire [COEFF_W-1:0] c1_preview [0:7],
    output wire [COEFF_W-1:0] c2_preview [0:7],
    output wire [7:0] recovered_bytes [0:(N/8)-1]
);

    wire       payload_valid;
    wire [7:0] payload_data [0:MAX_PAYLOAD-1];

    wire enc_done;
    reg  enc_start;

    wire encoder_done;
    reg  encoder_start;

    wire [COEFF_W-1:0] m_poly [0:N-1];

    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] START_ENC_M = 3'd1;
    localparam [2:0] WAIT_ENC_M  = 3'd2;
    localparam [2:0] START_CRYP  = 3'd3;
    localparam [2:0] WAIT_CRYP   = 3'd4;
    localparam [2:0] DONE_ST     = 3'd5;

    reg [2:0] state;

    parser #(
        .MAX_PAYLOAD(MAX_PAYLOAD)
    ) parser (
        .clk(clk),
        .rst_n(rst_n),
        .rx_valid(in_valid),
        .rx_data(in_data),
        .payload_valid(payload_valid),
        .payload_type(payload_type),
        .payload_len(payload_len),
        .payload_data(payload_data),
        .frame_error(frame_error)
    );

    encoder #(
        .N(N),
        .Q(Q),
        .MAX_PAYLOAD(MAX_PAYLOAD),
        .COEFF_W(COEFF_W)
    ) encoder (
        .clk(clk),
        .rst_n(rst_n),
        .start(encoder_start),
        .payload_len(payload_len),
        .payload_data(payload_data),
        .done(encoder_done),
        .m_poly(m_poly)
    );

    crypto_core #(
        .N(N),
        .Q(Q),
        .COEFF_W(COEFF_W)
    ) crypto (
        .clk(clk),
        .rst_n(rst_n),
        .start(enc_start),
        .m_poly(m_poly),
        .done(enc_done),
        .c1_preview(c1_preview),
        .c2_preview(c2_preview),
        .recovered_bytes(recovered_bytes)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            encoder_start <= 1'b0;
            enc_start <= 1'b0;
            done <= 1'b0;
        end else begin
            encoder_start <= 1'b0;
            enc_start <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (payload_valid) begin
                        state <= START_ENC_M;
                    end
                end

                START_ENC_M: begin
                    encoder_start <= 1'b1;
                    state <= WAIT_ENC_M;
                end

                WAIT_ENC_M: begin
                    if (encoder_done) begin
                        state <= START_CRYP;
                    end
                end

                START_CRYP: begin
                    enc_start <= 1'b1;
                    state <= WAIT_CRYP;
                end

                WAIT_CRYP: begin
                    if (enc_done) begin
                        state <= DONE_ST;
                    end
                end

                DONE_ST: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
