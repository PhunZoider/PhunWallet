if isServer() then
    return
end

local PW = PhunWallet
local mainName = "PhunWallet"
local subName = "PhunWallet Admin"

function PW:showContext(playerObj, context, worldobjects)

    if isAdmin() or isDebugEnabled() then

        local mainMenu = nil
        local contextoptions = context:getMenuOptionNames()
        local mainMenu = contextoptions[mainName]

        if not mainMenu then
            -- there isn't one so create it
            mainMenu = context:addOption(mainName)
        end

        -- add the submenu
        local sub = context:getNew(context)
        context:addSubMenu(mainMenu, sub)
        sub:addOption(subName, worldobjects, function()
            local player = playerObj and getSpecificPlayer(playerObj) or getPlayer()
            PW.ui.admin.OnOpenPanel(player)
        end)

    end

end
