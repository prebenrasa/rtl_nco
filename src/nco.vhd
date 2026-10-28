library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.sine_lut_pkg.all;

entity nco is
    generic (
        GC_PHASE_BITS : positive := 24; -- N accumulator width
        GC_ADDR_BITS  : positive := 10; -- M LUT address = top M bits of the phase
        GC_OUT_BITS   : positive := 12  -- L output amplitude width
    );
    port (
        clk       : in std_logic;
        clk_en    : in std_logic;
        reset     : in std_logic;
        step_size : in unsigned(GC_PHASE_BITS - 1 downto 0);
        valid     : out std_logic;
        sine_wave : out signed(GC_OUT_BITS - 1 downto 0)
    );
    begin
        assert GC_ADDR_BITS <= GC_PHASE_BITS;
end entity nco;

architecture rtl of nco is
    constant C_LUT : t_sine_lut := f_sine_lut(GC_OUT_BITS, GC_ADDR_BITS);
    constant C_LATENCY : positive := 2;   -- clocks from clk_en to valid/sine_wave

    signal s_accumulator : unsigned(GC_PHASE_BITS - 1 downto 0) := (others => '0');
    signal s_rom         : signed(GC_OUT_BITS - 1 downto 0);     -- RAM read stage
    signal s_sine        : signed(GC_OUT_BITS - 1 downto 0);     -- RAM output  
    signal s_valid : std_logic_vector(C_LATENCY-1 downto 0) := (others => '0'); 
begin
    -- Accumulator: increases by step-size each clock
    p_accumulator : process (clk, reset)
    begin
        if reset = '1' then
            s_accumulator <= (others => '0');
        elsif rising_edge(clk) then
            if clk_en = '1' then
                s_accumulator <= s_accumulator + step_size;
            end if;
        end if;
    end process;

    -- ROM: cuts accumulator output to only top address bits and reads from sine LUT 
    p_rom : process (clk)
        variable v_address : unsigned(GC_ADDR_BITS - 1 downto 0);
    begin
        if rising_edge(clk) then
            v_address := s_accumulator(GC_PHASE_BITS - 1 downto GC_PHASE_BITS - GC_ADDR_BITS);
            s_rom <= C_LUT(to_integer(v_address));
            s_sine <= s_rom;
        end if;
    end process;
    
    -- Valid: passes valid signal through pipeline to synchronise with sine wave output
    p_valid : process (clk, reset)
    begin
        if reset = '1' then
            s_valid <= (others => '0');
        elsif rising_edge(clk) then
            s_valid <= s_valid(s_valid'high -1 downto 0) & clk_en;
        end if;
    end process;

    -- assign output
    valid <= s_valid(s_valid'high);
    sine_wave <= s_sine;

end architecture;
