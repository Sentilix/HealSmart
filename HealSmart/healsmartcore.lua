-- ==========================================
-- HealSmart - Core Engine (v0.6.0) - PART 1 & 2 (Global Variable Framework)
-- ==========================================

-- Configuration Constants
HEALSMART_MAX_SAVED_SESSIONS = 20

HealSmart_SelectedViewSessionID = 0 
HealSmart_CurrentActivePage = 0 

-- Runtime cache objects
local groupRosterCache = {}
local currentFilterMode = "ALL"
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
        local finalClass = classToken
        
        if guid ~= UnitGUID("player") then
            if IsInRaid() then
                for i = 1, GetNumGroupMembers() do
                    if UnitGUID("raid"..i) == guid then 
                        unitToken = "raid"..i 
                        -- SECURE BACKUP: If token is missing, query the engine live
                        if not finalClass then _, finalClass = UnitClass(unitToken) end
                        break 
                    end
                end
            else
                for i = 1, GetNumGroupMembers() - 1 do
                    if UnitGUID("party"..i) == guid then 
                        unitToken = "party"..i 
                        if not finalClass then _, finalClass = UnitClass(unitToken) end
                        break 
                    end
                end
            end
        else
            -- If it's the player, ensure we grab the correct class filename
            if not finalClass then _, finalClass = UnitClass("player") end
        end

        -- SECURE FALLBACK: Default to "UNKNOWN" instead of "SHAMAN" to prevent data pollution
        if not finalClass or finalClass == "" then
            finalClass = "UNKNOWN"
        end

        dataTable[guid] = {
            name = name,
            class = finalClass,
            effective = 0,
            overheal = 0,
            percent = 0,
            unitId = unitToken,
            manaUsed = 0,
            hpm = 0,
            deaths = 0,
            resurrects = 0,
            dispels = 0,
            buffs = 0
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

-- ==========================================
-- HealSmart - Core Engine (v0.7.0) - PART 2 (7-Page Specific Sorting)
-- ==========================================

local sortedHealers = {}

coreFrame.RefreshStats = function()
    if HealSmart_CurrentActivePage == 0 and HealSmart_SelectedViewSessionID == 0 then
        local welcomeMessage = "Welcome to HealSmart v0.7.0!\n\nUse the < and > arrows to switch pages.\n\nClick the Gold Reset Arrow to wipe raid night tracking data."
        if HealSmart_RenderTextMessage then HealSmart_RenderTextMessage("HealSmart v0.7.0", welcomeMessage) end
        return
    end

    table.wipe(sortedHealers)
    local topHealerAmount = 0
    local totalRaidEffective = 0 
    local topHPMValue = 0 
    local topDispelValue = 0
    local topDeathValue = 0
    local topRessValue = 0

    local activeThreshold = HEALSMART_MANA_THRESHOLD or 300
    if not IsInGroup() then activeThreshold = 0 end

    local dataSourceTable = nil
    local sessionLabel = "Current Fight"

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
                data.deaths = data.deaths or 0
                data.resurrects = data.resurrects or 0
                data.dispels = data.dispels or 0
                data.buffs = data.buffs or 0

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
                if data.dispels > topDispelValue then topDispelValue = data.dispels end
                if data.deaths > topDeathValue then topDeathValue = data.deaths end
                if data.resurrects > topRessValue then topRessValue = data.resurrects end
            end
        end
    end

    -- Render blank state if no dataset rows found
    if #sortedHealers == 0 then
        local baseTitle = HealSmart_PageTitles[HealSmart_CurrentActivePage] or "HealSmart"
        local pageTitle = baseTitle .. " (" .. sessionLabel .. ")"
        if HealSmart_RenderTextMessage then HealSmart_RenderTextMessage(pageTitle, "") end
        return
    end

    -- Compile dynamic strings headings using the unified global dictionary array
    local baseTitle = HealSmart_PageTitles[HealSmart_CurrentActivePage] or "HealSmart"
    local viewTitle = baseTitle .. " (" .. sessionLabel .. ")"

    -- CORRECTLY ORDERED SORTING CIRCUITS FOR v0.7.0 (4: Dispels, 5: Buffs, 6: Deaths, 7: Resser)
    if HealSmart_CurrentActivePage == 1 then
        table.sort(sortedHealers, function(a, b) return (a.effective == b.effective) and (a.name < b.name) or (a.effective > b.effective) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topHealerAmount, "HEAL", totalRaidEffective, viewTitle) end
    elseif HealSmart_CurrentActivePage == 2 then
        table.sort(sortedHealers, function(a, b) return (a.percent == b.percent) and (a.name < b.name) or (a.percent > b.percent) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, 0, "EFFICIENCY", 0, viewTitle) end
    elseif HealSmart_CurrentActivePage == 3 then
        table.sort(sortedHealers, function(a, b) return (a.hpm == b.hpm) and (a.name < b.name) or (a.hpm > b.hpm) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topHPMValue, "MANA", 0, viewTitle) end
    elseif HealSmart_CurrentActivePage == 4 then
        -- Page 4: Dispels Done
        table.sort(sortedHealers, function(a, b) return (a.dispels == b.dispels) and (a.name < b.name) or (a.dispels > b.dispels) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topDispelValue, "DISPELS", 0, viewTitle) end
    elseif HealSmart_CurrentActivePage == 5 then
        -- Page 5: Buffs Cast
        table.sort(sortedHealers, function(a, b) return (a.buffs == b.buffs) and (a.name < b.name) or (a.buffs > b.buffs) end)
        local topBuffValue = 0
        for _, data in ipairs(sortedHealers) do if data.buffs > topBuffValue then topBuffValue = data.buffs end end
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topBuffValue, "BUFFS", 0, viewTitle) end
    elseif HealSmart_CurrentActivePage == 6 then
        -- Page 6: Raid Deaths
        table.sort(sortedHealers, function(a, b) return (a.deaths == b.deaths) and (a.name < b.name) or (a.deaths > b.deaths) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topDeathValue, "DEATHS", 0, viewTitle) end
    elseif HealSmart_CurrentActivePage == 7 then
        -- Page 7: Resurrects Cast
        table.sort(sortedHealers, function(a, b) return (a.resurrects == b.resurrects) and (a.name < b.name) or (a.resurrects > b.resurrects) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topRessValue, "RESS", 0, viewTitle) end
    end
end

-- BOUNDARY MATRIX: Maintained at 7 pages maximum capacity
function HealSmart_ChangePage(direction)
    HealSmart_CurrentActivePage = HealSmart_CurrentActivePage + direction
    if HealSmart_CurrentActivePage > 7 then HealSmart_CurrentActivePage = 0 end
    if HealSmart_CurrentActivePage < 0 then HealSmart_CurrentActivePage = 7 end
    if HealSmartSettings then HealSmartSettings.page = HealSmart_CurrentActivePage end
    HealSmart_RefreshCurrentPage()
end

function HealSmart_ToggleClassFilter()
    if currentFilterMode == "ALL" then currentFilterMode = "CLASS" else currentFilterMode = "ALL" end
    if coreFrame.RefreshStats then coreFrame.RefreshStats() end
    return currentFilterMode
end

-- ==========================================
-- HealSmart - Core Engine (v0.7.0) - PART 3A (Combat Log Parser - Part 1)
-- ==========================================

local isSessionActive = false      
local inTrueCombat = false         
local timeSinceCombatEnd = 0

-- Dynamic Cache tracking for major long-term raid buffs to filter out combat procs securely
local BUFF_WATCH_LIST = {
    ["Power Word: Fortitude"] = true, ["Prayer of Fortitude"] = true,
    ["Shadow Protection"] = true, ["Prayer of Shadow Protection"] = true,
    ["Divine Spirit"] = true, ["Prayer of Spirit"] = true,
    ["Arcane Intellect"] = true, ["Arcane Brilliance"] = true,
    ["Mark of the Wild"] = true, ["Gift of the Wild"] = true,
    ["Thorns"] = true,
    ["Blessing of Might"] = true, ["Greater Blessing of Might"] = true,
    ["Blessing of Wisdom"] = true, ["Greater Blessing of Wisdom"] = true,
    ["Blessing of Kings"] = true, ["Greater Blessing of Kings"] = true,
    ["Blessing of Light"] = true, ["Greater Blessing of Light"] = true,
    ["Blessing of Sanctuary"] = true, ["Greater Blessing of Sanctuary"] = true,
    ["Blessing of Salvation"] = true, ["Greater Blessing of Salvation"] = true
}

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
    -- Fetch the active writing sub-table for the current active fight session
    local activeHealers = HealSmart_GetActiveSessionHealers()
    if not activeHealers then return end

    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    -- --- 1. HYBRID MANA WATCH ENGINE (Requires session tracking check) ---
    if eventType == "SPELL_CAST_SUCCESS" and isSessionActive then
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
                
                if HealSmartSettings and HealSmartSettings.overallData then
                    local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, sourceGUID, cleanName, classFilename)
                    overallHealer.manaUsed = overallHealer.manaUsed + cost
                end
                coreFrame.RefreshStats()
            end
        end

    -- --- 2. DIRECT HEALS & HOTS (Requires session tracking check) ---
    elseif (eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL") and isSessionActive then
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
                local healer = HealSmart_GetOrCreateProfile(activeHealers, sourceGUID, cleanName, classFilename)
                healer.effective = healer.effective + effective
                healer.overheal = healer.overheal + overheal
                
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

    -- ==========================================
    -- HealSmart - Core Engine (v0.7.0) - PART 3A (Combat Log Parser - Part 2)
    -- ==========================================

    -- --- 4. RAID DEATH WATCH ENGINE (Runs out-of-combat!) ---
    elseif eventType == "UNIT_DIED" then
        local isTargetGroupMember = (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                    (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                    (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        -- Ensure we only track player deaths inside our own raid group, excluding pets and monsters
        if isTargetGroupMember and destName and not string.find(destGUID, "^Pet-") then
            local cleanDestName = string.match(destName, "([^-]+)")
            local healerClass = groupRosterCache[cleanDestName]
            
            if healerClass and ALLOWED_CLASSES[healerClass] then
                -- Add points to the person who died inside the current session array
                local healer = HealSmart_GetOrCreateProfile(activeHealers, destGUID, cleanDestName, healerClass)
                healer.deaths = healer.deaths + 1
                
                -- Accumulate cumulatively inside the master Overall database sheet
                if HealSmartSettings and HealSmartSettings.overallData then
                    local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, destGUID, cleanDestName, healerClass)
                    overallHealer.deaths = overallHealer.deaths + 1
                end
                coreFrame.RefreshStats()
            end
        end

    -- --- 5. DISPEL TRACKING ENGINE (Runs out-of-combat!) ---
    elseif eventType == "SPELL_DISPEL" then
        local isCasterGroupMember = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isCasterGroupMember and sourceName then
            local cleanSourceName = string.match(sourceName, "([^-]+)")
            local healerClass = groupRosterCache[cleanSourceName] or "UNKNOWN"
            
            if healerClass and ALLOWED_CLASSES[healerClass] then
                local healer = HealSmart_GetOrCreateProfile(activeHealers, sourceGUID, cleanSourceName, healerClass)
                healer.dispels = healer.dispels + 1
                
                if HealSmartSettings and HealSmartSettings.overallData then
                    local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, sourceGUID, cleanSourceName, healerClass)
                    overallHealer.dispels = overallHealer.dispels + 1
                end
                coreFrame.RefreshStats()
            end
        end

    -- --- 6. RESURRECTION TRACKING ENGINE (Runs out-of-combat!) ---
    elseif eventType == "SPELL_RESURRECT" then
        local isCasterGroupMember = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isCasterGroupMember and sourceName then
            local cleanSourceName = string.match(sourceName, "([^-]+)")
            local healerClass = groupRosterCache[cleanSourceName] or "UNKNOWN"
            
            if healerClass and ALLOWED_CLASSES[healerClass] then
                local healer = HealSmart_GetOrCreateProfile(activeHealers, sourceGUID, cleanSourceName, healerClass)
                healer.resurrects = healer.resurrects + 1
                
                if HealSmartSettings and HealSmartSettings.overallData then
                    local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, sourceGUID, cleanSourceName, healerClass)
                    overallHealer.resurrects = overallHealer.resurrects + 1
                end
                coreFrame.RefreshStats()
            end
        end

    -- --- 7. RAID BUFF TRACKING ENGINE (Runs out-of-combat!) ---
    elseif eventType == "SPELL_AURA_APPLIED" then
        local _, spellName, _ = select(12, CombatLogGetCurrentEventInfo())
        
        local isCasterGroupMember = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        -- Secure barrier filtration: Validate against our hard-coded watch list to ignore short combat procs
        if isCasterGroupMember and sourceName and spellName and BUFF_WATCH_LIST[spellName] then
            local cleanSourceName = string.match(sourceName, "([^-]+)")
            local healerClass = groupRosterCache[cleanSourceName] or "UNKNOWN"
            
            if healerClass and ALLOWED_CLASSES[healerClass] then
                local healer = HealSmart_GetOrCreateProfile(activeHealers, sourceGUID, cleanSourceName, healerClass)
                healer.buffs = healer.buffs + 1
                
                if HealSmartSettings and HealSmartSettings.overallData then
                    local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, sourceGUID, cleanSourceName, healerClass)
                    overallHealer.buffs = overallHealer.buffs + 1
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
    HealSmart_CurrentActivePage = savedPage
    
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

-- ==========================================
-- HealSmart - Core Engine (v0.7.0 Chat Exporter)
-- ==========================================

function HealSmart_ReportCurrentPageToChat()
    if not sortedHealers or #sortedHealers == 0 then return end
    if not HealSmartSettings then return end

    local mode = HealSmartSettings.reportChannelMode or 1
    local channelType = "SAY"
    local channelNum = nil
    local isSoloWhisperLoop = false

    if mode == 1 then
        -- FIXED AUTO ROUTING: Only use official party/raid lines if actively grouped, else fallback to local prints
        if IsInRaid() then 
            channelType = "RAID"
        elseif IsInGroup() then 
            channelType = "PARTY"
        else 
            isSoloWhisperLoop = true 
        end
    elseif mode == 2 then channelType = "SAY"
    elseif mode == 3 then channelType = "YELL"
    elseif mode == 4 then channelType = "GUILD"
    elseif mode == 5 then 
        channelType = "CHANNEL" 
        channelNum = HealSmartSettings.reportCustomChannelNum or 1
    end

    local maxLines = HealSmartSettings.reportLinesLimit or 5
    local linesToPost = math.min(maxLines, #sortedHealers)
    if linesToPost <= 0 then return end

    local baseTitle = HealSmart_PageTitles[HealSmart_CurrentActivePage] or "HealSmart Stats"
    
    -- Execute Text Outputs
    if isSoloWhisperLoop then
        if HealSmart_Print then HealSmart_Print("=== " .. baseTitle .. " ===") end
    else
        SendChatMessage("=== HealSmart: " .. baseTitle .. " ===", channelType, nil, channelNum)
    end

    for i = 1, linesToPost do
        local data = sortedHealers[i]
        if data then
            local lineMessage = ""
            
            if HealSmart_CurrentActivePage == 1 then
                local formattedAmt = FormatDotNumber and FormatDotNumber(data.effective) or data.effective
                lineMessage = string.format("%d. %s - %s Effective Healing", i, data.name, formattedAmt)
            elseif HealSmart_CurrentActivePage == 2 then
                lineMessage = string.format("%d. %s - %.1f%% Healing Efficiency", i, data.name, data.percent)
            elseif HealSmart_CurrentActivePage == 3 then
                lineMessage = string.format("%d. %s - %.1f HPM", i, data.name, data.hpm)
            elseif HealSmart_CurrentActivePage == 4 then
                lineMessage = string.format("%d. %s - %d Dispels", i, data.name, data.dispels)
            elseif HealSmart_CurrentActivePage == 5 then
                lineMessage = string.format("%d. %s - %d Buffs", i, data.name, data.buffs)
            elseif HealSmart_CurrentActivePage == 6 then
                lineMessage = string.format("%d. %s - %d Deaths", i, data.name, data.deaths)
            elseif HealSmart_CurrentActivePage == 7 then
                lineMessage = string.format("%d. %s - %d Resurrects", i, data.name, data.resurrects)
            end

            if lineMessage ~= "" then
                if isSoloWhisperLoop then
                    if HealSmart_Print then HealSmart_Print(lineMessage) end
                else
                    SendChatMessage(lineMessage, channelType, nil, channelNum)
                end
            end
        end
    end
end

-- end healsmartcore.lua