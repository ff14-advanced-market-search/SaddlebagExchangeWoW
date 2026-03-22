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
    for _, value in pairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

local function get_index(tab, val)
    for index, value in pairs(tab) do
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
        global = {
            throttleStats = {
                realms = {},
                characters = {},
            },
        },
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
            throttleMonitor = {
                enabled = true,
                compactWidget = true,
                showDebugDetails = false,
                sampleWindowSeconds = 30,
                maxRecentEvents = 50,
                maxLatencySamples = 30,
                warnOnDrops = true,
                persistHistory = true,
                historyLimitPerCharacter = 200,
                realmComparisonWindowDays = 14,
            },
        },
    })
    -- LibDBIcon:Register("Saddlebag Exchange", SaddlebagLDB, self.db.profile.minimap)
    -- Saddlebag:UpdateMinimapButton()

    do
        local tmDefaults = {
            enabled = true,
            compactWidget = true,
            showDebugDetails = false,
            sampleWindowSeconds = 30,
            maxRecentEvents = 50,
            maxLatencySamples = 30,
            warnOnDrops = true,
            persistHistory = true,
            historyLimitPerCharacter = 200,
            realmComparisonWindowDays = 14,
        }
        local tm = self.db.profile.throttleMonitor or {}
        for k, v in pairs(tmDefaults) do
            if tm[k] == nil then
                tm[k] = v
            end
        end
        self.db.profile.throttleMonitor = tm
    end
    self.db.global.throttleStats = self.db.global.throttleStats or { realms = {}, characters = {} }
    self.db.global.throttleStats.realms = self.db.global.throttleStats.realms or {}
    self.db.global.throttleStats.characters = self.db.global.throttleStats.characters or {}
    Saddlebag.ThrottleMonitor.Initialize(self.db)
    self.throttleHistoryRealmFilter = self.throttleHistoryRealmFilter or "all"
    self.throttleHistoryCharFilter = self.throttleHistoryCharFilter or "all"
    self.throttleHistoryPeriod = self.throttleHistoryPeriod or "lifetime"
    self.throttleHistorySortKey = self.throttleHistorySortKey or "avgResponseDelayMs"
    Saddlebag:RegisterChatCommand('sbex', 'HandleChatCommand')
end

local function strtrim(s)
    if not s then
        return ""
    end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function Saddlebag:HandleThrottleCommand(rest)
    rest = strtrim(rest or "")
    local sub = rest:match("^(%S+)") or ""
    local tm = Saddlebag.ThrottleMonitor
    local p = self.db.profile.throttleMonitor

    if sub == "" or sub == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/sbex throttle|r on | off | debug | reset | history | compare | realm | resetstats")
        return
    end

    if sub == "off" then
        tm.SetEnabled(false)
        DEFAULT_CHAT_FRAME:AddMessage("Saddlebag: AH throttle monitor disabled.")
        return
    end
    if sub == "on" then
        tm.SetEnabled(true)
        DEFAULT_CHAT_FRAME:AddMessage("Saddlebag: AH throttle monitor enabled.")
        return
    end
    if sub == "debug" then
        Saddlebag.Debug.Log("%s", tm.GetDebugDump())
        DEFAULT_CHAT_FRAME:AddMessage("Saddlebag: throttle debug sent to SBDebug chat (if configured).")
        return
    end
    if sub == "reset" then
        tm.ResetSession()
        DEFAULT_CHAT_FRAME:AddMessage("Saddlebag: current AH throttle session counters reset.")
        return
    end
    if sub == "resetstats" then
        tm.ResetAllStats()
        DEFAULT_CHAT_FRAME:AddMessage("Saddlebag: saved AH speed history cleared.")
        return
    end
    if sub == "history" or sub == "compare" or sub == "realm" then
        self.throttlePendingTab = "history"
        if sub == "realm" then
            self.throttleHistoryRealmFilter = "current"
            self.throttleHistoryCharFilter = "all"
        else
            self.throttleHistoryRealmFilter = self.throttleHistoryRealmFilter or "all"
            self.throttleHistoryCharFilter = self.throttleHistoryCharFilter or "all"
        end
        self.throttleHistorySortKey = (sub == "compare") and "avgResponseDelayMs" or (self.throttleHistorySortKey or "avgResponseDelayMs")
        self:showall()
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("Saddlebag: unknown throttle subcommand. Try |cffffcc00/sbex throttle help|r")
end

function Saddlebag:HandleChatCommand(input)
    input = strtrim(input or "")
    if input == "throttle" or input:match("^throttle%s+") then
        local rest = input:match("^throttle%s*(.*)$") or ""
        self:HandleThrottleCommand(rest)
        return
    end

    local args = { strsplit(" ", input) }

    for _, arg in pairs(args) do
        if arg == "help" then
            DEFAULT_CHAT_FRAME:AddMessage("Saddlebag: |cffffcc00/sbex|r open window  |  |cffffcc00/sbex throttle ...|r AH throttle tools")
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
    if Saddlebag.sf then
        Saddlebag.sf:SetText("")
    end
    Saddlebag.Debug.Log("Your auctions table has been cleared out.")
end

function Saddlebag:tableLength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function Saddlebag:SetupMultiSelect(multiSelect, auctions)
    Saddlebag.Debug.Log("Setting up multiSelect with auctions "..Saddlebag:tableLength(auctions))
    for _, item in pairs(auctions) do
        local itemName, _, _, _, _, _, _, _ = GetItemInfo(item["itemKey"]["itemID"])
        Saddlebag.Debug.Log("Adding item "..itemName)
        multiSelect:AddItem(itemName)
    end
end

function Saddlebag:GetCleanAuctions()
    local ownedAuctions = C_AuctionHouse.GetOwnedAuctions();
    Saddlebag.Debug.Log("Found "..Saddlebag:tableLength(ownedAuctions).." auctions.")

    -- find active auctions
    local active_auctions = 0
    for k, v in pairs(ownedAuctions) do
        if v["status"] == 0 then
            active_auctions = active_auctions + 1
        end
    end
    Saddlebag.Debug.Log("Found "..tostring(active_auctions).." active auctions.")

    -- delete duplicate entries
    local seen = {}
    local clean_ownedAuctions = {}
    for index, item in pairs(ownedAuctions) do
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
                    seen[kv_str] = true
                    clean_ownedAuctions[index] = item
                end
            end
        end
    end

    Saddlebag.Debug.Log("Found "..Saddlebag:tableLength(clean_ownedAuctions).." unique auctions.")
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
                if v["itemKey"]["battlePetSpeciesID"] == 0 then
                    item_data.itemID = v["itemKey"]["itemID"]
                else
                    item_data.petID = v["itemKey"]["battlePetSpeciesID"]
                end
                item_data.price = v["buyoutAmount"]
                item_data.auctionID = v["auctionID"]
                storage.user_auctions[count] = item_data
                count = count + 1
            end
        end
        -- add to saved variable
        UndercutJsonTable[playerName] = storage
        return dkjson.json.encode(storage, { indent = true })
    else
        Saddlebag.Debug.Log("ERROR! Make sure you are at the auction house looking at your auctions before you click the button or run /sbex")
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

function Saddlebag:BuildUndercutTab(container, text)
    local mainGroup = AceGUI:Create("SimpleGroup")
    mainGroup:SetLayout("List")
    mainGroup:SetFullWidth(true)
    mainGroup:SetFullHeight(true)
    container:AddChild(mainGroup)

    local itemsGroup = AceGUI:Create("SimpleGroup")
    itemsGroup:SetLayout("Flow")
    itemsGroup:SetFullWidth(true)
    itemsGroup:SetFullHeight(true)
    mainGroup:AddChild(itemsGroup)

    local li = AceGUI:Create("MultiSelect")
    itemsGroup:AddChild(li)
    li:SetLabel("My listed auctions")
    li:SetMultiSelect(false)
    li:SetHeight(175)
    li:SetFullWidth(false)
    li:SetRelativeWidth(0.45)

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

    local ei = AceGUI:Create("MultiSelect")
    itemsGroup:AddChild(ei)
    ei:SetLabel("My excluded auctions")
    ei:SetMultiSelect(false)
    ei:SetHeight(175)
    ei:SetFullWidth(false)
    ei:SetRelativeWidth(0.45)

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
    sf:SetText(text or "")
    sf:HighlightText()
    Saddlebag.sf = sf

    Saddlebag:SetupMultiSelect(li, Saddlebag:GetCleanAuctions())
    li:SetCallback("OnLabelClick", function(_, _, value)
        Saddlebag.Debug.Log("You clicked on the item " .. li:GetText(value))
        ei:AddItem(li:GetText(value))
        table.insert(private.ignoredAuctions, private.auctions[get_index(private.itemNames, li:GetText(value))])
        li:RemoveItem(value)
        sf:SetText(Saddlebag:GetUpdatedListingsJson())
        li:Sort()
        ei:Sort()
    end)
    ei:SetCallback("OnLabelClick", function(_, _, value)
        Saddlebag.Debug.Log("You clicked on the item " .. ei:GetText(value))
        li:AddItem(ei:GetText(value))
        table.remove(private.ignoredAuctions, get_index(private.ignoredAuctions, private.auctions[get_index(private.itemNames, ei:GetText(value))]))
        ei:RemoveItem(value)
        sf:SetText(Saddlebag:GetUpdatedListingsJson())
        li:Sort()
        ei:Sort()
    end)
end

function Saddlebag:RefreshThrottleHistoryOutput()
    if not self.throttleHistoryOutput then
        return
    end
    local tm = Saddlebag.ThrottleMonitor
    local rows = tm.ComputeHistoryRows({
        period = self.throttleHistoryPeriod or "lifetime",
        realmFilter = self.throttleHistoryRealmFilter or "all",
        charFilter = self.throttleHistoryCharFilter or "all",
    })
    self.throttleHistoryOutput:SetText(tm.FormatHistoryTable(rows, self.throttleHistorySortKey or "avgResponseDelayMs"))
end

function Saddlebag:BuildHistoryTab(container)
    local tm = Saddlebag.ThrottleMonitor
    local p = self.db.profile.throttleMonitor

    local head = AceGUI:Create("Label")
    head:SetFullWidth(true)
    head:SetText(
        "|cffffcc00Auction House Speed History|r\n"
            .. "Observed AH responsiveness by realm and character (client-side only; not Blizzard's internal budget)."
    )
    container:AddChild(head)

    local live = AceGUI:Create("Label")
    live:SetFullWidth(true)
    local snap = tm.GetSnapshot()
    local liveText = string.format(
        "Live (this session): %s | Ready now: %s | Queued (%ds): %d | Dropped: %d | Avg queue→send: %s | Avg send→response: %s",
        snap.pressure or "?",
        snap.apiReady and "Yes" or "No",
        snap.windowSeconds or 30,
        snap.queuedWindow or 0,
        snap.droppedWindow or 0,
        snap.avgQueueDelayMs and string.format("%.0f ms", snap.avgQueueDelayMs) or "—",
        snap.avgResponseDelayMs and string.format("%.0f ms", snap.avgResponseDelayMs) or "—"
    )
    if p.showDebugDetails then
        liveText = liveText .. "\n" .. tm.GetDebugDump()
    end
    live:SetText(liveText)
    container:AddChild(live)

    local flow = AceGUI:Create("SimpleGroup")
    flow:SetLayout("Flow")
    flow:SetFullWidth(true)
    container:AddChild(flow)

    local function addDropdown(label, w, list, current, setter)
        local dd = AceGUI:Create("Dropdown")
        dd:SetLabel(label)
        dd:SetList(list)
        dd:SetWidth(w)
        dd:SetValue(current)
        dd:SetCallback("OnValueChanged", function(_, _, val)
            setter(val)
            Saddlebag:RefreshThrottleHistoryOutput()
        end)
        flow:AddChild(dd)
    end

    addDropdown("Realm", 160, {
        all = "All realms",
        current = "Current realm",
    }, self.throttleHistoryRealmFilter or "all", function(v)
        self.throttleHistoryRealmFilter = v
    end)

    addDropdown("Character", 160, {
        all = "All characters",
        current = "Current character",
    }, self.throttleHistoryCharFilter or "all", function(v)
        self.throttleHistoryCharFilter = v
    end)

    addDropdown("Period", 140, {
        lifetime = "Lifetime",
        ["7d"] = "Last 7 days",
        ["14d"] = "Last 14 days",
    }, self.throttleHistoryPeriod or "lifetime", function(v)
        self.throttleHistoryPeriod = v
    end)

    addDropdown("Sort by", 200, {
        avgResponseDelayMs = "Avg response delay",
        avgQueueDelayMs = "Avg queue delay",
        dropRate = "Drop rate",
        sessions = "Sessions",
        samples = "Samples",
        lastSeen = "Last seen",
    }, self.throttleHistorySortKey or "avgResponseDelayMs", function(v)
        self.throttleHistorySortKey = v
    end)

    local foot = AceGUI:Create("Label")
    foot:SetFullWidth(true)
    foot:SetText('Estimate only. Low sample counts are labeled "Insufficient data".')
    container:AddChild(foot)

    local out = AceGUI:Create("MultiLineEditBox")
    out:SetLabel("Comparison table (copy for reports)")
    out:SetMaxLetters(0)
    out:SetNumLines(16)
    out:SetHeight(220)
    out:DisableButton(true)
    out:SetFullWidth(true)
    container:AddChild(out)
    self.throttleHistoryOutput = out
    self:RefreshThrottleHistoryOutput()
end

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
        Saddlebag:SetEscapeHandler(f, function() Saddlebag:auctionButton(""):Hide() end)

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

        local initialJson = text or ""
        local tabGroup = AceGUI:Create("TabGroup")
        tabGroup:SetLayout("Fill")
        tabGroup:SetFullWidth(true)
        tabGroup:SetFullHeight(true)
        tabGroup:SetTabs({
            { text = "Undercut Data", value = "undercut" },
            { text = "AH Speed History", value = "history" },
        })
        tabGroup:SetCallback("OnGroupSelected", function(widget, _, group)
            if Saddlebag._lastMainTab == "undercut" and Saddlebag.sf then
                tabGroup._undercutJsonStash = Saddlebag.sf:GetText()
            end
            widget:ReleaseChildren()
            if group == "undercut" then
                Saddlebag:BuildUndercutTab(widget, tabGroup._undercutJsonStash or initialJson)
            elseif group == "history" then
                Saddlebag:BuildHistoryTab(widget)
            end
            Saddlebag._lastMainTab = group
        end)
        f:AddChild(tabGroup)
        Saddlebag.throttleTabGroup = tabGroup

        tabGroup:SelectTab("undercut")
        if self.throttlePendingTab == "history" then
            tabGroup:SelectTab("history")
        end
        self.throttlePendingTab = nil

        SaddlebagFrame = f
    elseif self.throttlePendingTab == "history" and self.throttleTabGroup then
        self.throttleTabGroup:SelectTab("history")
        self.throttlePendingTab = nil
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
        Saddlebag.Debug.Log("OnDragStart", button)
    end)
    addonButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Saddlebag.Debug.Log("OnDragStop")
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
        Saddlebag.Debug.Log("OnDragStart", button)
    end)
    addonButton2:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Saddlebag.Debug.Log("OnDragStop")
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
        Saddlebag.Debug.Log("OnDragStart", button)
    end)
    addonButton3:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Saddlebag.Debug.Log("OnDragStop")
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
buttonPopUpFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
buttonPopUpFrame:SetScript("OnEvent", function(_, ev)
    if ev == "AUCTION_HOUSE_SHOW" then
        Saddlebag:addonButton()
        Saddlebag:addonButton2()
        Saddlebag:addonButton3()
        Saddlebag.ThrottleMonitor.OnAuctionHouseShow()
    elseif ev == "AUCTION_HOUSE_CLOSED" then
        Saddlebag.ThrottleMonitor.OnAuctionHouseClosed()
    end
end)

local buttonPopUpFrame2 = CreateFrame("Frame")
buttonPopUpFrame2:RegisterEvent("OWNED_AUCTIONS_UPDATED")
buttonPopUpFrame2:SetScript("OnEvent", function()
    Saddlebag:GetUpdatedListingsJson()
end)

local logoutFlushFrame = CreateFrame("Frame")
logoutFlushFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFlushFrame:SetScript("OnEvent", function()
    Saddlebag.ThrottleMonitor.FlushOnLogout()
end)

----------------------------------------------------------------------------------
-- AceGUI hacks --

-- hack to hook the escape key for closing the window
function Saddlebag:SetEscapeHandler(widget, fn)
	widget.origOnKeyDown = widget.frame:GetScript("OnKeyDown")
	widget.frame:SetScript("OnKeyDown", function(self, key)
		widget.frame:SetPropagateKeyboardInput(true)
		if key == "ESCAPE" then
			widget.frame:SetPropagateKeyboardInput(false)
			fn()
		elseif widget.origOnKeyDown then
			widget.origOnKeyDown(self, key)
		end
	end)
	widget.frame:EnableKeyboard(true)
	widget.frame:SetPropagateKeyboardInput(true)
end