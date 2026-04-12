-- ###############################################################################################
-- #    Flying Locations for JETI DC/DS transmitters 
-- #    Copyright (c) 2026 Sverrir Gunnlaugsson
-- #
-- #    This program is free software: you can redistribute it and/or modify
-- #    it under the terms of the GNU General Public License as published by
-- #    the Free Software Foundation, either version 3 of the License, or
-- #    (at your option) any later version.
-- #    
-- #    This program is distributed in the hope that it will be useful,
-- #    but WITHOUT ANY WARRANTY; without even the implied warranty of
-- #    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- #    GNU General Public License for more details.
-- #    
-- #    You should have received a copy of the GNU General Public License
-- #    along with this program.  If not, see <http://www.gnu.org/licenses/>.
-- #
-- ###############################################################################################
-- ─────────────────────────────────────────────────────────────────
-- https://github.com/sverrirg/lua/tree/main/flying_locations
--
-- Flying Locations — Jeti DC/DS transmitter app
-- Compatible with DS-12, DS/DC-14 II, DS/DC-16 II, DS-24 and DS/DC-24 II
-- on firmware 4.22+
--
-- Single form with two views toggled by F1:
--   Browse view — scrollable list, F1 = send to F3F Tool, F3 = Add
--   Add view    — input fields,    F1 = back to list
--
-- File layout on SD card:
--   Apps/flyloc.lua
--   Apps/flyloc/flyloc.jsn
--
-- Version: 1.2
-- ─────────────────────────────────────────────────────────────────

-- DS/DC-24 II have a 480x480 screen; all other current models use 320x240.
local devName = system.getDeviceType()
local isLarge = (string.find(devName, "24 II") ~= nil or string.find(devName, "24II") ~= nil)

local DATA_DIR  = "Apps/flyloc"
local F3F_FILE  = "Apps/f3fTool-21/slopeData.jsn"
local DATA_FILE = "Apps/flyloc/flyloc.jsn"

-- ── State ────────────────────────────────────────────────────────
local locations   = {}
local scrollIndex     = 1
local selectedIndex = 1      -- currently highlighted row
local viewAdd       = false   -- false = browse, true = add
local editIndex     = nil        -- nil = adding new, number = editing existing

local inputName = ""
local inputWind = 0

-- Notification state
local notifyMsg    = nil   -- message to show, nil = none
local notifyTime   = 0     -- system time when notification was set
local notifyTimeout = 5000 -- ms to show notification

-- ── Sort / Save / Load ───────────────────────────────────────────
local function sortLocations()
    table.sort(locations, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)
end

local function saveData()
    local text = json.encode(locations)
    if not text then return end
    local f = io.open(DATA_FILE, "w")
    if not f then
        io.mkdir(DATA_DIR)
        f = io.open(DATA_FILE, "w")
    end
    if f then
        io.write(f, text)
        io.close(f)
    end
end

local function loadData()
    local text = io.readall(DATA_FILE)
    if text and #text > 2 then
        local decoded = json.decode(text)
        if type(decoded) == "table" then
            locations = decoded
        end
    end
    sortLocations()
end

-- ── Timed notification ───────────────────────────────────────────
local function notify(msg, timeout)
    notifyMsg     = msg
    notifyTime    = system.getTimeCounter()
    notifyTimeout = timeout or 5000
end

-- ── Send bearing to F3F Tool ─────────────────────────────────────
local function sendToF3F()
    if #locations == 0 then return end
    local loc = locations[selectedIndex]
    -- F3F Tool uses the slope edge direction: add 90° with 360° rollover
    local bearing = (math.floor(loc.wind) + 90) % 360

    -- Read existing slopeData to preserve other fields
    local text = io.readall(F3F_FILE)
    local data = {}
    if text and #text > 2 then
        data = json.decode(text) or {}
    end
    data.bearing = bearing

    local f = io.open(F3F_FILE, "w")
    if f then
        io.write(f, json.encode(data))
        io.close(f)
        f3fTool_extCourseChange = true    -- signal F3F Tool to reload course data
        notify(string.format("%s - %d\194\176|sent to F3F Tool",
            loc.name, loc.wind), 3000)
    else
        notify("Error: Could not write|to F3F Tool slope file.", 2000)
    end
end

-- ── Wind compass label ────────────────────────────────────────────
local COMPASS = {
    "N","NNE","NE","ENE","E","ESE","SE","SSE",
    "S","SSW","SW","WSW","W","WNW","NW","NNW"
}
local function windLabel(deg)
    deg = math.floor(deg) % 360
    local idx = math.floor((deg + 11.25) / 22.5) % 16 + 1
    return string.format("%d° %s", deg, COMPASS[idx])
end

-- ── Layout ───────────────────────────────────────────────────────
local ROW_H   = isLarge and 28 or 19
local FONT_H  = FONT_NORMAL
local FONT_HD = FONT_BOLD
local COL2_X  = isLarge and 228 or 230
local VISIBLE = isLarge and 10 or 8

-- ── Form init — rebuilds widgets for current view ─────────────────
local function initForm(formID)
    if viewAdd then
        -- Add view
        form.setButton(1, ":backward", ENABLED)
        form.addLabel({ label = editIndex and "Edit Location" or "Add New Location", font = FONT_BOLD })
        form.addRow(2)
        form.addLabel({ label = "Name", width = 90 })
        form.addTextbox(inputName, 24,
            function(v) inputName = v end, { width = 220 })
        form.addRow(2)
        form.addLabel({ label = "Wind (°)", width = 90 })
        form.addIntbox(math.floor(inputWind), 0, 359, 0, 0, 1,
            function(v) inputWind = math.floor(v) end, { width = 100 })
        form.addRow(1)
        form.addLink(function()
            local trimmed = string.match(inputName, "^%s*(.-)%s*$")
            if trimmed and #trimmed > 0 then
                if editIndex then
                    locations[editIndex] = { name = trimmed, wind = inputWind }
                    sortLocations()
                else
                    locations[#locations + 1] = { name = trimmed, wind = inputWind }
                    sortLocations()
                end
                saveData()
                inputName = ""
                inputWind = 0
                editIndex = nil
                viewAdd = false
                form.reinit()
            end
        end, { label = editIndex and "Save changes >>" or "Add location >>" })
        form.addLabel({
            label   = editIndex and string.format("Editing %d of %d", editIndex, #locations)
                               or string.format("Total locations: %d", #locations),
            font    = FONT_MINI,
            enabled = false
        })
    else
        -- Browse view — no widgets, pure custom draw
        form.setButton(1, ":play", ENABLED)
        form.setButton(2, ":edit", ENABLED)
        form.setButton(3, ":add", ENABLED)
        form.setButton(4, ":delete", ENABLED)
    end
end

-- ── Key handler ───────────────────────────────────────────────────
local function keyPressed(key)
    if key == KEY_3 and not viewAdd then
        -- F3 = Add (browse view only)
        viewAdd = true
        inputName = ""
        inputWind = 0
        editIndex = nil
        form.reinit()
        return
    end
    if key == KEY_1 and viewAdd then
        -- F1 = backward (add/edit view only)
        viewAdd = false
        inputName = ""
        inputWind = 0
        editIndex = nil
        form.reinit()
        return
    end
    -- F1 = send to F3F Tool (browse view only)
    if key == KEY_1 and not viewAdd then
        sendToF3F()
        return
    end
    -- Scroll and delete only active in browse view
    if not viewAdd then
        local maxScroll = math.max(1, #locations - VISIBLE + 1)
        if key == KEY_DOWN then
            if selectedIndex < #locations then
                selectedIndex = selectedIndex + 1
            end
            if selectedIndex > scrollIndex + VISIBLE - 1 then
                scrollIndex = selectedIndex - VISIBLE + 1
            end
        elseif key == KEY_UP then
            if selectedIndex > 1 then
                selectedIndex = selectedIndex - 1
            end
            if selectedIndex < scrollIndex then
                scrollIndex = selectedIndex
            end
        elseif key == KEY_2 then
            if #locations > 0 then
                editIndex = selectedIndex
                inputName = locations[selectedIndex].name
                inputWind = locations[selectedIndex].wind
                viewAdd = true
                form.reinit()
            end
        elseif key == KEY_4 then
            if #locations > 0 then
                local deletedName = locations[selectedIndex].name
                table.remove(locations, selectedIndex)
                if selectedIndex > #locations then
                    selectedIndex = math.max(1, #locations)
                end
                scrollIndex = math.max(1, math.min(scrollIndex,
                    math.max(1, #locations - VISIBLE + 1)))
                saveData()
                notify(string.format("\"%s\" deleted", deletedName), 2000)
            end
        end
    end
end

-- ── Custom draw (browse view only) ───────────────────────────────
local function printForm()
    if viewAdd then return end   -- widgets handle the add view

    local scrW = isLarge and 440 or 300

    lcd.setColor(0, 0, 0)
    lcd.drawText(2, 0, "Slope / Location", FONT_HD)
    lcd.drawText(COL2_X, 0, "Wind", FONT_HD)
    local divY = ROW_H
    lcd.drawLine(0, divY, scrW, divY)

    if #locations == 0 then
        lcd.setColor(120, 120, 120)
        lcd.drawText(4, divY + 4, "No locations — press F1 to add.", FONT_H)
        lcd.setColor(0, 0, 0)
        return
    end

    local maxScroll = math.max(1, #locations - VISIBLE + 1)
    if scrollIndex > maxScroll then scrollIndex = maxScroll end

    local last = math.min(scrollIndex + VISIBLE - 1, #locations)
    local textOff = isLarge and 5 or 0
    for i = scrollIndex, last do
        local loc  = locations[i]
        local rowY = divY + 2 + (i - scrollIndex) * ROW_H
        if i == selectedIndex then
            lcd.setColor(60, 60, 200)
            lcd.drawFilledRectangle(0, rowY - 1, scrW - 8, ROW_H)
            lcd.setColor(255, 255, 255)
        elseif  (i % 2 == 0) then
            lcd.setColor(238, 238, 250)
            lcd.drawFilledRectangle(0, rowY - 1, scrW - 8, ROW_H)
            lcd.setColor(0, 0, 0)
        else
            lcd.setColor(0, 0, 0)
        end
        lcd.drawText(4,      rowY + textOff, loc.name,            FONT_H)
        lcd.drawText(COL2_X, rowY + textOff, windLabel(loc.wind), FONT_H)
    end

    -- Timed notification overlay
    if notifyMsg and (system.getTimeCounter() - notifyTime) < notifyTimeout then
        local boxW = isLarge and 300 or 280
        local boxH = 44
        local boxX = 8
        local boxY = math.floor((VISIBLE * ROW_H) / 2) - math.floor(boxH / 2) + divY
        lcd.setColor(240, 240, 200)
        lcd.drawFilledRectangle(boxX, boxY, boxW, boxH)
        lcd.setColor(0, 0, 0)
        lcd.drawRectangle(boxX, boxY, boxW, boxH)
        -- Split message into two lines
        local line1, line2 = string.match(notifyMsg, "^(.-)|(.+)$")
        if line1 then
            lcd.drawText(boxX + 8, boxY + 6,  line1, FONT_NORMAL)
            lcd.drawText(boxX + 8, boxY + 24, line2, FONT_NORMAL)
        else
            lcd.drawText(boxX + 8, boxY + 14, notifyMsg, FONT_NORMAL)
        end
    elseif notifyMsg and (system.getTimeCounter() - notifyTime) >= notifyTimeout then
        notifyMsg = nil
    end

    -- Scrollbar
    if #locations > VISIBLE then
        local barX    = scrW - 6
        local barArea = VISIBLE * ROW_H
        local barH    = math.max(4, math.floor(barArea * VISIBLE / #locations))
        local maxTop  = math.max(1, #locations - VISIBLE)
        local barY    = divY + 2 + math.floor(
                            (barArea - barH) * (scrollIndex - 1) / maxTop)
        lcd.setColor(200, 200, 200)
        lcd.drawFilledRectangle(barX, divY + 2, 4, barArea)
        lcd.setColor(60, 60, 200)
        lcd.drawFilledRectangle(barX, barY, 4, barH)
        lcd.setColor(0, 0, 0)
    end
end

-- ── Init ─────────────────────────────────────────────────────────
local function init()
    loadData()
    system.registerForm(1, MENU_APPS, "Flying Locations",
        initForm, keyPressed, printForm)
end

local function loop() end

return {
    init    = init,
    loop    = loop,
    author  = "Sverrir Gunnlaugsson",
    version = "1.2",
    name    = "Flying Locations",
}
