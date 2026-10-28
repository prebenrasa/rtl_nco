library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_scoreboard;
use bitvis_vip_scoreboard.generic_sb_support_pkg.all;

entity nco_tb is
end entity nco_tb;

architecture bhv of nco_tb is

    constant GC_PHASE_BITS : positive := 8; -- N accumulator width
    constant GC_ADDR_BITS  : positive := 4; -- M LUT address = top M bits of the phase
    constant GC_OUT_BITS   : positive := 8; -- L output amplitude width

    constant C_TCLK      : time     := 10 ns;
    constant C_AMPLITUDE : integer  := 2**(GC_OUT_BITS - 1) - 1;
    constant C_UNIT_STEP : positive := 2**(GC_PHASE_BITS - GC_ADDR_BITS); -- one LUT address per sample
    constant C_PERIOD    : positive := 2**GC_ADDR_BITS;                   -- samples per period at C_UNIT_STEP

    -- entity signals
    signal clk       : std_logic := '0';
    signal clk_en    : std_logic := '0';
    signal reset     : std_logic := '1';
    signal step_size : unsigned(GC_PHASE_BITS - 1 downto 0) := (others => '0');
    signal valid     : std_logic;
    signal sine_wave : signed(GC_OUT_BITS - 1 downto 0);

    -- used to check peak sine wave values
    signal peak_max  : integer := 0;
    signal peak_min  : integer := 0;

    -- expected samples, written by p_model and consumed by p_checker
    shared variable sb : bitvis_vip_scoreboard.int_sb_pkg.t_generic_sb;

    -- reference model: expected output for an accumulator value
    function f_expected(phase : unsigned) return integer is
        constant C_ADDRESS : natural := to_integer(phase(phase'high downto phase'high - GC_ADDR_BITS + 1));
    begin
        return integer(round(sin(MATH_2_PI * real(C_ADDRESS) / real(2**GC_ADDR_BITS)) * real(C_AMPLITUDE)));
    end function;
begin
    clock_generator(clk, C_TCLK);

    i_dut : entity work.nco
        generic map(
            GC_PHASE_BITS => GC_PHASE_BITS,
            GC_ADDR_BITS  => GC_ADDR_BITS,
            GC_OUT_BITS   => GC_OUT_BITS
        )
        port map(
            clk       => clk,
            clk_en    => clk_en,
            reset     => reset,
            step_size => step_size,
            valid     => valid,
            sine_wave => sine_wave
        );

    -- Model: mirrors the accumulator and adds one expected sample per clk_en
    p_model : process (clk)
        variable v_phase : unsigned(GC_PHASE_BITS - 1 downto 0) := (others => '0');
    begin
        if rising_edge(clk) then
            if reset = '1' then
                v_phase := (others => '0');
                if not sb.is_empty(VOID) then
                    sb.flush("samples in flight are discarded by reset");
                end if;
            elsif clk_en = '1' then
                sb.add_expected(f_expected(v_phase));
                v_phase := v_phase + step_size;
            end if;
        end if;
    end process;

    -- Checker: compares every valid sample with the oldest expected one. 
    -- A valid with nothing expected is reported by the scoreboard as a TB_ERROR.
    p_checker : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '0' and valid = '1' then
                sb.check_received(to_integer(sine_wave));
                peak_max <= maximum(peak_max, to_integer(sine_wave));
                peak_min <= minimum(peak_min, to_integer(sine_wave));
            end if;
        end if;
    end process;

    stimulus : process
        procedure step(constant n : positive := 1) is
        begin
            wait_num_rising_edge_plus_margin(clk, n, C_TCLK/4);
        end procedure;

        procedure set_step(constant step_word : natural) is
        begin
            step_size <= to_unsigned(step_word, step_size'length);
        end procedure;

        procedure run_samples(constant n : positive; constant en_period : positive := 1) is
        begin
            for i in 1 to n loop
                clk_en <= '1';
                step;
                clk_en <= '0';
                if en_period > 1 then
                    step(en_period - 1);
                end if;
            end loop;
        end procedure;

        procedure drain is   -- let the pipeline empty, then check nothing was lost
        begin
            step(8);
            check_value(sb.is_empty(VOID), ERROR, "every clk_en produced exactly one valid");
        end procedure;
    begin
        set_log_file_name("nco_tb_log.txt");
        set_alert_file_name("nco_tb_alert.txt");
        set_alert_stop_limit(ERROR, 0);    -- see every failure, not just the first
        set_alert_stop_limit(TB_ERROR, 0); -- the scoreboard reports a stray valid as TB_ERROR
        disable_log_msg(ID_POS_ACK);       -- don't log every passing check

        sb.config(C_SB_CONFIG_DEFAULT);
        sb.set_scope("NCO SB");
        sb.enable(VOID);
        sb.disable_log_msg(ID_DATA);       -- don't log every add/check

        log(ID_LOG_HDR, "Reset");
        step(2);
        reset <= '0';
        step;
        check_value(valid, '0', ERROR, "valid low after reset");

        log(ID_LOG_HDR, "One period, one LUT address per sample");
        set_step(C_UNIT_STEP);
        run_samples(C_PERIOD);
        drain;
        check_value(peak_max, C_AMPLITUDE, ERROR, "positive peak");
        check_value(peak_min, -C_AMPLITUDE, ERROR, "negative peak");

        log(ID_LOG_HDR, "Odd step size, several accumulator wraps");
        set_step(37);
        run_samples(3 * 2**GC_PHASE_BITS / 37);
        drain;

        log(ID_LOG_HDR, "clk_en as a slow sample strobe");
        set_step(C_UNIT_STEP);
        run_samples(C_PERIOD, en_period => 3);
        drain;

        log(ID_LOG_HDR, "Reset in the middle of a run");
        run_samples(5);
        reset <= '1';
        step;
        check_value(valid, '0', ERROR, "valid cleared by reset");
        reset <= '0';
        run_samples(C_PERIOD);
        drain;

        clk_en <= '0';
        sb.report_counters(VOID);     -- entered / matched / mismatched / deleted per scoreboard
        report_alert_counters(FINAL); -- prints "Simulation SUCCESS" or "Simulation FAILED"
        std.env.stop;
        wait;
    end process;
end architecture;
