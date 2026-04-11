require "ISUI/ISPanel"

ISCarBombWarning = ISPanel:derive("ISCarBombWarning")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6

function ISCarBombWarning.OpenPanel()
    local x = getMouseX() + 10;
    local y = getMouseY() + 10;
    local ui = ISCarBombWarning:new(x,y,400,600);
    ui:initialise();
    ui:addToUIManager();
end

function ISCarBombWarning:initialise()
    ISPanel.initialise(self);
end

function ISCarBombWarning:createChildren()
    ISPanel.createChildren(self);

    local btnWid = 100;
    local panelY = 200;

    local y = UI_BORDER_SPACING+1;
    self.titleText = getText('UI_CarBombsV1.2WarningTitle');
    self.title = ISLabel:new (0, y, FONT_HGT_MEDIUM, self.titleText, 1, 1, 1, 1.0, UIFont.Medium, true);
    self.title:initialise();
    self.title:instantiate();
    self:addChild(self.title);

  --  y = y + FONT_HGT_MEDIUM + UI_BORDER_SPACING;

    y = y + panelY + UI_BORDER_SPACING+1;

    self.accept = ISButton:new(10, y, btnWid, BUTTON_HGT, getText("UI_Ok"), self, ISCarBombWarning.onOptionMouseDown);
    self.accept.internal = "ACCEPT";
    self.accept:initialise()
    self.accept:instantiate()
    self.accept:enableAcceptColor()
    self:addChild(self.accept)
    local w = 600 + (UI_BORDER_SPACING+1)*2;
    self.accept:setX(w-btnWid-UI_BORDER_SPACING-1);

    y = y + FONT_HGT_MEDIUM + UI_BORDER_SPACING+1;

    self:setWidth(w);
    self:setHeight(y);
    --   self:setWidth('650');
    --   self:setHeight('300');

    local textW = getTextManager():MeasureStringX(UIFont.Medium, self.titleText);
    local textX = (w/2) - (textW/2);

    self.title:setX(textX);

    y = 70

    self.warningLabelText = getText('UI_CarBombsV1.2WarningFull')
    textW = getTextManager():MeasureStringX(UIFont.Small, self.warningLabelText);
    textX = (w/2) - (textW/2);
    self.warningLabel = ISLabel:new(textX, y, FONT_HGT_SMALL, self.warningLabelText, 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.warningLabel)

    -- old y: 2*(UI_BORDER_SPACING + FONT_HGT_MEDIUM)
    -- y = y + BUTTON_HGT + 3*(UI_BORDER_SPACING+1);
    y = y + 2*(UI_BORDER_SPACING + FONT_HGT_MEDIUM)

    textW = getTextManager():MeasureStringX(UIFont.Small, self.warningLabelText2);
--    textX = (w/2) - (textW/2);
    local warningLabelText2 = getText('UI_CarBombsV1.2Warning2');
    self.warningLabelText2 = getText('UI_CarBombsV1.2Warning2');
    self.warningLabel2 = ISLabel:new(textX, y, FONT_HGT_SMALL, self.warningLabelText2, 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.warningLabel2)

    y = y + BUTTON_HGT + 3*(UI_BORDER_SPACING+1);

    textW = getTextManager():MeasureStringX(UIFont.Small, self.warningLabelText3);
--    textX = (w/2) - (textW/2);
    local warningLabelText3 = getText('UI_CarBombsV1.2Warning3');
    self.warningLabelText3 = getText('UI_CarBombsV1.2Warning3');
    self.warningLabel3 = ISLabel:new(textX, y, FONT_HGT_SMALL, self.warningLabelText3, 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.warningLabel3)
end

function ISCarBombWarning:onOptionMouseDown(button, x, y)
    if button.internal == "ACCEPT" then
        self:setVisible(false);
        self:removeFromUIManager();
    end
end

function ISCarBombWarning:setVisible(visible)
    self.javaObject:setVisible(visible);
end

function ISCarBombWarning:new(x, y, width, height)
    local o = {};
    o = ISPanel:new(x, y, 1000, height);
    setmetatable(o, self);
    self.__index = self;
    o.variableColor={r=0.9, g=0.55, b=0.1, a=1};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
    o.backgroundColor = {r=0, g=0, b=0, a=0.8};
    o.buttonBorderColor = {r=0.7, g=0.7, b=0.7, a=0.5};
    o.zOffsetSmallFont = 25;
    o.moveWithMouse = true;

    return o;
end
