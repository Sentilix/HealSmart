-- ==========================================
-- HealSmart - Core Engine
-- ==========================================

-- Data storage for our rolling window
-- Each entry will contain: { timestamp = GetTime(), effective = value, overheal = value }
local healingHistory = {}

-- 1. Create a hidden core frame to handle events and timers
local coreFrame = CreateFrame("Frame")

-- 2. Clean old data and calculate current efficiency
local function RefreshHealingStats()
    local currentTime = GetTime()
    local cutoffTime = currentTime - HEALSMART_REFRESH_WINDOW

    local totalEffective = 0
    local totalOverheal = 0

    -- Loop backwards to safely remove expired entries
    for i = #healingHistory, 1, -1 do
        local entry = healingHistory[i]
        if entry.timestamp < cutoffTime then
            table.remove(healingHistory, i)
        else
            totalEffective = totalEffective + entry.effective
            totalOverheal = totalOverheal + entry.overheal
        end
    end

    local totalHealing = totalEffective + totalOverheal

    -- If no healing has occurred in the window, reset the bar display to empty with "--%"
    if totalHealing == 0 then
        if HealSmart_UpdateBar then
            HealSmart_UpdateBar(0, "--%")
        end
        return
    end

    -- Calculate efficiency percentage
    local effectivePercent = (totalEffective / totalHealing) * 100

    -- Format the text string to just show "nn%"
    local textString = string.format("%.0f%%", effectivePercent)
    
    -- Push the new data to our UI frame
    if HealSmart_UpdateBar then
        HealSmart_UpdateBar(effectivePercent, textString)
    end
end

-- 3. Combat log parser
local function OnCombatLogEvent()
    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    -- Filter: Only look at healing events cast by the player
    if sourceGUID == UnitGUID("player") and (eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL") then
        local _, _, _, _, _, _, _, _, _, _, _, _, _, _, amount, overheal = CombatLogGetCurrentEventInfo()
        
        overheal = overheal or 0
        amount = amount or 0
        local effective = amount - overheal

        if effective < 0 then effective = 0 end

        -- Store the event with a high-precision timestamp
        table.insert(healingHistory, {
            timestamp = GetTime(),
            effective = effective,
            overheal = overheal
        })

        -- Instantly refresh stats on a successful heal
        RefreshHealingStats()
    end
end

-- 4. Event registration and routing
coreFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
coreFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
    end
end)

-- 5. Sliding window cleaner ticker (Runs roughly every 0.5 seconds to clean old data)
local timeSinceLastUpdate = 0
coreFrame:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate >= 0.5 then
        timeSinceLastUpdate = 0
        RefreshHealingStats()
    end
end)

-- end healsmartcore.lua