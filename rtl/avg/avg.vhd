-- Black Widow AVG wrapper.
--
-- Uses the PROM-driven AVG core and 14-bit drawer. The active video path
-- consumes the drawer coordinates and dot tag directly.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.pkg_bwidow.all;

entity avg is
    Port ( cpu_data_in : out STD_LOGIC_VECTOR (7 downto 0);
           cpu_data_out : in STD_LOGIC_VECTOR (7 downto 0);
           cpu_addr : in STD_LOGIC_VECTOR (13 downto 0);
           cpu_cs_l : in STD_LOGIC;
           cpu_rw_l : in STD_LOGIC;
           vgrst : in STD_LOGIC;
           vggo : in STD_LOGIC;
           halted : out STD_LOGIC;
           xout14 : out STD_LOGIC_VECTOR (13 downto 0);
           yout14 : out STD_LOGIC_VECTOR (13 downto 0);
           zout : out STD_LOGIC_VECTOR (7 downto 0);
           rgbout : out STD_LOGIC_VECTOR (2 downto 0);
           is_dot_out : out STD_LOGIC;
           dbg : out STD_LOGIC_VECTOR(15 downto 0);
           clken: in STD_LOGIC;
           clk : in STD_LOGIC;
           dn_addr : in STD_LOGIC_VECTOR(15 downto 0);
           dn_data : in STD_LOGIC_VECTOR(7 downto 0);
           dn_wr : in STD_LOGIC
        );
end avg;

architecture Behavioral of avg is
    signal vecram_dout : STD_LOGIC_VECTOR(7 downto 0);
    signal vecram_din : STD_LOGIC_VECTOR(7 downto 0);
    signal vecrom_dout : STD_LOGIC_VECTOR(7 downto 0);
    signal vecrom_dout_q : STD_LOGIC_VECTOR(7 downto 0);
    signal vecram_cs_l : STD_LOGIC;
    signal vecram_rw_l : STD_LOGIC;

    signal memory_addr : STD_LOGIC_VECTOR(13 downto 0);
    signal memory_owner_avg : STD_LOGIC;
    signal returned_addr_d : STD_LOGIC_VECTOR(13 downto 0);
    signal returned_is_avg_d : STD_LOGIC;
    signal returned_addr : STD_LOGIC_VECTOR(13 downto 0);
    signal returned_is_avg : STD_LOGIC;
    signal avg_fetch_addr : STD_LOGIC_VECTOR(13 downto 0);
    signal avg_addr : STD_LOGIC_VECTOR(15 downto 0);
    signal avg_data : STD_LOGIC_VECTOR(7 downto 0);
    signal avg_data_valid : STD_LOGIC;

    signal avg_x14 : STD_LOGIC_VECTOR(13 downto 0);
    signal avg_y14 : STD_LOGIC_VECTOR(13 downto 0);
    signal avg_is_dot : STD_LOGIC;
    signal avg_prom_wr : STD_LOGIC;
begin
    myvecram: entity work.ram2k port map (
        addr     => memory_addr(10 downto 0),
        data_in  => vecram_din,
        data_out => vecram_dout,
        ena      => '1',
        cs_l     => vecram_cs_l,
        rw_l     => vecram_rw_l,
        clk      => clk
    );

    myvecrom: vecrom port map (
        addr    => memory_addr,
        data    => vecrom_dout,
        clk     => clk,
        dn_addr => dn_addr,
        dn_data => dn_data,
        dn_wr   => dn_wr
    );

    -- The MRA packs the 256-byte AVG PROM after program and vector ROMs.
    avg_prom_wr <= dn_wr when dn_addr(15 downto 8)=x"A0" else '0';

    -- Black Widow vector memory is CPU-visible as low byte, then high byte.
    -- The PROM-driven core requests bytes in hardware latch order, so swap A0
    -- only on AVG fetches. CPU reads/writes keep the original memory layout.
    avg_fetch_addr <= avg_addr(13 downto 1) & (not avg_addr(0));

    -- RAM and ROM responses share the same two-cycle tag pipeline. The extra
    -- ROM register matches the vector-RAM output latency.
    avg_data <= vecram_dout when returned_addr(13 downto 11)="000"
                              else vecrom_dout_q;
    avg_data_valid <= '1' when cpu_cs_l='1' and returned_is_avg='1'
                               and returned_addr=avg_fetch_addr else '0';

    prom_avg: entity work.avg_prom_core port map (
        clk => clk,
        clken => clken,
        cpu_data_in => open,
        cpu_data_out => cpu_data_out,
        cpu_addr => cpu_addr,
        avg_data_valid => avg_data_valid,
        cpu_rw_l => cpu_rw_l,
        vgrst => vgrst,
        vggo => vggo,
        halted => halted,
        xout => avg_x14,
        yout => avg_y14,
        zout => zout,
        rgbout => rgbout,
        is_dot => avg_is_dot,
        avg_addr_out => avg_addr,
        avg_data_in => avg_data,
        dn_addr => dn_addr(7 downto 0),
        dn_data => dn_data,
        dn_wr => avg_prom_wr
    );

    process (clk) begin
        if clk'event and clk='1' then
            if vgrst='1' then
                returned_addr_d <= (others => '0');
                returned_is_avg_d <= '0';
                returned_addr <= (others => '0');
                returned_is_avg <= '0';
            else
                returned_addr_d <= memory_addr;
                returned_is_avg_d <= memory_owner_avg;
                returned_addr <= returned_addr_d;
                returned_is_avg <= returned_is_avg_d;
            end if;

            vecrom_dout_q <= vecrom_dout;

            if cpu_cs_l='0' then
                vecram_rw_l <= cpu_rw_l;
                memory_addr <= cpu_addr;
                memory_owner_avg <= '0';
                vecram_din <= cpu_data_out;

                if cpu_addr(13 downto 11)="000" then
                    vecram_cs_l <= '0';
                    cpu_data_in <= vecram_dout;
                else
                    vecram_cs_l <= '1';
                    cpu_data_in <= vecrom_dout;
                end if;
            else
                vecram_rw_l <= '1';
                vecram_cs_l <= '0';
                memory_addr <= avg_fetch_addr;
                memory_owner_avg <= '1';
                cpu_data_in <= x"00";
            end if;
        end if;
    end process;

    xout14 <= avg_x14;
    yout14 <= avg_y14;
    is_dot_out <= avg_is_dot;

    dbg(15) <= clk;
    dbg(14) <= clken;
    dbg(13) <= avg_is_dot;
    dbg(12) <= cpu_cs_l;
    dbg(11) <= cpu_rw_l;
    dbg(10) <= vecram_cs_l;
    dbg(9) <= vecram_rw_l;
    dbg(8) <= avg_prom_wr;
    dbg(7 downto 4) <= memory_addr(3 downto 0);
    dbg(3 downto 0) <= vecram_din(3 downto 0);
end Behavioral;
