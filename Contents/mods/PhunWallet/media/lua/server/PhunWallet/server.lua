if isClient() then
    return
end

require "PhunLib/core"
local PL = PhunLib
local fileTools = PL.file
local PW = PhunWallet
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

function PW:reload()

    -- local data = fileTools:loadTable(PW.const.currenciesFile)
    -- local currencies = buildCurrencyLookup(data)
    -- if currencies then
    --     PW.currencies = currencies
    --     ModData.add(PW.const.currencies, self.currencies)
    --     ModData.transmit(PW.const.currencies)
    -- end

end

function PW:export()
    -- fileTools:saveTable(self.const.currenciesFile, PW.currencies)
end

function PW:adjustWallet(playerObj, values, doNotAddBound)

    for k, v in pairs(values) do

        if self.currencies[k] then
            local currency = PW.currencies[k]
            local data = PW:getPlayerData(playerObj)
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

            fileTools.log("PhunWallet:adjustWallet", playerObj:getUsername(), k, v)

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
            PW.playersModified = getTimestamp()
        end
    end

    sendServerCommand(playerObj, PW.name, PW.commands.getWallet, {
        playerIndex = playerObj:getPlayerNum(),
        playerName = playerObj:getUsername(),
        wallet = PW:getPlayerData(playerObj:getUsername()).wallet or {}
    })
end

function PW:adjustPlayerWallet(playerName, walletType, currency, value, note)
    if PW.currencies[currency] then
        local data = PW:getPlayerData(playerName)
        local target = data.wallet[walletType or "current"]
        if not target then
            return false
        end

        value = tonumber(value) or 0
        if ((target[currency] or 0) + value) < 0 then
            return false
        end
        fileTools.log(tostring(note or "PhunWallet:adjustPlayerWallet"), playerName, currency, value)
        if target[currency] then
            target[currency] = target[currency] + value
        else
            target[currency] = value
        end

        PW.playersModified = getTimestamp()

        for i = 1, getOnlinePlayers():size() do
            local p = getOnlinePlayers():get(i - 1)
            if p:getUsername() == playerName then
                sendServerCommand(p, PW.name, PW.commands.getWallet, {
                    playerIndex = p:getPlayerNum(),
                    playerName = p:getUsername(),
                    wallet = PW:getPlayerData(p:getUsername()).wallet or {}
                })
            end
        end

    else
        return false
    end
end

function PW:savePlayers()
    if PW.playersModified > PW.playersSaved then
        fileTools.saveTable(PW.const.playersFile, PW.players)
        PW.playersSaved = getTimestamp()
    end
end
