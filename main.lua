-- message('My first addon!')

SLASH_HELLOWORLD1, SLASH_HELLOWORLD2 = '/hiw', '/hellow';
local function handler(msg, editBox)
    if msg == 'help' then
        message('Go to the auction house, view your auctions and then run /hiw')
    else
        -- print("test")
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
            print("{}")
        end
    end
end
SlashCmdList["HELLOWORLD"] = handler; -- Also a valid assignment strategy