-- ==========================================
-- HealSmart - Core Engine (v0.6.0) - PART 1 & 2 (Global Variable Framework)
-- ==========================================

-- Configuration Constants
HEALSMART_MAX_SAVED_SESSIONS = 20

HealSmart_CurrentActivePage = 0 
HealSmart_CurrentFightDuration = 0

-- Runtime cache objects
local playerGUID = UnitGUID("player")
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
local timerFrame = CreateFrame("Frame")
local fightStartTime = 0

timerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
timerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
timerFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- RESET AND START: Combat has initiated
        fightStartTime = GetTime()
        HealSmart_CurrentFightDuration = 0
        
        -- Start an independent on-update ticker to count seconds live
        self:SetScript("OnUpdate", function()
            if fightStartTime > 0 then
                HealSmart_CurrentFightDuration = GetTime() - fightStartTime
            end
        end)
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:SetScript("OnUpdate", nil)
        
        if fightStartTime > 0 then
            HealSmart_CurrentFightDuration = GetTime() - fightStartTime
            
            -- STAMP THE DURATION: Lock the precise seconds directly onto the active session data
            if HealSmartSettings and HealSmartSettings.sessions then
                local targetIdx = HealSmartSettings.activeSessionIndex or #HealSmartSettings.sessions
                local currentSession = HealSmartSettings.sessions[targetIdx]
                if currentSession then
                    -- Save the fight duration cleanly inside this specific session container
                    currentSession.fightDuration = HealSmart_CurrentFightDuration
                end
            end
            
            -- Accumulate the total database time onto your Overall/Total data tracking layer
            if HealSmartSettings and HealSmartSettings.overallData then
                if not HealSmartSettings.overallData.totalTime then HealSmartSettings.overallData.totalTime = 0 end
                HealSmartSettings.overallData.totalTime = HealSmartSettings.overallData.totalTime + HealSmart_CurrentFightDuration
            end
        end
        fightStartTime = 0
        if coreFrame.RefreshStats then coreFrame.RefreshStats() end
    end
end)

-- Multi-Session Profile Factory: Securely fetches or creates data rows within any sub-table target
function HealSmart_GetOrCreateProfile(dataTable, guid, name, classToken)
    if not dataTable then return nil end
    if not dataTable[guid] then
        local unitToken = "player"
        local finalClass = classToken
        
        if guid ~= playerGUID then
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
            buffs = 0,
            damageDone = 0,
            damageTaken = 0,
            manaGained = 0,
            damageDone = 0,
            damageTaken = 0,
            manaGained = 0,
            spellHeals = {},
            spellDamage = {},
            spellTaken = {},
            spellBuffs = {},
            spellMana = {}
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
-- HealSmart - Core Engine (v0.8.0) - PART 2 (Zero-Value Filter Refactor)
-- ==========================================

local sortedHealers = {}

function coreFrame.RefreshStats()
    -- Unified v0.8.0 Data-Driven Token Matrix Routing
    local pageRecord = HealSmart_GetPageRecord(HealSmart_CurrentActivePage)
    local pageName = pageRecord.name
    local viewTitle = pageRecord.title

    -- FRONTPAGE HANDLING: Safely short-circuit if on the welcome screen
    if pageName == "FRONTPAGE" then
        if uiBars then
            for _, bar in ipairs(uiBars) do
                if bar and bar.Hide then bar:Hide() end
            end
        end

        local welcomeMessage = "Welcome to HealSmart!\n\nUse the < and > arrows in the top right to switch statistics screens.\n\nData tracks automatically as soon as combat starts."
        if HealSmart_RenderTextMessage then
            HealSmart_RenderTextMessage(viewTitle or "HealSmart", welcomeMessage)
        end
        return
    end

    -- Clear previous fight cache cleanly
    table.wipe(sortedHealers)
    
    -- CONSOLIDATED MASTER TRACKERS: Your original trusted variables + new extensions (NO DUPLICATES!)
    local topHealerAmount = 0
    local totalRaidEffective = 0 
    local topHPMValue = 0 
    local topDispelValue = 0
    local topDeathValue = 0
    local topRessValue = 0
    local topBuffsValue = 0
    local topDamageDoneValue = 0
    local topDamageTakenValue = 0
    local topManaGainedValue = 0

    local activeThreshold = HEALSMART_MANA_THRESHOLD or 300
    if not IsInGroup() then activeThreshold = 0 end

    local dataSourceTable = nil
    local sessionLabel = "Current Fight"
    local activeViewID = HealSmartSettings and HealSmartSettings.selectedViewSessionID or 0

    if activeViewID == -1 then
        dataSourceTable = HealSmartSettings and HealSmartSettings.overallData
        sessionLabel = "Overall Total"
    else
        if HealSmartSettings and HealSmartSettings.sessions then
            local targetIdx = HealSmartSettings.activeSessionIndex or 1
            if activeViewID > 0 then
                for idx, session in ipairs(HealSmartSettings.sessions) do
                    if session.id == activeViewID then
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

    -- NEW v0.9.0: Dynamic Historical Time Calibration Pipeline
    local activeFightSeconds = HealSmart_CurrentFightDuration or 0 -- Default fallback
    
    if activeViewID == -1 then
        -- If viewing Overall Total, pull the full accumulated historical time
        activeFightSeconds = HealSmartSettings and HealSmartSettings.overallData and HealSmartSettings.overallData.totalTime or 0
    else
        if HealSmartSettings and HealSmartSettings.sessions then
            local targetIdx = HealSmartSettings.activeSessionIndex or 1
            if activeViewID > 0 then
                for idx, session in ipairs(HealSmartSettings.sessions) do
                    if session.id == activeViewID then
                        targetIdx = idx
                        break
                    end
                end
            end
            local sessionData = HealSmartSettings.sessions[targetIdx]
            -- Pull the frozen historical seconds directly from this specific archived fight!
            activeFightSeconds = sessionData and sessionData.fightDuration or activeFightSeconds
        end
    end
    
    -- Safeguard to prevent division by zero or negative integers
    if activeFightSeconds < 1 then activeFightSeconds = 1 end
    
    -- Now export this local calibrated time out so your UI function can see it perfectly
    -- (We simply overwrite the global variable for this specific render tick frame)
    HealSmart_CurrentFightDuration_RenderOverride = activeFightSeconds

    if dataSourceTable then
        for guid, data in pairs(dataSourceTable) do
            -- Dynamically disable class locks on damage pages using text tokens!
            local isDamagePage = (pageName == "DAMAGE_DONE" or pageName == "DAMAGE_TAKEN")
            
            if currentFilterMode == "CLASS" and data.class ~= playerClassFilename and not isDamagePage then
                -- Filtered safely
            else
                local total = data.effective + data.overheal
                data.percent = (total > 0) and ((data.effective / total) * 100) or 0
                data.manaUsed = data.manaUsed or 0
                data.deaths = data.deaths or 0
                data.resurrects = data.resurrects or 0
                data.dispels = data.dispels or 0
                data.buffs = data.buffs or 0
                data.damageDone = data.damageDone or 0
                data.damageTaken = data.damageTaken or 0
                data.manaGained = data.manaGained or 0

                -- Calculate and track factual HPM yields safely
                if data.manaUsed > 0 then
                    data.hpm = data.effective / data.manaUsed
                    if data.manaUsed >= activeThreshold then
                        if data.hpm > topHPMValue then topHPMValue = data.hpm end
                    end
                else
                    data.hpm = 0
                end

                -- Accumulate maximum thresholds inside your dataset loops
                if data.damageDone > topDamageDoneValue then topDamageDoneValue = data.damageDone end
                if data.damageTaken > topDamageTakenValue then topDamageTakenValue = data.damageTaken end
                if data.buffs > topBuffsValue then topBuffsValue = data.buffs end
                if data.manaGained > topManaGainedValue then topManaGainedValue = data.manaGained end

                -- Pure data-driven token filter mapping gates
                local shouldInclude = false
                if pageName == "HEALING" or pageName == "OVERHEALING" or pageName == "MANA_EFF" then
                    if (data.effective or 0) > 0 or (data.overheal or 0) > 0 then shouldInclude = true end
                elseif pageName == "DISPELS" then
                    if (data.dispels or 0) > 0 then shouldInclude = true end
                elseif pageName == "BUFFS" then
                    if (data.buffs or 0) > 0 then shouldInclude = true end
                elseif pageName == "DEATHS" then
                    if (data.deaths or 0) > 0 then shouldInclude = true end
                elseif pageName == "RESURRECTS" then
                    if (data.resurrects or 0) > 0 then shouldInclude = true end
                elseif pageName == "DAMAGE_DONE" then
                    if (data.damageDone or 0) > 0 then shouldInclude = true end
                elseif pageName == "DAMAGE_TAKEN" then
                    if (data.damageTaken or 0) > 0 then shouldInclude = true end
                elseif pageName == "MANA_GAINED" then
                    if (data.manaGained or 0) > 0 then shouldInclude = true end
                end

                if shouldInclude then
                    table.insert(sortedHealers, data)
                    totalRaidEffective = totalRaidEffective + data.effective
                    if data.effective > topHealerAmount then topHealerAmount = data.effective end
                    if data.dispels > topDispelValue then topDispelValue = data.dispels end
                    if data.deaths > topDeathValue then topDeathValue = data.deaths end
                    if data.resurrects > topRessValue then topRessValue = data.resurrects end
                end
            end
        end
    end

    -- Render blank state if no dataset rows found (v0.8.0 Data-Driven Secured)
    if #sortedHealers == 0 then
        local baseTitle = viewTitle or "HealSmart"
        local pageTitle = baseTitle .. " (" .. sessionLabel .. ")"
        if HealSmart_RenderTextMessage then HealSmart_RenderTextMessage(pageTitle, "") end
        return
    end

    -- FIXED v0.8.0: Data-driven sorting and rendering pipeline (Consolidated & Token Synchronized)
    if pageName == "DAMAGE_DONE" then
        table.sort(sortedHealers, function(a, b) return (a.damageDone == b.damageDone) and (a.name < b.name) or (a.damageDone > b.damageDone) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topDamageDoneValue, "DAMAGE_DONE", 0, viewTitle) end
        
    elseif pageName == "DAMAGE_TAKEN" then
        table.sort(sortedHealers, function(a, b) return (a.damageTaken == b.damageTaken) and (a.name < b.name) or (a.damageTaken > b.damageTaken) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topDamageTakenValue, "DAMAGE_TAKEN", 0, viewTitle) end

    elseif pageName == "HEALING" then
        table.sort(sortedHealers, function(a, b) return (a.effective == b.effective) and (a.name < b.name) or (a.effective > b.effective) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topHealerAmount, "HEALING", totalRaidEffective, viewTitle) end
        
    elseif pageName == "OVERHEALING" then
        table.sort(sortedHealers, function(a, b) return (a.percent == b.percent) and (a.name < b.name) or (a.percent > b.percent) end)       
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, 100, "OVERHEALING", 0, viewTitle) end
        
    elseif pageName == "MANA_EFF" then
        table.sort(sortedHealers, function(a, b) return (a.hpm == b.hpm) and (a.name < b.name) or (a.hpm > b.hpm) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topHPMValue, "MANA_EFF", 0, viewTitle) end
        
    elseif pageName == "MANA_GAINED" then
        table.sort(sortedHealers, function(a, b) return (a.manaGained == b.manaGained) and (a.name < b.name) or (a.manaGained > b.manaGained) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topManaGainedValue, "MANA_GAINED", 0, viewTitle) end

    elseif pageName == "DISPELS" then
        table.sort(sortedHealers, function(a, b) return (a.dispels == b.dispels) and (a.name < b.name) or (a.dispels > b.dispels) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topDispelValue, "DISPELS", 0, viewTitle) end
        
    elseif pageName == "BUFFS" then
        table.sort(sortedHealers, function(a, b) return (a.buffs == b.buffs) and (a.name < b.name) or (a.buffs > b.buffs) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topBuffsValue, "BUFFS", 0, viewTitle) end
        
    elseif pageName == "DEATHS" then
        table.sort(sortedHealers, function(a, b) return (a.deaths == b.deaths) and (a.name < b.name) or (a.deaths > b.deaths) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topDeathValue, "DEATHS", 0, viewTitle) end
        
    elseif pageName == "RESURRECTS" then
        table.sort(sortedHealers, function(a, b) return (a.resurrects == b.resurrects) and (a.name < b.name) or (a.resurrects > b.resurrects) end)
        if HealSmart_RenderRaidBars then HealSmart_RenderRaidBars(sortedHealers, topRessValue, "RESURRECTS", 0, viewTitle) end
    end
end

function HealSmart_ChangePage(direction)
    local maxPages = #HealSmart_Pages
    HealSmart_CurrentActivePage = HealSmart_CurrentActivePage + direction
    
    if HealSmart_CurrentActivePage > maxPages then HealSmart_CurrentActivePage = 1 end
    if HealSmart_CurrentActivePage < 1 then HealSmart_CurrentActivePage = maxPages end
    
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

-- =========================================================================
-- --- HealSmart - Core Engine (v0.8.0) - OnCombatLogEvent Pipeline ---
-- =========================================================================
local activeHealers = nil;

--  SPELL_CAST_SUCCESS - processed both IN and OUT of combat)
local function OnEvent_SPELL_CAST_SUCCESS(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local _, spellName = select(12, CombatLogGetCurrentEventInfo())
    local cleanSourceName = sourceName and string.match(sourceName, "([^-]+)") or "Unknown"
    local healerClass = groupRosterCache[cleanSourceName]

    if sourceGUID == playerGUID and not healerClass then _, healerClass = UnitClass("player") end
    healerClass = healerClass or "UNKNOWN"

    local isCasterGroupMember = (sourceGUID == playerGUID) or
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

    if isCasterGroupMember and sourceName and spellName then
        local spellID = select(12, CombatLogGetCurrentEventInfo())
        local fullSpellName = spellName
            
        if spellID and C_Spell and C_Spell.GetSpellSubtext then
            local rankText = C_Spell.GetSpellSubtext(spellID)
            if rankText and rankText ~= "" then
                fullSpellName = string.format("%s (%s)", spellName, rankText)
            end
        end

        if spellID and C_Spell and C_Spell.GetSpellPowerCost then
            local costTable = C_Spell.GetSpellPowerCost(spellID)
            local costInfo = costTable and costTable[1]
            local actualCost = costInfo and costInfo.cost or 0
            local isHealingSpell = SPELL_CLASS_CACHE[spellName] or (spellName == "Power Word: Shield")

            if actualCost > 0 and isHealingSpell then
                local healer = HealSmart_GetOrCreateProfile(activeHealers, sourceGUID, cleanSourceName, healerClass)
                
                -- FIXED: Now safely locked inside the healing-filter wall!
                healer.manaUsed = (healer.manaUsed or 0) + actualCost

                if not healer.spellMana then healer.spellMana = {} end
                if not healer.spellMana[fullSpellName] then
                    healer.spellMana[fullSpellName] = { manaUsed = 0, effective = 0 }
                end
                healer.spellMana[fullSpellName].manaUsed = healer.spellMana[fullSpellName].manaUsed + actualCost

                if HealSmartSettings and HealSmartSettings.overallData then
                    local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, sourceGUID, cleanSourceName, healerClass)
                    
                    -- FIXED: Overall master safely locked inside the healing-filter wall too!
                    overallHealer.manaUsed = (overallHealer.manaUsed or 0) + actualCost

                    if not overallHealer.spellMana then overallHealer.spellMana = {} end
                    if not overallHealer.spellMana[fullSpellName] then
                        overallHealer.spellMana[fullSpellName] = { manaUsed = 0, effective = 0 }
                    end
                    overallHealer.spellMana[fullSpellName].manaUsed = overallHealer.spellMana[fullSpellName].manaUsed + actualCost
                end
            end
        end

        -- Run buff watchlist check
        if BUFF_WATCH_LIST[spellName] then
            local healer = HealSmart_GetOrCreateProfile(activeHealers, sourceGUID, cleanSourceName, healerClass)
            healer.buffs = (healer.buffs or 0) + 1
            if not healer.spellBuffs then healer.spellBuffs = {} end
            healer.spellBuffs[spellName] = (healer.spellBuffs[spellName] or 0) + 1

            if HealSmartSettings and HealSmartSettings.overallData then
                local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, sourceGUID, cleanSourceName, healerClass)
                overallHealer.buffs = (overallHealer.buffs or 0) + 1
                if not overallHealer.spellBuffs then overallHealer.spellBuffs = {} end
                overallHealer.spellBuffs[spellName] = (overallHealer.spellBuffs[spellName] or 0) + 1
            end
        end
        coreFrame.RefreshStats()
    end
end;

-- STANDARD DAMAGE DONE & DAMAGE TAKEN MOTORS (v0.8.0 - Rank-Separated)
local function OnEvent_DAMAGE(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local amount

    -- SWING_DAMAGE uses argument 12, while all SPELL and DoT variants use argument 15
    if eventType == "SWING_DAMAGE" then
        amount = select(12, CombatLogGetCurrentEventInfo())
    else
        amount = select(15, CombatLogGetCurrentEventInfo())
    end
        
    amount = amount or 0

    if amount > 0 then
        -- A: DAMAGE DONE DETECTION (Who is dealing damage?)
        local isSourceGroupMember = (sourceGUID == playerGUID) or
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isSourceGroupMember and sourceName and not string.find(sourceGUID, "^Pet-") then
            local cleanSourceName = string.match(sourceName, "([^-]+)")
            local sourceClass = groupRosterCache[cleanSourceName] or "UNKNOWN"
                
            -- Fetch spell context and combine it dynamically with the Rank subtext
            local spellID, spellName = select(12, CombatLogGetCurrentEventInfo())
            local fullSpellName = spellName
                
            if eventType == "SWING_DAMAGE" then 
                fullSpellName = "Melee" 
            elseif spellID and spellName and C_Spell and C_Spell.GetSpellSubtext then
                local rankText = C_Spell.GetSpellSubtext(spellID)
                if rankText and rankText ~= "" then
                    fullSpellName = string.format("%s (%s)", spellName, rankText)
                end
            end
                
            local profile = HealSmart_GetOrCreateProfile(activeHealers, sourceGUID, cleanSourceName, sourceClass)
            profile.damageDone = profile.damageDone + amount
                
            if fullSpellName then
                if not profile.spellDamage then profile.spellDamage = {} end
                profile.spellDamage[fullSpellName] = (profile.spellDamage[fullSpellName] or 0) + amount
            end
                
            if HealSmartSettings and HealSmartSettings.overallData then
                local overallProfile = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, sourceGUID, cleanSourceName, sourceClass)
                overallProfile.damageDone = overallProfile.damageDone + amount
                    
                if fullSpellName then
                    if not overallProfile.spellDamage then overallProfile.spellDamage = {} end
                    overallProfile.spellDamage[fullSpellName] = (overallProfile.spellDamage[fullSpellName] or 0) + amount
                end
            end
            coreFrame.RefreshStats()
        end

        -- DAMAGE TAKEN DETECTION (Who is taking damage? - FIXED v0.8.0)
        local isDestGroupMember = (destGUID == playerGUID) or
                                    (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                    (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                    (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isDestGroupMember and destName and not string.find(destGUID, "^Pet-") then
            local cleanDestName = string.match(destName, "([^-]+)")
            local destClass = groupRosterCache[cleanDestName] or "UNKNOWN"
                
            -- Extract the monster spell context safely based on the specific hit event type
            local spellName = "Melee"
            if eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "RANGE_DAMAGE" then
                _, spellName = select(12, CombatLogGetCurrentEventInfo())
            end
                
            local cleanSourceName = sourceName and string.match(sourceName, "([^-]+)") or "Environment"
            local combinedSourceKey = string.format("%s - %s", cleanSourceName, spellName or "Unknown")

            -- v0.8.0: Detect Blizzard Damage School Bitmasks to determine text coloring
            local schoolColor = "physical"
            if eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "RANGE_DAMAGE" then
                local schoolBit = select(14, CombatLogGetCurrentEventInfo())
                if schoolBit == 2 then schoolColor = "holy"
                elseif schoolBit == 4 then schoolColor = "fire"
                elseif schoolBit == 8 then schoolColor = "nature"
                elseif schoolBit == 16 then schoolColor = "frost"
                elseif schoolBit == 32 then schoolColor = "shadow"
                elseif schoolBit == 64 then schoolColor = "arcane" end
            end
                
            -- Manual override for Poison spells based on string context matching
            if spellName and (string.find(string.lower(spellName), "poison") or string.find(string.lower(spellName), "toxin")) then
                schoolColor = "poison"
            end

            local profile = HealSmart_GetOrCreateProfile(activeHealers, destGUID, cleanDestName, destClass)
            profile.damageTaken = profile.damageTaken + amount

            -- Secure multidimensional sub-table writing for current session matrix
            if not profile.spellTaken then profile.spellTaken = {} end
            if not profile.spellTaken[combinedSourceKey] then
                profile.spellTaken[combinedSourceKey] = { amt = 0, color = schoolColor }
            end
            profile.spellTaken[combinedSourceKey].amt = profile.spellTaken[combinedSourceKey].amt + amount
                
            if HealSmartSettings and HealSmartSettings.overallData then
                local overallProfile = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, destGUID, cleanDestName, destClass)
                overallProfile.damageTaken = overallProfile.damageTaken + amount
                    
                if not overallProfile.spellTaken then overallProfile.spellTaken = {} end
                if not overallProfile.spellTaken[combinedSourceKey] then
                    overallProfile.spellTaken[combinedSourceKey] = { amt = 0, color = schoolColor }
                end
                overallProfile.spellTaken[combinedSourceKey].amt = overallProfile.spellTaken[combinedSourceKey].amt + amount
            end
            coreFrame.RefreshStats()
        end
	end;
end;

--  DIRECT HEALS & HOTS (v0.8.0 - Rank-Separated & Parameter Secured)
local function OnEvent_HEAL(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local spellID, spellName = select(12, CombatLogGetCurrentEventInfo())
    local _, _, _, amount, overheal = select(12, CombatLogGetCurrentEventInfo())
        
    overheal = overheal or 0
    amount = amount or 0
    local effective = amount - overheal
    if effective < 0 then effective = 0 end

    local isGroupMember = (sourceGUID == playerGUID) or
                            (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                            (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                            (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

    if isGroupMember and sourceName then
        local cleanName = string.match(sourceName, "([^-]+)")
        local classFilename = groupRosterCache[cleanName] or SPELL_CLASS_CACHE[spellName]

        if classFilename and ALLOWED_CLASSES[classFilename] then
            local healer = HealSmart_GetOrCreateProfile(activeHealers, sourceGUID, cleanName, classFilename)
            healer.effective = healer.effective + effective
            healer.overheal = healer.overheal + overheal
                
            -- Dynamic Rank Compiler (e.g. "Flash Heal (Rank 4)")
            local fullSpellName = spellName
            if spellID and spellName and C_Spell and C_Spell.GetSpellSubtext then
                local rankText = C_Spell.GetSpellSubtext(spellID)
                if rankText and rankText ~= "" then
                    fullSpellName = string.format("%s (%s)", spellName, rankText)
                end
            end

            if fullSpellName then
                if not healer.spellHeals then healer.spellHeals = {} end
                if not healer.spellHeals[fullSpellName] then 
                    healer.spellHeals[fullSpellName] = { effective = 0, overheal = 0 } 
                end
                healer.spellHeals[fullSpellName].effective = healer.spellHeals[fullSpellName].effective + effective
                healer.spellHeals[fullSpellName].overheal = healer.spellHeals[fullSpellName].overheal + overheal
            end

            if HealSmartSettings and HealSmartSettings.overallData then
                local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, sourceGUID, cleanName, classFilename)
                overallHealer.effective = overallHealer.effective + effective
                overallHealer.overheal = overallHealer.overheal + overheal
                    
                if fullSpellName then
                    if not overallHealer.spellHeals then overallHealer.spellHeals = {} end
                    if not overallHealer.spellHeals[fullSpellName] then 
                        overallHealer.spellHeals[fullSpellName] = { effective = 0, overheal = 0 } 
                    end
                    overallHealer.spellHeals[fullSpellName].effective = overallHealer.spellHeals[fullSpellName].effective + effective
                    overallHealer.spellHeals[fullSpellName].overheal = overallHealer.spellHeals[fullSpellName].overheal + overheal
                        
                    -- Purely accumulate overall master effective yield safely
                    if not overallHealer.spellMana then overallHealer.spellMana = {} end
                    if not overallHealer.spellMana[fullSpellName] then
                        overallHealer.spellMana[fullSpellName] = { manaUsed = 0, effective = 0 }
                    end
                    overallHealer.spellMana[fullSpellName].effective = overallHealer.spellMana[fullSpellName].effective + effective
                end
            end
            coreFrame.RefreshStats()
        end
    end
end;

--  DETECT REFLECTED SHIELDS & THORNS (v0.8.0 - Factual Source Routing Locked)
local function OnEvent_SHIELD(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local _, _, _, sourceGUID, sourceName, sourceFlags, _, _, _, _ = CombatLogGetCurrentEventInfo()
    local amount = select(15, CombatLogGetCurrentEventInfo()) or 0

    if amount > 0 then
        local isPlayerSelf = (sourceGUID == playerGUID)
        local isSourceGroupMember = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if (isPlayerSelf or isSourceGroupMember) and sourceName then
            local cleanSourceName = string.match(sourceName, "([^-]+)")
                
            local sourceClass = groupRosterCache[cleanSourceName]
            if isPlayerSelf and not sourceClass then
                _, sourceClass = UnitClass("player")
            end
                
            sourceClass = sourceClass or "UNKNOWN"

            if ALLOWED_CLASSES[sourceClass] then
                -- NEW: Fetch the spellID and check for specific shield ranks dynamically
                local spellID, spellName = select(12, CombatLogGetCurrentEventInfo())
                local fullSpellName = spellName or "Damage Shield"
                    
                if spellID and spellName and C_Spell and C_Spell.GetSpellSubtext then
                    local rankText = C_Spell.GetSpellSubtext(spellID)
                    if rankText and rankText ~= "" then
                        fullSpellName = string.format("%s (%s)", spellName, rankText)
                    end
                end
                    
                local profile = HealSmart_GetOrCreateProfile(activeHealers, sourceGUID, cleanSourceName, sourceClass)
                profile.damageDone = profile.damageDone + amount
                    
                if fullSpellName then
                    if not profile.spellDamage then profile.spellDamage = {} end
                    profile.spellDamage[fullSpellName] = (profile.spellDamage[fullSpellName] or 0) + amount
                end
                    
                if HealSmartSettings and HealSmartSettings.overallData then
                    local overallProfile = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, sourceGUID, cleanSourceName, sourceClass)
                    overallProfile.damageDone = overallProfile.damageDone + amount
                        
                    if fullSpellName then
                        if not overallProfile.spellDamage then overallProfile.spellDamage = {} end
                        overallProfile.spellDamage[fullSpellName] = (overallProfile.spellDamage[fullSpellName] or 0) + amount
                    end
                end
                coreFrame.RefreshStats()
            end
        end
    end
end;

--  SHIELDS & ABSORBS
local function OnEvent_ABSORBED(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
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
        local isGroupMember = (shieldCasterGUID == playerGUID) or
                                (bit.band(shieldCasterFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                (bit.band(shieldCasterFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                (bit.band(shieldCasterFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isGroupMember then
            local cleanName = string.match(shieldCasterName, "([^-]+)")
            local healer = HealSmart_GetOrCreateProfile(activeHealers, shieldCasterGUID, cleanName, "PRIEST")
            healer.effective = healer.effective + shieldAbsorbAmount
                
            -- NEW v0.8.0: Aggregate Shield absorption abilities dynamically in current session
            if not healer.spellHeals then healer.spellHeals = {} end
            if not healer.spellHeals[absorbSpellName] then 
                healer.spellHeals[absorbSpellName] = { effective = 0, overheal = 0 } 
            end
            healer.spellHeals[absorbSpellName].effective = healer.spellHeals[absorbSpellName].effective + shieldAbsorbAmount

            if HealSmartSettings and HealSmartSettings.overallData then
                local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, shieldCasterGUID, cleanName, "PRIEST")
                overallHealer.effective = overallHealer.effective + shieldAbsorbAmount
                    
                -- Also aggregate into the overall night master totals safely
                if not overallHealer.spellHeals then overallHealer.spellHeals = {} end
                if not overallHealer.spellHeals[absorbSpellName] then 
                    overallHealer.spellHeals[absorbSpellName] = { effective = 0, overheal = 0 } 
                end
                overallHealer.spellHeals[absorbSpellName].effective = overallHealer.spellHeals[absorbSpellName].effective + shieldAbsorbAmount
            end
            coreFrame.RefreshStats()
        end
    end
end;

--  RAID DEATH WATCH ENGINE (Runs out-of-combat!)
local function OnEvent_UNIT_DIED(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)

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
end;

--  DISPEL TRACKING ENGINE (Runs out-of-combat!)
--  DISPEL TRACKING ENGINE (Runs out-of-combat!)
local function OnEvent_DISPELL(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local isCasterGroupMember = (sourceGUID == playerGUID) or
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

    if isCasterGroupMember and sourceName then
        local cleanSourceName = string.match(sourceName, "([^-]+)")
        local healerClass = groupRosterCache[cleanSourceName]
        if sourceGUID == playerGUID and not healerClass then _, healerClass = UnitClass("player") end
        healerClass = healerClass or "UNKNOWN"
            
        if ALLOWED_CLASSES[healerClass] then
            -- Safely query the active kampsession table array
            local sessionHealers = HealSmart_GetActiveSessionHealers()
            if sessionHealers then
                local healer = HealSmart_GetOrCreateProfile(sessionHealers, sourceGUID, cleanSourceName, healerClass)
                
                -- Update master totals
                healer.dispels = (healer.dispels or 0) + 1
                
                -- NEW v0.8.0: Fetch your own dispel ability name safely from the engine
                local _, dispelSpellName = select(12, CombatLogGetCurrentEventInfo())
                if dispelSpellName then
                    if not healer.spellDispels then healer.spellDispels = {} end
                    healer.spellDispels[dispelSpellName] = (healer.spellDispels[dispelSpellName] or 0) + 1
                end
                    
                if HealSmartSettings and HealSmartSettings.overallData then
                    local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, sourceGUID, cleanSourceName, healerClass)
                    overallHealer.dispels = (overallHealer.dispels or 0) + 1
                    
                    if dispelSpellName then
                        if not overallHealer.spellDispels then overallHealer.spellDispels = {} end
                        overallHealer.spellDispels[dispelSpellName] = (overallHealer.spellDispels[dispelSpellName] or 0) + 1
                    end
                end
                coreFrame.RefreshStats()
            end
        end
    end
end;

--  RESURRECTION TRACKING ENGINE (Runs out-of-combat!)
local function OnEvent_RESURRECT(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
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
end;

--  DETECT MANA GAINED EFFECTS (v0.8.0 - Potions, Innervate, Mana Tide)
local function OnEvent_MANAGAINS(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local spellID, spellName = select(12, CombatLogGetCurrentEventInfo())
    local amount, powerType = select(15, CombatLogGetCurrentEventInfo()) -- Amount is arg 15, PowerType is arg 16
        
    amount = tonumber(amount) or 0
    powerType = tonumber(powerType) or 0 -- 0 is the universal Blizzard enum token for Mana

    if amount > 0 and powerType == 0 and destName and not string.find(destGUID, "^Pet-") then
        local isDestGroupMember = (destGUID == playerGUID) or
                                  (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                  (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                  (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isDestGroupMember then
            local cleanDestName = string.match(destName, "([^-]+)")
            local destClass = groupRosterCache[cleanDestName]
            if destGUID == playerGUID and not destClass then _, destClass = UnitClass("player") end
            destClass = destClass or "UNKNOWN"

            if ALLOWED_CLASSES[destClass] then
                local sessionHealers = HealSmart_GetActiveSessionHealers()
                if sessionHealers then
                    local profile = HealSmart_GetOrCreateProfile(sessionHealers, destGUID, cleanDestName, destClass)
                    profile.manaGained = (profile.manaGained or 0) + amount
                    
                    if spellName then
                        if not profile.spellManaGained then profile.spellManaGained = {} end
                        profile.spellManaGained[spellName] = (profile.spellManaGained[spellName] or 0) + amount
                    end

                    if HealSmartSettings and HealSmartSettings.overallData then
                        local overallProfile = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, destGUID, cleanDestName, destClass)
                        overallProfile.manaGained = (overallProfile.manaGained or 0) + amount
                        
                        if spellName then
                            if not overallProfile.spellManaGained then overallProfile.spellManaGained = {} end
                            overallProfile.spellManaGained[spellName] = (overallProfile.spellManaGained[spellName] or 0) + amount
                        end
                    end
                    coreFrame.RefreshStats()
                end
            end
        end
    end
end;

--  DETECT COMPACT AURA PROCS (v0.8.0 - Tier 3 Epiphany Engine Secured)
local function OnEvent_AURA(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    if destGUID == playerGUID then
        local _, buffName = select(12, CombatLogGetCurrentEventInfo())
        
        if buffName == "Epiphany" then
            -- SAFETY GATE: Only log the 500 mana if a valid fight session dataset is actively running!
            local sessionHealers = HealSmart_GetActiveSessionHealers()
            if sessionHealers then
                local _, playerClass = UnitClass("player")
                local healer = HealSmart_GetOrCreateProfile(sessionHealers, playerGUID, "Mimma", playerClass or "PRIEST")
                
                healer.manaGained = (healer.manaGained or 0) + 500
                if not healer.spellManaGained then healer.spellManaGained = {} end
                healer.spellManaGained["Epiphany"] = (healer.spellManaGained["Epiphany"] or 0) + 500
                
                if HealSmartSettings and HealSmartSettings.overallData then
                    local overallHealer = HealSmart_GetOrCreateProfile(HealSmartSettings.overallData, playerGUID, "Mimma", playerClass or "PRIEST")
                    overallHealer.manaGained = (overallHealer.manaGained or 0) + 500
                    if not overallHealer.spellManaGained then overallHealer.spellManaGained = {} end
                    overallHealer.spellManaGained["Epiphany"] = (overallHealer.spellManaGained["Epiphany"] or 0) + 500
                end
                if coreFrame.RefreshStats then coreFrame.RefreshStats() end
            end
        end
    end
end;

local function OnCombatLogEvent()
    -- Fetch the active writing sub-table for the current active fight session
    activeHealers = HealSmart_GetActiveSessionHealers()
    if not activeHealers then return end

    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    if eventType == "SPELL_CAST_SUCCESS" then
	    OnEvent_SPELL_CAST_SUCCESS(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);

	elseif eventType == "UNIT_DIED" then
        OnEvent_UNIT_DIED(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);

    elseif eventType == "SPELL_DISPEL" then
        OnEvent_DISPELL(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);
	
    elseif eventType == "SPELL_RESURRECT" then
        OnEvent_RESURRECT(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);

    elseif eventType == "SPELL_AURA_APPLIED" then
        OnEvent_AURA(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);
		
	--  The next events only applies in combat, so bail out if not:
	elseif isSessionActive then
        if (eventType == "SWING_DAMAGE" or eventType == "SPELL_DAMAGE" or eventType == "RANGE_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE") then
            OnEvent_DAMAGE(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);

        elseif (eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL") then
            OnEvent_HEAL(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);

        elseif eventType == "DAMAGE_SHIELD" then
            OnEvent_SHIELD(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);
		
        elseif eventType == "SPELL_ABSORBED" then
            OnEvent_ABSORBED(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);		

        elseif eventType == "SPELL_ENERGIZE" then
            OnEvent_MANAGAINS(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);
        end; 
    end;
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
        -- FIXED v0.8.0: Reset the precise fight duration clock on pull
        HealSmart_CurrentFightDuration = 0
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
        
        local currentlyInGroup = IsInGroup() or IsInRaid()
        if currentlyInGroup and not wasInGroupLastCheck then
            if HealSmartSettings and HealSmartSettings.groupJoinBehavior then
                local behavior = HealSmartSettings.groupJoinBehavior
                if behavior == 1 then
                    HealSmart_ExecuteMasterWipeData()
                    if HealSmart_Print then HealSmart_Print("Automatically cleared history due to group join settings.") end
                elseif behavior == 3 then
                    StaticPopup_Show("HEALSMART_GROUP_JOIN_PROMPT")
                end
            end
        end
        wasInGroupLastCheck = currentlyInGroup
    end
end)

UpdateGroupRosterCache()

-- Inside your existing OnUpdate frame ticker loop, add this check:
local totalElapsed = 0
coreFrame:SetScript("OnUpdate", function(self, elapsed)
    if inTrueCombat then
        totalElapsed = totalElapsed + elapsed
        -- Every time 1 full second passes, tick the master combat clock up by 1
        if totalElapsed >= 1 then
            HealSmart_CurrentFightDuration = (HealSmart_CurrentFightDuration or 0) + 1
            totalElapsed = 0
            
            -- Live update bars while fighting so DPS/HPS changes in real-time
            if coreFrame.RefreshStats then coreFrame.RefreshStats() end
        end
    end
    
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

    -- FIXED v0.8.0: Data-driven title extraction safely mapped via your 1-based lookupFramework
    local pageRecord = HealSmart_GetPageRecord(HealSmart_CurrentActivePage)
    local baseTitle = pageRecord and pageRecord.title or "HealSmart Stats"
    local pageName = pageRecord and pageRecord.name;
    if pageName =="FRONTPAGE" then return; end;
    
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
            
            -- Pure data-driven token mapping for perfect chat reports
            if pageName == "HEALING" then
                local formattedAmt = FormatDotNumber and FormatDotNumber(data.effective) or data.effective
                lineMessage = string.format("%d. %s - %s Effective Healing", i, data.name, formattedAmt)
            elseif pageName == "OVERHEALING" then
                lineMessage = string.format("%d. %s - %.1f%% Healing Efficiency", i, data.name, data.percent)
            elseif pageName == "MANA_EFF" then
                lineMessage = string.format("%d. %s - %.1f HPM", i, data.name, data.hpm)
            elseif pageName == "DISPELS" then
                lineMessage = string.format("%d. %s - %d Dispels", i, data.name, data.dispels)
            elseif pageName == "BUFFS" then
                lineMessage = string.format("%d. %s - %d Buffs", i, data.name, data.buffs)
            elseif pageName == "DEATHS" then
                lineMessage = string.format("%d. %s - %d Deaths", i, data.name, data.deaths)
            elseif pageName == "RESURRECTS" then
                lineMessage = string.format("%d. %s - %d Resurrects", i, data.name, data.resurrects)
            elseif pageName == "DAMAGE_DONE" then
                local formattedAmt = FormatDotNumber and FormatDotNumber(data.damageDone) or data.damageDone
                lineMessage = string.format("%d. %s - %s Damage Done", i, data.name, formattedAmt)
            elseif pageName == "DAMAGE_TAKEN" then
                local formattedAmt = FormatDotNumber and FormatDotNumber(data.damageTaken) or data.damageTaken
                lineMessage = string.format("%d. %s - %s Damage Taken", i, data.name, formattedAmt)
            elseif pageName == "MANA_GAINED" then
                local formattedAmt = FormatDotNumber and FormatDotNumber(data.manaGained) or data.manaGained
                lineMessage = string.format("%d. %s - %s Mana Gained", i, data.name, formattedAmt)
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