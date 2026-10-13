module tm1638(
    input clk,
    input rst,

    input data_latch,
    inout [7:0] data,
    input rw,

    output busy,

    output sclk,
    input  dio_in,
    output reg dio_out
    );

    localparam CLK_DIV = 4; // 12 MHz / 16 = 750 kHz (datasheet TM1638: maks 1 MHz)
    localparam CLK_DIV1 = CLK_DIV - 1;
    localparam [1:0]
        S_IDLE      = 2'h0,
        S_WAIT      = 2'h1,
        S_TRANSFER  = 2'h2;

    reg [1:0] cur_state, next_state;
    reg [CLK_DIV1:0] sclk_d, sclk_q;
    reg [7:0] data_d, data_q, data_out_d, data_out_q;
    reg dio_out_d;
    reg [2:0] ctr_d, ctr_q;

    assign data = rw ? 8'hZZ : data_out_q;
    assign busy = cur_state != S_IDLE;
    assign sclk = ~((~sclk_q[CLK_DIV1]) & (cur_state == S_TRANSFER));

    always @(*)
    begin
        sclk_d = sclk_q;
        data_d = data_q;
        dio_out_d = dio_out;
        ctr_d = ctr_q;
        data_out_d = data_out_q;
        next_state = cur_state;

        case(cur_state)
            S_IDLE: begin
                sclk_d = 0;
                if (data_latch) begin
                    data_d = rw ? data : 8'b0;
                    next_state = S_WAIT;
                end
            end

            S_WAIT: begin
                sclk_d = sclk_q + 1;
                if (sclk_q == {1'b0, {CLK_DIV1{1'b1}}}) begin
                    sclk_d = 0;
                    next_state = S_TRANSFER;
                end
            end

            S_TRANSFER: begin
                sclk_d = sclk_q + 1;
                if (sclk_q == 0) begin
                    dio_out_d = data_q[0];
                end else if (sclk_q == {1'b0, {CLK_DIV1{1'b1}}}) begin
                    data_d = {dio_in, data_q[7:1]};
                end else if (&sclk_q) begin
                    ctr_d = ctr_q + 1;
                    if (&ctr_q) begin
                        next_state = S_IDLE;
                        data_out_d = data_q;
                        dio_out_d = 0;
                    end
                end
            end

            default:
                next_state = S_IDLE;
        endcase
    end

    always @(posedge clk)
    begin
        if (rst)
        begin
            cur_state <= S_IDLE;
            sclk_q <= 0;
            ctr_q <= 0;
            dio_out <= 0;
            data_q <= 0;
            data_out_q <= 0;
        end
        else
        begin
            cur_state <= next_state;
            sclk_q <= sclk_d;
            ctr_q <= ctr_d;
            dio_out <= dio_out_d;
            data_q <= data_d;
            data_out_q <= data_out_d;
        end
    end
endmodule
