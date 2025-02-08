if isServer() then
    return
end
local PW = PhunWallet
local Commands = require("PhunWallet/client_commands")

Events.OnZombieDead.Add(function(zombie)
    for k, v in pairs(PW.currencies) do
        if v.removeFromZeds and zombie:getInventory():containsType(v.type) then
            zombie:getInventory():Remove(v.type)
        end
    end
end);

Events.OnServerCommand.Add(function(module, command, arguments)
    if module == PW.name and Commands[command] then
        Commands[command](arguments)
    end
end)

Events.OnPreFillWorldObjectContextMenu.Add(function(playerObj, context, worldobjects)
    PW:showContext(playerObj, context, worldobjects)
end);

Events.OnCreatePlayer.Add(function(index, playerObj)
    PW:ini()
    sendClientCommand(playerObj, PW.name, PW.commands.getWallet, {})
end)

Events.OnCharacterDeath.Add(function(playerObj)
    if instanceof(playerObj, "IsoPlayer") and playerObj:isLocalPlayer() then
        local wallet = PW:getPlayerData(playerObj).wallet
        local toAdd = {}
        local current = wallet.current or {}
        local bound = wallet.bound or {}

        if PW.settings.DropWallet then
            local doAdd = false
            for k, v in pairs(wallet.current) do
                local currency = PW.currencies[k]
                -- skip bound entries
                if not currency.boa then
                    local rate = 100
                    if currency.returnRate then
                        rate = currency.returnRate
                    elseif PW.settings.DefaultReturnRate then
                        rate = PW.settings.DefaultReturnRate
                    end
                    toAdd[k] = math.floor(v * (rate / 100))
                    if toAdd[k] > 0 then
                        doAdd = true
                    end
                    -- log the full reduction on server
                    sendClientCommand(playerObj, PW.name, PW.commands.logPlayerDroppedWallet, {
                        currency = k,
                        value = -v,
                        note = "Death"
                    })
                end
            end

            if doAdd then
                local item = playerObj:getInventory():AddItem("PhunWallet.DroppedWallet")
                item:setName(getText("IGUI_PhunWallet.CharsWallet", playerObj:getUsername()))
                item:getModData().PhunWallet = {
                    owner = playerObj:getUsername(),
                    wallet = {
                        current = toAdd
                    }
                }
                -- log these as death reductions!
            end
        end

    end
end)

Events.OnPlayerUpdate.Add(function(playerObj)
    PW.queue:process()
end)

Events.OnReceiveGlobalModData.Add(function(tableName, tableData)
    if tableName == PW.const.currencies then
        PW.currencies = tableData
        for k, v in pairs(PW.currencies) do
            local item = getScriptManager():getItem(v.type)
            if item then
                v.displayText = item:getDisplayName()
                v.texture = item:getNormalTexture()
            end
        end
    end
end)

