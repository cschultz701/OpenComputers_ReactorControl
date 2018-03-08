




--FUNCTIONS TO WRITE

--Core Display Functions
--MonitorData (constantly call DisplayData)
--DisplayAutomationParameterMenu

--Status Functions
--getReactorStatus
--getReactorHeatValue
--getReactorHeatPercentage

--Automated Control Parameter Assignment
--setMaxReactorHeatPercentage
--setMaxBatteryPowerPercentage
--setMinBatteryPowerPercentage

--Automated Control Monitoring and Response Test
--checkForReactorHeatResponse	(Do we need to do something because of the current heat level)
--checkForBatteryPowerResponse	(Do we need to do something because of the current power level)

--Control Functions
--StartAutomation

--SIGNALS
--Redstone1 -> addr 606
--North - Reactor On/Off
--East - SCRAM status and reset command (high = ready, low = triggered) (pulse high reset)
--South - SCRAM activate
--West - Alarm activate

--Redstone2 -> addr 8d6
--East - Alarm status and reset command (high = ready/inactive, low = triggered) (pulse high reset)

local component = require("component")
local sides = require("sides")
local text = require("text")

local gpu = component.gpu
--Server Addresses
local red1 = component.proxy(component.get("606"))
local red2 = component.proxy(component.get("8d6"))
local battery = component.proxy(component.get("4bf"))	--temporary for MFE

--Single Player addresses
--local red1 = component.proxy(component.get("aef"))
--local red2 = component.proxy(component.get("047"))
--local battery = component.proxy(component.get("c4f"))	--temporary for MFE
--local reactor = component.get("xxx")

local MaxReactorHeatPercentage = 90
local MaxBatteryPowerPercentage = 99
local MinBatteryPowerPercentage = 5

local function WriteMenuItem(itemnumber, itemtext, totalpadding)
	gpu.setForeground(0x00FFFF)
	if itemnumber < 10 then
	io.write(itemnumber .. ":  ")
	else
	io.write(itemnumber .. ": ")
	end
	gpu.setForeground(0xFFFFFF)
	io.write(text.padRight(itemtext, totalpadding - 3))	-- -3 to account for the number and colon
end

--Returns TRUE if set (triggered), Returns False if not set (ready) (power on allowed)
local function getSCRAMStatus()
	return red1.getInput(sides.east) == 0
end

local function SCRAMset()
	red1.setOutput(sides.south, 15)
	os.sleep(1)
	red1.setOutput(sides.south, 0)	
end

local function SCRAMreset()
	red1.setOutput(sides.east, 15)
	os.sleep(1)
	red1.setOutput(sides.east, 0)
	if getSCRAMStatus() then 
	gpu.setForeground(0xFF00FF)
	print("SCRAM Reset Failure: Safety microcontroller overriding reset. Check reactor status.")
	gpu.setForeground(0xFFFFFF)
	end
end

--Returns TRUE if set (alarm on), Returns False if not set (alarm off)
local function getAlarmStatus()
	return red2.getInput(sides.east) == 0
end

local function Alarmset()
	red1.setOutput(sides.west, 15)
	os.sleep(1)
	red1.setOutput(sides.west, 0)
end

local function Alarmreset()
	red2.setOutput(sides.east, 15)
	os.sleep(1)
	red2.setOutput(sides.east, 0)
	if getAlarmStatus() then 
	print("Alarm Reset Failure: Safety microcontroller overriding reset. Check reactor status")
	end
end

local function getBatteryPowerValue()
	return battery.getStored()
end

local function getBatteryPowerPercentage()
	local capacity = battery.getCapacity()
	return getBatteryPowerValue() / capacity * 100
end

local function StartReactor()
	red1.setOutput(sides.north, 15)
end

local function StopReactor()
	red1.setOutput(sides.north, 0)
end

local function getReactorStatus()
	print("***REACTOR STATUS NOT IMPLEMENTED***")
	return false
end

local function PrintTestResult(TestText, ResultText, Pass)
	local padding = 50
	local resultpadding = 12
	gpu.setForeground(0xFFFFFF)
	io.write(text.padRight(TestText, padding))
	if Pass then
		gpu.setForeground(0x00FF00)
		io.write(text.padRight(ResultText, resultpadding))
		print("- Passed")
	else
		gpu.setForeground(0xFF0000)
		io.write(text.padRight(ResultText, resultpadding))
		print("- Failed")
	end
	gpu.setForeground(0xFFFFFF)
end

local function SCRAMtest()
	local initialreactorstatus = getReactorStatus()
	local result = "Passed"
	
	print("Initiating SCRAM Test")
	local testtext = "Initial Status................................... "
	if getSCRAMStatus() then
		PrintTestResult(testtext, "Triggered", false)
		gpu.setForeground(0xFF00FF)
		print("Test aborted. Ensure safe plant status and clear SCRAM.")
		print()
		return
	else
		PrintTestResult(testtext, "Ready", true)
	end
	
	--if necessary, power up reactor to ensure scram is working
	if not initialreactorstatus then
		--TEST REACTOR POWER UP
		testtext = "Reactor Startup.................................. "
		StartReactor()
		os.sleep(1)
		if getReactorStatus() then
			PrintTestResult(testtext, "Started", true)
		else
			PrintTestResult(testtext, "Stopped", false)
			gpu.setForeground(0xFF00FF)
			print("Unable to power reactor. Ability to stop reactor cannot be verified.")
			result = "Failed"
		end
	end
	
	--TEST SCRAM
	gpu.setForeground(0xFFFFFF)
	print("Triggering SCRAM")
	SCRAMset()
	os.sleep(1)
	testtext = "Checking SCRAM status after SCRAM trigger........ "
	if getSCRAMStatus() then
		PrintTestResult(testtext, "Triggered", true)
	else
		PrintTestResult(testtext, "Ready", false)
		gpu.setForeground(0xFF00FF)
		print("SCRAM not reading as triggered. Check SCRAM redstone circuitry.")
		result = "Failed"
	end
	
	--TEST REACTOR NOW STOPPED
	testtext = "Checking reactor status after SCRAM trigger...... "
	if getReactorStatus() then
		PrintTestResult(testtext, "Started", false)
		gpu.setForeground(0xFF00FF)
		print("SCRAM IS NOT STOPPING REACTOR! SAFETY MECHANISMS ARE NOT OPERATIONAL! FIX CIRCUITRY OR DISABLE REACTOR IMMEDIATELY!")
		result = "Failed"
		Alarmset()
	else
		PrintTestResult(testtext, "Stopped", true)
	end
	
	--TEST SCRAM Reset
	gpu.setForeground(0xFFFFFF)
	print("Resetting SCRAM")
	SCRAMreset()
	os.sleep(1)
	testtext = "Checking SCRAM status after SCRAM reset.......... "
	if getSCRAMStatus() then
		PrintTestResult(testtext, "Triggered", false)
		gpu.setForeground(0xFF00FF)
		print("SCRAM reset failed. Check SCRAM redstone circuitry.")
		result = "Failed"
	else
		PrintTestResult(testtext, "Ready", true)
	end
	
	--return reactor to original state
	if not initialreactorstatus then
		StopReactor()
	end
	gpu.setForeground(0x00FFFF)
	io.write("SCRAM Test Complete: ")
	if result == "Passed" then
		gpu.setForeground(0x00FF00)
	else
		gpu.setForeground(0xFF0000)
	end
	print(result)
	gpu.setForeground(0xFFFFFF)
	print()
end

local function Alarmtest()
	local result = "Passed"
	
	print("Initiating Alarm Test")
	local testtext = "Initial Status................................... "
	if getAlarmStatus() then
		PrintTestResult(testtext, "Active", false)
		gpu.setForeground(0xFF00FF)
		print("Test aborted. Ensure safe plant status and clear Alarm.")
		print()
		return
	else
		PrintTestResult(testtext, "Ready", true)
	end
	
	--TEST Alarm
	gpu.setForeground(0xFFFFFF)
	print("Triggering Alarm")
	Alarmset()
	os.sleep(1)
	testtext = "Checking Alarm status after Alarm trigger........ "
	if getAlarmStatus() then
		PrintTestResult(testtext, "Active", true)
	else
		PrintTestResult(testtext, "Ready", false)
		gpu.setForeground(0xFF00FF)
		print("Alarm not reading as triggered. Check Alarm redstone circuitry.")
		result = "Failed"
	end
	
	testtext = "Checking Alarm audibility........................ "
	local response = ""
	repeat
		gpu.setForeground(0x00FFFF)
		io.write("User Query: Is Alarm Audible? (Y/N) ")
		response = io.read()
	until response == "Y" or response == "y" or response == "N" or response == "n"
	if response == "Y" or response == "y" then
		PrintTestResult(testtext, "Audible", true)
	else
		PrintTestResult(testtext, "Inaudible", false)
		gpu.setForeground(0xFF00FF)
		print("Alarm should be easily audible in all reactor areas. Check Alarm redstone circuitry.")
		result = "Failed"
	end
	
	--RESET ALARM
	gpu.setForeground(0xFFFFFF)
	print("Resetting Alarm")
	Alarmreset()
	os.sleep(1)
	testtext = "Checking Alarm status after Alarm reset.......... "
	if getAlarmStatus() then
		PrintTestResult(testtext, "Active", false)
		gpu.setForeground(0xFF00FF)
		print("Alarm no reading as reset. Check Alarm redstone circuitry.")
		result = "Failed"
		Alarmset()
	else
		PrintTestResult(testtext, "Ready", true)
	end
	testtext = "Checking Alarm audibility........................ "
	local response = ""
	repeat
		io.write("User Query: Is Alarm Audible? (Y/N)")
		response = io.read()
	until response == "Y" or response == "y" or response == "N" or response == "n"
	if response == "Y" or response == "y" then
		PrintTestResult(testtext, "Audible", false)
		gpu.setForeground(0xFF00FF)
		print("Alarm should no longer be audible. Check Alarm redstone circuitry.")
		result = "Failed"
	else
		PrintTestResult(testtext, "Inaudible", true)
	end
	
	gpu.setForeground(0x00FFFF)
	io.write("Alarm Test Complete: ")
	if result == "Passed" then
		gpu.setForeground(0x00FF00)
	else
		gpu.setForeground(0xFF0000)
	end
	print(result)
	gpu.setForeground(0xFFFFFF)
	print()
end

local function DisplayMainMenu()
	--get the width of the screen
	local width, height = gpu.getResolution()
	
	--write menu title
	local padding = width / 2 + 15
	gpu.setForeground(0xFF0000)
	print(text.padLeft("REACTOR CONTROL PROGRAM MAIN MENU", padding))
	print()
	
	maxtextsize = 36
	padding = (width - (maxtextsize * 3)) / 4
	--write first line (3 entries)
	io.write(text.padLeft("", padding))
	WriteMenuItem(1, "Automated Control", maxtextsize+padding)
	WriteMenuItem(5, "Start Reactor", maxtextsize+padding)
	WriteMenuItem(9, "Full Control System Diagnostic", maxtextsize)
	print()
	
	io.write(text.padLeft("", padding))
	WriteMenuItem(2, "Set Automated Control Parameters", maxtextsize+padding)
	WriteMenuItem(6, "Stop Reactor", maxtextsize+padding)
	WriteMenuItem(10, "Manual Tests", maxtextsize)
	print()
	
	io.write(text.padLeft("", padding))
	WriteMenuItem(3, "Print Plant Status", maxtextsize+padding)
	WriteMenuItem(7, "Emergency SCRAM", maxtextsize+padding)
	WriteMenuItem(11, "Reset Alarm", maxtextsize)
	print()
	
	io.write(text.padLeft("", padding))
	WriteMenuItem(4, "Monitor Plant Status", maxtextsize+padding)
	WriteMenuItem(8, "Reset Emergency SCRAM", maxtextsize+padding)
	WriteMenuItem(12, "Exit Program", maxtextsize)
	print()
	
	print()
	io.write("Selection: ")
	local input = io.read()
	return input
end

local function DisplayAutomationParameterMenu()

end

local function DisplayData()
	os.execute('clear')
	--get the width of the screen
	local width, height = gpu.getResolution()
	
	--write title
	local padding = width / 2 + 7
	gpu.setForeground(0xFF00FF)
	print(text.padLeft("REACTOR STATUS", padding))
	
	local labelsize=26
	local valuesize=22
	local maxtextsize=48
	padding = ((width - maxtextsize * 2)) / 3
	--Write each status line
	io.write(text.padLeft("", padding))
	gpu.setForeground(0x00FFFF)
	io.write(text.padRight("Reactor Powered:", labelsize))
	gpu.setForeground(0x7F7F7F)
	io.write(text.padRight("Not Implemented", valuesize+padding))
	print()
	io.write(text.padLeft("", padding))
	gpu.setForeground(0x00FFFF)
	io.write(text.padRight("Reactor Heat Value:", labelsize))
	gpu.setForeground(0x7F7F7F)
	io.write(text.padRight("Not Implemented", valuesize+padding))
	gpu.setForeground(0x00FFFF)
	io.write(text.padRight("Reactor Heat Percentage:", labelsize))
	gpu.setForeground(0x7F7F7F)
	io.write(text.padRight("Not Implemented", valuesize))
	print()
	print()
	io.write(text.padLeft("", padding))
	gpu.setForeground(0x00FFFF)
	io.write(text.padRight("Battery Power Value:", labelsize))
	local batterycolor = 0xFFFFFF
	if getBatteryPowerPercentage() < 10 then
		batterycolor = 0xFF0000
	elseif getBatteryPowerPercentage() < 50 then
		batterycolor = 0xFFFF00
	else
		batterycolor = 0x00FF00
	end
	gpu.setForeground(batterycolor)
	io.write(text.padRight(tostring(getBatteryPowerValue()), valuesize+padding))
	gpu.setForeground(0x00FFFF)
	io.write(text.padRight("Battery Power Percentage:", labelsize))
	gpu.setForeground(batterycolor)
	io.write(text.padRight(tostring(getBatteryPowerPercentage()), valuesize))
	print()
	print()
	io.write(text.padLeft("", padding))
	gpu.setForeground(0x00FFFF)
	io.write(text.padRight("SCRAM Status:", labelsize))
	if getSCRAMStatus() then
		gpu.setForeground(0xFF0000)
	else
		gpu.setForeground(0x00FF00)
	end
	io.write(text.padRight(getSCRAMStatus() and "Triggered" or "Ready", valuesize+padding))
	gpu.setForeground(0x00FFFF)
	io.write(text.padRight("Alarm Status:", labelsize))
	if getAlarmStatus() then
		gpu.setForeground(0xFF0000)
	else
		gpu.setForeground(0x00FF00)
	end
	io.write(text.padRight(getAlarmStatus() and "Active" or "Inactive", valuesize+padding))
	print()
	print()
end

local function DisplayTestMenu()
	--get the width of the screen
	local width, height = gpu.getResolution()
	
	--write menu title
	local padding = width / 2 + 8
	gpu.setForeground(0xFF0000)
	print(text.padLeft("MANUAL TEST MENU", padding))
	print()
	
	maxtextsize = 32
	padding = (width - (maxtextsize * 2)) / 3
	gpu.setForeground(0xFF00FF)
	io.write(text.padLeft("", padding))
	io.write(text.padRight("Function Tests", maxtextsize+padding))
	io.write(text.padRight("Response Tests", maxtextsize))
	print()

	io.write(text.padLeft("", padding))
	WriteMenuItem(1, "SCRAM Functionality", maxtextsize+padding)
	WriteMenuItem(3, "Reactor High Heat Response", maxtextsize)
	print()
	io.write(text.padLeft("", padding))
	WriteMenuItem(2, "Alarm Functionality", maxtextsize+padding)
	WriteMenuItem(4, "Battery High Power Response", maxtextsize)
	print()
	io.write(text.padLeft("", padding+1))
	io.write(text.padRight("", maxtextsize+padding))
	WriteMenuItem(5, "Battery Low Power Response", maxtextsize)
	print()
	gpu.setForeground(0xFFFFFF)
	io.write("Selection: ")
	local input = io.read()
	return input
end

--MAIN ROUTINE
local response = 0
local subresponse = 0
repeat
response = DisplayMainMenu()
os.execute('clear')
if response == "1" then
print("Function Not Yet Implemented")
elseif response == "2" then
print("Function Not Yet Implemented")
elseif response == "3" then
	DisplayData()
elseif response == "4" then
print("Function Not Yet Implemented")
elseif response == "5" then
	StartReactor()
elseif response == "6" then
	StopReactor()
elseif response == "7" then
	SCRAMset()
elseif response == "8" then
	SCRAMreset()
elseif response == "9" then
print("Function Not Yet Implemented")
elseif response == "10" then
	subresponse = DisplayTestMenu()
	os.execute('clear')
	if subresponse == "1" then
		SCRAMtest()
	elseif subresponse == "2" then
		Alarmtest()
	end
elseif response == "11" then
	Alarmreset()
elseif response == "12" then
	--don't do anything - including say it's a bad entry, 'cause it's not
else
	print("Invalid Selection: " .. response)
end
until response == "12"
print("Program Terminating")