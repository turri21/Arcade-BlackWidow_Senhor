//============================================================================
//  Arcade: Black Widow
//
//  Port to MiSTer
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

wire clk_6, clk_12, clk_50, clk_125;
wire pll_locked;

wire [127:0] status;
wire [1:0] ar = status[15:14];

wire  [1:0] buttons;
wire        direct_video;
wire [21:0] gamma_bus;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire        ioctl_rd;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;

wire [15:0] joy_0, joy_1;
wire [15:0] joy = joy_0 | joy_1;
wire        rom_download = ioctl_download && !ioctl_index;
wire [15:0] dl_addr = ioctl_addr[15:0];
wire reset = (RESET | status[0] | buttons[1] | rom_download);

wire hblank, vblank;
wire hs, vs;

wire [11:0] hs_address;
wire  [7:0] hs_data_in;
wire  [7:0] hs_data_out;
wire        hs_write_enable;
wire        hs_access_read;
wire        hs_access_write;
wire        hs_pause;
wire        hs_configured;

reg mod_bwidow   = 0;
reg mod_gravitar = 0;
reg mod_lunarbat = 0;
reg mod_spacduel = 0;
reg [7:0] mod    = 0;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;

wire [15:0] sdram_dq_out;
wire        sdram_dq_oe;
wire  [1:0] sdram_dqm;

assign SDRAM_DQ   = sdram_dq_oe ? sdram_dq_out : 16'hzzzz;
assign SDRAM_DQML = sdram_dqm[0];
assign SDRAM_DQMH = sdram_dqm[1];

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;
assign VGA_SL = 0;
assign USER_OUT  = '1;
wire [2:0] core_led;
assign LED_USER  = core_led[2] | ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign AUDIO_MIX = 0;
assign HDMI_FREEZE = 0;

assign CLK_VIDEO = clk_125;
assign VGA_HS = hs;
assign VGA_VS = vs;
assign VGA_DE = ~(hblank | vblank);

// Debounced output mode and 120 Hz selection
reg [11:0] h_s1 = 0, h_s2 = 0;
reg [11:0] hdmi_height_candidate = 0;
reg [11:0] stable_height_reg = 0;
reg [24:0] hdmi_height_timer = 0;
reg direct_video_s1 = 0, direct_video_s2 = 0;
reg direct_video_31khz_s1 = 0, direct_video_31khz_s2 = 0;

always @(posedge clk_50) begin
	direct_video_s1 <= direct_video;
	direct_video_s2 <= direct_video_s1;
	direct_video_31khz_s1 <= status[115];
	direct_video_31khz_s2 <= direct_video_31khz_s1;

	if (direct_video_s2)
		h_s1 <= direct_video_31khz_s2 ? 12'd480 : 12'd240;
	else
		h_s1 <= HDMI_HEIGHT;
	h_s2 <= h_s1;

	if (h_s1 == h_s2) begin
		if (h_s2 > 12'd200 && h_s2 == hdmi_height_candidate) begin
			if (hdmi_height_timer < 25'd25_000_000) begin
				hdmi_height_timer <= hdmi_height_timer + 1'd1;
			end else begin
				stable_height_reg <= hdmi_height_candidate;
			end
		end else begin
			hdmi_height_candidate <= h_s2;
			hdmi_height_timer <= 0;
			stable_height_reg <= 0;
		end
	end
end

reg hz_s1 = 0, hz_s2 = 0;
reg osd_120hz_latched = 0;
reg [24:0] hz_timer = 0;

always @(posedge clk_50) begin
	hz_s1 <= status[25];
	hz_s2 <= hz_s1;

	if (hz_s1 == hz_s2) begin
		if (hz_s2 != osd_120hz_latched) begin
			if (hz_timer < 25'd25_000_000) begin
				hz_timer <= hz_timer + 1'd1;
			end else begin
				osd_120hz_latched <= hz_s2;
				hz_timer <= 0;
			end
		end else begin
			hz_timer <= 0;
		end
	end
end

wire is_120hz_changing = (hz_s2 != osd_120hz_latched) || (hz_timer > 0);
wire [11:0] STABLE_HEIGHT = is_120hz_changing ? 12'd0 : stable_height_reg;
wire STABLE_120HZ = osd_120hz_latched & (STABLE_HEIGHT == 12'd720);

// Profile selection and custom settings
wire [2:0] crt_profile = status[68:66] + 3'd2;
wire       crt_profile_off        = (crt_profile == 3'd0);
wire       crt_profile_touch      = (crt_profile == 3'd1);
wire       crt_profile_typical    = (crt_profile == 3'd2);
wire       crt_profile_overdriven = (crt_profile == 3'd3);
wire       crt_profile_neon       = (crt_profile == 3'd4);
wire       crt_profile_pink       = (crt_profile == 3'd5);
wire       crt_profile_custom1    = (crt_profile == 3'd6);
wire       crt_profile_custom2    = (crt_profile == 3'd7);
wire       crt_profile_flashing   = crt_profile_neon | crt_profile_pink;

wire [2:0] crt_custom_bloom_width =
	crt_profile_custom2 ? status[99:97] : status[76:74];
wire [2:0] crt_custom_halo =
	crt_profile_custom2 ? status[105:103] : status[82:80];
wire       crt_custom_active = crt_profile_custom1 | crt_profile_custom2;
wire       crt_custom_bloom_width_off =
	crt_custom_active && (crt_custom_bloom_width == 3'd0);
wire       crt_custom_halo_off =
	crt_custom_active && (crt_custom_halo == 3'd0);
wire [1:0] osd_off_tonemapping = status[38:37] + 2'd1;
wire [1:0] osd_custom1_tonemapping = status[73:72] + 2'd1;
wire [1:0] osd_custom2_tonemapping = status[96:95] + 2'd1;

wire [22:0] crt_custom1_settings = {
	status[71:69],
	osd_custom1_tonemapping,
	status[76:74],
	status[79:77],
	status[82:80],
	status[84:83],
	status[86:85],
	status[87],
	status[90:88],
	status[91]
};

wire [22:0] crt_custom2_settings = {
	status[94:92],
	osd_custom2_tonemapping,
	status[99:97],
	status[102:100],
	status[105:103],
	status[107:106],
	status[109:108],
	status[110],
	status[113:111],
	status[114]
};

`include "build_id.v" 
localparam CONF_STR = {
	"Black Widow;;",
	"-;",
	"P3,Video Options;",
	"P3-;",
	"P3O[15:14],Aspect ratio,Optimized,Stretched,Pixel Perfect;",
	"D3P3O[25],120Hz (720p only),Off,On;",
	"h0P3O[115],Direct Video Scan Rate,15 kHz,31 kHz;",
	"P3O[40:39],Buffer Mode,EOF + VBL,VBL,EOF;",
	"P3-;",
	"P3O[68:66],Profile,80s Cruise Control,80s Overdrive,Neon Fever Dream,Pinktoe Tarantula,Custom 1,Custom 2,Off,A Touch of CRT;",
	"h7P3O[30:28],Dot Scale,Auto,Pixel,2x,2.5x;",
	"h7P3O[38:37],Tone Mapping,Linear 2,Bright,Off,Linear 1;",
	"h7P3O[56:55],Phosphor Decay,Off,LUT A,LUT B,LUT C;",
	"h7P3-;",
	"h7P3-, For advanced settings;",
	"h7P3-, select Custom Profiles 1/2;",
	"h8P3-;",
	"h8P3-,This profile adds a subtle;",
	"h8P3-,CRT halo and bloom effect,;",
	"h8P3-,to modern AA vector drawing;",
	"h8P3-;",
	"h8P3-,   Use Custom Profiles 1/2;",
	"h8P3-, to create your own effects;",
	"h9P3-;",
	"h9P3-,Step away from the modern..;",
	"h9P3-,The Amplifone Slot-Mask adds;",
	"h9P3-,faint vertical CRT stripes +;",
	"h9P3-,richer halos and blooming.;",
	"h9P3-,A new color space setting;",
	"h9P3-,delivers authentic blues.;",
	"h9P3-;",
	"h9P3-,Warning: Overdrive is next;",
	"hAP3-;",
	"hAP3-,A remote arcade in the 80s:;",
	"hAP3-,CRTs overdriven and abused;",
	"hAP3-,pulsate with vector glow.;",
	"hAP3-;",
	"hAP3-,Phosphor decay simulation;",
	"hAP3-,depends highly on your;",
	"hAP3-,monitor's panel type and;",
	"hAP3-,settings;",
	"hAP3-;",
	"hBP3-;",
	"hBP3-,     Epilepsy warning:;",
	"hBP3-,    excessive flashing;",
	"hBP3-,       bright lights;",
	"hBP3-;",
	"hBP3-,   Use Custom Profiles 1/2;",
	"hBP3-, to create your own effects;",
	"hDP3O[71:69],> Dot Scale,Auto,Pixel,2x,2.5x;",
	"hDP3O[73:72],> Tone Mapping,Linear 2,Bright,Off,Linear 1;",
	"hDP3O[76:74],> Bloom Width,Off,Thin,Tight,Soft,Normal,Broad,Wide-,Wide;",
	"hDD5P3O[79:77],> Bloom Curve,Minimal,Min+,Mild,Mild+,Moderate,Mod+,Strong-,Strong;",
	"hDP3O[82:80],> Halo,Off,0.25x,0.33x,0.5x,0.75x,1.0x,1.25x,1.5x;",
	"hDD6P3O[84:83],> Halo Spread,Original,Wide 1,Wide 2,Wide 3;",
	"hDP3O[86:85],> Phosphor Decay,Off,LUT A,LUT B,LUT C;",
	"hDP3O[87],> Color Space,Off,Amp709;",
	"hDP3O[90:88],> Color Channels,RGB,RBG,GRB,GBR,BRG,BGR,B/W,Toe;",
	"hDP3O[91],> Slot Mask,Off,On;",
	"hEP3O[94:92],> Dot Scale,Auto,Pixel,2x,2.5x;",
	"hEP3O[96:95],> Tone Mapping,Linear 2,Bright,Off,Linear 1;",
	"hEP3O[99:97],> Bloom Width,Off,Thin,Tight,Soft,Normal,Broad,Wide-,Wide;",
	"hED5P3O[102:100],> Bloom Curve,Minimal,Min+,Mild,Mild+,Moderate,Mod+,Strong-,Strong;",
	"hEP3O[105:103],> Halo,Off,0.25x,0.33x,0.5x,0.75x,1.0x,1.25x,1.5x;",
	"hED6P3O[107:106],> Halo Spread,Original,Wide 1,Wide 2,Wide 3;",
	"hEP3O[109:108],> Phosphor Decay,Off,LUT A,LUT B,LUT C;",
	"hEP3O[110],> Color Space,Off,Amp709;",
	"hEP3O[113:111],> Color Channels,RGB,RBG,GRB,GBR,BRG,BGR,B/W,Toe;",
	"hEP3O[114],> Slot Mask,Off,On;",
	"-;",
	"h2O6,Fire Controls,Normal,P2 Controller;",
	"h2-;",
	"H1OR,Autosave Hiscores,Off,On;",
	"P1,Pause options;",
	"P1O[116],Pause when OSD is open,Off,On;",
	"P1O[117],Dim video after 10s,On,Off;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Fire Right,Fire Left,Fire Up,Fire Down,Start 1,Start 2,Coin,Pause,Aux Coin;",
	"jn,A,Y,X,B,Start,Select,R,L;",
	"V,v3.00.",`BUILD_DATE
};


/*
-------------------------------------------------------------------------------
Settings of 8-Toggle Switch on Black Widow CPU PCB (at D4)
 8   7   6   5   4   3   2   1   Option
-------------------------------------------------------------------------------
Off Off                          1 coin/1 credit <
On  On                           1 coin/2 credits
On  Off                          2 coins/1 credit
Off On                           Free play

        Off Off                  Right coin mechanism x 1 <
        On  Off                  Right coin mechanism x 4
        Off On                   Right coin mechanism x 5
        On  On                   Right coin mechanism x 6

                Off              Left coin mechanism x 1 <
                On               Left coin mechanism x 2

                    Off Off Off  No bonus coins (0)* <
                    Off On  On   No bonus coins (6)
                    On  On  On   No bonus coins (7)

                    On  Off Off  For every 2 coins inserted,
                                 logic adds 1 more coin (1)
                    Off On  Off  For every 4 coins inserted,
                                 logic adds 1 more coin (2)
                    On  On  Off  For every 4 coins inserted,
                                 logic adds 2 more coins (3)
                    Off Off On   For every 5 coins inserted,
                                 logic adds 1 more coin (4)
                    On  Off On   For every 3 coins inserted,
                                 logic adds 1 more coin (5)

-------------------------------------------------------------------------------

* The numbers in parentheses will appear on the BONUS ADDER line in the
  Operator Information Display (Figure 2-1) for these settings.
< Manufacturer's recommended setting


                Table 1-3  Switch Settings for Special Options

-------------------------------------------------------------------------------
Settings of 4-Toggle Switch on Black Widow CPU PCB (at P10/11)
 4   3   2   1                   Option
-------------------------------------------------------------------------------
            On                   Credits counted on one coin counter
            Off                  Credits counted on two separate coin counters
-------------------------------------------------------------------------------


          Table 1-4  Switch Settings for Bonus and Difficulty Options

-------------------------------------------------------------------------------
Settings of 8-Toggle Switch on Black Widow CPU PCB (at B4)
 8   7   6   5   4   3   2   1   Option
-------------------------------------------------------------------------------
Off Off                          Maximum start at level 13
On  Off                          Maximum start at level 21 <
Off On                           Maximum start at level 37
On  On                           Maximum start at level 53

        Off Off                  3 spiders per game <
        On  Off                  4 spiders per game
        Off On                   5 spiders per game
        On  On                   6 spiders per game

                Off Off          Easy game play
                On  Off          Medium game play <
                Off On           Hard game play
                On  On           Demonstration mode

                        Off Off  Bonus spider every 20,000 points <
                        On  Off  Bonus spider every 30,000 points
                        Off On   Bonus spider every 40,000 points
                        On  On   No bonus

*/

// Clock generation

assign SDRAM_CLK = ~clk_125;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_50),
	.outclk_1(clk_12),
	.outclk_2(clk_6),
	.outclk_3(clk_125),
	.locked(pll_locked)
);

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_12),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({
		1'b0,
		crt_profile_custom2,
		crt_profile_custom1,
		1'b0,
		crt_profile_flashing,
		crt_profile_overdriven,
		crt_profile_typical,
		crt_profile_touch,
		crt_profile_off,
		crt_custom_halo_off,
		crt_custom_bloom_width_off,
		1'b0,
		STABLE_HEIGHT != 12'd720,
		mod_bwidow,
		~hs_configured,
		direct_video
	}),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_rd(ioctl_rd),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),

	.joystick_0(joy_0),
	.joystick_1(joy_1)
);

always @(posedge clk_12) begin
	if (ioctl_wr && (ioctl_index==1)) mod <= ioctl_dout;
	mod_bwidow     <= ( mod == 0 );
	mod_gravitar   <= ( mod == 1 );
	mod_lunarbat   <= ( mod == 2 );
	mod_spacduel   <= ( mod == 3 );
end

// DIP-switch data from the MRA
reg [7:0] sw[8];
always @(posedge clk_12) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;


wire m_up     = joy_0[3];
wire m_down   = joy_0[2];
wire m_left   = joy_0[1];
wire m_right  = joy_0[0];

// Black Widow fire source: mapped P1 inputs or P2 directional inputs.
wire m_fire_up     = (mod_bwidow && status[6]) ? joy_1[3] : joy_0[6];
wire m_fire_down   = (mod_bwidow && status[6]) ? joy_1[2] : joy_0[7];
wire m_fire_left   = (mod_bwidow && status[6]) ? joy_1[1] : joy_0[5];
wire m_fire_right  = (mod_bwidow && status[6]) ? joy_1[0] : joy_0[4];

wire m_start1 = joy[8];
wire m_start2 = joy[9];
wire m_coin    = joy[10];
wire m_coin2   = 0;
wire m_pause   = joy[11];
wire m_auxcoin = joy[12];


// Pause controller
wire pause_cpu;
wire [11:0] pause_rgb_unused;
pause #(4,4,4,50) pause (
	.clk_sys(clk_12),
	.reset(reset),
	.user_button(m_pause),
	.pause_request(hs_pause),
	.options({~status[117], status[116]}),
	.OSD_STATUS(OSD_STATUS),
	.r(4'd0),
	.g(4'd0),
	.b(4'd0),
	.pause_cpu(pause_cpu),
	.rgb_out(pause_rgb_unused)
);

reg [7:0] input_0;
reg [7:0] input_1;
reg [7:0] input_2;
reg [7:0] input_3;
reg [7:0] input_4;
reg clk3k;

// Game-specific DIP and input wiring
always @(*) begin

	input_0 = 8'hff;
	input_1 = sw[0];
	input_2 = sw[1];
	input_3 = 8'hff;
	input_4 = 8'hff;

	if (mod_bwidow) begin
		input_0 = ~{ 1'b0, 1'b1, sw[2][1], sw[2][0], 1'b0, m_auxcoin, m_coin, m_coin2 };
		// P10/11 switches 2-4 drive OPTION2:0 on IN3[7:5].
		input_3 = ~{ sw[2][4:2], 1'b0, m_up, m_down, m_left, m_right };
		input_4 = ~{ 1'b0, m_start2, m_start1, 1'b0, m_fire_up, m_fire_down, m_fire_left, m_fire_right };
	end
	else if (mod_gravitar) begin
		input_0 = ~{ 1'b0, 1'b1, sw[2][1], sw[2][0], 1'b0, m_auxcoin, m_coin, m_coin2 };
		// P10/11 switches 2-4 drive OPTION2:0 on IN3[7:5].
		input_3 = ~{ sw[2][4:2], m_fire_left, m_left, m_right, m_fire_right, m_fire_down };
		input_4 = ~{ 1'b0, m_start2, m_start1, 5'b0 };
	end
	else if (mod_lunarbat) begin
		input_0 = ~{ 1'b0, 1'b1, sw[2][1], sw[2][0], 2'b0, (m_coin | m_auxcoin), m_coin2 };
		input_3 = ~{ 3'b0, m_fire_left, m_left, m_right, m_fire_right, m_fire_down };
		input_4 = ~{ 1'b0, m_start2, m_start1, 5'b0 };
	end
	else if (mod_spacduel) begin
	end
end

wire [7:0] audio;
assign AUDIO_L = {audio, audio};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

wire [13:0] avg_x;
wire [13:0] avg_y;
wire [7:0]  avg_z_raw;
wire [7:0]  avg_z;
wire [2:0]  avg_rgb;
wire        avg_is_dot;
wire        avg_halted;

BWIDOW_TOP BWIDOW_TOP
(
	.AUDIO_OUT(audio),
	
	.dn_addr(dl_addr),
	.dn_wr(ioctl_wr & rom_download),
	.dn_data(ioctl_dout),

	.AVG_X_OUT(avg_x),
	.AVG_Y_OUT(avg_y),
	.AVG_Z_OUT(avg_z_raw),
	.AVG_RGB_OUT(avg_rgb),
	.AVG_IS_DOT_OUT(avg_is_dot),
	.AVG_HALTED_OUT(avg_halted),
	
	.input_0(input_0),
	.input_3(input_3),
	.input_4(input_4),

	.SW_B4(input_2),
	.SW_D4(input_1),

	.RESET_L(~reset),
	.clk_6(clk_6),
	.clk_12(clk_12),

	.pause_h(pause_cpu),

	.hs_address(hs_address),
	.hs_data_out(hs_data_out),
	.hs_data_in(hs_data_in),
	.hs_write(hs_write_enable)
);

wire [2:0] effective_dot_mode;
wire [1:0] effective_tonemapping;
wire [2:0] effective_bloom_width;
wire [2:0] effective_bloom_curve;
wire [2:0] effective_halo_filter;
wire [1:0] effective_halo_spread;
wire [1:0] effective_phosphor_mode;
wire       effective_color_space;
wire [2:0] effective_color_channels;
wire       effective_slot_mask;
wire       effective_full_bypass;

(* romstyle = "logic" *) reg [7:0] z_lut[0:255] = '{default:0};
initial begin
	z_lut[0] = 8'd0; z_lut[1] = 8'd2; z_lut[2] = 8'd3; z_lut[3] = 8'd5; z_lut[4] = 8'd7;
	z_lut[5] = 8'd9; z_lut[6] = 8'd10; z_lut[7] = 8'd12; z_lut[8] = 8'd14; z_lut[9] = 8'd15;
	z_lut[10] = 8'd17; z_lut[11] = 8'd19; z_lut[12] = 8'd21; z_lut[13] = 8'd22; z_lut[14] = 8'd24;
	z_lut[15] = 8'd26; z_lut[16] = 8'd27; z_lut[17] = 8'd29; z_lut[18] = 8'd31; z_lut[19] = 8'd33;
	z_lut[20] = 8'd34; z_lut[21] = 8'd36; z_lut[22] = 8'd38; z_lut[23] = 8'd39; z_lut[24] = 8'd41;
	z_lut[25] = 8'd43; z_lut[26] = 8'd45; z_lut[27] = 8'd46; z_lut[28] = 8'd48; z_lut[29] = 8'd50;
	z_lut[30] = 8'd52; z_lut[31] = 8'd54; z_lut[32] = 8'd56; z_lut[33] = 8'd58; z_lut[34] = 8'd60;
	z_lut[35] = 8'd62; z_lut[36] = 8'd64; z_lut[37] = 8'd66; z_lut[38] = 8'd68; z_lut[39] = 8'd70;
	z_lut[40] = 8'd72; z_lut[41] = 8'd74; z_lut[42] = 8'd76; z_lut[43] = 8'd78; z_lut[44] = 8'd80;
	z_lut[45] = 8'd82; z_lut[46] = 8'd84; z_lut[47] = 8'd86; z_lut[48] = 8'd88; z_lut[49] = 8'd90;
	z_lut[50] = 8'd92; z_lut[51] = 8'd94; z_lut[52] = 8'd96; z_lut[53] = 8'd98; z_lut[54] = 8'd100;
	z_lut[55] = 8'd102; z_lut[56] = 8'd104; z_lut[57] = 8'd106; z_lut[58] = 8'd108; z_lut[59] = 8'd110;
	z_lut[60] = 8'd112; z_lut[61] = 8'd114; z_lut[62] = 8'd116; z_lut[63] = 8'd118; z_lut[64] = 8'd120;
	z_lut[65] = 8'd122; z_lut[66] = 8'd124; z_lut[67] = 8'd126; z_lut[68] = 8'd128; z_lut[69] = 8'd130;
	z_lut[70] = 8'd132; z_lut[71] = 8'd134; z_lut[72] = 8'd136; z_lut[73] = 8'd138; z_lut[74] = 8'd140;
	z_lut[75] = 8'd142; z_lut[76] = 8'd144; z_lut[77] = 8'd146; z_lut[78] = 8'd148; z_lut[79] = 8'd150;
	z_lut[80] = 8'd152; z_lut[81] = 8'd154; z_lut[82] = 8'd156; z_lut[83] = 8'd158; z_lut[84] = 8'd160;
	z_lut[85] = 8'd162; z_lut[86] = 8'd164; z_lut[87] = 8'd166; z_lut[88] = 8'd168; z_lut[89] = 8'd170;
	z_lut[90] = 8'd172; z_lut[91] = 8'd174; z_lut[92] = 8'd176; z_lut[93] = 8'd178; z_lut[94] = 8'd180;
	z_lut[95] = 8'd182; z_lut[96] = 8'd184; z_lut[97] = 8'd186; z_lut[98] = 8'd188; z_lut[99] = 8'd190;
	z_lut[100] = 8'd192; z_lut[101] = 8'd194; z_lut[102] = 8'd196; z_lut[103] = 8'd198; z_lut[104] = 8'd200;
	z_lut[105] = 8'd202; z_lut[106] = 8'd204; z_lut[107] = 8'd206; z_lut[108] = 8'd208; z_lut[109] = 8'd210;
	z_lut[110] = 8'd212; z_lut[111] = 8'd214; z_lut[112] = 8'd216; z_lut[113] = 8'd216; z_lut[114] = 8'd217;
	z_lut[115] = 8'd217; z_lut[116] = 8'd217; z_lut[117] = 8'd217; z_lut[118] = 8'd218; z_lut[119] = 8'd218;
	z_lut[120] = 8'd218; z_lut[121] = 8'd219; z_lut[122] = 8'd219; z_lut[123] = 8'd219; z_lut[124] = 8'd219;
	z_lut[125] = 8'd220; z_lut[126] = 8'd220; z_lut[127] = 8'd220; z_lut[128] = 8'd221; z_lut[129] = 8'd221;
	z_lut[130] = 8'd221; z_lut[131] = 8'd221; z_lut[132] = 8'd222; z_lut[133] = 8'd222; z_lut[134] = 8'd222;
	z_lut[135] = 8'd223; z_lut[136] = 8'd223; z_lut[137] = 8'd223; z_lut[138] = 8'd223; z_lut[139] = 8'd224;
	z_lut[140] = 8'd224; z_lut[141] = 8'd224; z_lut[142] = 8'd225; z_lut[143] = 8'd225; z_lut[144] = 8'd225;
	z_lut[145] = 8'd225; z_lut[146] = 8'd226; z_lut[147] = 8'd226; z_lut[148] = 8'd226; z_lut[149] = 8'd227;
	z_lut[150] = 8'd227; z_lut[151] = 8'd227; z_lut[152] = 8'd227; z_lut[153] = 8'd228; z_lut[154] = 8'd228;
	z_lut[155] = 8'd228; z_lut[156] = 8'd229; z_lut[157] = 8'd229; z_lut[158] = 8'd229; z_lut[159] = 8'd229;
	z_lut[160] = 8'd230; z_lut[161] = 8'd230; z_lut[162] = 8'd230; z_lut[163] = 8'd231; z_lut[164] = 8'd231;
	z_lut[165] = 8'd231; z_lut[166] = 8'd231; z_lut[167] = 8'd232; z_lut[168] = 8'd232; z_lut[169] = 8'd233;
	z_lut[170] = 8'd233; z_lut[171] = 8'd234; z_lut[172] = 8'd234; z_lut[173] = 8'd235; z_lut[174] = 8'd235;
	z_lut[175] = 8'd236; z_lut[176] = 8'd236; z_lut[177] = 8'd237; z_lut[178] = 8'd237; z_lut[179] = 8'd238;
	z_lut[180] = 8'd239; z_lut[181] = 8'd239; z_lut[182] = 8'd240; z_lut[183] = 8'd240; z_lut[184] = 8'd241;
	z_lut[185] = 8'd241; z_lut[186] = 8'd242; z_lut[187] = 8'd242; z_lut[188] = 8'd243; z_lut[189] = 8'd244;
	z_lut[190] = 8'd244; z_lut[191] = 8'd245; z_lut[192] = 8'd245; z_lut[193] = 8'd246; z_lut[194] = 8'd246;
	z_lut[195] = 8'd247; z_lut[196] = 8'd247; z_lut[197] = 8'd248; z_lut[198] = 8'd248; z_lut[199] = 8'd249;
	z_lut[200] = 8'd250; z_lut[201] = 8'd250; z_lut[202] = 8'd251; z_lut[203] = 8'd251; z_lut[204] = 8'd252;
	z_lut[205] = 8'd252; z_lut[206] = 8'd253; z_lut[207] = 8'd253; z_lut[208] = 8'd254; z_lut[209] = 8'd254;
	z_lut[210] = 8'd255; z_lut[211] = 8'd255; z_lut[212] = 8'd255; z_lut[213] = 8'd255; z_lut[214] = 8'd255;
	z_lut[215] = 8'd255; z_lut[216] = 8'd255; z_lut[217] = 8'd255; z_lut[218] = 8'd255; z_lut[219] = 8'd255;
	z_lut[220] = 8'd255; z_lut[221] = 8'd255; z_lut[222] = 8'd255; z_lut[223] = 8'd255; z_lut[224] = 8'd255;
	z_lut[225] = 8'd255; z_lut[226] = 8'd255; z_lut[227] = 8'd255; z_lut[228] = 8'd255; z_lut[229] = 8'd255;
	z_lut[230] = 8'd255; z_lut[231] = 8'd255; z_lut[232] = 8'd255; z_lut[233] = 8'd255; z_lut[234] = 8'd255;
	z_lut[235] = 8'd255; z_lut[236] = 8'd255; z_lut[237] = 8'd255; z_lut[238] = 8'd255; z_lut[239] = 8'd255;
	z_lut[240] = 8'd255; z_lut[241] = 8'd255; z_lut[242] = 8'd255; z_lut[243] = 8'd255; z_lut[244] = 8'd255;
	z_lut[245] = 8'd255; z_lut[246] = 8'd255; z_lut[247] = 8'd255; z_lut[248] = 8'd255; z_lut[249] = 8'd255;
	z_lut[250] = 8'd255; z_lut[251] = 8'd255; z_lut[252] = 8'd255; z_lut[253] = 8'd255; z_lut[254] = 8'd255;
	z_lut[255] = 8'd255;
end

wire raw_beam_on = (|avg_z_raw && (avg_rgb != 3'b000));
reg raw_beam_on_d = 0;
always @(posedge clk_12)
	raw_beam_on_d <= raw_beam_on;

wire [8:0] z_base = {1'b0, avg_z_raw};
wire [8:0] z_inertia_soft = (raw_beam_on && !raw_beam_on_d) ? (z_base + (z_base >> 1)) : z_base;
assign avg_z = (z_inertia_soft > 9'd232) ? 8'd232 : z_inertia_soft[7:0];

wire [16:0] linear1_mult = avg_z * 17'd311;
wire [7:0] linear1_final_z = (avg_z >= 8'd210) ? 8'd255 : linear1_mult[15:8];
wire [16:0] linear2_mult = avg_z * 17'd389;
wire [7:0] linear2_final_z = (avg_z >= 8'd168) ? 8'd255 : linear2_mult[15:8];

wire [7:0] final_z =
	(effective_tonemapping == 2'd0) ? linear1_final_z :
	(effective_tonemapping == 2'd1) ? linear2_final_z :
	(effective_tonemapping == 2'd2) ? z_lut[avg_z] :
	avg_z;

reg [11:0] fb_width = 12'd640;
reg [11:0] fb_height = 12'd480;
reg [11:0] x_center = 12'd320;
reg [11:0] y_center = 12'd237;
reg [12:0] auto_arx = 13'h1000 | 13'd640;
reg [12:0] auto_ary = 13'h1000 | 13'd480;

vfb_profile_resolver crt_profiles (
	.profile(crt_profile),
	.fb_height(fb_height),
	.off_dot_mode(status[30:28]),
	.off_tonemapping(osd_off_tonemapping),
	.off_phosphor_mode(status[56:55]),
	.custom1_settings(crt_custom1_settings),
	.custom2_settings(crt_custom2_settings),
	.dot_mode(effective_dot_mode),
	.tonemapping(effective_tonemapping),
	.bloom_width(effective_bloom_width),
	.bloom_curve(effective_bloom_curve),
	.halo_filter(effective_halo_filter),
	.halo_spread(effective_halo_spread),
	.phosphor_mode(effective_phosphor_mode),
	.color_space(effective_color_space),
	.color_channels(effective_color_channels),
	.slot_mask(effective_slot_mask),
	.full_bypass(effective_full_bypass)
);

reg [11:0] h_total_reg = 12'd992;
reg [11:0] v_total_reg = 12'd524;
reg [11:0] hs_start_reg = 12'd720;
reg [11:0] hs_end_reg = 12'd816;
reg [11:0] vs_start_reg = 12'd490;
reg [11:0] vs_end_reg = 12'd492;

reg is_1080p = 1'b0;
reg is_480p  = 1'b1;
reg is_240p  = 1'b0;

reg signed [11:0] x_scaled;
reg signed [11:0] y_scaled;
wire signed [21:0] avg_x_ext = $signed(avg_x);
wire signed [21:0] avg_y_ext = $signed(avg_y);

reg [11:0] stable_height_meta = 12'd480;
reg osd_120hz_meta;
reg osd_120hz_vid = 0;
reg fb_reset_vid = 1'b0;

reg [11:0] fb_width_next;
reg [11:0] fb_height_next;
reg [11:0] x_center_next;
reg [11:0] y_center_next;
reg [12:0] auto_arx_next;
reg [12:0] auto_ary_next;
reg [11:0] h_total_next;
reg [11:0] v_total_next;
reg [11:0] hs_start_next;
reg [11:0] hs_end_next;
reg [11:0] vs_start_next;
reg [11:0] vs_end_next;
reg is_1080p_next;
reg is_480p_next;
reg is_240p_next;

always @(*) begin
	is_1080p_next = (stable_height_meta >= 12'd1080 &&
	                 stable_height_meta < 12'd1400);
	is_480p_next  = (stable_height_meta >= 12'd480 &&
	                 stable_height_meta < 12'd720);
	is_240p_next  = (stable_height_meta != 12'd0 &&
	                 stable_height_meta < 12'd480);

	if (is_1080p_next) begin
		fb_width_next  = 12'd1472;
		fb_height_next = 12'd1080;
		x_center_next  = 12'd736;
		y_center_next  = 12'd525;
		auto_arx_next  = 13'h1000 | 13'd1472;
		auto_ary_next  = 13'h1000 | 13'd1080;

		h_total_next  = 12'd1851;
		v_total_next  = 12'd1124;
		hs_start_next = 12'd1600;
		hs_end_next   = 12'd1688;
		vs_start_next = 12'd1088;
		vs_end_next   = 12'd1093;

	end else if (is_240p_next) begin
		fb_width_next  = 12'd640;
		fb_height_next = 12'd240;
		x_center_next  = 12'd320;
		y_center_next  = 12'd119;
		auto_arx_next  = 13'h1000 | 13'd640;
		auto_ary_next  = 13'h1000 | 13'd240;

		h_total_next  = 12'd993;
		v_total_next  = 12'd261;
		hs_start_next = 12'd720;
		hs_end_next   = 12'd816;
		vs_start_next = 12'd245;
		vs_end_next   = 12'd248;

	end else if (is_480p_next) begin
		fb_width_next  = 12'd640;
		fb_height_next = 12'd480;
		x_center_next  = 12'd320;
		y_center_next  = 12'd237;
		auto_arx_next  = 13'h1000 | 13'd640;
		auto_ary_next  = 13'h1000 | 13'd480;

		h_total_next  = 12'd992;
		v_total_next  = 12'd524;
		hs_start_next = 12'd720;
		hs_end_next   = 12'd816;
		vs_start_next = 12'd490;
		vs_end_next   = 12'd492;

	end else begin
		fb_width_next  = 12'd980;
		fb_height_next = 12'd720;
		x_center_next  = 12'd490;
		y_center_next  = 12'd350;

		if (stable_height_meta >= 12'd1440) begin
			auto_arx_next = 13'h1000 | 13'd1960;
			auto_ary_next = 13'h1000 | 13'd1440;
		end else begin
			auto_arx_next = 13'h1000 | 13'd980;
			auto_ary_next = 13'h1000 | 13'd720;
		end

		h_total_next  = 12'd1388;
		v_total_next  = 12'd749;
		hs_start_next = 12'd1108;
		hs_end_next   = 12'd1196;
		vs_start_next = 12'd728;
		vs_end_next   = 12'd733;
	end
end

always @(posedge clk_125) begin
	stable_height_meta <= STABLE_HEIGHT;

	osd_120hz_meta <= STABLE_120HZ;
	osd_120hz_vid  <= osd_120hz_meta;
	fb_reset_vid   <= (stable_height_meta == 12'd0);

	if (stable_height_meta != 12'd0) begin
		fb_width     <= fb_width_next;
		fb_height    <= fb_height_next;
		x_center     <= x_center_next;
		y_center     <= y_center_next;
		auto_arx     <= auto_arx_next;
		auto_ary     <= auto_ary_next;
		h_total_reg  <= h_total_next;
		v_total_reg  <= v_total_next;
		hs_start_reg <= hs_start_next;
		hs_end_reg   <= hs_end_next;
		vs_start_reg <= vs_start_next;
		vs_end_reg   <= vs_end_next;
		is_1080p     <= is_1080p_next;
		is_480p      <= is_480p_next;
		is_240p      <= is_240p_next;
	end
end

always @(*) begin
	if (is_1080p) begin
		x_scaled = ((avg_x_ext << 5) + (avg_x_ext << 4) + avg_x_ext) >>> 9;
		y_scaled = ((avg_y_ext << 5) + (avg_y_ext << 2) + (avg_y_ext << 1) + avg_y_ext) >>> 9;
	end else if (is_240p) begin
		x_scaled = ((avg_x_ext << 5) + (avg_x_ext << 3) + (avg_x_ext << 1) + avg_x_ext) >>> 10;
		y_scaled = ((avg_y_ext << 5) + (avg_y_ext << 1) + avg_y_ext) >>> 11;
	end else if (is_480p) begin
		x_scaled = ((avg_x_ext << 5) + (avg_x_ext << 3) + (avg_x_ext << 1) + avg_x_ext) >>> 10;
		y_scaled = ((avg_y_ext << 5) + (avg_y_ext << 1) + avg_y_ext) >>> 10;
	end else begin
		x_scaled = ((avg_x_ext << 6) + avg_x_ext) >>> 10;
		y_scaled = ((avg_y_ext << 4) - (avg_y_ext << 1) - avg_y_ext) >>> 8;
	end
end

assign VIDEO_ARX = (ar == 2'd0) ? auto_arx :
                   (ar == 2'd1) ? 13'd0 :
                                  (13'h1000 | {1'b0, fb_width});
assign VIDEO_ARY = (ar == 2'd0) ? auto_ary :
                   (ar == 2'd1) ? 13'd0 :
                                  (13'h1000 | {1'b0, fb_height});

wire signed [11:0] new_x = x_center + x_scaled;
wire signed [11:0] new_y = y_center - 12'sd1 - y_scaled;
wire [10:0] final_x = new_x[10:0];
wire [10:0] final_y = new_y[10:0];
wire beam_in_bounds = (new_x[11:0] < ((is_1080p) ? 12'd1470 : fb_width)) && (new_y[11:0] < fb_height);

wire x_match = ($signed(avg_x) >= 14'sd7678 && $signed(avg_x) <= 14'sd7682) ||
               ($signed(avg_x) >= -14'sd7682 && $signed(avg_x) <= -14'sd7678);
wire y_match = ($signed(avg_y) >= -14'sd8191 && $signed(avg_y) <= -14'sd8190);
wire flash_trigger = x_match || y_match;
wire is_flash = flash_trigger && avg_rgb == 3'd7 && (avg_z_raw == 8'd223) && !avg_is_dot && !avg_halted;
wire hit_flash_active = is_flash;

wire [2:0] actual_dot_mode;
wire [2:0] auto_dot_mode = (fb_height >= 12'd1000) ? 3'd2 :
                           (fb_height >= 12'd700)  ? 3'd1 :
                                                       3'd0;
assign actual_dot_mode = (effective_dot_mode == 3'd0) ? auto_dot_mode :
                         (effective_dot_mode == 3'd1) ? 3'd0 :
                         (effective_dot_mode == 3'd2) ? 3'd1 :
                         (effective_dot_mode == 3'd3) ? 3'd2 :
                                                         3'd0;

wire rst_vid = reset | fb_reset_vid;

reg [10:0] vfb_x_q = 11'd0;
reg [10:0] vfb_y_q = 11'd0;
reg [7:0]  vfb_z_q = 8'd0;
reg [2:0]  vfb_rgb_q = 3'd0;
reg        vfb_is_dot_q = 1'b0;
reg        vfb_beam_on_q = 1'b0;
reg        vfb_frame_done_q = 1'b0;
reg [2:0]  vfb_dot_mode_q = 3'd0;

always @(posedge clk_12) begin
	if (rst_vid) begin
		vfb_x_q <= 11'd0;
		vfb_y_q <= 11'd0;
		vfb_z_q <= 8'd0;
		vfb_rgb_q <= 3'd0;
		vfb_is_dot_q <= 1'b0;
		vfb_beam_on_q <= 1'b0;
		vfb_frame_done_q <= 1'b0;
		vfb_dot_mode_q <= 3'd0;
	end else begin
		vfb_x_q <= final_x;
		vfb_y_q <= final_y;
		vfb_z_q <= final_z;
		vfb_rgb_q <= avg_rgb;
		vfb_is_dot_q <= avg_is_dot;
		vfb_beam_on_q <= raw_beam_on && beam_in_bounds && !hit_flash_active;
		vfb_frame_done_q <= avg_halted;
		vfb_dot_mode_q <= actual_dot_mode;
	end
end

reg [7:0] flash_param = 0;
reg [3:0] flash_sub = 0;
reg [16:0] flash_tick_cnt = 0;
wire flash_tick = (flash_tick_cnt == 17'd99999);

always @(posedge clk_12) begin
	if (reset) begin
		flash_param <= 0;
		flash_sub <= 0;
		flash_tick_cnt <= 0;
	end else begin
		flash_tick_cnt <= flash_tick ? 17'd0 : flash_tick_cnt + 17'd1;

		if (flash_tick) begin
			if (flash_param > 8'd2) flash_param <= flash_param - 8'd2;
			else flash_param <= 0;
		end else if (hit_flash_active) begin
			flash_sub <= flash_sub + 1'b1;
			if (flash_sub == 4'd12 && flash_param < 21) begin
				flash_param <= flash_param + 1'b1;
			end
		end
	end
end

reg [7:0] flash_param_s1 = 0, flash_param_s2 = 0;
reg [7:0] flash_param_stable = 0;
always @(posedge clk_125) begin
	flash_param_s1 <= flash_param;
	flash_param_s2 <= flash_param_s1;
	if (flash_param_s1 == flash_param_s2) begin
		flash_param_stable <= flash_param_s2;
	end
end

wire [10:0] pre_vblank_line = fb_height[10:0] + 11'd2;
reg [2:0] clk_div_cnt = 0;
reg ce_pix = 0;
reg [10:0] h_cnt = 0;
reg [10:0] v_cnt = 0;

always @(posedge clk_125) begin
	if (rst_vid)                   ce_pix <= 1'b0;
	else if (is_1080p)             ce_pix <= 1'b1;
	else if (osd_120hz_vid)        ce_pix <= 1'b1;
	else if (is_240p)              ce_pix <= (clk_div_cnt[2:0] == 0);
	else if (is_480p)              ce_pix <= (clk_div_cnt[1:0] == 0);
	else                           ce_pix <= clk_div_cnt[0];
end

wire h_end = (h_cnt >= h_total_reg[10:0]);
wire v_end = (v_cnt >= v_total_reg[10:0]);

always @(posedge clk_125) begin
	if (rst_vid) begin
		clk_div_cnt <= 3'd0;
		h_cnt       <= h_total_reg[10:0];
		v_cnt       <= pre_vblank_line;
	end else begin
		clk_div_cnt <= clk_div_cnt + 1'b1;
		if (ce_pix) begin
			if (h_end) begin
				h_cnt <= 0;
				if (v_end) v_cnt <= 0;
				else v_cnt <= v_cnt + 1'd1;
			end else begin
				h_cnt <= h_cnt + 1'd1;
			end
		end
	end
end

wire raw_hsync  = ~(h_cnt >= hs_start_reg[10:0] && h_cnt < hs_end_reg[10:0]);
wire raw_vsync  = ~(v_cnt >= vs_start_reg[10:0] && v_cnt < vs_end_reg[10:0]);
wire raw_hblank = (h_cnt >= fb_width[10:0]);
wire raw_vblank = (v_cnt >= fb_height[10:0]);

wire fifo_full_led;
wire arbiter_reset_busy;
vfb_top rasterizer (
	.reset(rst_vid),
	.video_timing_reset(rst_vid),
	.clk_sys(clk_125),
	.clk_12(clk_12),

	.osd_bloom_width(effective_bloom_width),
	.osd_bloom_curve(effective_bloom_curve),
	.osd_halo_filter(effective_halo_filter),
	.osd_phosphor_mode(effective_phosphor_mode),
	.osd_halo_spread(effective_halo_spread),
	.osd_color_space(effective_color_space),
	.osd_color_channels(effective_color_channels),
	.osd_slot_mask(effective_slot_mask),
	.osd_full_bypass(effective_full_bypass),
	.arbiter_reset_busy(arbiter_reset_busy),

	.X_VECTOR(vfb_x_q),
	.Y_VECTOR(vfb_y_q),
	.Z_VECTOR(vfb_z_q),
	.RGB(vfb_rgb_q),
	.IS_DOT(vfb_is_dot_q),
	.BEAM_ON(vfb_beam_on_q),

	.FRAME_DONE(vfb_frame_done_q),
	.BUFFER_MODE(status[40:39]),
	.DOT_MODE(vfb_dot_mode_q),
	.FIFO_FULL_LED(fifo_full_led),
	.FLASH_PARAM(flash_param_stable),
	.OSD_120HZ(STABLE_120HZ),

	.DDRAM_CLK(DDRAM_CLK),
	.DDRAM_BUSY(DDRAM_BUSY),
	.DDRAM_BURSTCNT(DDRAM_BURSTCNT),
	.DDRAM_ADDR(DDRAM_ADDR),
	.DDRAM_DOUT(DDRAM_DOUT),
	.DDRAM_DOUT_READY(DDRAM_DOUT_READY),
	.DDRAM_RD(DDRAM_RD),
	.DDRAM_DIN(DDRAM_DIN),
	.DDRAM_BE(DDRAM_BE),
	.DDRAM_WE(DDRAM_WE),

	.SDRAM_DQ_IN(SDRAM_DQ),
	.SDRAM_DQ_OUT(sdram_dq_out),
	.SDRAM_DQ_OE(sdram_dq_oe),
	.SDRAM_CKE(SDRAM_CKE),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_DQM(sdram_dqm),
	.SDRAM_A(SDRAM_A),
	.SDRAM_BA(SDRAM_BA),

	.RENDER_WIDTH(fb_width),
	.RENDER_HEIGHT(fb_height),

	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_HS(hs),
	.VGA_VS(vs),
	.VGA_HBLANK(hblank),
	.VGA_VBLANK(vblank),

	.h_cnt(h_cnt),
	.v_cnt(v_cnt),
	.ce_pix(ce_pix),
	.hsync(raw_hsync),
	.vsync(raw_vsync),
	.hblank(raw_hblank),
	.vblank(raw_vblank)
);

assign CE_PIXEL = ce_pix;
assign core_led = {fifo_full_led, 1'b0, 1'b0};


// Hiscore support

hiscore #(
	.HS_ADDRESSWIDTH(12),
	.CFG_ADDRESSWIDTH(3),
	.CFG_LENGTHWIDTH(2)
) hi (
	.*,
	.clk(clk_12),
	.paused(pause_cpu),
	.autosave(status[27]),
	.ram_address(hs_address),
	.data_from_ram(hs_data_out),
	.data_to_ram(hs_data_in),
	.data_from_hps(ioctl_dout),
	.data_to_hps(ioctl_din),
	.ram_write(hs_write_enable),
	.ram_intent_read(hs_access_read),
	.ram_intent_write(hs_access_write),
	.pause_cpu(hs_pause),
	.configured(hs_configured)
);

endmodule
