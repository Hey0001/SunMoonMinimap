-- Sun & Moon Minimap
-- Version 1.0.4

local ADDON_NAME = ...
local DB

local DEFAULTS = {
    radius = 104,          -- distance from Minimap center, in UI pixels
    size = 42,             -- native Forever day/night housing size
    offset = 0,            -- degrees; positive = clockwise
    hideBlizzard = true,
    enabled = true,
    serverTime = true,     -- false = local time, true = server time
    horizonMode = false,   -- false = Clock mode 12h (06h/18h=bottom, 12h/00h=top), true = Horizon mode 24 (6h=left, 12h=top, 18h=right, 0h=bottom)
}

local frame
local disc
local rim
local ticker

local function CopyDefaults()
    DB = SunMoonMinimapDB or {}
    SunMoonMinimapDB = DB

    for k, v in pairs(DEFAULTS) do
        if DB[k] == nil then
            DB[k] = v
        end
    end
end

local function GetDisplayTime()
    if DB and DB.serverTime and C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        local calTime = C_DateAndTime.GetCurrentCalendarTime()
        if calTime and calTime.hour then
            return calTime.hour + (calTime.minute / 60)
        end
    end

    local t = date("*t")
    return t.hour + (t.min / 60) + (t.sec / 3600)
end

local function IsLocalDay()
    local h = GetDisplayTime()
    return h >= 6 and h < 18
end

local function Paint()
    if not disc then return end

    if C_Texture and C_Texture.GetAtlasInfo then
        disc:SetAtlas(
            IsLocalDay() and "UI-HUD-Minimap-DayCycle"
                or "UI-HUD-Minimap-NightCycle",
            true
        )
    end
end

local function UpdatePosition()
    if not frame or not Minimap or not DB.enabled then return end

    local w = Minimap:GetWidth() or 198
    local h = Minimap:GetHeight() or 198
    local scale = math.max(1, math.min(w, h) / 198)

    local radius = (DB.radius or DEFAULTS.radius) * scale

    local hourVal = GetDisplayTime()
    local angle = 0

    if DB.horizonMode then
        -- 1. Basic linear calculation (0 to 2pi)
        local baseAngle = ((hourVal - 12) / 24) * (2 * math.pi)
        
        -- 2. Asymmetric non-linear correction for visual balance
        -- We differentiate the upper half (near 12h) and lower half (near 00h)
        local correction = 0
        local sinVal = math.sin(baseAngle)
        local cosVal = math.cos(baseAngle)
        
        -- If we are in the upper hemisphere (cosVal > 0, meaning between 18h and 06h via 12h)
        if cosVal > 0 then
            -- Push intermediate hours away from 12h by lowering the flanks (09h / 15h)
            local upperFactor = 0.50 -- Increase this value if 09h/15h feel too close to 12h
            correction = upperFactor * sinVal * cosVal
        else
            -- In the lower hemisphere (cosVal < 0, between 06h and 18h via 00h)
			local lowerFactor = -0.20 -- Decrease this value (higher in the negatives) to be closer to 00h
            correction = lowerFactor * sinVal * cosVal
        end
        
        angle = baseAngle + correction
    else
        -- Classic 12h Clock mode
        local clockHour = hourVal % 12
        angle = (clockHour / 12) * (2 * math.pi)
    end

    angle = angle + math.rad(DB.offset or 0)

    local x = math.sin(angle) * radius
    local y = math.cos(angle) * radius

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", Minimap, "CENTER", x, y)
    frame:SetScale(scale * ((DB.size or DEFAULTS.size) / 42))
    frame:Show()

    Paint()
end

local function RestoreBlizzard()
    local dFrame = _G.DielFrame or (_G.MinimapCluster and _G.MinimapCluster.DielFrame)
    if  dFrame then
        dFrame.Show = nil
        dFrame:SetAlpha(1)
        dFrame:EnableMouse(true)
        dFrame:Show()
    end

    if  _G.GameTimeFrame then
        _G.GameTimeFrame.Show = nil
        _G.GameTimeFrame:SetAlpha(1)
        _G.GameTimeFrame:EnableMouse(true)
        _G.GameTimeFrame:Show()
    end
end

local function HideBlizzard()
    if not DB.hideBlizzard or not DB.enabled then 
        RestoreBlizzard()
        return 
    end

    local dFrame = _G.DielFrame or (_G.MinimapCluster and _G.MinimapCluster.DielFrame)
    if  dFrame then
        dFrame:Hide()
        dFrame:UnregisterAllEvents()
        dFrame:EnableMouse(false)
        dFrame:SetAlpha(0)
        dFrame.Show = function() end

        if not dFrame._smm_Hooked then
            dFrame._smm_Hooked = true
            dFrame:HookScript("OnShow", function(self)
                if DB and DB.enabled and DB.hideBlizzard then
                    self:Hide()
                    self:SetAlpha(0)
                    self:EnableMouse(false)
                end
            end)
        end
    end

    if  _G.GameTimeFrame then
		_G.GameTimeFrame:Hide()
		_G.GameTimeFrame:UnregisterAllEvents()
		_G.GameTimeFrame:EnableMouse(false)
		_G.GameTimeFrame:SetAlpha(0)
		_G.GameTimeFrame.Show = function() end
    end
end

local function CreateIndicator()
    if frame or not Minimap then return end

    frame = CreateFrame("Button", "SunMoonMinimapFrame", Minimap)
    frame:SetSize(DEFAULTS.size, DEFAULTS.size)
    frame:EnableMouse(true)
    frame:SetFrameLevel(Minimap:GetFrameLevel() + 10)

    rim = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    rim:SetAllPoints()
    rim:SetAtlas("UI-HUD-Minimap-Frame-Cycle", true)

    disc = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    disc:SetPoint("CENTER")
    disc:SetSize(33, 33)

    frame:SetScript("OnEnter", function(self)
        local h = GetDisplayTime()
        local hour = math.floor(h)
        local minute = math.floor((h - hour) * 60)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(DB.serverTime and "Server Time" or "Local Time")
        GameTooltip:AddLine(string.format("%02d:%02d", hour, minute), 1, 1, 1)
        GameTooltip:AddLine(
            DB.serverTime and "Sun/Moon follows server time" or "Sun/Moon follows local time",
            0.7, 0.7, 0.7
        )
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame:SetScript("OnClick", function(_, button)
        if button == "LeftButton" and ToggleCalendar then
            ToggleCalendar()
        end
    end)
end

local function Apply()
    if not DB or not DB.enabled then
        if frame then frame:Hide() end
        RestoreBlizzard()
        return
    end

    HideBlizzard()
    CreateIndicator()
    UpdatePosition()
end

local function StartTicker()
    if ticker then ticker:Cancel() end

    ticker = C_Timer.NewTicker(1, function()
        if DB and DB.enabled then
            UpdatePosition()
            HideBlizzard()
        end
    end)
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100Sun Moon Minimap:|r " .. msg)
end

local function Command(msg)
    msg = (msg or ""):lower()

    if    msg == "on" then
        DB.enabled = true
        Apply()
        Print("> SMM enabled")
    elseif    msg == "off" then
            DB.enabled = false
            if frame then frame:Hide() end
            RestoreBlizzard()
            Print("> Blizzard's native indicator enabled")
    elseif  msg == "server" or msg == "serv" or msg == "server time" or msg == "serv time" then
			DB.serverTime = true
			UpdatePosition()
			Print("> Using server time")
    elseif  msg == "local" or msg == "local time" then
            DB.serverTime = false
            UpdatePosition()
            Print("> Using local time")
    elseif  msg == "mode" then
        if  DB.horizonMode then
			DB.horizonMode = false
            UpdatePosition()
            Print("> Clock (12h) mode enabled (Bottom=06h/18h, Left=09h/21h, Top=12h/00h, Right=15h/03h).")
        else
            DB.horizonMode = true
            UpdatePosition()
            Print("> Horizon (24h) mode enabled (Left=06h (sunrise), Top=12h, Right=18h (sunset), Bottom=00h).")
        end
    elseif  msg == "clock" then
        if  DB.horizonMode then
            DB.horizonMode = false
            UpdatePosition()
            Print("> Clock (12h) mode enabled (Bottom=06h/18h, Left=09h/21h, Top=12h/00h, Right=15h/03h).")
        else Print("> Clock (12h) mode already enabled (Bottom=06h/18h, Left=09h/21h, Top=12h/00h, Right=15h/03h).")
        end
    elseif  msg == "horizon" then
        if  DB.horizonMode then
            Print("> Horizon (24h) mode already enabled (Left=06h (sunrise), Top=12h, Right=18h (sunset), Bottom=00h).")
        else DB.horizonMode = true
             UpdatePosition()
             Print("> Horizon (24h) mode enabled (Left=06h (sunrise), Top=12h, Right=18h (sunset), Bottom=00h).")
        end
	elseif  msg == "info" or msg == "status" then
            local modeStr = DB.horizonMode and "Horizon (24h)" or "Clock (12h)"
            local timeStr = DB.serverTime and "Server Time" or "Local Time"
            Print("~ ☼ SMM INFO ☼ ~")
            Print("Active mode: " .. modeStr)
            Print("Time source: " .. timeStr)
    elseif  msg == "custom" then
            Print("~ ☼ SMM CUSTOM COMMANDS ☼ ~")
            Print("/smm custom radius 104 - radius size (default: 104)")
            Print("/smm custom size 42 - icon size (default: 42)")
            Print("/smm custom offset 0 - adjust icon position (default: 0)")
			Print("/smm custom info - show current custom values")
            Print("/smm custom reset - default custom settings")
	elseif  msg == "custom info" or msg == "custom status" or msg == "custom values" then
            Print("~ ☼ SMM CUSTOM VALUES ☼ ~")
            Print("Radius: " .. tostring(DB.radius))
            Print("Size (icon): " .. tostring(DB.size))
            Print("Offset: " .. tostring(DB.offset) .. " degrees")
    elseif  msg == "custom reset" or msg == "custom default" then
            DB.radius = DEFAULTS.radius
            DB.size = DEFAULTS.size
            DB.offset = DEFAULTS.offset
            Apply()
            Print("> SMM custom values reset to default")
    elseif    msg:match("^custom%s+radius%s+") then
        local n = tonumber(msg:match("^custom%s+radius%s+([%d%.]+)"))
        if    n then
            DB.radius = math.max(50, math.min(180, n))
            UpdatePosition()
            Print("> Radius (50-180) = " .. DB.radius)
        else
            Print("> Usage: /smm custom radius 104")
        end
    elseif msg:match("^custom%s+offset%s+") then
        local val = tonumber(msg:match("^custom%s+offset%s+([%-]?[%d%.]+)"))
        if    val then
            DB.offset = val
            UpdatePosition()
            Print("> Offset = " .. DB.offset .. " degrees")
        else
            Print("> Usage: /smm custom offset 0")
        end
    elseif    msg:match("^custom%s+size%s+") then
        local val = tonumber(msg:match("^custom%s+size%s+([%d%.]+)"))
        if    val then
            DB.size = math.max(20, math.min(80, val))
            UpdatePosition()
            Print("> Size (20-80) = " .. DB.size)
        else
            Print("> Usage: /smm custom size 42")
        end
    else
        Print("~ ☼ SMM COMMANDS ☼ ~")
        Print("/smm server - server time (default)")
        Print("/smm local - local time")
        Print("/smm mode - {Clock (12h)} (default) | {Horizon (24h)}")
		Print("/smm info - display current SMM settings")
        Print("/smm custom - display custom commands")
        Print("/smm on/off - activate/desactivate SMM")  
    end
end

SLASH_SunMoonMinimap1 = "/smm"
SlashCmdList.SunMoonMinimap = Command

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" then
        if addon == ADDON_NAME then
            CopyDefaults()
        end
    elseif event == "PLAYER_LOGIN" then
        if not DB then CopyDefaults() end

        C_Timer.After(0.5, function()
            Apply()
            StartTicker()
        end)

        self:UnregisterAllEvents()
    end
end)