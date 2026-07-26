-- ==========================================
-- HealSmart - UI & Constants
-- ==========================================

-- Global constants (Easy to modify or convert to settings later)
HEALSMART_WINDOW_WIDTH = 200
HEALSMART_WINDOW_HEIGHT = 16 
HEALSMART_OUT_OF_COMBAT_GRACE = 5 -- Seconds to keep tracking after combat ends

-- Colors (Red, Green, Blue, Alpha)
local COLOR_EFFECTIVE = {0.1, 0.5, 0.9, 1.0}   -- Light blue (Effective healing)

-- 1. Create Main Frame (Window)
local frame = CreateFrame("Frame", "HealSmartMainFrame", UIParent)
frame:SetSize(HEALSMART_WINDOW_WIDTH, HEALSMART_WINDOW_HEIGHT)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) -- Starts at the center of the screen

-- Make the window draggable (Hold SHIFT down to move)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then
        self:StartMoving()
    end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- Modern UI Approach: Create background using Textures
local bgTexture = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
bgTexture:SetAllPoints(frame)
bgTexture:SetColorTexture(0, 0, 0, 0.6) -- Semi-transparent black window background (Overheal area)

-- Create a 1-pixel black border outline using textures
local function CreateBorderLine(parent, point, relativePoint, x, y, width, height)
    local line = parent:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(0, 0, 0, 0.9) -- Dark border color
    line:SetPoint(point, parent, relativePoint, x, y)
    line:SetSize(width, height)
end
CreateBorderLine(frame, "TOPLEFT", "TOPLEFT", 0, 0, HEALSMART_WINDOW_WIDTH, 1) -- Top border
CreateBorderLine(frame, "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, HEALSMART_WINDOW_WIDTH, 1) -- Bottom border
CreateBorderLine(frame, "TOPLEFT", "TOPLEFT", 0, 0, 1, HEALSMART_WINDOW_HEIGHT) -- Left border
CreateBorderLine(frame, "TOPRIGHT", "TOPRIGHT", 0, 0, 1, HEALSMART_WINDOW_HEIGHT) -- Right border

-- 2. Create the Status Bar (Meters)
local statusBar = CreateFrame("StatusBar", nil, frame)
statusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
statusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
statusBar:SetMinMaxValues(0, 100)

-- Apply the requested color scheme
statusBar:SetStatusBarColor(unpack(COLOR_EFFECTIVE)) -- Light blue fill

-- 3. Create the Text String overlay (Adjusted to Small font to fit 16px bar perfectly)
local text = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
text:SetPoint("CENTER", statusBar, "CENTER", 0, 0)
text:SetText("--%")

-- ==========================================
-- Global Functions (Callable by core file)
-- ==========================================

-- Update the bar display based on calculations
function HealSmart_UpdateBar(effectivePercent, textString)
    if effectivePercent > 100 then effectivePercent = 100 end
    if effectivePercent < 0 then effectivePercent = 0 end
    
    statusBar:SetValue(effectivePercent)
    text:SetText(textString)
end

-- Initialize with no healing text
HealSmart_UpdateBar(0, "--%")

-- end healsmartui.lua