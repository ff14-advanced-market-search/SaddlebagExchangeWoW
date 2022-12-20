-- Now on Curseforge!

-- message('Thanks for testing out Saddlebag Exchange WoW Undercut alerts! Use the commands: \n/sbex, /saddlebag or /saddlebagexchange')

SLASH_SADDLEBAG1, SLASH_SADDLEBAG2, SLASH_SADDLEBAG3 = '/sbex', '/saddlebag', '/saddlebagexchange';
local function handler(msg, editBox)
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
                if v["status"] == 0 then
                    item_data = '\n        {"itemID": ' .. tostring(v["itemKey"]["itemID"]) .. ',"price": '.. tostring(v["buyoutAmount"]) .. '},'
                    output = output .. item_data
                end
            end
            output = output:sub(1, -2)
            output = output .. "\n    ]\n"
            output = output .. "}\n"
            print(output)
            return output
        else
            print("ERROR! Make sure you are at the auction house looking at your auctions before you click the button or run /sbex")
            print("{}")
            return "{}"
        end
    end
end
SlashCmdList["SADDLEBAG"] = handler; -- Also a valid assignment strategy

-- easy button system
local function auctionButton()
    -- button for function
    local wrapper = CreateFrame("Frame", nil, UIParent, "ButtonFrameTemplate")
    ButtonFrameTemplate_HidePortrait(wrapper)
    ButtonFrameTemplate_HideButtonBar(wrapper)
    wrapper:SetSize(380, 400)
    wrapper:SetPoint("CENTER", 100, 0)

    -- https://wowpedia.fandom.com/wiki/Making_draggable_frames
    wrapper:SetMovable(true)
    wrapper:EnableMouse(true)
    wrapper:RegisterForDrag("LeftButton")
    wrapper:SetScript("OnDragStart", function(self, button)
        self:StartMoving()
        print("OnDragStart", button)
    end)
    wrapper:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        print("OnDragStop")
    end)

    -- make buttons
    local b = CreateFrame("Button", "MyButton", wrapper, "UIPanelButtonTemplate")
    local editBox = CreateFrame("EditBox", nil, wrapper)
    b:SetSize(180,22) -- width, height
    b:SetText("Get Undercut Alert Data")
    -- center is fine for now, but need to pin to auction house frame https://wowwiki-archive.fandom.com/wiki/API_Region_SetPoint
    b:SetPoint("TOP", 0, -25)
    b:SetScript("OnClick", function()
        output = handler()

        editBox:SetSize(350, 200) -- 200px by 200px
        editBox:SetFontObject("GameFontNormal") -- set it to the default game font, a small yellow one
        editBox:SetPoint("CENTER", 25, 0) -- put it in the middle of the screen
        editBox:SetText(output) -- some text
        editBox:SetMultiLine(true)
        editBox:Show() -- when you want the user to see the editbox and copy from it
    end)

    -- -- button to hide the other button
    -- local b2 = CreateFrame("Button", "MyButton", wrapper, "UIPanelButtonTemplate")
    -- b2:SetSize(180,22) -- width, height
    -- b2:SetText("Hide Button")
    -- -- center is fine for now, but need to pin to auction house frame https://wowwiki-archive.fandom.com/wiki/API_Region_SetPoint
    -- b2:SetPoint("BOTTOM")
    -- b2:SetScript("OnClick", function()
    --     b:Hide()
    --     b2:Hide()
    --     editBox:Hide()
    --     wrapper:Hide()
    -- end)

    -- auto close buttons if auction house is closed
    b:RegisterEvent("AUCTION_HOUSE_CLOSED")
    b:SetScript("OnEvent", function()
        b:Hide()
        -- b2:Hide()
        editBox:Hide()
        wrapper:Hide()
    end)

end

-- easy button system
local function addonButton()
    local addonButton = CreateFrame("Button", "MyButton", UIParent, "UIPanelButtonTemplate")
    addonButton:SetSize(180,22) -- width, height
    addonButton:SetText("Open Saddlebag Exchange")
    -- center is fine for now, but need to pin to auction house frame https://wowwiki-archive.fandom.com/wiki/API_Region_SetPoint
    addonButton:SetPoint("CENTER", 0, 220)

    -- make moveable
    addonButton:SetMovable(true)
    addonButton:EnableMouse(true)
    addonButton:RegisterForDrag("LeftButton")
    addonButton:SetScript("OnDragStart", function(self, button)
        self:StartMoving()
        print("OnDragStart", button)
    end)
    addonButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        print("OnDragStop")
    end)

    -- open main window on click
    addonButton:SetScript("OnClick", function()
        auctionButton()
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
    addonButton()
end)
