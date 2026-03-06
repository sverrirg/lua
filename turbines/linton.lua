-- ─────────────────────────────────────────────────────────────────
-- https://github.com/sverrirg/lua/tree/main/fuel
--
-- Turbine Status Widget for Jeti DC/DS transmitters
-- Compatible with DS-16 (devID 1) and DS-24II (devID 2)
-- on firmware 4.22+
--
-- Displays turbine status code as human-readable text.
-- Turbine name is configurable in the setup form and used
-- as the widget title.
--
-- Version: 1.8
-- Filename: linton.lua  (max 8 chars before extension)
-- Place in /Apps/ folder on SD card
-- ─────────────────────────────────────────────────────────────────

local statusSensor   = nil
local statusParam    = nil
local sensorsAvail   = {}
local currentCode    = nil

-- Detect device and emulator
-- devId: 1=DS-16, 2=DS-24II
local devId, emulator = system.getDeviceType()
local isDS16 = (devId == 1)

-- ── Status code table ─────────────────────────────────────────────
-- Linton turbine ECU status codes
local STATUS_CODES = {
    [-40] = "No data",
    [-39] = "Error Alarms",
    [-38] = "Acc7",
    [-37] = "Acc6",
    [-36] = "Acc5",
    [-35] = "Power limit",
    [-34] = "Restart Fail",
    [-33] = "Acc24",
    [-32] = "Dec23",
    [-31] = "Acc22",
    [-30] = "Idle21",
    [-29] = "Idle Time",
    [-28] = "CTH Time",
    [-27] = "Pump bubble",
    [-26] = "Temp5 Pro",
    [-25] = "Temp4 Pro",
    [-24] = "Temp3 Pro",
    [-23] = "Temp2 Pro",
    [-22] = "Temp1 Pro",
    [-21] = "HEGT3",
    [-20] = "HEGT2",
    [-19] = "HEGT1",
    [-18] = "Fuel Fail",
    [-17] = "RPM Low",
    [-16] = "RPM Err",
    [-15] = "Rc Lost Off",
    [-14] = "Pump Fail",
    [-13] = "Pump Current",
    [-12] = "Pump Open",
    [-11] = "CTH Fail",
    [-10] = "Motor Current",
    [-9]  = "Motor Open",
    [-8]  = "IGT Short",
    [-7]  = "IGT Open",
    [-6]  = "EGT Warn",
    [-5]  = "TT Trans",
    [-4]  = "TT Open",
    [-3]  = "Over Current",
    [-2]  = "Volt High",
    [-1]  = "Volt Low",
    [0]   = "Ready",
    [1]   = "Ready start",
    [2]   = "Temp high",
    [3]   = "Start..",
    [4]   = "Burner..",
    [5]   = "Success",
    [6]   = "Heating1..",
    [7]   = "Heating2..",
    [8]   = "Heating3..",
    [9]   = "Heating4..",
    [10]  = "Heating5..",
    [11]  = "Heating6..",
    [12]  = "Pump Acc..",
    [13]  = "CTH..",
    [14]  = "Acc5..",
    [15]  = "Acc6..",
    [16]  = "Acc7..",
    [17]  = "Acc8..",
    [18]  = "Idling..",
    [19]  = "Acc..",
    [20]  = "Dec..",
    [21]  = "Speed..",
    [22]  = "Max Speed..",
    [23]  = "RC Learn",
    [24]  = "RC Learning..",
    [25]  = "RC Successful",
    [26]  = "Restart",
    [27]  = "Restart..",
    [28]  = "Cooling..",
    [29]  = "Error Status",
}

-- ── Resolve a code to display text ───────────────────────────────
local function resolveCode(code)
    local text = STATUS_CODES[code]
    if text then
        return text
    else
        return "Code unknown"
    end
end

-- ── Mock data generator (emulator only) ──────────────────────────
local mockCodes  = { 0, 1, 3, 18, 19, 21, 28, -1, -14 }
local mockIndex  = 1
local mockTimer  = nil
local MOCK_STEP  = 3000  -- ms per code step

local function getMockValue()
    if mockTimer == nil then
        mockTimer = system.getTimeCounter()
    end
    local elapsed = system.getTimeCounter() - mockTimer
    mockIndex = (math.floor(elapsed / MOCK_STEP) % #mockCodes) + 1
    return mockCodes[mockIndex], true
end

-- ── Live sensor reader ────────────────────────────────────────────
local function getLiveValue()
    if statusSensor and statusParam then
        local sensorData = system.getSensorByID(statusSensor, statusParam)
        if sensorData and sensorData.valid then
            return math.floor(sensorData.value + 0.5), true  -- round to nearest integer
        end
    end
    return nil, false
end

local getValue = emulator ~= 0 and getMockValue or getLiveValue

-- ── Sensor changed callback ───────────────────────────────────────
local function sensorChanged(value)
    if value > 0 then
        statusSensor = sensorsAvail[value].id
        statusParam  = sensorsAvail[value].param
        system.pSave("turbSens", statusSensor)
        system.pSave("turbParm", statusParam)
    end
end

-- ── Config form ───────────────────────────────────────────────────
local function initForm(formID)
    sensorsAvail = {}
    local list     = {}
    local curIndex = -1
    local descr    = ""

    local available = system.getSensors()
    for _, sensor in ipairs(available) do
        if sensor.param == 0 then
            descr = sensor.label
        else
            list[#list + 1] = string.format("%s - %s [%s]", descr, sensor.label, sensor.unit)
            sensorsAvail[#sensorsAvail + 1] = sensor
            if sensor.id == statusSensor and sensor.param == statusParam then
                curIndex = #sensorsAvail
            end
        end
    end

    form.addLabel({ label = "Turbine Status Setup", font = FONT_BOLD })

    -- Sensor selector
    form.addRow(2)
    form.addLabel({ label = "Status sensor", width = 120 })
    form.addSelectbox(list, curIndex, true, sensorChanged, { width = 190 })

    -- Status code reference table
    form.addRow(1)
    form.addLabel({ label = "Status codes:", font = FONT_BOLD })
    for code, text in pairs(STATUS_CODES) do
        form.addRow(1)
        form.addLabel({ label = string.format("  %d = %s", code, text) })
    end

    if emulator ~= 0 then
        form.addRow(1)
        form.addLabel({ label = "** EMULATOR: cycling through all codes **" })
    end
end

local function keyPressed(key) end
local function printForm() end

-- ── Shared: resolve status text and colour ────────────────────────
local function getStatusDisplay()
    local displayText
    local r, g, b = 0, 0, 0
    if currentCode == nil then
        displayText = "Select sensor"
    else
        displayText = resolveCode(currentCode)
        if currentCode < 0 then
            r, g, b = 255, 0, 0        -- red for all error/fault codes
        elseif currentCode == 0 or currentCode == 1 then
            r, g, b = 0, 0, 0          -- black for ready states
        elseif currentCode >= 18 and currentCode <= 22 then
            r, g, b = 0, 180, 0        -- green for running/acc/dec/speed
        elseif currentCode == 28 then
            r, g, b = 0, 100, 255      -- blue for cooling
        elseif STATUS_CODES[currentCode] == nil then
            r, g, b = 255, 100, 0      -- amber for unknown codes
        end
    end
    return displayText, r, g, b
end

-- ── Telemetry widget paint ────────────────────────────────────────
local function printTelemetry(width, height)
    local statusFont = isDS16 and FONT_NORMAL or FONT_BIG
    local displayText, r, g, b = getStatusDisplay()
    -- Draw white background to match other widgets
    lcd.setColor(255, 255, 255)
    lcd.drawFilledRectangle(0, 0, width, height)
    lcd.setColor(r, g, b)
    lcd.drawText(5, 5, displayText, statusFont)
end

-- ── Init ─────────────────────────────────────────────────────────
local function init()
    statusSensor = system.pLoad("turbSens")
    statusParam  = system.pLoad("turbParm")

    system.registerForm(1, MENU_APPS, "Turbine Status", initForm, keyPressed, printForm)
    -- Size 3 = user can toggle Double in the Displayed Telemetry screen
    system.registerTelemetry(1, "Turbine status", 1, printTelemetry)
end

-- ── Loop ─────────────────────────────────────────────────────────
local function loop()
    local val, valid = getValue()
    if not valid then
        currentCode = nil
        return
    end
    currentCode = val
end

-- ── Return table ──────────────────────────────────────────────────
return {
    init    = init,
    loop    = loop,
    author  = "Custom",
    version = "1.8",
    name    = "Turbine",
}
