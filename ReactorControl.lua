local component = require("component")
local sides = require("sides")
local text = require("text")

local gpu = component.gpu
--Server Addresses
local red1 = component.proxy(component.get("a3c"))
local red2 = component.proxy(component.get("56e"))
local battery = component.proxy(component.get("95f"))	--temporary for MFE
local reactor = component.proxy(component.get("55d"))

--Signal Locations
--SCRAM activate
local SCRAMActComp = red1
local SCRAMActSide = sides.right
--SCRAM status and reset command (high = ready, low = triggered) (pulse high reset)
local SCRAMResComp = red2
local SCRAMResSide = sides.east
--Alarm activate
local ALARMActComp = red2
local ALARMActSide = sides.north
--Alarm status and reset command (high = ready/inactive, low = triggered) (pulse high reset)
local ALARMResComp = red2
local ALARMResSide = sides.west
--Reactor On/Off
local ReactorCommandComp = red2
local ReactorCommandSide = sides.south

--ITEMS BELOW HERE SHOULD NOT NEED TO BE CHANGED FROM REACTOR TO REACTOR

local MaxReactorHeatPercentage = 75
local MaxBatteryPowerPercentage = 99
local MinBatteryPowerPercentage = 5
local StopAutomaticControl = true

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
	return SCRAMResComp.getInput(SCRAMResSide) == 0
end

local function SCRAMset()
	SCRAMActComp.setOutput(SCRAMActSide, 15)
	os.sleep(1)
	SCRAMActComp.setOutput(SCRAMActSide, 0)	
end

local function SCRAMreset()
	SCRAMResComp.setOutput(SCRAMResSide, 15)
	os.sleep(1)
	SCRAMResComp.setOutput(SCRAMResSide, 0)
	if getSCRAMStatus() then 
	gpu.setForeground(0xFF00FF)
	print("SCRAM Reset Failure: Safety microcontroller overriding reset. Check reactor status.")
	gpu.setForeground(0xFFFFFF)
	end
end

--Returns TRUE if set (alarm on), Returns False if not set (alarm off)
local function getAlarmStatus()
	return ALARMResComp.getInput(ALARMResSide) == 0
end

local function Alarmset()
	ALARMActComp.setOutput(ALARMActSide, 15)
	os.sleep(1)
	ALARMActComp.setOutput(ALARMActSide, 0)
end

local function Alarmreset()
	ALARMResComp.setOutput(ALARMResSide, 15)
	os.sleep(1)
	ALARMResComp.setOutput(ALARMResSide, 0)
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
	ReactorCommandComp.setOutput(ReactorCommandSide, 15)
end

local function StopReactor()
	ReactorCommandComp.setOutput(ReactorCommandSide, 0)
end

local function getReactorStatus()
	return reactor.producesEnergy()
end

local function getPowerGeneration()
	return reactor.getReactorEUOutput()
end

local function getReactorHeatValue()
	return reactor.getHeat()
end

local function getReactorHeatPercentage()
	local capacity = reactor.getMaxHeat()
	return getReactorHeatValue() / capacity * 100
end

local function setMaxReactorHeatPercentage()
	local input
	repeat
	gpu.setForeground(0x00FFFF)
	io.write("Current Maximum Heat Percentage:")
	gpu.setForeground(0xFFFFFF)
	io.write(tostring(MaxReactorHeatPercentage))
	print()
	gpu.setForeground(0xFFFF00)
	io.write("Input New Maximum Heat Percentage:")
	input = tonumber(io.read())
	until not (input == nil or input > 100 or input < 0)
	MaxReactorHeatPercentage = input
end

local function setMaxBatteryPowerPercentage()
	local input
	repeat
	gpu.setForeground(0x00FFFF)
	io.write("Current Maximum Power Percentage:")
	gpu.setForeground(0xFFFFFF)
	io.write(tostring(MaxBatteryPowerPercentage))
	print()
	gpu.setForeground(0x00FFFF)
	io.write("Current Minimum Power Percentage:")
	gpu.setForeground(0xFFFFFF)
	io.write(tostring(MinBatteryPowerPercentage))
	print()
	gpu.setForeground(0xFFFF00)
	io.write("Input New Maximum Power Percentage:")
	input = tonumber(io.read())
	until not (input == nil or input > 100 or input < MinBatteryPowerPercentage)
	MaxBatteryPowerPercentage = input
end

local function setMinBatteryPowerPercentage()
	local input
	repeat
	gpu.setForeground(0x00FFFF)
	io.write("Current Maximum Power Percentage:")
	gpu.setForeground(0xFFFFFF)
	io.write(tostring(MaxBatteryPowerPercentage))
	print()
	gpu.setForeground(0x00FFFF)
	io.write("Current Minimum Power Percentage:")
	gpu.setForeground(0xFFFFFF)
	io.write(tostring(MinBatteryPowerPercentage))
	print()
	gpu.setForeground(0xFFFF00)
	io.write("Input New Minimum Power Percentage:")
	input = tonumber(io.read())
	until not (input == nil or input > MaxBatteryPowerPercentage or input < 0)
	MinBatteryPowerPercentage = input
end

--For automated control and test, do we need to do something because of the reactor heat?
--if so, run appropriate action and return true, else return false
--calling function must handle UI explanation of result
local function checkForReactorHeatResponse(CurrentHeatPercentage)
	if CurrentHeatPercentage >= MaxReactorHeatPercentage then
		SCRAMset()
		Alarmset()
		return true
	end
	return false
end

--For automated control and test, do we need to do something because of the battery power?
--if so, run appropriate action
--calling function must handle UI explanation of result
local function checkForBatteryPowerResponse(CurrentPowerPercentage)
	if CurrentPowerPercentage >= MaxBatteryPowerPercentage then
		StopReactor()
		return true
	elseif CurrentPowerPercentage <= MinBatteryPowerPercentage then
		StartReactor()
		return true
	end
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
	return result == "Passed"
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
		gpu.setForeground(0x00FFFF)
		io.write("User Query: Is Alarm Audible? (Y/N) ")
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
	return result == "Passed"
end

local function HeatHightest()
	local result = "Passed"
	local response
	
	print("Initiating High Heat Response Test")
	local testtext = "Initial SCRAM Status............................. "
	if getSCRAMStatus() then
		PrintTestResult(testtext, "Triggered", false)
		gpu.setForeground(0xFF00FF)
		print("Test aborted. Ensure safe plant status and clear SCRAM.")
		print()
		return
	else
		PrintTestResult(testtext, "Ready", true)
	end
	
	SCRAMreset()
	Alarmreset()
	gpu.setForeground(0xFFFFFF)
	print("Testing 0 Heat Response")
	response = checkForReactorHeatResponse(0)
	testtext = "Checking 0 Heat Response result.................. "
	if response then
		PrintTestResult(testtext, "Triggered", false)
		result = "Failed"
	else
		PrintTestResult(testtext, "No Response", true)
	end
	os.sleep(1)
	testtext = "Checking SCRAM status after heat response test... "
	if getSCRAMStatus() then
		PrintTestResult(testtext, "Triggered", false)
		result = "Failed"
	else
		PrintTestResult(testtext, "Ready", true)
	end

	SCRAMreset()
	Alarmreset()
	gpu.setForeground(0xFFFFFF)
	print("Testing Border Heat Response")
	response = checkForReactorHeatResponse(MaxReactorHeatPercentage-0.01)
	testtext = "Checking Border Heat Response result............. "
	if response then
		PrintTestResult(testtext, "Triggered", false)
		result = "Failed"
	else
		PrintTestResult(testtext, "No Response", true)
	end
	os.sleep(1)
	testtext = "Checking SCRAM status after heat response test... "
	if getSCRAMStatus() then
		PrintTestResult(testtext, "Triggered", false)
		result = "Failed"
	else
		PrintTestResult(testtext, "Ready", true)
	end

	SCRAMreset()
	Alarmreset()
	gpu.setForeground(0xFFFFFF)
	print("Testing Limit Heat Response")
	response = checkForReactorHeatResponse(MaxReactorHeatPercentage)
	testtext = "Checking Limit Heat Response result.............. "
	if response then
		PrintTestResult(testtext, "Triggered", true)
	else
		PrintTestResult(testtext, "No Response", false)
		result = "Failed"
	end
	os.sleep(1)
	testtext = "Checking SCRAM status after heat response test... "
	if getSCRAMStatus() then
		PrintTestResult(testtext, "Triggered", true)
	else
		PrintTestResult(testtext, "Ready", false)
		result = "Failed"
	end

	gpu.setForeground(0xFFFFFF)
	SCRAMreset()
	Alarmreset()
	gpu.setForeground(0xFFFFFF)
	print("Testing 100% Heat Response")
	response = checkForReactorHeatResponse(100)
	testtext = "Checking 100% Heat Response result............... "
	if response then
		PrintTestResult(testtext, "Triggered", true)
	else
		PrintTestResult(testtext, "No Response", false)
		result = "Failed"
	end
	os.sleep(1)
	testtext = "Checking SCRAM status after heat response test... "
	if getSCRAMStatus() then
		PrintTestResult(testtext, "Triggered", true)
	else
		PrintTestResult(testtext, "Ready", false)
		result = "Failed"
	end

	SCRAMreset()
	Alarmreset()
	gpu.setForeground(0x00FFFF)
	io.write("High Heat Response Test Complete: ")
	if result == "Passed" then
		gpu.setForeground(0x00FF00)
	else
		gpu.setForeground(0xFF0000)
	end
	print(result)
	gpu.setForeground(0xFFFFFF)
	print()
	return result == "Passed"
end

local function Powertest()
	local initialreactorstatus = getReactorStatus()
	local result = "Passed"
	local response
	
	print("Initiating High/Low Power Response Test")
	local testtext = "Initial SCRAM Status............................. "
	if getSCRAMStatus() then
		PrintTestResult(testtext, "Triggered", false)
		gpu.setForeground(0xFF00FF)
		print("Test aborted. Ensure safe plant status and clear SCRAM.")
		print()
		return
	else
		PrintTestResult(testtext, "Ready", true)
	end
	
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
			print("Unable to power reactor.")
			result = "Failed"
		end
	end

	gpu.setForeground(0xFFFFFF)
	print("Testing 0 Power Response")
	response = checkForBatteryPowerResponse(0)
	testtext = "Checking 0 Power Response result................. "
	if response then
		PrintTestResult(testtext, "Triggered", true)
	else
		PrintTestResult(testtext, "No Response", false)
		result = "Failed"
	end
	os.sleep(1)
	testtext = "Checking start status after power response test.. "
	if getReactorStatus() then
		PrintTestResult(testtext, "Started", true)
	else
		PrintTestResult(testtext, "Stopped", false)
		result = "Failed"
	end

	StopReactor()
	gpu.setForeground(0xFFFFFF)
	print("Testing Low Limit Heat Response")
	response = checkForBatteryPowerResponse(MinBatteryPowerPercentage)
	testtext = "Checking Low Limit Power Response result......... "
	if response then
		PrintTestResult(testtext, "Triggered", true)
	else
		PrintTestResult(testtext, "No Response", false)
		result = "Failed"
	end
	os.sleep(1)
	testtext = "Checking start status after power response test.. "
	if getReactorStatus() then
		PrintTestResult(testtext, "Started", true)
	else
		PrintTestResult(testtext, "Stopped", false)
		result = "Failed"
	end

	StopReactor()
	gpu.setForeground(0xFFFFFF)
	print("Testing Low Border Power Response")
	response = checkForBatteryPowerResponse(MinBatteryPowerPercentage+0.01)
	testtext = "Checking Low Border Power Response result........ "
	if response then
		PrintTestResult(testtext, "Triggered", false)
		result = "Failed"
	else
		PrintTestResult(testtext, "No Response", true)
	end
	os.sleep(1)
	testtext = "Checking start status after power response test.. "
	if getReactorStatus() then
		PrintTestResult(testtext, "Started", false)
		result = "Failed"
	else
		PrintTestResult(testtext, "Stopped", true)
	end

	StartReactor()
	gpu.setForeground(0xFFFFFF)
	print("Testing High Border Power Response")
	response = checkForBatteryPowerResponse(MaxBatteryPowerPercentage-0.01)
	testtext = "Checking High Border Power Response result....... "
	if response then
		PrintTestResult(testtext, "Triggered", false)
		result = "Failed"
	else
		PrintTestResult(testtext, "No Response", true)
	end
	os.sleep(1)
	testtext = "Checking start status after power response test.. "
	if getReactorStatus() then
		PrintTestResult(testtext, "Started", true)
	else
		PrintTestResult(testtext, "Stopped", false)
		result = "Failed"
	end

	StartReactor()
	gpu.setForeground(0xFFFFFF)
	print("Testing High Limit Heat Response")
	response = checkForBatteryPowerResponse(MaxBatteryPowerPercentage)
	testtext = "Checking High Limit Power Response result........ "
	if response then
		PrintTestResult(testtext, "Triggered", true)
	else
		PrintTestResult(testtext, "No Response", false)
		result = "Failed"
	end
	os.sleep(1)
	testtext = "Checking start status after power response test.. "
	if getReactorStatus() then
		PrintTestResult(testtext, "Started", false)
		result = "Failed"
	else
		PrintTestResult(testtext, "Stopped", true)
	end

	StartReactor()
	gpu.setForeground(0xFFFFFF)
	print("Testing 100% Power Response")
	response = checkForBatteryPowerResponse(100)
	testtext = "Checking 100% Power Response result.............. "
	if response then
		PrintTestResult(testtext, "Triggered", true)
	else
		PrintTestResult(testtext, "No Response", false)
		result = "Failed"
	end
	os.sleep(1)
	testtext = "Checking start status after power response test.. "
	if getReactorStatus() then
		PrintTestResult(testtext, "Started", false)
		result = "Failed"
	else
		PrintTestResult(testtext, "Stopped", true)
	end

	if not initialreactorstatus then
		StopReactor()
	else
		StartReactor()
	end

	gpu.setForeground(0x00FFFF)
	io.write("High/Low Power Response Test Complete: ")
	if result == "Passed" then
		gpu.setForeground(0x00FF00)
	else
		gpu.setForeground(0xFF0000)
	end
	print(result)
	gpu.setForeground(0xFFFFFF)
	print()
	return result == "Passed"
end

local function DisplayMainMenu()
	--get the width of the screen
	local width, height = gpu.getResolution()
	
	--write menu title
	local padding = width / 2 + 15
	gpu.setForeground(0xFF0000)
	print(text.padLeft("REACTOR CONTROL PROGRAM MAIN MENU", padding))
	print()
	
	if width > 80 then
		maxtextsize = 36
	else
		maxtextsize = 24
	end
	padding = (width - (maxtextsize * 3)) / 4
	--write first line (3 entries)
	io.write(text.padLeft("", padding))
	local autostate
	if StopAutomaticControl then
		autostate = "Start"
	else
		autostate = "Stop"
	end
	if width > 80 then
		WriteMenuItem(1, autostate .. " Automated Control", maxtextsize+padding)
	else
		WriteMenuItem(1, autostate .. " Auto Ctrl", maxtextsize+padding)
	end
	WriteMenuItem(4, "Print Plant Status", maxtextsize+padding)
	WriteMenuItem(7, "Emergency SCRAM", maxtextsize)
	print()
	
	io.write(text.padLeft("", padding))
	WriteMenuItem(2, "Start Reactor", maxtextsize+padding)
	if width > 80 then
		WriteMenuItem(5, "Set Automated Control Parameters", maxtextsize+padding)
	else
		WriteMenuItem(5, "Set Auto Ctrl Params", maxtextsize+padding)
	end
	if width > 80 then
		WriteMenuItem(8, "Reset Emergency SCRAM", maxtextsize)
	else
		WriteMenuItem(8, "Reset SCRAM", maxtextsize)
	end
	print()
	
	io.write(text.padLeft("", padding))
	WriteMenuItem(3, "Stop Reactor", maxtextsize+padding)
	WriteMenuItem(6, "Manual Tests", maxtextsize+padding)
	WriteMenuItem(9, "Reset Alarm", maxtextsize)
	print()
	
	io.write(text.padLeft("", padding+maxtextsize+padding+maxtextsize+padding+2))
	WriteMenuItem(10, "Exit Program", maxtextsize)
	print()
	
	print()
	io.write("Selection: ")
	local input = io.read()
	return input
end

local function DisplayAutomationParameterMenu()
	os.execute('clear')
	--get the width of the screen
	local width, height = gpu.getResolution()
	
	--write title
	local padding = width / 2 + 14
	gpu.setForeground(0xFF0000)
	print(text.padLeft("AUTOMATIC CONTROL PARAMETERS", padding))
	print()

	local labelsize=36
	local valuesize=12
	local maxtextsize=48
	padding = ((width - maxtextsize * 2)) / 3
	io.write(text.padLeft("", padding))
	WriteMenuItem(1, "Change Maximum Reactor Heat Percentage", maxtextsize+padding)
	gpu.setForeground(0x00FFFF)
	if width <= 80 then print() end
	io.write(text.padRight("Current Maximum Heat Percentage:", labelsize))
	gpu.setForeground(0xFFFFFF)
	io.write(text.padRight(tostring(MaxReactorHeatPercentage), valuesize))
	print()
	io.write(text.padLeft("", padding))
	WriteMenuItem(2, "Change Maximum Battery Power Percentage", maxtextsize+padding)
	gpu.setForeground(0x00FFFF)
	if width <= 80 then print() end
	io.write(text.padRight("Current Maximum Power Percentage:", labelsize))
	gpu.setForeground(0xFFFFFF)
	io.write(text.padRight(tostring(MaxBatteryPowerPercentage), valuesize))
	print()
	io.write(text.padLeft("", padding))
	WriteMenuItem(3, "Change Minimum Battery Power Percentage", maxtextsize+padding)
	gpu.setForeground(0x00FFFF)
	if width <= 80 then print() end
	io.write(text.padRight("Current Minimum Power Percentage:", labelsize))
	gpu.setForeground(0xFFFFFF)
	io.write(text.padRight(tostring(MinBatteryPowerPercentage), valuesize))
	print()
	io.write(text.padLeft("", padding))
	WriteMenuItem(4, "Return to Main Menu", maxtextsize+padding)
	print()
	
	print()
	io.write("Selection: ")
	local input = io.read()
	return input
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
	if getReactorStatus() then
		gpu.setForeground(0xA5FF00)
	else
		gpu.setForeground(0x7F7F7F)
	end
	io.write(text.padRight(getReactorStatus() and "On-line" or "Off-line", valuesize+padding))
	gpu.setForeground(0x00FFFF)
	io.write(text.padRight("Reactor Power Generation:", labelsize))
	if getReactorStatus() then
		gpu.setForeground(0x00FF00)
	else
		gpu.setForeground(0x7F7F7F)
	end
	io.write(text.padRight(tostring(getPowerGeneration()) .. " EU/t", valuesize))
	print()
	io.write(text.padLeft("", padding))
	gpu.setForeground(0x00FFFF)
	io.write(text.padRight("Reactor Heat Value:", labelsize))
	local reactorcolor = 0xFFFFFF
	if getReactorHeatPercentage() > 75 then
		reactorcolor = 0xFF0000
	elseif getBatteryPowerPercentage() > 50 then
		reactorcolor = 0xFFA500
	elseif getBatteryPowerPercentage() > 25 then
		reactorcolor = 0xFFFF00
	else
		reactorcolor = 0x00FF00
	end
	gpu.setForeground(reactorcolor)
	io.write(text.padRight(tostring(getReactorHeatValue()), valuesize+padding))
	gpu.setForeground(0x00FFFF)
	io.write(text.padRight("Reactor Heat Percentage:", labelsize))
	gpu.setForeground(reactorcolor)
	io.write(text.padRight(string.format("%.1f", getReactorHeatPercentage()) .. "%", valuesize))
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
	io.write(text.padRight(string.format("%.1f", getBatteryPowerPercentage()) .. "%", valuesize))
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
	io.write(text.padRight("Function Tests", maxtextsize+padding+1))
	io.write(text.padRight("Response Tests", maxtextsize))
	print()

	io.write(text.padLeft("", padding))
	WriteMenuItem(1, "SCRAM Functionality", maxtextsize+padding)
	WriteMenuItem(3, "Reactor High Heat Response", maxtextsize)
	print()
	io.write(text.padLeft("", padding))
	WriteMenuItem(2, "Alarm Functionality", maxtextsize+padding)
	WriteMenuItem(4, "Battery High/Low Power Response", maxtextsize)
	print()
	gpu.setForeground(0xFFFFFF)
	print("Unlisted number returns to Main Menu")
	io.write("Selection: ")
	local input = io.read()
	return input
end

local function AutomatedControl()
	local response = false
	repeat
		response = checkForReactorHeatResponse(getReactorHeatPercentage())
		checkForBatteryPowerResponse(getBatteryPowerPercentage())
		--get the width of the screen
		local width, height = gpu.getResolution()
		local padding = width / 2 + 13
		gpu.setForeground(0xFF0000)
		print(text.padLeft("AUTOMATIC CONTROL ENABLED", padding))
		DisplayData()
		if getReactorHeatPercentage() <= MaxReactorHeatPercentage * 0.5 then
			os.sleep(10)
		elseif getReactorHeatPercentage() <= MaxReactorHeatPercentage * 0.75 then
			os.sleep(3)
		else
			os.sleep(1)
		end
	until StopAutomaticControl or response
	if response then
		gpu.setForeground(0xFF0000)
		StopAutomaticControl = true
		print("EMERGENCY SCRAM TRIGGERED!")
	end
end

--MAIN ROUTINE
local response = 0
local subresponse = 0
local co
repeat
response = DisplayMainMenu()
os.execute('clear')
if response == "1" then
	if StopAutomaticControl then
		StopAutomaticControl = false
		print("Automated Control Starting")
		AutomatedControl()
	else
		print("Automatic Control Stopping")
		StopAutomaticControl = true
	end
elseif response == "2" then
	StartReactor()
elseif response == "3" then
	StopReactor()
elseif response == "4" then
	DisplayData()
elseif response == "5" then
	subresponse = DisplayAutomationParameterMenu()
	os.execute('clear')
	if subresponse == "1" then
		setMaxReactorHeatPercentage()
	elseif subresponse == "2" then
		setMaxBatteryPowerPercentage()
	elseif subresponse == "3" then
		setMinBatteryPowerPercentage()
	--4 is return to main menu doing nothing, so no extra code is necessary
	end
elseif response == "6" then
	subresponse = DisplayTestMenu()
	os.execute('clear')
	if subresponse == "1" then
		SCRAMtest()
	elseif subresponse == "2" then
		Alarmtest()
	elseif subresponse == "3" then
		HeatHightest()
	elseif subresponse == "4" then
		Powertest()
	end
elseif response == "7" then
	SCRAMset()
elseif response == "8" then
	SCRAMreset()
elseif response == "9" then
	Alarmreset()
elseif response == "10" then
	--don't do anything - including say it's a bad entry, 'cause it's not
else
	print("Invalid Selection: " .. response)
end
until response == "10"
print("Program Terminating")
