--=============================================================================--
-- Black Widow logic. Everything from here should be implementation-agnostic.
--===========================================================================--

-- Black Widow arcade hardware implemented in an FPGA
-- (C) 2012 Jeroen Domburg (jeroen AT spritesmods.com)
-- 
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

library ieee;
   use ieee.std_logic_1164.all;
   use IEEE.STD_LOGIC_ARITH.ALL;
   use IEEE.STD_LOGIC_UNSIGNED.ALL;
   use ieee.numeric_std.all;
	
use work.pkg_bwidow.all;

entity bwidow is
  port(
		reset_h   : in    std_logic;
		clk			: in    std_logic; -- 12.096 MHz
		pause_h   : in    std_logic;
		analog_sound_out    : out std_logic_vector(7 downto 0);
		analog_x14_out  : out std_logic_vector(13 downto 0);
		analog_y14_out  : out std_logic_vector(13 downto 0);
		analog_z_out    : out std_logic_vector(7 downto 0);
		rgb_out    : out std_logic_vector(2 downto 0);
		is_dot_out : out std_logic;
		avg_halted_out : out std_logic;
		--buttons				 : in std_logic_vector(14 downto 0);
		SW_B4				 : in std_logic_vector(7 downto 0);
		SW_D4				 : in std_logic_vector(7 downto 0);
		dn_addr           : in 	std_logic_vector(15 downto 0);
		dn_data         	 : in 	std_logic_vector(7 downto 0);
		dn_wr				 : in 	std_logic	;
		input_0        : in  std_logic_vector( 7 downto 0);
		--input_1        : in  std_logic_vector( 7 downto 0);
		--input_2        : in  std_logic_vector( 7 downto 0);
		input_3        : in  std_logic_vector( 7 downto 0);
		input_4        : in  std_logic_vector( 7 downto 0);

		dbg				 : out std_logic_vector(15 downto 0);
		
		-- HISCORE
		hs_address   : in  std_logic_vector(15 downto 0);
		hs_data_out  : out std_logic_vector(7 downto 0);
		hs_data_in   : in  std_logic_vector(7 downto 0);
		hs_write     : in  std_logic
		
	);
end bwidow;

architecture Behaviour of bwidow is
	signal c_addr			: std_logic_vector(23 downto 0);
	signal c_din			: std_logic_vector(7 downto 0);
	signal c_dout			: std_logic_vector(7 downto 0);
	signal c_rw_l			: std_logic;
	signal c_irq_l			: std_logic;
	signal avg_dout		: std_logic_vector(7 downto 0);
	signal pgmrom_dout	: std_logic_vector(7 downto 0);
	signal pgmram_dout	: std_logic_vector(7 downto 0);
	signal pgmrom_addr	: std_logic_vector(15 downto 0);
	signal pgmram_addr	: std_logic_vector(10 downto 0);
	signal avgmem_addr	: std_logic_vector(15 downto 0);
	signal earom_dout		: std_logic_vector(7 downto 0);
	signal pokeya_dout	: std_logic_vector(7 downto 0);
	signal pokeyb_dout	: std_logic_vector(7 downto 0);
	signal pokeya_cs_l	: std_logic;
	signal pokeyb_cs_l	: std_logic;
	signal pgmram_cs_l	: std_logic;
	signal avgmem_cs_l	: std_logic;
	signal earom_write_l	: std_logic;
	signal earom_con_l	: std_logic;
	signal pokeya_audio	: std_logic_vector(7 downto 0);
	signal pokeyb_audio	: std_logic_vector(7 downto 0);
	signal latchin_a		: std_logic_vector(7 downto 0);
	signal latchin_b		: std_logic_vector(7 downto 0);
	signal latchin_c		: std_logic_vector(7 downto 0);
	signal latchout		: std_logic_vector(7 downto 0) := (others => '0');
	signal cnt_3khz		: std_logic_vector(8 downto 0);
	signal ena_1_5M		: std_logic;
	signal reset_l			: std_logic;
	signal avg_rst			: std_logic;
	signal avg_go			: std_logic;
	signal avg_halted		: std_logic;
	signal avg_dbg			: std_logic_vector(15 downto 0);
	signal clkdiv			: std_logic_vector(2 downto 0);
	signal irqctr			: std_logic_vector(3 downto 0);
	signal intack_l		: std_logic;
	signal service_btnst	: std_logic;
begin
	pokeya: pokey port map (
		ADDR      => c_addr(3 downto 0),
		DIN       => c_dout,
		DOUT      => pokeya_dout,
		DOUT_OE_L => open,
		RW_L      => c_rw_l,
		CS        => '1',
		CS_L      => pokeya_cs_l,
		AUDIO_OUT => pokeya_audio,
		PIN       => SW_D4, -- DIP bank D4
		ENA       => ena_1_5M,
		CLK       => clk
	);

	pokeyb: pokey port map (
		ADDR      => c_addr(3 downto 0),
		DIN       => c_dout,
		DOUT      => pokeyb_dout,
		DOUT_OE_L => open,
		RW_L      => c_rw_l,
		CS        => '1',
		CS_L      => pokeyb_cs_l,
		AUDIO_OUT => pokeyb_audio,
		PIN       => SW_B4,
		ENA       => ena_1_5M,
		CLK       => clk
	);

	cpu: entity work.T65 port map (
		Mode    => "00",
		BCD_en  => '1',
		Res_n   => reset_l,
		Enable  => ena_1_5M,
		Clk     => clk,
		Rdy     => not pause_h,
		Abort_n => '1',
		IRQ_n   => c_irq_l,
		NMI_n   => '1',
		SO_n    => '1',
		R_W_n   => c_rw_l,
		Sync    => open,
		EF      => open,
		MF      => open,
		XF      => open,
		ML_n    => open,
		VP_n    => open,
		VDA     => open,
		VPA     => open,
		A       => c_addr,
		DI      => c_din,
		DO      => c_dout,
		Regs    => open,
		DEBUG   => open,
		NMI_ack => open
	);
	
	mypgmrom: pgmrom port map (
		addr		=> pgmrom_addr(14 downto 0),
		data		=> pgmrom_dout,
		clk		=> clk,
		dn_addr =>dn_addr,
		dn_data =>dn_data,
		dn_wr =>dn_wr
	);
	
	mypgmram: entity work.dpram2k port map (
		addr_a		=> pgmram_addr,
		data_in_a	=> c_dout,
		data_out_a	=> pgmram_dout,
		ena_a			=> '1',
		cs_l_a		=> pgmram_cs_l, -- Keep the RAM port clock-enabled.
		rw_l_a 		=> c_rw_l,
		clk_a			=> clk,
		
		addr_b		=> hs_address(10 downto 0),
		data_in_b	=> hs_data_in,
		data_out_b	=> hs_data_out,
		ena_b			=> '1',
		we_b			=> hs_write,
		clk_b			=> clk
	);
	
	myearom: earom port map (
		reset_l	=> reset_l,
		clk		=> clk,
		data_in	=> c_dout,
		data_out => earom_dout,
		addr		=> c_addr(5 downto 0),
		write_l	=> earom_write_l,
		con_l		=> earom_con_l
	);

	myavg: avg port map (
		clk => clk,
		clken => ena_1_5M,
		cpu_data_in => avg_dout,
		cpu_data_out => c_dout,
		cpu_addr => avgmem_addr(13 downto 0),
		cpu_cs_l => avgmem_cs_l,
		cpu_rw_l => c_rw_l,
		vgrst => reset_h or avg_rst,
		vggo => avg_go,
		halted => avg_halted,
		xout14 => analog_x14_out,
		yout14 => analog_y14_out,
		zout => analog_z_out,
		rgbout => rgb_out,
		is_dot_out => is_dot_out,
		dbg => avg_dbg,
		dn_addr =>dn_addr,
		dn_data =>dn_data,
		dn_wr =>dn_wr
		
	);

	-- Memory decoding: CPU read
	c_din <= latchin_a	when c_addr(15 downto 11)="10001" else
				latchin_b	when c_addr(15 downto 11)="10000" else
				latchin_c	when c_addr(15 downto 11)="01111" else
				earom_dout	when c_addr(15 downto 11)="01110" else
				pokeyb_dout	when c_addr(15 downto 11)="01101" else
				pokeya_dout	when c_addr(15 downto 11)="01100" else
				avg_dout		when c_addr(15 downto 12)="0101" else
				avg_dout		when c_addr(15 downto 12)="0100" else
				avg_dout		when c_addr(15 downto 12)="0011" else
				avg_dout		when c_addr(15 downto 11)="00101" else
				avg_dout		when c_addr(15 downto 11)="00100" else
				pgmram_dout	when c_addr(15 downto 11)="00000" else
				pgmrom_dout	when c_addr(15)='1' else
				"00000000";

	-- Memory-mapped selects and write strobes
	pokeya_cs_l <= '0' when c_addr(15 downto 11)="01100" else '1';
	pokeyb_cs_l <= '0' when c_addr(15 downto 11)="01101" else '1';
	pgmram_cs_l <= '0' when c_addr(15 downto 11)="00000" else '1';
	avgmem_cs_l <= '0' when c_addr(15 downto 12)="0101" else
						'0' when c_addr(15 downto 12)="0100" else
						'0' when c_addr(15 downto 12)="0011" else
						'0' when c_addr(15 downto 11)="00101" else
						'0' when c_addr(15 downto 11)="00100" else '1';
	earom_write_l <= '0' when c_addr(15 downto 6)="1000100101" else '1';
	earom_con_l <= '0' when c_addr(15 downto 6)="1000100100" else '1';
	intack_l <= '0' when c_addr(15 downto 6)="1000100011" else '1';
	avg_go <= '1' when c_addr(15 downto 6)="1000100001" else '0';
	avg_rst <= '1' when c_addr(15 downto 6)="1000100010" else '0';
	
	process(clk) begin
		if clk'EVENT and clk='1' then
			if c_addr(15 downto 12)="1000100000" and c_rw_l='0' then
				latchout <= c_dout;
			end if;
		end if;
	end process;

	dbg<=avg_dbg;
	
	analog_sound_out<=(("0"&pokeya_audio(7 downto 1))+("0"&pokeyb_audio(7 downto 1)));
	
	-- CPU-to-local address mapping
	pgmrom_addr<=c_addr(15 downto 0);
	avgmem_addr<= c_addr(15 downto 0)-"10000000000000"; -- $2000-based AVG window
	pgmram_addr(10)<=c_addr(10) xor latchout(2); -- Bank select
	pgmram_addr(9 downto 0)<=c_addr(9 downto 0);
	
	-- Reset and CPU input latches
	reset_l <= not reset_h;

	latchin_c(7)<=cnt_3khz(8);
	latchin_c(6)<=avg_halted;
	latchin_c(5 downto 0)<=input_0(5 downto 0);
	latchin_b(7 downto 0)<=input_3(7 downto 0);
	latchin_a(7 downto 0)<=input_4(7 downto 0);
		

	c_irq_l<=not(irqctr(3) and irqctr(2)); -- Active-low divider IRQ.

	-- Generate the 1.512 MHz CPU enable and service timer/IRQ counters.
	process(clk) begin
		if clk'EVENT and clk='1' then
			clkdiv<=clkdiv+"001";
			if (clkdiv="000") then
				ena_1_5M<='1';
				cnt_3khz<=cnt_3khz+"000000001";
				if cnt_3KHz="000000000" and intack_l='1' and c_irq_l='1' then
					irqctr<=irqctr+"0001";
				end if;
			else
				ena_1_5M<='0';
			end if;
			if intack_l='0' then
				irqctr<="0000";
			end if;
		end if;
	end process;

	  avg_halted_out <= avg_halted;

end Behaviour;

