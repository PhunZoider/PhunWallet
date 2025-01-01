if isServer() then
    return
end

require "TimedActions/ISInventoryTransferAction"
local PW = PhunWallet
local cachedBindInventoryItems = nil
-- Hook the original New Inventory Transfer Method
local originalNewInventoryTransaferAction = ISInventoryTransferAction.new
function ISInventoryTransferAction:new(player, item, srcContainer, destContainer, time)

    local itemType = item:getFullType()
    local wallet = nil

    if srcContainer and instanceof(srcContainer:getParent(), "IsoDeadBody") then
        if itemType == "PhunWallet.DroppedWallet" then
            wallet = item:getModData().PhunWallet
            if wallet then
                if wallet.wallet and (not PW.settings.OnlyPickupOwnWallet or player:getUsername() == wallet.owner) then
                elseif wallet.wallet and PW.settings.OnlyPickupOwnWallet and player:getUsername() ~= wallet.owner then
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
                PW.queue:add(player, k, v, true)
                PW.queue:process()
            end
        end)
    elseif PW.currencies[itemType] then
        action:setOnComplete(function()

            if not cachedBindInventoryItems then
                cachedBindInventoryItems = {}
                for _, v in pairs(PW.currencies) do
                    cachedBindInventoryItems[v.type] = v
                end
            end

            local srcType = srcContainer:getType()
            local destType = destContainer:getType()

            if destType ~= "floor" and cachedBindInventoryItems[itemType] then
                PW.queue:add(player, itemType)
            end
        end)
    end

    return action
end
