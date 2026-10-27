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

function QC.GetHideBotQuestMessages()
    return TortoiseBotQuestControlDB and
        TortoiseBotQuestControlDB.hideBotQuestMessages == true or false
end

-- The checkbox changes display only; recognition and state delivery remain independent.
function QC.SetHideBotQuestMessages(hidden)
    if not TortoiseBotQuestControlDB then TortoiseBotQuestControlDB = {} end
    TortoiseBotQuestControlDB.hideBotQuestMessages = hidden and true or false
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
function QC.ShouldHideMessage(channel, message, sender)
    return QC.GetHideBotQuestMessages() and CHANNELS[channel] and
        resolveBot(sender) ~= nil and classify(message) ~= nil or false
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
local L = QC.L
local UI_W, UI_H = 690, 470
local VIEW_W, VIEW_H = 636, 320
local QUEST_W, BOT_W = 192, 144
local ICON_SIZE, ICON_STEP, HEADER_H = 28, 32, 46
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
local uiWindow, uiScroll, uiContent, uiHorizontal, uiVertical, uiCheckbox
local headerWidgets, rowWidgets = {}, {}
local newestDisplayedKey = 0

local function palette(name, fallback)
    local tb = TortoiseBots
    return tb and tb.C and tb.C.COLOR and tb.C.COLOR[name] or fallback
end

local function panelBackdrop(frame, alpha)
    local tb = TortoiseBots
    if tb and tb.ApplyBackdrop then
        tb.ApplyBackdrop(frame, alpha or 0.96, 0.85)
    else
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 11,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0.025, 0.032, 0.045, alpha or 0.96)
        frame:SetBackdropBorderColor(0.48, 0.36, 0.15, 0.85)
    end
end

local function font(parent, template, width)
    local label = parent:CreateFontString(nil, "OVERLAY", template)
    if width then label:SetWidth(width) end
    label:SetJustifyH("LEFT")
    return label
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
        or palette("text", { 0.92, 0.90, 0.84 })
    nameLabel:SetTextColor(c[1], c[2], c[3])
end

local function itemTexture(option)
    -- Vanilla GetItemInfo's tenth return value is the item texture.
    -- Never substitute a quest database item for the bot's original link.
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
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(ICON_SIZE); button:SetHeight(ICON_SIZE)
    button:RegisterForClicks("LeftButtonUp")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button:SetBackdropColor(0.04, 0.04, 0.04, 0.90)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetTexture(1, 0.84, 0.35, 0.22)
    button:SetScript("OnClick", function()
        QC.ChooseReward(this.rowKey, this.botName, this.optionIndex)
    end)
    button:SetScript("OnEnter", function()
        if this.option then
            this.icon:SetTexture(itemTexture(this.option))
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            -- The 1.12 tooltip API expects the payload within the actual
            -- bot-supplied hyperlink, rather than formatted chat color codes.
            local _, _, payload = string.find(this.option.link, "|H(item:[^|]+)|h")
            GameTooltip:SetHyperlink(payload or this.option.link)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

local function createActionButton(panel, label, action)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetWidth(60); button:SetHeight(21)
    button:SetText(label)
    button:SetScript("OnClick", function()
        if this.action == "talk" then
            QC.RecoveryTalk(this.rowKey, this.botName)
        else
            QC.RecoveryAccept(this.rowKey, this.botName)
        end
    end)
    button.action = action
    return button
end

local function createBotCell(row)
    local panel = CreateFrame("Frame", nil, row.frame)
    panelBackdrop(panel, 0.38)
    local status = font(panel, "GameFontHighlightSmall", BOT_W - 14)
    status:SetPoint("TOPLEFT", panel, "TOPLEFT", 7, -9)
    local talk = createActionButton(panel, L.ACTION_TALK, "talk")
    talk:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -33)
    local accept = createActionButton(panel, L.ACTION_ACCEPT, "accept")
    accept:SetPoint("LEFT", talk, "RIGHT", 4, 0)
    return { frame = panel, status = status, icons = {},
        talk = talk, accept = accept }
end

local function renderBotCell(widget, row, botName, colIndex, height)
    local cell = widget.cells[colIndex]
    if not cell then
        cell = createBotCell(widget)
        widget.cells[colIndex] = cell
    end
    local panel = cell.frame
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", widget.frame, "TOPLEFT",
        QUEST_W + (colIndex - 1) * BOT_W, -2)
    panel:SetWidth(BOT_W - 2); panel:SetHeight(height - 3)
    panel:Show()
    local data = row.bots[botName]
    local options = data and data.rewardOptions
    local selectable = data and (data.status == "choices" or
        data.status == "awaiting_ack") and options and table.getn(options) > 0
    cell.talk:Hide()
    cell.accept:Hide()
    if not data then
        cell.status:SetText(L.STATUS_NOT_TRACKED)
    elseif row.stage == "accept" then
        if data.status == "accepted" then
            cell.status:SetText(L.STATUS_ACCEPTED)
        elseif data.status == "already_have" then
            cell.status:SetText(L.STATUS_ALREADY_HAVE)
        elseif data.status == "already_completed" then
            cell.status:SetText(L.STATUS_ALREADY_COMPLETE)
        elseif data.status == "cannot_take" or
            data.status == "cannot_take_log_full" or
            data.status == "cannot_take_bag_full" or
            data.status == "failed" then
            cell.status:SetText(L.STATUS_CANNOT_ACCEPT)
        else
            cell.status:SetText(L.STATUS_UNCONFIRMED)
        end
        if data.status ~= "accepted" and data.status ~= "already_have" then
            cell.talk.rowKey = row.key
            cell.talk.botName = botName
            cell.talk:Show()
            cell.accept.rowKey = row.key
            cell.accept.botName = botName
            if row.questLink then
                cell.accept:Enable()
                cell.accept:SetAlpha(1)
            else
                cell.accept:Disable()
                cell.accept:SetAlpha(0.45)
            end
            cell.accept:Show()
        end
    elseif row.stage == "handin" then
        if data.status == "unable_to_turn_in" then
            cell.status:SetText(L.STATUS_HANDIN_FAILED)
        elseif data.status == "incomplete" then
            cell.status:SetText(L.STATUS_INCOMPLETE)
        else
            cell.status:SetText(L.STATUS_HANDIN_ASSUMED)
        end
        if data.status == "unable_to_turn_in" or data.status == "incomplete" then
            cell.talk.rowKey = row.key
            cell.talk.botName = botName
            cell.talk:Show()
        end
    elseif selectable and data.status == "awaiting_ack" then
        cell.status:SetText(L.STATUS_AWAITING)
    elseif selectable then
        cell.status:SetText(L.STATUS_CHOOSE)
    elseif data.status == "resolved" then
        cell.status:SetText(L.STATUS_RESOLVED)
    else
        cell.status:SetText(L.STATUS_HANDIN_ASSUMED)
    end
    for _, button in ipairs(cell.icons) do button:Hide() end
    if selectable then
        for i, option in ipairs(options) do
            local button = cell.icons[i]
            if not button then
                button = createRewardButton(panel)
                cell.icons[i] = button
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", panel, "TOPLEFT",
                7 + math.mod(i - 1, 4) * ICON_STEP,
                -24 - math.floor((i - 1) / 4) * ICON_STEP)
            button.rowKey = row.key
            button.botName = botName
            button.optionIndex = i
            button.option = option
            button.icon:SetTexture(itemTexture(option))
            if data.selectedIndex == i then
                button:SetBackdropBorderColor(1, 0.84, 0.35, 1)
            else
                button:SetBackdropBorderColor(0.48, 0.36, 0.15, 0.85)
            end
            button:Show()
        end
    end
end

local function createRow()
    local frame = CreateFrame("Frame", nil, uiContent)
    panelBackdrop(frame, 0.60)
    local title = font(frame, "GameFontNormalSmall", QUEST_W - 43)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -9)
    local stage = font(frame, "GameFontHighlightSmall", QUEST_W - 18)
    stage:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -44)
    local context = font(frame, "GameFontHighlightSmall", QUEST_W - 18)
    context:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -62)
    local dismiss = CreateFrame("Button", nil, frame)
    dismiss:SetWidth(18); dismiss:SetHeight(18)
    dismiss:SetPoint("TOPRIGHT", frame, "TOPLEFT", QUEST_W - 8, -5)
    local cross = font(dismiss, "GameFontNormalSmall")
    cross:SetPoint("CENTER", dismiss, "CENTER", 0, 0)
    cross:SetText("X")
    dismiss:SetScript("OnClick", function()
        QC.RemoveQuestRow(this.rowKey)
    end)
    local widget = { frame = frame, title = title, stage = stage,
        context = context, dismiss = dismiss, cells = {} }
    table.insert(rowWidgets, widget)
    return widget
end

local function renderHeader(info, index)
    local widget = headerWidgets[index]
    if not widget then
        local frame = CreateFrame("Frame", nil, uiContent)
        panelBackdrop(frame, 0.65)
        local texture = frame:CreateTexture(nil, "ARTWORK")
        texture:SetWidth(19); texture:SetHeight(19)
        texture:SetPoint("LEFT", frame, "LEFT", 6, 0)
        local name = font(frame, "GameFontNormalSmall", BOT_W - 34)
        name:SetPoint("LEFT", texture, "RIGHT", 5, 0)
        widget = { frame = frame, texture = texture, name = name }
        headerWidgets[index] = widget
    end
    widget.frame:ClearAllPoints()
    widget.frame:SetPoint("TOPLEFT", uiContent, "TOPLEFT",
        QUEST_W + (index - 1) * BOT_W, -3)
    widget.frame:SetWidth(BOT_W - 2); widget.frame:SetHeight(HEADER_H - 7)
    widget.name:SetText(info.name)
    classAppearance(info, widget.texture, widget.name)
    widget.frame:Show()
end

local function rowHeight(row)
    local lines = 0
    for _, name in ipairs(row.botNames) do
        local cell = row.bots[name]
        if cell and cell.rewardOptions and
            (cell.status == "choices" or cell.status == "awaiting_ack") then
            lines = math.max(lines, math.ceil(table.getn(cell.rewardOptions) / 4))
        end
    end
    return math.max(88, 38 + lines * ICON_STEP)
end

function QC.RefreshUI()
    if not uiWindow then return end
    local rows, columns = QC.GetQuestRows(), QC.GetBotColumns()
    local contentWidth = math.max(VIEW_W, QUEST_W + table.getn(columns) * BOT_W)
    uiContent:SetWidth(contentWidth)
    if table.getn(rows) == 0 then
        uiWindow.emptyLabel:Show()
    else
        uiWindow.emptyLabel:Hide()
    end
    for _, header in ipairs(headerWidgets) do header.frame:Hide() end
    for i, bot in ipairs(columns) do renderHeader(bot, i) end
    local y = HEADER_H
    for i, row in ipairs(rows) do
        local widget = rowWidgets[i] or createRow()
        local height = rowHeight(row)
        widget.frame:ClearAllPoints()
        widget.frame:SetPoint("TOPLEFT", uiContent, "TOPLEFT", 0, -y)
        widget.frame:SetWidth(contentWidth); widget.frame:SetHeight(height)
        widget.title:SetText(row.title)
        widget.title:SetHeight(33)
        widget.stage:SetText(row.stage == "accept" and L.STAGE_ACCEPT
            or row.stage == "reward" and L.STAGE_REWARD or L.STAGE_HANDIN)
        widget.context:SetText(row.interaction and
            row.interaction.targetName and
            (L.CONTEXT_TARGET .. row.interaction.targetName) or "")
        widget.dismiss.rowKey = row.key
        widget.frame:SetAlpha(QC.RowFadeAlpha(row))
        for _, cell in ipairs(widget.cells) do cell.frame:Hide() end
        for j, bot in ipairs(columns) do
            renderBotCell(widget, row, bot.name, j, height)
        end
        widget.frame:Show()
        y = y + height + 3
    end
    for i = table.getn(rows) + 1, table.getn(rowWidgets) do
        rowWidgets[i].frame:Hide()
    end
    local contentHeight = math.max(VIEW_H, y + 12)
    uiContent:SetHeight(contentHeight)
    local horizontalMax = math.max(0, contentWidth - VIEW_W)
    local verticalMax = math.max(0, contentHeight - VIEW_H)
    uiHorizontal:SetMinMaxValues(0, horizontalMax)
    uiVertical:SetMinMaxValues(0, verticalMax)
    uiHorizontal:SetValue(math.min(uiHorizontal:GetValue(), horizontalMax))
    uiVertical:SetValue(math.min(uiVertical:GetValue(), verticalMax))
    uiScroll:SetHorizontalScroll(uiHorizontal:GetValue())
    uiScroll:SetVerticalScroll(uiVertical:GetValue())
    if horizontalMax > 0 then uiHorizontal:Show() else uiHorizontal:Hide() end
    if verticalMax > 0 then uiVertical:Show() else uiVertical:Hide() end
    uiCheckbox:SetChecked(QC.GetHideBotQuestMessages())
end

-- Alpha updates do not rebuild the table or mutate quest state each frame.
function QC.RefreshRowFades(now)
    if not uiWindow or not uiWindow:IsShown() then return end
    for index, row in ipairs(questRows) do
        local widget = rowWidgets[index]
        if widget then widget.frame:SetAlpha(QC.RowFadeAlpha(row, now)) end
    end
end

local function createScrollSlider(parent, orientation, width, height)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation(orientation)
    slider:SetWidth(width); slider:SetHeight(height)
    slider:SetMinMaxValues(0, 0)
    slider:SetValueStep(24)
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    slider:SetBackdropColor(0.10, 0.09, 0.07, 0.9)
    slider:SetBackdropBorderColor(0.48, 0.36, 0.15, 0.9)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    return slider
end

function QC.InitUI()
    if uiWindow then return end
    -- Restored rows must not trigger an unrelated auto-open on the next event.
    for _, row in ipairs(QC.GetQuestRows()) do
        if row.key > newestDisplayedKey then newestDisplayedKey = row.key end
    end
    local window = CreateFrame("Frame", "TortoiseBotQuestControlFrame", UIParent)
    uiWindow = window
    window:SetWidth(UI_W); window:SetHeight(UI_H)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    panelBackdrop(window, 0.98)
    if UISpecialFrames then
        table.insert(UISpecialFrames, "TortoiseBotQuestControlFrame")
    end
    local drag = CreateFrame("Frame", nil, window)
    drag:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", window, "TOPRIGHT", -34, 0)
    drag:SetHeight(38); drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() window:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        -- In WoW 1.12 GetPoint() after StopMovingOrSizing() can crash.
        local left, top = window:GetLeft(), window:GetTop()
        if left and top then
            window:ClearAllPoints()
            window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
    end)
    local logo = window:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\Icons\\Ability_Hunter_Pet_Turtle")
    logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    logo:SetWidth(23); logo:SetHeight(23)
    logo:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -7)
    local title = font(window, "GameFontNormalLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 6, 5)
    title:SetText("|cffd8a657Tortoise|r|cff4ecb5aBots|r |cfffff2cc"
        .. L.WINDOW_TITLE .. "|r")
    local version = font(window, "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    version:SetText("v" .. (QC.version or "?"))
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -3, -2)
    close:SetFrameLevel(drag:GetFrameLevel() + 2)
    local divider = window:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -42)
    divider:SetPoint("TOPRIGHT", window, "TOPRIGHT", -12, -42)
    divider:SetHeight(1); divider:SetTexture(0.48, 0.36, 0.15, 0.7)
    local scroll = CreateFrame("ScrollFrame", nil, window)
    scroll:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -55)
    scroll:SetWidth(VIEW_W); scroll:SetHeight(VIEW_H)
    uiScroll = scroll
    local body = CreateFrame("Frame", nil, scroll)
    body:SetWidth(VIEW_W); body:SetHeight(VIEW_H)
    scroll:SetScrollChild(body)
    uiContent = body
    local questLabel = font(body, "GameFontNormalSmall", QUEST_W - 16)
    questLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 10, -14)
    questLabel:SetText(L.QUEST_HEADER)
    local gold = palette("gold", { 0.95, 0.72, 0.28 })
    questLabel:SetTextColor(gold[1], gold[2], gold[3])
    local empty = font(body, "GameFontHighlightSmall", VIEW_W - 32)
    empty:SetPoint("TOPLEFT", body, "TOPLEFT", 12, -69)
    empty:SetText(L.EMPTY_ROWS)
    window.emptyLabel = empty
    local vert = createScrollSlider(window, "VERTICAL", 15, VIEW_H - 8)
    vert:SetPoint("TOPRIGHT", window, "TOPRIGHT", -13, -59)
    vert:SetScript("OnValueChanged", function()
        scroll:SetVerticalScroll(this:GetValue())
    end)
    uiVertical = vert
    local horiz = createScrollSlider(window, "HORIZONTAL", VIEW_W, 14)
    horiz:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 0, -4)
    horiz:SetScript("OnValueChanged", function()
        scroll:SetHorizontalScroll(this:GetValue())
    end)
    uiHorizontal = horiz
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function()
        vert:SetValue(vert:GetValue() - arg1 * 45)
    end)
    local checkbox = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    checkbox:SetWidth(24); checkbox:SetHeight(24)
    checkbox:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 9, 7)
    local checkboxText = font(window, "GameFontHighlightSmall")
    checkboxText:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    checkboxText:SetText(L.HIDE_BOT_QUEST_MESSAGES)
    checkbox:SetScript("OnClick", function()
        QC.SetHideBotQuestMessages(this:GetChecked())
    end)
    uiCheckbox = checkbox
    SLASH_TBMQ1 = "/tbmq"
    SlashCmdList["TBMQ"] = function()
        if uiWindow:IsShown() then
            uiWindow:Hide()
        else
            QC.RefreshUI()
            uiWindow:Show()
        end
    end
    QC.RefreshUI()
    window:Hide()
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
    -- New hand-ins open the panel; bot replies cannot reopen a closed panel.
    if isNew then uiWindow:Show() end
end

local events = CreateFrame("Frame", "TortoiseBotQuestControlEvents")
events:SetScript("OnUpdate", function() QC.TickResolvedFades() end)
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("QUEST_LOG_UPDATE")
for channel in pairs(CHANNELS) do events:RegisterEvent(channel) end
events:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if arg1 == QC.ADDON_NAME then
            if type(TortoiseBotQuestControlDB) ~= "table" then
                TortoiseBotQuestControlDB = {}
            end
            if TortoiseBotQuestControlDB.hideBotQuestMessages == nil then
                TortoiseBotQuestControlDB.hideBotQuestMessages = true
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
