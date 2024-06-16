if isServer() then
    return
end
require 'ISInventoryTransferAction'
local PhunWallet = PhunWallet

local Commands = {}

local queue = {
    isPaused = false,
    counter = 0,
    items = {}
}

function queue:add(playerObj, itemtype, qty)
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
        qty = quantity
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
    for _, v in ipairs(self.items[name]) do
        if v.id == args.id then
            table.remove(self.items[name], index)
            break
        end
        index = index + 1
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

    if instanceof(srcContainer:getParent(), "IsoDeadBody") then
        if itemType == "PhunWallet.DroppedWallet" then
            local wallet = item:getModData().PhunWallet
            if wallet then
                if player:getUsername() == wallet.owner and wallet.wallet then
                    for k, v in pairs(wallet.wallet.current or {}) do
                        queue:add(player, k, v)
                        queue:process()
                    end
                    srcContainer:removeItemOnServer(item)
                    srcContainer:DoRemoveItem(item)
                    getSoundManager():PlaySound("PhunWallet_Pickup", false, 0):setVolume(0.50);
                    return {
                        ignoreAction = true
                    }
                end
            end
        end
    end

    if phun.currencies[itemType] then
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

            if srcType == "floor" and item:getWorldItem() then
                local worldItem = item:getWorldItem()
                if worldItem then
                    local square = worldItem:getSquare()
                    if square then
                        square:transmitRemoveItemFromSquare(worldItem)
                        square:getChunk():recalcHashCodeObjects();
                        square:getObjects():remove(worldItem);
                        item:setWorldItem(nil);
                    end
                end
            end
            if srcType ~= "floor" and srcType ~= "none" then
                srcContainer:removeItemOnServer(item)
            end
            srcContainer:DoRemoveItem(item)

            return {
                ignoreAction = true
            }
        end
    end

    -- otherwise, just do the transfer by passing parms back to original method
    return originalNewInventoryTransaferAction(self, player, item, srcContainer, destContainer, time)
end

local function CheckZedSpecialDrops(zombie)

    local wasSprinter = zombie:getModData().isSprinter == true or
                            (zombie:getModData().PhunRunners and zombie:getModData().PhunRunners.sprinting == true)
    print("Dead body found sprinter? " .. tostring(wasSprinter))
    for k, v in pairs(PhunWallet.currencies) do
        if v.removeFromZeds and zombie:getInventory():containsType(v.type) then
            print("Removing " .. v.type .. " from dead body")
            zombie:getInventory():Remove(v.type)
        elseif not wasSprinter and v.zedSpawnChance > 0 then
            print("Checking " .. v.type .. " " .. v.zedSpawnChance .. " spawn chance")
            if ZombRand(100) <= v.zedSpawnChance then
                print("Adding " .. v.type .. " to dead body")
                zombie:getInventory():AddItems(v.type, ZombRand(v.spawnMin or 1, v.spawnMax or 1))
            end
        elseif wasSprinter and v.zedSprinterSpawnChance > 0 then
            print("Checking " .. v.type .. " " .. v.zedSprinterSpawnChance .. " sprinter spawn chance")
            if ZombRand(100) <= v.zedSprinterSpawnChance then
                print("Adding " .. v.type .. " to dead body")
                zombie:getInventory():AddItems(v.type, ZombRand(v.spawnMin or 1, v.spawnMax or 1))
            end
        end
    end
    zombie:getModData().PhunRunners = nil
end

Events.OnZombieDead.Add(CheckZedSpecialDrops);

local function setup()
    Events.EveryOneMinute.Remove(setup)
    for i = 1, getOnlinePlayers():size() do
        local p = getOnlinePlayers():get(i - 1)
        sendClientCommand(p, PhunWallet.name, PhunWallet.commands.getWallet, {})
    end
end

Events.EveryOneMinute.Add(setup)

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
    print("RECEIVED WALLET DATA")
    PhunTools:printTable(arguments)
    local player = getSpecificPlayer(arguments.playerIndex)
    if not PhunWallet.players[player:getUsername()] then
        PhunWallet.players[player:getUsername()] = {}
    end
    PhunWallet.players[player:getUsername()].wallet = arguments.wallet
    triggerEvent(PhunWallet.events.OnPhunWalletChanged, arguments.wallet)
end

Events[PhunWallet.events.OnPhunWalletChanged].Add(function(data)
    print("OnPhunWalletChanged")
    if PhunWalletContents.instance then
        PhunWalletContents.instance:rebuild()
    end
    -- ISPhunWalletWalletTab.wallet = data
    -- if ISPhunWalletWalletTab.rebuild then
    --     ISPhunWalletWalletTab:rebuild()
    -- end
end)

Events[PhunWallet.events.OnPhunWalletCurrenciesUpdated].Add(function(data)
    print("OnPhunWalletCurrenciesUpdated")
    if PhunWalletContents.instance then
        PhunWalletContents.instance:rebuild()
    end
    -- ISPhunWalletWalletTab.currencies = data
    -- if ISPhunWalletWalletTab.rebuild then
    --     ISPhunWalletWalletTab:rebuild()
    -- end
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
    ModData.request("PhunWallet_Currencies")
end
Events.EveryOneMinute.Add(setup)

Events.EveryTenMinutes.Add(function()
    sendClientCommand(getSpecificPlayer(0), PhunWallet.name, PhunWallet.commands.getWallet, {})
end)
