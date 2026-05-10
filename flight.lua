# Updated `flight.lua`

```lua
--========================================================
-- AIRSHIP FLIGHT COMPUTER
--========================================================
-- Features:
--
-- * Altitude hold autopilot
-- * Touchscreen monitor controls
-- * Peripheral setup wizard
-- * Flight logging
-- * Printer support
-- * Saveable flight statistics
--
--========================================================

----------------------------------------------------------
-- FILES
----------------------------------------------------------

local CONFIG_FILE = "flight_config"
local LOG_FILE = "flight_logs"

----------------------------------------------------------
-- CONFIG
----------------------------------------------------------

local config = {
    burnerSide = nil,
    altitudeSide = nil,
    speedSide = nil,
    monitorSide = nil,
    printerSide = nil
}

----------------------------------------------------------
-- SETTINGS
----------------------------------------------------------

local targetAltitude = 200
local altitudeHold = true

local MIN_GAS = 0
local MAX_GAS = 10000
local BASE_GAS = 5000

----------------------------------------------------------
-- STATS
----------------------------------------------------------

local stats = {
    maxAltitude = 0,
    maxSpeed = 0,
    totalRuntime = 0,
    startTime = os.clock()
}

----------------------------------------------------------
-- LOAD/SAVE CONFIG
----------------------------------------------------------

local function saveConfig()
    local file = fs.open(CONFIG_FILE, "w")
    file.write(textutils.serialize(config))
    file.close()
end

local function loadConfig()
    if fs.exists(CONFIG_FILE) then
        local file = fs.open(CONFIG_FILE, "r")
        local data = file.readAll()
        file.close()

        config = textutils.unserialize(data)
        return true
    end

    return false
end

----------------------------------------------------------
-- SETUP WIZARD
----------------------------------------------------------

local function askPeripheral(name, peripheralType)

    term.clear()
    term.setCursorPos(1,1)

    print("================================")
    print(" AIRSHIP FLIGHT COMPUTER SETUP ")
    print("================================")
    print("")

    print("Available peripherals:")
    print("")

    local names = peripheral.getNames()

    for _, side in ipairs(names) do
        print(side .. " - " .. peripheral.getType(side))
    end

    print("")
    print("Enter side for:")
    print(name)
    print("(" .. peripheralType .. ")")
    print("")

    write("> ")

    local input = read()

    return input
end

local function setupWizard()

    config.burnerSide = askPeripheral(
        "Burner Controller",
        "burner"
    )

    config.altitudeSide = askPeripheral(
        "Altitude Sensor",
        "altitude sensor"
    )

    config.speedSide = askPeripheral(
        "Speed Sensor",
        "speed sensor"
    )

    config.monitorSide = askPeripheral(
        "Monitor",
        "monitor"
    )

    config.printerSide = askPeripheral(
        "Printer",
        "printer"
    )

    saveConfig()

    term.clear()
    term.setCursorPos(1,1)

    print("Setup complete.")
    sleep(1)
end

----------------------------------------------------------
-- LOAD CONFIG OR RUN SETUP
----------------------------------------------------------

if not loadConfig() then
    setupWizard()
end

----------------------------------------------------------
-- PERIPHERALS
----------------------------------------------------------

local burner = peripheral.wrap(config.burnerSide)
local alt = peripheral.wrap(config.altitudeSide)
local speedSensor = peripheral.wrap(config.speedSide)
local monitor = peripheral.wrap(config.monitorSide)
local printer = peripheral.wrap(config.printerSide)

----------------------------------------------------------
-- MONITOR SETUP
----------------------------------------------------------

if monitor then
    monitor.setTextScale(0.5)
end

----------------------------------------------------------
-- UTILS
----------------------------------------------------------

local function clamp(value, min, max)

    if value < min then
        return min
    end

    if value > max then
        return max
    end

    return value
end

local function centerText(y, text)

    if not monitor then
        return
    end

    local w, h = monitor.getSize()

    local x = math.floor((w - #text) / 2) + 1

    monitor.setCursorPos(x, y)
    monitor.write(text)
end

----------------------------------------------------------
-- LOGGING
----------------------------------------------------------

local function writeLog(text)

    local file = fs.open(LOG_FILE, "a")

    file.writeLine(text)

    file.close()
end

local function saveFlightLog()

    local altitude = alt.getHeight()
    local speed = 0

    if speedSensor then
        speed = speedSensor.getVelocity()
    end

    local runtime = math.floor(os.clock() - stats.startTime)

    local log = "Time=" .. textutils.formatTime(os.time(), true) ..
        " Altitude=" .. math.floor(altitude) ..
        " MaxAltitude=" .. math.floor(stats.maxAltitude) ..
        " MaxSpeed=" .. string.format("%.2f", stats.maxSpeed) ..
        " Runtime=" .. runtime .. "s"

    writeLog(log)

    return log
end

----------------------------------------------------------
-- PRINTING
----------------------------------------------------------

local function printFlightLog()

    if not printer then
        return
    end

    local log = saveFlightLog()

    printer.newPage()

    printer.setPageTitle("Flight Log")

    printer.write("AIRSHIP FLIGHT LOG")
    printer.setCursorPos(1,3)

    printer.write(log)

    printer.setCursorPos(1,5)
    printer.write("Target Altitude: " .. targetAltitude)

    printer.setCursorPos(1,6)
    printer.write("Altitude Hold: " .. tostring(altitudeHold))

    printer.endPage()
end

----------------------------------------------------------
-- DRAW UI
----------------------------------------------------------

local function drawUI()

    if not monitor then
        return
    end

    local altitude = alt.getHeight()
    local vspeed = alt.getVerticalSpeed()

    local speed = 0

    if speedSensor then
        speed = speedSensor.getVelocity()
    end

    if altitude > stats.maxAltitude then
        stats.maxAltitude = altitude
    end

    if math.abs(speed) > stats.maxSpeed then
        stats.maxSpeed = math.abs(speed)
    end

    stats.totalRuntime = os.clock() - stats.startTime

    local gas = burner.getTargetAmount()

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)

    monitor.clear()

    centerText(1, "AIRSHIP FLIGHT COMPUTER")

    monitor.setCursorPos(2,3)
    monitor.write("Altitude: " .. math.floor(altitude))

    monitor.setCursorPos(2,4)
    monitor.write("Target:   " .. math.floor(targetAltitude))

    monitor.setCursorPos(2,5)
    monitor.write("VSpeed:   " .. string.format("%.2f", vspeed))

    monitor.setCursorPos(2,6)
    monitor.write("Speed:    " .. string.format("%.2f", speed))

    monitor.setCursorPos(2,7)
    monitor.write("Max Alt:  " .. math.floor(stats.maxAltitude))

    monitor.setCursorPos(2,8)
    monitor.write("Max Speed:" .. string.format("%.2f", stats.maxSpeed))

    monitor.setCursorPos(2,9)
    monitor.write("Runtime:  " .. math.floor(stats.totalRuntime) .. "s")

    monitor.setCursorPos(2,10)

    if altitudeHold then
        monitor.setTextColor(colors.lime)
        monitor.write("HOLD: ENABLED")
    else
        monitor.setTextColor(colors.red)
        monitor.write("HOLD: DISABLED")
    end

    monitor.setTextColor(colors.white)

    ------------------------------------------------------
    -- BUTTONS
    ------------------------------------------------------

    local w, h = monitor.getSize()

    monitor.setBackgroundColor(colors.green)
    monitor.setCursorPos(w - 8, 3)
    monitor.write("  +  ")

    monitor.setBackgroundColor(colors.orange)
    monitor.setCursorPos(w - 8, 5)
    monitor.write("  -  ")

    if altitudeHold then
        monitor.setBackgroundColor(colors.lime)
    else
        monitor.setBackgroundColor(colors.red)
    end

    monitor.setCursorPos(w - 8, 7)
    monitor.write(" HOLD ")

    monitor.setBackgroundColor(colors.blue)
    monitor.setCursorPos(w - 8, 9)
    monitor.write("PRINT")

    monitor.setBackgroundColor(colors.black)
end

----------------------------------------------------------
-- FLIGHT CONTROLLER
----------------------------------------------------------

local function flightLoop()

    while true do

        if altitudeHold then

            local altitude = alt.getHeight()
            local vspeed = alt.getVerticalSpeed()

            local error = targetAltitude - altitude

            local p = error * 15
            local d = vspeed * 40

            local correction = p - d

            local gasTarget = BASE_GAS + correction

            gasTarget = clamp(
                math.floor(gasTarget),
                MIN_GAS,
                MAX_GAS
            )

            burner.setTargetAmount(gasTarget)
        end

        sleep(0.1)
    end
end

----------------------------------------------------------
-- UI LOOP
----------------------------------------------------------

local function uiLoop()

    while true do
        drawUI()
        sleep(0.1)
    end
end

----------------------------------------------------------
-- TOUCH INPUT
----------------------------------------------------------

local function touchLoop()

    if not monitor then
        return
    end

    while true do

        local event, side, x, y =
            os.pullEvent("monitor_touch")

        local w, h = monitor.getSize()

        if x >= w - 8 and x <= w - 3 then

            if y == 3 then
                targetAltitude = targetAltitude + 10
            end

            if y == 5 then
                targetAltitude = targetAltitude - 10
            end

            if y == 7 then
                altitudeHold = not altitudeHold
            end

            if y == 9 then
                printFlightLog()
            end
        end
    end
end

----------------------------------------------------------
-- STARTUP
----------------------------------------------------------

term.clear()
term.setCursorPos(1,1)

print("================================")
print(" AIRSHIP FLIGHT COMPUTER ONLINE ")
print("================================")
print("")

print("Burner:   " .. tostring(config.burnerSide))
print("Altitude: " .. tostring(config.altitudeSide))
print("Speed:    " .. tostring(config.speedSide))
print("Monitor:  " .. tostring(config.monitorSide))
print("Printer:  " .. tostring(config.printerSide))

sleep(2)

----------------------------------------------------------
-- RUN
----------------------------------------------------------

parallel.waitForAny(
    flightLoop,
    uiLoop,
    touchLoop
)
```

## Suggested GitHub Layout

```text
flight.lua
README.md
install.lua
```

## Download Command

```lua
wget https://raw.githubusercontent.com/cutefurryprotogen-png/airship-controller/main/flight.lua flight
```

## Running

```lua
flight
```

## Resetting Peripheral Setup

Delete the config file:

```lua
delete flight_config
```

Then restart the program and it will ask again.
--========================================================
-- AIRSHIP FLIGHT COMPUTER
-- CC:Tweaked Airship Autopilot
--
-- Peripheral Layout:
-- LEFT  = Altitude Sensor
-- RIGHT = Burner Controller
-- BACK  = Speed Sensor (optional)
-- TOP   = Monitor
--
-- Monitor Controls:
-- [+] Raise target altitude
-- [-] Lower target altitude
-- [H] Toggle altitude hold
--
--========================================================

----------------------------------------------------------
-- PERIPHERALS
----------------------------------------------------------

local burner = peripheral.wrap("right")
local alt = peripheral.wrap("left")

local monitor = peripheral.find("monitor")

local speedSensor = peripheral.wrap("back")

----------------------------------------------------------
-- SETTINGS
----------------------------------------------------------

local targetAltitude = 200
local altitudeHold = true

local MIN_GAS = 0
local MAX_GAS = 10000

local BASE_GAS = 5000

----------------------------------------------------------
-- MONITOR SETUP
----------------------------------------------------------

if monitor then
    monitor.setTextScale(0.5)
end

----------------------------------------------------------
-- UTILS
----------------------------------------------------------

local function clamp(value, min, max)
    if value < min then
        return min
    end

    if value > max then
        return max
    end

    return value
end

local function centerText(y, text)
    if not monitor then return end

    local w, h = monitor.getSize()

    local x = math.floor((w - #text) / 2) + 1

    monitor.setCursorPos(x, y)
    monitor.write(text)
end

----------------------------------------------------------
-- DRAW UI
----------------------------------------------------------

local function drawUI()

    if not monitor then
        return
    end

    local altitude = alt.getHeight()
    local vspeed = alt.getVerticalSpeed()

    local speed = 0

    if speedSensor then
        speed = speedSensor.getVelocity()
    end

    local gas = burner.getTargetAmount()

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)

    monitor.clear()

    centerText(1, "AIRSHIP FLIGHT COMPUTER")

    monitor.setCursorPos(2,3)
    monitor.write("Altitude: " ..
        math.floor(altitude))

    monitor.setCursorPos(2,4)
    monitor.write("Target:   " ..
        math.floor(targetAltitude))

    monitor.setCursorPos(2,5)
    monitor.write("VSpeed:   " ..
        string.format("%.2f", vspeed))

    monitor.setCursorPos(2,6)
    monitor.write("Speed:    " ..
        string.format("%.2f", speed))

    monitor.setCursorPos(2,7)
    monitor.write("Gas:      " ..
        math.floor(gas))

    monitor.setCursorPos(2,8)

    if altitudeHold then
        monitor.setTextColor(colors.lime)
        monitor.write("HOLD: ENABLED")
    else
        monitor.setTextColor(colors.red)
        monitor.write("HOLD: DISABLED")
    end

    monitor.setTextColor(colors.white)

    ------------------------------------------------------
    -- BUTTONS
    ------------------------------------------------------

    local w, h = monitor.getSize()

    -- PLUS BUTTON
    monitor.setBackgroundColor(colors.green)
    monitor.setCursorPos(w - 8, 3)
    monitor.write("  +  ")

    -- MINUS BUTTON
    monitor.setBackgroundColor(colors.orange)
    monitor.setCursorPos(w - 8, 5)
    monitor.write("  -  ")

    -- HOLD BUTTON
    if altitudeHold then
        monitor.setBackgroundColor(colors.lime)
    else
        monitor.setBackgroundColor(colors.red)
    end

    monitor.setCursorPos(w - 8, 7)
    monitor.write(" HOLD ")

    monitor.setBackgroundColor(colors.black)
end

----------------------------------------------------------
-- FLIGHT CONTROLLER
----------------------------------------------------------

local function flightLoop()

    while true do

        if altitudeHold then

            local altitude = alt.getHeight()
            local vspeed = alt.getVerticalSpeed()

            --------------------------------------------------
            -- CONTROL SYSTEM
            --------------------------------------------------

            local error = targetAltitude - altitude

            -- Proportional gain
            local p = error * 15

            -- Vertical speed damping
            local d = vspeed * 40

            local correction = p - d

            local gasTarget = BASE_GAS + correction

            gasTarget = clamp(
                math.floor(gasTarget),
                MIN_GAS,
                MAX_GAS
            )

            burner.setTargetAmount(gasTarget)
        end

        sleep(0.1)
    end
end

----------------------------------------------------------
-- UI LOOP
----------------------------------------------------------

local function uiLoop()

    while true do
        drawUI()
        sleep(0.1)
    end
end

----------------------------------------------------------
-- TOUCH INPUT
----------------------------------------------------------

local function touchLoop()

    if not monitor then
        return
    end

    while true do

        local event, side, x, y =
            os.pullEvent("monitor_touch")

        local w, h = monitor.getSize()

        --------------------------------------------------
        -- PLUS BUTTON
        --------------------------------------------------

        if x >= w - 8 and x <= w - 3 then

            if y == 3 then
                targetAltitude =
                    targetAltitude + 10
            end

            if y == 5 then
                targetAltitude =
                    targetAltitude - 10
            end

            if y == 7 then
                altitudeHold =
                    not altitudeHold
            end
        end
    end
end

----------------------------------------------------------
-- STARTUP MESSAGE
----------------------------------------------------------

term.clear()
term.setCursorPos(1,1)

print("================================")
print(" AIRSHIP FLIGHT COMPUTER ONLINE ")
print("================================")

if monitor then
    print("Monitor connected.")
else
    print("WARNING: No monitor found.")
end

print("Target altitude: " ..
    targetAltitude)

sleep(1)

----------------------------------------------------------
-- RUN EVERYTHING
----------------------------------------------------------

parallel.waitForAny(
    flightLoop,
    uiLoop,
    touchLoop
)
