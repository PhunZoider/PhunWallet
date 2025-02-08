if isClient() then
    return
end
require "PhunLib/core"
local PL = PhunLib
local fileTools = PL.file
local tableTools = PL.table

local PW = PhunWallet
local Commands = {}

Commands[PW.commands.getPlayerList] = function(playerObj, args)

    local players = {}
    for k, v in pairs(PW.players) do
        table.insert(players, k)
    end

    table.sort(players, function(a, b)
        return a < b
    end)
    local data = {
        playerIndex = playerObj:getPlayerNum(),
        players = players
    }
    sendServerCommand(playerObj, PW.name, PW.commands.getPlayerList, data)
end

Commands[PW.commands.getPlayersWallet] = function(playerObj, args)
    local data = {
        playerIndex = playerObj:getPlayerNum(),
        wallet = PW:getPlayerData(args.playername).wallet or {}
    }
    sendServerCommand(playerObj, PW.name, PW.commands.getPlayersWallet, data)
end

Commands[PW.commands.getWallet] = function(playerObj, args)
    local wallet = PW:getPlayerData(playerObj:getUsername()).wallet or {}
    local data = {
        playerIndex = playerObj:getPlayerNum(),
        playerName = playerObj:getUsername(),
        wallet = wallet
    }
    sendServerCommand(playerObj, PW.name, PW.commands.getWallet, data)
end

Commands[PW.commands.getCurrencies] = function(playerObj, args)
    -- sendServerCommand(playerObj, PhunWallet.name, PhunWallet.commands.getCurrencies, PhunWallet.currencies)
end

Commands[PW.commands.logPlayerDroppedWallet] = function(playerObj, args)
    fileTools.log(args.note or "Dropped Wallet", playerObj:getUsername(), args.currency, args.value)
end

Commands[PW.commands.addToWallet] = function(playerObj, args)
    if playerObj == nil then
        return
    end
    local data = PW:getPlayerData(playerObj)
    PW:adjustWallet(playerObj, {
        [args.type or args.item] = args.qty or args.value
    })
    args.wallet = PW:getPlayerData(playerObj:getUsername()).wallet or {}
    sendServerCommand(playerObj, PW.name, PW.commands.addToWallet, args)
end

Commands[PW.commands.adjustPlayerWallet] = function(playerObj, args)
    if not args.player then
        return
    end
    local data = PW:getPlayerData(args.player)
    if not data then
        return
    end

    PW:adjustPlayerWallet(args.player, args.walletType, args.currencyType, args.value, args.note)

    local data = {
        playerIndex = playerObj:getPlayerNum(),
        wallet = data.wallet
    }
    sendServerCommand(playerObj, PW.name, PW.commands.getPlayersWallet, data)
end

return Commands
