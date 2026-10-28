--------------------------------------------------------------------------------
-- UpDnCount : 8-bit synchronous up/down counter  (Practical 8, part 2)
--
--   Reset  : asynchronous, active high          -> Q = 0
--   Enable : synchronous, active high, priority 1 (0 = hold)
--   Load   : synchronous, active high, priority 2 (Q <= Data)
--   UpDn   : 1 = count up (Q+1), 0 = count down (Q-1)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UpDnCount is
    port (
        Clk    : in  std_logic;
        Reset  : in  std_logic;
        Enable : in  std_logic;
        Load   : in  std_logic;
        UpDn   : in  std_logic;
        Data   : in  std_logic_vector(7 downto 0);
        Q      : out std_logic_vector(7 downto 0)
    );
end entity UpDnCount;

architecture rtl of UpDnCount is
    signal count : unsigned(7 downto 0);
begin

    process (Clk, Reset)
    begin
        if Reset = '1' then
            count <= (others => '0');
        elsif rising_edge(Clk) then
            -- TODO: implement Enable / Load / UpDn behaviour from the truth table
            null;
        end if;
    end process;

    Q <= std_logic_vector(count);

end architecture rtl;
