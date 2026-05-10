--========================================================
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
