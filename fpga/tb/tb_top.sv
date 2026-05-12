`timescale 1ns/1ps

module tb_top;

    localparam integer N = 256;
    localparam integer Q = 7681;
    localparam integer COEFF_W = 16;

    reg clk;
    reg rst_n;

    reg        in_valid;
    reg [7:0]  in_data;

    wire done;
    wire frame_error;

    wire [7:0] payload_type;
    wire [7:0] payload_len;

    wire [15:0] c1_preview [0:7];
    wire [15:0] c2_preview [0:7];
    wire [7:0]  recovered_bytes [0:31];

    integer pass_count;
    integer fail_count;
    integer i;
    integer j;
    integer k;

    reg [15:0] golden_m  [0:N-1];
    reg [15:0] golden_a  [0:N-1];
    reg [15:0] golden_s  [0:N-1];
    reg [15:0] golden_r  [0:N-1];
    reg [15:0] golden_b  [0:N-1];
    reg [15:0] golden_c1 [0:N-1];
    reg [15:0] golden_c2 [0:N-1];

    top dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .done(done),
        .frame_error(frame_error),
        .payload_type(payload_type),
        .payload_len(payload_len),
        .c1_preview(c1_preview),
        .c2_preview(c2_preview),
        .recovered_bytes(recovered_bytes)
    );

    always #5 clk = ~clk;

    function [15:0] mod_q;
        input integer value;
        integer tmp;
        begin
            tmp = value % Q;
            if (tmp < 0) begin
                tmp = tmp + Q;
            end
            mod_q = tmp[15:0];
        end
    endfunction

    task clear_golden;
        begin
            for (i = 0; i < N; i = i + 1) begin
                golden_m[i]  = 16'd0;
                golden_a[i]  = 16'd0;
                golden_s[i]  = 16'd0;
                golden_r[i]  = 16'd0;
                golden_b[i]  = 16'd0;
                golden_c1[i] = 16'd0;
                golden_c2[i] = 16'd0;
            end
        end
    endtask

    task encode_payload_to_golden_m;
        input [7:0] b0;
        input [7:0] b1;
        input [7:0] b2;
        input [7:0] b3;

        reg [7:0] payload [0:3];
        integer bit_idx;
        integer byte_idx;
        integer local_i;
        begin
            payload[0] = b0;
            payload[1] = b1;
            payload[2] = b2;
            payload[3] = b3;

            for (local_i = 0; local_i < N; local_i = local_i + 1) begin
                byte_idx = local_i / 8;
                bit_idx  = 7 - (local_i % 8);

                if (byte_idx < 4) begin
                    if (payload[byte_idx][bit_idx]) begin
                        golden_m[local_i] = Q / 2;
                    end else begin
                        golden_m[local_i] = 16'd0;
                    end
                end else begin
                    golden_m[local_i] = 16'd0;
                end
            end
        end
    endtask

    task compute_golden_crypto;
        integer acc;
        begin
            for (i = 0; i < N; i = i + 1) begin
                golden_a[i] = mod_q(17*i + 5);

                if ((i % 64) == 0) begin
                    golden_s[i] = 16'd1;
                end else begin
                    golden_s[i] = 16'd0;
                end

                if ((i % 80) == 0) begin
                    golden_r[i] = 16'd1;
                end else begin
                    golden_r[i] = 16'd0;
                end

                golden_b[i]  = 16'd0;
                golden_c1[i] = 16'd0;
                golden_c2[i] = 16'd0;
            end
			
            for (i = 0; i < N; i = i + 1) begin
                acc = 0;

                for (j = 0; j < N; j = j + 1) begin
                    k = i - j;
                    if (k < 0) begin
                        k = k + N;
                    end

                    acc = acc + golden_a[j] * golden_s[k];
                end

                golden_b[i] = mod_q(acc);
            end

            for (i = 0; i < N; i = i + 1) begin
                acc = 0;

                for (j = 0; j < N; j = j + 1) begin
                    k = i - j;
                    if (k < 0) begin
                        k = k + N;
                    end

                    acc = acc + golden_a[j] * golden_r[k];
                end

                golden_c1[i] = mod_q(acc);
            end

            for (i = 0; i < N; i = i + 1) begin
                acc = 0;

                for (j = 0; j < N; j = j + 1) begin
                    k = i - j;
                    if (k < 0) begin
                        k = k + N;
                    end

                    acc = acc + golden_b[j] * golden_r[k];
                end

                golden_c2[i] = mod_q(acc + golden_m[i]);
            end
        end
    endtask

    task send_byte;
        input [7:0] b;
        begin
            @(posedge clk);
            in_valid <= 1'b1;
            in_data  <= b;

            @(posedge clk);
            in_valid <= 1'b0;
            in_data  <= 8'h00;

            repeat (2) @(posedge clk);
        end
    endtask

    task wait_done_or_timeout;
        output integer timed_out;
        integer cycles;
        begin
            timed_out = 0;
            cycles = 0;

            while (done !== 1'b1 && cycles < 5000) begin
                @(posedge clk);
                cycles = cycles + 1;
            end

            if (done !== 1'b1) begin
                timed_out = 1;
            end

            @(posedge clk);
        end
    endtask

    task check_result;
        input [8*20-1:0] name;
        input [7:0] expected0;
        input [7:0] expected1;
        input [7:0] expected2;
        input [7:0] expected3;

        reg ok_payload;
        reg ok_c1;
        reg ok_c2;
        integer timed_out;
        begin
            wait_done_or_timeout(timed_out);

            if (timed_out) begin
                $display("| %-20s | TIMEOUT | FAIL |", name);
                fail_count = fail_count + 1;
            end else begin
                ok_payload = (recovered_bytes[0] == expected0) &&
                             (recovered_bytes[1] == expected1) &&
                             (recovered_bytes[2] == expected2) &&
                             (recovered_bytes[3] == expected3) &&
                             (!frame_error);

                ok_c1 = 1'b1;
                ok_c2 = 1'b1;

                for (i = 0; i < 8; i = i + 1) begin
                    if (c1_preview[i] !== golden_c1[i]) begin
                        ok_c1 = 1'b0;
                    end

                    if (c2_preview[i] !== golden_c2[i]) begin
                        ok_c2 = 1'b0;
                    end
                end

                $write("| %-20s | ", name);
                $write("rec=[%02X %02X %02X %02X] | ",
                    recovered_bytes[0], recovered_bytes[1],
                    recovered_bytes[2], recovered_bytes[3]);

                $write("c1_verilog=[");
                for (i = 0; i < 8; i = i + 1) begin
                    $write("%0d", c1_preview[i]);
                    if (i != 7) $write(" ");
                end

                $write("] | c1_golden=[");
                for (i = 0; i < 8; i = i + 1) begin
                    $write("%0d", golden_c1[i]);
                    if (i != 7) $write(" ");
                end

                $write("] | c2_verilog=[");
                for (i = 0; i < 8; i = i + 1) begin
                    $write("%0d", c2_preview[i]);
                    if (i != 7) $write(" ");
                end

                $write("] | c2_golden=[");
                for (i = 0; i < 8; i = i + 1) begin
                    $write("%0d", golden_c2[i]);
                    if (i != 7) $write(" ");
                end

                $write("] | ");

                if (ok_payload && ok_c1 && ok_c2) begin
                    $display("PASS |");
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL | payload=%0d c1=%0d c2=%0d |", ok_payload, ok_c1, ok_c2);
                    fail_count = fail_count + 1;
                end
            end

            repeat (5) @(posedge clk);
        end
    endtask

    task send_temp_frame;
        begin
            clear_golden();
            encode_payload_to_golden_m(8'h00, 8'h00, 8'hBC, 8'h41);
            compute_golden_crypto();

            send_byte(8'hAA);
            send_byte(8'h04);
            send_byte(8'h01);
            send_byte(8'h00);
            send_byte(8'h00);
            send_byte(8'hBC);
            send_byte(8'h41);
            send_byte(8'h02);
            send_byte(8'h55);

            check_result("Temperatura", 8'h00, 8'h00, 8'hBC, 8'h41);
        end
    endtask

    task send_humidity_frame;
        begin
            clear_golden();
            encode_payload_to_golden_m(8'h66, 8'h66, 8'h82, 8'h42);
            compute_golden_crypto();

            send_byte(8'hAA);
            send_byte(8'h04);
            send_byte(8'h02);
            send_byte(8'h66);
            send_byte(8'h66);
            send_byte(8'h82);
            send_byte(8'h42);
            send_byte(8'h96);
            send_byte(8'h55);

            check_result("Umiditate", 8'h66, 8'h66, 8'h82, 8'h42);
        end
    endtask

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_top);

        clk = 1'b0;
        rst_n = 1'b0;
        in_valid = 1'b0;
        in_data = 8'h00;

        pass_count = 0;
        fail_count = 0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        $display("");
        $display("=======================================================================================================================================================================================================");
        $display(" SIMULARE FPGA - VERIFICARE CRIPTARE c1/c2 + DECRIPTARE");
        $display("=======================================================================================================================================================================================================");

        send_temp_frame();
        send_humidity_frame();

        $display("=======================================================================================================================================================================================================");
        $display("Rezultat final: PASS=%0d, FAIL=%0d", pass_count, fail_count);
        $display("=======================================================================================================================================================================================================");

        if (fail_count == 0) begin
            $display("SIMULARE REUSITA: criptarea c1/c2 si decriptarea au fost verificate.");
        end else begin
            $display("SIMULARE ESUATA.");
        end

        $finish;
    end

endmodule
