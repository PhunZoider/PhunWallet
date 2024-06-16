PhunWallet = {
    inied = false,
    name = "PhunWallet",
    commands = {
        dataLoaded = "dataLoaded",
        reload = "reload",
        requestData = "requestData",
        getWallet = "getWallet",
        getCurrencies = "getCurrencies",
        addToWallet = "addToWallet"
    },
    ticks = 100,
    players = {},
    currencies = {},
    events = {
        OnPhunWalletChanged = "OnPhunWalletChanged",
        OnPhunWalletCurrenciesUpdated = "OnPhunWalletCurrenciesUpdated"
    },
    settings = {
        debug = true
    },
    bounds = {},
    zones = {}
}

for _, event in pairs(PhunWallet.events) do
    if not Events[event] then
        LuaEventManager.AddEvent(event)
    end
end

function PhunWallet:debug(...)
    if self.settings.debug then
        local args = {...}
        PhunTools:debug(args)
    end
end

function PhunWallet:getPlayerData(playerObj)
    local key = nil
    if type(playerObj) == "string" then
        key = playerObj
    else
        key = playerObj:getUsername()
    end
    if key and string.len(key) > 0 then
        if not self.players then
            self.players = {}
        end
        if not self.players[key] then
            self.players[key] = {}
        end
        if not self.players[key].wallet then
            self.players[key].wallet = {}
        end
        if not self.players[key].wallet.current then
            self.players[key].wallet.current = {}
        end
        if not self.players[key].wallet.bound then
            self.players[key].wallet.bound = {}
        end
        if not self.players[key].purchases then
            self.players[key].purchases = {}
        end
        return self.players[key]
    end
end

function PhunWallet:processCurrencyLabelHook(key)
    if self.currencies[key] then
        local item = getScriptManager():getItem(key)
        return item:getDisplayName(), "PhunWallet"
    end
end

function PhunWallet:processPrePurchaseHook(playerObj, key, value)
    -- mutate value, but don't actually change the wallet value
    -- this is used to ensure the player has enough currency to make a purchase
    if value and playerObj then
        local wallet = self:getPlayerData(playerObj).wallet or {}
        local current = wallet.current or {}
        if current[key] and current[key] > 0 then
            if current[key] < value then
                value = value - current[key]
            elseif current[key] >= value then
                value = 0
            end
        end
    end
end

function PhunWallet:processPurchaseHook(playerObj, key, value)
    -- mutate value AND change the wallet value
    if value and playerObj then
        local wallet = self:getPlayerData(playerObj).wallet or {}
        local current = wallet.current or {}
        if current[key] and current[key] > 0 then
            if current[key] < value then
                self.queue:add(playerObj, key, (current[key] * -1))
                value = value - current[key]
            elseif current[key] >= value then
                self.queue:add(playerObj, key, (value * -1))
                value = 0
            end
        end
    end
end

function PhunWallet:satisfyPriceHook(playerObj, item, satisfied)
    if satisfied and playerObj and playerObj then

        local wallet = self:getPlayerData(playerObj).wallet or {}
        local current = wallet.current or {}

        for k, v in pairs(satisfied) do
            if current[k] and v.value > 0 then
                if current[k] > v.value then
                    v.value = 0
                else
                    v.value = v.value - current[k]
                end
            end
        end
    end
end

function PhunWallet:ini()
    if not self.inied then
        self.inied = true
        if isServer() then
            self.currencies = ModData.getOrCreate("PhunWallet_Currencies")
            local playerData = ModData.getOrCreate("PhunWallet_PlayerData")
            self.players = playerData
            self:reload()
        end

        if PhunMart then
            print("PhunWallet: Adding hooks to PhunMart")
            -- add some hooks
            PhunMart:addHook("currencyLabel", function(key)
                return self:processCurrencyLabelHook(key)
            end)

            PhunMart:addHook("preSatisfyPrice", function(playerObj, item, satisfied)
                self:satisfyPriceHook(playerObj, item, satisfied)
            end)

            PhunMart:addHook("prePurchase", function(playerObj, key, value)
                self:processPrePurchaseHook(playerObj, key, value)
            end)

            PhunMart:addHook("purchase", function(playerObj, key, value)
                self:processPurchaseHook(playerObj, key, value)
            end)
        else
            print("PhunWallet: PhunMart not found, cannot add hooks")
        end

    end

end
