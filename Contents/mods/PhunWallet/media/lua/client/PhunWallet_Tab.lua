require "ISUI/ISPanelJoypad"
ISPhunWalletWalletTab = ISPanelJoypad:derive("ISPhunWalletWalletTab");
local PhunWallet = PhunWallet

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local FONT_SCALE = FONT_HGT_SMALL / 14

local function addCharacterPageTab(tabName, pageType)
    local viewName = tabName .. "View"
    local upperLayer_ISCharacterInfoWindow_createChildren = ISCharacterInfoWindow.createChildren
    function ISCharacterInfoWindow:createChildren()
        upperLayer_ISCharacterInfoWindow_createChildren(self)
        self[viewName] = pageType:new(0, 8, self.width, self.height - 8, self.playerNum)
        self[viewName]:initialise()
        self[viewName].infoText = getText("UI_" .. tabName .. "Panel"); -- UI_<tabName>Panel is full text of tooltip
        self.panel:addView(getText("UI_PhunWalletWallet"), self[viewName]) -- UI_<tabName> is short text of tab
    end

    local upperLayer_ISCharacterInfoWindow_onTabTornOff = ISCharacterInfoWindow.onTabTornOff
    function ISCharacterInfoWindow:onTabTornOff(view, window)
        if self.playerNum == 0 and view == self[viewName] then
            ISLayoutManager.RegisterWindow('charinfowindow.' .. tabName, ISCollapsableWindow, window)
        end
        upperLayer_ISCharacterInfoWindow_onTabTornOff(self, view, window)

    end

    local upperLayer_ISCharacterInfoWindow_SaveLayout = ISCharacterInfoWindow.SaveLayout
    function ISCharacterInfoWindow:SaveLayout(name, layout)
        upperLayer_ISCharacterInfoWindow_SaveLayout(self, name, layout)

        local tabs = {}
        if self[viewName].parent == self.panel then
            table.insert(tabs, tabName)
            if self[viewName] == self.panel:getActiveView() then
                layout.current = tabName
            end
        end
        if not layout.tabs then
            layout.tabs = ""
        end
        layout.tabs = layout.tabs .. table.concat(tabs, ',')
    end

end

function ISPhunWalletWalletTab:initialise()
    ISPanelJoypad.initialise(self);
end

function ISPhunWalletWalletTab:setSelected(tabName, row)
    self.selected = row
    self.selectedTab = tabName
end

function ISPhunWalletWalletTab:createChildren()

    self.tabPanel = ISTabPanel:new(10, 10, self.width - 20, self.height - 20)
    self.tabPanel:initialise()
    self.tabPanel.tabFont = UIFont.Medium
    self.tabPanel.tabHeight = FONT_HGT_MEDIUM + 6
    self.tabPanel.activateView = function(self, viewname)
        ISTabPanel.activateView(self, viewname)
        self.parent:setSelected(viewname, self.activeView.view.selected)
    end
    self.tabPanel.render = self.tabsRender
    self:addChild(self.tabPanel)

    self.currentPanel = ISPanel:new(0, 50, self.width, self.tabPanel.height - 50)
    self.currentPanel:initialise()
    self.currentPanel:instantiate()

    self.currentList = ISScrollingListBox:new(1, 50, self.tabPanel.width - 20, self.tabPanel.height - 60)
    self.currentList.itemPadY = 10 * FONT_SCALE
    self.currentList.itemheight = FONT_HGT_SMALL + self.currentList.itemPadY * 2 + 1 * FONT_SCALE + FONT_HGT_SMALL
    self.currentList.textureHeight = self.currentList.itemheight - self.currentList.itemPadY * 2
    self.currentList.mouseoverselected = -1
    self.currentList:initialise()
    self.currentList.doDrawItem = self.doDrawCurrentItem
    self.currentList.selectionMode = "single"
    self.currentList.onMouseDown = function(self, x, y)
        if #self.items == 0 then
            return
        end
        local row = self:rowAt(x, y)

        self.parent.activeTab = self.parent.activeView.name

        if row > #self.items then
            row = #self.items
        end

        if row < 1 then
            return
        end

        if row == self.selected and self.parent.activeTab == self.parent.activeView.name then
            return
        end

        getSoundManager():playUISound("UISelectListItem")

        self.selected = row

        if self.onmousedown then
            self.onmousedown(self.target, self.items[self.selected].item)
        end
        self.parent.parent:setSelected(self.parent.activeTab, self.items[self.selected])
    end
    self.currentPanel:addChild(self.currentList)

    self.currentDesc = ISRichTextPanel:new(1, self.currentPanel.height + 5, self.currentPanel.width - 1, 19)
    self.currentDesc.marginLeft = 10
    self.currentDesc.marginTop = 10
    self.currentDesc.marginRight = 10
    self.currentDesc.marginBottom = 10
    self.currentDesc:setText(getText("IGUI_PhunWallet.CurrentDesc"))
    self.currentDesc.textDirty = true;
    self.currentDesc.autosetheight = true
    self.currentDesc.clip = true
    self.currentDesc:initialise()
    self.currentDesc:paginate()
    self.currentPanel:addChild(self.currentDesc)

    self.tabPanel:addView(getText("IGUI_PhunWallet.Current"), self.currentList)

    self.savingsPanel = ISPanel:new(0, 50, self.width, self.tabPanel.height - 50)
    self.savingsPanel:initialise()
    self.savingsPanel:instantiate()

    self.savingsList = ISScrollingListBox:new(1, 1, self.savingsPanel.width, self.savingsPanel.height - 48)

    self.savingsList.itemPadY = 10 * FONT_SCALE
    self.savingsList.itemheight = FONT_HGT_SMALL + self.savingsList.itemPadY * 2 + 1 * FONT_SCALE + FONT_HGT_SMALL
    self.savingsList.textureHeight = self.savingsList.itemheight - self.savingsList.itemPadY * 2
    self.savingsList.mouseoverselected = -1
    self.savingsList:initialise()
    self.savingsList.doDrawItem = self.doDrawSavingsItem
    self.savingsList.selectionMode = "single"
    self.savingsList.onMouseDown = function(self, x, y)
        if #self.items == 0 then
            return
        end
        local row = self:rowAt(x, y)

        self.parent.activeTab = self.parent.activeView.name

        if row > #self.items then
            row = #self.items
        end

        if row < 1 then
            return
        end

        if row == self.selected and self.parent.activeTab == self.parent.activeView.name then
            return
        end

        getSoundManager():playUISound("UISelectListItem")

        self.selected = row

        if self.onmousedown then
            self.onmousedown(self.target, self.items[self.selected].item)
        end
        self.parent.parent:setSelected(self.parent.activeTab, self.items[self.selected])
    end
    self.savingsPanel:addChild(self.savingsList)
    self.savingsDesc = ISRichTextPanel:new(1, self.savingsList.height + 5, self.savingsPanel.width - 1, 19)
    self.savingsDesc.marginLeft = 10
    self.savingsDesc.marginTop = 10
    self.savingsDesc.marginRight = 10
    self.savingsDesc.marginBottom = 10
    self.savingsDesc:setText(getText("IGUI_PhunWallet.SavingsDesc"))
    self.savingsDesc.textDirty = true;
    self.savingsDesc.autosetheight = true
    self.savingsDesc.clip = true
    self.savingsDesc:initialise()
    self.savingsDesc:paginate()
    self.savingsPanel:addChild(self.savingsDesc)

    self.tabPanel:addView(getText("IGUI_PhunWallet.Savings"), self.savingsPanel)

    self:rebuild()

end

function doDrawRow(self, y, data, alt, wallet)
    if data and data.item and data.item.displayText then
        local text = data.item.displayText
        local currencies = PhunWallet.currencies or {}
        local key = data.item.key or ""
        local value = PhunTools:formatWholeNumber(wallet[key] or 0)

        local x = 2 -- reset left

        local alpha = 0.9
        if alt then
            alpha = 0.6
        end

        local selected = self.parent.parent.selected

        if selected and selected.index == data.index then
            self:drawRect(0, y, self:getWidth(), data.height, 0.3, 0.7, 0.35, 0.15);
        elseif alt then
            self:drawRect(0, y, self:getWidth(), data.height, 0.1, 0.1, 0.1, 0.6);
        end
        -- draw border for first column
        self:drawRectBorder(x, y, self:getWidth() / 2, data.height, 0.5, self.borderColor.r, self.borderColor.g,
            self.borderColor.b)

        -- draw icon of the currency
        if currencies[data.item.type] and currencies[data.item.type].texture then
            self:drawTextureScaledAspect2(currencies[data.item.type].texture, x, y + 5, data.height - 10,
                data.height - 10, 1, 1, 1, 1)
            -- move cursor to the right
            x = data.height + 5
        end

        -- draw the name of the currency
        self:drawText(text, x, y + 3, 0.7, 0.7, 0.7, 1.0, UIFont.Medium)

        -- move left to be new column
        x = (self:getWidth() / 2)

        -- draw border for second column
        self:drawRectBorder(x, y, self:getWidth() / 2, data.height, 0.5, self.borderColor.r, self.borderColor.g,
            self.borderColor.b)

        -- width of "value" text
        local textWidth = getTextManager():MeasureStringX(UIFont.Medium, value)
        self:drawText(value, self.width - textWidth - 20, y + 3, 0.7, 0.7, 0.7, 1.0, UIFont.Medium)
    end
    return y + FONT_HGT_LARGE + 3 * FONT_SCALE
end

function ISPhunWalletWalletTab:doDrawCurrentItem(y, data, alt)
    local wallets = ISPhunWalletWalletTab.wallet or {}
    return doDrawRow(self, y, data, alt, wallets.current or {})
end

function ISPhunWalletWalletTab:doDrawSavingsItem(y, data, alt)
    local wallets = ISPhunWalletWalletTab.wallet or {}
    return doDrawRow(self, y, data, alt, wallets.bound or {})
end

function ISPhunWalletWalletTab:tabsRender()
    ISScrollingListBox.render(self)
    local inset = 1
    local x = inset + self.scrollX

    for i, viewObject in ipairs(self.viewList) do
        local tabWidth = self.equalTabWidth and self.maxLength or viewObject.tabWidth
        tabWidth = tabWidth + 4
        if viewObject == self.activeView then
            self:drawRect(x, 0, tabWidth, self.tabHeight, 1, 0.4, 0.4, 0.4, 0.7)
        else
            self:drawRect(x + tabWidth, 0, 1, self.tabHeight, 1, 0.4, 0.4, 0.4, 0.9)
            if self:getMouseY() >= 0 and self:getMouseY() < self.tabHeight and self:isMouseOver() and
                self:getTabIndexAtX(self:getMouseX()) == i then
                viewObject.fade:setFadeIn(true)
            else
                viewObject.fade:setFadeIn(false)
            end
            viewObject.fade:update()
            self:drawRect(x, 0, tabWidth, self.tabHeight, 0.2 * viewObject.fade:fraction(), 1, 1, 1, 0.9)
        end
        self:drawTextCentre(viewObject.name, x + (tabWidth / 2), 3, 1, 1, 1, 1, self.tabFont)
        x = x + tabWidth
    end
end

function ISPhunWalletWalletTab:rebuild()

    local panel = self.instance.currentList
    if panel then
        panel:clear()
        for k, v in pairs((self.wallet or {}).current or {}) do
            if panel and PhunWallet.currencies[k] then
                panel:addItem(k, PhunWallet.currencies[k])
            end
        end
    end

    panel = self.instance.savingsList
    if panel then
        panel:clear()
        for k, v in pairs((self.wallet or {}).bound or {}) do
            if panel and PhunWallet.currencies[k] then
                panel:addItem(k, PhunWallet.currencies[k])
            end
        end
    end

end

function ISPhunWalletWalletTab:setVisible(visible)
    self.javaObject:setVisible(visible);
end

function ISPhunWalletWalletTab:prerender()
    ISPanelJoypad.prerender(self)

    self:setStencilRect(0, 0, self.width, self.height)
end

function ISPhunWalletWalletTab:render()

    local x = 20
    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    local textY = fontHeight
    local maxTextWidth = 0

    local maxWidth = self.parent.width

    local sw = maxWidth
    self:setWidth(sw)
    self.tabPanel:setWidth(sw - 20)
    self.savingsPanel:setWidth(sw - 20)
    self.currentPanel:setWidth(sw - 20)
    self.currentList:setWidth(sw - 20)
    self.savingsList:setWidth(sw - 20)
    self.savingsDesc:setWidth(sw - 20)

    local tabHeight = self.tabPanel.height
    local maxHeight = getCore():getScreenHeight() - tabHeight - 20
    if ISWindow and ISWindow.TitleBarHeight then
        maxHeight = maxHeight - ISWindow.TitleBarHeight
    end
    self:setHeightAndParentHeight(tabHeight);
    self:setScrollHeight(textY)

    self:clearStencilRect()
end

function ISPhunWalletWalletTab:onMouseWheel(del)
    self:setYScroll(self:getYScroll() - del * 30)
    return true
end

function ISPhunWalletWalletTab:new(x, y, width, height, playerNum)
    local o = {};
    o = ISPanelJoypad:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;
    o.playerNum = playerNum
    o.playerObj = getSpecificPlayer(playerNum);
    o.wallet = {}
    o.currencies = {}
    o:noBackground();
    ISPhunWalletWalletTab.instance = o;
    return o;
end

function ISPhunWalletWalletTab:ensureVisible()
    if not self.joyfocus then
        return
    end
    local child = nil; -- TODO manage scroll? self.progressBars[self.joypadIndex]
    if not child then
        return
    end
    local y = child:getY()
    if y - 40 < 0 - self:getYScroll() then
        self:setYScroll(0 - y + 40)
    elseif y + child:getHeight() + 40 > 0 - self:getYScroll() + self:getHeight() then
        self:setYScroll(0 - (y + child:getHeight() + 40 - self:getHeight()))
    end
end

function ISPhunWalletWalletTab:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData);
    self.joypadIndex = nil
    self.barWithTooltip = nil
end

function ISPhunWalletWalletTab:onLoseJoypadFocus(joypadData)
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData);
end

function ISPhunWalletWalletTab:onJoypadDown(button)
    if button == Joypad.AButton then
    end
    if button == Joypad.YButton then
    end
    if button == Joypad.BButton then
    end
    if button == Joypad.LBumper then
        getPlayerInfoPanel(self.playerNum):onJoypadDown(button)
    end
    if button == Joypad.RBumper then
        getPlayerInfoPanel(self.playerNum):onJoypadDown(button)
    end
end

function ISPhunWalletWalletTab:onJoypadDirDown()
    self.joypadIndex = self.joypadIndex + 1
    self:ensureVisible()
    self:updateTooltipForJoypad()
end

function ISPhunWalletWalletTab:onJoypadDirLeft()
end

function ISPhunWalletWalletTab:onJoypadDirRight()
end

addCharacterPageTab("PhunWalletWallet ", ISPhunWalletWalletTab)

Events[PhunWallet.events.OnPhunWalletChanged].Add(function(data)
    ISPhunWalletWalletTab.wallet = data
    if ISPhunWalletWalletTab.rebuild then
        ISPhunWalletWalletTab:rebuild()
    end
end)

Events[PhunWallet.events.OnPhunWalletCurrenciesUpdated].Add(function(data)
    ISPhunWalletWalletTab.currencies = data
    if ISPhunWalletWalletTab.rebuild then
        ISPhunWalletWalletTab:rebuild()
    end
end)

