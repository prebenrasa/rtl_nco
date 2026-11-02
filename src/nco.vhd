library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.sine_lut_pkg.all;
use work.nco_pkg.all;

-- Reset: reset_n, async assertion, active low. Its release must be synchronous to clk (the parent's reset
-- synchroniser), so the NCO leaves reset on the same edge as the registers around it.
entity nco is
    generic (
        GC_PHASE_WIDTH  : positive := 24; -- N accumulator width
        GC_ADDR_WIDTH   : positive := 10; -- M LUT address = top M bits of the phase
        GC_SAMPLE_WIDTH : positive := 12  -- L output amplitude width
    );
    port (
        clk        : in std_logic;
        clk_en     : in std_logic;
        reset_n    : in std_logic; -- async assertion, active low, synchronous release
        step_size  : in unsigned(GC_PHASE_WIDTH - 1 downto 0);
        sine_valid : out std_logic;
        sine_data  : out signed(GC_SAMPLE_WIDTH - 1 downto 0);
        cos_data   : out signed(GC_SAMPLE_WIDTH - 1 downto 0)
    );
begin
    assert f_nco_config_ok(GC_PHASE_WIDTH, GC_ADDR_WIDTH, GC_SAMPLE_WIDTH) severity failure;
end entity nco;

architecture rtl of nco is
    constant C_LUT          : t_sine_lut                           := f_sine_lut(GC_ADDR_WIDTH, GC_SAMPLE_WIDTH);
    constant C_QUARTER_WAVE : unsigned(GC_ADDR_WIDTH - 1 downto 0) := f_nco_quarter_wave(GC_ADDR_WIDTH);

    signal s_accumulator : unsigned(GC_PHASE_WIDTH - 1 downto 0) := (others => '0');
    signal s_sine_rom    : signed(GC_SAMPLE_WIDTH - 1 downto 0); -- RAM read stage
    signal s_cos_rom     : signed(GC_SAMPLE_WIDTH - 1 downto 0); -- RAM read stage
    signal s_sine_data   : signed(GC_SAMPLE_WIDTH - 1 downto 0); -- RAM output  
    signal s_cos_data    : signed(GC_SAMPLE_WIDTH - 1 downto 0); -- RAM output  
    signal s_valid_dly   : std_logic_vector(C_NCO_LATENCY - 1 downto 0) := (others => '0');
begin
    -- Accumulator: increases by step-size each clock
    p_accumulator : process (clk, reset_n)
    begin
        if reset_n = '0' then
            s_accumulator <= (others => '0');
        elsif rising_edge(clk) then
            if clk_en = '1' then
                s_accumulator <= s_accumulator + step_size;
            end if;
        end if;
    end process;

    -- ROM: cuts accumulator output to only top address bits and reads from LUT 
    p_rom : process (clk)
        variable v_address : unsigned(GC_ADDR_WIDTH - 1 downto 0);
    begin
        if rising_edge(clk) then
            v_address := s_accumulator(GC_PHASE_WIDTH - 1 downto GC_PHASE_WIDTH - GC_ADDR_WIDTH);
            s_sine_rom  <= C_LUT(to_integer(v_address));
            s_cos_rom   <= C_LUT(to_integer(v_address + C_QUARTER_WAVE));
            s_sine_data <= s_sine_rom;
            s_cos_data  <= s_cos_rom;
        end if;
    end process;

    -- Valid: passes valid signal through pipeline to synchronise with sine wave output
    p_valid : process (clk, reset_n)
    begin
        if reset_n = '0' then
            s_valid_dly <= (others => '0');
        elsif rising_edge(clk) then
            s_valid_dly <= s_valid_dly(s_valid_dly'high - 1 downto 0) & clk_en;
        end if;
    end process;

    -- assign output
    sine_valid <= s_valid_dly(s_valid_dly'high);
    sine_data  <= s_sine_data;
    cos_data   <= s_cos_data;

end architecture;
