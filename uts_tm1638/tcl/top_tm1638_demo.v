// ============================================================
//  top_tm1638_demo.v
//  Board  : iCESugar v1.5 (iCE40UP5K-SG48)
//  Modul  : TM1638 LED & KEY
//
//  Fungsi :
//  - Tombol S1..S8 berfungsi sebagai 8 buah switch (toggle).
//    S1 = bit 7 (MSB) ... S8 = bit 0 (LSB).
//  - LED 1..8 menunjukkan nilai biner switch.
//  - Digit 1-2 (kiri)   : nilai switch dalam HEXADESIMAL
//  - Digit 6-8 (kanan)  : nilai switch dalam DESIMAL
//    Contoh: 8'b10101010 -> "AA   170"
// ============================================================
module top_tm1638_demo(
    input clk,

    output reg tm_cs,
    output tm_clk,
    inout  tm_dio
    );

    localparam
        HIGH    = 1'b1,
        LOW     = 1'b0;

    localparam [6:0]
        S_BLK   = 7'b0000000;          // digit kosong

    localparam [7:0]
        C_READ  = 8'b01000010,         // mode baca tombol
        C_WRITE = 8'b01000000,         // mode tulis, alamat auto-increment
        C_DISP  = 8'b10001111,         // display on, kecerahan maksimum
        C_ADDR  = 8'b11000000;         // mulai dari alamat 0

    reg rst = HIGH;                    // reset otomatis saat power-on

    reg [5:0]  instruction_step;
    reg [18:0] counter;                // 2^19 / 12 MHz ~ 44 ms (interval sampling tombol)

    reg [7:0] keys;                    // status tombol saat ini
    reg [7:0] keys_prev;               // sampel tombol sebelumnya (~44 ms lalu)
    reg [7:0] keys_db;                 // status tombol yang sudah stabil (debounced)
    reg [7:0] sw;                      // nilai "switch" 8 bit
    reg [7:0] rd_wait;                 // jeda setelah perintah baca (Twait TM1638)

    // ========================================================
    //  Decoder 7 segment (urutan bit: g f e d c b a)
    // ========================================================
    function [6:0] seg7;
        input [3:0] v;
        case (v)
            4'h0: seg7 = 7'b0111111;
            4'h1: seg7 = 7'b0000110;
            4'h2: seg7 = 7'b1011011;
            4'h3: seg7 = 7'b1001111;
            4'h4: seg7 = 7'b1100110;
            4'h5: seg7 = 7'b1101101;
            4'h6: seg7 = 7'b1111101;
            4'h7: seg7 = 7'b0000111;
            4'h8: seg7 = 7'b1111111;
            4'h9: seg7 = 7'b1101111;
            4'hA: seg7 = 7'b1110111;   // A
            4'hB: seg7 = 7'b1111100;   // b
            4'hC: seg7 = 7'b0111001;   // C
            4'hD: seg7 = 7'b1011110;   // d
            4'hE: seg7 = 7'b1111001;   // E
            4'hF: seg7 = 7'b1110001;   // F
        endcase
    endfunction

    // ========================================================
    //  Konversi nilai switch
    // ========================================================
    // Hexadesimal: cukup pecah per 4 bit (nibble)
    wire [3:0] hex_hi  = sw[7:4];
    wire [3:0] hex_lo  = sw[3:0];

    // Desimal: ratusan, puluhan, satuan
    wire [3:0] dec_100 = sw / 100;
    wire [3:0] dec_10  = (sw / 10) % 10;
    wire [3:0] dec_1   = sw % 10;

    // Pola segmen tiap digit
    wire [6:0] dig1 = seg7(hex_hi);
    wire [6:0] dig2 = seg7(hex_lo);
    // nol di depan disembunyikan: 5 tampil "  5", bukan "005"
    wire [6:0] dig6 = (dec_100 != 0)                ? seg7(dec_100) : S_BLK;
    wire [6:0] dig7 = (dec_100 != 0 || dec_10 != 0) ? seg7(dec_10)  : S_BLK;
    wire [6:0] dig8 = seg7(dec_1);

    // ========================================================
    //  Pin DIO tiga keadaan (tulis / baca)
    // ========================================================
    reg  tm_rw;
    wire dio_in, dio_out;
    SB_IO #(
        .PIN_TYPE(6'b101001),
        .PULLUP(1'b1)
    ) tm_dio_io (
        .PACKAGE_PIN(tm_dio),
        .OUTPUT_ENABLE(tm_rw),
        .D_IN_0(dio_in),
        .D_OUT_0(dio_out)
    );

    // ========================================================
    //  Driver TM1638 (kirim / terima 1 byte)
    // ========================================================
    reg  tm_latch;
    wire busy;
    wire [7:0] tm_data, tm_in;
    reg  [7:0] tm_out;

    assign tm_in   = tm_data;
    assign tm_data = tm_rw ? tm_out : 8'hZZ;

    tm1638 u_tm1638 (
        .clk(clk),
        .rst(rst),
        .data_latch(tm_latch),
        .data(tm_data),
        .rw(tm_rw),
        .busy(busy),
        .sclk(tm_clk),
        .dio_in(dio_in),
        .dio_out(dio_out)
    );

    // kirim pola 1 digit
    // dp = titik desimal; menyala selama tombol di bawah digit itu
    //      terbaca sedang ditekan (berguna untuk mengecek pembacaan tombol)
    task display_digit;
        input [6:0] segs;
        input dp;
        begin
            tm_latch <= HIGH;
            tm_out   <= {dp, segs};
        end
    endtask

    // kirim status 1 LED
    task display_led;
        input on;
        begin
            tm_latch <= HIGH;
            tm_out   <= {7'b0, on};
        end
    endtask

    // ========================================================
    //  Logika utama
    // ========================================================
    always @(posedge clk) begin
        if (rst) begin
            instruction_step <= 6'b0;
            tm_cs     <= HIGH;
            tm_rw     <= HIGH;
            rst       <= LOW;
            counter   <= 0;
            keys      <= 8'b0;
            keys_prev <= 8'b0;
            keys_db   <= 8'b0;
            sw        <= 8'b0;
            rd_wait   <= 8'd0;

        end else begin
            counter <= counter + 1;

            // ---- tombol -> switch (toggle) dengan debounce ----
            // Sampel tombol diambil tiap ~44 ms. Status tombol baru dianggap
            // berubah kalau 2 sampel berturut-turut nilainya sama, sehingga
            // pantulan tombol / bacaan yang salah sesaat diabaikan.
            if (&counter) begin
                keys_prev <= keys;
                // keys == FF dianggap bacaan rusak (DIO tidak ditarik LOW),
                // jadi diabaikan supaya sw tidak langsung menjadi FF
                if (keys == keys_prev && keys != 8'hFF) begin
                    keys_db <= keys;
                    sw <= sw ^ (keys & ~keys_db);  // balik bit yg baru ditekan
                end
            end

            // ---- jeda sebelum mulai membaca tombol ----
            if (rd_wait != 0 && ~busy)
                rd_wait <= rd_wait - 1;

            // ---- urutan komunikasi dengan TM1638 ----
            if (counter[0] && ~busy && rd_wait == 0) begin
                case (instruction_step)
                    // *** BACA TOMBOL ***
                    1:  {tm_cs, tm_rw}     <= {LOW, HIGH};
                    2:  begin
                            {tm_latch, tm_out} <= {HIGH, C_READ};
                            rd_wait <= 8'd120;   // ~10 us (datasheet: min 2 us)
                        end
                    3:  {tm_latch, tm_rw}  <= {HIGH, LOW};

                    4:  {keys[7], keys[3]} <= {tm_in[0], tm_in[4]}; // S1, S5
                    5:  {tm_latch}         <= {HIGH};
                    6:  {keys[6], keys[2]} <= {tm_in[0], tm_in[4]}; // S2, S6
                    7:  {tm_latch}         <= {HIGH};
                    8:  {keys[5], keys[1]} <= {tm_in[0], tm_in[4]}; // S3, S7
                    9:  {tm_latch}         <= {HIGH};
                    10: {keys[4], keys[0]} <= {tm_in[0], tm_in[4]}; // S4, S8
                    11: {tm_cs}            <= {HIGH};

                    // *** TULIS DISPLAY ***
                    12: {tm_cs, tm_rw}     <= {LOW, HIGH};
                    13: {tm_latch, tm_out} <= {HIGH, C_WRITE};
                    14: {tm_cs}            <= {HIGH};

                    15: {tm_cs, tm_rw}     <= {LOW, HIGH};
                    16: {tm_latch, tm_out} <= {HIGH, C_ADDR};

                    17: display_digit(dig1, keys[7]);   // digit 1 : hex tinggi
                    18: display_led(sw[7]);    // LED 1   : bit 7
                    19: display_digit(dig2, keys[6]);   // digit 2 : hex rendah
                    20: display_led(sw[6]);
                    21: display_digit(S_BLK, keys[5]);  // digit 3 : kosong
                    22: display_led(sw[5]);
                    23: display_digit(S_BLK, keys[4]);  // digit 4 : kosong
                    24: display_led(sw[4]);
                    25: display_digit(S_BLK, keys[3]);  // digit 5 : kosong
                    26: display_led(sw[3]);
                    27: display_digit(dig6, keys[2]);   // digit 6 : ratusan
                    28: display_led(sw[2]);
                    29: display_digit(dig7, keys[1]);   // digit 7 : puluhan
                    30: display_led(sw[1]);
                    31: display_digit(dig8, keys[0]);   // digit 8 : satuan
                    32: display_led(sw[0]);    // LED 8   : bit 0

                    33: {tm_cs}            <= {HIGH};

                    34: {tm_cs, tm_rw}     <= {LOW, HIGH};
                    35: {tm_latch, tm_out} <= {HIGH, C_DISP};
                    36: {tm_cs, instruction_step} <= {HIGH, 6'b0};
                endcase

                instruction_step <= instruction_step + 1;

            end else if (busy) begin
                tm_latch <= LOW;
            end
        end
    end
endmodule
