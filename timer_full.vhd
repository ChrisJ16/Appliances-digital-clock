library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

entity timerup is
	port(inDeb: in std_logic_vector(2 downto 0);
	outDeb: inout std_logic_vector(2 downto 0);
	CLK:in std_logic;
	anode_out: out std_logic_vector(3 downto 0);
	led_out: out std_logic_vector(6 downto 0);
	reset_led: out std_logic);
end entity;
-- inDeb - intrari pentru butoane
-- inDeb[0] - BTN minute
-- inDeb[1] - BTN secunde
-- inDeb[2] - BTN start/stop

architecture comportamentala of timerup is 
signal one_second_counter: std_logic_vector(26 downto 0) := b"000000000000000000000000000";
signal one_second_enable: std_logic := '0';
signal led_bcd: std_logic_vector(3 downto 0) := b"0000";
signal refresh_count: std_logic_vector(19 downto 0) := b"00000000000000000000";
signal active_LED: std_logic_vector(1 downto 0) := b"00";

signal m1: std_logic_vector(3 downto 0) := x"0";
signal m2: std_logic_vector(3 downto 0) := x"0";
signal s1: std_logic_vector(3 downto 0) := x"0";
signal s2: std_logic_vector(3 downto 0) := x"0";

signal RESET: std_logic := '0';
signal delay1,delay2,delay3: std_logic_vector(2 downto 0);
signal countMode: std_logic_vector (3 downto 0) := b"1000"; --starea initiala
signal downCount: std_logic := '0';
--countMode: reprezentare
-- b3 b2 b1 b0
-- interpretare
-- b3 = 1 daca nu se numara deloc(stop), 0 daca se numara(start)
-- b2 = 1 daca la urmatorul momentul dat se va numara descrescator, 0 daca se numara crescator
-- b1,b0 = 00 -> hold, 01 -> se numara, 11 -> hold pentru incementare minute/secunde; starea curenta in care ne aflam

signal slowClock: std_logic_vector(25 downto 0);
signal slowClockPulse: std_logic := '0';
signal justReset: std_logic := '0';
signal resetLim: std_logic := '0';

begin
    
    process(inDeb,CLK)
        begin
        outDeb <= b"000";
        if(slowClockPulse = '1') then
            delay1 <= inDeb;
            delay2 <= delay1;
            delay3 <= delay2;
        end if;
        outDeb <= delay1 and delay2 and delay3;
    end process;
    
    process(outDeb, CLK) 
    begin
    reset_led <= justReset;
        if(CLK'event and CLK = '1') then
            if(resetLim = '1') then
                RESET <= '1';
            else
                RESET <= '0';
            end if;
             
             if (justReset = '1') then
                countMode(2) <= '0';
                if(slowClockPulse = '1') then
                    justReset <= '0';
                end if;
            elsif(outDeb(0) = '1' and outDeb(1) = '1')then -- reset
                RESET <= '1';
                justReset <= '1';
                countMode <= b"1000";
            elsif(outDeb(2) = '1') and (outDeb(0) = '0' and outDeb(1) = '0') then --start/stop
                if(countMode(3) = '0') then
                    countMode(3) <= '1';
                    countMode(1 downto 0) <= b"00";
                else
                    countMode(3) <= '0';
                    countMode(1 downto 0) <= b"01";
                end if;
            elsif (outDeb(0) = '1' or outDeb(1) = '1') and (outDeb(2) = '0') then -- mod incrementare numere
                    countMode <= b"1111";
            end if;
         end if;
       
    end process;
   
    process(led_bcd )
	begin
		case led_bcd is
		when b"0000" => led_out <= b"0000001"; --0
		when b"0001" => led_out <= b"1001111"; --1
		when b"0010" => led_out <= b"0010010"; --2
		when b"0011" => led_out <= b"0000110"; --3
		when b"0100" => led_out <= b"1001100"; --4
		when b"0101" => led_out <= b"0100100"; --5
		when b"0110" => led_out <= b"0100000"; --6		   
		when b"0111" => led_out <= b"0001111"; --7
		when b"1000" => led_out <= b"0000000"; --8
		when b"1001" => led_out <= b"0000100"; --9
		when others => led_out <=  b"0000001"; --0
		end case;
	end process;
		
	process(RESET,CLK) 
	begin
		if(RESET = '1')then
			refresh_count <= b"00000000000000000000";
		else								   
			if(CLK'event) and (CLK = '0') then
				refresh_count <= refresh_count + 1;
			end if;
		end if;
	end process;
	   active_LED <= refresh_count(19 downto 18);
	   
	process(active_LED)
	begin
		case active_LED is
		when "00" => 
		anode_out <= b"0111";
		led_bcd <= m2; -- minute 2
		when "01" => 
		anode_out <= b"1011";
		led_bcd <= m1; -- minute 1
		when "10" => 
		anode_out <= b"1101";
		led_bcd <= s2; -- secunde 2
		when "11" => 
		anode_out <= b"1110";
		led_bcd <= s1;  --secunde 1
		when others => anode_out <= b"1111";
		led_bcd <= b"0000";
		end case;
	end process;
    
	process(RESET,CLK)
	begin
		if(RESET = '1')then
			one_second_counter <= (others => '0');
		elsif(CLK'event) and (CLK = '0') then
				if(one_second_counter >= x"5F5E0FF")then
					one_second_counter <= (others => '0');
				else
				    if(countMode(1 downto 0) /= b"00" and countMode(1 downto 0) /= b"11" and countMode(3) = '0') then
					   one_second_counter <= one_second_counter + 1;
					end if;
				end if;
			end if;
	end process; 
	   one_second_enable <= '1' when one_second_counter=x"5F5E0FF" else '0';
	
	process(RESET,CLK)
	begin
	   if(RESET = '1') then
	       slowClock  <= (others => '0');
	    elsif(CLK'event) and (CLK = '0') then
	       if(slowClock >= x"17D7840") then --  = 20_000_000
	           slowClock  <= (others => '0');
	       else
	           slowClock  <= slowClock  + 1;
	       end if;
	    end if;
	end process;
	   slowClockPulse <= '1' when slowClock = x"17D7840" else '0';
	
	process(RESET, CLK)
	
	begin
	
	if(countMode(2) = '1') then
        downCount <= '1';
    else
        downCount <= '0';
    end if;
	
	if(CLK'event) and (CLK = '0') then 
            if(RESET = '1')	then --reset
                s1 <= b"0000";
                s2 <= b"0000";
                m1 <= b"0000";
                m2 <= b"0000";
                resetLim <= '0';
            elsif (countMode(1 downto 0) = b"11") then -- mod incrementare minute/secunde  
                  downCount <= '1';  
                  if(outDeb(1) = '1') then -- secunde
                        if(slowClockPulse = '1') then
                            s1 <= s1 + 1;
                            if(s1 = b"1001") then 
                                  s2 <= s2 + 1;
                                  s1 <= b"0000";
                              end if;
                          
                              if(s2 = b"0101") and (s1 = b"1001") then 
                                  s2 <= b"0000";
                              end if;
                        end if;
                  end if;
                  if (outDeb(0) = '1') then --minute 
                        if(slowClockPulse = '1') then
                            m1 <= m1 +1;
                            if(m1 = b"1001") then
                                m2 <= m2 + 1;
                                m1 <= b"0000";
                            end if;
                            if(m2 = b"1001" and m1 = b"1001")then
                                m2 <= "0000";
                            end if;
                        end if;
                  end if;     
            else
                if(downCount = '0') then -- numarare normala
                          if (one_second_enable = '1') then 
                                s1 <= s1 + 1;
                            
                                  if(s1 = b"1001") then --secunde 1
                                      s2 <= s2 + 1;
                                      s1 <= b"0000";
                                  end if;
                              
                                  if(s2 = b"0101") and (s1 = b"1001") then --secunde 2
                                      m1 <= m1 + 1;
                                      s2 <= b"0000";
                                  end if;
                                  
                                  if(m1 = "1001") and (s2 = b"0101") and (s1 = b"1001") then  --minute 1
                                      m2 <= m2 + 1;
                                      m1 <= b"0000";
                                  end if;
                                  
                                  if(m2 = "1001") and (m1 = "1001") and (s2 = b"0101") and (s1 = b"1001")  then --minute 2
                                      m2 <= b"0000";
                                      resetLim <= '1';
                                  end if;
                          end if;
                    else -- numaratoare descrescatoare
                            if (one_second_enable = '1') then 
                              s1 <= s1 - 1;
                        
                              if(s1 = b"000") then --secunde 1
                                  s2 <= s2 - 1;
                                  s1 <= b"1001";
                              end if;
                          
                              if(s2 = b"0000") and (s1 = b"0000") then --secunde 2
                                  m1 <= m1 - 1;
                                  s2 <= b"0101";
                              end if;
                              
                              if(m1 = "0000") and (s2 = b"0000") and (s1 = b"0000") then  --minute 1
                                  m2 <= m2 - 1;
                                  m1 <= b"1001";
                              end if;
                              
                              if(m2 = "0000") and (m1 = "0000") and (s2 = b"0000") and (s1 = b"0000")  then --semnal sonor
                                  resetLim <= '1';
                              end if;
                      end if;
                end if;
            end if;
        end if;
	end process;
end architecture;