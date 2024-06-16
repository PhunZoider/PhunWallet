if not isServer() then
    return
end
local PhunWallet = PhunWallet
local modList

local function loadData(filename)

    local res
    local data = {}
    local fileReaderObj = getFileReader(filename, true)
    local line = fileReaderObj:readLine()
    local startsWithReturn = nil
    while line do
        if startsWithReturn == nil then
            startsWithReturn = PhunTools:startsWith(line, "return")
        end
        data[#data + 1] = line
        line = fileReaderObj:readLine()
    end
    fileReaderObj:close()
    if startsWithReturn == true then
        res = loadstring(table.concat(data, "\n"))()
    else
        res = loadstring("return {" .. table.concat(data, "\n") .. "}")()
    end
    return res

end

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

    local data = loadData("PhunWallet_Currencies.lua")
    local currencies = buildCurrencyLookup(data)
    if currencies then
        self.currencies = currencies
        ModData.add("PhunWallet_Currencies", currencies)
        ModData.transmit("PhunWallet_Currencies")
        self:debug("Currency data loaded", self.currencies)
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
        end
    end

    sendServerCommand(playerObj, PhunWallet.name, PhunWallet.commands.getWallet, {
        playerIndex = playerObj:getPlayerNum(),
        wallet = PhunWallet:getPlayerData(playerObj:getUsername()).wallet or {}
    })
end

local Commands = {}

Commands[PhunWallet.commands.getWallet] = function(playerObj, args)
    print("PhunWallet.commands.getWallet requested")
    local wallet = PhunWallet:getPlayerData(playerObj:getUsername()).wallet or {}
    local data = {
        playerIndex = playerObj:getPlayerNum(),
        wallet = wallet
    }
    PhunTools:printTable(data)
    sendServerCommand(playerObj, PhunWallet.name, PhunWallet.commands.getWallet, data)
end

Commands[PhunWallet.commands.getCurrencies] = function(playerObj, args)
    -- sendServerCommand(playerObj, PhunWallet.name, PhunWallet.commands.getCurrencies, PhunWallet.currencies)
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

Events.OnClientCommand.Add(function(module, command, playerObj, arguments)
    if module == PhunWallet.name and Commands[command] then
        Commands[command](playerObj, arguments)
    end
end)

Events.OnCharacterDeath.Add(function(playerObj)
    if instanceof(playerObj, "IsoPlayer") then
        local wallet = PhunWallet:getPlayerData(playerObj).wallet
        local item = playerObj:getInventory():AddItem("PhunWallet.DroppedWallet")

        local toAdd = {}
        local current = wallet.current or {}
        local bound = wallet.bound or {}

        for k, v in pairs(bound) do
            local val = 0
            toAdd[k] = v
        end
        for k, v in pairs(current) do
            if not toAdd[k] then
                -- skip bound entries
                toAdd[k] = v
            end
        end

        PhunWallet:getPlayerData(playerObj).wallet = {
            current = {},
            bound = {}
        }
        item:getModData().PhunWallet = {
            owner = playerObj:getUsername(),
            wallet = wallet
        }
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
