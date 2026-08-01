-- ==========================================
-- HealSmart - UI & Constants (v0.5.0) - PART 1
-- ==========================================

HEALSMART_BAR_HEIGHT = 16
HEALSMART_BAR_GAP = 2
HEALSMART_HEADER_HEIGHT = 20
HEALSMART_OUT_OF_COMBAT_GRACE = 5
HEALSMART_MANA_THRESHOLD = 300 

HEALSMART_MIN_WIDTH = 150
HEALSMART_MIN_HEIGHT = 110 

local uiBars = {}

-- 1. Create the Main Window Frame (Container)
local container = CreateFrame("Frame", "HealSmartContainer", UIParent)
container:SetClampedToScreen(true)
container:SetResizable(true)

if container.SetResizeBounds then
    container:SetResizeBounds(HEALSMART_MIN_WIDTH, HEALSMART_MIN_HEIGHT, 1000, 1000)
end

-- Draggable logic without Shift requirement
container:SetMovable(true)
container:EnableMouse(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", function(self) 
    if HealSmartSettings and not HealSmartSettings.locked then self:StartMoving() end 
end)
container:SetScript("OnDragStop", function(self) 
    self:StopMovingOrSizing()
    if HealSmartSettings then
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        HealSmartSettings.point = point
        HealSmartSettings.relativePoint = relativePoint
        HealSmartSettings.xOfs = xOfs
        HealSmartSettings.yOfs = yOfs
    end
end)

local bgTexture = container:CreateTexture(nil, "BACKGROUND", nil, -8)
bgTexture:SetAllPoints(container)
bgTexture:SetColorTexture(0, 0, 0, 0.4)

-- ==========================================
-- HealSmart - UI (v0.6.0) - PART 2 (Unified Header Framework)
-- ==========================================

-- 2. Create the Header Bar (KEPT INTACT!)
local header = CreateFrame("Frame", nil, container)
header:SetHeight(HEALSMART_HEADER_HEIGHT)
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
function HealSmart_UpdateLockVisuals(isLocked)
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

function HealSmart_UpdateFilterVisuals(isFiltered)
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
closeButton:SetScript("OnClick", function() if HealSmart_HideMainWindow then HealSmart_HideMainWindow() end end)
closeButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText("Hide frame (use /hs to show again)", 1, 1, 1, 1, true)
    GameTooltip:Show()
end)
closeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Filter Toggle Button (10x10)
filterButton = CreateFrame("Button", nil, header)
filterButton:SetSize(10, 10)
filterButton:SetPoint("RIGHT", closeButton, "LEFT", -2, -1)
filterButton:SetScript("OnClick", function()
    isCurrentlyClassFiltered = not isCurrentlyClassFiltered
    HealSmart_UpdateFilterVisuals(isCurrentlyClassFiltered)
    if HealSmart_ToggleClassFilter then HealSmart_ToggleClassFilter() end
end)
filterButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText("Toggle All classes or current class", 1, 1, 1, 1, true)
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
    if HealSmart_TriggerResetDialog then HealSmart_TriggerResetDialog() end
end)
resetButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText("Reset All Data & Clear History", 1, 1, 1, 1, true)
    GameTooltip:Show()
end)
resetButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- NEW: Graphical Shout/Report Button (Sized to 10x10 with dynamic tooltip overlay engine)
local shoutButton = CreateFrame("Button", nil, header)
shoutButton:SetSize(10, 10)
shoutButton:SetPoint("RIGHT", resetButton, "LEFT", -4, 0) -- Fixed to 0y for straight alignment
shoutButton:SetNormalTexture("Interface\\Icons\\Ability_Warrior_BattleShout")

if shoutButton:GetNormalTexture() then
    shoutButton:GetNormalTexture():SetAllPoints(shoutButton)
end

shoutButton:SetScript("OnClick", function()
    if HealSmart_ReportCurrentPageToChat then
        HealSmart_ReportCurrentPageToChat()
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
    local currentLines = HealSmartSettings and HealSmartSettings.reportLinesLimit or 5
    local currentMode = HealSmartSettings and HealSmartSettings.reportChannelMode or 1
    local channelText = channelNames[currentMode] or "Raid / Party"
    
    -- Append the channel number to the string if the selection is set to custom channel
    if currentMode == 5 and HealSmartSettings and HealSmartSettings.reportCustomChannelNum then
        channelText = "Channel " .. HealSmartSettings.reportCustomChannelNum
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
sessionButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Note_02")
if sessionButton:GetNormalTexture() then sessionButton:GetNormalTexture():SetAllPoints(sessionButton) end
sessionButton:SetScript("OnClick", function()
    if HealSmart_ToggleSessionWindow then HealSmart_ToggleSessionWindow() end
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
    if HealSmartSettings then
        HealSmartSettings.locked = not HealSmartSettings.locked
        HealSmart_UpdateLockVisuals(HealSmartSettings.locked)
    end
end)
lockButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText("Lock or Unlock Frame", 1, 1, 1, 1, true)
    GameTooltip:Show()
end)
lockButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- NEW DYNAMIC COLOR ENGINE: Tint the standard texture dynamically via VertexColor
function HealSmart_UpdateLockVisuals(isLocked)
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

function HealSmart_UpdateFilterVisuals(isFiltered)
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
-- HealSmart - UI (v0.5.0) - PART 3
-- ==========================================

-- 3. Create the Scrollable Area
local scrollFrame = CreateFrame("ScrollFrame", "HealSmartScrollFrame", container, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -20, 2) 

if HealSmartScrollFrameScrollBar then
    local sb = HealSmartScrollFrameScrollBar
    sb:ClearAllPoints()
    -- FIXED ANCHOR: Stays on the absolute window edge, but drops 22 pixels down to clear the icons
    sb:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -37)
    sb:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 20)
    if HealSmartScrollFrameScrollBarScrollUpButton then HealSmartScrollFrameScrollBarScrollUpButton:Hide() end
    if HealSmartScrollFrameScrollBarScrollDownButton then HealSmartScrollFrameScrollBarScrollDownButton:Hide() end
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
    if HealSmartSettings then
        HealSmartSettings.width = container:GetWidth()
        HealSmartSettings.height = container:GetHeight()
    end
    for _, bar in ipairs(uiBars) do
        bar:SetWidth(targetWidth)
        if bar.UpdateBorders then bar:UpdateBorders(targetWidth) end
    end
end)

-- ==========================================
-- HealSmart - UI (v0.5.0) - PART 4
-- ==========================================

local function CreateHealerBar(index)
    local currentBarWidth = container:GetWidth() - 22
    local bar = CreateFrame("Frame", nil, scrollChild)
    bar:SetSize(currentBarWidth, HEALSMART_BAR_HEIGHT)
    
    if index == 1 then
        bar:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 1, 0)
    else
        bar:SetPoint("TOPLEFT", uiBars[index - 1], "BOTTOMLEFT", 0, -HEALSMART_BAR_GAP)
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
    leftLine:SetSize(1, HEALSMART_BAR_HEIGHT)

    local rightLine = bar:CreateTexture(nil, "OVERLAY")
    rightLine:SetColorTexture(0, 0, 0, 0.9)
    rightLine:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    rightLine:SetSize(1, HEALSMART_BAR_HEIGHT)

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

function HealSmart_RenderRaidBars(sortedData, maxVal, viewType, totalRaidEffective)
    infoText:SetText("")
    for _, bar in ipairs(uiBars) do bar:Hide() end

    local totalHeight = #sortedData * (HEALSMART_BAR_HEIGHT + HEALSMART_BAR_GAP)
    scrollChild:SetHeight(totalHeight)
    local targetWidth = container:GetWidth() - 22

    if viewType == "HEAL" then
        headerText:SetText("1. Healing Done")
    elseif viewType == "EFFICIENCY" then
        headerText:SetText("2. Heal vs Overheal")
    elseif viewType == "MANA" then
        headerText:SetText("3. Mana Efficiency")
    end

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
        
        if viewType == "HEAL" then
            local fillValue = (maxVal > 0) and ((data.effective / maxVal) * 100) or 0
            bar.statusBar:SetValue(fillValue)
        elseif viewType == "EFFICIENCY" then
            bar.statusBar:SetValue(data.percent)
        elseif viewType == "MANA" then
            local fillValue = (maxVal > 0) and ((data.hpm / maxVal) * 100) or 0
            bar.statusBar:SetValue(fillValue)
        end
        
        bar.leftText:SetText(data.name)
        
        -- DYNAMIC PER-SECOND CALCULATIONS FOR HPS, DPS AND DTPS (v0.8.0)
        local fightSeconds = HealSmart_CurrentFightDuration or 0
        if fightSeconds < 1 then fightSeconds = 1 end

        -- FIXED v0.8.0: This single line now dynamically controls the header for ALL 10 pages cleanly
        headerText:SetText(viewTitle or HealSmart_PageTitles[HealSmart_CurrentActivePage] or "HealSmart")

        if viewType == "HEAL" then
            local currentTotalRaid = totalRaidEffective or 1
            if currentTotalRaid == 0 then currentTotalRaid = 1 end
            local raidSharePercent = (data.effective / currentTotalRaid) * 100
            local formattedAmt = FormatDotNumber and FormatDotNumber(data.effective) or data.effective
            
            local hps = data.effective / fightSeconds
            bar.rightText:SetText(string.format("%s (%.0f HPS) - %.1f%%", formattedAmt, hps, raidSharePercent))
            
        elseif viewType == "EFFICIENCY" then
            local grossHealing = data.effective + data.overheal
            local formattedNet = FormatDotNumber and FormatDotNumber(data.effective) or data.effective
            local formattedGross = FormatDotNumber and FormatDotNumber(grossHealing) or grossHealing
            bar.rightText:SetText(string.format("%s / %s - %.0f%%", formattedNet, formattedGross, data.percent))
            
        elseif viewType == "MANA" then
            local currentThreshold = HealSmart_CurrentThreshold or 0
            if data.manaUsed < currentThreshold then
                bar.rightText:SetText(string.format("%s mana - 0.0 HPM", FormatDotNumber(data.manaUsed)))
            else
                bar.rightText:SetText(string.format("%s mana - %.1f HPM", FormatDotNumber(data.manaUsed), data.hpm))
            end
            
        elseif viewType == "DISPELS" then
            bar.statusBar:SetValue((maxVal > 0) and ((data.dispels / maxVal) * 100) or 0)
            bar.rightText:SetText(string.format("%d dispels", data.dispels))
            
        elseif viewType == "BUFFS" then
            bar.statusBar:SetValue((maxVal > 0) and ((data.buffs / maxVal) * 100) or 0)
            bar.rightText:SetText(string.format("%d buffs", data.buffs))
            
        elseif viewType == "DEATHS" then
            bar.statusBar:SetValue((maxVal > 0) and ((data.deaths / maxVal) * 100) or 0)
            bar.rightText:SetText(string.format("%d deaths", data.deaths))
            
        elseif viewType == "RESS" then
            bar.statusBar:SetValue((maxVal > 0) and ((data.resurrects / maxVal) * 100) or 0)
            bar.rightText:SetText(string.format("%d resurrects", data.resurrects))
            
        elseif viewType == "DAMAGEDONE" then
            bar.statusBar:SetValue((maxVal > 0) and ((data.damageDone / maxVal) * 100) or 0)
            local formattedDmg = FormatDotNumber and FormatDotNumber(data.damageDone) or data.damageDone
            local dps = data.damageDone / fightSeconds
            bar.rightText:SetText(string.format("%s dmg (%.0f DPS)", formattedDmg, dps))
            
        elseif viewType == "DAMAGETAKEN" then
            bar.statusBar:SetValue((maxVal > 0) and ((data.damageTaken / maxVal) * 100) or 0)
            local formattedTaken = FormatDotNumber and FormatDotNumber(data.damageTaken) or data.damageTaken
            local dtps = data.damageTaken / fightSeconds
            bar.rightText:SetText(string.format("%s taken (%.0f DTPS)", formattedTaken, dtps))
        end

        -- NEW v0.8.0: Fully Mirrored Per-Ability Tooltip Engine (HPS/DPS/Personal Pct Synced)
        bar:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
            GameTooltip:ClearLines()
            
            -- Title layout string: Displays Name and Class
            GameTooltip:AddLine(data.name .. " (" .. (data.class or "UNKNOWN") .. ")", 1, 0.82, 0)
            GameTooltip:AddLine(" ") -- Blank gap layout line
            
            -- Secure active fight clock duration, clamping at minimum 1 second to prevent division by zero
            local fightSeconds = HealSmart_CurrentFightDuration or 0
            if fightSeconds < 1 then fightSeconds = 1 end

            -- ROW 1 & 2: HEALING DONE & HEAL VS OVERHEAL SPECIFIC TOOLTIPS
            if HealSmart_CurrentActivePage == 1 or HealSmart_CurrentActivePage == 2 then
                GameTooltip:AddLine("Top Healing Abilities:", 1, 1, 1)
                if data.spellHeals then
                    local sortedSpells = {}
                    for spellName, spellData in pairs(data.spellHeals) do
                        table.insert(sortedSpells, { name = spellName, eff = spellData.effective, oh = spellData.overheal })
                    end
                    table.sort(sortedSpells, function(a, b) return a.eff > b.eff end)
                    
                    local lineCount = 1
                    for i = 1, #sortedSpells do
                        -- Stop the print loop immediately if we have already listed the top 8 elements
                        if lineCount > 8 then break end
                        
                        local s = sortedSpells[i]
                        
                        if HealSmart_CurrentActivePage == 1 then
                            -- FIXED v0.8.0: Skip legacy 0-healing ghost records entirely on Page 1
                            if s.eff > 0 then
                                local personalSharePct = (data.effective > 0) and ((s.eff / data.effective) * 100) or 0
                                local formattedAmt = FormatDotNumber and FormatDotNumber(s.eff) or s.eff
                                local spellHps = s.eff / fightSeconds
                                
                                GameTooltip:AddDoubleLine(
                                    lineCount .. ". " .. s.name, 
                                    string.format("%s (%.0f HPS) - %.1f%%", formattedAmt, spellHps, personalSharePct), 
                                    0.8, 0.8, 0.8, 1, 1, 1
                               )
                               lineCount = lineCount + 1
                            end
                        else
                            -- Page 2 (Overhealing): Show everything since raw efficiency can contain gross damage logs
                            local spellGross = s.eff + s.oh
                            local spellEfficiencyPct = (spellGross > 0) and ((s.eff / spellGross) * 100) or 0
                            local formattedNet = FormatDotNumber and FormatDotNumber(s.eff) or s.eff
                            local formattedGross = FormatDotNumber and FormatDotNumber(spellGross) or spellGross
                            
                            GameTooltip:AddDoubleLine(
                                lineCount .. ". " .. s.name, 
                                string.format("%s / %s - %.0f%%", formattedNet, formattedGross, spellEfficiencyPct), 
                                0.8, 0.8, 0.8, 1, 0.3, 0.3
                            )
                            lineCount = lineCount + 1
                        end
                    end
                end
                
            -- ROW 3: MANA EFFICIENCY SPECIFIC TOOLTIP (v0.8.0 Factual Raw Mana Model - NO GUESSWORK)
            elseif HealSmart_CurrentActivePage == 3 then
                GameTooltip:AddLine("Ability Yield Breakdown:", 1, 1, 1)
                
                -- Loop strictly through your persistent spellMana database populated by SPELL_CAST_SUCCESS
                if data.spellMana and next(data.spellMana) ~= nil then
                    local sortedManaSpells = {}
                    for spellName, manaData in pairs(data.spellMana) do
                        -- Fetch the factual raw mana spent AND the factual raw healing accumulated inside core
                        local rawSpent = manaData.manaUsed or 0
                        local rawHealAmt = manaData.effective or 0
                        
                        table.insert(sortedManaSpells, { name = spellName, spent = rawSpent, eff = rawHealAmt })
                    end
                    -- Sort from the highest mana consuming rank to the lowest
                    table.sort(sortedManaSpells, function(a, b) return a.spent > b.spent end)
                    
                    for i = 1, math.min(8, #sortedManaSpells) do
                        local m = sortedManaSpells[i]
                        
                        -- Calculate the absolute true, independent HPM based on raw database parameters
                        local spellHpm = (m.spent > 0) and (m.eff / m.spent) or 0
                        local formattedMana = FormatDotNumber and FormatDotNumber(m.spent) or m.spent
                        
                        -- Displays independent data: e.g. Rank 5 on 1.9 HPM and Rank 10 on 4.5 HPM
                        GameTooltip:AddDoubleLine(
                            i .. ". " .. m.name, 
                            string.format("%s mana - %.1f HPM", formattedMana, spellHpm), 
                            0.8, 0.8, 0.8, 1, 0.82, 0
                        )
                    end
                    
                    -- Summary line at the bottom matches your main bar 1:1 without deviations
                    GameTooltip:AddLine(" ")
                    local formattedTotalMana = FormatDotNumber and FormatDotNumber(data.manaUsed) or data.manaUsed
                    GameTooltip:AddDoubleLine("Total Combined Yield:", string.format("%s mana (%.1f HPM)", formattedTotalMana, data.hpm), 1, 1, 1, 1, 0.82, 0)
                else
                    GameTooltip:AddLine("No detailed mana logs available for this session.", 0.6, 0.6, 0.6, true)
                end

            -- ROW 5: BUFFS APPLIED SPECIFIC TOOLTIP (v0.8.0 Nil-Safeguarded)
            elseif HealSmart_CurrentActivePage == 5 then
                GameTooltip:AddLine("Top Buffs Applied:", 1, 1, 1)
                
                -- FIXED: Safe verification check ensures we never loop a missing nil array
                if data.spellBuffs and next(data.spellBuffs) ~= nil then
                    local sortedBuffs = {}
                    for buffName, count in pairs(data.spellBuffs) do
                        table.insert(sortedBuffs, { name = buffName, amt = count })
                    end
                    table.sort(sortedBuffs, function(a, b) return a.amt > b.amt end)
                    
                    for i = 1, math.min(8, #sortedBuffs) do
                        local b = sortedBuffs[i]
                        local personalSharePct = (data.buffs > 0) and ((b.amt / data.buffs) * 100) or 0
                        
                        GameTooltip:AddDoubleLine(
                            i .. ". " .. b.name, 
                            string.format("%d buffs (%.0f%%)", b.amt, personalSharePct), 
                            0.8, 0.8, 0.8, 1, 1, 1
                        )
                    end
                else
                    -- Elegant fallback string for old legacy datasets lacking detailed logs
                    GameTooltip:AddLine("No detailed buff logs available for this session.", 0.6, 0.6, 0.6, true)
                end

            -- ROW 8: DAMAGE DONE SPECIFIC TOOLTIP
            elseif HealSmart_CurrentActivePage == 8 then
                GameTooltip:AddLine("Top Damage Abilities:", 1, 1, 1)
                if data.spellDamage then
                    local sortedSpells = {}
                    for spellName, dmgAmt in pairs(data.spellDamage) do
                        table.insert(sortedSpells, { name = spellName, amt = dmgAmt })
                    end
                    table.sort(sortedSpells, function(a, b) return a.amt > b.amt end)
                    
                    for i = 1, math.min(8, #sortedSpells) do
                        local s = sortedSpells[i]
                        -- Mirrored Page 8 Format: SpellName | 45.200 dmg (950 DPS) - 65.0%
                        local personalSharePct = (data.damageDone > 0) and ((s.amt / data.damageDone) * 100) or 0
                        local formattedAmt = FormatDotNumber and FormatDotNumber(s.amt) or s.amt
                        local spellDps = s.amt / fightSeconds
                        
                        GameTooltip:AddDoubleLine(
                            i .. ". " .. s.name, 
                            string.format("%s dmg (%.0f DPS) - %.1f%%", formattedAmt, spellDps, personalSharePct), 
                            0.8, 0.8, 0.8, 1, 1, 1
                        )
                    end
                end

            -- ROW 9: DAMAGE TAKEN SPECIFIC TOOLTIP (v0.8.0 Advanced Color-Coded Matrix)
            elseif HealSmart_CurrentActivePage == 9 then
                GameTooltip:AddLine("Top Damage Sources Taken:", 1, 1, 1)
                if data.spellTaken then
                    local sortedSources = {}
                    for sourceKey, sourceData in pairs(data.spellTaken) do
                        local finalAmt = 0
                        local finalColor = "physical"
                        
                        if type(sourceData) == "table" then
                            finalAmt = sourceData.amt or 0
                            finalColor = sourceData.color or "physical"
                        else
                            -- Legacy data fallback loop: Treat the raw number value as the amount
                            finalAmt = tonumber(sourceData) or 0
                        end
                        
                        table.insert(sortedSources, { key = sourceKey, amt = finalAmt, color = finalColor })
                    end
                    table.sort(sortedSources, function(a, b) return a.amt > b.amt end)
                    
                    -- Pre-compiled color library layout map targeting RGB floats
                    local schoolColors = {
                        physical = { 0.9, 0.9, 0.9 }, -- Clean light grey/white
                        fire     = { 1.0, 0.3, 0.3 }, -- Burning red
                        nature   = { 0.3, 1.0, 0.3 }, -- Vibrant nature green
                        poison   = { 0.6, 0.4, 0.2 }, -- Earthen poison brown
                        shadow   = { 0.6, 0.3, 0.9 }  -- Void shadow purple
                    }
                    
                    for i = 1, math.min(8, #sortedSources) do
                        local s = sortedSources[i]
                        local personalSharePct = (data.damageTaken > 0) and ((s.amt / data.damageTaken) * 100) or 0
                        local formattedAmt = FormatDotNumber and FormatDotNumber(s.amt) or s.amt
                        local sourceDtps = s.amt / fightSeconds
                        
                        -- Fetch color layout configuration dynamically or fallback to physical
                        local rgb = schoolColors[s.color] or schoolColors["physical"]
                        
                        -- Print the colored entry line into the GameTooltip view canvas
                        GameTooltip:AddDoubleLine(
                            i .. ". " .. s.key, 
                            string.format("%s taken (%.0f DTPS) - %.1f%%", formattedAmt, sourceDtps, personalSharePct), 
                            rgb[1], rgb[2], rgb[3], 1, 1, 1
                        )
                    end
                end
            end
            
            GameTooltip:Show()
        end)


        bar:Show()
    end
end

function HealSmart_RenderTextMessage(titleString, bodyString)
    for _, bar in ipairs(uiBars) do bar:Hide() end
    headerText:SetText(titleString)
    infoText:SetText(bodyString)
    scrollChild:SetHeight(120)
end

function HealSmart_ClearDisplay()
    for _, bar in ipairs(uiBars) do bar:Hide() end
    scrollChild:SetHeight(1)
end

nextButton:SetScript("OnClick", function() if HealSmart_ChangePage then HealSmart_ChangePage(1) end end)
prevButton:SetScript("OnClick", function() if HealSmart_ChangePage then HealSmart_ChangePage(-1) end end)

function HealSmart_ShowMainWindow()
    if container then
        container:Show()
        if HealSmartSettings then HealSmartSettings.hidden = false end
        if HealSmart_RefreshCurrentPage then HealSmart_RefreshCurrentPage() end
    end
end

-- Global control interface to hide the main window frame securely
function HealSmart_HideMainWindow()
    if container then
        container:Hide()
        if HealSmartSettings then HealSmartSettings.hidden = true end
        
        -- ROUTED: Now using the unified central print engine safely
        if HealSmart_Print then
            HealSmart_Print("Window is hidden. You can show it again by typing /hs.")
        end
    end
end

-- NEW: Official Blizzard Static Popup Confirmation Specification Sheet
StaticPopupDialogs["HEALSMART_WIPE_CONFIRM"] = {
    text = "Are you sure you want to wipe all data and clear your entire fight history?",
    button1 = "Yes, Clear Everything",
    button2 = "No, Cancel",
    OnAccept = function()
        -- Route directly to the backend clearing engine in the core file
        if HealSmart_ExecuteMasterWipeData then
            HealSmart_ExecuteMasterWipeData()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Global bridge allowing the header button object to spawn the prompt panel instantly
function HealSmart_TriggerResetDialog()
    StaticPopup_Show("HEALSMART_WIPE_CONFIRM")
end

local loaderFrame = CreateFrame("Frame")
loaderFrame:RegisterEvent("ADDON_LOADED")
loaderFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HealSmart" then
        if not HealSmartSettings then
            HealSmartSettings = { width = 200, height = HEALSMART_MIN_HEIGHT, point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0, page = 0, locked = false, hidden = false }
        end
        if not HealSmartSettings.page then HealSmartSettings.page = 0 end
        if HealSmartSettings.locked == nil then HealSmartSettings.locked = false end
        if HealSmartSettings.hidden == nil then HealSmartSettings.hidden = false end

        container:SetSize(HealSmartSettings.width, HealSmartSettings.height)
        container:ClearAllPoints()
        container:SetPoint(HealSmartSettings.point, UIParent, HealSmartSettings.relativePoint, HealSmartSettings.xOfs, HealSmartSettings.yOfs)
        scrollChild:SetWidth(container:GetWidth() - 22)
        infoText:SetWidth(container:GetWidth() - 32)
        
        if HealSmartSettings.selectedViewSessionID == nil then 
            HealSmartSettings.selectedViewSessionID = 0 
        end

        if HealSmart_SetInitialPage then 
            HealSmart_SetInitialPage(HealSmartSettings.page) 
        end
        
        if HealSmart_UpdateLockVisuals then HealSmart_UpdateLockVisuals(HealSmartSettings.locked) end
        if HealSmart_UpdateFilterVisuals then HealSmart_UpdateFilterVisuals(false) end
        
        if HealSmartSettings.hidden then
            container:Hide()
        else
            container:Show()
        end
        
        HealSmart_ClearDisplay()

        C_Timer.After(1.0, function()
            scrollChild:SetWidth(container:GetWidth() - 22)
            if HealSmart_RefreshCurrentPage then HealSmart_RefreshCurrentPage() end
        end)

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- end healsmartui.lua