-- ==========================================
-- HeroStats - Interface Options Config Panel (v1.0.0a3)
-- ==========================================

local configPanel = CreateFrame("Frame", "HeroStatsConfigPanel", UIParent)
configPanel.name = "HeroStats"

-- Fetch the version string directly from the .toc metadata sheet
local addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("HeroStats", "Version") or "1.0.0a3"

-- Create Credits Header Text
local creditsText = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
local addonAuthor = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("HeroStats", "Author") or "mimma"
creditsText:SetPoint("TOPLEFT", 16, -6)
creditsText:SetText("HeroStats v" .. addonVersion .. " - by " .. addonAuthor)
creditsText:SetTextColor(0.75, 0.75, 0.75, 1.0)

-- Create Title Layout Text
local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", creditsText, "BOTTOMLEFT", 0, -14)
title:SetText("HeroStats Configuration")

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
groupLabel:SetTextColor(1.0, 0.82, 0.0, 1.0) -- 1. FARVESKIFT: Symmetrical Gold Header

-- RESTORED v1.0.0a2: Reverts strictly back to your trusted, working interface template name
local function CreateRadioButton(name, text, yOffset)
    local cb = CreateFrame("CheckButton", name, configPanel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", groupLabel, "BOTTOMLEFT", 0, yOffset)
    local cbText = _G[cb:GetName() .. "Text"]
    if cbText then 
        cbText:SetText(text) 
        cbText:SetTextColor(1.0, 1.0, 1.0, 1.0) -- White text choice layout
    end
    return cb
end

local cbDelete = CreateRadioButton("HeroStatsCBDelete", "Automatically clear all history", -10)
local cbKeep   = CreateRadioButton("HeroStatsCBKeep", "Keep history and accumulate data", -35)
local cbAsk    = CreateRadioButton("HeroStatsCBAsk", "Prompt me with a popup dialog", -60)

-- Right Column: Max Saved Sessions Slider (Shifted 300px right)
local slider = CreateFrame("Slider", "HeroStatsSessionSlider", configPanel, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 300, -45)
slider:SetMinMaxValues(5, 100)
slider:SetValueStep(1)
slider:SetObeyStepOnDrag(true)

local sliderLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sliderLabel:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
sliderLabel:SetText("Max Saved Sessions:")
sliderLabel:SetTextColor(1.0, 0.82, 0.0, 1.0) -- 2. FARVESKIFT: Symmetrical Gold Header

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
chatLabel:SetPoint("TOPLEFT", groupLabel, "BOTTOMLEFT", 0, -110)
chatLabel:SetText("Report Target Channel:")
chatLabel:SetTextColor(1.0, 0.82, 0.0, 1.0) -- 3. FARVESKIFT: Symmetrical Gold Header

-- RESTORED v1.0.0a2: Reverts strictly back to your trusted, working interface template name
local function CreateChatRadioButton(name, text, yOffset)
    local cb = CreateFrame("CheckButton", name, configPanel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", chatLabel, "BOTTOMLEFT", 0, yOffset)
    local cbText = _G[cb:GetName() .. "Text"]
    if cbText then 
        cbText:SetText(text) 
        cbText:SetTextColor(1.0, 1.0, 1.0, 1.0) -- White text choice layout
    end
    return cb
end

local cbAuto   = CreateChatRadioButton("HeroStatsCBAuto", "/Raid or /Party (Instance)", -10)
local cbSay    = CreateChatRadioButton("HeroStatsCBSay", "/say (Local Zone)", -35)
local cbGuild  = CreateChatRadioButton("HeroStatsCBGuild", "/guild (Guild members)", -60)
local cbOfficer = CreateChatRadioButton("HeroStatsCBOfficer", "/officer (Officer chat)", -85)
local cbCustom = CreateChatRadioButton("HeroStatsCBCustom", "Custom Channel Number:", -110)

local customChannelBox = CreateFrame("EditBox", "HeroStatsCustomChannelBox", configPanel, "InputBoxTemplate")
customChannelBox:SetSize(40, 20)
customChannelBox:SetPoint("LEFT", _G[cbCustom:GetName() .. "Text"], "RIGHT", 15, 0)
customChannelBox:SetAutoFocus(false)
customChannelBox:SetMaxLetters(3)
customChannelBox:SetNumeric(true)

-- Right Column: Max Report Lines Slider (Shifted 300px right, aligned with row 2 title)
local linesSlider = CreateFrame("Slider", "HeroStatsLinesSlider", configPanel, "OptionsSliderTemplate")
linesSlider:SetPoint("TOPLEFT", chatLabel, "TOPLEFT", 300, -15)
linesSlider:SetMinMaxValues(1, 10)
linesSlider:SetValueStep(1)
linesSlider:SetObeyStepOnDrag(true)

local linesSliderLabel = linesSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
linesSliderLabel:SetPoint("BOTTOMLEFT", linesSlider, "TOPLEFT", 0, 4)
linesSliderLabel:SetText("Max Report Lines To Chat:")
linesSliderLabel:SetTextColor(1.0, 0.82, 0.0, 1.0) -- 4. FARVESKIFT: Symmetrical Gold Header

local linesLowText = _G[linesSlider:GetName() .. "Low"]
if linesLowText then linesLowText:SetText("1") end

local linesHighText = _G[linesSlider:GetName() .. "High"]
if linesHighText then linesHighText:SetText("10") end

local linesValueText = linesSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
linesValueText:SetPoint("LEFT", linesSlider, "RIGHT", 10, 0)


-- ==========================================
-- RADIO CORE LOGIC & INITIAL SYNCHRONIZATION
-- ==========================================

local function SyncGroupRadioButtons(selectedMode)
    cbDelete:SetChecked(selectedMode == 1)
    cbKeep:SetChecked(selectedMode == 2)
    cbAsk:SetChecked(selectedMode == 3)
    if HeroStatsSettings then HeroStatsSettings.groupJoinBehavior = selectedMode end
end

cbDelete:SetScript("OnClick", function() SyncGroupRadioButtons(1) end)
cbKeep:SetScript("OnClick", function() SyncGroupRadioButtons(2) end)
cbAsk:SetScript("OnClick", function() SyncGroupRadioButtons(3) end)

slider:SetScript("OnValueChanged", function(self, value)
    local roundedValue = math.floor(value + 0.5)
    valueText:SetText(tostring(roundedValue))
    if HeroStatsSettings then
        HeroStatsSettings.maxSessionsLimit = roundedValue
        HEROSTATS_MAX_SAVED_SESSIONS = roundedValue
    end
end)

-- ==========================================
-- ROW 3: PERSONAL RECORDS NOTIFICATIONS (LEFT COLUMN)
-- ==========================================

-- Create Section Label Layout anchored cleanly under Row 2's chat checkboxes layout area
local notifyLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
notifyLabel:SetPoint("TOPLEFT", chatLabel, "BOTTOMLEFT", 0, -145) -- Safely clears row 2 dropdown spacing
notifyLabel:SetText("Personal Record Alerts & Pings:")
notifyLabel:SetTextColor(1.0, 0.82, 0.0, 1.0) -- 5. FARVESKIFT: Symmetrical Gold Header

-- 1. RADIO BUTTON: MUTE ALL (Mode 1)
-- RESTORED v1.0.0a2: Uses your trusted working framework template securely
local cbRecNone = CreateFrame("CheckButton", "HeroStats_RadioRecNone", configPanel, "InterfaceOptionsCheckButtonTemplate")
cbRecNone:SetPoint("TOPLEFT", notifyLabel, "BOTTOMLEFT", 0, -10)
local textNone = _G[cbRecNone:GetName() .. "Text"]
if textNone then
    textNone:SetText("Mute All Alerts (Silent Mode)")
    textNone:SetTextColor(1.0, 1.0, 1.0, 1.0) -- Crisp White choice label text
end

-- 2. RADIO BUTTON: LOCAL ALERTS (Mode 2)
-- RESTORED v1.0.0a2: Uses your trusted working framework template securely
local cbRecLocal = CreateFrame("CheckButton", "HeroStats_RadioRecLocal", configPanel, "InterfaceOptionsCheckButtonTemplate")
cbRecLocal:SetPoint("TOPLEFT", cbRecNone, "BOTTOMLEFT", 0, -8)
local textLocal = _G[cbRecLocal:GetName() .. "Text"]
if textLocal then
    textLocal:SetText("Local Chat & Audio Pings Only")
    textLocal:SetTextColor(1.0, 1.0, 1.0, 1.0) -- Crisp White choice label text
end

-- 3. RADIO BUTTON: GROUP ANNOUNCE (Mode 3)
-- RESTORED v1.0.0a2: Uses your trusted working framework template securely
local cbRecGroup = CreateFrame("CheckButton", "HeroStats_RadioRecGroup", configPanel, "InterfaceOptionsCheckButtonTemplate")
cbRecGroup:SetPoint("TOPLEFT", cbRecLocal, "BOTTOMLEFT", 0, -8)
local textGroup = _G[cbRecGroup:GetName() .. "Text"]
if textGroup then
    textGroup:SetText("Announce to Active Raid/Party Chat")
    textGroup:SetTextColor(1.0, 1.0, 1.0, 1.0) -- Crisp White choice label text
end


-- ==========================================
-- RADIO ENGINE & DATABASE SYNCHRONIZATION
-- ==========================================

local function SyncChatRadioButtons(selectedChannelMode)
    cbAuto:SetChecked(selectedChannelMode == 1)
    cbSay:SetChecked(selectedChannelMode == 2)
    cbGuild:SetChecked(selectedChannelMode == 3)
    cbOfficer:SetChecked(selectedChannelMode == 4)
    cbCustom:SetChecked(selectedChannelMode == 5)
    
    if selectedChannelMode == 5 then 
        customChannelBox:Show() 
    else 
        customChannelBox:Hide() 
        customChannelBox:ClearFocus() 
    end
    if HeroStatsSettings then HeroStatsSettings.reportChannelMode = selectedChannelMode end
end

cbAuto:SetScript("OnClick", function() SyncChatRadioButtons(1) end)
cbSay:SetScript("OnClick", function() SyncChatRadioButtons(2) end)
cbGuild:SetScript("OnClick", function() SyncChatRadioButtons(3) end)
cbOfficer:SetScript("OnClick", function() SyncChatRadioButtons(4) end)
cbCustom:SetScript("OnClick", function() SyncChatRadioButtons(5) end)

customChannelBox:SetScript("OnTextChanged", function(self)
    local textNum = tonumber(self:GetText()) or 1
    if HeroStatsSettings then HeroStatsSettings.reportCustomChannelNum = textNum end
end)

linesSlider:SetScript("OnValueChanged", function(self, value)
    local roundedValue = math.floor(value + 0.5)
    linesValueText:SetText(tostring(roundedValue))
    if HeroStatsSettings then HeroStatsSettings.reportLinesLimit = roundedValue end
end)

-- Helper function to toggle the record radio state visually and save dynamically
local function HeroStats_UpdateNotificationRadioButtons(activeMode)
    if HeroStatsSettings then
        HeroStatsSettings.recordNotifyMode = activeMode
    end
    
    if cbRecNone then cbRecNone:SetChecked(activeMode == 1) end
    if cbRecLocal then cbRecLocal:SetChecked(activeMode == 2) end
    if cbRecGroup then cbRecGroup:SetChecked(activeMode == 3) end
end

cbRecNone:SetScript("OnClick", function()
    HeroStats_UpdateNotificationRadioButtons(1)
    PlaySound(856)
end)

cbRecLocal:SetScript("OnClick", function()
    HeroStats_UpdateNotificationRadioButtons(2)
    PlaySound(856)
end)

cbRecGroup:SetScript("OnClick", function()
    HeroStats_UpdateNotificationRadioButtons(3)
    PlaySound(856)
end)

-- ON-SHOW PIPELINE: Read database state dynamically when opening options panel
local function HeroStats_RefreshRadioVisuals()
    if not HeroStatsSettings then return end
    local currentMode = HeroStatsSettings.recordNotifyMode or 2
    HeroStats_UpdateNotificationRadioButtons(currentMode)
end

configPanel:HookScript("OnShow", HeroStats_RefreshRadioVisuals)


-- ==========================================
-- BLIZZARD INTERFACE REGISTRATION PIPELINE
-- ==========================================

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(configPanel, configPanel.name)
    Settings.RegisterAddOnCategory(category)
    HeroStats_ConfigCategoryID = category:GetID()
else
    InterfaceOptions_AddCategory(configPanel)
end


-- ==========================================
-- RESET ENGINE & EMERGENCY PURGE MODULE
-- ==========================================

local btnResetRecords = CreateFrame("Button", "HeroStatsResetRecordsButton", configPanel, "UIPanelButtonTemplate")
btnResetRecords:SetSize(160, 24)
btnResetRecords:SetPoint("TOPLEFT", cbCustom, "BOTTOMLEFT", 0, -225) -- Shifted down to clear Row 3 nicely!
btnResetRecords:SetText("Reset Personal Records")

StaticPopupDialogs["HEROSTATS_PURGE_RECORDS_CONFIRM"] = {
    text = "WARNING: Are you sure you want to permanently delete ALL your historical personal records and Critline milestones?",
    button1 = "Yes, Purge My Records",
    button2 = "No, Cancel",
    OnAccept = function()
        if HeroStatsSettings then
            HeroStatsSettings.personalDamageRecords = {}
            HeroStatsSettings.personalHealingRecords = {}
            if HeroStats_Print then
                HeroStats_Print("Your historical Personal Damage and Healing Records have been completely purged.")
            end
            if coreFrame and coreFrame.RefreshStats then 
                coreFrame.RefreshStats() 
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

btnResetRecords:SetScript("OnClick", function()
    StaticPopup_Show("HEROSTATS_PURGE_RECORDS_CONFIRM")
end)


-- ==========================================
-- SYSTEM ONBOARDING FRAME LOADER
-- ==========================================

local configLoader = CreateFrame("Frame")
configLoader:RegisterEvent("ADDON_LOADED")
configLoader:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HeroStats" then
        if HeroStatsSettings then
            HeroStatsSettings.activeFilterState = HeroStatsSettings.activeFilterState or 1
            if not HeroStatsSettings.maxSessionsLimit then HeroStatsSettings.maxSessionsLimit = 20 end
            if not HeroStatsSettings.groupJoinBehavior then HeroStatsSettings.groupJoinBehavior = 3 end
            if not HeroStatsSettings.reportChannelMode then HeroStatsSettings.reportChannelMode = 1 end
            if not HeroStatsSettings.reportCustomChannelNum then HeroStatsSettings.reportCustomChannelNum = 1 end
            if not HeroStatsSettings.reportLinesLimit then HeroStatsSettings.reportLinesLimit = 5 end
            if not HeroStatsSettings.personalDamageRecords then HeroStatsSettings.personalDamageRecords = {} end
            if not HeroStatsSettings.personalHealingRecords then HeroStatsSettings.personalHealingRecords = {} end
            if not HeroStatsSettings.recordNotifyMode then HeroStatsSettings.recordNotifyMode = 2 end

            slider:SetValue(HeroStatsSettings.maxSessionsLimit)
            linesSlider:SetValue(HeroStatsSettings.reportLinesLimit)
            HEROSTATS_MAX_SAVED_SESSIONS = HeroStatsSettings.maxSessionsLimit
            
            if SyncGroupRadioButtons then SyncGroupRadioButtons(HeroStatsSettings.groupJoinBehavior) end
            if SyncChatRadioButtons then SyncChatRadioButtons(HeroStatsSettings.reportChannelMode) end
            if HeroStats_RefreshRadioVisuals then HeroStats_RefreshRadioVisuals() end
            
            customChannelBox:SetText(tostring(HeroStatsSettings.reportCustomChannelNum))
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- end herostatsconfig.lua
