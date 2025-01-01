if isServer() then
    return
end

local PW = PhunWallet
local Commands = {}

-- Commands[PW.commands.getCurrencies] = function(arguments)
--     PW.currencies = arguments
--     for k, v in pairs(PW.currencies) do
--         local item = getScriptManager():getItem(v.type)
--         v.displayText = item:getDisplayName()
--         v.texture = item:getNormalTexture()
--     end
--     triggerEvent(PW.events.OnPhunWalletCurrenciesUpdated, PW.currencies)
-- end

Commands[PW.commands.addToWallet] = function(arguments)
    local player = getSpecificPlayer(arguments.playerIndex)
    PW.queue:complete(arguments)
end

Commands[PW.commands.getWallet] = function(arguments)
    PW:getPlayerData(arguments.playerName).wallet = arguments.wallet
    triggerEvent(PW.events.OnPhunWalletChanged, arguments.playerName)
end

return Commands
