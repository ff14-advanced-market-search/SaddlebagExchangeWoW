-- message('Thanks for testing out Saddlebag Exchange WoW Undercut alerts! Use the commands: \n/sbex, /saddlebag or /saddlebagexchange')

SLASH_SADDLEBAG1, SLASH_SADDLEBAG2, SLASH_SADDLEBAG3 = '/sbex', '/saddlebag', '/saddlebagexchange';
local function handler(msg, editBox)
    if msg == 'help' then
        message('Go to the auction house, view your auctions and then click the pop up button or run /sbex')
    else
        ownedAuctions=C_AuctionHouse.GetOwnedAuctions();
        print("Found", table.maxn(ownedAuctions), "active auctions.")
        if (table.maxn(ownedAuctions) > 0)
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
            for k, v in pairs(ownedAuctions) do

                -- print('======')
                -- print("auction keys")
                -- for i, j in pairs(v) do
                --     print(i)
                -- end

                -- print('-----')
                -- print("itemKey info")
                -- for i, j in pairs(v["itemKey"]) do
                --     print(i)
                -- end
                -- print()
                -- print("itemID found!", v["itemKey"]["itemID"])
                -- print("price found!", v["buyoutAmount"])

                item_data = '\n        {"itemID": ' .. tostring(v["itemKey"]["itemID"]) .. ',"price": '.. tostring(v["buyoutAmount"]) .. '},'
                output = output .. item_data
            end
            output = output:sub(1, -2)
            output = output .. "\n    ]\n"
            output = output .. "}\n"
            print(output)
        else
            print("ERROR! Make sure you are at the auction house looking at your auctions before you click the button or run /sbex")
            print("{}")
        end
    end
end
SlashCmdList["SADDLEBAG"] = handler; -- Also a valid assignment strategy

-- easy button system
local function auctionButton()
    -- button for function
    local b = CreateFrame("Button", "MyButton", UIParent, "UIPanelButtonTemplate")
    b:SetSize(180,22) -- width, height
    b:SetText("Get Undercut Alert Data")
    -- center is fine for now, but need to pin to auction house frame https://wowwiki-archive.fandom.com/wiki/API_Region_SetPoint
    b:SetPoint("CENTER")
    b:SetScript("OnClick", function()
        handler()
        -- easy way to fix this is just close it after you get the data
        -- b:Hide()
    end)

    -- button to hide the other button
    local b2 = CreateFrame("Button", "MyButton", UIParent, "UIPanelButtonTemplate")
    b2:SetSize(180,22) -- width, height
    b2:SetText("Hide Button")
    -- center is fine for now, but need to pin to auction house frame https://wowwiki-archive.fandom.com/wiki/API_Region_SetPoint
    b2:SetPoint("CENTER", 0, -25)
    b2:SetScript("OnClick", function()
        b:Hide()
        b2:Hide()
    end)

    -- auto close buttons if auction house is closed
    b:RegisterEvent("AUCTION_HOUSE_CLOSED")
    b:SetScript("OnEvent", function()
        b:Hide()
        b2:Hide()
    end)

end

-- https://wowwiki-archive.fandom.com/wiki/Events/Names
local buttonPopUpFrame = CreateFrame("Frame")
buttonPopUpFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
buttonPopUpFrame:SetScript("OnEvent", function()
    auctionButton()
end)
