-- ==========================================
-- HealSmart - Interface Options Config Panel (v0.7.0)
-- ==========================================

local configPanel = CreateFrame("Frame", "HealSmartConfigPanel", UIParent)
configPanel.name = "HealSmart"

-- Fetch the version string directly from the .toc metadata sheet
local addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("HealSmart", "Version") or "0.7.0"

-- Create Credits Header Text
local creditsText = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
creditsText:SetPoint("TOPLEFT", 16, -6)
creditsText:SetText("HealSmart v" .. addonVersion .. " - by mimma @ EU-Pyrewood Village")
creditsText:SetTextColor(0.75, 0.75, 0.75, 1.0)

-- Create Title Layout Text
local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", creditsText, "BOTTOMLEFT", 0, -14)
title:SetText("HealSmart Configuration")

local subText = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subText:SetText("Customize your multi-session layout behaviors and history limits below.")

-- Create the Session Limit Slider Object (Range 5-100)
local slider = CreateFrame("Slider", "HealSmartSessionSlider", configPanel, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -30)
slider:SetMinMaxValues(5, 100)
slider:SetValueStep(1)
slider:SetObeyStepOnDrag(true)

local sliderLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sliderLabel:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
sliderLabel:SetText("Max Saved Sessions:")

local lowText = _G[slider:GetName() .. "Low"]
if lowText then lowText:SetText("5") end

local highText = _G[slider:GetName() .. "High"]
if highText then highText:SetText("100") end

local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)

slider:SetScript("OnValueChanged", function(self, value)
    local roundedValue = math.floor(value + 0.5)
    valueText:SetText(tostring(roundedValue))
    if HealSmartSettings then
        HealSmartSettings.maxSessionsLimit = roundedValue
        HEALSMART_MAX_SAVED_SESSIONS = roundedValue
    end
end)

-- Create Group Join Behavior Options
local groupLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
groupLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -40)
groupLabel:SetText("When joining a new Group or Raid:")
groupLabel:SetTextColor(1.0, 1.0, 1.0, 1.0)

local function CreateRadioButton(name, text, yOffset)
    local cb = CreateFrame("CheckButton", name, configPanel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", groupLabel, "BOTTOMLEFT", 0, yOffset)
    local cbText = _G[cb:GetName() .. "Text"]
    if cbText then cbText:SetText(text) end
    return cb
end

local cbDelete = CreateRadioButton("HealSmartCBDelete", "1: Automatically clear all history and start fresh", -10)
local cbKeep   = CreateRadioButton("HealSmartCBKeep", "2: Keep history and continue accumulating data", -35)
local cbAsk    = CreateRadioButton("HealSmartCBAsk", "3: Prompt me with a popup dialog window to ask", -60)

local function SyncGroupRadioButtons(selectedMode)
    cbDelete:SetChecked(selectedMode == 1)
    cbKeep:SetChecked(selectedMode == 2)
    cbAsk:SetChecked(selectedMode == 3)
    if HealSmartSettings then
        HealSmartSettings.groupJoinBehavior = selectedMode
    end
end

cbDelete:SetScript("OnClick", function() SyncGroupRadioButtons(1) end)
cbKeep:SetScript("OnClick", function() SyncGroupRadioButtons(2) end)
cbAsk:SetScript("OnClick", function() SyncGroupRadioButtons(3) end)

-- FIXED REGISTRATION: Runs strictly ONCE at the absolute final sequence of the file
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(configPanel, configPanel.name)
    Settings.RegisterAddOnCategory(category)
    HealSmart_ConfigCategoryID = category:GetID()
else
    InterfaceOptions_AddCategory(configPanel)
end

-- Hook an onboarding loader listener to populate default slider and checkbox states
local configLoader = CreateFrame("Frame")
configLoader:RegisterEvent("ADDON_LOADED")
configLoader:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HealSmart" then
        if HealSmartSettings then
            if not HealSmartSettings.maxSessionsLimit then HealSmartSettings.maxSessionsLimit = 20 end
            if not HealSmartSettings.groupJoinBehavior then HealSmartSettings.groupJoinBehavior = 3 end
            
            slider:SetValue(HealSmartSettings.maxSessionsLimit)
            HEALSMART_MAX_SAVED_SESSIONS = HealSmartSettings.maxSessionsLimit
            
            SyncGroupRadioButtons(HealSmartSettings.groupJoinBehavior)
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- end healsmartconfig.lua
