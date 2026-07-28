-- ==========================================
-- HealSmart - Core Engine (v0.4.0) - PART 1 (Profile Lock Fix)
-- ==========================================

local activeHealers = {}
local sortedHealers = {}
local groupRosterCache = {}
local lastKnownMana = {}

local isSessionActive = false      
local inTrueCombat = false         
local timeSinceCombatEnd = 0

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
    ["Healing Wave"] = "SHAMAN",
    ["Lesser Healing Wave"] = "SHAMAN",
    ["Chain Heal"] = "SHAMAN",
    ["Lesser Heal"] = "PRIEST",
    ["Heal"] = "PRIEST",
    ["Flash Heal"] = "PRIEST",
    ["Greater Heal"] = "PRIEST",
    ["Renew"] = "PRIEST",
    ["Prayer of Healing"] = "PRIEST",
    ["Power Word: Shield"] = "PRIEST",
    ["Healing Touch"] = "DRUID",
    ["Rejuvenation"] = "DRUID",
    ["Regrowth"] = "DRUID",
    ["Flash of Light"] = "PALADIN",
    ["Holy Light"] = "PALADIN"
}

local coreFrame = CreateFrame("Frame")

-- FIXED FACTORY: Instantly returns the existing profile to guarantee mana values are never lost
local function GetOrCreateHealerProfile(guid, name, classToken)
    -- CRITICAL LAYOUT LOCK: If the profile already exists, return it immediately!
    -- This prevents subsequent events (like SPELL_HEAL) from breaking or corrupting the data structure.
    if activeHealers[guid] then
        return activeHealers[guid]
    end

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

    activeHealers[guid] = {
        name = name,
        class = classToken or "SHAMAN", -- Safe default fallback
        effective = 0,
        overheal = 0,
        percent = 0,
        unitId = unitToken,
        manaUsed = 0,
        hpm = 0
    }
    
    return activeHealers[guid]
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
-- HealSmart - Core Engine (v0.4.0) - PART 2 (Global Variable Sync)
-- ==========================================

-- Global variable accessible by the UI file for future configuration panels
HealSmart_CurrentThreshold = 300 

coreFrame.RefreshStats = function()
    if currentActivePage == 0 then
        local welcomeMessage = "Welcome to HealSmart!\n\nUse the < and > arrows in the top right to switch statistics screens.\n\nData tracks automatically as soon as combat starts."
        if HealSmart_RenderTextMessage then HealSmart_RenderTextMessage("HealSmart v0.4.0", welcomeMessage) end
        return
    end

    table.wipe(sortedHealers)
    local topHealerAmount = 0
    local totalRaidEffective = 0 
    local topHPMValue = 0 

    -- Sync the global threshold value based on group state (bypassed if solo)
    if not IsInGroup() then
        HealSmart_CurrentThreshold = 0 
    else
        -- Fallback to the configuration constant (or a saved variable later)
        HealSmart_CurrentThreshold = HEALSMART_MANA_THRESHOLD or 300
    end

    for guid, data in pairs(activeHealers) do
        if currentFilterMode == "CLASS" and data.class ~= playerClassFilename then
            -- Filtered out
        else
            local total = data.effective + data.overheal
            if total > 0 then
                data.percent = (data.effective / total) * 100
            else
                data.percent = 0
            end
            
            data.manaUsed = data.manaUsed or 0

            -- Calculate raw HPM directly for accurate sorting data arrays
            if data.manaUsed > 0 then
                data.hpm = data.effective / data.manaUsed
                
                -- Only evaluate towards topHPMValue if they crossed the active threshold
                if data.manaUsed >= HealSmart_CurrentThreshold then
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

    -- Handle blank state
    if #sortedHealers == 0 then
        local pageTitle = "HealSmart"
        if currentActivePage == 1 then pageTitle = "1. Healing Done"
        elseif currentActivePage == 2 then pageTitle = "2. Heal vs Overheal"
        elseif currentActivePage == 3 then pageTitle = "3. Mana Efficiency" end
        if HealSmart_RenderTextMessage then HealSmart_RenderTextMessage(pageTitle, "") end
        return
    end

    -- --- SORTING AND ROUTING PATHWAYS ---
    if currentActivePage == 1 then
        table.sort(sortedHealers, function(a, b)
            if a.effective == b.effective then return a.name < b.name end
            return a.effective > b.effective
        end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topHealerAmount, "HEAL", totalRaidEffective) end
        
    elseif currentActivePage == 2 then
        table.sort(sortedHealers, function(a, b)
            if a.percent == b.percent then return a.name < b.name end
            return a.percent > b.percent
        end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, 0, "EFFICIENCY") end
        
    elseif currentActivePage == 3 then
        table.sort(sortedHealers, function(a, b)
            if a.hpm == b.hpm then return a.name < b.name end
            return a.hpm > b.hpm
        end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topHPMValue, "MANA") end
    end
end

function HealSmart_ChangePage(direction)
    currentActivePage = currentActivePage + direction
    if currentActivePage > 3 then currentActivePage = 0 end
    if currentActivePage < 0 then currentActivePage = 3 end
    if HealSmartSettings then HealSmartSettings.page = currentActivePage end
    HealSmart_RefreshCurrentPage()
end

function HealSmart_SetInitialPage(savedPage)
    currentActivePage = savedPage
    if HealSmartSettings and HealSmartSettings.lastFightData then
        table.wipe(activeHealers)
        for guid, data in pairs(HealSmartSettings.lastFightData) do
            local fallbackUnit = data.unitId or "player"
            activeHealers[guid] = {
                name = data.name,
                class = data.class,
                effective = data.effective,
                overheal = data.overheal,
                percent = data.percent or 0,
                unitId = fallbackUnit,
                manaUsed = data.manaUsed or 0,
                hpm = data.hpm or 0
            }
        end
    end
end

function HealSmart_RefreshCurrentPage()
    if coreFrame.RefreshStats then coreFrame.RefreshStats() end
end

function HealSmart_ToggleClassFilter()
    if currentFilterMode == "ALL" then currentFilterMode = "CLASS" else currentFilterMode = "ALL" end
    if coreFrame.RefreshStats then coreFrame.RefreshStats() end
    return currentFilterMode
end

-- ==========================================
-- HealSmart - Core Engine (v0.4.0) - PART 3 (Cleaned)
-- ==========================================

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

    -- --- HYBRID MANA WATCH ENGINE ---
    if eventType == "SPELL_CAST_SUCCESS" then
        -- Secure unpack: spellID (12), spellName (13), spellSchool (14)
        local spellID, spellName, _ = select(12, CombatLogGetCurrentEventInfo())
        
        local isGroupMember = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                              (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                              (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isGroupMember and sourceName then
            local dbData = nil
            if spellID and HealSmart_SpellCostDB then
                dbData = HealSmart_SpellCostDB[spellID]
            end
            
            local classFilename = dbData and dbData.class or SPELL_CLASS_CACHE[spellName]
            
            if classFilename and ALLOWED_CLASSES[classFilename] then
                local cleanName = string.match(sourceName, "([^-]+)")
                local healer = GetOrCreateHealerProfile(sourceGUID, cleanName, classFilename)
                
                -- Step 1: Query live API
                local cost = spellID and GetLiveSpellManaCost(spellID) or 0
                
                -- Step 2: Query database fallback
                if cost == 0 and dbData then
                    cost = dbData.cost or 0
                end
                
                -- Step 3: Pure name-based safe fallback for missing/low level IDs
                if cost == 0 and spellName then
                    if spellName == "Healing Wave" then
                        cost = 25
                    elseif spellName == "Lesser Healing Wave" then
                        cost = 105
                    elseif spellName == "Chain Heal" then
                        cost = 260
                    elseif spellName == "Flash Heal" or spellName == "Lesser Heal" or spellName == "Renew" then
                        cost = 30
                    elseif spellName == "Heal" then
                        cost = 90
                    elseif spellName == "Greater Heal" then
                        cost = 370
                    elseif spellName == "Prayer of Healing" then
                        cost = 410
                    elseif spellName == "Power Word: Shield" then
                        cost = 45
                    elseif spellName == "Healing Touch" or spellName == "Rejuvenation" or spellName == "Regrowth" then
                        cost = 25
                    elseif spellName == "Flash of Light" or spellName == "Holy Light" then
                        cost = 35
                    end
                end
                
                healer.manaUsed = healer.manaUsed + cost
                if coreFrame.RefreshStats then coreFrame.RefreshStats() end
            end
        end

    -- --- A: DIRECT HEALS & HOTS ---
    elseif eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL" then
        -- Secure unpack: spellID (12), spellName (13), spellSchool (14), amount (15), overheal (16)
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
                local healer = GetOrCreateHealerProfile(sourceGUID, cleanName, classFilename)
                healer.effective = healer.effective + effective
                healer.overheal = healer.overheal + overheal
                if coreFrame.RefreshStats then coreFrame.RefreshStats() end
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
                local healer = GetOrCreateHealerProfile(shieldCasterGUID, cleanName, "PRIEST")
                healer.effective = healer.effective + shieldAbsorbAmount
                if coreFrame.RefreshStats then coreFrame.RefreshStats() end
            end
        end
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
            table.wipe(activeHealers) 
            isSessionActive = true
            if coreFrame.RefreshStats then coreFrame.RefreshStats() end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inTrueCombat = false
        timeSinceCombatEnd = 0
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        UpdateGroupRosterCache()
    end
end)

UpdateGroupRosterCache()

coreFrame:SetScript("OnUpdate", function(self, elapsed)
    if isSessionActive and not inTrueCombat then
        timeSinceCombatEnd = timeSinceCombatEnd + elapsed
        if timeSinceCombatEnd >= HEALSMART_OUT_OF_COMBAT_GRACE then
            isSessionActive = false
            if HealSmartSettings then
                HealSmartSettings.lastFightData = {}
                for guid, data in pairs(activeHealers) do
                    HealSmartSettings.lastFightData[guid] = {
                        name = data.name,
                        class = data.class,
                        effective = data.effective,
                        overheal = data.overheal,
                        percent = data.percent,
                        unitId = data.unitId,
                        manaUsed = data.manaUsed,
                        hpm = data.hpm
                    }
                end
            end
        end
    end
end)

-- end healsmartcore.lua