-- ==========================================
-- HealSmart - Core Engine (v0.6.0) - PART 1 & 2 (Global Variable Framework)
-- ==========================================

-- Configuration Constants
HEALSMART_MAX_SAVED_SESSIONS = 20

-- NEW GLOBAL CHECKPOINT: Declared globally at birth so healsmartsession.lua can write to it
HealSmart_SelectedViewSessionID = 0 

-- Runtime cache objects
local groupRosterCache = {}
local currentFilterMode = "ALL"
local currentActivePage = 0 
local _, playerClassFilename = UnitClass("player")

local ALLOWED_CLASSES = {
    ["PRIEST"] = true,
    ["PALADIN"] = true,
    ["DRUID"] = true,
    ["SHAMAN"] = true
}

local SPELL_CLASS_CACHE = {
    ["Healing Wave"] = "SHAMAN", ["Lesser Healing Wave"] = "SHAMAN", ["Chain Heal"] = "SHAMAN",
    ["Lesser Heal"] = "PRIEST", ["Heal"] = "PRIEST", ["Flash Heal"] = "PRIEST", ["Greater Heal"] = "PRIEST", ["Renew"] = "PRIEST", ["Prayer of Healing"] = "PRIEST", ["Power Word: Shield"] = "PRIEST",
    ["Healing Touch"] = "DRUID", ["Rejuvenation"] = "DRUID", ["Regrowth"] = "DRUID",
    ["Flash of Light"] = "PALADIN", ["Holy Light"] = "PALADIN"
}

local coreFrame = CreateFrame("Frame")

-- Multi-Session Profile Factory: Securely fetches or creates data rows within any sub-table target
function HealSmart_GetOrCreateProfile(dataTable, guid, name, classToken)
    if not dataTable then return nil end
    if not dataTable[guid] then
        local unitToken = "player"
        if guid ~= UnitGUID("player") then
            if IsInRaid() then
                for i = 1, GetNumGroupMembers() do
                    if UnitGUID("raid"..i) == guid then unitToken = "raid"..i break end
                end
            else
                for i = 1, GetNumGroupMembers() - 1 do
                    if UnitGUID("party"..i) == guid then unitToken = "party"..i break end
                end
            end
        end

        dataTable[guid] = {
            name = name,
            class = classToken or "SHAMAN",
            effective = 0,
            overheal = 0,
            percent = 0,
            unitId = unitToken,
            manaUsed = 0,
            hpm = 0
        }
    end
    return dataTable[guid]
end

-- Helper interface to grab the active writing combat healer block
function HealSmart_GetActiveSessionHealers()
    if HealSmartSettings and HealSmartSettings.sessions and HealSmartSettings.activeSessionIndex then
        local activeSession = HealSmartSettings.sessions[HealSmartSettings.activeSessionIndex]
        if activeSession then
            return activeSession.healers
        end
    end
    return nil
end

local function UpdateGroupRosterCache()
    table.wipe(groupRosterCache)
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")
    if playerName and playerClass then groupRosterCache[playerName] = playerClass end
    
    local numGroupMembers = GetNumGroupMembers()
    if numGroupMembers > 0 then
        local isRaid = IsInRaid()
        local prefix = isRaid and "raid" or "party"
        local loopMax = isRaid and numGroupMembers or (numGroupMembers - 1)
        for i = 1, loopMax do
            local unit = prefix .. i
            local name = UnitName(unit)
            if name then
                local _, classToken = UnitClass(unit)
                if classToken then groupRosterCache[name] = classToken end
            end
        end
    end
end

-- --- PART 2: Core Data Processing ---
local sortedHealers = {}

coreFrame.RefreshStats = function()
    if currentActivePage == 0 then
        local welcomeMessage = "Welcome to HealSmart!\n\nUse the < and > arrows to switch pages.\n\nFights are saved automatically up to 20 sessions."
        if HealSmart_RenderTextMessage then HealSmart_RenderTextMessage("HealSmart v0.6.0", welcomeMessage) end
        return
    end

    table.wipe(sortedHealers)
    local topHealerAmount = 0
    local totalRaidEffective = 0 
    local topHPMValue = 0 

    local activeThreshold = HEALSMART_MANA_THRESHOLD or 300
    if not IsInGroup() then activeThreshold = 0 end

    local dataSourceTable = nil
    local sessionLabel = "Current Fight"

    -- FIXED LOGIC: Query the global HealSmart_SelectedViewSessionID token securely
    if HealSmart_SelectedViewSessionID == -1 then
        dataSourceTable = HealSmartSettings and HealSmartSettings.overallData
        sessionLabel = "Overall Total"
    else
        if HealSmartSettings and HealSmartSettings.sessions then
            local targetIdx = HealSmartSettings.activeSessionIndex or 1
            if HealSmart_SelectedViewSessionID > 0 then
                for idx, session in ipairs(HealSmartSettings.sessions) do
                    if session.id == HealSmart_SelectedViewSessionID then
                        targetIdx = idx
                        sessionLabel = "Fight #" .. session.id
                        break
                    end
                end
            end
            local sessionData = HealSmartSettings.sessions[targetIdx]
            dataSourceTable = sessionData and sessionData.healers
        end
    end

    if dataSourceTable then
        for guid, data in pairs(dataSourceTable) do
            if currentFilterMode == "CLASS" and data.class ~= playerClassFilename then
                -- Filtered
            else
                local total = data.effective + data.overheal
                data.percent = (total > 0) and ((data.effective / total) * 100) or 0
                data.manaUsed = data.manaUsed or 0

                if data.manaUsed > 0 then
                    data.hpm = data.effective / data.manaUsed
                    if data.manaUsed >= activeThreshold then
                        if data.hpm > topHPMValue then topHPMValue = data.hpm end
                    end
                else
                    data.hpm = 0
                end

                table.insert(sortedHealers, data)
                totalRaidEffective = totalRaidEffective + data.effective
                if data.effective > topHealerAmount then topHealerAmount = data.effective end
            end
        end
    end

    if #sortedHealers == 0 then
        local pageTitle = "HealSmart"
        if currentActivePage == 1 then pageTitle = "1. Healing Done"
        elseif currentActivePage == 2 then pageTitle = "2. Heal vs Overheal"
        elseif currentActivePage == 3 then pageTitle = "3. Mana Efficiency" end
        pageTitle = pageTitle .. " (" .. sessionLabel .. ")"
        if HealSmart_RenderTextMessage then HealSmart_RenderTextMessage(pageTitle, "") end
        return
    end

    local viewTitle = ""
    if currentActivePage == 1 then viewTitle = "1. Healing Done ("..sessionLabel..")"
    elseif currentActivePage == 2 then viewTitle = "2. Heal vs Overheal ("..sessionLabel..")"
    elseif currentActivePage == 3 then viewTitle = "3. Mana Efficiency ("..sessionLabel..")" end

    if currentActivePage == 1 then
        table.sort(sortedHealers, function(a, b) return (a.effective == b.effective) and (a.name < b.name) or (a.effective > b.effective) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topHealerAmount, "HEAL", totalRaidEffective, viewTitle) end
    elseif currentActivePage == 2 then
        table.sort(sortedHealers, function(a, b) return (a.percent == b.percent) and (a.name < b.name) or (a.percent > b.percent) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, 0, "EFFICIENCY", 0, viewTitle) end
    elseif currentActivePage == 3 then
        table.sort(sortedHealers, function(a, b) return (a.hpm == b.hpm) and (a.name < b.name) or (a.hpm > b.hpm) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topHPMValue, "MANA", 0, viewTitle) end
    end
end

function HealSmart_ChangePage(direction)
    currentActivePage = currentActivePage + direction
    if currentActivePage > 3 then currentActivePage = 0 end
    if currentActivePage < 0 then currentActivePage = 3 end
    if HealSmartSettings then HealSmartSettings.page = currentActivePage end
    HealSmart_RefreshCurrentPage()
end

function HealSmart_ToggleClassFilter()
    if currentFilterMode == "ALL" then currentFilterMode = "CLASS" else currentFilterMode = "ALL" end
    if coreFrame.RefreshStats then coreFrame.RefreshStats() end
    return currentFilterMode
end

-- ==========================================
-- HealSmart - Core Engine (v0.6.0) - PART 3A
-- ==========================================

local isSessionActive = false      
local inTrueCombat = false         
local timeSinceCombatEnd = 0

local function GetLiveSpellManaCost(spellID)
    if not spellID then return 0 end
    local costTable = GetSpellPowerCost(spellID)
    if costTable then
        for _, costInfo in ipairs(costTable) do
            if costInfo.type == 0 and costInfo.cost then return costInfo.cost end
        end
    end
    return 0
end

local function OnCombatLogEvent()
    if not isSessionActive then return end

    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    -- Fetch the active writing sub-table for the current active fight session
    local activeHealers = HealSmart_GetActiveSessionHealers()
    if not activeHealers then return end

    -- --- HYBRID MANA WATCH ENGINE ---
    if eventType == "SPELL_CAST_SUCCESS" then
        local spellID, spellName, _ = select(12, CombatLogGetCurrentEventInfo())
        
        local isGroupMember = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                              (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                              (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isGroupMember and sourceName then
            local dbData = nil
            if spellID and HealSmart_SpellCostDB then dbData = HealSmart_SpellCostDB[spellID] end
            
            local classFilename = dbData and dbData.class or SPELL_CLASS_CACHE[spellName]
            
            if classFilename and ALLOWED_CLASSES[classFilename] then
                local cleanName = string.match(sourceName, "([^-]+)")
                
                -- Log directly to current combat session
                local healer = HealSmart_GetOrCreateProfile(activeHealers, sourceGUID, cleanName, classFilename)
                local cost = spellID and GetLiveSpellManaCost(spellID) or 0
                if cost == 0 and dbData then cost = dbData.cost or 0 end
                
                if cost == 0 and spellName then
                    if spellName == "Healing Wave" then cost = 25
                    elseif spellName == "Lesser Healing Wave" then cost = 105
                    elseif spellName == "Chain Heal" then cost = 260
                    elseif spellName == "Flash Heal" or spellName == "Lesser Heal" or spellName == "Renew" then cost = 30
                    elseif spellName == "Heal" then cost = 90
                    elseif spellName == "Greater Heal" then cost = 370
                    elseif spellName == "Prayer of Healing" then cost = 410
                    elseif spellName == "Power Word: Shield" then cost = 45
                    elseif spellName == "Healing Touch" or spellName == "Rejuvenation" or spellName == "Regrowth" then cost = 25
                    elseif spellName == "Flash of Light" or spellName == "Holy Light" then cost = 35 end
                end
                
                healer.manaUsed = healer.manaUsed + cost
                
                -- Log simultaneously to the un-resetted Overall Total table
                if HealSmartSettings and HealSmartSettings.overallData then
                    local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, sourceGUID, cleanName, classFilename)
                    overallHealer.manaUsed = overallHealer.manaUsed + cost
                end
                
                coreFrame.RefreshStats()
            end
        end

    -- --- A: DIRECT HEALS & HOTS ---
    elseif eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL" then
        local _, spellName, _, amount, overheal = select(12, CombatLogGetCurrentEventInfo())
        
        overheal = overheal or 0
        amount = amount or 0
        local effective = amount - overheal
        if effective < 0 then effective = 0 end

        local isGroupMember = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                              (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                              (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isGroupMember and sourceName then
            local cleanName = string.match(sourceName, "([^-]+)")
            local classFilename = groupRosterCache[cleanName] or SPELL_CLASS_CACHE[spellName]

            if classFilename and ALLOWED_CLASSES[classFilename] then
                -- Log to current session
                local healer = HealSmart_GetOrCreateProfile(activeHealers, sourceGUID, cleanName, classFilename)
                healer.effective = healer.effective + effective
                healer.overheal = healer.overheal + overheal
                
                -- Log to overall total accumulation variables
                if HealSmartSettings and HealSmartSettings.overallData then
                    local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, sourceGUID, cleanName, classFilename)
                    overallHealer.effective = overallHealer.effective + effective
                    overallHealer.overheal = overallHealer.overheal + overheal
                end
                
                coreFrame.RefreshStats()
            end
        end

    -- --- B: SHIELDS & ABSORBS ---
    elseif eventType == "SPELL_ABSORBED" then
        local allArgs = { CombatLogGetCurrentEventInfo() }
        local shieldCasterGUID, shieldCasterName, shieldCasterFlags, shieldAbsorbAmount, absorbSpellName
        
        local numArgs = #allArgs
        if numArgs >= 19 then
            absorbSpellName = allArgs[numArgs - 2]
            shieldCasterGUID = allArgs[numArgs - 7]
            shieldCasterName = allArgs[numArgs - 6]
            shieldCasterFlags = allArgs[numArgs - 5]
            shieldAbsorbAmount = allArgs[numArgs]
        end

        if absorbSpellName == "Power Word: Shield" and shieldCasterGUID and shieldAbsorbAmount and shieldCasterGUID ~= "" and shieldCasterName then
            local isGroupMember = (bit.band(shieldCasterFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                  (bit.band(shieldCasterFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                  (bit.band(shieldCasterFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

            if isGroupMember then
                local cleanName = string.match(shieldCasterName, "([^-]+)")
                
                -- Log to current session
                local healer = HealSmart_GetOrCreateProfile(activeHealers, shieldCasterGUID, cleanName, "PRIEST")
                healer.effective = healer.effective + shieldAbsorbAmount
                
                -- Log to overall total
                if HealSmartSettings and HealSmartSettings.overallData then
                    local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, shieldCasterGUID, cleanName, "PRIEST")
                    overallHealer.effective = overallHealer.effective + shieldAbsorbAmount
                end
                
                coreFrame.RefreshStats()
            end
        end
    end
end

-- ==========================================
-- HealSmart - Core Engine (v0.6.0) - PART 3B
-- ==========================================

-- NEW SESSION GENERATOR PIPELINE: Runs securely when pulling threat / entering combat
local function HealSmart_CreateNewSession()
    if not HealSmartSettings or not HealSmartSettings.sessions then return end
    
    HealSmartSettings.activeSessionID = (HealSmartSettings.activeSessionID or 0) + 1
    
    local zoneName = GetZoneText() or "Unknown Area"
    local encounterName = UnitName("target") or "Trash Mob"
    local sessionName = encounterName .. " (" .. zoneName .. ")"
    
    local newSessionBlock = {
        id = HealSmartSettings.activeSessionID,
        name = sessionName,
        healers = {}
    }
    
    table.insert(HealSmartSettings.sessions, newSessionBlock)
    HealSmartSettings.activeSessionIndex = #HealSmartSettings.sessions
    
    -- FIFO REMOVAL BARRIER: Delete oldest session if inventory list hits 21 slots
    if #HealSmartSettings.sessions > HEALSMART_MAX_SAVED_SESSIONS then
        table.remove(HealSmartSettings.sessions, 1)
        HealSmartSettings.activeSessionIndex = #HealSmartSettings.sessions
    end
    end

coreFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
coreFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
coreFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
coreFrame:RegisterEvent("GROUP_ROSTER_UPDATE")   
coreFrame:RegisterEvent("PLAYER_ENTERING_WORLD") 

coreFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inTrueCombat = true
        timeSinceCombatEnd = 0
        if not isSessionActive then
            -- Trigger the automated history list rotation on pull
            HealSmart_CreateNewSession()
            isSessionActive = true
            coreFrame.RefreshStats()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inTrueCombat = false
        timeSinceCombatEnd = 0
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        UpdateGroupRosterCache()
    end
end)

UpdateGroupRosterCache()

-- Grace period ticker
coreFrame:SetScript("OnUpdate", function(self, elapsed)
    if isSessionActive and not inTrueCombat then
        timeSinceCombatEnd = timeSinceCombatEnd + elapsed
        if timeSinceCombatEnd >= HEALSMART_OUT_OF_COMBAT_GRACE then
            isSessionActive = false
            -- Combat fully finalized, stats are safely written inside SavedVariables array
        end
    end
end)

-- ==========================================
-- HealSmart - Core Engine (v0.6.0 Multi-Session) - PART 4
-- ==========================================

-- Global initialization interface running across layout load hooks
function HealSmart_SetInitialPage(savedPage)
    currentActivePage = savedPage
    
    -- Structure validation: Ensure multi-session databases exist upon login
    if HealSmartSettings then
        if not HealSmartSettings.sessions then
            HealSmartSettings.sessions = {}
        end
        if not HealSmartSettings.activeSessionID then
            HealSmartSettings.activeSessionID = 0
        end
        if not HealSmartSettings.activeSessionIndex then
            HealSmartSettings.activeSessionIndex = 1
        end
        if not HealSmartSettings.overallData then
            HealSmartSettings.overallData = {}
        end
        
        -- Create a baseline starter session block if the history log is completely empty
        if #HealSmartSettings.sessions == 0 then
            local zoneName = GetZoneText() or "Azeroth"
            HealSmartSettings.activeSessionID = 1
            HealSmartSettings.sessions[1] = {
                id = 1,
                name = "Startup Session (" .. zoneName .. ")",
                healers = {}
            }
            HealSmartSettings.activeSessionIndex = 1
        end
    end
    
    -- Refresh display metrics instantly
    if coreFrame.RefreshStats then coreFrame.RefreshStats() end
end

function HealSmart_RefreshCurrentPage()
    if coreFrame.RefreshStats then coreFrame.RefreshStats() end
end


-- ==========================================
-- HealSmart - Core Engine (v0.7.0) - PART 4A (Reset & Group Popups)
-- ==========================================

-- NEW MASTER WIPE ENGINE: Complete hard-reset of all cached data arrays and night totals
function HealSmart_ExecuteMasterWipeData()
    if not HealSmartSettings then return end
    
    -- 1. Purge all structural data pipelines permanently
    HealSmartSettings.sessions = {}
    HealSmartSettings.overallData = {}
    HealSmartSettings.activeSessionID = 1
    HealSmartSettings.activeSessionIndex = 1
    
    -- 2. Build a fresh baseline starter fight block to prevent empty array nil crashes
    local zoneName = GetZoneText() or "Azeroth"
    HealSmartSettings.sessions[1] = {
        id = 1,
        name = "Startup Session (" .. zoneName .. ")",
        healers = {}
    }
    
    -- 3. Reset the global display viewport back to show the fresh current fight slot
    HealSmart_SelectedViewSessionID = 0
    
    -- 4. Flush the main window canvas completely and redraw the empty state
    if HealSmart_ClearDisplay then HealSmart_ClearDisplay() end
    if coreFrame and coreFrame.RefreshStats then coreFrame.RefreshStats() end
    
    -- 5. Force update the historic session dropdown window cache if it happens to be open
    if HealSmart_UpdateSessionListWindow then HealSmart_UpdateSessionListWindow() end
    
    if HealSmart_Print then
        HealSmart_Print("All combat session logs and Overall Raid Totals have been successfully wiped.")
    end
end

-- NEW: Official Blizzard Static Popup Specification for automated Group Join promptings
StaticPopupDialogs["HEALSMART_GROUP_JOIN_PROMPT"] = {
    text = "You have joined a new Group or Raid. Do you want to wipe your previous fight history?",
    button1 = "Yes, Start Fresh",
    button2 = "No, Keep Data",
    OnAccept = function()
        HealSmart_ExecuteMasterWipeData()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- global callback bridge enabling the UI loader ticker to query background states
HealSmart_SetInitialPage(HealSmartSettings and HealSmartSettings.page or 0)

-- ==========================================
-- HealSmart - Core Engine (v0.7.0) - PART 3B (Group-Join Listener)
-- ==========================================

-- Runtime guard flag to track your previous grouping state across checks securely
local wasInGroupLastCheck = false

coreFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inTrueCombat = true
        timeSinceCombatEnd = 0
        if not isSessionActive then
            HealSmart_CreateNewSession()
            isSessionActive = true
            coreFrame.RefreshStats()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inTrueCombat = false
        timeSinceCombatEnd = 0
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        UpdateGroupRosterCache()
        
        -- NEW AUTOMATED GROUP JOIN ENGINE
        local currentlyInGroup = IsInGroup() or IsInRaid()
        
        -- Trigger point: Fires ONLY when transitioning from solo player to group member
        if currentlyInGroup and not wasInGroupLastCheck then
            if HealSmartSettings and HealSmartSettings.groupJoinBehavior then
                local behavior = HealSmartSettings.groupJoinBehavior
                
                if behavior == 1 then
                    -- Option 1: Hard wipe instantly without prompting
                    HealSmart_ExecuteMasterWipeData()
                    if HealSmart_Print then HealSmart_Print("Automatically cleared history due to group join settings.") end
                elseif behavior == 2 then
                    -- Option 2: Keep data silently and do absolutely nothing
                elseif behavior == 3 then
                    -- Option 3: Fire Blizzards popup confirmation window framework
                    StaticPopup_Show("HEALSMART_GROUP_JOIN_PROMPT")
                end
            end
        end
        
        -- Update the state tracking flag for the next event loop check
        wasInGroupLastCheck = currentlyInGroup
    end
end)

UpdateGroupRosterCache()

-- Remember to close the file with your signature block!

-- end healsmartcore.lua