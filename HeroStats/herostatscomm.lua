-- ==========================================
-- HeroStats - Communications & Reporting Engine (v0.10.2)
-- ==========================================

-- FIXED v0.10.2: Async chat queue engine handles global and custom channels to prevent silent spam bans
function HeroStats_SendQueuedMessages(msgList, channel, isCustom, customNum)
    if not msgList or #msgList == 0 then return end

    -- Route through the timer queue if it is a global server channel or a numbered custom channel
    local useTimerQueue = (channel == "GUILD" or channel == "OFFICER" or isCustom)

    if useTimerQueue then
        local index = 1
        local function SendNextLine()
            if index <= #msgList then
                local lineMsg = msgList[index]
                if isCustom and customNum then
                    -- Safely tunnels your lines into custom numbered channels with a 300ms window
                    SendChatMessage(lineMsg, "CHANNEL", nil, customNum)
                else
                    SendChatMessage(lineMsg, channel)
                end
                index = index + 1
                C_Timer.After(0.3, SendNextLine)
            end
        end
        SendNextLine()
    else
        -- Instant firing loop remains locked strictly to local secure layers (Raid/Party/Say)
        for _, lineMsg in ipairs(msgList) do
            SendChatMessage(lineMsg, channel)
        end
    end
end

-- FIXED v0.10.2: Upgraded to feed the new asynchronous packet management queue layout
function HeroStats_Report_DamageDone(playerData, channel, isCustom, customNum, fightSeconds)
    if not playerData or not playerData.spellDamage then return end
    
    local msgQueue = {}
    local dps = (fightSeconds > 0) and (playerData.damageDone / fightSeconds) or 0
    local formattedTotal = FormatDotNumber and FormatDotNumber(playerData.damageDone) or playerData.damageDone
    local headerMsg = string.format("HeroStats - Top Damage Done for %s: %s (%.0f DPS):", playerData.name or "Unknown", formattedTotal, dps)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, amt in pairs(playerData.spellDamage) do
        if amt > 0 then table.insert(sortedSpells, { name = spellName, amount = amt }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local sharePct = (playerData.damageDone > 0) and ((s.amount / playerData.damageDone) * 100) or 0
        local formattedAmt = FormatDotNumber and FormatDotNumber(s.amount) or s.amount
        local lineMsg = string.format("%d. %s: %s (%.1f%%)", i, s.name, formattedAmt, sharePct)
        table.insert(msgQueue, lineMsg)
    end
    
    HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
end

-- FIXED v0.10.2: Upgraded to feed the new asynchronous packet management queue layout
function HeroStats_Report_DamageCrits(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellCrits then return end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Top Damage Crits for %s:", playerData.name or "Unknown")
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    local totalSessionCritDmg = 0
    for spellName, cr in pairs(playerData.spellCrits) do
        local totalCritDmg = cr.dmg or 0
        if totalCritDmg > 0 then
            table.insert(sortedSpells, { name = spellName, crits = cr.crits or 0, dmg = totalCritDmg })
            totalSessionCritDmg = totalSessionCritDmg + totalCritDmg
        end
    end
    table.sort(sortedSpells, function(a, b) return a.dmg > b.dmg end)
    if totalSessionCritDmg == 0 then totalSessionCritDmg = 1 end

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local spellCritSharePct = (s.dmg / totalSessionCritDmg) * 100
        local formattedDmg = FormatDotNumber and FormatDotNumber(s.dmg) or s.dmg
        local lineMsg = string.format("%d. %s: %s (%d crits) (%.1f%%)", i, s.name, formattedDmg, s.crits, spellCritSharePct)
        table.insert(msgQueue, lineMsg)
    end
    
    HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
end

-- FIXED v0.10.2: Upgraded to feed the new asynchronous packet management queue layout
function HeroStats_Report_DamageTaken(playerData, channel, isCustom, customNum, fightSeconds)
    if not playerData or not playerData.spellTaken then return end
    
    local msgQueue = {}
    local dtps = (fightSeconds > 0) and (playerData.damageTaken / fightSeconds) or 0
    local formattedTotal = FormatDotNumber and FormatDotNumber(playerData.damageTaken) or playerData.damageTaken
    local headerMsg = string.format("HeroStats - Top Damage Taken for %s: %s (%.0f DTPS):", playerData.name or "Unknown", formattedTotal, dtps)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, amt in pairs(playerData.spellTaken) do
        if amt > 0 then table.insert(sortedSpells, { name = spellName, amount = amt }) end end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local sharePct = (playerData.damageTaken > 0) and ((s.amount / playerData.damageTaken) * 100) or 0
        local formattedAmt = FormatDotNumber and FormatDotNumber(s.amount) or s.amount
        local lineMsg = string.format("%d. %s: %s (%.1f%%)", i, s.name, formattedAmt, sharePct)
        table.insert(msgQueue, lineMsg)
    end
    
    HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
end

-- FIXED v0.10.2: Upgraded to feed the new asynchronous packet management queue layout
function HeroStats_Report_HealingDone(playerData, channel, isCustom, customNum, fightSeconds)
    if not playerData or not playerData.spellHeals then return end
    
    local msgQueue = {}
    local hps = (fightSeconds > 0) and (playerData.effective / fightSeconds) or 0
    local formattedTotal = FormatDotNumber and FormatDotNumber(playerData.effective) or playerData.effective
    local headerMsg = string.format("HeroStats - Top Healing Done for %s: %s (%.0f HPS):", playerData.name or "Unknown", formattedTotal, hps)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, hData in pairs(playerData.spellHeals) do
        if hData.effective > 0 then table.insert(sortedSpells, { name = spellName, amount = hData.effective, overheal = hData.overheal or 0 }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local sharePct = (playerData.effective > 0) and ((s.amount / playerData.effective) * 100) or 0
        local totalSpellHeal = s.amount + s.overheal
        local ohPct = (totalSpellHeal > 0) and ((s.overheal / totalSpellHeal) * 100) or 0
        local formattedAmt = FormatDotNumber and FormatDotNumber(s.amount) or s.amount
        local lineMsg = string.format("%d. %s: %s (%.1f%%) [OH: %.0f%%]", i, s.name, formattedAmt, sharePct, ohPct)
        table.insert(msgQueue, lineMsg)
    end
    
    HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
end

-- FIXED v0.10.2: Upgraded to feed the new asynchronous packet management queue layout
function HeroStats_Report_HealingCrits(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellHealCrits then return end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Top Healing Crits for %s:", playerData.name or "Unknown")
    table.insert(msgQueue, headerMsg)

    local sortedHeals = {}
    local totalSessionCritHeal = 0
    for spellName, cr in pairs(playerData.spellHealCrits) do
        local totalCritHeal = cr.amt or 0
        if totalCritHeal > 0 then
            table.insert(sortedHeals, { name = spellName, crits = cr.crits or 0, amt = totalCritHeal })
            totalSessionCritHeal = totalSessionCritHeal + totalCritHeal
        end
    end
    table.sort(sortedHeals, function(a, b) return a.amt > b.amt end)
    if totalSessionCritHeal == 0 then totalSessionCritHeal = 1 end

    for i = 1, math.min(5, #sortedHeals) do
        local h = sortedHeals[i]
        local spellCritSharePct = (h.amt / totalSessionCritHeal) * 100
        local formattedHeal = FormatDotNumber and FormatDotNumber(h.amt) or h.amt
        local lineMsg = string.format("%d. %s: %s (%d crits) (%.1f%%)", i, h.name, formattedHeal, h.crits, spellCritSharePct)
        table.insert(msgQueue, lineMsg)
    end
    
    HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
end

-- FIXED v0.10.2: Upgraded to feed the new asynchronous packet management queue layout
function HeroStats_Report_Efficiency(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellHeals then return end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Overhealing Breakdown for %s (%.1f%% Efficiency):", playerData.name or "Unknown", playerData.percent or 0)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, hData in pairs(playerData.spellHeals) do
        local total = (hData.effective or 0) + (hData.overheal or 0)
        if total > 0 then table.insert(sortedSpells, { name = spellName, effective = hData.effective or 0, overheal = hData.overheal or 0, total = total }) end
    end
    table.sort(sortedSpells, function(a, b) return b.overheal > a.overheal end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local spellEffPct = (s.total > 0) and ((s.effective / s.total) * 100) or 0
        local formattedOH = FormatDotNumber and FormatDotNumber(s.overheal) or s.overheal
        local lineMsg = string.format("%d. %s: %s Overheal (Ability Eff: %.1f%%)", i, s.name, formattedOH, spellEffPct)
        table.insert(msgQueue, lineMsg)
    end
    
    HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
end

-- FIXED v0.10.2: Upgraded to feed the new asynchronous packet management queue layout
function HeroStats_Report_ManaEff(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellMana then return end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Heal per Mana for %s (%.1f HPM):", playerData.name or "Unknown", playerData.hpm or 0)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, mData in pairs(playerData.spellMana) do
        local mUsed = mData.manaUsed or 0
        if mUsed > 0 then
            local trueEffective = mData.effective or 0
            if trueEffective == 0 and playerData.spellHeals and playerData.spellHeals[spellName] then
                trueEffective = playerData.spellHeals[spellName].effective or 0
            end
            local spellHPM = trueEffective / mUsed
            table.insert(sortedSpells, { name = spellName, hpm = spellHPM, used = mUsed })
        end
    end
    table.sort(sortedSpells, function(a, b) return a.hpm > b.hpm end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local formattedMana = FormatDotNumber and FormatDotNumber(s.used) or s.used
        local lineMsg = string.format("%d. %s %s mana (%.1f HPM)", i, s.name, formattedMana, s.hpm)
        table.insert(msgQueue, lineMsg)
    end
    
    HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
end

-- FIXED v0.10.2: Upgraded to feed the new asynchronous packet management queue layout
function HeroStats_Report_ManaGained(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellManaGained then return end
    
    local msgQueue = {}
    local formattedTotal = FormatDotNumber and FormatDotNumber(playerData.manaGained) or playerData.manaGained
    local headerMsg = string.format("HeroStats - Mana Gained Breakdown for %s: %s total mana:", playerData.name or "Unknown", formattedTotal)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, amt in pairs(playerData.spellManaGained) do
        if amt > 0 then table.insert(sortedSpells, { name = spellName, amount = amt }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local formattedAmt = FormatDotNumber and FormatDotNumber(s.amount) or s.amount
        local lineMsg = string.format("%d. %s: +%s mana", i, s.name, formattedAmt)
        table.insert(msgQueue, lineMsg)
    end
    
    HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
end

-- FIXED v0.10.2: Upgraded to feed the new asynchronous packet management queue layout
function HeroStats_Report_Dispels(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellDispels then return end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Dispels Breakdown for %s (%d total):", playerData.name or "Unknown", playerData.dispels or 0)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, amt in pairs(playerData.spellDispels) do
        if amt > 0 then table.insert(sortedSpells, { name = spellName, amount = amt }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local lineMsg = string.format("%d. %s: %d dispels", i, s.name, s.amount)
        table.insert(msgQueue, lineMsg)
    end
    
    HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
end

-- FIXED v0.10.2: Upgraded to feed the new asynchronous packet management queue layout
function HeroStats_Report_Buffs(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellBuffs then return end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Applied Buffs Breakdown for %s (%d total):", playerData.name or "Unknown", playerData.buffs or 0)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, amt in pairs(playerData.spellBuffs) do
        if amt > 0 then table.insert(sortedSpells, { name = spellName, amount = amt }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local lineMsg = string.format("%d. %s: %d casts", i, s.name, s.amount)
        table.insert(msgQueue, lineMsg)
    end
    
    HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
end

-- FIXED v0.10.2: Upgraded to feed the new asynchronous packet management queue layout
function HeroStats_Report_Deaths(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.deathCauses then return end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Fatal Damage Log for %s (%d deaths):", playerData.name or "Unknown", playerData.deaths or 0)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, amt in pairs(playerData.deathCauses) do
        if amt > 0 then table.insert(sortedSpells, { name = spellName, amount = amt }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local lineMsg = string.format("%d. %s: %d fatalities", i, s.name, s.amount)
        table.insert(msgQueue, lineMsg)
    end
    
    HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
end

-- FIXED v0.10.2: Upgraded to feed the new asynchronous packet management queue layout
function HeroStats_Report_Resurrects(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.resRecipients then return end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Resurrect Recipients for %s (%d casted):", playerData.name or "Unknown", playerData.resurrects or 0)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for targetName, rData in pairs(playerData.resRecipients) do
        local tAmt = type(rData) == "table" and rData.amount or rData
        if tAmt > 0 then table.insert(sortedSpells, { name = targetName, amount = tAmt }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local lineMsg = string.format("%d. %s: Brought back %d times", i, s.name, s.amount)
        table.insert(msgQueue, lineMsg)
    end
    
    HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
end

-- end herostatscomm.lua
