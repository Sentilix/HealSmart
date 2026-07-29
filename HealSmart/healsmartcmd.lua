-- ==========================================
-- HealSmart - Slash Command Engine (v0.5.0)
-- ==========================================

local function HealSmart_SlashCommandHandler(msg)
    local command = string.lower(msg or "")
    
    if command == "" or command == "open" then
        -- Execute the global UI visibility trigger safely
        if HealSmart_ShowMainWindow then
            HealSmart_ShowMainWindow()
            print("|cff00bcffHealSmart:|r Window opened successfully.")
        else
            print("|cff00bcffHealSmart:|r Error - UI engine not fully loaded yet.")
        end
    else
        print("|cff00bcffHealSmart:|r Unknown command. Use '/hs' or '/hs open' to show the meter.")
    end
end

SLASH_HEALSMART1 = "/healsmart"
SlashCmdList["HEALSMART"] = HealSmart_SlashCommandHandler

SLASH_HS1 = "/hs"
SlashCmdList["HS"] = HealSmart_SlashCommandHandler

-- end healsmartcmd.lua