module puf_16bit (
    input             clk,
    input             rst,
    input             enable,
    output reg [15:0] puf_id,
    output reg        puf_valid
);
    wire [15:0] bits;
    wire [15:0] valids;

    genvar i;
    generate
        for (i = 0; i < 16; i = i+1) begin : BIT
            ro_puf_bit inst (
                .clk    (clk),
                .rst    (rst),
                .enable (enable),
                .puf_bit(bits[i]),
                .valid  (valids[i])
            );
        end
    endgenerate

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            puf_id    <= 0;
            puf_valid <= 0;
        end else if (&valids) begin
            puf_id    <= bits;
            puf_valid <= 1;
        end
    end
endmodule
