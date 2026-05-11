`timescale 1ns/1ps

module tb_top;

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

    initial begin
        #5000000;
        $display("TIMEOUT GLOBAL: simularea s-a oprit automat.");
        $finish;
    end

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

        reg ok;
        integer timed_out;
        begin
            wait_done_or_timeout(timed_out);

            if (timed_out) begin
                $display("| %-20s | TIMEOUT: done nu a devenit 1 | FAIL |", name);
                fail_count = fail_count + 1;
            end else begin
                ok = (recovered_bytes[0] == expected0) &&
                     (recovered_bytes[1] == expected1) &&
                     (recovered_bytes[2] == expected2) &&
                     (recovered_bytes[3] == expected3) &&
                     (!frame_error);

                $write("| %-20s | ", name);
                $write("payload_len=%0d type=%0d | ", payload_len, payload_type);
                $write("c1=[");
                for (i = 0; i < 8; i = i + 1) begin
                    $write("%0d", c1_preview[i]);
                    if (i != 7) $write(" ");
                end
                $write("] | c2=[");
                for (i = 0; i < 8; i = i + 1) begin
                    $write("%0d", c2_preview[i]);
                    if (i != 7) $write(" ");
                end
                $write("] | rec=[%02X %02X %02X %02X] | ",
                    recovered_bytes[0], recovered_bytes[1],
                    recovered_bytes[2], recovered_bytes[3]);

                if (ok) begin
                    $display("PASS |");
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL |");
                    fail_count = fail_count + 1;
                end
            end

            repeat (5) @(posedge clk);
        end
    endtask

    task send_temp_frame;
        begin
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
        $display("==============================================================================================================================");
        $display(" SIMULARE FPGA - NUME SIMPLE, N=256, Q=7681");
        $display("==============================================================================================================================");

        send_temp_frame();
        send_humidity_frame();

        $display("==============================================================================================================================");
        $display("Rezultat final: PASS=%0d, FAIL=%0d", pass_count, fail_count);
        $display("==============================================================================================================================");

        if (fail_count == 0) begin
            $display("SIMULARE REUSITA.");
        end else begin
            $display("SIMULARE ESUATA.");
        end

        $finish;
    end

endmodule
