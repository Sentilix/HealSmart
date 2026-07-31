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


-- ==========================================
-- ROW 1: GROUP JOIN BEHAVIOR (LEFT) & MAX SAVED SESSIONS (RIGHT)
-- ==========================================

-- Left Column: Group Join Behavior Label
local groupLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
groupLabel:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -30)
groupLabel:SetText("When joining a new Group or Raid:")
groupLabel:SetTextColor(1.0, 1.0, 1.0, 1.0)

local function CreateRadioButton(name, text, yOffset)
    local cb = CreateFrame("CheckButton", name, configPanel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", groupLabel, "BOTTOMLEFT", 0, yOffset)
    local cbText = _G[cb:GetName() .. "Text"]
    if cbText then 
        cbText:SetText(text) 
        cbText:SetTextColor(1.0, 1.0, 1.0, 1.0)
    end
    return cb
end

local cbDelete = CreateRadioButton("HealSmartCBDelete", "Automatically clear all history", -10)
local cbKeep   = CreateRadioButton("HealSmartCBKeep", "Keep history and accumulate data", -35)
local cbAsk    = CreateRadioButton("HealSmartCBAsk", "Prompt me with a popup dialog", -60)

-- Right Column: Max Saved Sessions Slider (Shifted 300px right)
local slider = CreateFrame("Slider", "HealSmartSessionSlider", configPanel, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 300, -45)
slider:SetMinMaxValues(5, 100)
slider:SetValueStep(1)
slider:SetObeyStepOnDrag(true)

local sliderLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sliderLabel:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
sliderLabel:SetText("Max Saved Sessions:")
sliderLabel:SetTextColor(1.0, 1.0, 1.0, 1.0)

local lowText = _G[slider:GetName() .. "Low"]
if lowText then lowText:SetText("5") end

local highText = _G[slider:GetName() .. "High"]
if highText then highText:SetText("100") end

local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)


-- ==========================================
-- ROW 2: CHAT CHANNELS (LEFT) & MAX REPORT LINES (RIGHT)
-- ==========================================

-- Left Column: Chat Report Behavior Menu Labels
local chatLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
chatLabel:SetPoint("TOPLEFT", groupLabel, "BOTTOMLEFT", 0, -110) -- Placed neatly under the row 1 checkboxes
chatLabel:SetText("Report Target Channel:")
chatLabel:SetTextColor(1.0, 1.0, 1.0, 1.0)

local function CreateChatRadioButton(name, text, yOffset)
    local cb = CreateFrame("CheckButton", name, configPanel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", chatLabel, "BOTTOMLEFT", 0, yOffset)
    local cbText = _G[cb:GetName() .. "Text"]
    if cbText then 
        cbText:SetText(text) 
        cbText:SetTextColor(1.0, 1.0, 1.0, 1.0)
    end
    return cb
end

local cbAuto   = CreateChatRadioButton("HealSmartCBAuto", "/Raid or /Party (Instance)", -10)
local cbSay    = CreateChatRadioButton("HealSmartCBSay", "/say (Local Zone)", -35)
local cbYell   = CreateChatRadioButton("HealSmartCBYell", "/yell (Shout out loud)", -60)
local cbGuild  = CreateChatRadioButton("HealSmartCBGuild", "/guild (Guild members)", -85)
local cbCustom = CreateChatRadioButton("HealSmartCBCustom", "Custom Channel Number:", -110)

local customChannelBox = CreateFrame("EditBox", "HealSmartCustomChannelBox", configPanel, "InputBoxTemplate")
customChannelBox:SetSize(40, 20)
customChannelBox:SetPoint("LEFT", _G[cbCustom:GetName() .. "Text"], "RIGHT", 15, 0)
customChannelBox:SetAutoFocus(false)
customChannelBox:SetMaxLetters(3)
customChannelBox:SetNumeric(true)

-- Right Column: Max Report Lines Slider (Shifted 220px right, aligned with row 2 title)
local linesSlider = CreateFrame("Slider", "HealSmartLinesSlider", configPanel, "OptionsSliderTemplate")
linesSlider:SetPoint("TOPLEFT", chatLabel, "TOPLEFT", 300, -15)
linesSlider:SetMinMaxValues(1, 10)
linesSlider:SetValueStep(1)
linesSlider:SetObeyStepOnDrag(true)

local linesSliderLabel = linesSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
linesSliderLabel:SetPoint("BOTTOMLEFT", linesSlider, "TOPLEFT", 0, 4)
linesSliderLabel:SetText("Max Report Lines To Chat:")
linesSliderLabel:SetTextColor(1.0, 1.0, 1.0, 1.0)

local linesLowText = _G[linesSlider:GetName() .. "Low"]
if linesLowText then linesLowText:SetText("1") end

local linesHighText = _G[linesSlider:GetName() .. "High"]
if linesHighText then linesHighText:SetText("10") end

local linesValueText = linesSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
linesValueText:SetPoint("LEFT", linesSlider, "RIGHT", 10, 0)


-- ==========================================
-- CORE SYNCHRONIZATION ENGINES
-- ==========================================

local function SyncGroupRadioButtons(selectedMode)
    cbDelete:SetChecked(selectedMode == 1)
    cbKeep:SetChecked(selectedMode == 2)
    cbAsk:SetChecked(selectedMode == 3)
    if HealSmartSettings then HealSmartSettings.groupJoinBehavior = selectedMode end
end

cbDelete:SetScript("OnClick", function() SyncGroupRadioButtons(1) end)
cbKeep:SetScript("OnClick", function() SyncGroupRadioButtons(2) end)
cbAsk:SetScript("OnClick", function() SyncGroupRadioButtons(3) end)

slider:SetScript("OnValueChanged", function(self, value)
    local roundedValue = math.floor(value + 0.5)
    valueText:SetText(tostring(roundedValue))
    if HealSmartSettings then
        HealSmartSettings.maxSessionsLimit = roundedValue
        HEALSMART_MAX_SAVED_SESSIONS = roundedValue
    end
end)

local function SyncChatRadioButtons(selectedChannelMode)
    cbAuto:SetChecked(selectedChannelMode == 1)
    cbSay:SetChecked(selectedChannelMode == 2)
    cbYell:SetChecked(selectedChannelMode == 3)
    cbGuild:SetChecked(selectedChannelMode == 4)
    cbCustom:SetChecked(selectedChannelMode == 5)
    
    if selectedChannelMode == 5 then customChannelBox:Show() else customChannelBox:Hide() customChannelBox:ClearFocus() end
    if HealSmartSettings then HealSmartSettings.reportChannelMode = selectedChannelMode end
end

cbAuto:SetScript("OnClick", function() SyncChatRadioButtons(1) end)
cbSay:SetScript("OnClick", function() SyncChatRadioButtons(2) end)
cbYell:SetScript("OnClick", function() SyncChatRadioButtons(3) end)
cbGuild:SetScript("OnClick", function() SyncChatRadioButtons(4) end)
cbCustom:SetScript("OnClick", function() SyncChatRadioButtons(5) end)

customChannelBox:SetScript("OnTextChanged", function(self)
    local textNum = tonumber(self:GetText()) or 1
    if HealSmartSettings then HealSmartSettings.reportCustomChannelNum = textNum end
end)

linesSlider:SetScript("OnValueChanged", function(self, value)
    local roundedValue = math.floor(value + 0.5)
    linesValueText:SetText(tostring(roundedValue))
    if HealSmartSettings then HealSmartSettings.reportLinesLimit = roundedValue end
end)

-- Register the completed frame panel into Blizzards Addon Options sub-menu hierarchy
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(configPanel, configPanel.name)
    Settings.RegisterAddOnCategory(category)
    HealSmart_ConfigCategoryID = category:GetID()
else
    InterfaceOptions_AddCategory(configPanel)
end

-- Hook an onboarding loader listener to populate saved variables securely upon login
local configLoader = CreateFrame("Frame")
configLoader:RegisterEvent("ADDON_LOADED")
configLoader:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HealSmart" then
        if HealSmartSettings then
            if not HealSmartSettings.maxSessionsLimit then HealSmartSettings.maxSessionsLimit = 20 end
            if not HealSmartSettings.groupJoinBehavior then HealSmartSettings.groupJoinBehavior = 3 end
            if not HealSmartSettings.reportChannelMode then HealSmartSettings.reportChannelMode = 1 end
            if not HealSmartSettings.reportCustomChannelNum then HealSmartSettings.reportCustomChannelNum = 1 end
            if not HealSmartSettings.reportLinesLimit then HealSmartSettings.reportLinesLimit = 5 end
            
            slider:SetValue(HealSmartSettings.maxSessionsLimit)
            linesSlider:SetValue(HealSmartSettings.reportLinesLimit)
            HEALSMART_MAX_SAVED_SESSIONS = HealSmartSettings.maxSessionsLimit
            
            SyncGroupRadioButtons(HealSmartSettings.groupJoinBehavior)
            SyncChatRadioButtons(HealSmartSettings.reportChannelMode)
            customChannelBox:SetText(tostring(HealSmartSettings.reportCustomChannelNum))
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- end healsmartconfig.lua
