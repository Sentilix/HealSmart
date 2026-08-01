-- ==========================================
-- HealSmart - Slash Command Engine (v0.6.0 Upgrade)
-- ==========================================

-- CENTRAL PRINT FACTORY: Manages the custom cyan addon logo and formatting globally
function HealSmart_Print(msg)
    if msg then
        print("|cff00bcffHealSmart:|r " .. msg)
    end
end

-- Netplay Version Checker: Registers hidden addon channel to query group version levels
local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == "HealSmartComm" then
        local command, value = string.match(text, "([^:]+):([^:]+)")
        if command == "QUERY_VERSION" then
            -- Respond silently back to the sender with our installed version token
            local _, cleanSender = string.match(sender, "([^-]+)")
            C_ChatInfo.SendAddonMessage("HealSmartComm", "RESP_VERSION:0.6.0", "WHISPER", sender)
        elseif command == "RESP_VERSION" and value then
            local cleanSender = string.match(sender, "([^-]+)") or sender
            HealSmart_Print(cleanSender .. " is running version " .. value)
        end
    end
end)

-- Register the secure addon network prefix with the game engine
C_ChatInfo.RegisterAddonMessagePrefix("HealSmartComm")

local function HealSmart_SlashCommandHandler(msg)
    -- Secure tokenize parser splitting arguments by blank spaces cleanly
    local cmd, arg = string.match(msg or "", "^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")
    
    if cmd == "" or cmd == "open" then
        if HealSmart_ShowMainWindow then
            HealSmart_ShowMainWindow()
        else
            HealSmart_Print("Error - UI engine not fully loaded yet.")
        end
        
    elseif cmd == "resetui" then
        if HealSmartContainer and HealSmartSettings then
            HealSmartSettings.point = "CENTER"
            HealSmartSettings.relativePoint = "CENTER"
            HealSmartSettings.xOfs = 0
            HealSmartSettings.yOfs = 0
            HealSmartSettings.width = 200
            HealSmartSettings.height = 110
            HealSmartSettings.locked = false
            
            HealSmartContainer:SetSize(HealSmartSettings.width, HealSmartSettings.height)
            HealSmartContainer:ClearAllPoints()
            HealSmartContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            
            if HealSmartScrollFrameScrollBar then
                HealSmartScrollFrameScrollBar:SetValue(0)
            end
            
            if HealSmart_UpdateLockVisuals then
                HealSmart_UpdateLockVisuals(false)
            end
            
            HealSmart_Print("Window layout position successfully reset to center screen and UNLOCKED.")
        end
        
    -- Direct configuration shortcut command utilizing the dynamic numeric ID bridge
    elseif cmd == "config" or cmd == "options" then
        if Settings and Settings.OpenToCategory and HealSmart_ConfigCategoryID then
            -- Modern Era API pathing utilizing the verified internal number ID
            Settings.OpenToCategory(HealSmart_ConfigCategoryID)
        else
            -- Legacy engine fallback pathing
            InterfaceOptionsFrame_OpenToCategory("HealSmart")
        end
        
    elseif cmd == "version" then
        HealSmart_Print("Querying group members for installed addon versions...")
        local targetChannel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or "INSTANCE_CHAT")
        if IsInGroup() or IsInRaid() then
            C_ChatInfo.SendAddonMessage("HealSmartComm", "QUERY_VERSION:0", targetChannel)
        else
            HealSmart_Print(UnitName("player") .. " is running version 0.6.0")
        end
        
    elseif cmd == "help" then
        print("|cff00bcff--- HealSmart Slash Commands Help ---|r")
        print("|cff00ff00/hs|r or |cff00ff00/hs open|r - Opens and shows the main meter window.")
        print("|cff00ff00/hs config|r - Opens the Blizzard Addon Options configuration panel directly.")
        print("|cff00ff00/hs resetui|r - Resets the window position back to the center of your screen.")
        print("|cff00ff00/hs version|r - Queries all group/raid members to check their addon versions.")
        print("|cff00ff00/hs help|r - Displays this command help overview layout screen.")
        print("|cff00bcff--------------------------------------|r")
        
    else
        HealSmart_Print("Unknown command. Type |cff00ff00/hs help|r to see all available features.")
    end
end

SLASH_HEALSMART1 = "/healsmart"
SlashCmdList["HEALSMART"] = HealSmart_SlashCommandHandler

SLASH_HS1 = "/hs"
SlashCmdList["HS"] = HealSmart_SlashCommandHandler

-- end healsmartcmd.lua
