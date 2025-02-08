if isServer() then
    return
end

require "ISUI/ISPanel"
require "PhunLib/core"
local PL = PhunLib
local tableTools = PL.table
local PW = PhunWallet
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local FONT_SCALE = FONT_HGT_SMALL / 14
local HEADER_HGT = FONT_HGT_MEDIUM + 2 * 2

local windowName = "PhunWalletAdminUI"

PW.ui.admin = ISPanel:derive(windowName);
PW.ui.admin.instances = {}
local UI = PW.ui.admin

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

local function refreshPlayers()
    sendClientCommand(PW.name, PW.commands.getPlayerList, {})
end

local function refreshPlayerWallet(playername)
    sendClientCommand(PW.name, PW.commands.getPlayersWallet, {
        playername = playername
    })
end

local function formatWholeNumber(number)
    number = number or 0
    -- Round the number to remove the decimal part
    local roundedNumber = math.floor(number + 0.5)
    -- Convert to string and format with commas
    local formattedNumber = tostring(roundedNumber):reverse():gsub("(%d%d%d)", "%1,")
    formattedNumber = formattedNumber:reverse():gsub("^,", "")
    return formattedNumber
end

function UI.OnOpenPanel(player)

    local playerIndex = player:getPlayerNum()
    local instance = UI.instances[playerIndex]
    if not instance then
        local core = getCore()
        local FONT_SCALE = getTextManager():getFontHeight(UIFont.Small) / 14
        local width = 350
        local height = 400

        local x = (core:getScreenWidth() - width) / 2
        local y = (core:getScreenHeight() - height) / 2

        instance = UI:new(x, y, width, height, player);
        instance:initialise();

        UI.instances[playerIndex] = instance
    end
    instance:addToUIManager();
    instance:setVisible(true);
    refreshPlayers()
    return instance;

end

function UI:setPlayers(players)
    self.box:clear()
    table.sort(players, function(a, b)
        return a < b
    end)
    for _, player in ipairs(players) do
        self.box:addOption(player)
    end
    refreshPlayerWallet(self.box:getSelectedText())
end

function UI:setWallet(wallet)
    self.datas:clear();
    local bound = {}
    for k, v in pairs(PW.currencies or {}) do
        local item = getScriptManager():getItem(v.type)
        if item then
            v.label = item:getDisplayName() or k
            v.texture = item:getNormalTexture()
            v.value = formatWholeNumber(wallet.current[k] or 0)
        end
        self.datas:addItem(k, v)
        if v.boa then
            bound[k] = tableTools.shallowCopy(v)
            bound[k].isBoa = true
        end
    end

    for k, v in pairs(bound) do
        v.value = formatWholeNumber(wallet.bound[k] or 0)
        self.datas:addItem("BOA:" .. k, v)
    end
end

function UI:promptForValue(playerName, walletType, currencyType, value)
    local modal = ISTextBox:new(0, 0, 280, 180, currencyType .. "(" .. walletType .. ") for " .. playerName,
        tostring(value), nil, function(target, button, obj)
            if button.internal == "OK" then
                sendClientCommand(PW.name, PW.commands.adjustPlayerWallet, {
                    player = playerName,
                    walletType = walletType,
                    currencyType = currencyType,
                    value = button.parent.entry:getText()
                })
            end

        end, self.playerIndex)
    modal:initialise()
    modal:addToUIManager()
end

function UI:GridDoubleClick(item)
    local player = self.box:getSelectedText()
    if player then
        local walletType = item.isBoa and "bound" or "current"
        self:promptForValue(player, walletType, item.type, -1)
    end
end

function UI:createChildren()
    ISPanel.createChildren(self);

    local x = 10
    local y = 10
    local h = FONT_HGT_MEDIUM;
    local w = self.width - 20;
    self.title = ISLabel:new(x, y, h, "Tools", 1, 1, 1, 1, UIFont.Medium, true);
    self.title:initialise();
    self.title:instantiate();
    self:addChild(self.title);

    self.closeButton = ISButton:new(self.width - 25 - x, y, 25, 25, "X", self, function()
        UI.OnOpenPanel(self.player):close()
    end);
    self.closeButton:initialise();
    self:addChild(self.closeButton);

    y = y + h + x + 20

    self.box = ISComboBox:new(x, y, 200, h, self, function()
        refreshPlayerWallet(self.box:getSelectedText())
    end);
    self.box:initialise()
    self:addChild(self.box)

    self.refreshPlayersButton = ISButton:new(x + 210, y, 100, h, "Refresh", self, function()
        refreshPlayerWallet(self.box:getSelectedText())
    end);
    self.refreshPlayersButton:initialise();
    self:addChild(self.refreshPlayersButton);

    y = y + h + x + 20

    self.datas = ISScrollingListBox:new(x, y, self.width - (x * 2), self.height - y - h);
    self.datas:initialise();
    self.datas:instantiate();
    self.datas.itemheight = FONT_HGT_MEDIUM + 4 * 2
    self.datas.selected = 0;
    self.datas.joypadParent = self;
    self.datas.font = UIFont.NewSmall;
    self.datas.doDrawItem = self.drawDatas;
    self.datas.drawBorder = true;
    self.datas:setOnMouseDoubleClick(self, self.GridDoubleClick)
    self.datas:addColumn("Currency", 0);
    self.datas:addColumn("Value", 200);
    self.datas:setVisible(false);
    self.datas.onMouseMove = self.doOnMouseMove
    self.datas.onMouseMoveOutside = self.doOnMouseMoveOutside
    self:addChild(self.datas);

    self.datas:clear();
    for k, v in pairs(PW.currencies or {}) do
        local item = getScriptManager():getItem(v.type)
        if item then
            v.label = item:getDisplayName()
            v.texture = item:getNormalTexture()
        end
        self.datas:addItem(k, v)
        self.datas:setVisible(true)
    end

    y = y + h + x

end

function UI:drawDatas(y, item, alt)

    if y + self:getYScroll() + self.itemheight < 0 or y + self:getYScroll() >= self.height then
        return y + self.itemheight
    end

    local a = 0.9;

    if self.selected == item.index then
        self:drawRect(0, (y), self:getWidth(), self.itemheight, 0.3, 0.7, 0.35, 0.15);
    end

    if alt then
        self:drawRect(0, (y), self:getWidth(), self.itemheight, 0.3, 0.6, 0.5, 0.5);
    end

    self:drawRectBorder(0, (y), self:getWidth(), self.itemheight, a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b);

    local iconX = 4
    local iconSize = FONT_HGT_SMALL;
    local xoffset = 10;

    local clipX = self.columns[1].size
    local clipX2 = self.columns[2].size
    local clipY = math.max(0, y + self:getYScroll())
    local clipY2 = math.min(self.height, y + self:getYScroll() + self.itemheight)

    self:setStencilRect(clipX, clipY, clipX2 - clipX, clipY2 - clipY)
    if item.item.texture then
        self:drawTextureScaledAspect2(item.item.texture, xoffset, y + 4, item.height - 4, item.height - 8, 1, 1, 1, 1)
        xoffset = xoffset + item.height + 4
    end
    local label = item.item.label or item.text or ""
    if item.item.isBoa then
        label = label .. " (bound)"
    end
    self:drawText(label, xoffset, y + 4, 1, 1, 1, a, self.font);
    self:clearStencilRect()

    local valueWidth = getTextManager():MeasureStringX(self.font, item.item.value)
    local w = self.width
    local cw = self.columns[2].size
    self:drawText(item.item.value, w - valueWidth - 10, y + 4, 1, 1, 1, a, self.font);

    self.itemsHeight = y + self.itemheight;
    return self.itemsHeight;
end

function UI:close()
    self:setVisible(false);
    self:removeFromUIManager();
    UI.instance = nil
end

function UI:new(x, y, width, height, player)
    local o = {};
    o = ISPanel:new(x, y, width, height, player);
    setmetatable(o, self);
    self.__index = self;
    o.player = player
    o.playerIndex = player:getPlayerNum()
    o.variableColor = {
        r = 0.9,
        g = 0.55,
        b = 0.1,
        a = 1
    };
    o.borderColor = {
        r = 0.4,
        g = 0.4,
        b = 0.4,
        a = 1
    };
    o.backgroundColor = {
        r = 0,
        g = 0,
        b = 0,
        a = 0.8
    };
    o.buttonBorderColor = {
        r = 0.7,
        g = 0.7,
        b = 0.7,
        a = 0.5
    };
    o.zOffsetSmallFont = 25;
    o.moveWithMouse = true;
    return o;
end

local Commands = {}

Commands[PW.commands.getPlayerList] = function(args)
    if UI.instances then
        for _, instance in pairs(UI.instances) do
            instance:setPlayers(args.players)
        end
    end
end

Commands[PW.commands.getPlayersWallet] = function(args)
    if UI.instances then
        for _, instance in pairs(UI.instances) do
            instance:setWallet(args.wallet)
        end
    end
end

-- Listen for commands from the server
Events.OnServerCommand.Add(function(module, command, arguments)
    if module == PW.name and Commands[command] then
        Commands[command](arguments)
    end
end)
