-- Sun & Moon Minimap
-- Version 1.0.9

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

    if frame:GetParent() ~= Minimap then
        frame:SetParent(Minimap)
    end

    local w = Minimap:GetWidth() or 198
    local h = Minimap:GetHeight() or 198
    local scale = math.max(1, math.min(w, h) / 198)

    local radius = (DB.radius or DEFAULTS.radius) * scale
    local hourVal = GetDisplayTime()
    local angle = 0

    if DB.horizonMode then
        local baseAngle = ((hourVal - 12) / 24) * (2 * math.pi)
        local correction = 0
        local sinVal = math.sin(baseAngle)
        local cosVal = math.cos(baseAngle)
        
        if cosVal > 0 then
            correction = 0.20 * sinVal * cosVal
        else
            correction = -0.00 * sinVal * cosVal
        end
        angle = baseAngle + correction
    else
        local clockHour = hourVal % 12
        angle = (clockHour / 12) * (2 * math.pi)
    end

    angle = angle + math.rad(DB.offset or 0)

    local x = math.sin(angle) * radius
    local y = math.cos(angle) * radius

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", Minimap, "CENTER", x, y)
    frame:SetScale(scale * ((DB.size or DEFAULTS.size) / 42))
    
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 1)
    
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

    frame = CreateFrame("Frame", "SMM_IndicatorFrame", Minimap)
    frame:SetSize(DEFAULTS.size, DEFAULTS.size)
    frame:EnableMouse(true)
    
    frame:SetHitRectInsets(4, 4, 4, 4) 

    -- Protections anti-conflit pour MinimapButtonBag (MBB)
    frame.ignore = true
    frame.ignoreMinimapButton = true
    frame.mbbIgnore = true
    frame.isMinimapButton = false

    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 1)

    rim = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    rim:SetAllPoints()
    rim:SetAtlas("UI-HUD-Minimap-Frame-Cycle", true)

    disc = frame:CreateTexture(nil, "OVERLAY", nil, 1)
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

    frame:SetScript("OnMouseUp", function(_, button)
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
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100SMM:|r " .. msg)
end

local function Command(msg)
    msg = (msg or ""):lower()

    if    msg == "on" then
        DB.enabled = true
        Apply()
        Print("> |cFF00FF00SMM|r enabled")
    elseif    msg == "off" then
            DB.enabled = false
            if frame then frame:Hide() end
            RestoreBlizzard()
            Print("> |cff00FFFFBlizzard|r's native indicator enabled")
	elseif	msg == "server/local" then
			Print("> |cffFF8C00Usage: '/smm server' or '/smm local'|r")
	elseif	msg == "clock/horizon" then
			Print("> |cffFF8C00Usage: '/smm clock' or '/smm horizon'|r")
    elseif  msg == "server" or msg == "serv" or msg == "server time" or msg == "serv time" then
            DB.serverTime = true
            UpdatePosition()
            Print("> Using |cFF00FF00Server|r time")
	elseif  msg == "local" or msg == "local time" then
            DB.serverTime = false
            UpdatePosition()
            Print("> Using |cffFFD100Local|r time")
    elseif  msg == "mode" then
        if  DB.horizonMode then
            DB.horizonMode = false
            UpdatePosition()
            Print("> |cFF00FF00Clock (12h)|r mode enabled (Bottom=06h/18h, Left=09h/21h, Top=12h/00h, Right=15h/03h).")
        else
            DB.horizonMode = true
            UpdatePosition()
            Print("> |cffFFD100Horizon (24h)|r mode enabled (Left=06h (sunrise), Top=12h, Right=18h (sunset), Bottom=00h).")
        end
    elseif  msg == "clock" or msg == "mode clock" then
        if  DB.horizonMode then
            DB.horizonMode = false
            UpdatePosition()
            Print("> |cFF00FF00Clock (12h)|r mode enabled (Bottom=06h/18h, Left=09h/21h, Top=12h/00h, Right=15h/03h).")
        else Print("> |cFF00FF00Clock (12h)|r mode already enabled (Bottom=06h/18h, Left=09h/21h, Top=12h/00h, Right=15h/03h).")
        end
    elseif  msg == "horizon" or msg == "mode horizon" then
        if  DB.horizonMode then
            Print("> |cffFFD100Horizon (24h)|r mode already enabled (Left=06h (sunrise), Top=12h, Right=18h (sunset), Bottom=00h).")
        else DB.horizonMode = true
             UpdatePosition()
             Print("> |cffFFD100Horizon (24h)|r mode enabled (Left=06h (sunrise), Top=12h, Right=18h (sunset), Bottom=00h).")
        end
    elseif  msg == "info" or msg == "status" then
            local modeStr = DB.horizonMode and "Horizon (24h)" or "Clock (12h)"
            local timeStr = DB.serverTime and "Server Time" or "Local Time"
            Print("|cffFFD100~ ☼ SMM INFO ☼ ~|r")
            local modeColorCode = "cffFFD100"
                if    modeStr == "Clock (12h)" then
                    modeColorCode = "cFF00FF00"
                elseif     modeStr == "Horizon (24h)" then
                    modeColorCode = "cffFFD100"
                end
            local timeColorCode = "cffFFD100"
                if    timeStr == "Server Time" then
                    timeColorCode = "cFF00FF00"
                elseif timeStr == "Local Time" then
                    timeColorCode = "cffFFD100"
                end    
            Print("Active mode: |" .. modeColorCode .. modeStr .. "|r")
            Print("Time source: |" .. timeColorCode .. timeStr .. "|r")
    elseif  msg == "custom" then
            Print("|cffFFD100~ ☼ SMM CUSTOM COMMANDS ☼ ~|r")
            Print("/smm custom radius |cFF00FF00104|r - Radius size (default: 104)")
            Print("/smm custom size |cFF00FF0042|r - Icon size (default: 42)")
            Print("/smm custom offset |cFF00FF000|r - Adjust icon position (default: 0)")
            Print("/smm custom info - Show current custom values")
            Print("/smm custom reset - Default custom settings")
    elseif  msg == "custom info" or msg == "custom status" or msg == "custom values" then
            Print("|cffFFD100~ ☼ SMM CUSTOM VALUES ☼ ~|r")
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
            Print("> |cffFF8C00Usage: '/smm custom radius 104'|r")
        end
    elseif msg:match("^custom%s+offset%s+") then
        local val = tonumber(msg:match("^custom%s+offset%s+([%-]?[%d%.]+)"))
        if    val then
            DB.offset = val
            UpdatePosition()
            Print("> Offset = " .. DB.offset .. " degrees")
        else
            Print("> |cffFF8C00Usage: '/smm custom offset 0'|r")
        end
    elseif    msg:match("^custom%s+size%s+") then
        local val = tonumber(msg:match("^custom%s+size%s+([%d%.]+)"))
        if    val then
            DB.size = math.max(20, math.min(80, val))
            UpdatePosition()
            Print("> Size (20-80) = " .. DB.size)
        else
            Print("> |cffFF8C00Usage: '/smm custom size 42'|r")
        end
    else
        Print("|cffFFD100~ ☼ SMM COMMANDS ☼ ~|r")
		Print("/smm clock/horizon - {|cFF00FF00Clock|r (12h)} (default) or {|cffFFD100Horizon|r (24h)}")
        Print("/smm server/local - |cFF00FF00Server|r time (default) or |cffFFD100Local|r time")
        Print("/smm info - Display current SMM settings")
        Print("/smm custom - Display custom commands")
        Print("/smm on/off - Toggle to |cffFFD100SMM|r or |cff00FFFFBlizzard|r icon")
    end
end

SLASH_SunMoonMinimap1 = "/smm"
SLASH_SunMoonMinimap2 = "/sunmoonminimap"
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