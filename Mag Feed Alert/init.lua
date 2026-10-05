-- Mag Feed Alert
-- Ephinea / PSOBB addon for the psobbaddonplugin Lua addon framework.
-- Read-only: reads carried Mag feed timers and renders reminders.
-- Developed with assistance from ChatGPT.

local core_ok, core_mainmenu = pcall(require, "core_mainmenu")
local helpers_ok, lib_helpers = pcall(require, "solylib.helpers")
local items_ok, lib_items = pcall(require, "solylib.items.items")

local ADDON_NAME = "Mag Feed Alert"
local ADDON_VERSION = "1.0.0"
local OPTIONS_FILE = "addons/Mag Feed Alert/options.lua"

local PROFILE_ACTIVE = 1
local PROFILE_AWAY = 2
local PROFILE_CUSTOM = 3
local PROFILE_NAMES = { "Active", "Away", "Custom" }

local READY_COLOR_DEFAULT = { 0.16, 0.80, 0.40, 1.00 }
local BORDER_COLOR_DEFAULT = { 0.16, 0.80, 0.40, 1.00 }

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function shallow_copy_array(t)
    return { t[1], t[2], t[3], t[4] }
end

local function default_custom_active()
    return {
        showCooldownHud = true,
        showReadyHud = true,
        timerScale = 1.00,
        transparentBackground = false,
        readyHudScale = 1.50,
        initialReadyPulse = true,
        readyPulseDuration = 0.80,
        readyPulseBoost = 0.25,
        centralReady = false,
        centralScale = 3.00,
        screenBorder = false,
        borderThickness = 8.0,
        borderPulse = false,
        borderCycle = 2.00,
        showOverdue = false,
        readyColor = shallow_copy_array(READY_COLOR_DEFAULT),
        borderColor = shallow_copy_array(BORDER_COLOR_DEFAULT),
    }
end

local function default_custom_away()
    local t = default_custom_active()
    t.centralReady = true
    t.screenBorder = true
    t.borderPulse = true
    return t
end

local DEFAULTS = {
    enable = true,
    firstRun = true,
    profile = PROFILE_ACTIVE,
    hudLocked = true,
    useFactoryPlacement = true,
    hudAnchor = 7,
    hudX = -20,
    hudY = 140,
    scanIntervalMs = 200,
    custom = default_custom_active(),
}

local optionsLoaded, options = pcall(require, "Mag Feed Alert.options")
if not optionsLoaded or type(options) ~= "table" then
    options = {}
end

local function merge_defaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            merge_defaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end
merge_defaults(options, DEFAULTS)

local configurationOpen = false
local optionsDirty = false
local firstPresent = true
local previewMode = nil -- nil | "cooldown" | "ready"
local previewUntil = 0
local previewStarted = 0

local tracker = {
    valid = false,
    hasMag = false,
    magCount = 0,
    rawMin = 0,
    rawMax = 0,
    remaining = 0,
    ready = false,
    lastReady = false,
    readySince = 0,
    pulseStarted = 0,
    lastScan = 0,
    lastError = nil,
}

local layout = {
    lastW = 190,
    lastH = 34,
    freeX = nil,
    freeY = nil,
}

local function boolstr(v)
    return v and "true" or "false"
end

local function numstr(v)
    return string.format("%.6f", tonumber(v) or 0)
end

local function write_color(f, key, color, indent)
    indent = indent or "    "
    f:write(string.format("%s%s = { %.6f, %.6f, %.6f, %.6f },\n",
        indent, key, color[1], color[2], color[3], color[4]))
end

local function SaveOptions()
    local f = io.open(OPTIONS_FILE, "w")
    if f == nil then
        return
    end

    f:write("return {\n")
    f:write("    enable = " .. boolstr(options.enable) .. ",\n")
    f:write("    firstRun = " .. boolstr(options.firstRun) .. ",\n")
    f:write(string.format("    profile = %d,\n", options.profile))
    f:write("    hudLocked = " .. boolstr(options.hudLocked) .. ",\n")
    f:write("    useFactoryPlacement = " .. boolstr(options.useFactoryPlacement) .. ",\n")
    f:write(string.format("    hudAnchor = %d,\n", options.hudAnchor))
    f:write("    hudX = " .. numstr(options.hudX) .. ",\n")
    f:write("    hudY = " .. numstr(options.hudY) .. ",\n")
    f:write(string.format("    scanIntervalMs = %d,\n", options.scanIntervalMs))
    f:write("    custom = {\n")
    f:write("        showCooldownHud = " .. boolstr(options.custom.showCooldownHud) .. ",\n")
    f:write("        showReadyHud = " .. boolstr(options.custom.showReadyHud) .. ",\n")
    f:write("        timerScale = " .. numstr(options.custom.timerScale) .. ",\n")
    f:write("        transparentBackground = " .. boolstr(options.custom.transparentBackground) .. ",\n")
    f:write("        readyHudScale = " .. numstr(options.custom.readyHudScale) .. ",\n")
    f:write("        initialReadyPulse = " .. boolstr(options.custom.initialReadyPulse) .. ",\n")
    f:write("        readyPulseDuration = " .. numstr(options.custom.readyPulseDuration) .. ",\n")
    f:write("        readyPulseBoost = " .. numstr(options.custom.readyPulseBoost) .. ",\n")
    f:write("        centralReady = " .. boolstr(options.custom.centralReady) .. ",\n")
    f:write("        centralScale = " .. numstr(options.custom.centralScale) .. ",\n")
    f:write("        screenBorder = " .. boolstr(options.custom.screenBorder) .. ",\n")
    f:write("        borderThickness = " .. numstr(options.custom.borderThickness) .. ",\n")
    f:write("        borderPulse = " .. boolstr(options.custom.borderPulse) .. ",\n")
    f:write("        borderCycle = " .. numstr(options.custom.borderCycle) .. ",\n")
    f:write("        showOverdue = " .. boolstr(options.custom.showOverdue) .. ",\n")
    write_color(f, "readyColor", options.custom.readyColor, "        ")
    write_color(f, "borderColor", options.custom.borderColor, "        ")
    f:write("    },\n")
    f:write("}\n")
    f:close()
end

local function mark_dirty()
    optionsDirty = true
end

local function get_resolution()
    if helpers_ok and lib_helpers then
        local okW, w = pcall(lib_helpers.GetResolutionWidth)
        local okH, h = pcall(lib_helpers.GetResolutionHeight)
        if okW and okH and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
            return w, h
        end
    end
    return 1280, 720
end

local function factory_y(resH)
    return clamp(math.floor(resH * 0.18 + 0.5), 110, 220)
end

local function anchored_position(anchor, ox, oy, w, h, resW, resH)
    local baseX, baseY = 0, 0
    if anchor == 1 then
        baseX, baseY = 0, 0
    elseif anchor == 2 then
        baseX, baseY = 0, (resH - h) / 2
    elseif anchor == 3 then
        baseX, baseY = 0, resH - h
    elseif anchor == 4 then
        baseX, baseY = (resW - w) / 2, 0
    elseif anchor == 5 then
        baseX, baseY = (resW - w) / 2, (resH - h) / 2
    elseif anchor == 6 then
        baseX, baseY = (resW - w) / 2, resH - h
    elseif anchor == 7 then
        baseX, baseY = resW - w, 0
    elseif anchor == 8 then
        baseX, baseY = resW - w, (resH - h) / 2
    elseif anchor == 9 then
        baseX, baseY = resW - w, resH - h
    end
    return baseX + ox, baseY + oy
end

local function nearest_anchor_and_offsets(x, y, w, h, resW, resH)
    local cx = x + w / 2
    local cy = y + h / 2

    local col
    if cx < resW / 3 then col = 1
    elseif cx > (resW * 2 / 3) then col = 3
    else col = 2 end

    local row
    if cy < resH / 3 then row = 1
    elseif cy > (resH * 2 / 3) then row = 3
    else row = 2 end

    local anchor = (col - 1) * 3 + row
    local bx, by = anchored_position(anchor, 0, 0, w, h, resW, resH)
    return anchor, x - bx, y - by
end

local function format_time(seconds)
    local s = math.max(0, math.floor(seconds or 0))
    local m = math.floor(s / 60)
    local r = s % 60
    return string.format("%d:%02d", m, r)
end

local function profile_name(profile)
    return PROFILE_NAMES[profile] or "Active"
end

local function set_profile(profile)
    if profile < PROFILE_ACTIVE or profile > PROFILE_CUSTOM then return end
    if options.profile ~= profile then
        options.profile = profile
        if tracker.ready then
            tracker.pulseStarted = pso.get_tick_count()
        end
        mark_dirty()
    end
end

local function copy_custom_from(profile)
    if profile == PROFILE_AWAY then
        options.custom = default_custom_away()
    else
        options.custom = default_custom_active()
    end
    options.profile = PROFILE_CUSTOM
    if tracker.ready then tracker.pulseStarted = pso.get_tick_count() end
    mark_dirty()
end

local function scan_mags(now)
    local interval = clamp(tonumber(options.scanIntervalMs) or 200, 100, 1000)
    if tracker.lastScan ~= 0 and (now - tracker.lastScan) < interval then
        return
    end
    tracker.lastScan = now

    if not items_ok or not lib_items then
        tracker.valid = false
        tracker.lastError = "SolyLib item library is unavailable."
        return
    end

    local ok, inventory = pcall(lib_items.GetInventory, lib_items.Me)
    if not ok or type(inventory) ~= "table" or type(inventory.items) ~= "table" then
        tracker.valid = false
        tracker.lastError = ok and "Inventory data unavailable." or tostring(inventory)
        return
    end

    local count = 0
    local minTimer = nil
    local maxTimer = nil

    for i = 1, #inventory.items do
        local item = inventory.items[i]
        if item and item.mag and type(item.mag.timer) == "number" then
            local t = item.mag.timer
            count = count + 1
            if minTimer == nil or t < minTimer then minTimer = t end
            if maxTimer == nil or t > maxTimer then maxTimer = t end
        end
    end

    tracker.valid = true
    tracker.lastError = nil
    tracker.magCount = count
    tracker.hasMag = count > 0

    if count == 0 then
        tracker.rawMin = 0
        tracker.rawMax = 0
        tracker.remaining = 0
        tracker.ready = false
        tracker.lastReady = false
        tracker.readySince = 0
        return
    end

    tracker.rawMin = minTimer or 0
    tracker.rawMax = maxTimer or 0

    -- If carried Mag timers ever disagree, use the largest remaining value.
    -- This is intentionally conservative: never announce readiness early.
    tracker.remaining = clamp(math.floor(tracker.rawMax), 0, 210)
    tracker.ready = tracker.rawMax < 1.0

    if tracker.ready and not tracker.lastReady then
        tracker.readySince = now
        tracker.pulseStarted = now
    elseif not tracker.ready then
        tracker.readySince = 0
    end

    tracker.lastReady = tracker.ready
end

local function effective_preset(profile)
    if profile == PROFILE_AWAY then
        return {
            showCooldownHud = true,
            showReadyHud = true,
            timerScale = 1.00,
            transparentBackground = false,
            readyHudScale = 1.50,
            initialReadyPulse = true,
            readyPulseDuration = 0.80,
            readyPulseBoost = 0.25,
            centralReady = true,
            centralScale = 3.00,
            screenBorder = true,
            borderThickness = 8.0,
            borderPulse = true,
            borderCycle = 2.00,
            showOverdue = false,
            readyColor = READY_COLOR_DEFAULT,
            borderColor = BORDER_COLOR_DEFAULT,
        }
    elseif profile == PROFILE_CUSTOM then
        return options.custom
    end

    return {
        showCooldownHud = true,
        showReadyHud = true,
        timerScale = 1.00,
        transparentBackground = false,
        readyHudScale = 1.50,
        initialReadyPulse = true,
        readyPulseDuration = 0.80,
        readyPulseBoost = 0.25,
        centralReady = false,
        centralScale = 3.00,
        screenBorder = false,
        borderThickness = 8.0,
        borderPulse = false,
        borderCycle = 2.00,
        showOverdue = false,
        readyColor = READY_COLOR_DEFAULT,
        borderColor = BORDER_COLOR_DEFAULT,
    }
end

local function current_visual_state(now)
    if previewMode ~= nil and now <= previewUntil then
        if previewMode == "ready" then
            return true, true, 0, previewStarted
        end
        return true, false, 137, 0
    end

    if previewMode ~= nil and now > previewUntil then
        previewMode = nil
    end

    if not tracker.valid or not tracker.hasMag then
        return false, false, 0, 0
    end

    return true, tracker.ready, tracker.remaining, tracker.readySince
end

local function pulse_hump(now, started, duration)
    if started == nil or started == 0 or duration <= 0 then return 0 end
    local age = (now - started) / 1000.0
    if age < 0 or age >= duration then return 0 end
    return math.sin(math.pi * (age / duration))
end

local function repeating_pulse(now, cycle)
    cycle = math.max(0.25, cycle or 2.0)
    local t = (now / 1000.0) * (2.0 * math.pi / cycle)
    return 0.50 + 0.50 * math.sin(t)
end

local function render_profile_popup()
    if imgui.BeginPopup("MagFeedProfilePopup") then
        if imgui.Selectable("Active", options.profile == PROFILE_ACTIVE) then
            set_profile(PROFILE_ACTIVE)
        end
        if imgui.Selectable("Away", options.profile == PROFILE_AWAY) then
            set_profile(PROFILE_AWAY)
        end
        if imgui.Selectable("Custom", options.profile == PROFILE_CUSTOM) then
            set_profile(PROFILE_CUSTOM)
        end
        imgui.Separator()
        if imgui.Selectable("Settings", false) then
            configurationOpen = true
        end
        imgui.EndPopup()
    end
end

local function render_hud(now, stateReady, remaining, readySince, preset)
    local showHud = stateReady and preset.showReadyHud or (not stateReady and preset.showCooldownHud)
    if not showHud then return end

    local windowName = "Mag Feed Alert - HUD"
    local flags = { "NoTitleBar", "NoResize", "AlwaysAutoResize", "NoScrollbar", "NoSavedSettings" }
    if options.hudLocked then
        table.insert(flags, "NoMove")
    end

    if preset.transparentBackground then
        imgui.PushStyleColor("WindowBg", 0.0, 0.0, 0.0, 0.0)
    end

    if imgui.Begin(windowName, nil, flags) then
        local textScale = preset.timerScale or 1.0
        local text = "Feed Mag " .. format_time(remaining)
        local color = nil

        if stateReady then
            text = "FEED MAG"
            textScale = preset.readyHudScale or 1.5
            color = preset.readyColor or READY_COLOR_DEFAULT
            if preset.initialReadyPulse then
                local hump = pulse_hump(now, tracker.pulseStarted, preset.readyPulseDuration or 0.8)
                textScale = textScale + hump * (preset.readyPulseBoost or 0.25)
            end
        end

        imgui.SetWindowFontScale(textScale)
        if color ~= nil then
            imgui.TextColored(color[1], color[2], color[3], color[4], text)
        else
            imgui.Text(text)
        end
        imgui.SetWindowFontScale(1.0)

        if stateReady and preset.showOverdue and readySince and readySince > 0 then
            local overdue = math.max(0, math.floor((now - readySince) / 1000))
            imgui.Text("Ready " .. format_time(overdue))
        end

        imgui.SameLine(0, 8)
        if imgui.SmallButton("[" .. profile_name(options.profile) .. "]") then
            imgui.OpenPopup("MagFeedProfilePopup")
        end
        render_profile_popup()

        local wx, wy = imgui.GetWindowPos()
        local ww, wh = imgui.GetWindowSize()
        layout.lastW, layout.lastH = ww, wh

        local resW, resH = get_resolution()
        if options.hudLocked then
            local ox, oy, anchor = options.hudX, options.hudY, options.hudAnchor
            if options.useFactoryPlacement then
                anchor = 7
                ox = -20
                oy = factory_y(resH)
            end
            local px, py = anchored_position(anchor, ox, oy, ww, wh, resW, resH)
            imgui.SetWindowPos(windowName, px, py, "Always")
        else
            layout.freeX, layout.freeY = wx, wy
        end
    end
    imgui.End()

    if preset.transparentBackground then
        imgui.PopStyleColor()
    end
end

local function pack_abgr(color, alphaMultiplier)
    local r = clamp(math.floor((color[1] or 1) * 255 + 0.5), 0, 255)
    local g = clamp(math.floor((color[2] or 1) * 255 + 0.5), 0, 255)
    local b = clamp(math.floor((color[3] or 1) * 255 + 0.5), 0, 255)
    local a = clamp(math.floor((color[4] or 1) * (alphaMultiplier or 1) * 255 + 0.5), 0, 255)
    return a * 0x1000000 + b * 0x10000 + g * 0x100 + r
end

local function render_center_ready(now, preset)
    if not preset.centralReady then return end

    local alpha = 1.0
    if preset.borderPulse then
        alpha = 0.60 + 0.40 * repeating_pulse(now, preset.borderCycle or 2.0)
    end

    imgui.SetNextWindowPosCenter("Always")
    imgui.PushStyleColor("WindowBg", 0.0, 0.0, 0.0, 0.0)
    if imgui.Begin("Mag Feed Alert - Ready", nil,
        { "NoTitleBar", "NoResize", "NoMove", "NoScrollbar", "AlwaysAutoResize", "NoSavedSettings", "NoInputs" }) then
        local c = preset.readyColor or READY_COLOR_DEFAULT
        imgui.SetWindowFontScale(preset.centralScale or 3.0)
        imgui.TextColored(c[1], c[2], c[3], clamp(c[4] * alpha, 0, 1), "FEED MAG")
        imgui.SetWindowFontScale(1.0)
    end
    imgui.End()
    imgui.PopStyleColor()
end

local function render_screen_border(now, preset)
    if not preset.screenBorder then return end

    local resW, resH = get_resolution()
    if resW <= 0 or resH <= 0 then return end

    local alpha = 1.0
    if preset.borderPulse then
        alpha = 0.35 + 0.65 * repeating_pulse(now, preset.borderCycle or 2.0)
    end

    local color = pack_abgr(preset.borderColor or BORDER_COLOR_DEFAULT, alpha)
    local thickness = clamp(preset.borderThickness or 8.0, 2.0, 30.0)

    imgui.SetNextWindowPos(0, 0, "Always")
    imgui.SetNextWindowSize(resW, resH, "Always")
    imgui.PushStyleColor("WindowBg", 0.0, 0.0, 0.0, 0.0)
    imgui.PushStyleVar("WindowPadding", 0, 0)
    if imgui.Begin("Mag Feed Alert - Border", nil,
        { "NoTitleBar", "NoResize", "NoMove", "NoScrollbar", "NoSavedSettings", "NoInputs", "NoBringToFrontOnFocus" }) then
        local inset = math.max(1.0, thickness / 2)
        imgui.AddRect(inset, inset, resW - inset, resH - inset, color, 0.0, 0x0F, thickness)
    end
    imgui.End()
    imgui.PopStyleVar()
    imgui.PopStyleColor()
end

local function checkbox_option(label, current, setter)
    local changed, value = imgui.Checkbox(label, current)
    if changed then
        setter(value)
        mark_dirty()
    end
end

local function slider_float_option(label, current, lo, hi, fmt, setter)
    local changed, value = imgui.SliderFloat(label, current, lo, hi, fmt or "%.2f")
    if changed then
        setter(value)
        mark_dirty()
    end
end

local function color_option(label, color)
    local changed, r, g, b, a = imgui.ColorEdit4(label, color[1], color[2], color[3], color[4], true)
    if changed then
        color[1], color[2], color[3], color[4] = r, g, b, a
        mark_dirty()
    end
end

local function finish_layout_lock()
    if layout.freeX == nil or layout.freeY == nil then
        options.hudLocked = true
        mark_dirty()
        return
    end

    local resW, resH = get_resolution()
    local anchor, ox, oy = nearest_anchor_and_offsets(
        layout.freeX, layout.freeY, layout.lastW, layout.lastH, resW, resH)
    options.hudAnchor = anchor
    options.hudX = ox
    options.hudY = oy
    options.useFactoryPlacement = false
    options.hudLocked = true
    mark_dirty()
end

local function render_status(now)
    imgui.Text("Status")
    imgui.Separator()

    if not items_ok then
        imgui.TextColored(1, 0.35, 0.35, 1, "SolyLib items library not found")
        imgui.Text("Install/restore the standard Soly addon libraries, then use Main > Reload.")
        return
    end

    if not tracker.valid then
        imgui.Text("Game/Mag state unavailable")
        if tracker.lastError then imgui.Text("Last read: " .. tostring(tracker.lastError)) end
        return
    end

    if not tracker.hasMag then
        imgui.Text("No carried Mag detected")
        return
    end

    if tracker.ready then
        imgui.TextColored(READY_COLOR_DEFAULT[1], READY_COLOR_DEFAULT[2], READY_COLOR_DEFAULT[3], 1, "Ready to feed")
    else
        imgui.Text("Next feed: " .. format_time(tracker.remaining))
    end
    imgui.Text(string.format("Carried Mags: %d", tracker.magCount))

    local spread = math.max(0, (tracker.rawMax or 0) - (tracker.rawMin or 0))
    imgui.Text(string.format("Timer spread: %.2f sec", spread))
    if spread >= 1.0 then
        imgui.TextColored(1.0, 0.75, 0.20, 1.0, "Timers differ; the addon is using the most conservative timer.")
    end
end

local function render_custom_settings()
    if not imgui.CollapsingHeader("Custom Profile") then return end

    if imgui.Button("Copy Active Settings") then
        copy_custom_from(PROFILE_ACTIVE)
    end
    imgui.SameLine(0, 6)
    if imgui.Button("Copy Away Settings") then
        copy_custom_from(PROFILE_AWAY)
    end

    imgui.Separator()
    imgui.Text("HUD")
    checkbox_option("Show cooldown HUD", options.custom.showCooldownHud, function(v) options.custom.showCooldownHud = v end)
    checkbox_option("Show ready HUD", options.custom.showReadyHud, function(v) options.custom.showReadyHud = v end)
    checkbox_option("Transparent HUD background", options.custom.transparentBackground, function(v) options.custom.transparentBackground = v end)
    slider_float_option("Timer scale", options.custom.timerScale, 0.75, 2.50, "%.2fx", function(v) options.custom.timerScale = v end)
    slider_float_option("Ready HUD scale", options.custom.readyHudScale, 1.00, 3.50, "%.2fx", function(v) options.custom.readyHudScale = v end)
    checkbox_option("Initial ready pulse", options.custom.initialReadyPulse, function(v) options.custom.initialReadyPulse = v end)
    if options.custom.initialReadyPulse then
        slider_float_option("Pulse duration", options.custom.readyPulseDuration, 0.20, 2.00, "%.2f sec", function(v) options.custom.readyPulseDuration = v end)
        slider_float_option("Pulse size boost", options.custom.readyPulseBoost, 0.05, 1.00, "+%.2fx", function(v) options.custom.readyPulseBoost = v end)
    end
    checkbox_option("Show time since ready", options.custom.showOverdue, function(v) options.custom.showOverdue = v end)

    imgui.Separator()
    imgui.Text("Large Ready Alert")
    checkbox_option("Large FEED MAG message", options.custom.centralReady, function(v) options.custom.centralReady = v end)
    if options.custom.centralReady then
        slider_float_option("Large message scale", options.custom.centralScale, 1.50, 5.00, "%.2fx", function(v) options.custom.centralScale = v end)
    end

    imgui.Separator()
    imgui.Text("Screen Border")
    checkbox_option("Screen-edge alert", options.custom.screenBorder, function(v) options.custom.screenBorder = v end)
    if options.custom.screenBorder then
        slider_float_option("Border thickness", options.custom.borderThickness, 2.0, 24.0, "%.0f px", function(v) options.custom.borderThickness = v end)
        checkbox_option("Pulse border", options.custom.borderPulse, function(v) options.custom.borderPulse = v end)
        if options.custom.borderPulse then
            slider_float_option("Border pulse cycle", options.custom.borderCycle, 0.75, 5.00, "%.2f sec", function(v) options.custom.borderCycle = v end)
        end
    end

    imgui.Separator()
    imgui.Text("Colors")
    color_option("Ready color", options.custom.readyColor)
    color_option("Border color", options.custom.borderColor)

    imgui.Separator()
    if imgui.Button("Reset Custom to Active") then
        options.custom = default_custom_active()
        options.profile = PROFILE_CUSTOM
        mark_dirty()
    end
end

local function render_configuration(now)
    if not configurationOpen then return end

    imgui.SetNextWindowSize(430, 520, "FirstUseEver")
    local visible
    visible, configurationOpen = imgui.Begin("Mag Feed Alert - Configuration", configurationOpen)
    if visible then
        local changed, enabled = imgui.Checkbox("Enable Mag Feed Alert", options.enable)
        if changed then options.enable = enabled; mark_dirty() end

        local pChanged, p = imgui.Combo("Profile", options.profile, PROFILE_NAMES, #PROFILE_NAMES)
        if pChanged then set_profile(p) end

        imgui.Text("Cooldown display: Feed Mag x:xx")
        imgui.Text("Ready display: FEED MAG")

        imgui.Dummy(1, 6)
        render_status(now)

        imgui.Dummy(1, 6)
        imgui.Text("Preview")
        imgui.Separator()
        if imgui.Button("Preview Cooldown") then
            previewMode = "cooldown"
            previewStarted = now
            previewUntil = now + 5000
        end
        imgui.SameLine(0, 6)
        if imgui.Button("Preview Ready") then
            previewMode = "ready"
            previewStarted = now
            previewUntil = now + 5000
            tracker.pulseStarted = now
        end
        if previewMode ~= nil then
            imgui.SameLine(0, 6)
            if imgui.Button("Stop Preview") then
                previewMode = nil
            end
        end

        imgui.Dummy(1, 6)
        imgui.Text("HUD Position")
        imgui.Separator()
        imgui.Text("Factory position: top-right, below the native minimap.")
        if options.hudLocked then
            if imgui.Button("Unlock Layout") then
                options.hudLocked = false
                options.useFactoryPlacement = false
                layout.freeX, layout.freeY = nil, nil
                mark_dirty()
            end
        else
            if imgui.Button("Lock Layout") then
                finish_layout_lock()
            end
            imgui.SameLine(0, 6)
            imgui.Text("Drag the Feed Mag HUD with the mouse.")
        end
        if imgui.Button("Reset HUD Position") then
            options.useFactoryPlacement = true
            options.hudAnchor = 7
            options.hudX = -20
            local _, rh = get_resolution()
            options.hudY = factory_y(rh)
            options.hudLocked = true
            layout.freeX, layout.freeY = nil, nil
            mark_dirty()
        end

        imgui.Dummy(1, 6)
        render_custom_settings()

        if imgui.CollapsingHeader("Diagnostics") then
            imgui.Text("Tracking source: live carried-Mag timer data")
            imgui.Text(string.format("Scan interval: %d ms", options.scanIntervalMs))
            imgui.Text(string.format("Raw min timer: %.3f", tracker.rawMin or 0))
            imgui.Text(string.format("Raw max timer: %.3f", tracker.rawMax or 0))
            imgui.Text("No independent 3:30 stopwatch is used.")
            imgui.Text("Addon code can be reloaded from the standard Main > Reload button.")
        end
    end
    imgui.End()
end

local function present()
    local now = pso.get_tick_count()

    if firstPresent then
        firstPresent = false
        if options.firstRun then
            configurationOpen = true
            options.firstRun = false
            mark_dirty()
        end
    end

    scan_mags(now)
    render_configuration(now)

    if options.enable then
        local hasState, stateReady, remaining, readySince = current_visual_state(now)
        if hasState then
            local preset = effective_preset(options.profile)
            render_hud(now, stateReady, remaining, readySince, preset)
            if stateReady then
                render_center_ready(now, preset)
                render_screen_border(now, preset)
            end
        end
    end

    if optionsDirty then
        SaveOptions()
        optionsDirty = false
    end
end

local function init()
    if core_ok and core_mainmenu then
        core_mainmenu.add_button(ADDON_NAME, function()
            configurationOpen = not configurationOpen
        end)
    else
        configurationOpen = true
    end

    return {
        name = ADDON_NAME,
        version = ADDON_VERSION,
        author = "AnlionGamer",
        description = "Live Mag feeding countdown and ready alerts for Ephinea PSOBB.",
        present = present,
    }
end

return {
    __addon = {
        init = init
    }
}
