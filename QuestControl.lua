-- QuestControl: message-handling foundation for Vanilla WoW 1.12.1 (Lua 5.0.3).
-- Quest rows, player hand-in tracking and reward commands are Chunk 2.
-- The finished window and checkbox widget are Chunk 3.
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
        end
    elseif CHANNELS[event] then
        QC.ReceiveChat(event, arg1, arg2)
    end
end)
