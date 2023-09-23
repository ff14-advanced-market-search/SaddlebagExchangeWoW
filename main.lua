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

    self:showall()
end

function Saddlebag:showall(msg, SaddlebagEditBox)
    local output = ""
    if (UndercutJsonTable == {}) 
    then
        output = output .. "[]"
    else
        output = output .. "["
        for k, v in pairs(UndercutJsonTable) do
            output = output .. v .. ","
        end
        -- if no data found
        if (output == "[")
        then
            output = "[]"
        else
            -- remove last comma
            output = output:sub(1, -2)
            output = output .. "]"
        end
    end

    local af = Saddlebag:auctionButton(output)
    af:Show()
end

function Saddlebag:clear(msg, SaddlebagEditBox)
    UndercutJsonTable = {}
    print("Your auctions table has been cleared out.")
end

function Saddlebag:GetUpdatedListingsJson()
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
            local _, _, _, _, _, _, _, itemStackCount= GetItemInfo(item["itemKey"]["itemID"])
            if itemStackCount == 1 then
                if seen[kv_str] then
                    table.remove(ownedAuctions, index)
                else
                -- print(kv_str)
                    seen[kv_str] = true
                    clean_ownedAuctions[index] = item
                end
            end
        end
    end

    -- used as key in the table
    playerName = UnitName("player") .. tostring(GetRealmID())
    if (UndercutJsonTable == nil)
    then
        UndercutJsonTable = {}
    end

    -- get undercut if active auctions found
    if (active_auctions > 0)
    then

        -- gets the auction id
        -- print(ownedAuctions[1]["auctionID"])

        -- doesnt work but it does show me the
        -- print(table.concat(ownedAuctions))

        -- loop through auctions
        output = "{\n"
        output = output .. '    "homeRealmName": "' .. tostring(GetRealmID()) .. '",\n'
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

            -- can go back to this if we need to disable legacy
            -- if (v["status"] == 0) and (v["itemKey"]["itemID"] ~= 82800) and (v["itemKey"]["itemID"] >= 185000)

            if (v["status"] == 0) and (v["itemKey"]["itemID"] ~= 82800)
            then
                item_data = '\n        {"itemID": ' .. tostring(v["itemKey"]["itemID"]) .. ', "price": '.. tostring(v["buyoutAmount"])  .. ', "auctionID": '.. tostring(v["auctionID"]) .. '},'
                output = output .. item_data
            elseif (v["status"] == 0) and (v["itemKey"]["itemID"] == 82800)
            then
                item_data = '\n        {"petID": ' .. tostring(v["itemKey"]["battlePetSpeciesID"]) .. ' ,"price": '.. tostring(v["buyoutAmount"]) .. ', "auctionID": '.. tostring(v["auctionID"]) .. '},'
                output = output .. item_data
            end
        end
        -- remove last comma
        output = output:sub(1, -2)
        output = output .. "\n    ]\n"
        output = output .. "}"
        -- add to saved variable
        UndercutJsonTable[playerName] = output
        -- print(output)
        return output
    else
        print("ERROR! Make sure you are at the auction house looking at your auctions before you click the button or run /sbex")
        print("{}")
        return "{}"
    end
end

function Saddlebag:handler(msg, SaddlebagEditBox)
    if msg == 'help' 
    then
        message('Go to the auction house, view your auctions and then click the pop up button or run /sbex')
    else
        output = Saddlebag:GetUpdatedListingsJson()
        local af = Saddlebag:auctionButton(output)
        af:Show()
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
    addonButton:SetText("Show Single Undercut Data")
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

function Saddlebag:addonButton2()
    local addonButton2 = CreateFrame("Button", "MyButton", UIParent, "UIPanelButtonTemplate")
    addonButton2:SetFrameStrata("HIGH")
    addonButton2:SetSize(180,22) -- width, height
    addonButton2:SetText("View Full Undercut Data")
    -- center is fine for now, but need to pin to auction house frame https://wowwiki-archive.fandom.com/wiki/API_Region_SetPoint
    addonButton2:SetPoint("TOPRIGHT", "AuctionHouseFrame", "TOPRIGHT", -240, 0)

    -- make moveable
    addonButton2:SetMovable(true)
    addonButton2:EnableMouse(true)
    addonButton2:RegisterForDrag("LeftButton")
    addonButton2:SetScript("OnDragStart", function(self, button)
        self:StartMoving()
        -- print("OnDragStart", button)
    end)
    addonButton2:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- print("OnDragStop")
    end)

    -- open main window on click
    addonButton2:SetScript("OnClick", function()
        Saddlebag:showall()
        -- addonButton2:Hide()
    end)

    addonButton2:RegisterEvent("AUCTION_HOUSE_CLOSED")
    addonButton2:SetScript("OnEvent", function()
        addonButton2:Hide()
    end)
end

function Saddlebag:addonButton3()
    local addonButton3 = CreateFrame("Button", "MyButton", UIParent, "UIPanelButtonTemplate")
    addonButton3:SetFrameStrata("HIGH")
    addonButton3:SetSize(120,22) -- width, height
    addonButton3:SetText("Clear All Data")
    -- center is fine for now, but need to pin to auction house frame https://wowwiki-archive.fandom.com/wiki/API_Region_SetPoint
    addonButton3:SetPoint("TOPRIGHT", "AuctionHouseFrame", "TOPRIGHT", -470, 0)

    -- make moveable
    addonButton3:SetMovable(true)
    addonButton3:EnableMouse(true)
    addonButton3:RegisterForDrag("LeftButton")
    addonButton3:SetScript("OnDragStart", function(self, button)
        self:StartMoving()
        -- print("OnDragStart", button)
    end)
    addonButton3:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- print("OnDragStop")
    end)

    -- open main window on click
    addonButton3:SetScript("OnClick", function()
        Saddlebag:clear()
        -- addonButton3:Hide()
    end)

    addonButton3:RegisterEvent("AUCTION_HOUSE_CLOSED")
    addonButton3:SetScript("OnEvent", function()
        addonButton3:Hide()
    end)
end

-- https://wowwiki-archive.fandom.com/wiki/Events/Names
local buttonPopUpFrame = CreateFrame("Frame")
buttonPopUpFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
buttonPopUpFrame:SetScript("OnEvent", function()
    Saddlebag:addonButton()
    Saddlebag:addonButton2()
    Saddlebag:addonButton3()
end)

local buttonPopUpFrame = CreateFrame("Frame")
buttonPopUpFrame:RegisterEvent("OWNED_AUCTIONS_UPDATED")
buttonPopUpFrame:SetScript("OnEvent", function()
    Saddlebag:GetUpdatedListingsJson()
end)
