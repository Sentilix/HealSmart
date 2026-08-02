-- ==========================================
-- HeroStats - UI & Constants (v0.5.0) - PART 1
-- ==========================================

HEROSTATS_BAR_HEIGHT = 16
HEROSTATS_BAR_GAP = 2
HEROSTATS_HEADER_HEIGHT = 20
HEROSTATS_OUT_OF_COMBAT_GRACE = 5
HEROSTATS_MANA_THRESHOLD = 300 

HEROSTATS_MIN_WIDTH = 150
HEROSTATS_MIN_HEIGHT = 110 

local uiBars = {}

-- 1. Create the Main Window Frame (Container)
local container = CreateFrame("Frame", "HeroStatsContainer", UIParent)
container:SetClampedToScreen(true)
container:SetResizable(true)

if container.SetResizeBounds then
    container:SetResizeBounds(HEROSTATS_MIN_WIDTH, HEROSTATS_MIN_HEIGHT, 1000, 1000)
end

-- Draggable logic without Shift requirement
container:SetMovable(true)
container:EnableMouse(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", function(self) 
    if HeroStatsSettings and not HeroStatsSettings.locked then self:StartMoving() end 
end)
container:SetScript("OnDragStop", function(self) 
    self:StopMovingOrSizing()
    if HeroStatsSettings then
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        HeroStatsSettings.point = point
        HeroStatsSettings.relativePoint = relativePoint
        HeroStatsSettings.xOfs = xOfs
        HeroStatsSettings.yOfs = yOfs
    end
end)

local bgTexture = container:CreateTexture(nil, "BACKGROUND", nil, -8)
bgTexture:SetAllPoints(container)
bgTexture:SetColorTexture(0, 0, 0, 0.4)

-- ==========================================
-- HeroStats - UI (v0.6.0) - PART 2 (Unified Header Framework)
-- ==========================================

-- 2. Create the Header Bar (KEPT INTACT!)
local header = CreateFrame("Frame", nil, container)
header:SetHeight(HEROSTATS_HEADER_HEIGHT)
header:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
header:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)

local headerBg = header:CreateTexture(nil, "BACKGROUND")
headerBg:SetAllPoints(header)
headerBg:SetColorTexture(0.05, 0.15, 0.3, 1.0)

local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
headerText:SetPoint("LEFT", header, "LEFT", 6, 0)
headerText:SetTextColor(1, 1, 1, 1) 

-- Configuration & Dictionaries
local isCurrentlyClassFiltered = false
local CLASS_ICON_MAP = {
    ["DEFAULT"]  = "Interface\\Icons\\INV_Misc_QuestionMark",
    ["ALL"]      = "Interface\\Icons\\inv_ore_arcanite_01",
    ["PRIEST"]   = "Interface\\Icons\\Spell_Holy_WordFortitude",
    ["SHAMAN"]   = "Interface\\Icons\\Spell_Nature_LightningShield",
    ["PALADIN"]  = "Interface\\Icons\\Spell_Holy_HolyDevotionAura",
    ["DRUID"]    = "Interface\\Icons\\Spell_Nature_Regeneration"
}

-- Forward declaration of layout objects to make functions globally secure inside this scope
local filterButton, lockButton, nextButton, prevButton, sessionButton

-- Visual Synchronization Engines
function HeroStats_UpdateLockVisuals(isLocked)
    if not lockButton then return end
    local normalTex = lockButton:GetNormalTexture()
    if isLocked then
        if normalTex then normalTex:SetVertexColor(1.0, 0.82, 0.0, 1.0) end -- Gold for LOCKED
        if resizeButton then resizeButton:Hide() end
    else
        if normalTex then normalTex:SetVertexColor(0.6, 0.3, 0.0, 1.0) end -- Rust-Orange for UNLOCKED
        if resizeButton then resizeButton:Show() end
    end
end

function HeroStats_UpdateFilterVisuals(isFiltered)
    if not filterButton then return end
    isCurrentlyClassFiltered = isFiltered
    
    if isCurrentlyClassFiltered then
        local playerClassFilename = string.upper(UnitClass("player"))
        local classIcon = CLASS_ICON_MAP[playerClassFilename]       
        if not classIcon then classIcon = CLASS_ICON_MAP["DEFAULT"] end
        filterButton:SetNormalTexture(classIcon)
    else
        filterButton:SetNormalTexture(CLASS_ICON_MAP["ALL"])
    end

    if filterButton:GetNormalTexture() then
        filterButton:GetNormalTexture():SetAllPoints(filterButton)
    end
end

-- Button Object Spawning & Anchoring

-- Close Button [X]
local closeButton = CreateFrame("Button", nil, header, "UIPanelCloseButton")
closeButton:SetSize(16, 16)
closeButton:SetPoint("RIGHT", header, "RIGHT", -2, 0)
closeButton:SetScript("OnClick", function() if HeroStats_HideMainWindow then HeroStats_HideMainWindow() end end)
closeButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText("Hide frame (use /hs to show again)", 1, 1, 1, 1, true)
    GameTooltip:Show()
end)
closeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Filter Toggle Button (10x10) - UPGRADED TO TRI-STATE (v0.10.0)
filterButton = CreateFrame("Button", nil, header)
filterButton:SetSize(10, 10)
filterButton:SetPoint("RIGHT", closeButton, "LEFT", -2, -1)

local _, playerClass = UnitClass("player")
local currentSavedState = HeroStatsSettings and HeroStatsSettings.activeFilterState or 1
if currentSavedState == 1 then
    filterButton:SetNormalTexture("Interface\\Icons\\inv_ore_arcanite_01")
elseif currentSavedState == 2 then
    filterButton:SetNormalTexture("Interface\\Icons\\spell_holy_healingaura")
elseif currentSavedState == 3 then
    filterButton:SetNormalTexture("Interface\\Icons\\ClassIcon_" .. (playerClass or "Priest"))
end
if filterButton:GetNormalTexture() then filterButton:GetNormalTexture():SetAllPoints(filterButton) end

filterButton:SetScript("OnClick", function(self)
    if HeroStatsSettings then
        local currentState = HeroStatsSettings.activeFilterState or 1
        local nextState = currentState + 1
        if nextState > 3 then nextState = 1 end
        
        HeroStatsSettings.activeFilterState = nextState
        
        if nextState == 1 then
            self:SetNormalTexture("Interface\\Icons\\inv_ore_arcanite_01")
        elseif nextState == 2 then
            self:SetNormalTexture("Interface\\Icons\\spell_holy_healingaura")
        elseif nextState == 3 then
            self:SetNormalTexture("Interface\\Icons\\ClassIcon_" .. (playerClass or "Priest"))
        end
        if self:GetNormalTexture() then self:GetNormalTexture():SetAllPoints(self) end
        
        if coreFrame and coreFrame.RefreshStats then coreFrame.RefreshStats() end
    end
end)

-- FIXED v0.10.0: Ultra-clean Tri-State click sequence sync
filterButton:SetScript("OnClick", function(self)
    if HeroStatsSettings then
        local currentState = HeroStatsSettings.activeFilterState or 1
        local nextState = currentState + 1
        if nextState > 3 then nextState = 1 end
        
        HeroStatsSettings.activeFilterState = nextState
        
        if nextState == 1 then
            self:SetNormalTexture("Interface\\Icons\\inv_ore_arcanite_01")
        elseif nextState == 2 then
            self:SetNormalTexture("Interface\\Icons\\spell_holy_healingaura")
        elseif nextState == 3 then
            self:SetNormalTexture("Interface\\Icons\\ClassIcon_" .. (playerClass or "Priest"))
        end
        if self:GetNormalTexture() then self:GetNormalTexture():SetAllPoints(self) end
        
        if filterButton:GetNormalTexture() then filterButton:GetNormalTexture():SetAllPoints(filterButton) end
        
        if HeroStats_GetCoreFrame then
            local frame = HeroStats_GetCoreFrame()
            if frame and frame.RefreshStats then
                frame.RefreshStats()
            end
        end
    end
end)

-- Filter Button Mouse Hover Instructions - UPGRADED TO TRI-STATE (v0.10.0)
filterButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:ClearLines()
    
    local state = HeroStatsSettings and HeroStatsSettings.activeFilterState or 1
    local stateNames = {
        [1] = "None (Show All)",
        [2] = "Healers Only",
        [3] = "Your Class Only"
    }
    
    GameTooltip:AddLine("Filter View Mode", 1, 1, 1)
    GameTooltip:AddDoubleLine("Current Filter:", stateNames[state] or "None (Show All)", 0.8, 0.8, 0.8, 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to cycle filter: None -> Healers -> Your Class", 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
end)

filterButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Graphical Next Page Button (14x14)
nextButton = CreateFrame("Button", nil, header)
nextButton:SetSize(14, 14)
nextButton:SetPoint("RIGHT", filterButton, "LEFT", -2, 0)
nextButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
nextButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
nextButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText("Next page", 1, 1, 1, 1, true)
    GameTooltip:Show()
end)
nextButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Graphical Previous Page Button (14x14)
prevButton = CreateFrame("Button", nil, header)
prevButton:SetSize(14, 14)
prevButton:SetPoint("RIGHT", nextButton, "LEFT", -2, 0)
prevButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
prevButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
prevButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText("Previous page", 1, 1, 1, 1, true)
    GameTooltip:Show()
end)
prevButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Graphical Master Reset Button (14x14)
resetButton = CreateFrame("Button", nil, header)
resetButton:SetSize(14, 14)
resetButton:SetPoint("RIGHT", prevButton, "LEFT", -2, 0)
resetButton:SetNormalTexture("Interface\\Buttons\\UI-RotationLeft-Button-Up")
if resetButton:GetNormalTexture() then
    resetButton:GetNormalTexture():SetAllPoints(resetButton)
    resetButton:GetNormalTexture():SetVertexColor(1.0, 0.82, 0.0, 1.0)
end
resetButton:SetScript("OnClick", function()
    if HeroStats_TriggerResetDialog then HeroStats_TriggerResetDialog() end
end)
resetButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText("Reset All Data & Clear History", 1, 1, 1, 1, true)
    GameTooltip:Show()
end)
resetButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local shoutButton = CreateFrame("Button", nil, header)
shoutButton:SetSize(10, 10)
shoutButton:SetPoint("RIGHT", resetButton, "LEFT", -4, 0) -- Fixed to 0y for straight alignment
shoutButton:SetNormalTexture("Interface\\Icons\\ui_chat")

if shoutButton:GetNormalTexture() then
    shoutButton:GetNormalTexture():SetAllPoints(shoutButton)
end

shoutButton:SetScript("OnClick", function()
    if HeroStats_ReportCurrentPageToChat then
        HeroStats_ReportCurrentPageToChat()
    end
end)

shoutButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    
    -- Local lookup dictionary for translation mapping
    local channelNames = {
        [1] = "/Raid or /Party",
        [2] = "/say",
        [3] = "/yell",
        [4] = "/guild",
        [5] = "Custom Channel"
    }
    
    -- Fetch the active limits and channel paths from the settings database safely
    local currentLines = HeroStatsSettings and HeroStatsSettings.reportLinesLimit or 5
    local currentMode = HeroStatsSettings and HeroStatsSettings.reportChannelMode or 1
    local channelText = channelNames[currentMode] or "Raid / Party"
    
    -- Append the channel number to the string if the selection is set to custom channel
    if currentMode == 5 and HeroStatsSettings and HeroStatsSettings.reportCustomChannelNum then
        channelText = "Channel " .. HeroStatsSettings.reportCustomChannelNum
    end
    
    -- Compile and show the dynamic live tooltip message screen
    local dynamicTooltipText = string.format("Report Top %d to %s", currentLines, channelText)
    GameTooltip:SetText(dynamicTooltipText, 1, 1, 1, 1, true)
    GameTooltip:Show()
end)

shoutButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Graphical History/Session Button (10x10 - FIXED ANCHOR: Tied to the left of the new 10x10 shoutButton)
sessionButton = CreateFrame("Button", nil, header)
sessionButton:SetSize(10, 10)
sessionButton:SetPoint("RIGHT", shoutButton, "LEFT", -4, 0) -- Back to 0y as it flushes with another square
sessionButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Note_03")
if sessionButton:GetNormalTexture() then sessionButton:GetNormalTexture():SetAllPoints(sessionButton) end
sessionButton:SetScript("OnClick", function()
    if HeroStats_ToggleSessionWindow then HeroStats_ToggleSessionWindow() end
end)
sessionButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText("View Saved Fight Sessions", 1, 1, 1, 1, true)
    GameTooltip:Show()
end)
sessionButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Lock Toggle Button (12x12 - FIXED ANCHOR: Tied to the left of sessionButton)
lockButton = CreateFrame("Button", nil, header)
lockButton:SetSize(12, 12)
lockButton:SetPoint("RIGHT", sessionButton, "LEFT", -4, 0)
lockButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
if lockButton:GetNormalTexture() then lockButton:GetNormalTexture():SetAllPoints(lockButton) end
lockButton:SetScript("OnClick", function()
    if HeroStatsSettings then
        HeroStatsSettings.locked = not HeroStatsSettings.locked
        HeroStats_UpdateLockVisuals(HeroStatsSettings.locked)
    end
end)
lockButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText("Lock or Unlock Frame", 1, 1, 1, 1, true)
    GameTooltip:Show()
end)
lockButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- NEW DYNAMIC COLOR ENGINE: Tint the standard texture dynamically via VertexColor
function HeroStats_UpdateLockVisuals(isLocked)
    local normalTex = lockButton:GetNormalTexture()
    
    if isLocked then
        if normalTex then 
            normalTex:SetVertexColor(1.0, 0.82, 0.0, 1.0) -- Gold/Yellow for LOCKED
        end
        if resizeButton then resizeButton:Hide() end
    else
        if normalTex then 
            normalTex:SetVertexColor(0.6, 0.3, 0.0, 1.0) -- Green for UNLOCKED
        end
        if resizeButton then resizeButton:Show() end
    end
end

function HeroStats_UpdateFilterVisuals(isFiltered)
    isCurrentlyClassFiltered = isFiltered
    
    if isCurrentlyClassFiltered then
        local playerClassFilename = string.upper(UnitClass("player"))
        local classIcon = CLASS_ICON_MAP[playerClassFilename]       
        if not classIcon then classIcon = CLASS_ICON_MAP["DEFAULT"] end
        
        filterButton:SetNormalTexture(classIcon)
    else
        filterButton:SetNormalTexture(CLASS_ICON_MAP["ALL"])
    end

    -- NEW LAYOUT LOCK: Force the textures to stretch and anchor perfectly to the new 12x12 frame dimensions
    if filterButton:GetNormalTexture() then
        filterButton:GetNormalTexture():SetAllPoints(filterButton)
    end
end

-- ==========================================
-- HeroStats - UI (v0.5.0) - PART 3
-- ==========================================

-- 3. Create the Scrollable Area
local scrollFrame = CreateFrame("ScrollFrame", "HeroStatsScrollFrame", container, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -20, 2) 

if HeroStatsScrollFrameScrollBar then
    local sb = HeroStatsScrollFrameScrollBar
    sb:ClearAllPoints()
    -- FIXED ANCHOR: Stays on the absolute window edge, but drops 22 pixels down to clear the icons
    sb:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -37)
    sb:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 20)
    if HeroStatsScrollFrameScrollBarScrollUpButton then HeroStatsScrollFrameScrollBarScrollUpButton:Hide() end
    if HeroStatsScrollFrameScrollBarScrollDownButton then HeroStatsScrollFrameScrollBarScrollDownButton:Hide() end
end

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollFrame:SetScrollChild(scrollChild)

local infoText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
infoText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 6, -10)
infoText:SetWidth(170)
infoText:SetJustifyH("LEFT")
infoText:SetText("")

resizeButton = CreateFrame("Button", nil, container)
resizeButton:SetSize(16, 16)
resizeButton:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 2)
resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeButton:SetFrameLevel(scrollFrame:GetFrameLevel() + 5)

resizeButton:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then container:StartSizing("BOTTOMRIGHT") end
end)
resizeButton:SetScript("OnMouseUp", function(self, button)
    container:StopMovingOrSizing()
    local targetWidth = container:GetWidth() - 22
    scrollChild:SetWidth(targetWidth)
    infoText:SetWidth(targetWidth - 10)
    if HeroStatsSettings then
        HeroStatsSettings.width = container:GetWidth()
        HeroStatsSettings.height = container:GetHeight()
    end
    for _, bar in ipairs(uiBars) do
        bar:SetWidth(targetWidth)
        if bar.UpdateBorders then bar:UpdateBorders(targetWidth) end
    end
end)

-- ==========================================
-- HeroStats - UI (v0.5.0) - PART 4
-- ==========================================

local function CreateHealerBar(index)
    local currentBarWidth = container:GetWidth() - 22
    local bar = CreateFrame("Frame", nil, scrollChild)
    bar:SetSize(currentBarWidth, HEROSTATS_BAR_HEIGHT)
    
    if index == 1 then
        bar:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 1, 0)
    else
        bar:SetPoint("TOPLEFT", uiBars[index - 1], "BOTTOMLEFT", 0, -HEROSTATS_BAR_GAP)
    end

    local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.6)

    local function UpdateBarBorders(parentFrame, width)
        if parentFrame.topLine then parentFrame.topLine:SetSize(width, 1) end
        if parentFrame.bottomLine then parentFrame.bottomLine:SetSize(width, 1) end
    end

    bar.topLine = bar:CreateTexture(nil, "OVERLAY")
    bar.topLine:SetColorTexture(0, 0, 0, 0.9)
    bar.topLine:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.topLine:SetSize(currentBarWidth, 1)

    bar.bottomLine = bar:CreateTexture(nil, "OVERLAY")
    bar.bottomLine:SetColorTexture(0, 0, 0, 0.9)
    bar.bottomLine:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bar.bottomLine:SetSize(currentBarWidth, 1)

    local leftLine = bar:CreateTexture(nil, "OVERLAY")
    leftLine:SetColorTexture(0, 0, 0, 0.9)
    leftLine:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    leftLine:SetSize(1, HEROSTATS_BAR_HEIGHT)

    local rightLine = bar:CreateTexture(nil, "OVERLAY")
    rightLine:SetColorTexture(0, 0, 0, 0.9)
    rightLine:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    rightLine:SetSize(1, HEROSTATS_BAR_HEIGHT)

    local statusBar = CreateFrame("StatusBar", nil, bar)
    statusBar:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    statusBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    statusBar:SetMinMaxValues(0, 100)

    local textOverlay = CreateFrame("Frame", nil, bar)
    textOverlay:SetAllPoints(bar)
    textOverlay:SetFrameLevel(statusBar:GetFrameLevel() + 5)

    local leftText = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    leftText:SetPoint("LEFT", textOverlay, "LEFT", 4, 0)
    leftText:SetJustifyH("LEFT")

    local rightText = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rightText:SetPoint("RIGHT", textOverlay, "RIGHT", -4, 0)
    rightText:SetJustifyH("RIGHT")

    bar.statusBar = statusBar
    bar.leftText = leftText
    bar.rightText = rightText
    bar.UpdateBorders = UpdateBarBorders

    uiBars[index] = bar
    return bar
end

function HeroStats_RenderRaidBars(sortedData, maxVal, viewType, totalRaidEffective, viewTitle)
    maxVal = tonumber(maxVal) or 0
    infoText:SetText("")

    for _, bar in ipairs(uiBars) do bar:Hide() end

    local totalHeight = #sortedData * (HEROSTATS_BAR_HEIGHT + HEROSTATS_BAR_GAP)
    scrollChild:SetHeight(totalHeight)
    local targetWidth = container:GetWidth() - 22

    local function FormatDotNumber(numValue)
        if numValue < 1000 then return tostring(numValue) end
        local strValue = tostring(numValue)
        local formatted = strValue
        while true do
            local newFormatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
            if k == 0 then break end
            formatted = newFormatted
        end
        return formatted
    end

    for i, data in ipairs(sortedData) do
        local bar = uiBars[i] or CreateHealerBar(i)
        bar:SetWidth(targetWidth)
        if bar.UpdateBorders then bar:UpdateBorders(targetWidth) end

        local color = RAID_CLASS_COLORS[data.class] or {r = 0.5, g = 0.5, b = 0.5}
        bar.statusBar:SetStatusBarColor(color.r, color.g, color.b, 1.0)
        
        -- FIXED v0.8.0: Token names changed from old short versions to your new full matrix tokens
        local fillValue = 0

        if viewType == "HEALING" then
            fillValue = (maxVal > 0) and ((data.effective / maxVal) * 100) or 0
        elseif viewType == "OVERHEALING" then
            fillValue = data.percent or 0
        elseif viewType == "MANA_EFF" then
            fillValue = (maxVal > 0) and ((data.hpm / maxVal) * 100) or 0            
        elseif viewType == "MANA_GAINED" then
            fillValue = (maxVal > 0) and ((data.manaGained / maxVal) * 100) or 0
        elseif viewType == "DAMAGE_DONE" then
            fillValue = (maxVal > 0) and ((data.damageDone / maxVal) * 100) or 0
        elseif viewType == "DAMAGE_TAKEN" then
            fillValue = (maxVal > 0) and ((data.damageTaken / maxVal) * 100) or 0
        elseif viewType == "DISPELS" then
            fillValue = (maxVal > 0) and ((data.dispels / maxVal) * 100) or 0
        elseif viewType == "BUFFS" then
            fillValue = (maxVal > 0) and ((data.buffs / maxVal) * 100) or 0
        elseif viewType == "DEATHS" then
            fillValue = (maxVal > 0) and ((data.deaths / maxVal) * 100) or 0
        elseif viewType == "RESURRECTS" then
            fillValue = (maxVal > 0) and ((data.resurrects / maxVal) * 100) or 0
        end
        
        bar.statusBar:SetValue(fillValue)
        bar.leftText:SetText(string.format("%d. %s", i, data.name))
        
        -- FIXED v0.9.0: Always relies on the calibrated historical session time or active duration
        local fightSeconds = HeroStats_CurrentFightDuration_RenderOverride or HeroStats_CurrentFightDuration or 1
        if fightSeconds < 1 then fightSeconds = 1 end

        -- FIXED v0.8.0: Cleanly relies on your incoming argument token, destroying the legacy array dependency!
        headerText:SetText(viewTitle or "HeroStats")

        -- FIXED v0.8.0: Text tokens are now 100% synchronized with your core sorted views!
        if viewType == "HEALING" then
            local currentTotalRaid = totalRaidEffective or 1
            if currentTotalRaid == 0 then currentTotalRaid = 1 end
            local raidSharePercent = (data.effective / currentTotalRaid) * 100
            local formattedAmt = FormatDotNumber and FormatDotNumber(data.effective) or data.effective
            local hps = data.effective / fightSeconds
            bar.rightText:SetText(string.format("%s (%.0f HPS) - %.1f%%", formattedAmt, hps, raidSharePercent))
            
        elseif viewType == "HEAL_CRIT" then
            -- FIXED v0.10.0: Render healing crit percentages cleanly on the primary layout bars
            bar.rightText:SetText(string.format("%.1f%% Crit Share", data.healCritPct or 0))

        elseif viewType == "OVERHEALING" then
            bar.rightText:SetText(string.format("%.1f%% Efficiency", data.percent or 0))
            
        elseif viewType == "MANA_EFF" then
            bar.rightText:SetText(string.format("%.1f HPM", data.hpm or 0))
            
        elseif viewType == "MANA_GAINED" then
            local formattedAmt = FormatDotNumber and FormatDotNumber(data.manaGained) or data.manaGained
            bar.rightText:SetText(string.format("%s mana", formattedAmt))
            
        elseif viewType == "DAMAGE_DONE" then
            local formattedAmt = FormatDotNumber and FormatDotNumber(data.damageDone) or data.damageDone
            local dps = data.damageDone / fightSeconds
            bar.rightText:SetText(string.format("%s (%.0f DPS)", formattedAmt, dps))
            
        elseif viewType == "DMG_CRIT" then
            -- FIXED v0.10.0: Render damage crit percentages cleanly on the primary layout bars
            bar.rightText:SetText(string.format("%.1f%% Crit Share", data.dmgCritPct or 0))

        elseif viewType == "DAMAGE_TAKEN" then
            local formattedAmt = FormatDotNumber and FormatDotNumber(data.damageTaken) or data.damageTaken
            local dtps = data.damageTaken / fightSeconds
            bar.rightText:SetText(string.format("%s (%.0f DTPS)", formattedAmt, dtps))
            
        elseif viewType == "DISPELS" then
            bar.rightText:SetText(string.format("%d Dispels", data.dispels or 0))
            
        elseif viewType == "BUFFS" then
            bar.rightText:SetText(string.format("%d Buffs", data.buffs or 0))
            
        elseif viewType == "DEATHS" then
            bar.rightText:SetText(string.format("%d Deaths", data.deaths or 0))
            
        elseif viewType == "RESURRECTS" then
            bar.rightText:SetText(string.format("%d Resses", data.resurrects or 0))
        end

        -- NEW v0.9.0: Fully Data-Driven Text Routed Tooltip Engine (Server-Grafting Secured)
        bar:SetScript("OnEnter", function(self)
            local pageRecord = HeroStats_GetPageRecord(HeroStats_CurrentActivePage)
            local pageName = pageRecord and pageRecord.name
            if pageName == "FRONTPAGE" then return end

            -- Fetch the profile name and the current active server name safely
            local rawName = data.name or "Unknown"
            local currentRealm = GetRealmName() or ""
            local fullServerName = rawName

            -- SERVER-GRAFTING: If Blizzard clipped the realm name off, we graft it on manually
            if not string.find(rawName, "-") and currentRealm ~= "" then
                fullServerName = rawName .. "-" .. currentRealm
            end

            GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
            GameTooltip:ClearLines()           
            
            -- Fetch the class colors from the game engine safely
            local classColor = RAID_CLASS_COLORS[data.class] or { r = 0.5, g = 0.5, b = 0.5 }
            
            -- FIXED v0.9.0: Beautiful class-colored header with your guaranteed server name!
            GameTooltip:AddLine(fullServerName, classColor.r, classColor.g, classColor.b)
            GameTooltip:AddLine(" ")
                        
            local fightSeconds = HeroStats_CurrentFightDuration_RenderOverride or HeroStats_CurrentFightDuration or 1
            if fightSeconds < 1 then fightSeconds = 1 end

            if pageName == "HEALING" or pageName == "OVERHEALING" then
                GameTooltip:AddLine("Top Healing Abilities:", 1, 1, 1)
                if data.spellHeals then
                    local sortedSpells = {}
                    for spellName, spellData in pairs(data.spellHeals) do
                        table.insert(sortedSpells, { name = spellName, eff = spellData.effective or 0, oh = spellData.overheal or 0 })
                    end
                    table.sort(sortedSpells, function(a, b) return a.eff > b.eff end)
                    
                    local lineCount = 1
                    for i = 1, #sortedSpells do
                        if lineCount > 10 then break end
                        local s = sortedSpells[i]
                        
                        if pageName == "HEALING" then
                            if s.eff > 0 then
                                local personalSharePct = (data.effective > 0) and ((s.eff / data.effective) * 100) or 0
                                local formattedAmt = FormatDotNumber and FormatDotNumber(s.eff) or s.eff
                                local spellHps = s.eff / fightSeconds
                                
                                GameTooltip:AddDoubleLine(lineCount .. ". " .. s.name, string.format("%s (%.0f HPS) (%.1f%%)", formattedAmt, spellHps, personalSharePct), 0.8, 0.8, 0.8, 1, 0.82, 0)
                                lineCount = lineCount + 1
                            end
                        else
                            local spellGross = s.eff + s.oh
                            local spellEfficiencyPct = (spellGross > 0) and ((s.eff / spellGross) * 100) or 0
                            local formattedNet = FormatDotNumber and FormatDotNumber(s.eff) or s.eff
                            local formattedGross = FormatDotNumber and FormatDotNumber(spellGross) or spellGross
                            
                            GameTooltip:AddDoubleLine(lineCount .. ". " .. s.name, string.format("%s / %s (%.0f%%)", formattedNet, formattedGross, spellEfficiencyPct), 0.8, 0.8, 0.8, 1, 0.82, 0)
                            lineCount = lineCount + 1
                        end
                    end
                end
                
            elseif pageName == "MANA_EFF" then
                GameTooltip:AddLine("Ability Yield Breakdown:", 1, 1, 1)
                if data.spellMana and next(data.spellMana) ~= nil then
                    local sortedManaSpells = {}
                    for spellName, manaData in pairs(data.spellMana) do
                        local rawHealAmt = (data.spellHeals and data.spellHeals[spellName]) and data.spellHeals[spellName].effective or 0
                        table.insert(sortedManaSpells, { name = spellName, spent = manaData.manaUsed or 0, eff = rawHealAmt })
                    end
                    table.sort(sortedManaSpells, function(a, b) return a.spent > b.spent end)
                    
                    for i = 1, math.min(10, #sortedManaSpells) do
                        local m = sortedManaSpells[i]
                        local spellHpm = (m.spent > 0) and (m.eff / m.spent) or 0
                        local formattedMana = FormatDotNumber and FormatDotNumber(m.spent) or m.spent
                        
                        GameTooltip:AddDoubleLine(i .. ". " .. m.name, string.format("%s mana (%.1f HPM)", formattedMana, spellHpm), 0.8, 0.8, 0.8, 1, 0.82, 0)
                    end
                    GameTooltip:AddLine(" ")
                    local formattedTotalMana = FormatDotNumber and FormatDotNumber(data.manaUsed) or data.manaUsed
                    GameTooltip:AddDoubleLine("Total Combined Yield:", string.format("%s mana (%.1f HPM)", formattedTotalMana, data.hpm), 1, 1, 1, 1, 0.82, 0)
                end
                
            elseif pageName == "MANA_GAINED" then
                GameTooltip:AddLine("Top Mana Gained Sources:", 1, 1, 1)
                if data.spellManaGained and next(data.spellManaGained) ~= nil then
                    local sortedGainedSpells = {}
                    for spellName, gainedAmt in pairs(data.spellManaGained) do table.insert(sortedGainedSpells, { name = spellName, amt = gainedAmt }) end
                    table.sort(sortedGainedSpells, function(a, b) return a.amt > b.amt end)
                    
                    for i = 1, math.min(8, #sortedGainedSpells) do
                        local g = sortedGainedSpells[i]
                        local personalSharePct = (data.manaGained > 0) and ((g.amt / data.manaGained) * 100) or 0
                        local formattedAmt = FormatDotNumber and FormatDotNumber(g.amt) or g.amt
                        
                        GameTooltip:AddDoubleLine(i .. ". " .. g.name, string.format("%s (%.0f%%)", formattedAmt, personalSharePct), 0.8, 0.8, 0.8, 1, 0.82, 0)
                    end
                end
                
            elseif pageName == "DAMAGE_DONE" then
                GameTooltip:AddLine("Top Damage Abilities:", 1, 1, 1)
                if data.spellDamage then
                    local sortedSpells = {}
                    for spellName, dmgAmt in pairs(data.spellDamage) do table.insert(sortedSpells, { name = spellName, amt = dmgAmt }) end
                    table.sort(sortedSpells, function(a, b) return a.amt > b.amt end)
                    
                    for i = 1, math.min(8, #sortedSpells) do
                        local s = sortedSpells[i]
                        local personalSharePct = (data.damageDone > 0) and ((s.amt / data.damageDone) * 100) or 0
                        local formattedAmt = FormatDotNumber and FormatDotNumber(s.amt) or s.amt
                        local spellDps = s.amt / fightSeconds
                        
                        GameTooltip:AddDoubleLine(i .. ". " .. s.name, string.format("%s (%.0f DPS) (%.1f%%)", formattedAmt, spellDps, personalSharePct), 0.8, 0.8, 0.8, 1, 0.82, 0)
                    end
                end
                
            elseif pageName == "DAMAGE_TAKEN" then
                GameTooltip:AddLine("Top Damage Sources Taken:", 1, 1, 1)
                if data.spellTaken then
                    local sortedSources = {}
                    for sourceKey, sourceData in pairs(data.spellTaken) do
                        local finalAmt = type(sourceData) == "table" and sourceData.amt or tonumber(sourceData) or 0
                        table.insert(sortedSources, { key = sourceKey, amt = finalAmt })
                    end
                    table.sort(sortedSources, function(a, b) return a.amt > b.amt end)
                    
                    for i = 1, math.min(8, #sortedSources) do
                        local s = sortedSources[i]
                        local personalSharePct = (data.damageTaken > 0) and ((s.amt / data.damageTaken) * 100) or 0
                        local formattedAmt = FormatDotNumber and FormatDotNumber(s.amt) or s.amt
                        local sourceDtps = s.amt / fightSeconds
                        
                        GameTooltip:AddDoubleLine(i .. ". " .. s.key, string.format("%s (%.0f DTPS) (%.1f%%)", formattedAmt, sourceDtps, personalSharePct), 0.8, 0.8, 0.8, 1, 0.82, 0)
                    end
                end
				
            elseif viewType == "DMG_CRIT" then
                -- FIXED v0.10.0: Render detailed damage spell crits breakdown inside tooltip layout
                GameTooltip:AddLine("Top Critical Damage Abilities:", 1, 1, 1)
            
                if data.spellCrits and next(data.spellCrits) ~= nil then
                    local sortedSpells = {}
                    for spellName, cr in pairs(data.spellCrits) do
                        table.insert(sortedSpells, { name = spellName, hits = cr.hits, crits = cr.crits })
                    end
                    table.sort(sortedSpells, function(a, b) return a.crits > b.crits end)
                
                    -- Top 10 cap loop synchronized layout-wide
                    for i = 1, math.min(10, #sortedSpells) do
                        local s = sortedSpells[i]
                        local spellCritPct = (s.hits > 0) and ((s.crits / s.hits) * 100) or 0
                    
                        -- Outputs: "1. Fireball | 14 (38%)" using golden design guidelines
                        GameTooltip:AddDoubleLine(
                            i .. ". " .. s.name,
                            string.format("%d (%.0f%%)", s.crits, spellCritPct),
                            0.8, 0.8, 0.8, 1, 0.82, 0
                        )
                    end
                else
                    GameTooltip:AddLine("No critical damage records found for this session.", 0.6, 0.6, 0.6, true)
                end

            elseif viewType == "HEAL_CRIT" then
                -- FIXED v0.10.0: Render detailed healing spell crits breakdown inside tooltip layout
                GameTooltip:AddLine("Top Critical Healing Abilities:", 1, 1, 1)
            
                if data.spellHealCrits and next(data.spellHealCrits) ~= nil then
                    local sortedHeals = {}
                    for spellName, cr in pairs(data.spellHealCrits) do
                        table.insert(sortedHeals, { name = spellName, hits = cr.hits, crits = cr.crits })
                    end
                    table.sort(sortedHeals, function(a, b) return a.crits > b.crits end)
                
                    -- Top 10 cap loop synchronized layout-wide
                    for i = 1, math.min(10, #sortedHeals) do
                        local h = sortedHeals[i]
                        local spellCritPct = (h.hits > 0) and ((h.crits / h.hits) * 100) or 0
                    
                        -- Outputs: "1. Flash Heal | 8 (24%)" using golden design guidelines
                        GameTooltip:AddDoubleLine(
                            i .. ". " .. h.name,
                            string.format("%d (%.0f%%)", h.crits, spellCritPct),
                            0.8, 0.8, 0.8, 1, 0.82, 0
                        )
                    end
                else
                    GameTooltip:AddLine("No critical healing records found for this session.", 0.6, 0.6, 0.6, true)
                end


            elseif pageName == "DISPELS" then
                GameTooltip:AddLine("Top Dispel Abilities:", 1, 1, 1)
                if data.spellDispels and next(data.spellDispels) ~= nil then
                    local sortedDispels = {}
                    for spellName, count in pairs(data.spellDispels) do table.insert(sortedDispels, { name = spellName, amt = count }) end
                    table.sort(sortedDispels, function(a, b) return a.amt > b.amt end)
                    
                    for i = 1, math.min(8, #sortedDispels) do
                        local d = sortedDispels[i]
                        local personalSharePct = (data.dispels > 0) and ((d.amt / data.dispels) * 100) or 0
                        
                        GameTooltip:AddDoubleLine(i .. ". " .. d.name, string.format("%d (%.0f%%)", d.amt, personalSharePct), 0.8, 0.8, 0.8, 1, 0.82, 0)
                    end
                end

            elseif pageName == "BUFFS" then
                GameTooltip:AddLine("Top Buffs Applied:", 1, 1, 1)
                if data.spellBuffs and next(data.spellBuffs) ~= nil then
                    local sortedBuffs = {}
                    for buffName, count in pairs(data.spellBuffs) do table.insert(sortedBuffs, { name = buffName, amt = count }) end
                    table.sort(sortedBuffs, function(a, b) return a.amt > b.amt end)
                    
                    for i = 1, math.min(8, #sortedBuffs) do
                        local b = sortedBuffs[i]
                        local personalSharePct = (data.buffs > 0) and ((b.amt / data.buffs) * 100) or 0
                        
                        GameTooltip:AddDoubleLine(i .. ". " .. b.name, string.format("%d (%.0f%%)", b.amt, personalSharePct), 0.8, 0.8, 0.8, 1, 0.82, 0)
                    end
                end
                
            elseif pageName == "DEATHS" then
                GameTooltip:AddLine("Death Count:", 1, 1, 1)
                local personalSharePct = (data.deaths > 0) and 100 or 0
                GameTooltip:AddDoubleLine("1. Deaths", string.format("%d (%.0f%%)", data.deaths or 0, personalSharePct), 0.8, 0.8, 0.8, 1, 0.82, 0)
 
            elseif pageName == "RESURRECTS" then
                GameTooltip:AddLine("Raid Resurrection Contribution:", 1, 1, 1)
                local totalRaidResses = topRessValue or 1
                if totalRaidResses == 0 then totalRaidResses = 1 end
                local personalSharePct = (data.resurrects > 0) and ((data.resurrects / totalRaidResses) * 100) or 0
                GameTooltip:AddDoubleLine("1. " .. data.name, string.format("%d (%.0f%%)", data.resurrects or 0, personalSharePct), 0.8, 0.8, 0.8, 1, 0.82, 0)
            end
            
            GameTooltip:Show()
        end)

        bar:SetScript("OnLeave", function(self)
            if GameTooltip then GameTooltip:Hide() end
        end)

        bar:Show()
    end
end

function HeroStats_RenderTextMessage(titleString, bodyString)
    for _, bar in ipairs(uiBars) do bar:Hide() end
    headerText:SetText(titleString)
    infoText:SetText(bodyString)
    scrollChild:SetHeight(120)
end

function HeroStats_ClearDisplay()
    for _, bar in ipairs(uiBars) do bar:Hide() end
    scrollChild:SetHeight(1)
end

nextButton:SetScript("OnClick", function() if HeroStats_ChangePage then HeroStats_ChangePage(1) end end)
prevButton:SetScript("OnClick", function() if HeroStats_ChangePage then HeroStats_ChangePage(-1) end end)

function HeroStats_ShowMainWindow()
    if container then
        container:Show()
        if HeroStatsSettings then HeroStatsSettings.hidden = false end
        if HeroStats_RefreshCurrentPage then HeroStats_RefreshCurrentPage() end
    end
end

-- Global control interface to hide the main window frame securely
function HeroStats_HideMainWindow()
    if container then
        container:Hide()
        if HeroStatsSettings then HeroStatsSettings.hidden = true end
        
        -- ROUTED: Now using the unified central print engine safely
        if HeroStats_Print then
            HeroStats_Print("Window is hidden. You can show it again by typing /hs.")
        end
    end
end

-- NEW: Official Blizzard Static Popup Confirmation Specification Sheet
StaticPopupDialogs["HEROSTATS_WIPE_CONFIRM"] = {
    text = "Are you sure you want to wipe all data and clear your entire fight history?",
    button1 = "Yes, Clear Everything",
    button2 = "No, Cancel",
    OnAccept = function()
        -- Route directly to the backend clearing engine in the core file
        if HeroStats_ExecuteMasterWipeData then
            HeroStats_ExecuteMasterWipeData()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Global bridge allowing the header button object to spawn the prompt panel instantly
function HeroStats_TriggerResetDialog()
    StaticPopup_Show("HEROSTATS_WIPE_CONFIRM")
end

local loaderFrame = CreateFrame("Frame")
loaderFrame:RegisterEvent("ADDON_LOADED")
loaderFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HeroStats" then
        if not HeroStatsSettings then
            HeroStatsSettings = { width = 200, height = HEROSTATS_MIN_HEIGHT, point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0, page = 0, locked = false, hidden = false }
        end
        if not HeroStatsSettings.page then HeroStatsSettings.page = 0 end
        if HeroStatsSettings.locked == nil then HeroStatsSettings.locked = false end
        if HeroStatsSettings.hidden == nil then HeroStatsSettings.hidden = false end

        container:SetSize(HeroStatsSettings.width, HeroStatsSettings.height)
        container:ClearAllPoints()
        container:SetPoint(HeroStatsSettings.point, UIParent, HeroStatsSettings.relativePoint, HeroStatsSettings.xOfs, HeroStatsSettings.yOfs)
        scrollChild:SetWidth(container:GetWidth() - 22)
        infoText:SetWidth(container:GetWidth() - 32)
        
        if HeroStatsSettings.selectedViewSessionID == nil then 
            HeroStatsSettings.selectedViewSessionID = 0 
        end

        if HeroStats_SetInitialPage then 
            HeroStats_SetInitialPage(HeroStatsSettings.page) 
        end
        
        if HeroStats_UpdateLockVisuals then HeroStats_UpdateLockVisuals(HeroStatsSettings.locked) end
        if HeroStats_UpdateFilterVisuals then HeroStats_UpdateFilterVisuals(false) end
        
        if HeroStatsSettings.hidden then
            container:Hide()
        else
            container:Show()
        end
        
        HeroStats_ClearDisplay()

        C_Timer.After(1.0, function()
            scrollChild:SetWidth(container:GetWidth() - 22)
            if HeroStats_RefreshCurrentPage then HeroStats_RefreshCurrentPage() end
        end)

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- end herostatsui.lua