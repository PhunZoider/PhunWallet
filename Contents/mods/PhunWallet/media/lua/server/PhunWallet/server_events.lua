if isClient() then
    return
end
local PW = PhunWallet
local Commands = require("PhunWallet/server_commands")
local emptyServerTickCount = 0
local emptyServerCalculate = false

Events.OnTickEvenPaused.Add(function()

    if emptyServerCalculate == true and emptyServerTickCount > 100 then
        if getOnlinePlayers():size() == 0 then
            emptyServerCalculate = false
            PW:savePlayers()
        end
    elseif emptyServerTickCount > 100 then
        emptyServerTickCount = 0
    else
        emptyServerTickCount = emptyServerTickCount + 1
    end
end)

Events.OnClientCommand.Add(function(module, command, playerObj, arguments)
    if module == PW.name and Commands[command] then
        Commands[command](playerObj, arguments)
    end
end)

Events.OnCharacterDeath.Add(function(playerObj)
    if instanceof(playerObj, "IsoPlayer") then
        local wallet = PW:getPlayerData(playerObj).wallet
        wallet.current = {}

        for k, v in pairs(wallet.bound) do
            wallet.current[k] = v
        end
    end
end)

Events.OnFillContainer.Add(function(roomtype, containertype, container)
    if container:isExplored() or container:isHasBeenLooted() then
        -- container already explored
        return;
    end

    for k, v in pairs(PW.currencies) do
        if container:containsType(v.type) then
            local item = getScriptManager():getItem(v.type)
            container:Remove(v.type)
        end
    end

end)

Events.OnInitGlobalModData.Add(function()
    PW:ini()
end)

Events.EveryTenMinutes.Add(function()
    PW:savePlayers()
end)
