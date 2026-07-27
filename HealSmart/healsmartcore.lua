-- ==========================================
-- HealSmart - Core Engine (v0.4.0) - PART 1 (UnitId Gendannelse)
-- ==========================================

local activeHealers = {}
local sortedHealers = {}
local groupRosterCache = {}

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

local coreFrame = CreateFrame("Frame")

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

function HealSmart_ChangePage(direction)
    currentActivePage = currentActivePage + direction
    if currentActivePage > 3 then currentActivePage = 0 end
    if currentActivePage < 0 then currentActivePage = 3 end
    
    if HealSmartSettings then
        HealSmartSettings.page = currentActivePage
    end
    
    HealSmart_RefreshCurrentPage()
end

-- FIXED INITIALIZER: Safely restores unitId and power metrics from SavedVariables
function HealSmart_SetInitialPage(savedPage)
    currentActivePage = savedPage
    
    if HealSmartSettings and HealSmartSettings.lastFightData then
        table.wipe(activeHealers)
        for guid, data in pairs(HealSmartSettings.lastFightData) do
            -- Fallback to "player" if unitId is missing to prevent UnitPower nil crashes
            local fallbackUnit = data.unitId or "player"
            
            activeHealers[guid] = {
                name = data.name,
                class = data.class,
                effective = data.effective,
                overheal = data.overheal,
                percent = data.percent or 0,
                unitId = fallbackUnit,
                manaAtStart = data.manaAtStart or 0,
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
-- HealSmart - Core Engine (v0.4.0) - PART 2 (Mana Logic)
-- ==========================================

coreFrame.RefreshStats = function()
    -- --- PAGE 0: Welcome Screen ---
    if currentActivePage == 0 then
        local welcomeMessage = "Welcome to HealSmart!\n\nUse the < and > arrows in the top right to switch statistics screens.\n\nData tracks automatically as soon as combat starts."
        if HealSmart_RenderTextMessage then
            HealSmart_RenderTextMessage("HealSmart v0.4.0", welcomeMessage)
        end
        return
    end

    -- --- PROCESS ACTIVE DATA (PAGES 1, 2 & 3) ---
    table.wipe(sortedHealers)
    local topHealerAmount = 0
    local totalRaidEffective = 0 
    local topHPMValue = 0 -- NEW: Tracks the highest valid HPM in the raid for scaling Page 3 bars

    for guid, data in pairs(activeHealers) do
        if currentFilterMode == "CLASS" and data.class ~= playerClassFilename then
            -- Filtered out
        else
            -- 1. Standard Efficiency Calculations
            local total = data.effective + data.overheal
            if total > 0 then
                data.percent = (data.effective / total) * 100
            else
                data.percent = 0
            end
            
            -- 2. NEW: Real-time Mana Efficiency (HPM) Calculations
            -- Read current mana to see how much has been spent since combat start
            local currentMana = UnitPower(data.unitId, 0) or 0 -- 0 is the power type token for Mana
            if data.manaAtStart > 0 and currentMana < data.manaAtStart then
                data.manaUsed = data.manaAtStart - currentMana
            else
                data.manaUsed = data.manaUsed or 0
            end

            -- RULE 1 & RULE 2 COMBINED: Apply the threshold gate
            if data.manaUsed >= HEALSMART_MANA_THRESHOLD and data.manaUsed > 0 then
                data.hpm = data.effective / data.manaUsed
                
                -- Track the maximum valid HPM for relative row bar scaling
                if data.hpm > topHPMValue then
                    topHPMValue = data.hpm
                end
            else
                -- If below 300 mana, force HPM ratio to 0 so they drop to the bottom
                data.hpm = 0
            end

            table.insert(sortedHealers, data)
            totalRaidEffective = totalRaidEffective + data.effective
            
            if data.effective > topHealerAmount then
                topHealerAmount = data.effective
            end
        end
    end

    -- Handle blank state
    if #sortedHealers == 0 then
        local pageTitle = "HealSmart"
        if currentActivePage == 1 then pageTitle = "1. Effective Heal"
        elseif currentActivePage == 2 then pageTitle = "2. Efficiency %"
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
        if HealSmart_RenderRaidBars then
            HealSmart_RenderRaidBars(sortedHealers, topHealerAmount, "HEAL", totalRaidEffective)
        end
    elseif currentActivePage == 2 then
        table.sort(sortedHealers, function(a, b)
            if a.percent == b.percent then return a.name < b.name end
            return a.percent > b.percent
        end)
        if HealSmart_RenderRaidBars then
            HealSmart_RenderRaidBars(sortedHealers, 0, "EFFICIENCY")
        end
    elseif currentActivePage == 3 then
        -- NEW SORTING FOR PAGE 3: Highest HPM first. 
        -- Tied scores (like multiple people at 0 HPM) are sorted alphabetically by name
        table.sort(sortedHealers, function(a, b)
            if a.hpm == b.hpm then return a.name < b.name end
            return a.hpm > b.hpm
        end)
        if HealSmart_RenderRaidBars then
            HealSmart_RenderRaidBars(sortedHealers, topHPMValue, "MANA")
        end
    end
end

-- ==========================================
-- HealSmart - Core Engine (v0.4.0) - PART 3 (Mana Update)
-- ==========================================

local function OnCombatLogEvent()
    if not isSessionActive then return end

    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    -- --- A: DIRECT HEALS & HOTS ---
    if eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL" then
        local _, _, _, _, _, _, _, _, _, _, _, _, spellName, _, amount, overheal = CombatLogGetCurrentEventInfo()
        
        overheal = overheal or 0
        amount = amount or 0
        local effective = amount - overheal
        if effective < 0 then effective = 0 end

        local isGroupMember = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                              (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                              (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isGroupMember and sourceName then
            local cleanName = string.match(sourceName, "([^-]+)")
            local classFilename = groupRosterCache[cleanName]

            if classFilename and ALLOWED_CLASSES[classFilename] then
                -- Determine unitToken to check real-time mana stats
                local unitToken = "player"
                if sourceGUID ~= UnitGUID("player") then
                    -- Search through roster to find the correct unit string matching the GUID
                    if IsInRaid() then
                        for i = 1, GetNumGroupMembers() do
                            if UnitGUID("raid"..i) == sourceGUID then unitToken = "raid"..i break end
                        end
                    else
                        for i = 1, GetNumGroupMembers() - 1 do
                            if UnitGUID("party"..i) == sourceGUID then unitToken = "party"..i break end
                        end
                    end
                end

                if not activeHealers[sourceGUID] then
                    -- Grab current baseline mana states upon their very first heal event in combat
                    local startingMana = UnitPower(unitToken, 0) or 0
                    activeHealers[sourceGUID] = { 
                        name = cleanName, 
                        class = classFilename, 
                        effective = 0, 
                        overheal = 0, 
                        percent = 0,
                        unitId = unitToken,
                        manaAtStart = startingMana,
                        manaUsed = 0,
                        hpm = 0
                    }
                end
                
                activeHealers[sourceGUID].effective = activeHealers[sourceGUID].effective + effective
                activeHealers[sourceGUID].overheal = activeHealers[sourceGUID].overheal + overheal
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
                local classFilename = "PRIEST"
                local cleanName = string.match(shieldCasterName, "([^-]+)")

                if not activeHealers[shieldCasterGUID] then
                    local unitToken = "player"
                    if shieldCasterGUID ~= UnitGUID("player") then
                        if IsInRaid() then
                            for i = 1, GetNumGroupMembers() do
                                if UnitGUID("raid"..i) == shieldCasterGUID then unitToken = "raid"..i break end
                            end
                        else
                            for i = 1, GetNumGroupMembers() - 1 do
                                if UnitGUID("party"..i) == shieldCasterGUID then unitToken = "party"..i break end
                            end
                        end
                    end
                    local startingMana = UnitPower(unitToken, 0) or 0

                    activeHealers[shieldCasterGUID] = { 
                        name = cleanName, 
                        class = classFilename, 
                        effective = 0, 
                        overheal = 0, 
                        percent = 0,
                        unitId = unitToken,
                        manaAtStart = startingMana,
                        manaUsed = 0,
                        hpm = 0
                    }
                end
                activeHealers[shieldCasterGUID].effective = activeHealers[shieldCasterGUID].effective + shieldAbsorbAmount
                coreFrame.RefreshStats()
            end
        end
    end
end

-- Event registration
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
            
            -- Save historical fight data including the new mana properties
            if HealSmartSettings then
                HealSmartSettings.lastFightData = {}
                for guid, data in pairs(activeHealers) do
                    -- Lock down the final mana used value right as combat ends permanently
                    local currentMana = UnitPower(data.unitId, 0) or 0
                    if data.manaAtStart > 0 and currentMana < data.manaAtStart then
                        data.manaUsed = data.manaAtStart - currentMana
                    end
                    if data.manaUsed >= HEALSMART_MANA_THRESHOLD and data.manaUsed > 0 then
                        data.hpm = data.effective / data.manaUsed
                    else
                        data.hpm = 0
                    end

                    HealSmartSettings.lastFightData[guid] = {
                        name = data.name,
                        class = data.class,
                        effective = data.effective,
                        overheal = data.overheal,
                        percent = data.percent,
                        unitId = data.unitId,
                        manaAtStart = data.manaAtStart,
                        manaUsed = data.manaUsed,
                        hpm = data.hpm
                    }
                end
            end
        end
    end
end)

-- end healsmartcore.lua