--
-- Black Widow game wrapper derived from the Asteroids Deluxe model.
-- Copyright (c) MikeJ - May 2004
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
-- The latest version of this file can be found at: www.fpgaarcade.com
--
-- Email support@fpgaarcade.com
--
-- Revision list
--
-- version 001 initial release
--

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;

entity BWIDOW_TOP is
  port (
    SW_B4				 : in std_logic_vector(7 downto 0);
    SW_D4				 : in std_logic_vector(7 downto 0);
	 
    input_0           : in  std_logic_vector( 7 downto 0);
    input_3           : in  std_logic_vector( 7 downto 0);
    input_4           : in  std_logic_vector( 7 downto 0);

    AUDIO_OUT         : out   std_logic_vector(7 downto 0);

    dn_addr           : in std_logic_vector(15 downto 0);
    dn_data           : in std_logic_vector(7 downto 0);
    dn_wr					: in std_logic;
    
    AVG_X_OUT         : out std_logic_vector(13 downto 0);
    AVG_Y_OUT         : out std_logic_vector(13 downto 0);
    AVG_Z_OUT         : out std_logic_vector(7 downto 0);
    AVG_RGB_OUT       : out std_logic_vector(2 downto 0);
    AVG_IS_DOT_OUT    : out std_logic;
    AVG_HALTED_OUT    : out std_logic;

	RESET_L           : in    std_logic;

	pause_h				: in    std_logic;

    -- Game clocks
    clk_6	      :  in  std_logic;
    clk_12            :  in  std_logic;

	 -- Hiscore interface
	hs_address   : in  std_logic_vector(15 downto 0);
	hs_data_out  : out std_logic_vector(7 downto 0);
	hs_data_in   : in  std_logic_vector(7 downto 0);
	hs_write     : in  std_logic

    );
end;

architecture RTL of BWIDOW_TOP is
  signal delay_count          : std_logic_vector(7 downto 0) := (others => '0');
  signal reset_6_l            : std_logic;

  signal x_vector14           : std_logic_vector(13 downto 0);
  signal y_vector14           : std_logic_vector(13 downto 0);
  signal z_vector             : std_logic_vector(7 downto 0);
  signal avg_is_dot           : std_logic;
  signal avg_halted           : std_logic;

  signal rgb	:			STD_LOGIC_VECTOR(2 downto 0);

begin

  -- Hold the game core in reset for 256 clk_6 cycles.

  p_delay : process(RESET_L, clk_6)
  begin
    if (RESET_L = '0') then
      delay_count <= x"00";
      reset_6_l <= '0';
    elsif rising_edge(clk_6) then
      if (delay_count(7 downto 0) = (x"FF")) then
        delay_count <= (x"FF");
        reset_6_l <= '1';
      else
        delay_count <= delay_count + "1";
        reset_6_l <= '0';
      end if;
    end if;
  end process;

  mybwidow: entity work.bwidow port map (
		clk              => clk_12,
		reset_h          => not reset_6_l,
		pause_h 			  => pause_h,
		analog_sound_out => AUDIO_OUT,
		analog_x14_out   => x_vector14,
		analog_y14_out   => y_vector14,
		analog_z_out     => z_vector,
		rgb_out          => rgb,
		is_dot_out       => avg_is_dot,
		avg_halted_out   => avg_halted,
		dbg              => open,
		SW_B4            => SW_B4,
		SW_D4            => SW_D4,
		input_0          => input_0,
		input_3          => input_3,
		input_4          => input_4,
		dn_addr          =>dn_addr,
		dn_data          =>dn_data,
		dn_wr            =>dn_wr,
		hs_address       =>hs_address,
		hs_data_out      =>hs_data_out,
		hs_data_in       =>hs_data_in,
		hs_write         =>hs_write
	);

  AVG_X_OUT      <= x_vector14;
  AVG_Y_OUT      <= y_vector14;
  AVG_Z_OUT      <= z_vector;
  AVG_RGB_OUT    <= rgb;
  AVG_IS_DOT_OUT <= avg_is_dot;
  AVG_HALTED_OUT <= avg_halted;

end RTL;
