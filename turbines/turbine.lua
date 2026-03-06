-- ─────────────────────────────────────────────────────────────────
-- https://github.com/sverrirg/lua/tree/main/fuel
--
-- Turbine Status Widget for Jeti DC/DS transmitters
-- Compatible with DS-16 (devID 1) and DS-24II (devID 2)
-- on firmware 4.22+
--
-- Displays turbine ECU status code as human-readable text.
-- Supports 12 turbine types selectable from the setup form.
-- Single slot only — status text, colour coded.
--
-- Turbine types:
--   1=Jakadofsky  2=evoJet      3=PBS         4=HORNET
--   5=JetCat      6=KingTech    7=AMT         8=Xicoy/Kolibri
--   9=JetCentral  10=Kolibri NG 11=Swiwin     12=Linton
--
-- Version: 2.1
-- Filename: turbine.lua  (max 8 chars before extension)
-- Place in /Apps/ folder on SD card
-- ─────────────────────────────────────────────────────────────────

local statusSensor   = nil
local statusParam    = nil
local sensorsAvail   = {}
local currentCode    = nil
local turbineType    = 1

local devId, emulator = system.getDeviceType()
local isDS16 = (devId == 1)

-- ── Turbine name list ─────────────────────────────────────────────
local TURBINE_NAMES = {
    "Jakadofsky", "evoJet", "PBS", "HORNET",
    "JetCat", "KingTech", "AMT", "Xicoy/Kolibri",
    "JetCentral", "Kolibri NG", "Swiwin", "Linton",
}

-- ── Status code tables ────────────────────────────────────────────
local TURBINE_CODES = {

    -- 1: Jakadofsky
    {
        [-30]="ERROR",   [-20]="TH:-off", [-10]="TH:cool",
        [-1]="TH:lock",  [0]="TH:stop",  [10]="TH:run-",
        [20]="TH:rel-",  [25]="TH:glow", [30]="TH:spin",
        [40]="TH:fire",  [45]="TH:ignt", [50]="TH:heat",
        [60]="TH:acce",  [65]="TH:cal.", [70]="TH:idle",
    },

    -- 2: evoJet
    {
        [-30]="ERROR",   [-20]="TH:-off", [-10]="TH:cool",
        [-1]="TH:lock",  [0]="TH:stop",  [10]="TH:run-",
        [20]="TH:rel-",  [25]="TH:glow", [30]="TH:spin",
        [40]="TH:fire",  [45]="TH:ignt", [50]="TH:heat",
        [60]="TH:acce",  [65]="TH:cal.", [70]="TH:idle",
    },

    -- 3: PBS
    {
        [-30]="ERROR",  [-10]="COOL",   [-1]="LOCK",
        [0]="STOP",     [10]="TH:Idle", [20]="TH:-Rel",
        [25]="TEST",    [40]="FIRE",    [70]="IDLE",
    },

    -- 4: HORNET
    {
        [-30]="DEV.DELAY", [-20]="FLAME OUT", [-10]="EMERGENCY",
        [0]="OFF",   [1]="ON",         [10]="Cool Down",
        [20]="Slow Down",  [30]="STANDBY",   [31]="PROP IGNIT",
        [32]="PROP HEAT",  [33]="Pump Start", [34]="BURNER ON",
        [35]="FUEL IGNIT", [36]="FUEL HEAT",  [37]="Ramp Delay",
        [38]="RAMP UP",    [40]="STEADY",     [41]="CAL IDLE",
        [42]="CALIBRATE",  [43]="WAIT ACC",   [44]="GO IDLE",
        [50]="AUTO",       [51]="AUTO HC",
    },

    -- 5: JetCat
    {
        [-40]="Failure",   [-32]="ECU reboot", [-31]="ClutchFail",
        [-30]="Low Rpm",   [-29]="Low Rpm",    [-28]="Out Fuel",
        [-27]="Pump Comm", [-26]="WrongPump",  [-25]="No Pump!",
        [-24]="OverCurr",  [-23]="No-OIL",     [-22]="2nd Comm",
        [-21]="2nd Diff",  [-20]="2nd EngF",   [-19]="Rpm2Fail",
        [-18]="FuelFail",  [-17]="TempFail",   [-16]="PowerFail",
        [-15]="IgnTimOut", [-14]="FailSafe",   [-13]="WatchDog",
        [-12]="GlowPlug!", [-11]="HiTempOff",  [-10]="LowTempOff",
        [-9]="OverTemp",   [-8]="BattryLow",   [-7]="Low-Rpm",
        [-6]="Over-Rpm",   [-5]="Acc. Slow",   [-4]="AccTimOut",
        [-3]="Manual Off", [-2]="Auto-Off",    [-1]="RC-Off",
        [0]="-OFF-",    [1]="SlowDown",  [2]="SwitchOff",
        [3]="Stby/START",  [4]="PreHeat1",     [5]="PreHeat2",
        [6]="Ignite...",   [7]="AccelrDly",    [8]="MainFStrt",
        [9]="Keros.Full",  [10]="Accelerate",  [11]="Stabilise",
        [12]="LearnLO",    [13]="RUN (reg.)",  [14]="SpeedCtrl",
        [15]="Rpm2Ctrl",
    },

    -- 6: KingTech
    {
        [-20]="ERROR",   [-19]="Unknown",  [-13]="CAB-Lost",
        [-12]="FlameOut",[-11]="TempHigh", [-10]="SpeedLow",
        [-9]="Failsafe", [-8]="RxPwFail", [-7]="Overload",
        [-6]="Low Batt", [-5]="StartBad", [-4]="Weak Gas",
        [-3]="Time Out", [-2]="Ign.Fail", [-1]="Glow Bad",
        [0]="Trim Low",  [1]="User Off",  [2]="Stop",
        [3]="Cooling",   [4]="Ready",     [5]="GdReady",
        [6]="GlowTest",  [7]="StickLo!",  [8]="PrimeVap",
        [9]="BurnerOn",  [10]="Start On", [11]="Ignition",
        [12]="Stage1",   [13]="Stage2",   [14]="Stage3",
        [20]="Running",  [22]="ReStart",
    },

    -- 7: AMT
    {
        [-20]="ERROR",          [-8]="Supply ASS",
        [-7]="Supply low",      [-6]="RPM high",
        [-5]="EGT error",       [-4]="Throttle fail",
        [-3]="Switch failure",  [-2]="RPM low",
        [-1]="No serial input", [0]="No Start Clear",
        [1]="Start Clear",      [2]="Starting",
        [3]="Started up",       [4]="Calibrated",
        [5]="Auto stop",        [6]="Running",
        [7]="Max. RPM",
    },

    -- 8: Xicoy/Kolibri
    {
        [-14]="FlameOut",  [-13]="TempHigh",  [-12]="SpeedLow",
        [-11]="Failsafe",  [-10]="RxPwFail",  [-9]="PumpLimit",
        [-8]="Overload",   [-7]="Low Batt",   [-6]="StartBad",
        [-5]="Weak Gas",   [-4]="Time Out",   [-3]="IgntrBaD",
        [-2]="Glow Bad",   [-1]="Unknown",    [0]="Trim Low",
        [1]="User Off",    [2]="Stop",        [3]="Cooling",
        [4]="Ready",       [5]="SetIdle!",    [6]="StickLo!",
        [7]="GlowTest",    [8]="Starting",    [9]="BurnerOn",
        [10]="Start On",   [11]="Ignition",   [12]="Pre Heat",
        [13]="SwitchOver", [14]="FuelRamp",   [20]="Run-Idle",
        [21]="Running",    [22]="Run-Max",    [23]="ReStart",
    },

    -- 9: JetCentral
    {
        [-21]="ERROR",         [-20]="No data",       [-19]="MaxPump",
        [-18]="RPMSensorErr",  [-17]="LowRPM",        [-16]="MaxAmpers",
        [-15]="MaxTemp",       [-14]="ComTurbErr",    [-13]="TempSensErr",
        [-12]="RxSetupError",  [-11]="Failsafe",      [-10]="NoRx",
        [-9]="LowECUBatt",     [-8]="LowRXBatt",      [-7]="IgniterBad",
        [-6]="AcelerateBad",   [-5]="ToIdle Error",   [-4]="StarterError",
        [-3]="SwitchOverErr",  [-2]="PreheatError",   [-1]="IgnitionError",
        [0]="OFF",     [1]="ManCooling",  [2]="AutoCooling",
        [6]="GlowTest",        [7]="StarterTest",     [8]="PrimeFuel",
        [9]="PrimeBurner",     [10]="Standby",        [11]="Start",
        [12]="IgniterHeat",    [13]="Ignition",       [14]="Preheat",
        [15]="Switchover",     [16]="To Idle",        [17]="MinPumpOk",
        [18]="MaxPumpOk",      [19]="Running",        [20]="Full",
    },

    -- 10: Kolibri NG
    {
        [-10]="FLAME OUT", [-2]="BATT LOW!", [-1]="GLOW PLUG!",
        [0]="OFF",    [1]="ON",    [2]="COOL-DOWN",
        [3]="SLOW-DOWN",   [10]="STANDBY",   [11]="PROPIGNIT",
        [12]="PROP-HEAT",  [13]="PUMPSTART", [14]="FUELHEAT",
        [15]="RAMP-UP",    [20]="AUTO",
    },

    -- 11: Swiwin
    {
        [-30]="No data",       [-18]="Engine Offline", [-17]="Curr overload",
        [-16]="Clutch failure",[-15]="Pump Tmp High",  [-14]="StarterTmpHigh",
        [-13]="Lost Signal",   [-12]="Fuel Valve Bad", [-11]="Gas Valve Bad",
        [-10]="TempSensorfail",[-9]="Low Temp",        [-8]="High Temp",
        [-7]="RPM Instability",[-6]="RPM Low",         [-5]="Starter failure",
        [-4]="Pump Anomaly",   [-3]="GlowPlug Bad",    [-2]="Low Battery",
        [-1]="Time Out",       [0]="Stop",             [1]="Cooling",
        [5]="TestGlowPlug",    [6]="TestFuelValve",    [7]="TestGasValve",
        [8]="TestPump",        [9]="TestStarter",      [10]="Ready",
        [11]="Ignition",       [12]="Preheat",         [13]="Fuelramp",
        [20]="Running",        [21]="Restart",
    },

    -- 12: Linton
    {
        [-40]="No data",      [-39]="Error Alarms",  [-38]="Acc7",
        [-37]="Acc6",         [-36]="Acc5",          [-35]="Power limit",
        [-34]="Restart Fail", [-33]="Acc24",         [-32]="Dec23",
        [-31]="Acc22",        [-30]="Idle21",        [-29]="Idle Time",
        [-28]="CTH Time",     [-27]="Pump bubble",   [-26]="Temp5 Pro",
        [-25]="Temp4 Pro",    [-24]="Temp3 Pro",     [-23]="Temp2 Pro",
        [-22]="Temp1 Pro",    [-21]="HEGT3",         [-20]="HEGT2",
        [-19]="HEGT1",        [-18]="Fuel Fail",     [-17]="RPM Low",
        [-16]="RPM Err",      [-15]="Rc Lost Off",   [-14]="Pump Fail",
        [-13]="Pump Current", [-12]="Pump Open",     [-11]="CTH Fail",
        [-10]="Motor Current",[-9]="Motor Open",     [-8]="IGT Short",
        [-7]="IGT Open",      [-6]="EGT Warn",       [-5]="TT Trans",
        [-4]="TT Open",       [-3]="Over Current",   [-2]="Volt High",
        [-1]="Volt Low",      [0]="Ready",           [1]="Ready start",
        [2]="Temp high",      [3]="Start..",         [4]="Burner..",
        [5]="Success",        [6]="Heating1..",      [7]="Heating2..",
        [8]="Heating3..",     [9]="Heating4..",      [10]="Heating5..",
        [11]="Heating6..",    [12]="Pump Acc..",     [13]="CTH..",
        [14]="Acc5..",        [15]="Acc6..",         [16]="Acc7..",
        [17]="Acc8..",        [18]="Idling..",       [19]="Acc..",
        [20]="Dec..",         [21]="Speed..",        [22]="Max Speed..",
        [23]="RC Learn",      [24]="RC Learning..",  [25]="RC Successful",
        [26]="Restart",       [27]="Restart..",      [28]="Cooling..",
        [29]="Error Status",
    },
}

-- ── Running state codes per turbine type (shown in green) ─────────
local RUNNING_CODES = {
    [1]={[70]=true}, [2]={[70]=true}, [3]={[70]=true},
    [4]={[40]=true,[50]=true,[51]=true},
    [5]={[10]=true,[11]=true,[13]=true,[14]=true},
    [6]={[20]=true}, [7]={[6]=true,[7]=true},
    [8]={[20]=true,[21]=true,[22]=true},
    [9]={[19]=true,[20]=true}, [10]={[20]=true},
    [11]={[20]=true,[21]=true},
    [12]={[18]=true,[19]=true,[20]=true,[21]=true,[22]=true},
}

-- ── Cooling state codes per turbine type (shown in blue) ──────────
local COOLING_CODES = {
    [1]={[-10]=true}, [2]={[-10]=true}, [3]={[-10]=true},
    [4]={[10]=true},  [5]={[1]=true},
    [6]={[3]=true},   [8]={[3]=true},
    [9]={[1]=true,[2]=true}, [10]={[2]=true},
    [11]={[1]=true},  [12]={[28]=true},
}

-- ── Resolve code to text ──────────────────────────────────────────
local function resolveCode(code)
    local codes = TURBINE_CODES[turbineType]
    if codes and codes[code] then return codes[code] end
    return "Code unknown"
end

-- ── Resolve code to colour ────────────────────────────────────────
local function getColour(code)
    if code < 0 then return 255, 0, 0 end   -- red: error
    local r = RUNNING_CODES[turbineType]
    if r and r[code] then return 0, 180, 0 end  -- green: running
    local c = COOLING_CODES[turbineType]
    if c and c[code] then return 0, 100, 255 end -- blue: cooling
    return 0, 0, 0                              -- black: normal
end

-- ── Mock data generator (emulator only) ──────────────────────────
local mockCodes = { 0, 3, 10, 18, 21, 28, -1, -14 }
local mockTimer = nil
local MOCK_STEP = 2500

local function getMockValue()
    if mockTimer == nil then mockTimer = system.getTimeCounter() end
    local elapsed = system.getTimeCounter() - mockTimer
    local idx = (math.floor(elapsed / MOCK_STEP) % #mockCodes) + 1
    return mockCodes[idx], true
end

-- ── Live sensor reader ────────────────────────────────────────────
local function getLiveValue()
    if statusSensor and statusParam then
        local sensorData = system.getSensorByID(statusSensor, statusParam)
        if sensorData and sensorData.valid then
            return math.floor(sensorData.value + 0.5), true
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

-- ── Turbine type changed callback ─────────────────────────────────
local function turbineTypeChanged(value)
    turbineType = value
    system.pSave("turbType", turbineType)
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

    form.addRow(2)
    form.addLabel({ label = "Turbine type", width = 120 })
    form.addSelectbox(TURBINE_NAMES, turbineType, true, turbineTypeChanged, { width = 190 })

    form.addRow(2)
    form.addLabel({ label = "Status sensor", width = 120 })
    form.addSelectbox(list, curIndex, true, sensorChanged, { width = 190 })

    if emulator ~= 0 then
        form.addRow(1)
        form.addLabel({ label = "** EMULATOR: cycling through codes **" })
    end
end

local function keyPressed(key) end
local function printForm() end

-- ── Telemetry widget paint (single slot) ─────────────────────────
local function printTelemetry(width, height)
    local statusFont = isDS16 and FONT_NORMAL or FONT_BIG
    local displayText
    local r, g, b = 0, 0, 0

    if currentCode == nil then
        displayText = "Select sensor"
    else
        displayText = resolveCode(currentCode)
        r, g, b = getColour(currentCode)
    end

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

    local savedType = system.pLoad("turbType")
    if savedType and savedType >= 1 and savedType <= #TURBINE_NAMES then
        turbineType = savedType
    end

    system.registerForm(1, MENU_APPS, "Turbine Status", initForm, keyPressed, printForm)
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
    version = "2.1",
    name    = "Turbine",
}
