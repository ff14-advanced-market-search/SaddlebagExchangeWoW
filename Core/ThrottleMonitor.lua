local _, Saddlebag = ...

--- Auction House throttle visibility (client-observed only; not Blizzard's internal budget).
local ThrottleMonitor = {}
Saddlebag.ThrottleMonitor = ThrottleMonitor

local db

local THROTTLE_EVENTS = {
    "AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED",
    "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT",
    "AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED",
    "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED",
    "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
}

local eventFrame
local ahStatusFrame
local pendingQueuedTimes = {}
local pendingSentTimes = {}

local state = {
    ahOpen = false,
    ready = true,
    systemReadyAt = 0,
    lastQueuedAt = 0,
    lastSentAt = 0,
    lastResponseAt = 0,
    lastDroppedAt = 0,
    notReadySince = nil,
    recentEvents = {},
    latencyQueueMs = {},
    latencyResponseMs = {},
    estimatedPressure = "ready",
    lastPressure = "ready",
    lastReadyValue = nil,
}

local session = {
    startedAt = nil,
    queued = 0,
    sent = 0,
    responses = 0,
    dropped = 0,
    queueDelaySum = 0,
    queueDelayN = 0,
    responseDelaySum = 0,
    responseDelayN = 0,
    maxQueueDelayMs = 0,
    maxResponseDelayMs = 0,
    pressureWorst = 1,
}

local PRESSURE_RANK = { ready = 1, waiting = 2, high = 3, blocked = 4 }

local function profile()
    return db and db.profile.throttleMonitor
end

local function statsRoot()
    if not db then
        return nil
    end
    db.global.throttleStats = db.global.throttleStats or {}
    db.global.throttleStats.realms = db.global.throttleStats.realms or {}
    db.global.throttleStats.characters = db.global.throttleStats.characters or {}
    return db.global.throttleStats
end

local function identityKeys()
    local regionKey = GetCurrentRegionName() or "Unknown"
    local realmKey = GetRealmName() or "Unknown"
    local charKey = UnitName("player") or "Unknown"
    local factionKey = UnitFactionGroup("player") or "Unknown"
    local fullKey = regionKey .. "|" .. realmKey .. "|" .. factionKey .. "|" .. charKey
    local realmOnlyKey = regionKey .. "|" .. realmKey
    return regionKey, realmKey, charKey, factionKey, fullKey, realmOnlyKey
end

local function now()
    return GetTime()
end

local function pushRecent(kind)
    local p = profile()
    if not p then
        return
    end
    local maxEv = p.maxRecentEvents or 50
    local t = now()
    table.insert(state.recentEvents, { t = t, kind = kind })
    while #state.recentEvents > maxEv do
        table.remove(state.recentEvents, 1)
    end
end

local function pruneLatencies(list, windowSec, maxSamples)
    local cutoff = now() - windowSec
    local i = 1
    while i <= #list do
        if list[i].t < cutoff then
            table.remove(list, i)
        else
            i = i + 1
        end
    end
    while #list > maxSamples do
        table.remove(list, 1)
    end
end

local function windowSeconds()
    local p = profile()
    return (p and p.sampleWindowSeconds) or 30
end

local function countRecentKind(kind)
    local w = windowSeconds()
    local cutoff = now() - w
    local n = 0
    for _, e in ipairs(state.recentEvents) do
        if e.t >= cutoff and e.kind == kind then
            n = n + 1
        end
    end
    return n
end

local function avgLatencies()
    local w = windowSeconds()
    local p = profile()
    local maxS = (p and p.maxLatencySamples) or 30
    pruneLatencies(state.latencyQueueMs, w * 2, maxS)
    pruneLatencies(state.latencyResponseMs, w * 2, maxS)
    local function avg(list)
        if #list == 0 then
            return nil
        end
        local sum = 0
        for _, v in ipairs(list) do
            sum = sum + v.ms
        end
        return sum / #list
    end
    return avg(state.latencyQueueMs), avg(state.latencyResponseMs)
end

local function pollReady()
    local ok, r = pcall(function()
        return C_AuctionHouse.IsThrottledMessageSystemReady()
    end)
    if not ok then
        return true
    end
    return r and true or false
end

local function updateReadyFromAPI()
    local r = pollReady()
    if state.lastReadyValue == nil then
        state.lastReadyValue = r
    elseif state.lastReadyValue ~= r then
        state.lastReadyValue = r
    end
    state.ready = r
    if r then
        state.notReadySince = nil
    elseif not state.notReadySince then
        state.notReadySince = now()
    end
end

local function recomputePressure()
    local w = windowSeconds()
    local dropped = countRecentKind("dropped")
    local queued = countRecentKind("queued")
    local avgQ, avgR = avgLatencies()
    updateReadyFromAPI()

    local notReadyAge = 0
    if state.notReadySince then
        notReadyAge = now() - state.notReadySince
    end

    local pressure = "ready"
    if dropped >= 3 or (dropped >= 1 and not state.ready and notReadyAge > 5) then
        pressure = "blocked"
    elseif dropped >= 1 or queued >= 10 or (avgQ and avgQ > 500) or (avgR and avgR > 1200) then
        pressure = "high"
    elseif not state.ready or queued >= 4 or (avgQ and avgQ > 150) then
        pressure = "waiting"
    end

    state.estimatedPressure = pressure
    if session.pressureWorst < (PRESSURE_RANK[pressure] or 1) then
        session.pressureWorst = PRESSURE_RANK[pressure] or 1
    end

    if pressure ~= state.lastPressure then
        Saddlebag.Debug.Log("Pressure state changed: %s -> %s", state.lastPressure, pressure)
        state.lastPressure = pressure
    end
end

local function pressurePeakName()
    for name, rank in pairs(PRESSURE_RANK) do
        if rank == session.pressureWorst then
            return name
        end
    end
    return "ready"
end

local function warnDropIfNeeded()
    local p = profile()
    if not p or not p.warnOnDrops then
        return
    end
    print("|cffffcc00Saddlebag:|r AH throttle: a throttled message was |cffff5555dropped|r (client observed). This usually means heavy AH traffic, not necessarily this addon.")
end

local function onThrottleEvent(_, event)
    local p = profile()
    if not db or not p or not p.enabled or not state.ahOpen then
        return
    end

    local t = now()
    if event == "AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED" then
        session.queued = session.queued + 1
        state.lastQueuedAt = t
        table.insert(pendingQueuedTimes, t)
        pushRecent("queued")
        Saddlebag.Debug.Log("Queued throttled message")
    elseif event == "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT" then
        session.sent = session.sent + 1
        state.lastSentAt = t
        local qT = table.remove(pendingQueuedTimes, 1)
        if qT then
            local ms = (t - qT) * 1000
            table.insert(state.latencyQueueMs, { t = t, ms = ms })
            session.queueDelaySum = session.queueDelaySum + ms
            session.queueDelayN = session.queueDelayN + 1
            if ms > session.maxQueueDelayMs then
                session.maxQueueDelayMs = ms
            end
            Saddlebag.Debug.Log("Sent throttled message after %.0fms queued delay", ms)
        else
            Saddlebag.Debug.Log("Sent throttled message")
        end
        table.insert(pendingSentTimes, t)
        pushRecent("sent")
    elseif event == "AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED" then
        session.responses = session.responses + 1
        state.lastResponseAt = t
        local sT = table.remove(pendingSentTimes, 1)
        if sT then
            local ms = (t - sT) * 1000
            table.insert(state.latencyResponseMs, { t = t, ms = ms })
            session.responseDelaySum = session.responseDelaySum + ms
            session.responseDelayN = session.responseDelayN + 1
            if ms > session.maxResponseDelayMs then
                session.maxResponseDelayMs = ms
            end
        end
        pushRecent("response")
    elseif event == "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED" then
        session.dropped = session.dropped + 1
        state.lastDroppedAt = t
        table.remove(pendingQueuedTimes, 1)
        table.remove(pendingSentTimes, 1)
        pushRecent("dropped")
        warnDropIfNeeded()
        Saddlebag.Debug.Log("Dropped throttled message")
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        state.ready = true
        state.systemReadyAt = t
        state.notReadySince = nil
        pushRecent("system_ready")
        Saddlebag.Debug.Log("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    end

    updateReadyFromAPI()
    recomputePressure()
    ThrottleMonitor._RefreshAHWidget()
end

local function registerThrottleEvents()
    if not eventFrame then
        return
    end
    for _, ev in ipairs(THROTTLE_EVENTS) do
        pcall(function()
            eventFrame:RegisterEvent(ev)
        end)
    end
end

local function unregisterThrottleEvents()
    if not eventFrame then
        return
    end
    for _, ev in ipairs(THROTTLE_EVENTS) do
        pcall(function()
            eventFrame:UnregisterEvent(ev)
        end)
    end
end

local function emptyEntryTemplate(regionKey, realmKey, factionKey, character)
    return {
        region = regionKey,
        realm = realmKey,
        faction = factionKey,
        character = character,
        totalSessions = 0,
        totalSamples = 0,
        totalQueued = 0,
        totalSent = 0,
        totalResponses = 0,
        totalDropped = 0,
        totalQueueDelayMs = 0,
        totalQueueSamples = 0,
        totalResponseDelayMs = 0,
        totalResponseSamples = 0,
        avgQueueDelayMs = 0,
        avgResponseDelayMs = 0,
        lastSeen = 0,
        recentSessions = {},
    }
end

local function mergeSessionIntoEntry(entry, summary)
    entry.totalSessions = (entry.totalSessions or 0) + 1
    entry.totalQueued = (entry.totalQueued or 0) + (summary.queued or 0)
    entry.totalSent = (entry.totalSent or 0) + (summary.sent or 0)
    entry.totalResponses = (entry.totalResponses or 0) + (summary.responses or 0)
    entry.totalDropped = (entry.totalDropped or 0) + (summary.dropped or 0)

    entry.totalQueueDelayMs = (entry.totalQueueDelayMs or 0) + (summary.queueDelaySum or 0)
    entry.totalQueueSamples = (entry.totalQueueSamples or 0) + (summary.queueDelayN or 0)
    entry.totalResponseDelayMs = (entry.totalResponseDelayMs or 0) + (summary.responseDelaySum or 0)
    entry.totalResponseSamples = (entry.totalResponseSamples or 0) + (summary.responseDelayN or 0)

    entry.avgQueueDelayMs = entry.totalQueueSamples > 0 and (entry.totalQueueDelayMs / entry.totalQueueSamples) or 0
    entry.avgResponseDelayMs = entry.totalResponseSamples > 0 and (entry.totalResponseDelayMs / entry.totalResponseSamples) or 0

    local samples = (summary.responseDelayN or 0) > 0 and summary.responseDelayN or (summary.responses or 0)
    entry.totalSamples = (entry.totalSamples or 0) + samples
    entry.lastSeen = summary.endedAt or time()

    if profile() and profile().persistHistory then
        entry.recentSessions = entry.recentSessions or {}
        table.insert(entry.recentSessions, 1, summary)
        local lim = profile().historyLimitPerCharacter or 200
        while #entry.recentSessions > lim do
            table.remove(entry.recentSessions)
        end
    end
end

local function buildSessionSummary()
    local ended = time()
    local started = session.startedAt or ended
    local avgQ = session.queueDelayN > 0 and (session.queueDelaySum / session.queueDelayN) or 0
    local avgR = session.responseDelayN > 0 and (session.responseDelaySum / session.responseDelayN) or 0
    local peak = pressurePeakName()
    return {
        startedAt = started,
        endedAt = ended,
        durationSeconds = math.max(0, ended - started),
        samples = session.responseDelayN > 0 and session.responseDelayN or session.responses,
        queued = session.queued,
        sent = session.sent,
        responses = session.responses,
        dropped = session.dropped,
        avgQueueDelayMs = avgQ,
        avgResponseDelayMs = avgR,
        maxQueueDelayMs = session.maxQueueDelayMs,
        maxResponseDelayMs = session.maxResponseDelayMs,
        pressurePeak = peak,
        queueDelayN = session.queueDelayN,
        responseDelayN = session.responseDelayN,
        queueDelaySum = session.queueDelaySum,
        responseDelaySum = session.responseDelaySum,
    }
end

local function persistSessionIfNeeded()
    local p = profile()
    if not p or not p.enabled or not p.persistHistory then
        return
    end
    local root = statsRoot()
    if not root then
        return
    end
    local regionKey, realmKey, _, factionKey, fullKey, realmOnlyKey = identityKeys()
    local summary = buildSessionSummary()
    if (summary.responses or 0) + (summary.queued or 0) < 1 and summary.durationSeconds < 5 then
        return
    end

    local charEntry = root.characters[fullKey] or emptyEntryTemplate(regionKey, realmKey, factionKey, UnitName("player") or "?")
    mergeSessionIntoEntry(charEntry, summary)
    root.characters[fullKey] = charEntry

    local realmEntry = root.realms[realmOnlyKey] or emptyEntryTemplate(regionKey, realmKey, factionKey, nil)
    realmEntry.character = nil
    mergeSessionIntoEntry(realmEntry, summary)
    root.realms[realmOnlyKey] = realmEntry
end

local function resetSessionCounters()
    session.startedAt = time()
    session.queued = 0
    session.sent = 0
    session.responses = 0
    session.dropped = 0
    session.queueDelaySum = 0
    session.queueDelayN = 0
    session.responseDelaySum = 0
    session.responseDelayN = 0
    session.maxQueueDelayMs = 0
    session.maxResponseDelayMs = 0
    session.pressureWorst = 1
    wipe(pendingQueuedTimes)
    wipe(pendingSentTimes)
end

function ThrottleMonitor.Initialize(database)
    db = database
    if not eventFrame then
        eventFrame = CreateFrame("Frame", "SaddlebagThrottleEventFrame", UIParent)
        eventFrame:SetScript("OnEvent", function(_, event)
            onThrottleEvent(_, event)
        end)
    end
end

function ThrottleMonitor.ResetSession()
    wipe(state.recentEvents)
    wipe(state.latencyQueueMs)
    wipe(state.latencyResponseMs)
    state.estimatedPressure = "ready"
    state.lastPressure = "ready"
    state.lastReadyValue = nil
    resetSessionCounters()
    if state.ahOpen then
        session.startedAt = time()
    end
    Saddlebag.Debug.Log("ThrottleMonitor session reset")
end

function ThrottleMonitor._RefreshAHWidget()
    if not ahStatusFrame or not ahStatusFrame.text then
        return
    end
    if not profile() or not profile().enabled or not profile().compactWidget then
        ahStatusFrame:Hide()
        return
    end
    if not state.ahOpen then
        ahStatusFrame:Hide()
        return
    end
    ahStatusFrame:Show()
    ahStatusFrame.text:SetText(ThrottleMonitor.GetSummaryText())
end

function ThrottleMonitor.EnsureAHWidget()
    local p = profile()
    if not p or not p.enabled or not p.compactWidget then
        return
    end
    if ahStatusFrame then
        return
    end
    local parent = AuctionHouseFrame or UIParent
    local f = CreateFrame("Frame", "SaddlebagThrottleAHStatus", parent)
    f:SetSize(220, 22)
    f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, -26)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    fs:SetJustifyH("RIGHT")
    fs:SetTextColor(0.9, 0.9, 0.7)
    f.text = fs
    f:SetScript("OnUpdate", function(self, elapsed)
        self._t = (self._t or 0) + elapsed
        if self._t >= 0.5 then
            self._t = 0
            if state.ahOpen and profile() and profile().enabled then
                updateReadyFromAPI()
                recomputePressure()
                ThrottleMonitor._RefreshAHWidget()
            end
        end
    end)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine("AH throttle (estimate)", 1, 1, 1)
        GameTooltip:AddLine(
            "Shows client-observed queueing and drops. Blizzard does not expose the exact AH action budget.",
            nil,
            nil,
            nil,
            true
        )
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)
    ahStatusFrame = f
end

function ThrottleMonitor.OnAuctionHouseShow()
    if not profile() or not profile().enabled then
        return
    end
    state.ahOpen = true
    resetSessionCounters()
    session.startedAt = time()
    updateReadyFromAPI()
    recomputePressure()
    ThrottleMonitor.EnsureAHWidget()
    registerThrottleEvents()
    ThrottleMonitor._RefreshAHWidget()
end

local function pruneOldHistory()
    local p = profile()
    local root = statsRoot()
    if not p or not root or not p.persistHistory then
        return
    end
    local days = p.realmComparisonWindowDays or 14
    local cutoff = time() - days * 86400
    local function pruneEntry(entry)
        if not entry or not entry.recentSessions then
            return
        end
        local i = 1
        while i <= #entry.recentSessions do
            local s = entry.recentSessions[i]
            if s.endedAt and s.endedAt < cutoff then
                table.remove(entry.recentSessions, i)
            else
                i = i + 1
            end
        end
    end
    for _, entry in pairs(root.characters) do
        pruneEntry(entry)
    end
    for _, entry in pairs(root.realms) do
        pruneEntry(entry)
    end
end

function ThrottleMonitor.OnAuctionHouseClosed()
    state.ahOpen = false
    unregisterThrottleEvents()
    if ahStatusFrame then
        ahStatusFrame:Hide()
    end
    persistSessionIfNeeded()
    pruneOldHistory()
end

function ThrottleMonitor.IsReady()
    if not state.ahOpen then
        return true
    end
    return pollReady()
end

function ThrottleMonitor.GetPressureState()
    recomputePressure()
    return state.estimatedPressure
end

function ThrottleMonitor.GetSnapshot()
    local w = windowSeconds()
    updateReadyFromAPI()
    recomputePressure()
    local avgQ, avgR = avgLatencies()
    local cq, cs, cr, cd = countRecentKind("queued"), countRecentKind("sent"), countRecentKind("response"), countRecentKind("dropped")
    return {
        ahOpen = state.ahOpen,
        ready = state.ready,
        apiReady = pollReady(),
        pressure = state.estimatedPressure,
        windowSeconds = w,
        queuedWindow = cq,
        sentWindow = cs,
        responseWindow = cr,
        droppedWindow = cd,
        avgQueueDelayMs = avgQ,
        avgResponseDelayMs = avgR,
        lastQueuedAt = state.lastQueuedAt,
        lastSentAt = state.lastSentAt,
        lastResponseAt = state.lastResponseAt,
        lastDroppedAt = state.lastDroppedAt,
        systemReadyAt = state.systemReadyAt,
        recentEventCount = #state.recentEvents,
    }
end

function ThrottleMonitor.GetSummaryText()
    local snap = ThrottleMonitor.GetSnapshot()
    local label
    if snap.pressure == "blocked" then
        label = "Blocked"
    elseif snap.pressure == "high" then
        label = "High Pressure"
    elseif snap.pressure == "waiting" then
        label = "Waiting"
    else
        label = "Ready"
    end
    return string.format("AH Throttle: %s", label)
end

function ThrottleMonitor.GetDebugDump()
    local snap = ThrottleMonitor.GetSnapshot()
    local lines = {
        "Saddlebag ThrottleMonitor (estimate only; not Blizzard budget)",
        string.format("pressure=%s apiReady=%s ahOpen=%s", tostring(snap.pressure), tostring(snap.apiReady), tostring(snap.ahOpen)),
        string.format("window=%ds queued=%d sent=%d resp=%d dropped=%d", snap.windowSeconds, snap.queuedWindow, snap.sentWindow, snap.responseWindow, snap.droppedWindow),
    }
    if snap.avgQueueDelayMs then
        lines[#lines + 1] = string.format("avgQueueDelayMs=%.1f", snap.avgQueueDelayMs)
    end
    if snap.avgResponseDelayMs then
        lines[#lines + 1] = string.format("avgResponseDelayMs=%.1f", snap.avgResponseDelayMs)
    end
    for i = math.max(1, #state.recentEvents - 15), #state.recentEvents do
        local e = state.recentEvents[i]
        if e then
            lines[#lines + 1] = string.format("event %s @ %.2f", e.kind, e.t)
        end
    end
    return table.concat(lines, "\n")
end

local MIN_SESSIONS_RATING = 3
local MIN_SAMPLES_RATING = 20

local function periodSeconds(period)
    if period == "7d" then
        return 7 * 86400
    elseif period == "14d" then
        return 14 * 86400
    end
    return nil
end

local function aggregateEntryOverPeriod(entry, period)
    if not entry then
        return nil
    end
    local maxAge = periodSeconds(period)
    if not maxAge or not entry.recentSessions or #entry.recentSessions == 0 then
        local dropRate = (entry.totalDropped or 0) / math.max((entry.totalSent or 0) + (entry.totalQueued or 0), 1)
        return {
            avgQueueDelayMs = entry.avgQueueDelayMs or 0,
            avgResponseDelayMs = entry.avgResponseDelayMs or 0,
            dropRate = dropRate,
            sessions = entry.totalSessions or 0,
            samples = entry.totalSamples or 0,
            lastSeen = entry.lastSeen or 0,
        }
    end
    local nowT = time()
    local qSum, qN, rSum, rN = 0, 0, 0, 0
    local dropped, queued, sent, responses, sess = 0, 0, 0, 0, 0
    for _, s in ipairs(entry.recentSessions) do
        if s.endedAt and (nowT - s.endedAt) <= maxAge then
            sess = sess + 1
            dropped = dropped + (s.dropped or 0)
            queued = queued + (s.queued or 0)
            sent = sent + (s.sent or 0)
            responses = responses + (s.responses or 0)
            if (s.queueDelayN or 0) > 0 then
                qSum = qSum + (s.avgQueueDelayMs or 0) * s.queueDelayN
                qN = qN + s.queueDelayN
            end
            if (s.responseDelayN or 0) > 0 then
                rSum = rSum + (s.avgResponseDelayMs or 0) * s.responseDelayN
                rN = rN + s.responseDelayN
            end
        end
    end
    if sess == 0 then
        return aggregateEntryOverPeriod(entry, "lifetime")
    end
    return {
        avgQueueDelayMs = qN > 0 and (qSum / qN) or 0,
        avgResponseDelayMs = rN > 0 and (rSum / rN) or 0,
        dropRate = dropped / math.max(sent + queued, 1),
        sessions = sess,
        samples = rN > 0 and rN or responses,
        lastSeen = entry.lastSeen or 0,
    }
end

local function ratingFromQuartile(value, q1, q2, q3)
    if not value or not q1 then
        return "—"
    end
    if value <= q1 then
        return "Fast"
    elseif value <= q2 then
        return "Normal"
    elseif value <= q3 then
        return "Slow"
    else
        return "Very Slow"
    end
end

function ThrottleMonitor.ComputeHistoryRows(filters)
    local root = statsRoot()
    if not root then
        return {}
    end
    local regionKey, realmKey, charKey, factionKey, fullKey, realmOnlyKey = identityKeys()
    filters = filters or {}
    local period = filters.period or "lifetime"
    local realmFilter = filters.realmFilter or "all"
    local charFilter = filters.charFilter or "all"

    local rows = {}

    for key, entry in pairs(root.realms) do
        if type(entry) == "table" then
            local include = realmFilter == "all" or key == realmOnlyKey
            if include and charFilter == "current" then
                include = key == realmOnlyKey
            end
            if include then
                local agg = aggregateEntryOverPeriod(entry, period)
                rows[#rows + 1] = {
                    kind = "realm",
                    key = key,
                    realm = entry.realm or "?",
                    character = "—",
                    agg = agg,
                }
            end
        end
    end

    for key, entry in pairs(root.characters) do
        if type(entry) == "table" then
            local include = true
            if realmFilter == "current" and entry.realm ~= realmKey then
                include = false
            end
            if charFilter == "current" and key ~= fullKey then
                include = false
            end
            if include then
                local agg = aggregateEntryOverPeriod(entry, period)
                rows[#rows + 1] = {
                    kind = "character",
                    key = key,
                    realm = entry.realm or "?",
                    character = entry.character or "?",
                    agg = agg,
                }
            end
        end
    end

    local vals = {}
    for _, row in ipairs(rows) do
        local a = row.agg
        if a and (a.sessions or 0) >= MIN_SESSIONS_RATING and (a.samples or 0) >= MIN_SAMPLES_RATING and (a.avgResponseDelayMs or 0) > 0 then
            vals[#vals + 1] = a.avgResponseDelayMs
        end
    end
    table.sort(vals)
    local function quartile(arr, q)
        if #arr == 0 then
            return nil
        end
        local idx = math.max(1, math.floor(#arr * q))
        return arr[idx]
    end
    local q1, q2, q3 = quartile(vals, 0.25), quartile(vals, 0.5), quartile(vals, 0.75)

    for _, row in ipairs(rows) do
        local a = row.agg
        local rating = "Insufficient data"
        if a and (a.sessions or 0) >= MIN_SESSIONS_RATING and (a.samples or 0) >= MIN_SAMPLES_RATING then
            rating = ratingFromQuartile(a.avgResponseDelayMs, q1, q2, q3)
        end
        row.rating = rating
    end

    return rows
end

function ThrottleMonitor.FormatHistoryTable(rows, sortKey)
    sortKey = sortKey or "avgResponseDelayMs"
    local desc = sortKey == "dropRate" or sortKey == "sessions" or sortKey == "samples" or sortKey == "lastSeen"
    table.sort(rows, function(a, b)
        local av = a.agg and a.agg[sortKey] or 0
        local bv = b.agg and b.agg[sortKey] or 0
        if desc then
            return av > bv
        end
        return av < bv
    end)

    local fmt = "%-14s %-16s %10s %10s %8s %8s %8s %12s"
    local out = {
        string.format(fmt, "Realm", "Character", "AvgQ(ms)", "AvgR(ms)", "Drop%", "Sess", "Samples", "Rating"),
        string.rep("-", 110),
    }
    for _, row in ipairs(rows) do
        local a = row.agg or {}
        local dropPct = math.floor((a.dropRate or 0) * 1000 + 0.5) / 10
        out[#out + 1] = string.format(
            fmt,
            (row.realm or ""):sub(1, 14),
            (row.character or ""):sub(1, 16),
            string.format("%.0f", a.avgQueueDelayMs or 0),
            string.format("%.0f", a.avgResponseDelayMs or 0),
            string.format("%.1f", dropPct),
            tostring(a.sessions or 0),
            tostring(a.samples or 0),
            (row.rating or "?"):sub(1, 12)
        )
    end
    out[#out + 1] = ""
    out[#out + 1] = "Observed client-side AH behavior only - not an official Blizzard budget."
    return table.concat(out, "\n")
end

function ThrottleMonitor.ResetAllStats()
    if not db then
        return
    end
    db.global.throttleStats = { realms = {}, characters = {} }
    Saddlebag.Debug.Log("Throttle history stats cleared")
end

function ThrottleMonitor.FlushOnLogout()
    if not state.ahOpen then
        return
    end
    persistSessionIfNeeded()
    pruneOldHistory()
end

function ThrottleMonitor.SetEnabled(on)
    if not profile() then
        return
    end
    profile().enabled = on and true or false
    if not profile().enabled then
        unregisterThrottleEvents()
        if ahStatusFrame then
            ahStatusFrame:Hide()
        end
    elseif state.ahOpen then
        registerThrottleEvents()
        ThrottleMonitor._RefreshAHWidget()
    end
end
