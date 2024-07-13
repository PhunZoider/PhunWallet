if not isServer() then
    return
end
local sandbox = SandboxVars.PhunWallet
local PhunWallet = PhunWallet
local modList

local function buildCurrencyLookup(data)
    local result = {}
    local removeItemsOnFillCheck = false
    for _, v in ipairs(data) do
        local formatted = {
            key = v.key or v.type,
            type = v.type,
            zedSpawnChance = v.zedSpawnChance or 0,
            zedSprinterSpawnChance = v.zedSprinterSpawnChance or 0,
            removeFromContainers = v.removeFromContainers, -- prevent spawning in any containers
            removeFromZeds = v.removeFromZeds -- remove from any zeds
        }
        if v.boa then
            formatted.boa = true
        end
        result[formatted.key] = formatted
    end
    return result
end

function PhunWallet:reload()

    local data = PhunTools:loadTable("PhunWallet_Currencies.lua")
    local currencies = buildCurrencyLookup(data)
    if currencies then
        self.currencies = currencies
        ModData.add("PhunWallet_Currencies", currencies)
        ModData.transmit("PhunWallet_Currencies")
    end

end

function PhunWallet:export()
    if PhunTools then
        PhunTools:saveTable("PhunWallet_Currencies.lua", self.currencies)
    end
end

function PhunWallet:adjustWallet(playerObj, values, doNotAddBound)

    for k, v in pairs(values) do

        if PhunWallet.currencies[k] then
            local currency = PhunWallet.currencies[k]
            local data = PhunWallet:getPlayerData(playerObj)
            if not data.wallet then
                data.wallet = {}
            end
            local wallet = data.wallet or {}
            if not wallet.current then
                wallet.current = {}
            end
            if not wallet.bound then
                wallet.bound = {}
            end

            local target = wallet.current

            PhunTools:addLogEntry("PhunWallet:adjustWallet", playerObj:getUsername(), k, v)

            if target[k] then
                target[k] = target[k] + v
            else
                target[k] = v
            end

            if v > 0 and currency.boa and not doNotAddBound then
                -- only add bound currency if doNotAddBound is not set
                -- when respawning character, pass doNotAddBound = true
                -- this will allow player to spend currency they had before death
                -- while preserving bound currency
                if wallet.bound[k] then
                    wallet.bound[k] = wallet.bound[k] + v
                else
                    wallet.bound[k] = v
                end
            end
            self.playersModified = getTimestamp()
        end
    end

    sendServerCommand(playerObj, PhunWallet.name, PhunWallet.commands.getWallet, {
        playerIndex = playerObj:getPlayerNum(),
        wallet = PhunWallet:getPlayerData(playerObj:getUsername()).wallet or {},
        currencies = self.currencies
    })
end

function PhunWallet:adjustPlayerWallet(playerName, walletType, currency, value, note)
    if self.currencies[currency] then
        local data = PhunWallet:getPlayerData(playerName)
        local target = data.wallet[walletType or "current"]
        if not target then
            print("PhunWallet:adjustPlayerWallet() - walletType " .. tostring(walletType) .. " not found")
            return false
        end

        value = tonumber(value) or 0
        if (target[currency] + value) < 0 then
            return false
        end
        PhunTools:addLogEntry(tostring(note or "PhunWallet:adjustPlayerWallet"), playerName, currency, value)
        if target[currency] then
            target[currency] = target[currency] + value
        else
            target[currency] = value
        end

        self.playersModified = getTimestamp()

        for i = 1, getOnlinePlayers():size() do
            local p = getOnlinePlayers():get(i - 1)
            if p:getUsername() == playerName then
                sendServerCommand(p, PhunWallet.name, PhunWallet.commands.getWallet, {
                    playerIndex = p:getPlayerNum(),
                    wallet = PhunWallet:getPlayerData(p:getUsername()).wallet or {},
                    currencies = self.currencies
                })
            end
        end

    else
        print("PhunWallet:adjustPlayerWallet() - currency " .. tostring(currency) .. " not found")
        return false
    end
end

function PhunWallet:savePlayers()
    if self.playersModified > self.playersSaved then
        print("PhunWallet:savePlayers() - saving players")
        PhunTools:saveTable(self.name .. "_Players.lua", {
            data = self.players
        })
        self.playersSaved = getTimestamp()
    end
end

local Commands = {}

Commands[PhunWallet.commands.getPlayerList] = function(playerObj, args)

    local players = {}
    for k, v in pairs(PhunWallet.players) do
        table.insert(players, k)
    end

    table.sort(players, function(a, b)
        return a < b
    end)
    local data = {
        playerIndex = playerObj:getPlayerNum(),
        players = players
    }
    sendServerCommand(playerObj, PhunWallet.name, PhunWallet.commands.getPlayerList, data)
end

Commands[PhunWallet.commands.getPlayersWallet] = function(playerObj, args)

    local data = {
        playerIndex = playerObj:getPlayerNum(),
        wallet = (PhunWallet.players[args.player] or {}).wallet or {
            current = {},
            bound = {}
        }
    }
    sendServerCommand(playerObj, PhunWallet.name, PhunWallet.commands.getPlayersWallet, data)
end

Commands[PhunWallet.commands.getWallet] = function(playerObj, args)
    local wallet = PhunWallet:getPlayerData(playerObj:getUsername()).wallet or {}
    local data = {
        playerIndex = playerObj:getPlayerNum(),
        wallet = wallet,
        currencies = PhunWallet.currencies
    }
    sendServerCommand(playerObj, PhunWallet.name, PhunWallet.commands.getWallet, data)
end

Commands[PhunWallet.commands.getCurrencies] = function(playerObj, args)
    -- sendServerCommand(playerObj, PhunWallet.name, PhunWallet.commands.getCurrencies, PhunWallet.currencies)
end

Commands[PhunWallet.commands.logPlayerDroppedWallet] = function(playerObj, args)
    PhunTools:addLogEntry(args.note or "Dropped Wallet", playerObj:getUsername(), args.currency, args.value)
end

Commands[PhunWallet.commands.addToWallet] = function(playerObj, args)
    if playerObj == nil then
        return
    end
    local data = PhunWallet:getPlayerData(playerObj)
    PhunWallet:adjustWallet(playerObj, {
        [args.type or args.item] = args.qty or args.value
    })
    args.wallet = PhunWallet:getPlayerData(playerObj:getUsername()).wallet or {}
    sendServerCommand(playerObj, PhunWallet.name, PhunWallet.commands.addToWallet, args)
end

Commands[PhunWallet.commands.adjustPlayerWallet] = function(playerObj, args)
    if not args.player then
        return
    end
    local data = PhunWallet:getPlayerData(args.player)
    if not data then
        return
    end

    PhunWallet:adjustPlayerWallet(args.player, args.walletType, args.currencyType, args.value, args.note)

    local data = {
        playerIndex = playerObj:getPlayerNum(),
        wallet = (PhunWallet.players[args.player] or {}).wallet or {
            current = {},
            bound = {}
        }
    }
    sendServerCommand(playerObj, PhunWallet.name, PhunWallet.commands.getPlayersWallet, data)
end

Events.OnClientCommand.Add(function(module, command, playerObj, arguments)
    if module == PhunWallet.name and Commands[command] then
        Commands[command](playerObj, arguments)
    end
end)

Events.OnCharacterDeath.Add(function(playerObj)
    if instanceof(playerObj, "IsoPlayer") then
        local wallet = PhunWallet:getPlayerData(playerObj).wallet
        wallet.current = {}

        for k, v in pairs(wallet.bound) do
            wallet.current[k] = v
        end
    end
end)

local function onContainerFill(roomtype, containertype, container)
    if container:isExplored() or container:isHasBeenLooted() then
        -- container already explored
        return;
    end

    for k, v in pairs(PhunWallet.currencies) do
        if container:containsType(v.type) then
            local item = getScriptManager():getItem(v.type)
            container:Remove(v.type)
        end
    end

end

Events.OnFillContainer.Add(onContainerFill)
Events.OnInitGlobalModData.Add(function()
    PhunWallet:ini()
end)

Events.EveryTenMinutes.Add(function()
    PhunWallet:savePlayers()
end)

-- Add a hook to save player data when the server goes empty
PhunTools:RunOnceWhenServerEmpties(PhunWallet.name, function()
    PhunWallet:savePlayers()
end)
