--------------------------------------------------------------------------------
-- Testbench for UpDnCount  (Practical 8, part 3)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity updncount_tb is
end entity updncount_tb;

architecture sim of updncount_tb is
    constant T_clk  : time    := 20 ns;
    constant N_clks : natural := 100;        -- length of the simulation in clock periods

    signal clktb    : std_logic := '0';
    signal resettb  : std_logic := '1';
    signal enabletb : std_logic := '0';
    signal loadtb   : std_logic := '0';
    signal updntb   : std_logic := '1';
    signal datatb   : std_logic_vector(7 downto 0) := (others => '0');
    signal qtb      : std_logic_vector(7 downto 0);
begin

    -- Device under test
    dut : entity work.UpDnCount
        port map (
            Clk    => clktb,
            Reset  => resettb,
            Enable => enabletb,
            Load   => loadtb,
            UpDn   => updntb,
            Data   => datatb,
            Q      => qtb
        );

    -- Clock generator (stops after N_clks periods, so the simulation ends by itself)
    clk_gen : process
    begin
        while now <= N_clks * T_clk loop
            clktb <= '1';
            wait for T_clk / 2;
            clktb <= '0';
            wait for T_clk / 2;
        end loop;
        wait;
    end process;

    -- Stimulus
    stim : process
    begin
        resettb <= '1';
        wait for 2 * T_clk;
        resettb <= '0';

        -- TODO: drive Enable / Load / UpDn / Data to exercise every row of the
        --       truth table, and check qtb, e.g.
        --   assert qtb = x"05" report "load failed" severity error;

        wait;
    end process;

end architecture sim;
