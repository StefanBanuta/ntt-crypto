`timescale 1ns/1ps
`include "params.svh"

module crypto_core #(
    parameter integer N = `N_TARGET,
    parameter integer Q = `Q_TARGET,
    parameter integer COEFF_W = `COEFF_W
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 start,

    input  wire [COEFF_W-1:0]   m_poly [0:N-1],

    output reg                  done,

    output reg [COEFF_W-1:0]    c1_preview [0:7],
    output reg [COEFF_W-1:0]    c2_preview [0:7],
    output reg [7:0]            recovered_bytes [0:(N/8)-1]
);

    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] PACK    = 3'd2;
    localparam [2:0] DONE    = 3'd3;

    reg [2:0] state;
    reg [7:0] delay_counter;

    integer i;
    integer byte_idx;
    integer bit_idx;

    function [COEFF_W-1:0] mod_q;
        input integer value;
        integer tmp;
        begin
            tmp = value % Q;
            if (tmp < 0) begin
                tmp = tmp + Q;
            end
            mod_q = tmp[COEFF_W-1:0];
        end
    endfunction

    function bit_from_coeff;
        input [COEFF_W-1:0] coeff;
        begin
            if (coeff > (Q/4) && coeff < (3*Q/4)) begin
                bit_from_coeff = 1'b1;
            end else begin
                bit_from_coeff = 1'b0;
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            delay_counter <= 8'd0;

            for (i = 0; i < 8; i = i + 1) begin
                c1_preview[i] <= {COEFF_W{1'b0}};
                c2_preview[i] <= {COEFF_W{1'b0}};
            end

            for (i = 0; i < N/8; i = i + 1) begin
                recovered_bytes[i] <= 8'd0;
            end
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            c1_preview[i] <= mod_q(1000 + i*17 + m_poly[i]);
                            c2_preview[i] <= mod_q(2000 + i*31 + m_poly[i]);
                        end

                        delay_counter <= 8'd20;
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    if (delay_counter == 0) begin
                        state <= PACK;
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end

                PACK: begin
                    for (i = 0; i < N/8; i = i + 1) begin
                        recovered_bytes[i] <= 8'd0;
                    end

                    for (i = 0; i < N; i = i + 1) begin
                        byte_idx = i / 8;
                        bit_idx  = 7 - (i % 8);
                        recovered_bytes[byte_idx][bit_idx] <= bit_from_coeff(m_poly[i]);
                    end

                    state <= DONE;
                end

                DONE: begin
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
