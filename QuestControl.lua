-- QuestControl: message-handling foundation for Vanilla WoW 1.12.1 (Lua 5.0.3).
-- Quest state and reward delivery are implemented; UI follows in Chunk 3.
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

-- The Chunk 3 checkbox will call this setter. It affects display only.
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


-- Chunk 2: ephemeral player hand-in rows, with one cell per grouped TBM bot.
-- Rows are created by submitting GetQuestReward, not QUEST_COMPLETE (which
-- merely opens the reward page) or a bot's objectives_completed notification.
local questRows = {}
local nextRowKey = 0

local function cleanQuestTitle(title)
    if type(title) ~= "string" or title == "" then return nil end
    -- A quest chat hyperlink displays [Title]; GetTitleText() returns Title.
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

    -- The group is the set of bots being asked to complete the hand-in.
    local raidSize = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raidSize > 0 then
        for index = 1, raidSize do add(UnitName("raid" .. index)) end
    else
        local partySize = GetNumPartyMembers and GetNumPartyMembers() or 0
        for index = 1, partySize do add(UnitName("party" .. index)) end
    end
    -- TBM also tracks members from its server-owned group snapshot. This
    -- preserves claimed/grouped bots if the client group view is still updating.
    local manager = TortoiseBots
    if manager and manager.GetGroupedBotNames then
        for _, name in ipairs(manager.GetGroupedBotNames() or {}) do add(name) end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

-- Public read-only-by-convention data for the Chunk 3 window.
-- row = { key, title, questId?, questLink?, botNames, bots[name] = cell }
-- cell = { botInfo, status, rewardOptions?, selected?, received?, outcome? }
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
            if not seen[name] then
                seen[name] = true
                table.insert(columns, row.bots[name].botInfo)
            end
        end
    end
    table.sort(columns, function(a, b) return a.name < b.name end)
    return columns
end

local function stateChanged()
    -- The presentation layer will own rendering; no UI is created in Chunk 2.
    if QC.OnStateChanged then QC.OnStateChanged() end
end

function QC.RecordPlayerHandIn(title)
    title = cleanQuestTitle(title)
    if not title then return nil end

    local bots = trackedBots()
    if table.getn(bots) == 0 then return nil end
    nextRowKey = nextRowKey + 1
    local row = { key = nextRowKey, title = title, botNames = {}, bots = {} }
    for _, bot in ipairs(bots) do
        table.insert(row.botNames, bot.name)
        row.bots[bot.name] = { botInfo = bot, status = "waiting" }
    end
    table.insert(questRows, row)
    stateChanged()
    return row.key
end

local function unresolvedCell(row, botName)
    local cell = row.bots[botName]
    if cell and cell.status ~= "resolved" then return cell end
    return nil
end

local function findQuestCell(parsed)
    local title = parsed.quest and cleanQuestTitle(parsed.quest.name)
    if not title then return nil end

    -- Prefer a row already bound to the bot's actual quest-link ID. In the
    -- original 1.12 quest log the ID is not returned, so initially the row
    -- only has the player-facing quest title; bind its ID on the first reply.
    if parsed.questId then
        for _, row in ipairs(questRows) do
            local cell = unresolvedCell(row, parsed.bot)
            if cell and row.questId == parsed.questId then return row, cell end
        end
    end
    for _, row in ipairs(questRows) do
        local cell = unresolvedCell(row, parsed.bot)
        if cell and row.title == title and not row.questId then
            row.questId = parsed.questId
            row.questLink = parsed.quest.link
            return row, cell
        end
    end
    return nil
end

local function allResolved(row)
    for _, name in ipairs(row.botNames) do
        if row.bots[name].status ~= "resolved" then return false end
    end
    return true
end

local function finishCell(row, cell, outcome, item)
    cell.status = "resolved"
    cell.outcome = outcome
    cell.received = item
    if allResolved(row) then
        for index, active in ipairs(questRows) do
            if active == row then
                table.remove(questRows, index)
                break
            end
        end
    end
    stateChanged()
end

-- Clicking a Chunk 3 reward icon calls this API with the row key, bot name and
-- index into that bot's actual linked options. Never rebuild the hyperlink.
function QC.ChooseReward(rowKey, botName, optionIndex)
    if type(optionIndex) ~= "number" or optionIndex < 1 or
        optionIndex ~= math.floor(optionIndex) then return false end
    for _, row in ipairs(questRows) do
        if row.key == rowKey then
            local cell = unresolvedCell(row, botName)
            local option = cell and cell.rewardOptions and cell.rewardOptions[optionIndex]
            if not option or not option.link or not option.id then return false end
            if not SendChatMessage then return false end
            cell.selected = option
            cell.status = "awaiting_ack"
            SendChatMessage("r " .. option.link, "WHISPER", nil, botName)
            stateChanged()
            return true
        end
    end
    return false
end

-- Linkless reward acknowledgement is correlated by sending bot + item ID,
-- selecting the oldest outstanding cell if the same item was sent for more
-- than one quest. Other linkless quest chatter cannot identify a quest.
function QC.OnQuestMessage(parsed)
    if not parsed or not parsed.bot then return end
    if parsed.kind == "reward_ack" then
        if not parsed.item then return end
        for _, row in ipairs(questRows) do
            local cell = unresolvedCell(row, parsed.bot)
            if cell and cell.status == "awaiting_ack" and cell.selected and
                cell.selected.id == parsed.item.id then
                finishCell(row, cell, "reward_ack", parsed.item)
                return
            end
        end
        return
    end

    if not parsed.quest then return end
    local kind = parsed.kind
    -- Objective completion, quest availability/acceptance and other unrelated
    -- notices never create a row or count as a player/bot hand-in.
    if kind ~= "reward_prompt" and kind ~= "turned_in" and
        kind ~= "turned_in_reward" and kind ~= "unable_to_turn_in" and
        kind ~= "incomplete" and kind ~= "already_completed" and
        kind ~= "failed" then return end

    local row, cell = findQuestCell(parsed)
    if not row then return end
    if kind == "reward_prompt" then
        cell.rewardOptions = parsed.rewardOptions
        cell.selected = nil
        cell.status = "choices"
        stateChanged()
    else
        finishCell(row, cell, kind, parsed.item)
    end
end

-- Vanilla has no QUEST_TURNED_IN event. QUEST_FINISHED includes cancellations,
-- whereas GetQuestReward is the actual final reward/hand-in submission.
-- Chain the native API, capturing the visible reward quest before it closes.
local function installHandInHook()
    if QC._handInHookInstalled or type(GetQuestReward) ~= "function" then return end
    local previous = GetQuestReward
    GetQuestReward = function(choice)
        local title
        if QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible() and
            type(GetTitleText) == "function" then
            title = GetTitleText()
        end
        local result = previous(choice)
        if title then QC.RecordPlayerHandIn(title) end
        return result
    end
    QC._handInHookInstalled = true
end

local events = CreateFrame("Frame", "TortoiseBotQuestControlEvents")
events:RegisterEvent("ADDON_LOADED")
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
            installChatVisibilityFilter()
            installHandInHook()
        end
    elseif CHANNELS[event] then
        QC.ReceiveChat(event, arg1, arg2)
    end
end)
