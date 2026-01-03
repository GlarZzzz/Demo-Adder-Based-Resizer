`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/03/2026 03:20:18 PM
// Design Name: 
// Module Name: Demo_Adder_Base_Resize_Design_Source
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


module Demo_Adder_Base_Resize_Design_Source #(
    parameter DATA_WIDTH          = 24,
    parameter USER_WIDTH          = 1,
    parameter SRC_WIDTH           = 1280,
    parameter SRC_HEIGHT          = 720,
    parameter DST_WIDTH           = 640,
    parameter DST_HEIGHT          = 480,
    parameter NUM_LINES_IN_BUFFER = 4,
    parameter FRAC_BITS           = 16
    
    )
    (
    input  wire                   aclk,
    input  wire                   aresetn,
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,
    input  wire [USER_WIDTH-1:0]  s_axis_tuser,
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast,
    output wire [USER_WIDTH-1:0]  m_axis_tuser
    );
    
    localparam ADDR_BITS_X           = $clog2(SRC_WIDTH);
    localparam ADDR_BITS_Y           = $clog2(SRC_HEIGHT);
    localparam LINE_BUFFER_ADDR_BITS = $clog2(NUM_LINES_IN_BUFFER);
    localparam COUNT_BITS_X_OUT      = $clog2(DST_WIDTH);
    localparam COUNT_BITS_Y_OUT      = $clog2(DST_HEIGHT);

    localparam S_IDLE            = 3'd0, S_START_ROW       = 3'd1, S_PROCESS_PIXEL   = 3'd2,
               S_OUTPUT_PIXEL    = 3'd3, S_WAIT_TRANSFER   = 3'd4;

    reg [DATA_WIDTH-1:0] line_buffer [0:(NUM_LINES_IN_BUFFER * SRC_WIDTH) - 1];

    reg [ADDR_BITS_X-1:0]           in_x_count;
    reg [ADDR_BITS_Y-1:0]           in_y_count;
    reg [LINE_BUFFER_ADDR_BITS-1:0] write_line_ptr;

    reg [LINE_BUFFER_ADDR_BITS:0]   lines_available_count;
    reg [ADDR_BITS_Y-1:0]           first_available_line_idx;
    
    reg [2:0]                     out_fsm_state;
    reg                           output_done;
    reg [COUNT_BITS_X_OUT-1:0]    dst_x_count;
    reg [COUNT_BITS_Y_OUT-1:0]    dst_y_count;
    reg [ADDR_BITS_X+FRAC_BITS:0] x_accum_reg;
    reg [ADDR_BITS_Y+FRAC_BITS:0] y_accum_reg;

    reg                           m_axis_tvalid_reg;
    reg [DATA_WIDTH-1:0]          m_axis_tdata_reg;
    reg                           m_axis_tlast_reg;
    reg [USER_WIDTH-1:0]          m_axis_tuser_reg;
    

    wire [ADDR_BITS_X+FRAC_BITS-1:0] x_step = (SRC_WIDTH << FRAC_BITS) / DST_WIDTH;
    wire [ADDR_BITS_Y+FRAC_BITS-1:0] y_step = (SRC_HEIGHT << FRAC_BITS) / DST_HEIGHT;
    
    wire buffer_is_full            = (lines_available_count == NUM_LINES_IN_BUFFER);
    wire [LINE_BUFFER_ADDR_BITS+ADDR_BITS_X-1:0] write_addr = (write_line_ptr * SRC_WIDTH) + in_x_count;
    assign s_axis_tready           = !buffer_is_full;
    wire reset_all                 = s_axis_tvalid && s_axis_tready && s_axis_tuser;
    
    wire [ADDR_BITS_X-1:0] src_x_addr_needed = x_accum_reg >> FRAC_BITS;
    wire [ADDR_BITS_Y-1:0] src_y_addr_needed = y_accum_reg >> FRAC_BITS;
    
    wire src_line_is_available     = (lines_available_count > 0) &&
                                     (src_y_addr_needed >= first_available_line_idx) &&
                                     (src_y_addr_needed < (in_y_count));

    wire [LINE_BUFFER_ADDR_BITS-1:0] read_line_ptr = src_y_addr_needed % NUM_LINES_IN_BUFFER;
    wire [LINE_BUFFER_ADDR_BITS+ADDR_BITS_X-1:0] read_addr = (read_line_ptr * SRC_WIDTH) + src_x_addr_needed;
    
    wire line_is_written = s_axis_tvalid && s_axis_tready && s_axis_tlast;
    wire line_is_freed   = (lines_available_count > 0) && (src_y_addr_needed > first_available_line_idx) && !reset_all;


    always @(posedge aclk) begin
        if (!aresetn || reset_all) begin
            in_x_count <= 0;
            in_y_count <= 0;
            write_line_ptr <= 0;
        end else begin
            if (s_axis_tvalid && s_axis_tready) begin
                line_buffer[write_addr] <= s_axis_tdata;

                if (s_axis_tlast) begin
                    in_x_count <= 0;
                    in_y_count <= in_y_count + 1;
                    write_line_ptr <= write_line_ptr + 1;
                end else begin
                    in_x_count <= in_x_count + 1;
                end
            end
        end
    end


    always @(posedge aclk) begin
        if (!aresetn) begin
            out_fsm_state     <= S_IDLE;
            dst_x_count       <= 0; dst_y_count       <= 0;
            x_accum_reg       <= 0; y_accum_reg       <= 0;
            m_axis_tvalid_reg <= 1'b0; m_axis_tlast_reg  <= 1'b0;
            m_axis_tuser_reg  <= 1'b0; output_done       <= 1'b1;
        end else if (reset_all) begin
            output_done       <= 1'b0; out_fsm_state     <= S_IDLE;
            dst_x_count       <= 0; dst_y_count       <= 0;
            x_accum_reg       <= 0; y_accum_reg       <= 0;
            m_axis_tvalid_reg <= 1'b0; m_axis_tlast_reg  <= 1'b0;
            m_axis_tuser_reg  <= 1'b0;
        end else begin
            case (out_fsm_state)
                S_IDLE: if (!output_done) begin
                    out_fsm_state <= S_START_ROW;
                end
                S_START_ROW: begin
                    dst_x_count <= 0; x_accum_reg <= 0;
                    out_fsm_state <= S_PROCESS_PIXEL;
                end
                S_PROCESS_PIXEL: if (src_line_is_available) begin
                    m_axis_tdata_reg <= line_buffer[read_addr];
                    out_fsm_state    <= S_OUTPUT_PIXEL;
                end
                S_OUTPUT_PIXEL: begin
                    m_axis_tvalid_reg <= 1'b1;
                    m_axis_tlast_reg  <= (dst_x_count == DST_WIDTH - 1);
                    m_axis_tuser_reg  <= (dst_x_count == 0) && (dst_y_count == 0);
                    out_fsm_state     <= S_WAIT_TRANSFER;
                end
                S_WAIT_TRANSFER: if (m_axis_tready) begin
                    m_axis_tvalid_reg <= 1'b0; m_axis_tuser_reg  <= 1'b0;
                    if (dst_x_count < DST_WIDTH - 1) begin
                        dst_x_count <= dst_x_count + 1;
                        x_accum_reg <= x_accum_reg + x_step;
                        out_fsm_state <= S_PROCESS_PIXEL;
                    end else begin
                        if (dst_y_count < DST_HEIGHT - 1) begin
                            dst_y_count <= dst_y_count + 1;
                            y_accum_reg <= y_accum_reg + y_step;
                            out_fsm_state <= S_START_ROW;
                        end else begin
                            output_done   <= 1'b1;
                            out_fsm_state <= S_IDLE;
                        end
                    end
                end
            endcase
        end
    end
    

    always @(posedge aclk) begin
        if (!aresetn || reset_all) begin
            lines_available_count    <= 0;
            first_available_line_idx <= 0;
        end else begin
            if (line_is_written && !line_is_freed) begin
                lines_available_count <= lines_available_count + 1;
            end else if (!line_is_written && line_is_freed) begin
                lines_available_count    <= lines_available_count - 1;
                first_available_line_idx <= first_available_line_idx + 1;
            end else if (line_is_written && line_is_freed) begin

                first_available_line_idx <= first_available_line_idx + 1;
            end
        end
    end


    assign m_axis_tdata  = m_axis_tdata_reg;
    assign m_axis_tvalid = m_axis_tvalid_reg;
    assign m_axis_tlast  = m_axis_tlast_reg;
    assign m_axis_tuser  = m_axis_tuser_reg;

endmodule
