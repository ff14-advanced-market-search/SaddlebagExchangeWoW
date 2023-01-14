-- Now on Curseforge!

-- message('Thanks for testing out Saddlebag Exchange WoW Undercut alerts! Use the commands: \n/sbex, /Saddlebag or /Saddlebagexchange')
local _, Saddlebag = ...

Saddlebag = LibStub("AceAddon-3.0"):NewAddon(Saddlebag, "Saddlebag", "AceConsole-3.0", "AceEvent-3.0")
LibRealmInfo = LibStub("LibRealmInfo")

local SaddlebagFrame = nil

-- SLASH_SADDLEBAG1, SLASH_SADDLEBAG2, SLASH_SADDLEBAG3 = '/sbex', '/Saddlebag', '/Saddlebagexchange';
function Saddlebag:OnInitialize()
    -- init databroker
    self.db = LibStub("AceDB-3.0"):New("SaddlebagDB", {
      profile = {
        minimap = {
          hide = false,
        },
        frame = {
          point = "CENTER",
          relativeFrame = nil,
          relativePoint = "CENTER",
          ofsx = 0,
          ofsy = 0,
          width = 750,
          height = 400,
        },
      },
    });
    -- LibDBIcon:Register("Saddlebag Exchange", SaddlebagLDB, self.db.profile.minimap)
    -- Saddlebag:UpdateMinimapButton()
  
    Saddlebag:RegisterChatCommand('sbex', 'HandleChatCommand')
end

function Saddlebag:HandleChatCommand(input)
    local args = {strsplit(' ', input)}

    for _, arg in ipairs(args) do
        if arg == 'help' then
            DEFAULT_CHAT_FRAME:AddMessage(
                "Saddlebag: NYI"
            )
            return
        end
    end

    self:handler()
end

function Saddlebag:handler(msg, SaddlebagEditBox)
    if msg == 'help' then
        message('Go to the auction house, view your auctions and then click the pop up button or run /sbex')
    else
        ownedAuctions=C_AuctionHouse.GetOwnedAuctions();
        print("Found", table.maxn(ownedAuctions), "auctions.")

        -- find active auctions
        active_auctions=0
        for k, v in pairs(ownedAuctions) do
            if v["status"] == 0 then
                active_auctions=active_auctions+1
            end
        end
        print("Found", tostring(active_auctions), "active auctions.")

        -- delete duplicate entries
        local seen = {}
        local clean_ownedAuctions = {}
        for index,item in ipairs(ownedAuctions) do
            -- skip sold auctions
            if item["status"] == 0 then
                kv_str = tostring(item["itemKey"]["itemID"]) .. "_" .. tostring(item["buyoutAmount"])
                if seen[kv_str] then
                    table.remove(ownedAuctions, index)
                else
                    -- print(kv_str)
                    seen[kv_str] = true
                    clean_ownedAuctions[index] = item
                end
            end
        end

        -- get undercut if active auctions found
        if (active_auctions > 0)
        then

            -- gets the auction id
            -- print(ownedAuctions[1]["auctionID"])

            -- doesnt work but it does show me the 
            -- print(table.concat(ownedAuctions))

            -- loop through auctions
            output = "\n"
            output = output .. "{\n"
            output = output .. '    "homeRealmName": "' .. tostring(GetRealmName()) .. '",\n'
            output = output .. '    "region": "' .. GetCurrentRegionName() .. '",\n'

            output = output .. '    "user_auctions": ['
            for k, v in pairs(clean_ownedAuctions) do

                -- print('===view auction keys===')
                -- print("auction keys")
                -- for i, j in pairs(v) do
                --     print(i)
                -- end

                -- print('---view itemKey keys---')
                -- print("itemKey info")
                -- for i, j in pairs(v["itemKey"]) do
                --     print(i)
                -- end
                -- print()
                -- print("itemID found!", v["itemKey"]["itemID"])
                -- print("price found!", v["buyoutAmount"])

                -- 0 if listed, 1 if sold
                -- dont do 82800 for battle pets its all messy
                if (v["status"] == 0) and (v["itemKey"]["itemID"] ~= 82800) then
                    item_data = '\n        {"itemID": ' .. tostring(v["itemKey"]["itemID"]) .. ',"price": '.. tostring(v["buyoutAmount"]) .. '},'
                    output = output .. item_data
                end
            end
            output = output:sub(1, -2)
            output = output .. "\n    ]\n"
            output = output .. "}\n"
            -- print(output)
            -- return output
            local af = Saddlebag:auctionButton(output)
            af:Show()
        else
            print("ERROR! Make sure you are at the auction house looking at your auctions before you click the button or run /sbex")
            print("{}")
            return "{}"
        end
    end
end
SlashCmdList["SADDLEBAG"] = handler; -- Also a valid assignment strategy

-- easy button system
function Saddlebag:auctionButton(text)
    if not SaddlebagFrame then
        -- MainFrame
        local frameConfig = self.db.profile.frame
        local f = CreateFrame("Frame", "SaddlebagFrame", UIParent, "DialogBoxFrame")
        f:ClearAllPoints()
        -- load position from local DB
        f:SetPoint(
            frameConfig.point,
            frameConfig.relativeFrame,
            frameConfig.relativePoint,
            frameConfig.ofsx,
            frameConfig.ofsy
        )
        f:SetSize(frameConfig.width, frameConfig.height)
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
            edgeSize = 16,
            insets = { left = 8, right = 8, top = 8, bottom = 8},
        })
        f:SetMovable(true)
        f:SetClampedToScreen(true)
        f:SetScript("OnMouseDown", function(self, button) -- luacheck: ignore
            if button == "LeftButton" then
                self:StartMoving()
            end
        end)
        f:SetScript("OnMouseUp", function(self, _) --luacheck: ignore
            self:StopMovingOrSizing()
            -- save position between sessions
            local point, relativeFrame, relativeTo, ofsx, ofsy = self:GetPoint()
            frameConfig.point = point
            frameConfig.relativeFrame = relativeFrame
            frameConfig.relativePoint = relativeTo
            frameConfig.ofsx = ofsx
            frameConfig.ofsy = ofsy
        end)

        -- scroll frame

        local sf = CreateFrame("ScrollFrame", "SaddlebagScrollFrame", f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("LEFT", 16, 0)
        sf:SetPoint("RIGHT", -32, 0)
        sf:SetPoint("TOP", 0, 0)
        sf:SetPoint("BOTTOM", SaddlebagFrameButton, "TOP", 0, 0)

        -- edit box
        local eb = CreateFrame("EditBox", "SaddlebagEditBox", SaddlebagScrollFrame)
        eb:SetSize(sf:GetSize())
        eb:SetMultiLine(true)
        eb:SetAutoFocus(true)
        eb:SetFontObject("ChatFontNormal")
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)

            -- resizing
    f:SetResizable(true)
    if f.SetMinResize then
      -- older function from shadowlands and before
      -- Can remove when Dragonflight is in full swing
      f:SetMinResize(150, 100)
    else
      -- new func for dragonflight
      f:SetResizeBounds(150, 100, nil, nil)
    end
    local rb = CreateFrame("Button", "SaddlebagResizeButton", f)
    rb:SetPoint("BOTTOMRIGHT", -6, 7)
    rb:SetSize(16, 16)

    rb:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    rb:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    rb:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    rb:SetScript("OnMouseDown", function(self, button) -- luacheck: ignore
        if button == "LeftButton" then
            f:StartSizing("BOTTOMRIGHT")
            self:GetHighlightTexture():Hide() -- more noticeable
        end
    end)
    rb:SetScript("OnMouseUp", function(self, _) -- luacheck: ignore
        f:StopMovingOrSizing()
        self:GetHighlightTexture():Show()
        eb:SetWidth(sf:GetWidth())

        -- save size between sessions
        frameConfig.width = f:GetWidth()
        frameConfig.height = f:GetHeight()
    end)

    SaddlebagFrame = f
  end
  SaddlebagEditBox:SetText(text)
  SaddlebagEditBox:HighlightText()
  return SaddlebagFrame

end

-- easy button system
function Saddlebag:addonButton()
    local addonButton = CreateFrame("Button", "MyButton", UIParent, "UIPanelButtonTemplate")
	addonButton:SetFrameStrata("HIGH")
    addonButton:SetSize(180,22) -- width, height
    addonButton:SetText("Open Saddlebag Exchange")
    -- center is fine for now, but need to pin to auction house frame https://wowwiki-archive.fandom.com/wiki/API_Region_SetPoint
    addonButton:SetPoint("TOPRIGHT", "AuctionHouseFrame", "TOPRIGHT", -30, 0)

    -- make moveable
    addonButton:SetMovable(true)
    addonButton:EnableMouse(true)
    addonButton:RegisterForDrag("LeftButton")
    addonButton:SetScript("OnDragStart", function(self, button)
        self:StartMoving()
        -- print("OnDragStart", button)
    end)
    addonButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- print("OnDragStop")
    end)

    -- open main window on click
    addonButton:SetScript("OnClick", function()
        Saddlebag:handler()
        -- addonButton:Hide()
    end)

    addonButton:RegisterEvent("AUCTION_HOUSE_CLOSED")
    addonButton:SetScript("OnEvent", function()
        addonButton:Hide()
    end)
end

-- https://wowwiki-archive.fandom.com/wiki/Events/Names
local buttonPopUpFrame = CreateFrame("Frame")
buttonPopUpFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
buttonPopUpFrame:SetScript("OnEvent", function()
    Saddlebag:addonButton()
end)
