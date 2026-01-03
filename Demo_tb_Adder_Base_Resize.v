`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/03/2026 03:58:16 PM
// Design Name: 
// Module Name: Demo_tb_Adder_Base_Resize
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Demo_tb_Adder_Base_Resize;

    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 24;
    localparam USER_WIDTH = 1;
    localparam SRC_WIDTH  = 1280;
    localparam SRC_HEIGHT = 720;
    localparam DST_WIDTH  = 640;
    localparam DST_HEIGHT = 480;
    localparam FRAC_BITS  = 16;
    localparam INPUT_PIXEL_FILE  = "verilog_input_pixels_rgb_interleaved.hex";
    localparam OUTPUT_PIXEL_FILE = "verilog_output_pixels.txt";
    localparam TOTAL_SRC_PIXELS = SRC_WIDTH * SRC_HEIGHT;
    localparam TOTAL_DST_PIXELS = DST_WIDTH * DST_HEIGHT;


    reg                   aclk;
    reg                   aresetn;
    reg [DATA_WIDTH-1:0]  s_axis_tdata_tb;
    reg                   s_axis_tvalid_tb;
    wire                  s_axis_tready_tb;
    reg                   s_axis_tlast_tb;
    reg [USER_WIDTH-1:0]  s_axis_tuser_tb;
    wire [DATA_WIDTH-1:0] m_axis_tdata_tb;
    wire                  m_axis_tvalid_tb;
    reg                   m_axis_tready_tb;
    wire                  m_axis_tlast_tb;
    wire [USER_WIDTH-1:0] m_axis_tuser_tb;
    reg [DATA_WIDTH-1:0]  src_image_mem[0:TOTAL_SRC_PIXELS-1];
    integer               src_pixel_idx;
    integer               dst_pixel_idx;
    integer               output_file_handle;


    Demo_Adder_Base_Resize_Design_Source (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata_tb), .s_axis_tvalid(s_axis_tvalid_tb), .s_axis_tready(s_axis_tready_tb),
        .s_axis_tlast(s_axis_tlast_tb), .s_axis_tuser(s_axis_tuser_tb),
        .m_axis_tdata(m_axis_tdata_tb), .m_axis_tvalid(m_axis_tvalid_tb), .m_axis_tready(m_axis_tready_tb), //
        .m_axis_tlast(m_axis_tlast_tb), .m_axis_tuser(m_axis_tuser_tb)
    );

    always #((CLK_PERIOD)/2) aclk = ~aclk;

    initial begin
        $readmemh(INPUT_PIXEL_FILE, src_image_mem, 0, TOTAL_SRC_PIXELS-1);
        $display("TB: Attempting to load %0d pixels from %s.", TOTAL_SRC_PIXELS, INPUT_PIXEL_FILE);
        output_file_handle = $fopen(OUTPUT_PIXEL_FILE, "w");
        if (output_file_handle == 0) begin $display("TB ERROR: Could not open %s", OUTPUT_PIXEL_FILE); $finish; end
    end

    initial begin
        aclk <= 0; aresetn <= 0; s_axis_tvalid_tb <= 0; s_axis_tuser_tb <= 0; m_axis_tready_tb <= 0;
        src_pixel_idx <= 0; dst_pixel_idx <= 0;
        
        repeat (5) @(posedge aclk);
        aresetn <= 1'b1;
        repeat (2) @(posedge aclk);
        

        m_axis_tready_tb <= 1'b1;
        
        fork
            begin : SOURCE_PROCESS
                for (src_pixel_idx=0; src_pixel_idx < TOTAL_SRC_PIXELS; src_pixel_idx=src_pixel_idx+1) begin
                    s_axis_tvalid_tb <= 1'b1;
                    s_axis_tdata_tb  <= src_image_mem[src_pixel_idx];
                    

                    s_axis_tuser_tb  <= (src_pixel_idx == 0); 
                    

                    s_axis_tlast_tb  <= ((src_pixel_idx % SRC_WIDTH) == (SRC_WIDTH - 1));
                    
                    @(posedge aclk);
                    while (!s_axis_tready_tb) @(posedge aclk);
                end
                
                s_axis_tvalid_tb <= 1'b0;
                s_axis_tuser_tb  <= 1'b0;
                s_axis_tlast_tb  <= 1'b0; 
                $display("TB: Finished sending all %d source pixels.", src_pixel_idx);
            end

            begin : SINK_PROCESS
                while (dst_pixel_idx < TOTAL_DST_PIXELS) begin
                    @(posedge aclk);
                    if (m_axis_tvalid_tb && m_axis_tready_tb) begin
                        if (dst_pixel_idx < 5 || (dst_pixel_idx > DST_WIDTH - 3 && dst_pixel_idx < DST_WIDTH + 3) ) begin
                           $display("TB: Received dst_pixel[%0d], TUSER=%b, TLAST=%b, TDATA=%h", dst_pixel_idx, m_axis_tuser_tb, m_axis_tlast_tb, m_axis_tdata_tb);
                        end
                        $fdisplay(output_file_handle, "%h", m_axis_tdata_tb);
                        dst_pixel_idx = dst_pixel_idx + 1;
                    end
                end
                
                @(posedge aclk);
                $display("TB: SUCCESS! Received all %d destination pixels.", dst_pixel_idx);
                $fclose(output_file_handle); 
                $finish;
            end
        join


        #((TOTAL_SRC_PIXELS + TOTAL_DST_PIXELS) * CLK_PERIOD * 30);
        $display("TB ERROR: Timeout! Simulation did not complete correctly.");
        $fclose(output_file_handle);
        $finish;
    end
 
endmodule
