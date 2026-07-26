-- ==========================================
-- HealSmart - Core Engine (v0.3.0 Roster Caching)
-- ==========================================

local activeHealers = {}
local sortedHealers = {}

-- Fast dictionary mapping: [CharacterName] = "CLASS_TOKEN"
local groupRosterCache = {}

local isSessionActive = false      
local inTrueCombat = false         
local timeSinceCombatEnd = 0

local currentFilterMode = "ALL"
local _, playerClassFilename = UnitClass("player")

local ALLOWED_CLASSES = {
    ["PRIEST"] = true,
    ["PALADIN"] = true,
    ["DRUID"] = true,
    ["SHAMAN"] = true
}

local coreFrame = CreateFrame("Frame")

-- 1. Scan the group/raid and build a name-to-class dictionary
local function UpdateGroupRosterCache()
    table.wipe(groupRosterCache)
    
    -- Always cache the player first
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")
    if playerName and playerClass then
        groupRosterCache[playerName] = playerClass
    end
    
    -- Scan party or raid group
    local numGroupMembers = GetNumGroupMembers()
    if numGroupMembers > 0 then
        local isRaid = IsInRaid()
        local prefix = isRaid and "raid" or "party"
        
        -- Party loop only checks party1-4, so we must include player for party mode manually
        local loopMax = isRaid and numGroupMembers or (numGroupMembers - 1)
        
        for i = 1, loopMax do
            local unit = prefix .. i
            local name = UnitName(unit)
            if name then
                local _, classToken = UnitClass(unit)
                if classToken then
                    groupRosterCache[name] = classToken
                end
            end
        end
    end
end

-- 2. Sort the database and push it to the UI
local function RefreshHealingStats()
    table.wipe(sortedHealers)

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
            table.insert(sortedHealers, data)
        end
    end

    if #sortedHealers == 0 then
        if HealSmart_ClearDisplay then HealSmart_ClearDisplay() end
        return
    end

    table.sort(sortedHealers, function(a, b)
        if a.percent == b.percent then
            return a.name < b.name
        end
        return a.percent > b.percent
    end)

    if HealSmart_RenderRaidBars then
        HealSmart_RenderRaidBars(sortedHealers)
    end
end

function HealSmart_ToggleClassFilter()
    if currentFilterMode == "ALL" then
        currentFilterMode = "CLASS"
    else
        currentFilterMode = "ALL"
    end
    RefreshHealingStats()
    return currentFilterMode
end

-- 3. Combat log parser
local function OnCombatLogEvent()
    if not isSessionActive then return end

    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    -- --- A: DIRECT HEALS & HOTS ---
    if eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL" then
        local _, _, _, _, _, _, _, _, _, _, _, _, _, _, amount, overheal = CombatLogGetCurrentEventInfo()
        
        overheal = overheal or 0
        amount = amount or 0
        local effective = amount - overheal
        if effective < 0 then effective = 0 end

        local isGroupMember = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                              (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                              (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isGroupMember and sourceName then
            local cleanName = string.match(sourceName, "([^-]+)")
            
            -- LOOKUP VIA NAME CACHE: Instantly find the class from our roster table
            local classFilename = groupRosterCache[cleanName]

            if classFilename and ALLOWED_CLASSES[classFilename] then
                if not activeHealers[sourceGUID] then
                    activeHealers[sourceGUID] = { name = cleanName, class = classFilename, effective = 0, overheal = 0, percent = 0 }
                end

                activeHealers[sourceGUID].effective = activeHealers[sourceGUID].effective + effective
                activeHealers[sourceGUID].overheal = activeHealers[sourceGUID].overheal + overheal
                RefreshHealingStats()
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
                local classFilename = "PRIEST"
                local cleanName = string.match(shieldCasterName, "([^-]+)")

                if not activeHealers[shieldCasterGUID] then
                    activeHealers[shieldCasterGUID] = { name = cleanName, class = classFilename, effective = 0, overheal = 0, percent = 0 }
                end

                activeHealers[shieldCasterGUID].effective = activeHealers[shieldCasterGUID].effective + shieldAbsorbAmount
                RefreshHealingStats()
            end
        end
    end
end

-- 4. Event registration and routing
coreFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
coreFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
coreFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
coreFrame:RegisterEvent("GROUP_ROSTER_UPDATE")   -- Fired when players join/leave or shift groups
coreFrame:RegisterEvent("PLAYER_ENTERING_WORLD") -- Fired when loading into a raid zone/instance

coreFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inTrueCombat = true
        timeSinceCombatEnd = 0
        if not isSessionActive then
            table.wipe(activeHealers) 
            isSessionActive = true
            RefreshHealingStats()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inTrueCombat = false
        timeSinceCombatEnd = 0
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        UpdateGroupRosterCache()
    end
end)

-- Initial scan upon addon startup
UpdateGroupRosterCache()

-- 5. Grace period ticker
coreFrame:SetScript("OnUpdate", function(self, elapsed)
    if isSessionActive and not inTrueCombat then
        timeSinceCombatEnd = timeSinceCombatEnd + elapsed
        if timeSinceCombatEnd >= HEALSMART_OUT_OF_COMBAT_GRACE then
            isSessionActive = false
        end
    end
end)

-- end healsmartcore.lua