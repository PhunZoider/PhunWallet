if not isClient() then
    return
end

require "ISUI/ISPanel"
PhunWalletContents = ISPanel:derive("PhunWalletContents");
local PhunWallet = PhunWallet

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

local HEADER_HGT = FONT_HGT_MEDIUM + 2 * 2

function PhunWalletContents:initialise()
    ISPanel.initialise(self);
end

function PhunWalletContents:new(x, y, width, height, viewer)
    local o = ISPanel:new(x, y, width, height);
    setmetatable(o, self);
    o.listHeaderColor = {
        r = 0.4,
        g = 0.4,
        b = 0.4,
        a = 0.3
    };
    o.borderColor = {
        r = 0.4,
        g = 0.4,
        b = 0.4,
        a = 0
    };
    o.backgroundColor = {
        r = 0,
        g = 0,
        b = 0,
        a = 1
    };
    o.buttonBorderColor = {
        r = 0.7,
        g = 0.7,
        b = 0.7,
        a = 0.5
    };
    o.totalResult = 0;
    o.filterWidgets = {};
    o.filterWidgetMap = {}
    o.viewer = viewer
    o.playerObj = getSpecificPlayer(viewer)
    o.itemsHeight = 200
    PhunWalletContents.instance = o;
    return o;
end

function PhunWalletContents:createChildren()
    ISPanel.createChildren(self);

    self.datas = ISScrollingListBox:new(0, HEADER_HGT, self.width, self.height - HEADER_HGT);
    self.datas:initialise();
    self.datas:instantiate();
    self.datas.itemheight = FONT_HGT_MEDIUM + 4 * 2
    self.datas.selected = 0;
    self.datas.joypadParent = self;
    self.datas.font = UIFont.NewSmall;
    self.datas.doDrawItem = self.drawDatas;
    self.datas.drawBorder = true;
    self.datas:addColumn("Currency", 0);
    self.datas:addColumn("Value", 200);
    self.datas:setVisible(false);
    self.datas.onMouseMove = self.doOnMouseMove
    self.datas.onMouseMoveOutside = self.doOnMouseMoveOutside
    self:addChild(self.datas);

    self.holding = ISLabel:new(50, 50, FONT_HGT_MEDIUM, "Loading...", 1, 1, 1, 1, UIFont.Medium, true);
    self.holding:initialise();
    self.holding:instantiate();
    self:addChild(self.holding);

    self.tooltip = ISToolTip:new();
    self.tooltip:initialise();
    self.tooltip:setVisible(false);
    self.tooltip:setAlwaysOnTop(true)
    self.tooltip.description = "";
    self.tooltip:setOwner(self.tabPanel)

end

function PhunWalletContents:rebuild()
    self.datas:clear();
    for k, v in pairs(PhunWallet.currencies or {}) do
        local item = getScriptManager():getItem(v.type)
        if item then
            v.label = item:getDisplayName()
            v.texture = item:getNormalTexture()
        end
        self.datas:addItem(k, v)
        self.datas:setVisible(true)
        self.holding:setVisible(false)
    end
end

function PhunWalletContents:prerender()
    ISPanel.prerender(self);
    local maxWidth = self.parent.width
    local maxHeight = self.parent.height
    local minHeight = 250
    local sw = maxWidth
    self:setWidth(sw)
    self.datas:setWidth(sw - 20)
    self.datas:setHeight(math.max(minHeight, maxHeight))

    local tabHeight = self.itemsHeight + HEADER_HGT + 20

    self:setHeightAndParentHeight(math.max(self.height, tabHeight));
end

function PhunWalletContents:drawDatas(y, item, alt)

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
        local boa = " *"
        if not item.item.boa then
            boa = ""
        end
        self:drawTextureScaledAspect2(item.item.texture, xoffset, y + 4, item.height - 4, item.height - 8, 1, 1, 1, 1)
        xoffset = xoffset + item.height + 4
    end
    self:drawText(item.item.label, xoffset, y + 4, 1, 1, 1, a, self.font);
    self:clearStencilRect()

    local viewer = self.parent.playerObj
    local wallet = PhunWallet:getPlayerData(viewer).wallet or {
        current = {},
        bound = {}
    }
    local value = PhunTools:formatWholeNumber(wallet.current[item.item.key] or 0)
    local valueWidth = getTextManager():MeasureStringX(self.font, value)
    local w = self.width
    local cw = self.columns[2].size
    self:drawText(value, w - valueWidth - 10, y + 4, 1, 1, 1, a, self.font);

    self.itemsHeight = y + self.itemheight;
    return self.itemsHeight;
end

function PhunWalletContents:doTooltip()
    local rectWidth = 10;

    local title = "Hello";
    local description = "Tooltop desc"
    local heightPadding = 2
    local rectHeight = 100 + 100 + (heightPadding * 3);

    local x = self:getMouseX() + 20;
    local y = self:getMouseY() + 20;

    self:drawRect(x, y, rectWidth + 100, rectHeight, 1.0, 0.0, 0.0, 0.0);
    self:drawRectBorder(x, y, rectWidth + 100, rectHeight, 0.7, 0.4, 0.4, 0.4);
    self:drawText(title or "???", x + 2, y + 2, 1, 1, 1, 1);
    self:drawText(description or "???", x + 2, y + 100 + (heightPadding * 2), 1, 1, 1, 0.7);
end

function PhunWalletContents:doOnMouseMoveOutside(dx, dy)
    local tooltip = self.parent.tooltip
    tooltip:setVisible(false)
    tooltip:removeFromUIManager()
end
function PhunWalletContents:doOnMouseMove(dx, dy)

    local showInvTooltipForItem = nil
    local item = nil
    local tooltip = nil

    if not self.dragging and self.rowAt then
        if self:isMouseOver() then
            local row = self:rowAt(self:getMouseX(), self:getMouseY())
            if row ~= nil and row > 0 then
                item = self.items[row] and self.items[row].item
                if item and item.boa then
                    tooltip = self.parent.tooltip
                    local viewer = self.parent.playerObj
                    local wallet = PhunWallet:getPlayerData(viewer).wallet or {
                        current = {},
                        bound = {}
                    }
                    tooltip:setName(item.label)
                    tooltip.description = getText("IGUI_PhunWallet.BalanceReplenishedOnDeath",
                        PhunTools:formatWholeNumber(wallet.bound[item.key] or 0))
                    if not tooltip:isVisible() then

                        tooltip:addToUIManager();
                        tooltip:setVisible(true)
                    end
                    tooltip:bringToTop()
                elseif self.parent.tooltip:isVisible() then
                    self.parent.tooltip:setVisible(false)
                    self.parent.tooltip:removeFromUIManager()
                end
            end
        end
    end

end
