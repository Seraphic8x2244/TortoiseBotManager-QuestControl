-- QuestControl: quest messages, hand-in state and reward UI for Vanilla WoW 1.12.1 (Lua 5.0.3).
TortoiseBotQuestControl = TortoiseBotQuestControl or {}
local QC = TortoiseBotQuestControl

QC.ADDON_NAME = "TortoiseBotManager-QuestControl"
QC.version = GetAddOnMetadata(QC.ADDON_NAME, "Version")

local CHANNELS = {
    CHAT_MSG_PARTY = true,
    CHAT_MSG_RAID = true,
    CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_WHISPER = true,
}

-- These markers represent links ONLY during matching; original links remain intact.
local QUEST = "\001Q\002"
local ITEM = "\001I\002"

local function linksInMessage(message)
    local links, parts = {}, {}
    local cursor = 1
    while true do
        local first, headerEnd, linkType, id =
            string.find(message, "|H([%a]+):(%d+)[^|]*|h", cursor)
        if not first then break end

        local closeStart, closeEnd = string.find(message, "|h", headerEnd + 1, true)
        if not closeStart then break end

        local linkStart, linkEnd = first, closeEnd
        local colorStart = first - 10
        if colorStart >= cursor and string.find(
            string.sub(message, colorStart, first - 1),
            "^|c%x%x%x%x%x%x%x%x$"
        ) then
            linkStart = colorStart
            if string.sub(message, linkEnd + 1, linkEnd + 2) == "|r" then
                linkEnd = linkEnd + 2
            end
        end

        table.insert(parts, string.sub(message, cursor, linkStart - 1))
        local link = string.sub(message, linkStart, linkEnd)
        local title = string.sub(message, headerEnd + 1, closeStart - 1)
        if linkType == "quest" or linkType == "item" then
            local data = { id = tonumber(id), link = link, name = title }
            table.insert(links, { kind = linkType, data = data })
            table.insert(parts, linkType == "quest" and QUEST or ITEM)
        else
            table.insert(parts, link)
        end
        cursor = linkEnd + 1
    end
    table.insert(parts, string.sub(message, cursor))
    return table.concat(parts), links
end

-- Exact English templates from TortoiseBots' ai_playerbot_texts world SQL.
-- A linked quest is required for every quest-specific template, rather than
-- accepting lookalike ordinary chat containing only quest-like words.
local FORMATS = {
    { "turned_in_reward", "^I have completed the quest " .. QUEST .. " and received " .. ITEM .. "$" },
    { "turned_in", "^I have completed the quest " .. QUEST .. "$" },
    { "unable_to_turn_in", "^I am unable to turn in the quest " .. QUEST .. "$" },
    { "incomplete", "^I have not completed the quest " .. QUEST .. "$" },
    { "available", "^Quest " .. QUEST .. " available$" },
    { "accepted", "^I have accepted " .. QUEST .. "$" },
    { "already_have", "^I already have " .. QUEST .. "$" },
    { "already_completed", "^I have already completed " .. QUEST .. "$" },
    { "cannot_take_log_full", "^I can't take " .. QUEST .. " because my quest log is full$" },
    { "cannot_take_bag_full", "^I can't take " .. QUEST .. " because my bag is full$" },
    { "cannot_take", "^I can't take " .. QUEST .. "$" },
    { "failed", "^I have failed the quest " .. QUEST .. "$" },
    { "objectives_completed", "^Completed " .. QUEST .. "$" },
}

local GENERIC = {
    ["Quest accepted"] = "accepted_generic",
    ["Quest removed"] = "removed_generic",
    ["I can't take this quest"] = "cannot_take_generic",
    ["I can't talk with the quest giver"] = "cannot_talk_to_giver",
}

local function classify(message)
    if type(message) ~= "string" then return nil end
    local marked, links = linksInMessage(message)
    -- The SQL source uses a typographic apostrophe; accept plain apostrophes
    -- too, without changing the original message or link bytes.
    marked = string.gsub(marked, "’", "'")
    local questLinks, itemLinks = {}, {}
    for _, record in ipairs(links) do
        if record.kind == "quest" then
            table.insert(questLinks, record.data)
        elseif record.kind == "item" then
            table.insert(itemLinks, record.data)
        end
    end

    local kind
    if table.getn(questLinks) == 1 then
        local prompt = "Which reward should I pick for completing the quest " .. QUEST .. "?"
        if string.sub(marked, 1, string.len(prompt)) == prompt then
            local after = string.sub(marked, string.len(prompt) + 1)
            after = string.gsub(after, ITEM, "")
            if table.getn(itemLinks) > 0 and string.find(after, "^%s*$") then
                kind = "reward_prompt"
            end
        end
        if not kind then
            for _, format in ipairs(FORMATS) do
                if string.find(marked, format[2]) then
                    kind = format[1]
                    break
                end
            end
        end
    elseif table.getn(questLinks) == 0 then
        if table.getn(itemLinks) == 1 and
            string.find(marked, "^Okay, I will pick " .. ITEM .. " as a reward$") then
            kind = "reward_ack"
        elseif table.getn(itemLinks) == 0 then
            kind = GENERIC[marked]
        end
    end
    if not kind then return nil end

    -- These records are immutable-by-convention handoff data for Chunk 2.
    -- Crucially, an objective-complete notification is NOT a quest turn-in.
    return {
        kind = kind,
        raw = message,
        quest = questLinks[1],
        questId = questLinks[1] and questLinks[1].id or nil,
        item = itemLinks[1],
        rewardOptions = kind == "reward_prompt" and itemLinks or nil,
    }
end

-- Only known TBM bots qualify. A human group member repeating a template
-- must never be hidden. TBM's server roster is the authoritative source.
local function resolveBot(sender)
    if type(sender) ~= "string" or sender == "" then return nil end
    local manager = TortoiseBots
    if type(manager) ~= "table" then return nil end
    local name = manager.NormalizeName and manager.NormalizeName(sender) or sender
    local entry = manager.GetRosterEntry and manager.GetRosterEntry(name)
    if not entry and manager.GetClaimedEntry then
        entry = manager.GetClaimedEntry(name)
    end
    if not entry then return nil end
    return {
        name = entry.name or name,
        classId = entry.classId,
        className = entry.className,
        guid = entry.guid,
    }
end

function QC.ParseQuestMessage(message)
    return classify(message)
end

function QC.ResolveBot(sender)
    return resolveBot(sender)
end

function QC.GetFilterOwnedBotMessages()
    return TortoiseBotQuestControlDB and
        TortoiseBotQuestControlDB.filterOwnedBotMessages == true or false
end

function QC.SetFilterOwnedBotMessages(enabled)
    if not TortoiseBotQuestControlDB then TortoiseBotQuestControlDB = {} end
    TortoiseBotQuestControlDB.filterOwnedBotMessages = enabled and true or false
end

function QC.GetFilterOtherBotMessages()
    return TortoiseBotQuestControlDB and
        TortoiseBotQuestControlDB.filterOtherBotMessages == true or false
end

function QC.SetFilterOtherBotMessages(enabled)
    if not TortoiseBotQuestControlDB then TortoiseBotQuestControlDB = {} end
    TortoiseBotQuestControlDB.filterOtherBotMessages = enabled and true or false
end

function QC.GetHideBotNames()
    return TortoiseBotQuestControlDB and
        TortoiseBotQuestControlDB.hideBotNames == true or false
end

function QC.SetHideBotNames(enabled)
    if not TortoiseBotQuestControlDB then TortoiseBotQuestControlDB = {} end
    TortoiseBotQuestControlDB.hideBotNames = enabled and true or false
end

function QC.GetHideBotQuestProgressMessages()
    return TortoiseBotQuestControlDB and
        TortoiseBotQuestControlDB.hideBotQuestProgressMessages == true or false
end

function QC.SetHideBotQuestProgressMessages(enabled)
    if not TortoiseBotQuestControlDB then TortoiseBotQuestControlDB = {} end
    TortoiseBotQuestControlDB.hideBotQuestProgressMessages = enabled and true or false
end

function QC.GetFadeWhenInactive()
    return TortoiseBotQuestControlDB and
        TortoiseBotQuestControlDB.fadeWhenInactive == true or false
end

function QC.SetFadeWhenInactive(enabled)
    if not TortoiseBotQuestControlDB then TortoiseBotQuestControlDB = {} end
    TortoiseBotQuestControlDB.fadeWhenInactive = enabled and true or false
end

-- The server's formatQuestObjective output is 'Objective: current/required'
-- with inline colour codes; clients may also surface it without colours.
-- These messages have no authenticated bot identity, so the new opt-in
-- filter uses the objective format independent of TBM's owned roster.
local function isBotQuestProgress(message)
    if type(message) ~= "string" then return false end
    local stripped = string.gsub(message, "|c%x%x%x%x%x%x%x%x", "")
    stripped = string.gsub(stripped, "|r", "")
    local _, _, objective, current, total = string.find(stripped,
        "^(.+): (%d+)/(%d+)$")
    if objective and current and total then
        local a, b = tonumber(current), tonumber(total)
        if a and b and b > 0 then return true end
    end
    -- Item objectives instead send '[questlink] - [itemlink] N/N'.
    local _, links = linksInMessage(message)
    if table.getn(links) == 2 and links[1].kind == "quest" and
        links[2].kind == "item" and
        string.find(message, " %d+/%d+$") then return true end
    return false
end

function QC.IsBotQuestProgress(message)
    return isBotQuestProgress(message)
end

-- This is the only delivery path for later quest-state handling.
-- It deliberately does not create rows, resolve quests or send commands yet.
function QC.ReceiveChat(channel, message, sender)
    if not CHANNELS[channel] then return nil end
    local bot = resolveBot(sender)
    if not bot then return nil end
    local parsed = classify(message)
    if not parsed then return nil end
    parsed.channel = channel
    parsed.bot = bot.name
    parsed.botInfo = bot
    if QC.OnQuestMessage then
        QC.OnQuestMessage(parsed)
    end
    return parsed
end

-- IMPORTANT: never call ReceiveChat here. ChatFrame_OnEvent is called once
-- per chat frame and both hook styles may run on the same event. Parsing
-- and state delivery instead happen once on our independent event frame.
-- Other-bot filtering is only a template match: TBM cannot certify an
-- unknown sender as a bot. Neither filter hides unrecognised chat.
function QC.ShouldHideMessage(channel, message, sender)
    if not CHANNELS[channel] or type(sender) ~= "string" or sender == "" then
        return false
    end
    -- Independent of both existing filters and all roster ownership checks.
    if QC.GetHideBotQuestProgressMessages() and
        isBotQuestProgress(message) then return true end
    if not classify(message) then return false end
    -- The bot/owner category comes exclusively from TBM's roster.
    local manager = TortoiseBots
    if type(manager) ~= "table" or
        (not manager.GetRosterEntry and not manager.GetClaimedEntry) then
        return false
    end
    if resolveBot(sender) then
        return QC.GetFilterOwnedBotMessages()
    end
    return QC.GetFilterOtherBotMessages()
end

local function installChatVisibilityFilter()
    if QC._chatVisibilityInstalled then return end
    local installed = false
    if ChatFrame_AddMessageEventFilter then
        local function filter(_, channel, message, sender)
            if QC.ShouldHideMessage(channel, message, sender) then return true end
        end
        for channel in pairs(CHANNELS) do
            ChatFrame_AddMessageEventFilter(channel, filter)
        end
        installed = true
    end

    -- Vanilla/Turtle can lack ChatFrame_AddMessageEventFilter. Chain rather
    -- than replace TBM's existing legacy ChatFrame_OnEvent chat filter.
    if ChatFrame_OnEvent then
        local previous = ChatFrame_OnEvent
        ChatFrame_OnEvent = function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
            local channel, message, sender = event, arg1, arg2
            if type(a1) == "string" and CHANNELS[a1] then
                channel, message, sender = a1, a2 or arg1, a3 or arg2
            elseif type(a2) == "string" and CHANNELS[a2] then
                channel, message, sender = a2, a3 or arg1, a4 or arg2
            end
            if QC.ShouldHideMessage(channel, message, sender) then return end
            return previous(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        end
        installed = true
    end
    QC._chatVisibilityInstalled = installed
end


-- Chunk 3 stabilization: persistent, order-independent bot quest observations.
-- A bot event is recorded before any attempt to find a player-created row.
-- Acceptance, hand-in issues and reward choices are distinct row stages.
local questRows, pendingEvents = {}, {}
local nextRowKey = 0
-- Resolved rows stay legible for seven seconds, then fade for three.
local RESOLVED_HOLD_SECONDS, RESOLVED_FADE_SECONDS = 7, 3
local RESOLVED_TOTAL_SECONDS = RESOLVED_HOLD_SECONDS + RESOLVED_FADE_SECONDS

local function cleanQuestTitle(title)
    if type(title) ~= "string" or title == "" then return nil end
    local _, _, unwrapped = string.find(title, "^%[(.*)%]$")
    return unwrapped or title
end

local function trackedBots()
    local result, seen = {}, {}
    local function add(name)
        local bot = QC.ResolveBot(name)
        if bot and bot.name and not seen[bot.name] then
            seen[bot.name] = true
            table.insert(result, bot)
        end
    end
    local raidSize = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raidSize > 0 then
        for index = 1, raidSize do add(UnitName("raid" .. index)) end
    else
        local partySize = GetNumPartyMembers and GetNumPartyMembers() or 0
        for index = 1, partySize do add(UnitName("party" .. index)) end
    end
    local manager = TortoiseBots
    if manager and manager.GetGroupedBotNames then
        for _, name in ipairs(manager.GetGroupedBotNames() or {}) do add(name) end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

local function db()
    if type(TortoiseBotQuestControlState) ~= "table" then
        TortoiseBotQuestControlState = {}
    end
    return TortoiseBotQuestControlState
end

local function saveState()
    local store = db()
    -- Fully resolved rows are visual-only until their fade finishes.
    -- Do not resurrect completed rows after /reload or a relog.
    local pendingRows = {}
    for _, row in ipairs(questRows) do
        if not row.fadeStartedAt then
            table.insert(pendingRows, row)
        end
    end
    store.questRows = pendingRows
    store.pendingEvents = pendingEvents
    store.nextRowKey = nextRowKey
end

function QC.LoadQuestState()
    local store = db()
    questRows = type(store.questRows) == "table" and store.questRows or {}
    pendingEvents = type(store.pendingEvents) == "table" and store.pendingEvents or {}
    nextRowKey = type(store.nextRowKey) == "number" and store.nextRowKey or 0
    for _, row in ipairs(questRows) do
        if type(row.key) == "number" and row.key > nextRowKey then
            nextRowKey = row.key
        end
    end
    saveState()
end

function QC.GetQuestRows()
    return questRows
end

function QC.GetTrackedBots()
    return trackedBots()
end

function QC.GetBotColumns()
    local columns, seen = {}, {}
    for _, row in ipairs(questRows) do
        for _, name in ipairs(row.botNames) do
            local cell = row.bots[name]
            if cell and not seen[name] then
                seen[name] = true
                table.insert(columns, cell.botInfo or { name = name })
            end
        end
    end
    table.sort(columns, function(a, b) return a.name < b.name end)
    return columns
end

local function stateChanged()
    saveState()
    if QC.OnStateChanged then QC.OnStateChanged() end
end

local function findPlayerQuestLink(title)
    -- Stock 1.12 does not expose GetQuestLink. Only use a client extension
    -- with an explicitly index-based link API; otherwise use bot chat links.
    if type(GetQuestLinkForLogIndex) ~= "function" or
        not GetQuestLogTitle or not GetNumQuestLogEntries then return nil end
    local indexFound
    for index = 1, GetNumQuestLogEntries() do
        local entryTitle, level, tag, isHeader = GetQuestLogTitle(index)
        if not isHeader and cleanQuestTitle(entryTitle) == title then
            if indexFound then return nil end -- duplicate titles are ambiguous
            indexFound = index
        end
    end
    if not indexFound then return nil end
    local ok, link = pcall(GetQuestLinkForLogIndex, indexFound)
    if ok and type(link) == "string" then
        local _, _, linkedTitle =
            string.find(link, "|Hquest:%d+[^|]*|h(%b[])|h")
        if cleanQuestTitle(linkedTitle) == title then return link end
    end
    return nil
end

local function captureInteraction()
    -- A unit target is only a hint, not proof it supplied the quest.
    -- Vanilla exposes no reliable targeted game-object identity here.
    if UnitExists and UnitName and UnitExists("target") then
        return { targetName = UnitName("target"), source = "selected unit" }
    end
    return nil
end

local function newRow(stage, title, questId, questLink, interaction)
    -- Columns are exclusively the online/grouped bots TBM reports.
    local bots = trackedBots()
    if table.getn(bots) == 0 then return nil end
    table.sort(bots, function(a, b) return a.name < b.name end)
    nextRowKey = nextRowKey + 1
    local row = {
        key = nextRowKey, stage = stage, title = title,
        questId = questId, questLink = questLink, interaction = interaction,
        botNames = {}, bots = {},
    }
    for _, bot in ipairs(bots) do
        table.insert(row.botNames, bot.name)
        row.bots[bot.name] = {
            botInfo = { name = bot.name, classId = bot.classId,
                className = bot.className, guid = bot.guid },
            status = stage == "accept" and "unconfirmed" or "assumed",
        }
    end
    table.insert(questRows, row)
    return row
end

local function resolvedRow(row)
    for _, name in ipairs(row.botNames) do
        local cell = row.bots[name]
        if not cell then return false end
        if row.stage == "accept" then
            if cell.status ~= "accepted" and cell.status ~= "already_have" then
                return false
            end
        elseif cell.status ~= "assumed" and cell.status ~= "resolved" then
            return false
        end
    end
    return true
end

local function removeResolvedRows()
    for i = table.getn(questRows), 1, -1 do
        local row = questRows[i]
        if resolvedRow(row) then
            -- A silent, assumed-success hand-in used to clear immediately;
            -- retain that behaviour rather than create a new visual row.
            local silentHandIn = row.stage == "handin"
            if silentHandIn then
                for _, name in ipairs(row.botNames) do
                    if row.bots[name].status ~= "assumed" then
                        silentHandIn = false
                        break
                    end
                end
            end
            if silentHandIn then
                table.remove(questRows, i)
            elseif not row.fadeStartedAt then
                row.fadeStartedAt = GetTime()
            end
        else
            -- If new evidence reopens the checkpoint, cancel its fade.
            row.fadeStartedAt = nil
        end
    end
end

function QC.RowFadeAlpha(row, now)
    if not row.fadeStartedAt then return 1 end
    local elapsed = (now or GetTime()) - row.fadeStartedAt
    if elapsed <= RESOLVED_HOLD_SECONDS then return 1 end
    return math.max(0, 1 - (elapsed - RESOLVED_HOLD_SECONDS) /
        RESOLVED_FADE_SECONDS)
end

function QC.TickResolvedFades()
    local now = GetTime()
    local removed, fading = false, false
    for i = table.getn(questRows), 1, -1 do
        local row = questRows[i]
        if row.fadeStartedAt then
            if not resolvedRow(row) then
                row.fadeStartedAt = nil
                removed = true -- repaint the revived row at full opacity
            elseif now - row.fadeStartedAt >= RESOLVED_TOTAL_SECONDS then
                table.remove(questRows, i)
                removed = true
            else
                fading = true
            end
        end
    end
    if removed then
        stateChanged()
    elseif fading and QC.RefreshRowFades then
        QC.RefreshRowFades(now)
    end
end

-- Avoid assigning an ID to a title-only row when distinct IDs have appeared.
local function ambiguousTitle(title)
    local found
    for _, observed in ipairs(pendingEvents) do
        if observed.title == title and observed.questId then
            if found and found ~= observed.questId then return true end
            found = observed.questId
        end
    end
    return false
end

local function findRow(stage, title, questId, botName)
    local fallback, matches = nil, 0
    for _, row in ipairs(questRows) do
        if row.stage == stage and row.title == title and
            (not botName or row.bots[botName]) then
            if questId and row.questId == questId then return row end
            if not questId or not row.questId then
                fallback = row
                matches = matches + 1
            end
        end
    end
    if matches == 1 and (not questId or not ambiguousTitle(title)) then
        return fallback
    end
    return nil
end

local function bindQuest(row, observed)
    if observed.questId and not row.questId then
        row.questId = observed.questId
    end
    if observed.questLink and not row.questLink then
        row.questLink = observed.questLink
    end
end

local function applyObserved(observed)
    local kind = observed.kind
    local stage
    if kind == "accepted" or kind == "available" or
        kind == "already_have" or kind == "already_completed" or
        kind == "cannot_take" or
        kind == "cannot_take_log_full" or kind == "cannot_take_bag_full" or
        kind == "failed" then
        stage = "accept"
    elseif kind == "reward_prompt" or kind == "turned_in" or
        kind == "turned_in_reward" then
        stage = "reward"
    elseif kind == "unable_to_turn_in" or kind == "incomplete" then
        stage = "handin"
    else
        return true -- available/objectives are not hand-ins or acceptances
    end

    local row = findRow(stage, observed.title, observed.questId, observed.bot)
    if not row and (kind == "reward_prompt" or stage == "handin") then
        row = newRow(stage, observed.title, observed.questId,
            observed.questLink)
    end
    if not row and (kind == "turned_in" or kind == "turned_in_reward") then
        row = findRow("handin", observed.title, observed.questId, observed.bot)
        -- Silent hand-in rows can already have been removed. Only an
        -- explicit linked completion deserves a visible confirmation row.
        -- Other bots remain neutral/assumed, not falsely confirmed.
        if not row then
            row = newRow("handin", observed.title, observed.questId,
                observed.questLink)
        end
    end
    if not row then return false end
    local cell = row.bots[observed.bot]
    if not cell then return false end
    bindQuest(row, observed)

    if stage == "accept" then
        -- A later failure message must not undo a confirmed pickup.
        if kind ~= "available" and
            ((cell.status ~= "accepted" and cell.status ~= "already_have") or
            kind == "accepted") then
            cell.status = kind
        end
    elseif kind == "reward_prompt" then
        if cell.status ~= "resolved" then
            cell.rewardOptions = observed.rewardOptions
            cell.selected = nil
            cell.selectedIndex = nil
            cell.status = "choices"
        end
    elseif kind == "turned_in" or kind == "turned_in_reward" then
        -- Refresh the 7+3 second display if another bot confirms in time.
        row.fadeStartedAt = nil
        cell.status = "resolved"
        cell.outcome = kind
        cell.received = observed.item
    else
        cell.status = kind
        cell.outcome = kind
    end
    return true
end

local function replayPending()
    -- One event may establish a reward row for an earlier unmatched event.
    -- Repeat while an event can be consumed, without depending on its order.
    local consumed
    repeat
        consumed = false
        local index = 1
        while index <= table.getn(pendingEvents) do
            if applyObserved(pendingEvents[index]) then
                table.remove(pendingEvents, index)
                consumed = true
            else
                index = index + 1
            end
        end
    until not consumed
    removeResolvedRows()
end

local function playerRow(stage, title, interaction)
    title = cleanQuestTitle(title)
    if not title then return nil end
    local knownLink = findPlayerQuestLink(title)
    local questId
    if knownLink then
        local _, _, idText = string.find(knownLink, "|Hquest:(%d+)")
        if idText then questId = tonumber(idText) end
    end
    local row = findRow(stage, title, questId)
    if not row then
        row = newRow(stage, title, questId, knownLink,
            interaction or captureInteraction())
    end
    if not row then return nil end
    if not row.questLink then row.questLink = knownLink end
    if not row.interaction then row.interaction = interaction or captureInteraction() end
    replayPending()
    stateChanged()
    return row.key
end

function QC.RecordPlayerAcceptance(title, interaction)
    return playerRow("accept", title, interaction)
end

function QC.RecordPlayerHandIn(title, interaction)
    title = cleanQuestTitle(title)
    if not title then return nil end
    -- An existing reward prompt owns the actionable state, not a second row.
    local existing = findRow("reward", title)
    if existing then
        if not existing.interaction then
            existing.interaction = interaction or captureInteraction()
        end
        replayPending()
        stateChanged()
        return existing.key
    end
    -- Hand-ins are assumed successful; a positive bot reply is optional.
    -- Only explicit problems/reward prompts keep actionable hand-in rows.
    return playerRow("handin", title, interaction)
end

function QC.RemoveQuestRow(rowKey)
    for index, row in ipairs(questRows) do
        if row.key == rowKey then
            table.remove(questRows, index)
            -- Deliberate dismissal also drops historical unmatched observations
            -- for this quest, so replay cannot resurrect the dismissed row.
            for pendingIndex = table.getn(pendingEvents), 1, -1 do
                local pending = pendingEvents[pendingIndex]
                if pending.title == row.title and
                    (not row.questId or pending.questId == row.questId) then
                    table.remove(pendingEvents, pendingIndex)
                end
            end
            stateChanged()
            return true
        end
    end
    return false
end

function QC.RecoveryTalk(rowKey, botName)
    for _, row in ipairs(questRows) do
        if row.key == rowKey and row.bots[botName] and
            row.bots[botName].status ~= "accepted" and
            row.bots[botName].status ~= "already_have" and SendChatMessage then
            SendChatMessage("talk", "WHISPER", nil, botName)
            return true
        end
    end
    return false
end

function QC.RecoveryAccept(rowKey, botName)
    for _, row in ipairs(questRows) do
        if row.key == rowKey and row.stage == "accept" and
            row.bots[botName] and row.bots[botName].status ~= "accepted" and
            row.bots[botName].status ~= "already_have" and SendChatMessage then
            local link = row.questLink or findPlayerQuestLink(row.title)
            if not link then return false end
            row.questLink = link
            SendChatMessage("accept " .. link, "WHISPER", nil, botName)
            stateChanged()
            return true
        end
    end
    return false
end

function QC.RefreshQuestLinks()
    local changed = false
    for _, row in ipairs(questRows) do
        if row.stage == "accept" and not row.questLink then
            local link = findPlayerQuestLink(row.title)
            if link then
                row.questLink = link
                local _, _, id = string.find(link, "|Hquest:(%d+)")
                if id and not row.questId then row.questId = tonumber(id) end
                changed = true
            end
        end
    end
    if changed then stateChanged() end
end

-- The exact original linked item is sent; a click never implies success.
function QC.ChooseReward(rowKey, botName, optionIndex)
    if type(optionIndex) ~= "number" or optionIndex < 1 or
        optionIndex ~= math.floor(optionIndex) then return false end
    for _, row in ipairs(questRows) do
        if row.key == rowKey and row.stage == "reward" then
            local cell = row.bots[botName]
            local option = cell and cell.rewardOptions and cell.rewardOptions[optionIndex]
            if not option or not option.link or not option.id then return false end
            if cell.status ~= "choices" and cell.status ~= "awaiting_ack" then
                return false
            end
            if not SendChatMessage then return false end
            cell.selected = option
            cell.selectedIndex = optionIndex
            cell.status = "awaiting_ack"
            SendChatMessage("r " .. option.link, "WHISPER", nil, botName)
            stateChanged()
            return true
        end
    end
    return false
end

function QC.OnQuestMessage(parsed)
    if not parsed or not parsed.bot then return end
    if parsed.kind == "reward_ack" then
        if not parsed.item then return end
        for _, row in ipairs(questRows) do
            if row.stage == "reward" then
                local cell = row.bots[parsed.bot]
                if cell and cell.status == "awaiting_ack" and cell.selected
                    and cell.selected.id == parsed.item.id then
                    cell.status = "resolved"
                    cell.outcome = "reward_ack"
                    cell.received = parsed.item
                    removeResolvedRows()
                    stateChanged()
                    return
                end
            end
        end
        return
    end
    if not parsed.quest then return end
    local observed = {
        kind = parsed.kind, bot = parsed.bot, botInfo = parsed.botInfo,
        title = cleanQuestTitle(parsed.quest.name),
        questId = parsed.questId, questLink = parsed.quest.link,
        item = parsed.item, rewardOptions = parsed.rewardOptions,
    }
    if not observed.title then return end
    table.insert(pendingEvents, observed)
    replayPending()
    stateChanged()
end

-- AcceptQuest and GetQuestReward are native 1.12 quest-dialogue functions.
-- Capture the visible quest/title before chaining the original function.
local function installQuestHooks()
    if QC._questHooksInstalled then return end
    if type(AcceptQuest) == "function" then
        local previousAccept = AcceptQuest
        AcceptQuest = function()
            local title
            if QuestFrameDetailPanel and QuestFrameDetailPanel:IsVisible() and
                type(GetTitleText) == "function" then
                title = GetTitleText()
            end
            local interaction = captureInteraction()
            local result = previousAccept()
            if title then QC.RecordPlayerAcceptance(title, interaction) end
            return result
        end
    end
    if type(GetQuestReward) == "function" then
        local previousReward = GetQuestReward
        GetQuestReward = function(choice)
            local title
            if QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible() and
                type(GetTitleText) == "function" then
                title = GetTitleText()
            end
            local interaction = captureInteraction()
            local result = previousReward(choice)
            if title then QC.RecordPlayerHandIn(title, interaction) end
            return result
        end
    end
    QC._questHooksInstalled = true
end


-- Chunk 3: display only. All quest state and original-link commands remain
-- owned by the core QC functions above; the UI never parses chat itself.
-- Compact pfQuest_Group-inspired presentation; no parser/state changes below.
local L = QC.L
local QUEST_W, BOT_MIN_W, BOT_ICON_MIN_W = 190, 122, 62
local HEADER_H, ROW_MIN = 25, 23
local ICON_SIZE, ICON_STEP = 18, 21
local CLASS_TOKENS = {
    [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER",
    [4] = "ROGUE", [5] = "PRIEST", [7] = "SHAMAN",
    [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID",
}
local CLASS_COORDS = {
    WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.5, 0, 0.25 },
    ROGUE = { 0.5, 0.75, 0, 0.25 }, DRUID = { 0.75, 1, 0, 0.25 },
    HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.5, 0.25, 0.5 },
    PRIEST = { 0.5, 0.75, 0.25, 0.5 }, WARLOCK = { 0.75, 1, 0.25, 0.5 },
    PALADIN = { 0, 0.25, 0.5, 0.75 },
}
local ADDON_ASSETS = "Interface\\AddOns\\TortoiseBotManager-QuestControl\\assets\\"
local uiWindow, uiScroll, uiContent, uiHorizontal, uiVertical
local uiCheckboxOwned, uiCheckboxOther, uiCheckboxNames, uiCheckboxProgress, uiCheckboxFade
local uiSettings, uiHovering = nil, false
local headerWidgets, rowWidgets = {}, {}
local newestDisplayedKey = 0
local questButton, questButtonHost, questButtonInfo, questButtonDrag
local integrationElapsed = 0

local function panelBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.025, 0.032, 0.045, 0.94)
    frame:SetBackdropBorderColor(0.38, 0.33, 0.23, 0.88)
end

local function font(parent, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template)
    label:SetJustifyH("LEFT")
    return label
end

local function tooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.tipText or "", 1, 0.85, 0.55)
    if button.tipDetail and button.tipDetail ~= "" then
        GameTooltip:AddLine(button.tipDetail, 0.9, 0.9, 0.9, 1)
    end
    GameTooltip:Show()
end

local function iconButton(parent, texture, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width); button:SetHeight(height)
    button:RegisterForClicks("LeftButtonUp")
    local image = button:CreateTexture(nil, "ARTWORK")
    image:SetAllPoints(button)
    image:SetTexture(texture)
    button.icon = image
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button:SetScript("OnEnter", function() tooltip(this) end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

local function classAppearance(info, texture, nameLabel)
    local token = CLASS_TOKENS[info.classId]
    if not token and type(info.className) == "string" then
        token = string.upper(info.className)
    end
    local coords = (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token])
        or CLASS_COORDS[token]
    if coords then
        texture:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        texture:Show()
    else
        texture:Hide()
    end
    local tb = TortoiseBots
    local c = tb and tb.GetClassColor and tb.GetClassColor(info.classId)
        or { 0.92, 0.90, 0.84 }
    nameLabel:SetTextColor(c[1], c[2], c[3])
end

local function itemTexture(option)
    -- Never replace the bot's actual original item link with an inferred item.
    local texture
    if GetItemInfo then
        local name, link, quality, level, minLevel, kind, subKind, stack, equip, icon =
            GetItemInfo(option.link)
        texture = icon
    end
    if not texture and GetItemIcon then texture = GetItemIcon(option.id) end
    return texture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function createRewardButton(parent)
    local button = iconButton(parent, "Interface\\Icons\\INV_Misc_QuestionMark",
        ICON_SIZE, ICON_SIZE)
    button:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    button.icon:ClearAllPoints()
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetScript("OnClick", function()
        QC.ChooseReward(this.rowKey, this.botName, this.optionIndex)
    end)
    button:SetScript("OnEnter", function()
        if this.option then
            this.icon:SetTexture(itemTexture(this.option))
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            local _, _, payload = string.find(this.option.link, "|H(item:[^|]+)|h")
            GameTooltip:SetHyperlink(payload or this.option.link)
            GameTooltip:Show()
        end
    end)
    return button
end

local function createActionButton(parent, texture, action, tip)
    local button = iconButton(parent, texture, 15, 15)
    button.action = action
    button.tipText = tip
    button:SetScript("OnClick", function()
        if this.action == "talk" then
            QC.RecoveryTalk(this.rowKey, this.botName)
        else
            QC.RecoveryAccept(this.rowKey, this.botName)
        end
    end)
    return button
end

local function createBotCell(widget)
    local panel = CreateFrame("Frame", nil, widget.frame)
    local status = iconButton(panel, ADDON_ASSETS .. "status-neutral", 15, 15)
    status:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    local talk = createActionButton(panel,
        "Interface\\GossipFrame\\GossipGossipIcon", "talk", L.ACTION_TALK)
    talk:SetPoint("LEFT", status, "RIGHT", 3, 0)
    local accept = createActionButton(panel, ADDON_ASSETS .. "clipboard-check",
        "accept", L.ACTION_ACCEPT)
    accept:SetPoint("LEFT", talk, "RIGHT", 3, 0)
    return { frame = panel, status = status, icons = {},
        talk = talk, accept = accept }
end

local function cellStatus(row, data)
    if not data then return "neutral", L.STATUS_NOT_TRACKED end
    if row.stage == "accept" then
        if data.status == "accepted" then return "yes", L.STATUS_ACCEPTED end
        if data.status == "already_have" then return "yes", L.STATUS_ALREADY_HAVE end
        if data.status == "already_completed" then
            return "no", L.STATUS_ALREADY_COMPLETE
        end
        if data.status == "cannot_take" or
            data.status == "cannot_take_log_full" or
            data.status == "cannot_take_bag_full" or
            data.status == "failed" then
            return "no", L.STATUS_CANNOT_ACCEPT
        end
        return "neutral", L.STATUS_UNCONFIRMED
    end
    if data.status == "unable_to_turn_in" then
        return "no", L.STATUS_HANDIN_FAILED
    end
    if data.status == "incomplete" then return "no", L.STATUS_INCOMPLETE end
    if data.status == "resolved" then
        if data.outcome == "turned_in" or data.outcome == "turned_in_reward" then
            return "yes", L.STATUS_TURNED_IN
        end
        return "yes", L.STATUS_RESOLVED
    end
    if data.status == "choices" then return "neutral", L.STATUS_CHOOSE end
    if data.status == "awaiting_ack" then return "neutral", L.STATUS_AWAITING end
    return "neutral", L.STATUS_HANDIN_ASSUMED
end

local function renderBotCell(widget, row, botName, colIndex, offset, width, height)
    local cell = widget.cells[colIndex]
    if not cell then
        cell = createBotCell(widget)
        widget.cells[colIndex] = cell
    end
    local panel = cell.frame
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", offset, 0)
    panel:SetWidth(width - 1); panel:SetHeight(height)
    local data = row.bots[botName]
    local kind, tip = cellStatus(row, data)
    -- Bundle the small marks: ReadyCheck art is not reliable across
    -- Vanilla/Turtle client builds. These never encode unconfirmed as failure.
    cell.status.icon:SetTexture(kind == "yes"
        and ADDON_ASSETS .. "status-yes"
        or kind == "no" and ADDON_ASSETS .. "status-no"
        or ADDON_ASSETS .. "status-neutral")
    cell.status.tipText = tip
    local options = data and data.rewardOptions
    local selectable = row.stage == "reward" and options and
        (data.status == "choices" or data.status == "awaiting_ack")
    -- Reward choices themselves are the only controls needed in this cell.
    -- No neutral placeholder/status icon or reserved first line.
    if selectable then cell.status:Hide() else cell.status:Show() end
    cell.talk:Hide()
    cell.accept:Hide()
    if data and row.stage == "accept" and
        data.status ~= "accepted" and data.status ~= "already_have" then
        cell.talk.rowKey = row.key
        cell.talk.botName = botName
        cell.talk:Show()
        cell.accept.rowKey = row.key
        cell.accept.botName = botName
        local canAccept = row.questLink ~= nil
        if canAccept then cell.accept:Enable() else cell.accept:Disable() end
        cell.accept:SetAlpha(canAccept and 1 or 0.4)
        cell.accept.tipDetail = canAccept and nil or L.STATUS_UNCONFIRMED
        cell.accept:Show()
    elseif data and row.stage == "handin" and
        (data.status == "unable_to_turn_in" or data.status == "incomplete") then
        cell.talk.rowKey = row.key
        cell.talk.botName = botName
        cell.talk:Show()
    end
    for _, button in ipairs(cell.icons) do button:Hide() end
    if selectable then
        local perLine = math.max(1, math.floor((width - 7) / ICON_STEP))
        for i, option in ipairs(options) do
            local button = cell.icons[i]
            if not button then
                button = createRewardButton(panel)
                cell.icons[i] = button
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", panel, "TOPLEFT",
                4 + math.mod(i - 1, perLine) * ICON_STEP,
                -2 - math.floor((i - 1) / perLine) * ICON_STEP)
            button.rowKey, button.botName = row.key, botName
            button.optionIndex, button.option = i, option
            button.icon:SetTexture(itemTexture(option))
            if data.selectedIndex == i then
                button:SetBackdropBorderColor(1, 0.85, 0.35, 1)
            else
                button:SetBackdropBorderColor(0.45, 0.41, 0.3, 0.85)
            end
            button:Show()
        end
    end
    panel:Show()
end

local function createRow()
    local frame = CreateFrame("Frame", nil, uiContent)
    local backdrop = frame:CreateTexture(nil, "BACKGROUND")
    backdrop:SetAllPoints(frame)
    backdrop:SetTexture(0.19, 0.18, 0.15, 0.28)
    local quest = iconButton(frame, "Interface\\GossipFrame\\AvailableQuestIcon",
        QUEST_W - 22, ROW_MIN)
    quest:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, 0)
    quest.icon:SetTexture(nil) -- the large hit target must not stretch quest artwork
    local qIcon = quest:CreateTexture(nil, "ARTWORK")
    qIcon:SetWidth(15); qIcon:SetHeight(15)
    qIcon:SetPoint("LEFT", quest, "LEFT", 3, 0)
    local title = font(quest, "GameFontNormalSmall")
    title:SetPoint("LEFT", qIcon, "RIGHT", 3, 0)
    title:SetWidth(QUEST_W - 45); title:SetHeight(18)
    quest:SetScript("OnEnter", function() tooltip(this) end)
    local dismiss = iconButton(frame, ADDON_ASSETS .. "trash-2", 15, 15)
    dismiss:SetPoint("TOPLEFT", frame, "TOPLEFT", QUEST_W - 19, -4)
    dismiss.tipText = "Remove quest"
    dismiss:SetScript("OnClick", function() QC.RemoveQuestRow(this.rowKey) end)
    local widget = { frame = frame, quest = quest, title = title,
        questIcon = qIcon, dismiss = dismiss, cells = {} }
    table.insert(rowWidgets, widget)
    return widget
end

local function renderHeader(info, index, offset, width)
    local widget = headerWidgets[index]
    if not widget then
        local frame = CreateFrame("Frame", nil, uiContent)
        local texture = frame:CreateTexture(nil, "ARTWORK")
        texture:SetWidth(16); texture:SetHeight(16)
        texture:SetPoint("LEFT", frame, "LEFT", 3, 0)
        local name = font(frame, "GameFontNormalSmall")
        name:SetPoint("LEFT", texture, "RIGHT", 4, 0)
        frame:EnableMouse(false)
        frame:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(this.botDisplayName or "", 1, 1, 1)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        widget = { frame = frame, texture = texture, name = name }
        headerWidgets[index] = widget
    end
    widget.frame:ClearAllPoints()
    widget.frame:SetPoint("TOPLEFT", uiContent, "TOPLEFT", offset, 0)
    widget.frame:SetWidth(width - 1); widget.frame:SetHeight(HEADER_H - 1)
    widget.name:SetWidth(width - 27); widget.name:SetHeight(20)
    widget.name:SetText(info.name)
    classAppearance(info, widget.texture, widget.name)
    widget.frame.botDisplayName = info.name
    local iconOnly = QC.GetHideBotNames()
    widget.frame:EnableMouse(iconOnly)
    if iconOnly then widget.name:Hide() else widget.name:Show() end
    widget.frame:Show()
end

local function rowHeight(row, columns, widths)
    local height = ROW_MIN
    if row.stage ~= "reward" then return height end
    for i, bot in ipairs(columns) do
        local cell = row.bots[bot.name]
        if cell and cell.rewardOptions and
            (cell.status == "choices" or cell.status == "awaiting_ack") then
            local perLine = math.max(1, math.floor((widths[i] - 7) / ICON_STEP))
            height = math.max(height,
                2 + math.ceil(table.getn(cell.rewardOptions) / perLine) * ICON_STEP)
        end
    end
    return height
end

local function windowStore()
    local state = db()
    if type(state.window) ~= "table" then state.window = {} end
    return state.window
end

local function saveWindow()
    if not uiWindow then return end
    local pos = windowStore()
    local left, top = uiWindow:GetLeft(), uiWindow:GetTop()
    if left and top then pos.x, pos.y = left, top end
    pos.width, pos.height = uiWindow:GetWidth(), uiWindow:GetHeight()
    pos.userSized = uiWindow.userSized and true or false
end

local function updateViewport()
    if not uiWindow then return end
    local width = math.max(100, uiWindow:GetWidth() - 26)
    local height = math.max(70, uiWindow:GetHeight() - 48)
    uiScroll:SetWidth(width); uiScroll:SetHeight(height)
    uiVertical:SetHeight(height - 5)
    uiHorizontal:SetWidth(width - 5)
end

-- Mouse-over testing by screen coordinates avoids parent OnLeave firing
-- when moving into child buttons or the settings popover. Both frame bounds
-- and cursor coordinates are converted to the frame's effective UI scale.
local function cursorOverQuestControl()
    if not uiWindow or not uiWindow:IsShown() or not GetCursorPosition then
        return false
    end
    local scale = uiWindow:GetEffectiveScale()
    if not scale or scale <= 0 then return false end
    local x, y = GetCursorPosition()
    if not x or not y then return false end
    x, y = x / scale, y / scale
    local function contains(frame)
        if not frame or not frame:IsShown() then return false end
        local left, right = frame:GetLeft(), frame:GetRight()
        local top, bottom = frame:GetTop(), frame:GetBottom()
        return left and right and top and bottom
            and x >= left and x <= right and y >= bottom and y <= top
    end
    return contains(uiWindow) or contains(uiSettings)
end

-- The parent dimmer is independent of each row's 7+3-second fade.
local function refreshWindowOpacity(rows)
    if not uiWindow then return end
    uiHovering = cursorOverQuestControl()
    local alpha = 1
    if QC.GetFadeWhenInactive() and not uiHovering then
        alpha = 0.2
        for _, row in ipairs(rows) do
            if not resolvedRow(row) then
                alpha = 1
                break
            end
        end
    end
    if uiWindow:GetAlpha() ~= alpha then uiWindow:SetAlpha(alpha) end
end

-- Runs with the existing event-frame update: brighten on cursor entry and
-- restore the configured inactive alpha on exit, without re-rendering rows.
function QC.UpdateHoverOpacity()
    if not uiWindow or not uiWindow:IsShown()
        or not QC.GetFadeWhenInactive() then return end
    if cursorOverQuestControl() ~= uiHovering then
        refreshWindowOpacity(QC.GetQuestRows())
    end
end

function QC.RefreshUI()
    if not uiWindow then return end
    local rows, columns = QC.GetQuestRows(), QC.GetBotColumns()
    local widths, offsets, totalWidth = {}, {}, QUEST_W
    local iconOnly = QC.GetHideBotNames()
    for index, info in ipairs(columns) do
        local width
        if iconOnly then
            -- Retain room for the status/Talk/Accept buttons. Grow a bot
            -- column only when its live reward options need more icon room.
            width = BOT_ICON_MIN_W
            for _, row in ipairs(rows) do
                local cell = row.bots[info.name]
                if row.stage == "reward" and cell and cell.rewardOptions and
                    (cell.status == "choices" or cell.status == "awaiting_ack") then
                    width = math.max(width, math.min(BOT_MIN_W,
                        7 + table.getn(cell.rewardOptions) * ICON_STEP))
                end
            end
        else
            width = math.max(BOT_MIN_W,
                string.len(info.name or "") * 8 + 31)
        end
        widths[index], offsets[index] = width, totalWidth
        totalWidth = totalWidth + width
    end
    local y = HEADER_H
    for _, row in ipairs(rows) do
        y = y + rowHeight(row, columns, widths) + 1
    end
    if not uiWindow.userSized then
        local targetWidth = math.min(UIParent:GetWidth() - 28,
            math.max(iconOnly and 240 or 340, totalWidth + 25))
        local targetHeight = math.min(UIParent:GetHeight() - 50,
            math.max(160, math.min(360, y + 54)))
        uiWindow:SetWidth(targetWidth)
        uiWindow:SetHeight(targetHeight)
    end
    updateViewport()
    local viewWidth, viewHeight = uiScroll:GetWidth(), uiScroll:GetHeight()
    local contentWidth = math.max(viewWidth, totalWidth)
    local contentHeight = math.max(viewHeight, y + 2)
    uiContent:SetWidth(contentWidth); uiContent:SetHeight(contentHeight)
    for _, widget in ipairs(headerWidgets) do widget.frame:Hide() end
    for index, info in ipairs(columns) do
        renderHeader(info, index, offsets[index], widths[index])
    end
    local top = HEADER_H
    for index, row in ipairs(rows) do
        local widget = rowWidgets[index] or createRow()
        local height = rowHeight(row, columns, widths)
        widget.frame:ClearAllPoints()
        widget.frame:SetPoint("TOPLEFT", uiContent, "TOPLEFT", 0, -top)
        widget.frame:SetWidth(contentWidth); widget.frame:SetHeight(height)
        widget.questIcon:SetTexture(row.stage == "accept"
            and "Interface\\GossipFrame\\AvailableQuestIcon"
            or "Interface\\GossipFrame\\ActiveQuestIcon")
        widget.title:SetText(row.title)
        widget.quest.tipText = row.title
        widget.quest.tipDetail = (row.stage == "accept" and L.STAGE_ACCEPT
            or row.stage == "reward" and L.STAGE_REWARD or L.STAGE_HANDIN)
        if row.interaction and row.interaction.targetName then
            widget.quest.tipDetail = widget.quest.tipDetail .. " / " ..
                L.CONTEXT_TARGET .. row.interaction.targetName
        end
        widget.dismiss.rowKey = row.key
        widget.frame:SetAlpha(QC.RowFadeAlpha(row))
        for _, cell in ipairs(widget.cells) do cell.frame:Hide() end
        for j, info in ipairs(columns) do
            renderBotCell(widget, row, info.name, j, offsets[j], widths[j], height)
        end
        widget.frame:Show()
        top = top + height + 1
    end
    for i = table.getn(rows) + 1, table.getn(rowWidgets) do
        rowWidgets[i].frame:Hide()
    end
    local hmax = math.max(0, contentWidth - viewWidth)
    local vmax = math.max(0, contentHeight - viewHeight)
    uiHorizontal:SetMinMaxValues(0, hmax)
    uiVertical:SetMinMaxValues(0, vmax)
    uiHorizontal:SetValue(math.min(uiHorizontal:GetValue(), hmax))
    uiVertical:SetValue(math.min(uiVertical:GetValue(), vmax))
    -- In the target 1.12 client positive horizontal offsets move this
    -- ScrollFrame opposite the thumb. Negate to keep 0 = first column
    -- and dragging the thumb right = revealing columns to the right.
    uiScroll:SetHorizontalScroll(-uiHorizontal:GetValue())
    uiScroll:SetVerticalScroll(uiVertical:GetValue())
    if hmax > 0 then uiHorizontal:Show() else uiHorizontal:Hide() end
    if vmax > 0 then uiVertical:Show() else uiVertical:Hide() end
    uiCheckboxOwned:SetChecked(QC.GetFilterOwnedBotMessages())
    uiCheckboxOther:SetChecked(QC.GetFilterOtherBotMessages())
    uiCheckboxNames:SetChecked(QC.GetHideBotNames())
    uiCheckboxProgress:SetChecked(QC.GetHideBotQuestProgressMessages())
    uiCheckboxFade:SetChecked(QC.GetFadeWhenInactive())
    refreshWindowOpacity(rows)
end

function QC.RefreshRowFades(now)
    if not uiWindow or not uiWindow:IsShown() then return end
    for index, row in ipairs(questRows) do
        local widget = rowWidgets[index]
        if widget then widget.frame:SetAlpha(QC.RowFadeAlpha(row, now)) end
    end
end

local function createScrollSlider(parent, orientation)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation(orientation)
    slider:SetWidth(12); slider:SetHeight(12)
    slider:SetMinMaxValues(0, 0)
    slider:SetValueStep(21)
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    slider:SetBackdropColor(0.1, 0.09, 0.07, 0.7)
    slider:SetBackdropBorderColor(0.4, 0.35, 0.22, 0.7)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    return slider
end

function QC.ToggleUI()
    if not uiWindow then QC.InitUI() end
    if not uiWindow then return end
    if uiWindow:IsShown() then
        uiWindow:Hide()
    else
        QC.RefreshUI()
        uiWindow:Show()
    end
end

function QC.EnsureTBMButton()
    local tb = TortoiseBots
    if not tb or not tb.frame or not tb.infoButton or not tb.dragHeader
        or not tb.StyleButton then return end
    if questButton and questButtonHost == tb.frame and
        questButtonInfo == tb.infoButton and
        questButtonDrag == tb.dragHeader then return end
    if not questButton then
        questButton = tb.StyleButton(CreateFrame("Button", nil,
            tb.frame, "UIPanelButtonTemplate"))
        questButton:SetWidth(44); questButton:SetHeight(20)
        questButton:SetText(L.QUEST_HEADER)
        questButton:SetScript("OnClick", function() QC.ToggleUI() end)
        questButton:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.WINDOW_TITLE)
            GameTooltip:Show()
        end)
        questButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    questButton:SetParent(tb.frame)
    questButton:ClearAllPoints()
    questButton:SetPoint("RIGHT", tb.infoButton, "LEFT", -4, 0)
    tb.dragHeader:ClearAllPoints()
    tb.dragHeader:SetPoint("TOPLEFT", tb.frame, "TOPLEFT", 0, 0)
    tb.dragHeader:SetPoint("BOTTOMRIGHT", questButton, "BOTTOMLEFT", -6, 0)
    questButton:SetFrameLevel(tb.dragHeader:GetFrameLevel() + 2)
    questButtonHost, questButtonInfo, questButtonDrag =
        tb.frame, tb.infoButton, tb.dragHeader
end

function QC.InitUI()
    if uiWindow then return end
    for _, row in ipairs(QC.GetQuestRows()) do
        if row.key > newestDisplayedKey then newestDisplayedKey = row.key end
    end
    local pos = windowStore()
    local window = CreateFrame("Frame", "TortoiseBotQuestControlFrame", UIParent)
    uiWindow = window
    window:SetWidth(pos.userSized and pos.width or 340)
    window:SetHeight(pos.userSized and pos.height or 180)
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:SetResizable(true)
    window:SetMinResize(240, 160)
    window:SetMaxResize(math.max(240, UIParent:GetWidth() - 28),
        math.max(160, UIParent:GetHeight() - 50))
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window.userSized = pos.userSized and true or false
    if type(pos.x) == "number" and type(pos.y) == "number" then
        window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 25)
    end
    panelBackdrop(window)
    if pfUI and pfUI.api and type(pfUI.api.CreateBackdrop) == "function" then
        pcall(pfUI.api.CreateBackdrop, window, nil, true)
    end
    -- Escape must not close this frame; close/Quest button and /tbmq still do.
    local drag = CreateFrame("Frame", nil, window)
    drag:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", window, "TOPRIGHT", -45, 0)
    drag:SetHeight(25); drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() window:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        local left, top = window:GetLeft(), window:GetTop()
        if left and top then
            window:ClearAllPoints()
            window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        saveWindow()
    end)
    local title = font(window, "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -8)
    title:SetText(L.WINDOW_TITLE)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetWidth(22); close:SetHeight(22)
    close:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
    close:SetFrameLevel(drag:GetFrameLevel() + 2)
    local gear = iconButton(window, "Interface\\Icons\\INV_Gizmo_02", 16, 16)
    gear:SetPoint("RIGHT", close, "LEFT", -3, 0)
    gear:SetFrameLevel(drag:GetFrameLevel() + 2)
    gear.tipText = L.SETTINGS_TOOLTIP
    local settings = CreateFrame("Frame", nil, window)
    settings:SetWidth(250); settings:SetHeight(142)
    settings:SetPoint("TOPRIGHT", gear, "BOTTOMRIGHT", 0, -4)
    settings:SetFrameLevel(gear:GetFrameLevel() + 2)
    uiSettings = settings
    panelBackdrop(settings)
    local owned = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")
    owned:SetWidth(20); owned:SetHeight(20)
    owned:SetPoint("TOPLEFT", settings, "TOPLEFT", 5, -6)
    local ownedText = font(settings, "GameFontHighlightSmall")
    ownedText:SetPoint("LEFT", owned, "RIGHT", 3, 0)
    ownedText:SetText(L.FILTER_OWNED_BOT_MESSAGES)
    owned:SetScript("OnClick", function()
        QC.SetFilterOwnedBotMessages(this:GetChecked())
    end)
    uiCheckboxOwned = owned
    local other = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")
    other:SetWidth(20); other:SetHeight(20)
    other:SetPoint("TOPLEFT", owned, "BOTTOMLEFT", 0, -2)
    local otherText = font(settings, "GameFontHighlightSmall")
    otherText:SetPoint("LEFT", other, "RIGHT", 3, 0)
    otherText:SetText(L.FILTER_OTHER_BOT_MESSAGES)
    other:SetScript("OnClick", function()
        QC.SetFilterOtherBotMessages(this:GetChecked())
    end)
    uiCheckboxOther = other
    local names = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")
    names:SetWidth(20); names:SetHeight(20)
    names:SetPoint("TOPLEFT", other, "BOTTOMLEFT", 0, -2)
    local namesText = font(settings, "GameFontHighlightSmall")
    namesText:SetPoint("LEFT", names, "RIGHT", 3, 0)
    namesText:SetText(L.HIDE_BOT_NAMES)
    names:SetScript("OnClick", function()
        -- Save per-mode widths so switching back preserves manual sizing.
        local pos = windowStore()
        local oldMode = QC.GetHideBotNames() and "icon" or "named"
        pos[oldMode .. "Width"] = window:GetWidth()
        pos[oldMode .. "UserSized"] = window.userSized and true or false
        QC.SetHideBotNames(this:GetChecked())
        local newMode = QC.GetHideBotNames() and "icon" or "named"
        window.userSized = pos[newMode .. "UserSized"] == true
        if window.userSized and type(pos[newMode .. "Width"]) == "number" then
            window:SetWidth(pos[newMode .. "Width"])
        end
        QC.RefreshUI()
        saveWindow()
    end)
    uiCheckboxNames = names
    local progress = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")
    progress:SetWidth(20); progress:SetHeight(20)
    progress:SetPoint("TOPLEFT", names, "BOTTOMLEFT", 0, -2)
    local progressText = font(settings, "GameFontHighlightSmall")
    progressText:SetPoint("LEFT", progress, "RIGHT", 3, 0)
    progressText:SetText(L.HIDE_BOT_QUEST_PROGRESS)
    progress:SetScript("OnClick", function()
        QC.SetHideBotQuestProgressMessages(this:GetChecked())
    end)
    uiCheckboxProgress = progress
    local fade = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")
    fade:SetWidth(20); fade:SetHeight(20)
    fade:SetPoint("TOPLEFT", progress, "BOTTOMLEFT", 0, -2)
    local fadeText = font(settings, "GameFontHighlightSmall")
    fadeText:SetPoint("LEFT", fade, "RIGHT", 3, 0)
    fadeText:SetText(L.FADE_WHEN_INACTIVE)
    fade:SetScript("OnClick", function()
        QC.SetFadeWhenInactive(this:GetChecked())
        QC.RefreshUI()
    end)
    uiCheckboxFade = fade
    settings:Hide()
    gear:SetScript("OnClick", function()
        if settings:IsShown() then settings:Hide() else
            QC.RefreshUI()
            settings:Show()
        end
    end)
    local scroll = CreateFrame("ScrollFrame", nil, window)
    scroll:SetPoint("TOPLEFT", window, "TOPLEFT", 7, -27)
    uiScroll = scroll
    local body = CreateFrame("Frame", nil, scroll)
    body:SetWidth(320); body:SetHeight(110)
    scroll:SetScrollChild(body)
    uiContent = body
    local vert = createScrollSlider(window, "VERTICAL")
    vert:SetPoint("TOPRIGHT", window, "TOPRIGHT", -8, -29)
    vert:SetScript("OnValueChanged", function()
        scroll:SetVerticalScroll(this:GetValue())
    end)
    uiVertical = vert
    local horiz = createScrollSlider(window, "HORIZONTAL")
    horiz:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 7, 7)
    horiz:SetScript("OnValueChanged", function()
        scroll:SetHorizontalScroll(-this:GetValue())
    end)
    uiHorizontal = horiz
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function()
        vert:SetValue(vert:GetValue() - arg1 * 35)
    end)
    local grip = iconButton(window,
        "Interface\\Buttons\\WHITE8X8", 20, 20)
    -- Contrast and thickness matter at different UI scales and pfUI skins.
    -- All marks use the Vanilla built-in solid texture, not missing art.
    grip.icon:SetTexture(0.05, 0.05, 0.05, 0.90)
    for step = 0, 2 do
        for dot = 0, step do
            local mark = grip:CreateTexture(nil, "OVERLAY")
            mark:SetTexture(1, 0.85, 0.40, 1)
            mark:SetWidth(4); mark:SetHeight(4)
            mark:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT",
                -2 - step * 5, 2 + dot * 5)
        end
    end
    grip:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(window:GetFrameLevel() + 6)
    grip.tipText = "Resize"
    grip:SetScript("OnMouseDown", function()
        window:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        window:StopMovingOrSizing()
        window.userSized = true
        saveWindow()
        QC.RefreshUI()
    end)
    window:SetScript("OnSizeChanged", function() updateViewport() end)
    SLASH_TBMQ1 = "/tbmq"
    SlashCmdList["TBMQ"] = function() QC.ToggleUI() end
    QC.RefreshUI()
    window:Hide()
    QC.EnsureTBMButton()
end

function QC.OnStateChanged()
    local isNew = false
    for _, row in ipairs(QC.GetQuestRows()) do
        if row.key > newestDisplayedKey then
            newestDisplayedKey = row.key
            isNew = true
        end
    end
    if not uiWindow then QC.InitUI() end
    QC.RefreshUI()
    if isNew then uiWindow:Show() end
end

local events = CreateFrame("Frame", "TortoiseBotQuestControlEvents")
events:SetScript("OnUpdate", function()
    QC.TickResolvedFades()
    QC.UpdateHoverOpacity()
    integrationElapsed = integrationElapsed + arg1
    if integrationElapsed >= 0.75 then
        integrationElapsed = 0
        QC.EnsureTBMButton()
    end
end)
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("QUEST_LOG_UPDATE")
for channel in pairs(CHANNELS) do events:RegisterEvent(channel) end
events:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if arg1 == QC.ADDON_NAME then
            if type(TortoiseBotQuestControlDB) ~= "table" then
                TortoiseBotQuestControlDB = {}
            end
            -- Preserve the original owned/other visibility migration.
            if TortoiseBotQuestControlDB.filterOwnedBotMessages == nil then
                local previous = TortoiseBotQuestControlDB.hideBotQuestMessages
                if previous == nil then previous = false end
                TortoiseBotQuestControlDB.filterOwnedBotMessages = previous and true or false
            end
            if TortoiseBotQuestControlDB.filterOtherBotMessages == nil then
                TortoiseBotQuestControlDB.filterOtherBotMessages = false
            end
            TortoiseBotQuestControlDB.hideBotQuestMessages = nil
            if TortoiseBotQuestControlDB.hideBotNames == nil then
                TortoiseBotQuestControlDB.hideBotNames = false
            end
            if TortoiseBotQuestControlDB.hideBotQuestProgressMessages == nil then
                TortoiseBotQuestControlDB.hideBotQuestProgressMessages = false
            end
            if TortoiseBotQuestControlDB.fadeWhenInactive == nil then
                TortoiseBotQuestControlDB.fadeWhenInactive = false
            end
            QC.LoadQuestState()
            installChatVisibilityFilter()
            installQuestHooks()
            QC.InitUI()
        end
    elseif event == "QUEST_LOG_UPDATE" then
        QC.RefreshQuestLinks()
    elseif CHANNELS[event] then
        QC.ReceiveChat(event, arg1, arg2)
    end
end)
