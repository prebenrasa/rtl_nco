library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

use work.sine_lut_pkg.all;

entity sine_lut_pkg_tb is
    generic (
        GC_ADDR_WIDTH   : positive := 4; -- M LUT address = top M bits of the phase
        GC_SAMPLE_WIDTH : positive := 8  -- L output amplitude width
    );
end entity sine_lut_pkg_tb;

architecture bhv of sine_lut_pkg_tb is
    signal watchdog_ctrl : t_watchdog_ctrl := C_WATCHDOG_CTRL_DEFAULT; -- watchdog

    -- golden values for M = 4, L = 8: round(sin(2*pi*i/16) * 127) for the first quarter,
    -- written out by hand so they don't depend on the formula in the package
    constant C_GOLDEN_QUARTER : integer_vector := (0, 49, 90, 117, 127);
begin
    watchdog_timer(watchdog_ctrl, 50 us, FAILURE, "sine_lut_pkg simulation hung");

    -- The package has no clock or ports, so one sequential process calls the function
    -- and checks its result. Each check is a property of a sampled sine, not a copy
    -- of the formula, so a bug in the package can't be repeated in the testbench.
    p_stimulus : process
        procedure check_lut(constant addr_width : positive; constant sample_width : positive) is
            constant C_LUT       : t_sine_lut := f_sine_lut(addr_width, sample_width);
            constant C_LUT_DEPTH : positive   := 2 ** addr_width;
            constant C_AMPLITUDE : integer    := 2 ** (sample_width - 1) - 1;
            constant C_SIZE      : string     := " (M=" & to_string(addr_width) & ", L=" & to_string(sample_width) & ")";
        begin
            -- shape of the table
            check_value(C_LUT'length, C_LUT_DEPTH, ERROR, "number of entries" & C_SIZE);
            check_value(C_LUT'low, 0, ERROR, "first address" & C_SIZE);
            check_value(C_LUT(0)'length, sample_width, ERROR, "entry width" & C_SIZE);

            -- the four quadrant points: 0, +peak, 0, -peak
            check_value(to_integer(C_LUT(0)), 0, ERROR, "sin(0)" & C_SIZE);
            check_value(to_integer(C_LUT(C_LUT_DEPTH / 4)), C_AMPLITUDE, ERROR, "sin(pi/2)" & C_SIZE);
            check_value(to_integer(C_LUT(C_LUT_DEPTH / 2)), 0, ERROR, "sin(pi)" & C_SIZE);
            check_value(to_integer(C_LUT(3 * C_LUT_DEPTH / 4)), -C_AMPLITUDE, ERROR, "sin(3pi/2)" & C_SIZE);

            for i in 1 to C_LUT_DEPTH - 1 loop
                -- odd symmetry: sin(2pi - x) = -sin(x)
                check_value(to_integer(C_LUT(i)), -to_integer(C_LUT(C_LUT_DEPTH - i)), ERROR,
                "odd symmetry at " & to_string(i) & C_SIZE);
                -- never above the peak, so +1.0 did not wrap to a negative value
                check_value_in_range(to_integer(C_LUT(i)), -C_AMPLITUDE, C_AMPLITUDE, ERROR,
                "range at " & to_string(i) & C_SIZE);
            end loop;

            -- first quarter never falls (neighbours can be equal when M > L)
            for i in 1 to C_LUT_DEPTH / 4 loop
                check_value(to_integer(C_LUT(i)) >= to_integer(C_LUT(i - 1)), ERROR,
                "rising first quarter at " & to_string(i) & C_SIZE);
            end loop;
        end procedure;

        constant C_LUT : t_sine_lut := f_sine_lut(GC_ADDR_WIDTH, GC_SAMPLE_WIDTH);
    begin
        set_log_file_name("sine_lut_pkg_tb_log.txt");
        set_alert_file_name("sine_lut_pkg_tb_alert.txt");
        set_alert_stop_limit(ERROR, 0); -- see every failure, not just the first
        disable_log_msg(ID_POS_ACK);    -- don't log every passing check

        -- the golden values only hold for the default size
        if GC_ADDR_WIDTH = 4 and GC_SAMPLE_WIDTH = 8 then
            log(ID_LOG_HDR, "Golden values, M=" & to_string(GC_ADDR_WIDTH) & " L=" & to_string(GC_SAMPLE_WIDTH));
            for i in C_GOLDEN_QUARTER'range loop
                check_value(to_integer(C_LUT(i)), C_GOLDEN_QUARTER(i), ERROR, "golden entry " & to_string(i));
            end loop;
        else
            log(ID_LOG_HDR, "Golden values skipped: they are for M=4, L=8 only");
        end if;

        log(ID_LOG_HDR, "Properties for several table sizes");
        check_lut(addr_width => GC_ADDR_WIDTH, sample_width => GC_SAMPLE_WIDTH);
        check_lut(addr_width => 2, sample_width => 2);   -- smallest table with four quadrant points
        check_lut(addr_width => 6, sample_width => 4);   -- more entries than amplitude levels
        check_lut(addr_width => 10, sample_width => 12); -- the nco defaults

        report_alert_counters(FINAL); -- prints "Simulation SUCCESS" or "Simulation FAILED"
        std.env.stop;
        wait;
    end process;
end architecture;
