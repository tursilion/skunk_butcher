----------------------------------------------------------------------------------
-- Create Date:    10:39:26 07/24/2007 
-- Design Name: 	 'Butcher' CPLD
-- Module Name:    main - dataflow 
-- Project Name:   Jag/USB
-- Target Devices: XC9572XL VQ64 -10
-- Description:    Jag/USB main bus and peripheral controller
--
--			DON'T EVEN THINK ABOUT USING X IN = COMPARISONS!  SYNTHESIS EATS IT!
--
-- Revision: 
-- Revision 0.01 - File Created
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity main is
-- Jag bus interface
    Port ( jd : inout  STD_LOGIC_VECTOR (15 downto 0);
		     ja22 : in  STD_LOGIC;
           jrom1 : in  STD_LOGIC;
           jrw : in  STD_LOGIC;		-- High for reads (jag_v8 p.125)
			  jck : in  STD_LOGIC;
			  jgpio : in  STD_LOGIC;

-- Private bus interface
           pd : inout  STD_LOGIC_VECTOR (15 downto 0);
           preset : out  STD_LOGIC;
	 
-- EZ-HOST bus interface
           eza0 : out  STD_LOGIC;
           eza1 : out  STD_LOGIC;
           ezrd30 : out  STD_LOGIC;
           ezwr31 : out  STD_LOGIC;
           ezck : in  STD_LOGIC;

-- Flash bus interface
           flwe : out  STD_LOGIC;
           floe : out  STD_LOGIC);
			  
    attribute loc : string;	 
	 attribute loc of jd : signal is "46,51,57,61, 64,60,56,52, 48,50,59,63, 62,58,49,47";
	 attribute loc of ja22 : signal is "27";
	 attribute loc of jrw : signal is "36";
	 attribute loc of jrom1 : signal is "45";
	 attribute loc of jck : signal is "17";
	 attribute loc of pd : signal is "13,12,11,10, 9,8,5,4, 32,31,35,38, 34,39,33,40";
	 attribute loc of preset : signal is "43";
	 attribute loc of eza0 : signal is "15";
	 attribute loc of eza1 : signal is "18";
	 attribute loc of ezrd30 : signal is "20";
	 attribute loc of ezwr31 : signal is "19";
	 attribute loc of ezck : signal is "16";
	 attribute loc of flwe : signal is "44";
	 attribute loc of floe : signal is "42";
	 attribute loc of jgpio : signal is "23";
--	 attribute loc of : signal is "";

	 attribute slew : string;
	 attribute slew of main : entity is "slow";
	 
end main;

architecture dataflow of main is

	signal ireset0 : STD_LOGIC := '0';
	signal bstate : STD_LOGIC_VECTOR (2 downto 0) := "000";

begin
	-- Jag read from private bus
	jd <= pd
		when (jrw='1' and jrom1='0')
		else "ZZZZZZZZZZZZZZZZ";
	-- Jag write to private bus
	-- Never drive bus when writing internal state (C0-DF and jd(14)='1')
	pd <= jd
		when (jrw='0' and jrom1='0' and (ja22='0' or jd(14)='0'))
		else "ZZZZZZZZZZZZZZZZ";
	
	-- Flash mode is controlled by bstate -- read is 00X
	-- Jag read from Flash -- 80 - BF
	floe <= '0' when (jrw='1' and jrom1='0' and ja22='0' and bstate(2 downto 1)="00") else '1';
	
	-- Flash mode is controlled by bstate -- read/write is 000
	-- Jag write to Flash -- 80 - BF
	flwe <= '0' when (jrw='0' and jrom1='0' and ja22='0' and bstate="000") else '1';

	-- Jag read from EZ-HOST -- C0 - DF always works, 80-BF works if bstate(2)='1'
	-- bstate="110" forces both low -- this is our HPI boot state
	ezrd30 <= '0' when (bstate="110" or 
			(jrw='1' and jrom1='0' and 
				(ja22='1' or bstate(2)='1'))) else '1';

	-- Jag write to EZ-HOST -- C0 - DF works if jd(14)='0', 80-BF works if bstate(2)='1'
	-- bstate="110" forces both low -- this is our HPI boot state
	ezwr31 <= '0' when (bstate="110" or 
			(jrw='0' and jrom1='0' and 
				((ja22='1' and jd(14)='0') or (ja22='0' and bstate(2)='1'))))
			else '1';
	
	-- EZ-HOST addressing:
	--		00 on C0 read (HPI read)
	--		10 on C0 write (HPI address)
	--		Else follow bstate all other times
	eza0 <= '0' when (jrom1='0' and ja22='1') else bstate(0);
	eza1 <= (not jrw) when (jrom1='0' and ja22='1') else bstate(1);
	
	-- Raise reset line to allow momentary Flash access during boot
	preset <= '1' when (jrw='1' and jrom1='0' and ja22='0') else ireset0;

	-- Control reset with write of '7BAX' to C0-DF
	-- 7BAC enters reset, 7BAD exits it
	ireset0 <= jd(0) when (jrw='0' and jrom1='0' and ja22='1' and 
			jd(15 downto 1)="11110111010110") else ireset0;

	-- Control HPI access on write of '400X' to C0-DF
	--	4000 - Flash mode
	-- 4001 - Lock mode (all bus writes are disabled)
	--	4004 - HPI read/write (A1-0=00)
	-- 4005 - HPI mailbox read/write (A1-0=01)
	-- 4006 - HPI boot mode (A10=10) -- RD/WR are held low
	-- 4007 - HPI status read (A10=11)
	bstate <= jd(2 downto 0) when (jrw='0' and jrom1='0' and ja22='1' and 
			jd(15 downto 3)="0100000000000") else bstate;
end dataflow;