if isServer() then
    return
end
local PW = PhunWallet

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
        playerId = playerObj:getOnlineID(),
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
                    sendClientCommand(getSpecificPlayer(item.playerIndex), PW.name, PW.commands.addToWallet, item)
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
        sendClientCommand(playerObj, PW.name, PW.commands.getWallet, {})
    end
    self:process()
end

return queue
