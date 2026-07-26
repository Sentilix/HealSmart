-- ==========================================
-- HealSmart - Core Engine (v0.2.0)
-- ==========================================

-- Session tracking variables
local sessionEffective = 0
local sessionOverheal = 0
local isSessionActive = false      -- True as long as a session is running (including grace period)
local inTrueCombat = false         -- Reflects the player's actual combat state in WoW
local timeSinceCombatEnd = 0

-- 1. Create a hidden core frame to handle events and timers
local coreFrame = CreateFrame("Frame")

-- 2. Calculate and push current efficiency stats to UI
local function RefreshHealingStats()
    local totalHealing = sessionEffective + sessionOverheal

    -- If no healing has occurred in this session yet
    if totalHealing == 0 then
        if HealSmart_UpdateBar then
            HealSmart_UpdateBar(0, "--%")
        end
        return
    end

    -- Calculate efficiency percentage
    local effectivePercent = (sessionEffective / totalHealing) * 100

    -- Format the text string to just show "nn%"
    local textString = string.format("%.0f%%", effectivePercent)
    
    -- Push the new data to our UI frame
    if HealSmart_UpdateBar then
        HealSmart_UpdateBar(effectivePercent, textString)
    end
end

-- 3. Combat log parser (With SPELL_ABSORBED handling)
local function OnCombatLogEvent()
    if not isSessionActive then return end

    -- Unpack standard combat log fields
    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    -- --- A: DIRECT HEALS & HOTS ---
    if sourceGUID == UnitGUID("player") and (eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL") then
        local _, _, _, _, _, _, _, _, _, _, _, _, _, _, amount, overheal = CombatLogGetCurrentEventInfo()
        
        overheal = overheal or 0
        amount = amount or 0
        local effective = amount - overheal
        if effective < 0 then effective = 0 end

        sessionEffective = sessionEffective + effective
        sessionOverheal = sessionOverheal + overheal
        RefreshHealingStats()

    -- --- B: SHIELDS & ABSORBS (Modern 1.15+ CLEU) ---
    elseif eventType == "SPELL_ABSORBED" then
        -- SPELL_ABSORBED structure has variable arguments depending on whether it was a swing or a spell that was absorbed.
        -- To avoid offset bugs, we extract fields from the end of the event:
        -- The last parameters for SPELL_ABSORBED are always: casterGUID, casterName, casterFlags, casterRaidFlags, absorbSpellId, absorbSpellName, absorbSpellSchool, amount
        local _, _, _, _, _, _, _, _, _, _, _, _, _, _, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22 = CombatLogGetCurrentEventInfo()
        
        -- Let's find the casterGUID and amount based on whether it was a spell or swing absorb
        local shieldCasterGUID, shieldAbsorbAmount
        
        if type(arg15) == "number" then
            -- Triggered by a SPELL_DAMAGE event (has 3 extra spell payload fields)
            shieldCasterGUID = arg18
            shieldAbsorbAmount = arg22
        else
            -- Triggered by a SWING_DAMAGE event
            shieldCasterGUID = arg15
            shieldAbsorbAmount = arg19
        end

        -- Filter: Only count it if the shield was originally cast by you!
        if shieldCasterGUID == UnitGUID("player") and shieldAbsorbAmount then
            sessionEffective = sessionEffective + shieldAbsorbAmount
            RefreshHealingStats()
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
            sessionEffective = 0
            sessionOverheal = 0
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