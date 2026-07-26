-- ==========================================
-- HealSmart - UI & Constants (v0.3.0 Advanced Window)
-- ==========================================

-- Sizing Constants (Easy to tweak)
HEALSMART_BAR_HEIGHT = 16
HEALSMART_BAR_GAP = 2
HEALSMART_HEADER_HEIGHT = 20
HEALSMART_OUT_OF_COMBAT_GRACE = 5

-- Minimum window limits
HEALSMART_MIN_WIDTH = 150
-- Minimum height = Header (20) + (5 bars * 16px) + (4 gaps * 2px) + padding
HEALSMART_MIN_HEIGHT = 110 

local uiBars = {}

-- 1. Create the Main Window Frame (Container)
local container = CreateFrame("Frame", "HealSmartContainer", UIParent)
container:SetSize(200, HEALSMART_MIN_HEIGHT) 
container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
container:SetClampedToScreen(true)

-- Tell the game's engine that this frame is allowed to be resized by the user
container:SetResizable(true)

-- Apply modern minimum and maximum boundaries for user resizing
if container.SetResizeBounds then
    container:SetResizeBounds(HEALSMART_MIN_WIDTH, HEALSMART_MIN_HEIGHT, 1000, 1000)
end

-- Make the window draggable via SHIFT + Drag anywhere on the background/header
container:SetMovable(true)
container:EnableMouse(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
container:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

-- Solid dark background for the main window area
local bgTexture = container:CreateTexture(nil, "BACKGROUND", nil, -8)
bgTexture:SetAllPoints(container)
bgTexture:SetColorTexture(0, 0, 0, 0.4)

-- 2. Create the Header Bar
local header = CreateFrame("Frame", nil, container)
header:SetHeight(HEALSMART_HEADER_HEIGHT)
header:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
header:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)

local headerBg = header:CreateTexture(nil, "BACKGROUND")
headerBg:SetAllPoints(header)
headerBg:SetColorTexture(0.05, 0.15, 0.3, 1.0) -- Dark Navy Blue Background

local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
headerText:SetPoint("LEFT", header, "LEFT", 6, 0)
headerText:SetText("HealSmart v0.3.0")
headerText:SetTextColor(1, 1, 1, 1) 

-- 3. Create the Scrollable Area (ScrollFrame & ScrollChild)
local scrollFrame = CreateFrame("ScrollFrame", "HealSmartScrollFrame", container, "UIPanelScrollFrameTemplate")
-- We leave 20 pixels of free space on the right for the scrollbar to live inside the window
scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -20, 2) 

-- VISUAL FIX: Anchor the scrollbar so it stops cleanly ABOVE the resize button area
if HealSmartScrollFrameScrollBar then
    local sb = HealSmartScrollFrameScrollBar
    sb:ClearAllPoints()
    -- Top anchors just below the navy header
    sb:SetPoint("TOPRIGHT", container, "TOPRIGHT", -2, -HEALSMART_HEADER_HEIGHT - 4)
    -- Bottom anchors 20 pixels above the container's real bottom, leaving a perfect gap for the resize icon
    sb:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 20)
    
    if HealSmartScrollFrameScrollBarScrollUpButton then HealSmartScrollFrameScrollBarScrollUpButton:Hide() end
    if HealSmartScrollFrameScrollBarScrollDownButton then HealSmartScrollFrameScrollBarScrollDownButton:Hide() end
end

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(container:GetWidth() - 22, 1) 
scrollFrame:SetScrollChild(scrollChild)

-- 4. Create the Interactive Resize Handle (Bottom-Right Corner - CLEAN FIX)
local resizeButton = CreateFrame("Button", nil, container)
resizeButton:SetSize(16, 16)
-- NEW POINT: Shifted slightly left (-4px) so it sits flawlessly inside the window right next to the scrollbar
resizeButton:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 2)
resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")

-- Ensure the resize grabber icon draws on top of any overlapping backgrounds
resizeButton:SetFrameLevel(scrollFrame:GetFrameLevel() + 5)

resizeButton:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        container:StartSizing("BOTTOMRIGHT")
    end
end)
resizeButton:SetScript("OnMouseUp", function(self, button)
    container:StopMovingOrSizing()
    local targetWidth = container:GetWidth() - 22
    scrollChild:SetWidth(targetWidth)
    for _, bar in ipairs(uiBars) do
        bar:SetWidth(targetWidth)
        if bar.UpdateBorders then bar:UpdateBorders(targetWidth) end
    end
end)

-- Helper function to draw 1px borders using textures
local function CreateBorderLine(parent, point, relativePoint, x, y, width, height)
    local line = parent:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(0, 0, 0, 0.9)
    line:SetPoint(point, parent, relativePoint, x, y)
    line:SetSize(width, height)
end

-- 5. Factory function to create an individual healer bar inside the scroll child
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

    local leftText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    leftText:SetPoint("LEFT", statusBar, "LEFT", 4, 0)
    leftText:SetJustifyH("LEFT")

    local rightText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rightText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    rightText:SetJustifyH("RIGHT")

    bar.statusBar = statusBar
    bar.leftText = leftText
    bar.rightText = rightText
    bar.UpdateBorders = UpdateBarBorders

    uiBars[index] = bar
    return bar
end

-- ==========================================
-- Global Functions (Called by core engine)
-- ==========================================

function HealSmart_RenderRaidBars(sortedData)
    for _, bar in ipairs(uiBars) do
        bar:Hide()
    end

    local totalHeight = #sortedData * (HEALSMART_BAR_HEIGHT + HEALSMART_BAR_GAP)
    scrollChild:SetHeight(totalHeight)

    local targetWidth = container:GetWidth() - 22

    for i, data in ipairs(sortedData) do
        local bar = uiBars[i] or CreateHealerBar(i)
        
        bar:SetWidth(targetWidth)
        if bar.UpdateBorders then bar:UpdateBorders(targetWidth) end
        
        local color = RAID_CLASS_COLORS[data.class] or {r = 0.5, g = 0.5, b = 0.5}
        
        bar.statusBar:SetStatusBarColor(color.r, color.g, color.b, 1.0)
        bar.statusBar:SetValue(data.percent)
        bar.leftText:SetText(data.name)
        bar.rightText:SetText(string.format("%.0f%%", data.percent))
        
        bar:Show()
    end
end

function HealSmart_ClearDisplay()
    for _, bar in ipairs(uiBars) do
        bar:Hide()
    end
    scrollChild:SetHeight(1)
end

HealSmart_ClearDisplay()

-- end healsmartui.lua