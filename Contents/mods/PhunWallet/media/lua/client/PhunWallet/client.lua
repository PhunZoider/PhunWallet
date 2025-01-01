if isServer() then
    return
end

local PW = PhunWallet

PW.queue = require("PhunWallet/queue")

local function setup()
    Events.OnTick.Remove(setup)
    PW:ini()
    sendClientCommand(PW.name, PW.commands.getWallet, {})
end
Events.OnTick.Add(setup)

