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
