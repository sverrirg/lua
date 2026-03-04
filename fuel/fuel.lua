-- ─────────────────────────────────────────────────────────────────
-- https://github.com/sverrirg/lua/tree/main/fuel
--
-- Fuel Widget for Jeti DC/DS transmitters
-- Compatible with DS-16 and DS-24 on firmware 4.22+
-- Displays AND announces fuel level in ml, rounded to nearest 100ml
-- Announces each time the displayed value changes by 100ml
-- Version: 1.1
-- Filename: fuel.lua  (max 8 chars before extension)
-- Place in /Apps/ folder on SD card
-- ─────────────────────────────────────────────────────────────────

local fuelSensor       = nil
local fuelParam        = nil
local sensorsAvail     = {}
local currentFuel      = 0
local lastAnnounced    = nil

-- Detect device and emulator
-- devId: 1=DC/DS-16, 2=DC/DS-24
local devId, emulator = system.getDeviceType()
local isDS16 = (devId == 1)

-- ── Round to nearest 100 ─────────────────────────────────────────
local function roundTo100(value)
    return math.floor((value + 50) / 100) * 100
end

-- ── Mock data generator (emulator only) ──────────────────────────
local mockFuel      = 2000
local mockStart     = nil
local MOCK_DURATION = 15000

local function getMockValue()
    if mockStart == nil then
        mockStart = system.getTimeCounter()
    end
    local elapsed  = system.getTimeCounter() - mockStart
    local fraction = math.min(elapsed / MOCK_DURATION, 1.0)
    mockFuel = 2000 * (1.0 - fraction)
    return mockFuel, true
end

-- ── Live sensor reader ────────────────────────────────────────────
local function getLiveValue()
    if fuelSensor and fuelParam then
        local sensorData = system.getSensorByID(fuelSensor, fuelParam)
        if sensorData and sensorData.valid then
            return sensorData.value, true
        end
    end
    return 0, false
end

local getValue = emulator ~= 0 and getMockValue or getLiveValue

-- ── Announce fuel value via TTS ───────────────────────────────────
local function announceFuel(fuelValue)
    system.playNumber(fuelValue, 0, "ml", "Fuel")
end

-- ── Sensor changed callback ───────────────────────────────────────
local function sensorChanged(value)
    if value > 0 then
        fuelSensor = sensorsAvail[value].id
        fuelParam  = sensorsAvail[value].param
        system.pSave("fuelSens", fuelSensor)
        system.pSave("fuelParm", fuelParam)
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
            if sensor.id == fuelSensor and sensor.param == fuelParam then
                curIndex = #sensorsAvail
            end
        end
    end

    form.addLabel({ label = "Fuel Widget Setup", font = FONT_BOLD })

    form.addRow(2)
    form.addLabel({ label = "Fuel sensor", width = 120 })
    form.addSelectbox(list, curIndex, true, sensorChanged, { width = 190 })

    if emulator ~= 0 then
        form.addRow(1)
        form.addLabel({ label = "** EMULATOR: mock 2000ml -> 0ml over 15s **" })
    end
end

local function keyPressed(key) end
local function printForm() end

-- ── Telemetry widget paint ────────────────────────────────────────
local function printTelemetry(width, height)
    local fuelValue = roundTo100(currentFuel)

    -- Use FONT_BIG on DS-16 (smaller screen), FONT_MAXI on DS-24
    local valueFont = isDS16 and FONT_BIG or FONT_MAXI

    lcd.setColor(lcd.getFgColor())
    lcd.drawText(5, 5, "Fuel", FONT_BOLD)

    if fuelValue <= 200 then
        lcd.setColor(255, 0, 0)
    else
        lcd.setColor(0, 0, 0)
    end

    local display = string.format("%d ml", fuelValue)
    lcd.drawText(5, isDS16 and 22 or 30, display, valueFont)
end

-- ── Init ─────────────────────────────────────────────────────────
local function init()
    fuelSensor = system.pLoad("fuelSens")
    fuelParam  = system.pLoad("fuelParm")

    -- DS-16 supports single width slots only (1), DS-24 supports double (2)
    local slotSize = isDS16 and 1 or 2

    system.registerForm(1, MENU_APPS, "Fuel Widget", initForm, keyPressed, printForm)
    system.registerTelemetry(1, "Fuel", slotSize, printTelemetry)
end

-- ── Loop ─────────────────────────────────────────────────────────
local function loop()
    local val, valid = getValue()
    if not valid then return end

    currentFuel = val
    local fuelValue = roundTo100(currentFuel)

    -- Announce whenever the displayed 100ml value changes
    if lastAnnounced ~= fuelValue then
        lastAnnounced = fuelValue
        announceFuel(fuelValue)
    end
end

-- ── Return table ──────────────────────────────────────────────────
return {
    init    = init,
    loop    = loop,
    author  = "Custom",
    version = "1.1",
    name    = "Fuel",
}
