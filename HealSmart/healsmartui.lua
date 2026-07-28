-- ==========================================
-- HealSmart - UI & Constants (v0.4.0 Mana Update) - PART 1
-- ==========================================

HEALSMART_BAR_HEIGHT = 16
HEALSMART_BAR_GAP = 2
HEALSMART_HEADER_HEIGHT = 20
HEALSMART_OUT_OF_COMBAT_GRACE = 5
HEALSMART_MANA_THRESHOLD = 300 -- NEW: Minimum mana consumed before HPM is calculated

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

-- Draggable logic
container:SetMovable(true)
container:EnableMouse(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
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
-- HealSmart - UI (v0.4.0) - PART 2
-- ==========================================

-- 2. Create the Header Bar
local header = CreateFrame("Frame", nil, container)
header:SetHeight(HEALSMART_HEADER_HEIGHT)
header:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
header:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)

local headerBg = header:CreateTexture(nil, "BACKGROUND")
headerBg:SetAllPoints(header)
headerBg:SetColorTexture(0.05, 0.15, 0.3, 1.0) -- Dark Navy Blue

local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
headerText:SetPoint("LEFT", header, "LEFT", 6, 0)
headerText:SetText("HealSmart v0.4.0")
headerText:SetTextColor(1, 1, 1, 1) 

-- Filter Toggle Button ([ALL] / [MINE])
local filterButton = CreateFrame("Button", nil, header)
filterButton:SetSize(40, HEALSMART_HEADER_HEIGHT)
filterButton:SetPoint("RIGHT", header, "RIGHT", -6, 0)

local filterText = filterButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
filterText:SetAllPoints(filterButton)
filterText:SetJustifyH("RIGHT")
filterText:SetText("[ALL]") 
filterText:SetTextColor(0.1, 0.6, 1.0, 1.0) 

filterButton:SetScript("OnClick", function()
    if HealSmart_ToggleClassFilter then
        local currentFilter = HealSmart_ToggleClassFilter()
        if currentFilter == "ALL" then
            filterText:SetText("[ALL]")
            filterText:SetTextColor(0.1, 0.6, 1.0, 1.0)
        else
            filterText:SetText("[MINE]")
            filterText:SetTextColor(1.0, 0.8, 0.0, 1.0)
        end
    end
end)

-- Navigation buttons (< and >) to flip virtual pages
local nextButton = CreateFrame("Button", nil, header)
nextButton:SetSize(16, HEALSMART_HEADER_HEIGHT)
nextButton:SetPoint("RIGHT", filterButton, "LEFT", -4, 0)
local nextText = nextButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nextText:SetAllPoints(nextButton)
nextText:SetText(">")
nextText:SetTextColor(1, 1, 1, 0.8)

local prevButton = CreateFrame("Button", nil, header)
prevButton:SetSize(16, HEALSMART_HEADER_HEIGHT)
prevButton:SetPoint("RIGHT", nextButton, "LEFT", -4, 0)
local prevText = prevButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
prevText:SetAllPoints(prevButton)
prevText:SetText("<")
prevText:SetTextColor(1, 1, 1, 0.8)

-- ==========================================
-- HealSmart - UI (v0.4.0) - PART 3
-- ==========================================

-- 3. Create the Scrollable Area
local scrollFrame = CreateFrame("ScrollFrame", "HealSmartScrollFrame", container, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -20, 2) 

if HealSmartScrollFrameScrollBar then
    local sb = HealSmartScrollFrameScrollBar
    sb:ClearAllPoints()
    sb:SetPoint("TOPRIGHT", container, "TOPRIGHT", -2, -HEALSMART_HEADER_HEIGHT - 4)
    sb:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 20)
    if HealSmartScrollFrameScrollBarScrollUpButton then HealSmartScrollFrameScrollBarScrollUpButton:Hide() end
    if HealSmartScrollFrameScrollBarScrollDownButton then HealSmartScrollFrameScrollBarScrollDownButton:Hide() end
end

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollFrame:SetScrollChild(scrollChild)

-- Global text blocks inside the canvas for Page 0 and empty pages
local infoText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
infoText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 6, -10)
infoText:SetWidth(170)
infoText:SetJustifyH("LEFT")
infoText:SetText("")

-- 4. Create the Interactive Resize Handle
local resizeButton = CreateFrame("Button", nil, container)
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

local function CreateBorderLine(parent, point, relativePoint, x, y, width, height)
    local line = parent:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(0, 0, 0, 0.9)
    line:SetPoint(point, parent, relativePoint, x, y)
    line:SetSize(width, height)
end

-- ==========================================
-- UPDATE TO healsmartui.lua - PART 4 (RENDERING SYNC FIX)
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

    -- The actual filling status bar color block
    local statusBar = CreateFrame("StatusBar", nil, bar)
    statusBar:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    statusBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    statusBar:SetMinMaxValues(0, 100)

    -- NEW CRITICAL LAYOUT FIX: Create a dedicated invisible overlay frame 
    -- to host text elements, guaranteeing they float on top of the status bar texture.
    local textOverlay = CreateFrame("Frame", nil, bar)
    textOverlay:SetAllPoints(bar)
    textOverlay:SetFrameLevel(statusBar:GetFrameLevel() + 5)

    -- Left Text: Now safely created on textOverlay instead of statusBar
    local leftText = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    leftText:SetPoint("LEFT", textOverlay, "LEFT", 4, 0)
    leftText:SetJustifyH("LEFT")

    -- Right Text: Safely created on textOverlay and locked flush against the right container edge
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

-- ==========================================
-- UPDATE TO healsmartui.lua (PAGE NAMES FIXED)
-- ==========================================
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
        
        -- --- 1. SET VISUAL BAR FILLS FIRST ---
        if viewType == "HEAL" then
            local fillValue = (maxVal > 0) and ((data.effective / maxVal) * 100) or 0
            bar.statusBar:SetValue(fillValue)
        elseif viewType == "EFFICIENCY" then
            bar.statusBar:SetValue(data.percent)
        elseif viewType == "MANA" then
            local fillValue = (maxVal > 0) and ((data.hpm / maxVal) * 100) or 0
            bar.statusBar:SetValue(fillValue)
        end
        
        -- --- 2. SET TEXT STRINGS ABSOLUTELY LAST ---
        -- Doing this at the very end of the loop prevents the Blizzard StatusBar 
        -- graphics engine from overriding or wiping our custom formatted labels.
        bar.leftText:SetText(data.name)
        
        if viewType == "HEAL" then
            local currentTotalRaid = totalRaidEffective or 1
            if currentTotalRaid == 0 then currentTotalRaid = 1 end
            local raidSharePercent = (data.effective / currentTotalRaid) * 100
            local formattedAmt = FormatDotNumber(data.effective)
            bar.rightText:SetText(string.format("%s - %.1f%%", formattedAmt, raidSharePercent))
            
        elseif viewType == "EFFICIENCY" then
            local grossHealing = data.effective + data.overheal
            local formattedNet = FormatDotNumber(data.effective)
            local formattedGross = FormatDotNumber(grossHealing)
            bar.rightText:SetText(string.format("%s / %s - %.0f%%", formattedNet, formattedGross, data.percent))
            
        elseif viewType == "MANA" then
            -- Fetch the dynamic threshold value synced by the core engine
            local currentThreshold = HealSmart_CurrentThreshold or 0

            -- Evaluate if the healer has crossed the active threshold barrier
            if data.manaUsed < currentThreshold then
                bar.rightText:SetText(string.format("%s mana - 0.0 HPM", FormatDotNumber(data.manaUsed)))
            else
                bar.rightText:SetText(string.format("%s mana - %.1f HPM", FormatDotNumber(data.manaUsed), data.hpm))
            end
        end
        
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

-- ==========================================
-- UPDATE TO BOTTOM OF healsmartui.lua
-- ==========================================
nextButton:SetScript("OnClick", function() if HealSmart_ChangePage then HealSmart_ChangePage(1) end end)
prevButton:SetScript("OnClick", function() if HealSmart_ChangePage then HealSmart_ChangePage(-1) end end)

local loaderFrame = CreateFrame("Frame")
loaderFrame:RegisterEvent("ADDON_LOADED")
loaderFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HealSmart" then
        if not HealSmartSettings then
            HealSmartSettings = { width = 200, height = HEALSMART_MIN_HEIGHT, point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0, page = 0 }
        end
        if not HealSmartSettings.page then HealSmartSettings.page = 0 end

        container:SetSize(HealSmartSettings.width, HealSmartSettings.height)
        container:ClearAllPoints()
        container:SetPoint(HealSmartSettings.point, UIParent, HealSmartSettings.relativePoint, HealSmartSettings.xOfs, HealSmartSettings.yOfs)
        scrollChild:SetWidth(container:GetWidth() - 22)
        infoText:SetWidth(container:GetWidth() - 32)
        
        if HealSmart_SetInitialPage then 
            HealSmart_SetInitialPage(HealSmartSettings.page) 
        end
        
        HealSmart_ClearDisplay()

        -- MODERN TIMING FIX: Uses Blizzard's secure C_Timer to prevent frame script errors
        C_Timer.After(1.0, function()
            scrollChild:SetWidth(container:GetWidth() - 22)
            if HealSmart_RefreshCurrentPage then 
                HealSmart_RefreshCurrentPage() 
            end
        end)

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- end healsmartui.lua