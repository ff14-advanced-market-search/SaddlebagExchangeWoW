-- Now on Curseforge!

-- message('Thanks for testing out Saddlebag Exchange WoW Undercut alerts! Use the commands: \n/sbex, /Saddlebag or /Saddlebagexchange')
local _, Saddlebag = ...
local addonName = "Saddlebag Exchange Undercut Alerts"

Saddlebag = LibStub("AceAddon-3.0"):NewAddon(Saddlebag, "Saddlebag", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")
LibRealmInfo = LibStub("LibRealmInfo")
local dkjson = LibStub("dkjson")

local SaddlebagFrame = nil
local private = {
    itemNames = {},
    auctions = {},
    ignoredAuctions = {},
}

local function has_value(tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

local function get_index(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return index
        end
    end

    return nil
end

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
                height = 500,
            },
        },
    });
    -- LibDBIcon:Register("Saddlebag Exchange", SaddlebagLDB, self.db.profile.minimap)
    -- Saddlebag:UpdateMinimapButton()

    Saddlebag:RegisterChatCommand('sbex', 'HandleChatCommand')
end

function Saddlebag:HandleChatCommand(input)
    local args = { strsplit(' ', input) }

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

function Saddlebag:showall()
    local output = ""
    if (UndercutJsonTable == nil)
    then
        output = output .. "[]"
    else
        output = output .. "["
        for _, v in pairs(UndercutJsonTable) do
            output = output .. dkjson.json.encode(v, { indent = true }) .. ","
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

    local af = Saddlebag:auctionButton("")
    Saddlebag.sf:SetText(output)
    af:Show()
end

function Saddlebag:clear(msg, SaddlebagEditBox)
    UndercutJsonTable = {}
    Saddlebag.sf:SetText("")
    print("Your auctions table has been cleared out.")
end

function Saddlebag:tableLength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function Saddlebag:SetupMultiSelect(multiSelect, auctions)
    -- print("Setting up multiSelect with auctions "..Saddlebag:tableLength(auctions))
    for _, item in ipairs(auctions) do
        local itemName, _, _, _, _, _, _, _ = GetItemInfo(item["itemKey"]["itemID"])
        -- print("Adding item "..itemName)
        multiSelect:AddItem(itemName)
    end
end

function Saddlebag:GetCleanAuctions()
    local ownedAuctions = C_AuctionHouse.GetOwnedAuctions();
    print("Found", Saddlebag:tableLength(ownedAuctions), "auctions.")

    -- find active auctions
    local active_auctions = 0
    for k, v in pairs(ownedAuctions) do
        if v["status"] == 0 then
            active_auctions = active_auctions + 1
        end
    end
    print("Found", tostring(active_auctions), "active auctions.")

    -- delete duplicate entries
    local seen = {}
    local clean_ownedAuctions = {}
    for index, item in ipairs(ownedAuctions) do
        -- skip sold auctions
        if item["status"] == 0 then
            local kv_str = tostring(item["itemKey"]["itemID"]) .. "_" .. tostring(item["buyoutAmount"])
            local itemName, _, _, _, _, _, _, itemStackCount = GetItemInfo(item["itemKey"]["itemID"])
            private.auctions[index] = item["auctionID"]
            private.itemNames[index] = itemName
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

    return clean_ownedAuctions
end

function Saddlebag:GetUpdatedListingsJson()
    local clean_ownedAuctions = Saddlebag:GetCleanAuctions()

    -- used as key in the table
    local playerName = UnitName("player") .. tostring(GetRealmID())
    if (UndercutJsonTable == nil)
    then
        UndercutJsonTable = {}
    end

    -- get undercut if active auctions found
    local storage = {}
    if (Saddlebag:tableLength(clean_ownedAuctions) > 0)
    then
        storage.homeRealmName = GetRealmID()
        storage.region = GetCurrentRegionName()
        storage.user_auctions = {}

        local count = 1
        for _, v in pairs(clean_ownedAuctions) do
            if (not has_value(private.ignoredAuctions, v["auctionID"]))
            then
                local item_data = {}
                item_data.itemID = v["itemKey"]["itemID"]
                item_data.price = v["buyoutAmount"]
                item_data.auctionID = v["auctionID"]
                storage.user_auctions[count] = item_data
            elseif (v["status"] == 0) and (v["itemKey"]["itemID"] == 82800)
            then
                local item_data = {}
                item_data.petID = v["itemKey"]["battlePetSpeciesID"]
                item_data.price = v["buyoutAmount"]
                item_data.auctionID = v["auctionID"]
                storage.user_auctions[count] = item_data
            end
            count = count + 1
        end
        -- add to saved variable
        UndercutJsonTable[playerName] = storage
        -- print(output)
        return dkjson.json.encode(storage, { indent = true })
    else
        print("ERROR! Make sure you are at the auction house looking at your auctions before you click the button or run /sbex")
        return "{}"
    end
end

function Saddlebag:handler(msg, SaddlebagEditBox)
    if msg == 'help'
    then
        message('Go to the auction house, view your auctions and then click the pop up button or run /sbex')
    else
        local af = Saddlebag:auctionButton("")
        Saddlebag.sf:SetText(Saddlebag:GetUpdatedListingsJson())
        af:Show()
    end
end

SlashCmdList["SADDLEBAG"] = handler; -- Also a valid assignment strategy

-- easy button system
function Saddlebag:auctionButton(text)
    if not SaddlebagFrame then
        -- MainFrame
        local frameConfig = self.db.profile.frame

        local f = AceGUI:Create("Frame")
        f:ClearAllPoints()
        f.frame:SetFrameStrata("MEDIUM")
        f.frame:Raise()
        f.content:SetFrameStrata("MEDIUM")
        f.content:Raise()
        f:Hide()
        f:SetTitle(addonName)
        f:SetLayout("Fill")
        f.frame:SetClampedToScreen(true)
        f:SetWidth(frameConfig.width)
        f:SetHeight(frameConfig.height)
        f:SetAutoAdjustHeight(true)

        -- load position from local DB
        f:SetPoint(
            frameConfig.point,
            frameConfig.relativeFrame,
            frameConfig.relativePoint,
            frameConfig.ofsx,
            frameConfig.ofsy
        )
        f:SetCallback("OnMouseDown", function(self, button) -- luacheck: ignore
            if button == "LeftButton" then
                self:StartMoving()
            end
        end)
        f:SetCallback("OnMouseUp", function(self, _) --luacheck: ignore
            self:StopMovingOrSizing()
            -- save position between sessions
            local point, relativeFrame, relativeTo, ofsx, ofsy = self:GetPoint()
            frameConfig.point = point
            frameConfig.relativeFrame = relativeFrame
            frameConfig.relativePoint = relativeTo
            frameConfig.ofsx = ofsx
            frameConfig.ofsy = ofsy
        end)

        local mainGroup = AceGUI:Create("SimpleGroup")
        mainGroup:SetLayout("List")
        mainGroup:SetFullWidth(true)
        mainGroup:SetFullHeight(true)
        f:AddChild(mainGroup)

        local itemsGroup = AceGUI:Create("SimpleGroup")
        itemsGroup:SetLayout("Flow")
        itemsGroup:SetFullWidth(true)
        itemsGroup:SetFullHeight(true)
        mainGroup:AddChild(itemsGroup)

        -- listed items
        local li = AceGUI:Create("MultiSelect")
        itemsGroup:AddChild(li)
        li:SetLabel("My listed auctions")
        li:SetMultiSelect(false)
        li:SetHeight(175)
        li:SetFullWidth(false)
        li:SetRelativeWidth(0.45)

        -- labels
        local labelGroup = AceGUI:Create("SimpleGroup")
        labelGroup:SetLayout("List")
        labelGroup:SetRelativeWidth(0.1)
        itemsGroup:AddChild(labelGroup)

        local addLabel = AceGUI:Create("Label")
        addLabel:SetText(">")
        labelGroup:AddChild(addLabel)

        local removeLabel = AceGUI:Create("Label")
        removeLabel:SetText("<")
        labelGroup:AddChild(removeLabel)

        -- exluded items
        local ei = AceGUI:Create("MultiSelect")
        itemsGroup:AddChild(ei)
        ei:SetLabel("My excluded auctions")
        ei:SetMultiSelect(false)
        ei:SetHeight(175)
        ei:SetFullWidth(false)
        ei:SetRelativeWidth(0.45)

        -- result group
        local resultGroup = AceGUI:Create("SimpleGroup")
        resultGroup:SetLayout("Flow")
        resultGroup:SetFullWidth(true)
        resultGroup:SetFullHeight(true)
        mainGroup:AddChild(resultGroup)

        local sf = AceGUI:Create("MultiLineEditBox")
        resultGroup:AddChild(sf)
        sf:SetLabel("Saddlebag exchange undercut alert JSON")
        sf:SetMaxLetters(0)
        sf:SetNumLines(15)
        sf:SetHeight(150)
        sf:DisableButton(true)
        sf:SetFullWidth(true)
        sf:SetText(text)
        sf:HighlightText()
        Saddlebag.sf = sf

        -- setup and callbacks
        Saddlebag:SetupMultiSelect(li, Saddlebag:GetCleanAuctions())
        li:SetCallback("OnLabelClick", function(widget, event, value)
            -- print("You clicked on the item " .. li:GetText(value))
            ei:AddItem(li:GetText(value))
            table.insert(private.ignoredAuctions, private.auctions[get_index(private.itemNames, li:GetText(value))])
            li:RemoveItem(value)
            sf:SetText(Saddlebag:GetUpdatedListingsJson())
            li:Sort()
            ei:Sort()
        end)
        ei:SetCallback("OnLabelClick", function(widget, event, value)
            -- print("You clicked on the item " .. ei:GetText(value))
            li:AddItem(ei:GetText(value))
            table.remove(private.ignoredAuctions, get_index(private.ignoredAuctions, private.auctions[get_index(private.itemNames, ei:GetText(value))]))
            ei:RemoveItem(value)
            sf:SetText(Saddlebag:GetUpdatedListingsJson())
            li:Sort()
            ei:Sort()
        end)

        SaddlebagFrame = f
    end
    return SaddlebagFrame
end

-- easy button system
function Saddlebag:addonButton()
    local addonButton = CreateFrame("Button", "MyButton", UIParent, "UIPanelButtonTemplate")
    addonButton:SetFrameStrata("HIGH")
    addonButton:SetSize(180, 22) -- width, height
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
    addonButton2:SetSize(180, 22) -- width, height
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
    addonButton3:SetSize(120, 22) -- width, height
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

local buttonPopUpFrame2 = CreateFrame("Frame")
buttonPopUpFrame2:RegisterEvent("OWNED_AUCTIONS_UPDATED")
buttonPopUpFrame2:SetScript("OnEvent", function()
    Saddlebag:GetUpdatedListingsJson()
end)
