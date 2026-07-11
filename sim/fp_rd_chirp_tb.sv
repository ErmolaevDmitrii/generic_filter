`timescale 1ns/1ps

module fp_rd_chirp_tb;

localparam int unsigned TAPS_COUNT = 16;
localparam int unsigned INPUT_DATA_WIDTH = 16;
localparam int unsigned COEFFS_WIDTH = 16;
localparam int unsigned COEFFS_INDEX_WIDTH = 4;
localparam int unsigned OUTPUT_DATA_WIDTH = 36;
localparam int unsigned MAX_SAMPLES = 4096;
localparam int unsigned TIMEOUT_CYCLES = 10000;
localparam string INPUT_FILE = "sim/build/fp_rd_chirp/samples.txt";
localparam string COEFF_FILE = "sim/build/fp_rd_chirp/coeffs.txt";
localparam string EXPECTED_FILE = "sim/build/fp_rd_chirp/expected.txt";
localparam string OUTPUT_FILE = "sim/build/fp_rd_chirp/dut_output.csv";

logic clk = 1'b0;
logic rst_n;
logic en_i;
logic short_mode_i;
logic signed [INPUT_DATA_WIDTH - 1:0] data_i;
logic data_v_i;
logic [COEFFS_INDEX_WIDTH - 1:0] coeff_update_index_i;
logic signed [COEFFS_WIDTH - 1:0] coeff_update_data_i;
logic coeff_update_v_i;
logic signed [OUTPUT_DATA_WIDTH - 1:0] data_o;
logic data_v_o;

logic signed [INPUT_DATA_WIDTH - 1:0] samples [0:MAX_SAMPLES - 1];
logic signed [COEFFS_WIDTH - 1:0] coefficients [0:TAPS_COUNT - 1];
logic signed [OUTPUT_DATA_WIDTH - 1:0] expected [0:MAX_SAMPLES - 1];

integer output_fd;
integer sample_count;
integer output_count;
integer error_count;
integer cycle_count;

generic_fp_rd i_dut (
      .clk(clk)
    , .rst_n(rst_n)
    , .en_i(en_i)
    , .short_mode_i(short_mode_i)
    , .data_i(data_i)
    , .data_v_i(data_v_i)
    , .coeff_update_index_i(coeff_update_index_i)
    , .coeff_update_data_i(coeff_update_data_i)
    , .coeff_update_v_i(coeff_update_v_i)
    , .data_o(data_o)
    , .data_v_o(data_v_o)
);

always #5 clk = ~clk;

task automatic read_vectors;
    integer fd;
    integer status;
    integer index;
    longint signed value;
begin
    fd = $fopen(INPUT_FILE, "r");
    if (fd == 0) $fatal(1, "Cannot open %s", INPUT_FILE);
    for (index = 0; index < sample_count; index = index + 1) begin
        status = $fscanf(fd, "%d", value);
        if (status != 1) $fatal(1, "Cannot read input sample %0d", index);
        samples[index] = value[INPUT_DATA_WIDTH - 1:0];
    end
    $fclose(fd);

    fd = $fopen(COEFF_FILE, "r");
    if (fd == 0) $fatal(1, "Cannot open %s", COEFF_FILE);
    for (index = 0; index < TAPS_COUNT; index = index + 1) begin
        status = $fscanf(fd, "%d", value);
        if (status != 1) $fatal(1, "Cannot read coefficient %0d", index);
        coefficients[index] = value[COEFFS_WIDTH - 1:0];
    end
    $fclose(fd);

    fd = $fopen(EXPECTED_FILE, "r");
    if (fd == 0) $fatal(1, "Cannot open %s", EXPECTED_FILE);
    for (index = 0; index < sample_count; index = index + 1) begin
        status = $fscanf(fd, "%d", value);
        if (status != 1) $fatal(1, "Cannot read expected sample %0d", index);
        expected[index] = value[OUTPUT_DATA_WIDTH - 1:0];
    end
    $fclose(fd);
end
endtask

task automatic program_coefficients;
    integer index;
begin
    for (index = 0; index < TAPS_COUNT; index = index + 1) begin
        @(negedge clk);
        coeff_update_index_i = index[COEFFS_INDEX_WIDTH - 1:0];
        coeff_update_data_i = coefficients[index];
        coeff_update_v_i = 1'b1;
    end
    @(negedge clk);
    coeff_update_v_i = 1'b0;
end
endtask

task automatic send_sample(input logic signed [INPUT_DATA_WIDTH - 1:0] value);
begin
    @(negedge clk);
    data_i = value;
    data_v_i = 1'b1;
end
endtask

always @(posedge clk) begin
    cycle_count = cycle_count + 1;

    if (cycle_count > TIMEOUT_CYCLES) begin
        $fatal(1, "Timeout after %0d cycles", TIMEOUT_CYCLES);
    end

    if (data_v_o) begin
        $fwrite(output_fd, "%0d,%0d\n", output_count, data_o);
        if (data_o !== expected[output_count]) begin
            $error(
                "sample %0d: expected %0d, got %0d",
                output_count,
                expected[output_count],
                data_o
            );
            error_count = error_count + 1;
        end
        output_count = output_count + 1;
    end
end

initial begin
    if (!$value$plusargs("SAMPLE_COUNT=%d", sample_count)) sample_count = 256;

    if (sample_count > MAX_SAMPLES)
        $fatal(1, "SAMPLE_COUNT exceeds MAX_SAMPLES=%0d", MAX_SAMPLES);

    read_vectors();
    output_fd = $fopen(OUTPUT_FILE, "w");
    if (output_fd == 0) $fatal(1, "Cannot open %s", OUTPUT_FILE);
    $fwrite(output_fd, "sample_index,value\n");

    rst_n = 1'b0;
    en_i = 1'b1;
    short_mode_i = 1'b0;
    data_i = '0;
    data_v_i = 1'b0;
    coeff_update_index_i = '0;
    coeff_update_data_i = '0;
    coeff_update_v_i = 1'b0;
    output_count = 0;
    error_count = 0;
    cycle_count = 0;

    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    program_coefficients();

    repeat (TAPS_COUNT - 1) send_sample('0);
    for (integer index = 0; index < sample_count; index = index + 1)
        send_sample(samples[index]);

    @(negedge clk);
    data_v_i = 1'b0;
    wait (output_count == sample_count);
    repeat (2) @(negedge clk);
    $fsdbDumpflush;
    $fclose(output_fd);

    if (error_count != 0) $fatal(1, "FAIL: %0d mismatches", error_count);
    $display("PASS: %0d samples match", output_count);
    $finish;
end

initial begin
    $fsdbDumpfile("sim/build/fp_rd_chirp/waves.fsdb");
    $fsdbDumpvars(0, fp_rd_chirp_tb, "+all");
end

endmodule
