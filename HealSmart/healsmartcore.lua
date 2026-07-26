-- ==========================================
-- HealSmart - Core Engine (v0.3.0 Raid)
-- ==========================================

local activeHealers = {}
local sortedHealers = {}

local isSessionActive = false      
local inTrueCombat = false         
local timeSinceCombatEnd = 0

local ALLOWED_CLASSES = {
    ["PRIEST"] = true,
    ["PALADIN"] = true,
    ["DRUID"] = true,
    ["SHAMAN"] = true
}

local coreFrame = CreateFrame("Frame")

-- 1. Sort the database and push it to the UI
local function RefreshHealingStats()
    table.wipe(sortedHealers)

    for guid, data in pairs(activeHealers) do
        local total = data.effective + data.overheal
        if total > 0 then
            data.percent = (data.effective / total) * 100
        else
            data.percent = 0
        end
        table.insert(sortedHealers, data)
    end

    if #sortedHealers == 0 then
        if HealSmart_ClearDisplay then HealSmart_ClearDisplay() end
        return
    end

    -- SORTING: 100% highest efficiency at the top, tied scores sorted alphabetically
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

-- 2. Combat log parser
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

        if isGroupMember then
            local _, classFilename = GetPlayerInfoByGUID(sourceGUID)
            
            -- Fallback: If player is you, get class directly
            if not classFilename and sourceGUID == UnitGUID("player") then
                _, classFilename = UnitClass("player")
            end

            if classFilename and ALLOWED_CLASSES[classFilename] then
                local cleanName = string.match(sourceName, "([^-]+)")

                if not activeHealers[sourceGUID] then
                    activeHealers[sourceGUID] = { name = cleanName, class = classFilename, effective = 0, overheal = 0, percent = 0 }
                end

                activeHealers[sourceGUID].effective = activeHealers[sourceGUID].effective + effective
                activeHealers[sourceGUID].overheal = activeHealers[sourceGUID].overheal + overheal
                RefreshHealingStats()
            end
        end

    -- --- B: SHIELDS & ABSORBS (Skudsikker udpakning) ---
    elseif eventType == "SPELL_ABSORBED" then
        -- We unpack ALL arguments systematically to avoid dynamic offset shift issues
        local allArgs = { CombatLogGetCurrentEventInfo() }
        
        local shieldCasterGUID, shieldCasterName, shieldCasterFlags, shieldAbsorbAmount
        
        -- In WoW Classic Era, SPELL_ABSORBED always places its payload at the absolute end of the array.
        -- The last 4 arguments are ALWAYS: absorbSpellId, absorbSpellName, absorbSpellSchool, absorbAmount
        -- The 4 arguments right BEFORE those are ALWAYS: casterGUID, casterName, casterFlags, casterRaidFlags
        local numArgs = #allArgs
        if numArgs >= 19 then
            shieldCasterGUID = allArgs[numArgs - 7]
            shieldCasterName = allArgs[numArgs - 6]
            shieldCasterFlags = allArgs[numArgs - 5]
            shieldAbsorbAmount = allArgs[numArgs]
        end

        if shieldCasterGUID and shieldAbsorbAmount and shieldCasterGUID ~= "" then
            local isGroupMember = (bit.band(shieldCasterFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                  (bit.band(shieldCasterFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                  (bit.band(shieldCasterFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

            if isGroupMember then
                -- Hardcoded optimization: In Classic Vanilla, only Priests cast Power Word: Shield!
                -- This bypasses the buggy GetPlayerInfoByGUID function completely for absorbs.
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
    end
end)

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