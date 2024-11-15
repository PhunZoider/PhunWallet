if isServer() then
    return
end
require "TimedActions/ISInventoryTransferAction"
local PhunWallet = PhunWallet
local sandbox = SandboxVars.PhunWallet
local Commands = {}

local queue = {
    isPaused = false,
    counter = 0,
    items = {}
}

function queue:add(playerObj, itemtype, qty, fromWallet)
    local quantity = qty or 1
    local name = playerObj:getUsername()
    if not self.items[name] then
        self.items[name] = {}
    end
    for _, v in ipairs(self.items[name]) do
        if v.item == itemtype and not v.processing then
            v.qty = v.qty + quantity
            return
        end
    end
    self.counter = self.counter + 1
    table.insert(self.items[name], {
        id = self.counter,
        playerIndex = playerObj:getPlayerNum(),
        item = itemtype,
        qty = quantity,
        fromWallet = fromWallet
    })
end

function queue:process()
    for k, v in pairs(self.items) do
        if #v > 0 then
            for _, item in ipairs(v) do
                if not item.processing then
                    item.processing = true
                    sendClientCommand(getSpecificPlayer(item.playerIndex), PhunWallet.name,
                        PhunWallet.commands.addToWallet, item)
                    break
                end
            end
        end
    end
end

function queue:complete(args)
    local playerObj = getSpecificPlayer(args.playerIndex)
    local name = playerObj:getUsername()
    local index = 1
    local fromWallet = false
    for _, v in ipairs(self.items[name]) do
        if v.id == args.id then
            fromWallet = v.fromWallet
            table.remove(self.items[name], index)
            break
        end
        index = index + 1
    end
    if not fromWallet then
        for i = 1, args.qty do
            local invItem = playerObj:getInventory():getItemFromTypeRecurse(args.item)
            if invItem then
                invItem:getContainer():DoRemoveItem(invItem)
            end
        end
    else
        local invItem = playerObj:getInventory():getItemFromTypeRecurse("PhunWallet.DroppedWallet")
        invItem:getContainer():DoRemoveItem(invItem)
        getSoundManager():PlaySound("PhunWallet_Pickup", false, 0):setVolume(0.50);
    end

    if #self.items[name] == 0 then
        sendClientCommand(playerObj, PhunWallet.name, PhunWallet.commands.getWallet, {})
    end
    self:process()
end

PhunWallet.queue = queue

local cachedBindInventoryItems = nil
-- Hook the original New Inventory Transfer Method
local originalNewInventoryTransaferAction = ISInventoryTransferAction.new
function ISInventoryTransferAction:new(player, item, srcContainer, destContainer, time)

    local itemType = item:getFullType()
    local phun = PhunWallet
    local wallet = nil

    if instanceof(srcContainer:getParent(), "IsoDeadBody") then
        if itemType == "PhunWallet.DroppedWallet" then
            wallet = item:getModData().PhunWallet
            if wallet then
                if wallet.wallet and
                    (not sandbox.PhunWallet_OnlyPickupOwnWallet or player:getUsername() == wallet.owner) then
                elseif wallet.wallet and sandbox.PhunWallet_OnlyPickupOwnWallet and player:getUsername() ~= wallet.owner then
                    return {
                        ignoreAction = true
                    }
                end
            end
        end
    end

    local action = originalNewInventoryTransaferAction(self, player, item, srcContainer, destContainer, time)

    if wallet and wallet.wallet then
        action:setOnComplete(function()
            for k, v in pairs(wallet.wallet.current or {}) do
                queue:add(player, k, v, true)
                queue:process()
            end
        end)
    elseif phun.currencies[itemType] then
        action:setOnComplete(function()

            if not cachedBindInventoryItems then
                cachedBindInventoryItems = {}
                for _, v in pairs(PhunWallet.currencies) do
                    cachedBindInventoryItems[v.type] = v
                end
            end

            local srcType = srcContainer:getType()
            local destType = destContainer:getType()

            if destType ~= "floor" and cachedBindInventoryItems[itemType] then
                queue:add(player, itemType)
            end
        end)
    end

    return action
end

local function CheckZedSpecialDrops(zombie)

    for k, v in pairs(PhunWallet.currencies) do
        if v.removeFromZeds and zombie:getInventory():containsType(v.type) then
            zombie:getInventory():Remove(v.type)
        end
    end
end

Events.OnZombieDead.Add(CheckZedSpecialDrops);

Events.OnServerCommand.Add(function(module, command, arguments)
    if module == PhunWallet.name and Commands[command] then
        Commands[command](arguments)
    end
end)

Commands[PhunWallet.commands.getCurrencies] = function(arguments)
    PhunWallet.currencies = arguments
    for k, v in pairs(PhunWallet.currencies) do
        local item = getScriptManager():getItem(v.type)
        v.displayText = item:getDisplayName()
        v.texture = item:getNormalTexture()
    end
    triggerEvent(PhunWallet.events.OnPhunWalletCurrenciesUpdated, PhunWallet.currencies)
end

Commands[PhunWallet.commands.addToWallet] = function(arguments)
    local player = getSpecificPlayer(arguments.playerIndex)
    queue:complete(arguments)
end

Commands[PhunWallet.commands.getWallet] = function(arguments)
    local player = getSpecificPlayer(arguments.playerIndex)
    if not PhunWallet.players[player:getUsername()] then
        PhunWallet.players[player:getUsername()] = {}
    end
    PhunWallet.currencies = arguments.currencies
    PhunWallet.players[player:getUsername()].wallet = arguments.wallet
    triggerEvent(PhunWallet.events.OnPhunWalletChanged, arguments.wallet)
end

Events.OnCharacterDeath.Add(function(playerObj)

    if instanceof(playerObj, "IsoPlayer") and playerObj:isLocalPlayer() then
        local wallet = PhunWallet:getPlayerData(playerObj).wallet

        local toAdd = {}
        local current = wallet.current or {}
        local bound = wallet.bound or {}

        if sandbox.PhunWallet_DropWallet then
            local doAdd = false
            for k, v in pairs(wallet.current) do
                local currency = PhunWallet.currencies[k]
                -- skip bound entries
                if not currency.boa then
                    local rate = 100
                    if currency.returnRate then
                        rate = currency.returnRate
                    elseif sandbox.PhunWallet_DefaultReturnRate then
                        rate = sandbox.PhunWallet_DefaultReturnRate
                    end
                    toAdd[k] = math.floor(v * (rate / 100))
                    if toAdd[k] > 0 then
                        doAdd = true
                    end
                    -- log the full reduction on server
                    sendClientCommand(playerObj, PhunWallet.name, PhunWallet.commands.logPlayerDroppedWallet, {
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

Events[PhunWallet.events.OnPhunWalletChanged].Add(function(data)
    if PhunWalletContents.instance then
        PhunWalletContents.instance:rebuild()
    end
end)

Events[PhunWallet.events.OnPhunWalletCurrenciesUpdated].Add(function(data)
    if PhunWalletContents.instance then
        PhunWalletContents.instance:rebuild()
    end
end)

Events.OnPlayerUpdate.Add(function(playerObj)
    queue:process()
end)

Events.OnReceiveGlobalModData.Add(function(tableName, tableData)
    if tableName == "PhunWallet_Currencies" then
        PhunWallet.currencies = tableData
        for k, v in pairs(PhunWallet.currencies) do
            local item = getScriptManager():getItem(v.type)
            if item then
                v.displayText = item:getDisplayName()
                v.texture = item:getNormalTexture()
            end
        end
    end
end)

Events.onLoadModDataFromServer.Add(function(modData)
    if modData.modDataName == "PhunWallet_Currencies" then
        PhunWallet.currencies = modData.modData
    end
end)

local function setup()
    Events.EveryOneMinute.Remove(setup)
    PhunWallet:ini()
    sendClientCommand(getSpecificPlayer(0), PhunWallet.name, PhunWallet.commands.getWallet, {})
end
Events.EveryOneMinute.Add(setup)
Events.OnCreatePlayer.Add(function(index, playerObj)
    PhunWallet:ini()
    sendClientCommand(playerObj, PhunWallet.name, PhunWallet.commands.getWallet, {})
end)

if PhunZones then
    Events[PhunZones.events.OnPhunZonesPlayerLocationChanged].Add(
        function(playerObj, location, oldLocation)
            PhunWallet.zoneInfo[playerObj:getUsername()] = location
        end)
end
