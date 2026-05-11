`timescale 1ns/1ps

module parser #(
    parameter integer MAX_PAYLOAD = 32
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        rx_valid,
    input  wire [7:0]  rx_data,

    output reg         payload_valid,
    output reg  [7:0]  payload_type,
    output reg  [7:0]  payload_len,
    output reg  [7:0]  payload_data [0:MAX_PAYLOAD-1],

    output reg         frame_error
);

    localparam [7:0] SOF      = 8'hAA;
    localparam [7:0] EOF_BYTE = 8'h55;

    localparam [2:0] WAIT_SOF      = 3'd0;
    localparam [2:0] READ_LEN      = 3'd1;
    localparam [2:0] READ_TYPE     = 3'd2;
    localparam [2:0] READ_PAYLOAD  = 3'd3;
    localparam [2:0] READ_CHECKSUM = 3'd4;
    localparam [2:0] READ_EOF      = 3'd5;

    reg [2:0] state;
    reg [7:0] checksum_calc;
    reg [7:0] index;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= WAIT_SOF;
            payload_valid <= 1'b0;
            payload_type  <= 8'd0;
            payload_len   <= 8'd0;
            checksum_calc <= 8'd0;
            index         <= 8'd0;
            frame_error   <= 1'b0;

            for (i = 0; i < MAX_PAYLOAD; i = i + 1) begin
                payload_data[i] <= 8'd0;
            end
        end else begin
            payload_valid <= 1'b0;
            frame_error   <= 1'b0;

            if (rx_valid) begin
                case (state)
                    WAIT_SOF: begin
                        if (rx_data == SOF) begin
                            state <= READ_LEN;
                            checksum_calc <= 8'd0;
                            index <= 8'd0;
                        end
                    end

                    READ_LEN: begin
                        payload_len <= rx_data;
                        checksum_calc <= checksum_calc + rx_data;

                        if (rx_data > MAX_PAYLOAD) begin
                            frame_error <= 1'b1;
                            state <= WAIT_SOF;
                        end else begin
                            state <= READ_TYPE;
                        end
                    end

                    READ_TYPE: begin
                        payload_type <= rx_data;
                        checksum_calc <= checksum_calc + rx_data;

                        if (payload_len == 0) begin
                            state <= READ_CHECKSUM;
                        end else begin
                            state <= READ_PAYLOAD;
                            index <= 8'd0;
                        end
                    end

                    READ_PAYLOAD: begin
                        payload_data[index] <= rx_data;
                        checksum_calc <= checksum_calc + rx_data;

                        if (index == payload_len - 1) begin
                            state <= READ_CHECKSUM;
                        end else begin
                            index <= index + 1;
                        end
                    end

                    READ_CHECKSUM: begin
                        if (rx_data == checksum_calc) begin
                            state <= READ_EOF;
                        end else begin
                            frame_error <= 1'b1;
                            state <= WAIT_SOF;
                        end
                    end

                    READ_EOF: begin
                        if (rx_data == EOF_BYTE) begin
                            payload_valid <= 1'b1;
                        end else begin
                            frame_error <= 1'b1;
                        end

                        state <= WAIT_SOF;
                    end

                    default: begin
                        state <= WAIT_SOF;
                    end
                endcase
            end
        end
    end

endmodule
