PhunWallet = {
    inied = false,
    name = "PhunWallet",
    commands = {
        getWallet = "getWallet",
        getCurrencies = "getCurrencies",
        addToWallet = "addToWallet",
        getPlayerList = "getPlayerList",
        getPlayersWallet = "getPlayersWallet",
        adjustPlayerWallet = "adjustPlayerWallet",
        logPlayerDroppedWallet = "logPlayerDroppedWallet"
    },
    const = {
        currenciesFile = "PhunWallet_Currencies.lua",
        playersFile = "PhunWallet_Players.lua",
        currencies = "PhunWallet_Currencies",
        players = "PhunWallet_Players"
    },
    ticks = 100,
    playersModified = 0,
    playersSaved = 0,
    players = {},
    currencies = {
        ["PhunMart.SilverDollar"] = {
            type = "PhunMart.SilverDollar",
            zedSpawnChance = 1,
            zedSprinterSpawnChance = 5,
            spawnMin = 1,
            spawnMax = 2,
            removeFromContainers = true,
            removeFromZeds = false
        },
        ["PhunMart.CheeseToken"] = {
            type = "PhunMart.CheeseToken",
            boa = false,
            zedSpawnChance = 0,
            zedSprinterSpawnChance = 3,
            spawnMin = 1,
            spawnMax = 2,
            removeFromContainers = true,
            removeFromZeds = false
        },
        ["PhunMart.TraiterToken"] = {
            type = "PhunMart.TraiterToken",
            boa = true,
            zedSpawnChance = 0,
            zedSprinterSpawnChance = 1,
            spawnMin = 1,
            spawnMax = 2,
            removeFromContainers = true,
            removeFromZeds = false
        }
    },
    zoneInfo = {},
    ui = {},
    events = {
        OnPhunWalletChanged = "OnPhunWalletChanged",
        OnPhunWalletInied = "OnPhunWalletInied"
    },
    settings = {
        debug = true
    },
    bounds = {},
    zones = {}
}

local Core = PhunWallet
Core.settings = SandboxVars[Core.name] or {}

for _, event in pairs(Core.events) do
    if not Events[event] then
        LuaEventManager.AddEvent(event)
    end
end

function Core:debug(...)

    local args = {...}
    for i, v in ipairs(args) do
        if type(v) == "table" then
            self:printTable(v)
        else
            print(tostring(v))
        end
    end

end

function Core:printTable(t, indent)
    indent = indent or ""
    for key, value in pairs(t or {}) do
        if type(value) == "table" then
            print(indent .. key .. ":")
            Core:printTable(value, indent .. "  ")
        elseif type(value) ~= "function" then
            print(indent .. key .. ": " .. tostring(value))
        end
    end
end

function Core:getPlayerData(playerObj)
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

function Core:processCurrencyLabelHook(key)
    if self.currencies[key] then
        local item = getScriptManager():getItem(key)
        return item:getDisplayName(), "PhunWallet"
    end
end

function Core:processPrePurchaseHook(playerObj, sourceType, key, value)
    -- mutate value, but don't actually change the wallet value
    -- this is used to ensure the player has enough currency to make a purchase
    if sourceType ~= "PhunWallet" then
        return
    end

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

function Core:processPurchaseHook(playerObj, sourceType, key, value)
    if sourceType ~= "PhunWallet" then
        return
    end
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

function Core:satisfyPriceHook(playerObj, item, satisfied, allocation)
    if satisfied and playerObj and playerObj then

        local wallet = self:getPlayerData(playerObj).wallet or {}
        local current = wallet.current or {}

        for k, v in pairs(satisfied) do
            if v.value > 0 then
                for _, cur in ipairs(v.currencies) do
                    if current[cur.key] then
                        if current[cur.key] > v.value then
                            table.insert(allocation, {
                                currency = cur.key,
                                type = "PhunWallet",
                                value = v.value
                            })
                            v.value = 0
                        else
                            table.insert(allocation, {
                                currency = cur.key,
                                type = "PhunWallet",
                                value = v.value - current[cur.key]
                            })
                            v.value = v.value - current[cur.key]
                        end
                    end
                end
            end
        end
    end
end

function Core:ini()
    if not self.inied then
        self.inied = true

        self.players = ModData.getOrCreate(Core.const.players)

        if PhunMart then
            -- add some hooks
            PhunMart:addHook("currencyLabel", function(key)
                return self:processCurrencyLabelHook(key)
            end)

            PhunMart:addHook("preSatisfyPrice", function(playerObj, item, satisfied, allocation)
                self:satisfyPriceHook(playerObj, item, satisfied, allocation)
            end)

            PhunMart:addHook("prePurchase", function(playerObj, type, key, value)
                self:processPrePurchaseHook(playerObj, key, value)
            end)

            PhunMart:addHook("purchase", function(playerObj, type, key, value)
                self:processPurchaseHook(playerObj, type, key, value)
            end)
        end
        triggerEvent(self.events.OnPhunWalletInied, self)

    end

end
