-- Sun & Moon Minimap
-- Version 1.0.3

local ADDON_NAME = ...
local DB

local DEFAULTS = {
    radius = 104,         -- distance from Minimap center, in UI pixels
    size = 42,            -- native Forever day/night housing size
    offset = 0,           -- degrees; positive = clockwise
    hideBlizzard = true,
    enabled = true,
    serverTime = true,    -- false = local time, true = server time
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

    local clockHour = GetDisplayTime() % 12
    local angle = (clockHour / 12) * (2 * math.pi)
    angle = angle + math.rad(DB.offset or 0)

    local x = math.sin(angle) * radius
    local y = math.cos(angle) * radius

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", Minimap, "CENTER", x, y)
    frame:SetScale(scale * ((DB.size or DEFAULTS.size) / 42))
    frame:Show()

    Paint()
end

local function HideBlizzard()
    if not DB.hideBlizzard then return end

    local dFrame = _G.DielFrame or (_G.MinimapCluster and _G.MinimapCluster.DielFrame)
    if dFrame then
        dFrame:Hide()
        dFrame:UnregisterAllEvents()
        dFrame:EnableMouse(false)
        dFrame:SetAlpha(0)
        dFrame.Show = function() end

        if not dFrame._smm_Hooked then
            dFrame._smm_Hooked = true
            dFrame:HookScript("OnShow", function(self)
                if DB and DB.hideBlizzard then
                    self:Hide()
                    self:SetAlpha(0)
                    self:EnableMouse(false)
                end
            end)
        end
    end

    if _G.GameTimeFrame then
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

    if msg == "on" then
        DB.enabled = true
        Apply()
        Print("enabled.")
    elseif msg == "off" then
        DB.enabled = false
        if frame then frame:Hide() end
        Print("disabled. Reload the UI to restore Blizzard's indicator.")
    elseif msg == "server" or msg == "servertime" then
        DB.serverTime = not DB.serverTime
        UpdatePosition()
        Print(DB.serverTime and "using server time." or "using local time.")
    elseif msg == "local" then
        DB.serverTime = false
        UpdatePosition()
        Print("using local time.")
    elseif msg == "server on" then
        DB.serverTime = true
        UpdatePosition()
        Print("using server time.")
    elseif msg == "server off" then
        DB.serverTime = false
        UpdatePosition()
        Print("using local time.")
    elseif msg == "reset" then
        DB.radius = DEFAULTS.radius
        DB.size = DEFAULTS.size
        DB.offset = DEFAULTS.offset
        Apply()
        Print("position reset.")
    elseif msg:match("^radius%s+") then
        local n = tonumber(msg:match("^radius%s+([%d%.]+)"))
        if n then
            DB.radius = math.max(50, math.min(180, n))
            UpdatePosition()
            Print("radius = " .. DB.radius)
        else
            Print("usage: /smm radius 104")
        end
    elseif msg:match("^offset%s+") then
        local n = tonumber(msg:match("^offset%s+([%-]?[%d%.]+)"))
        if n then
            DB.offset = n
            UpdatePosition()
            Print("offset = " .. DB.offset .. " degrees")
        else
            Print("usage: /smm offset 0")
        end
    elseif msg:match("^size%s+") then
        local val = tonumber(msg:match("^size%s+([%d%.]+)"))
        if val then
            DB.size = math.max(20, math.min(80, val))
            UpdatePosition()
            Print("size = " .. DB.size)
        else
            Print("usage: /smm size 42")
        end
    else
        Print("commands:")
        Print("/smm on | off")
        Print("/smm server  - toggle local/server time")
        Print("/smm local   - use local time")
        Print("/smm radius 104")
        Print("/smm size 42")
        Print("/smm offset 0")
        Print("/smm reset")
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
            HideBlizzard()
            Apply()
            StartTicker()
        end)

        self:UnregisterAllEvents()
    end
end)