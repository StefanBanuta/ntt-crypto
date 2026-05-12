`timescale 1ns/1ps
`include "params.svh"

/*
 * crypto_core.sv
 *
 * Modul de simulare mai realist pentru fluxul criptografic RLWE.
 *
 * Parametri:
 *   N = 256
 *   Q = 7681
 *
 * Flux simulat:
 *
 *   keygen:
 *      b = a*s
 *
 *   encrypt:
 *      c1 = a*r
 *      c2 = b*r + m
 *
 *   decrypt:
 *      t = c2 - c1*s
 *      recovered_bit = threshold(t)
 *
 * Observatie:
 *   Acest modul simuleaza matematic fluxul RLWE cu polinoame de 256 coeficienti.
 *   Pentru a garanta recuperarea corecta in aceasta etapa, zgomotele e, e1, e2
 *   sunt setate implicit la 0.
 *
 *   Pentru implementarea reala pe FPGA, inmultirea polinomiala O(N^2) din acest
 *   modul trebuie inlocuita cu:
 *      NTT -> inmultire punct cu punct -> INTT
 */

module crypto_core #(
    parameter integer N = `N,
    parameter integer Q = `Q,
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
    localparam [2:0] DONE_ST = 3'd2;

    reg [2:0] state;
    reg [7:0] delay_counter;

    reg [COEFF_W-1:0] a       [0:N-1];
    reg [COEFF_W-1:0] s       [0:N-1];
    reg [COEFF_W-1:0] r       [0:N-1];
    reg [COEFF_W-1:0] b       [0:N-1];

    reg [COEFF_W-1:0] c1      [0:N-1];
    reg [COEFF_W-1:0] c2      [0:N-1];
    reg [COEFF_W-1:0] c1s     [0:N-1];
    reg [COEFF_W-1:0] t       [0:N-1];

    integer i;
    integer j;
    integer k;
    integer byte_idx;
    integer bit_idx;
    integer acc;

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

            for (i = 0; i < N; i = i + 1) begin
                a[i]   <= {COEFF_W{1'b0}};
                s[i]   <= {COEFF_W{1'b0}};
                r[i]   <= {COEFF_W{1'b0}};
                b[i]   <= {COEFF_W{1'b0}};
                c1[i]  <= {COEFF_W{1'b0}};
                c2[i]  <= {COEFF_W{1'b0}};
                c1s[i] <= {COEFF_W{1'b0}};
                t[i]   <= {COEFF_W{1'b0}};
            end
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin

                        /*
                         * 1. Initializare polinoame demonstrative.
                         *
                         * a = polinom public determinist
                         * s = cheie secreta rara
                         * r = polinom efemer rar
                         */
                        for (i = 0; i < N; i = i + 1) begin
                            a[i] = mod_q(17*i + 5);

                            if ((i % 64) == 0) begin
                                s[i] = 16'd1;
                            end else begin
                                s[i] = 16'd0;
                            end

                            if ((i % 80) == 0) begin
                                r[i] = 16'd1;
                            end else begin
                                r[i] = 16'd0;
                            end

                            b[i]   = 16'd0;
                            c1[i]  = 16'd0;
                            c2[i]  = 16'd0;
                            c1s[i] = 16'd0;
                            t[i]   = 16'd0;
                        end

                        /*
                         * 2. Keygen:
                         *      b = a*s
                         */
                        for (i = 0; i < N; i = i + 1) begin
                            acc = 0;

                            for (j = 0; j < N; j = j + 1) begin
                                k = i - j;
                                if (k < 0) begin
                                    k = k + N;
                                end

                                acc = acc + a[j] * s[k];
                            end

                            b[i] = mod_q(acc);
                        end

                        /*
                         * 3. Encrypt:
                         *      c1 = a*r
                         */
                        for (i = 0; i < N; i = i + 1) begin
                            acc = 0;

                            for (j = 0; j < N; j = j + 1) begin
                                k = i - j;
                                if (k < 0) begin
                                    k = k + N;
                                end

                                acc = acc + a[j] * r[k];
                            end

                            c1[i] = mod_q(acc);
                        end

                        /*
                         * 4. Encrypt:
                         *      c2 = b*r + m
                         */
                        for (i = 0; i < N; i = i + 1) begin
                            acc = 0;

                            for (j = 0; j < N; j = j + 1) begin
                                k = i - j;
                                if (k < 0) begin
                                    k = k + N;
                                end

                                acc = acc + b[j] * r[k];
                            end

                            c2[i] = mod_q(acc + m_poly[i]);
                        end

                        /*
                         * 5. Decrypt:
                         *      t = c2 - c1*s
                         */
                        for (i = 0; i < N; i = i + 1) begin
                            acc = 0;

                            for (j = 0; j < N; j = j + 1) begin
                                k = i - j;
                                if (k < 0) begin
                                    k = k + N;
                                end

                                acc = acc + c1[j] * s[k];
                            end

                            c1s[i] = mod_q(acc);
                            t[i]   = mod_q(c2[i] - mod_q(acc));
                        end

                        /*
                         * 6. Preview pentru terminal/waveform.
                         */
                        for (i = 0; i < 8; i = i + 1) begin
                            c1_preview[i] = c1[i];
                            c2_preview[i] = c2[i];
                        end

                        /*
                         * 7. Impachetare inapoi in bytes.
                         */
                        for (i = 0; i < N/8; i = i + 1) begin
                            recovered_bytes[i] = 8'd0;
                        end

                        for (i = 0; i < N; i = i + 1) begin
                            byte_idx = i / 8;
                            bit_idx  = 7 - (i % 8);

                            recovered_bytes[byte_idx][bit_idx] = bit_from_coeff(t[i]);
                        end

                        delay_counter <= 8'd20;
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    if (delay_counter == 0) begin
                        state <= DONE_ST;
                    end else begin
                        delay_counter <= delay_counter - 1;
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
