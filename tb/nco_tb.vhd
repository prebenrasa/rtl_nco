library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.nco_pkg.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_scoreboard;
use bitvis_vip_scoreboard.generic_sb_support_pkg.all;

entity nco_tb is
    generic (
        GC_PHASE_WIDTH  : positive := 8; -- N accumulator width
        GC_ADDR_WIDTH   : positive := 4; -- M LUT address = top M bits of the phase
        GC_SAMPLE_WIDTH : positive := 8  -- L output amplitude width
    );
end entity nco_tb;

architecture bhv of nco_tb is
    constant C_TCLK          : time                                  := 10 ns;
    constant C_AMPLITUDE     : integer                               := 2 ** (GC_SAMPLE_WIDTH - 1) - 1;
    constant C_UNIT_STEP     : positive                              := 2 ** (GC_PHASE_WIDTH - GC_ADDR_WIDTH); -- one LUT address per sample
    constant C_PERIOD        : positive                              := 2 ** GC_ADDR_WIDTH;                    -- samples per period at C_UNIT_STEP
    constant C_QUARTER_WAVE  : unsigned(GC_ADDR_WIDTH - 1 downto 0)  := f_nco_quarter_wave(GC_ADDR_WIDTH);
    constant C_QUARTER_PHASE : unsigned(GC_PHASE_WIDTH - 1 downto 0) := shift_left(resize(C_QUARTER_WAVE, GC_PHASE_WIDTH), GC_PHASE_WIDTH - GC_ADDR_WIDTH); -- C_QUARTER_WAVE in phase units

    -- entity signals
    signal clk                 : std_logic                             := '0';
    signal clk_en              : std_logic                             := '0';
    signal reset               : std_logic                             := '1';
    signal step_size           : unsigned(GC_PHASE_WIDTH - 1 downto 0) := (others => '0');
    signal sine_valid          : std_logic;
    signal sine_data, cos_data : signed(GC_SAMPLE_WIDTH - 1 downto 0);

    -- used to check peak sine wave values
    signal s_peak_max : integer := 0;
    signal s_peak_min : integer := 0;

    -- expected samples, written by p_model and consumed by p_checker
    shared variable sb_sin : bitvis_vip_scoreboard.int_sb_pkg.t_generic_sb;
    shared variable sb_cos : bitvis_vip_scoreboard.int_sb_pkg.t_generic_sb;
    signal watchdog_ctrl   : t_watchdog_ctrl := C_WATCHDOG_CTRL_DEFAULT; -- watchdog

    -- reference model: expected output for an accumulator value
    function f_expected(constant phase : unsigned) return integer is
        constant C_ADDRESS                 : natural := to_integer(phase(phase'high downto phase'high - GC_ADDR_WIDTH + 1));
    begin
        return integer(round(sin(MATH_2_PI * real(C_ADDRESS) / real(2 ** GC_ADDR_WIDTH)) * real(C_AMPLITUDE)));
    end function;
begin
    clock_generator(clk, C_TCLK);
    watchdog_timer(watchdog_ctrl, 50 us, FAILURE, "nco simulation hung");

    i_dut : entity work.nco
        generic map(
            GC_PHASE_WIDTH  => GC_PHASE_WIDTH,
            GC_ADDR_WIDTH   => GC_ADDR_WIDTH,
            GC_SAMPLE_WIDTH => GC_SAMPLE_WIDTH
        )
        port map(
            clk        => clk,
            clk_en     => clk_en,
            reset      => reset,
            step_size  => step_size,
            sine_valid => sine_valid,
            sine_data  => sine_data,
            cos_data   => cos_data
        );

    -- Model: mirrors the accumulator and adds one expected sample per clk_en
    p_model : process (clk)
        variable v_phase : unsigned(GC_PHASE_WIDTH - 1 downto 0) := (others => '0');
    begin
        if rising_edge(clk) then
            if reset = '1' then
                v_phase := (others => '0');
                if not sb_sin.is_empty(VOID) then
                    sb_sin.flush("samples in flight are discarded by reset");
                end if;
                if not sb_cos.is_empty(VOID) then
                    sb_cos.flush("samples in flight are discarded by reset");
                end if;
            elsif clk_en = '1' then
                sb_cos.add_expected(f_expected(v_phase + C_QUARTER_PHASE));
                sb_sin.add_expected(f_expected(v_phase));
                v_phase := v_phase + step_size;
            end if;
        end if;
    end process;

    -- Checker: compares every valid sample with the oldest expected one. 
    -- A valid with nothing expected is reported by the scoreboard as a TB_ERROR.
    p_checker : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '0' and sine_valid = '1' then
                sb_cos.check_received(to_integer(cos_data));
                sb_sin.check_received(to_integer(sine_data));
                s_peak_max <= maximum(s_peak_max, to_integer(sine_data));
                s_peak_min <= minimum(s_peak_min, to_integer(sine_data));
            end if;
        end if;
    end process;

    p_stimulus : process
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

        procedure drain is -- let the pipeline empty, then check nothing was lost
        begin
            step(8);
            check_value(sb_sin.is_empty(VOID), ERROR, "sine: every clk_en produced exactly one valid");
            check_value(sb_cos.is_empty(VOID), ERROR, "cos: every clk_en produced exactly one valid");
        end procedure;
    begin
        set_log_file_name("nco_tb_log.txt");
        set_alert_file_name("nco_tb_alert.txt");
        set_alert_stop_limit(ERROR, 0);    -- see every failure, not just the first
        set_alert_stop_limit(TB_ERROR, 0); -- the scoreboard reports a stray valid as TB_ERROR
        disable_log_msg(ID_POS_ACK);       -- don't log every passing check

        sb_sin.config(C_SB_CONFIG_DEFAULT);
        sb_sin.set_scope("NCO SIN SB");
        sb_sin.enable(VOID);
        sb_sin.disable_log_msg(ID_DATA); -- don't log every add/check
        sb_cos.config(C_SB_CONFIG_DEFAULT);
        sb_cos.set_scope("NCO COS SB");
        sb_cos.enable(VOID);
        sb_cos.disable_log_msg(ID_DATA); -- don't log every add/check

        log(ID_LOG_HDR, "Reset");
        step(2);
        reset <= '0';
        step;
        check_value(sine_valid, '0', ERROR, "sine_valid low after reset");

        log(ID_LOG_HDR, "one clk_en gives one valid, C_NCO_LATENCY clocks later");
        run_samples(1);
        for i in 1 to C_NCO_LATENCY - 1 loop
            check_value(sine_valid, '0', ERROR, "sine_valid low " & to_string(i) & " clocks after clk_en");
            step;
        end loop;
        check_value(sine_valid, '1', ERROR, "sine_valid high C_NCO_LATENCY clocks after clk_en");
        step;
        check_value(sine_valid, '0', ERROR, "sine_valid is a one clock pulse per clk_en");
        drain;

        log(ID_LOG_HDR, "One period, one LUT address per sample");
        set_step(C_UNIT_STEP);
        run_samples(C_PERIOD);
        drain;
        check_value(s_peak_max, C_AMPLITUDE, ERROR, "positive peak");
        check_value(s_peak_min, -C_AMPLITUDE, ERROR, "negative peak");

        log(ID_LOG_HDR, "Odd step size, several accumulator wraps");
        set_step(37);
        run_samples(3 * 2 ** GC_PHASE_WIDTH / 37);
        drain;

        log(ID_LOG_HDR, "clk_en as a slow sample strobe");
        set_step(C_UNIT_STEP);
        run_samples(C_PERIOD, en_period => 3);
        drain;

        log(ID_LOG_HDR, "Reset in the middle of a run");
        run_samples(5);
        reset <= '1';
        step;
        check_value(sine_valid, '0', ERROR, "sine_valid cleared by reset");
        reset <= '0';
        run_samples(C_PERIOD);
        drain;

        clk_en <= '0';
        sb_sin.report_counters(VOID); -- entered / matched / mismatched / deleted per scoreboard
        sb_cos.report_counters(VOID); -- entered / matched / mismatched / deleted per scoreboard
        report_alert_counters(FINAL); -- prints "Simulation SUCCESS" or "Simulation FAILED"
        std.env.stop;
        wait;
    end process;
end architecture;
