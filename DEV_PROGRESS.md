# Development Progress

> Single live development/status document for TortoiseBotManager-QuestControl. Structure adapted from `Seraphic8x2244/VanillaTemplate/DEV_PROGRESS.md`; canonical `dev_rulebook.md` copied unchanged from the same template.

## Current
- Branch: `dev` (active development); `main` is the initial README-only baseline.
- Version: Not assigned; no addon `.toc` or runtime files yet.
- Development head at start of this status write: `74287939a60c194169662bb8d54e5aeb7a8c80b2` (copied rulebook). The commit adding this file is the newer `dev` head; verify `dev` when resuming.
- Stable baseline: None; no addon released.
- Goal: Build a Vanilla WoW 1.12.1 quest-by-bot reward selection UI, primarily to reduce TortoiseBots quest chat spam.
- Current scope boundary: Design and documentation only. No addon runtime code, server modification, or optional controls beyond the requested chat-visibility checkbox.

## Current Design / Development Contract

### Architecture / Ownership
- New QuestControl addon for WoW 1.12.1 (Lua 5.0.3), matching TortoiseBotsManager (TBM) window style and visual constants; integrate with TBM rather than replacing it.
- Quest rows are triggered by **the player handing in a quest**, not by quest pickup or bot objective completion.
- **Rows = quests; columns = tracked bots**. Column headers show bot name and class icon.
- Each bot's column displays its own reward options as **square item icons derived from the item hyperlinks sent in its chat message**.
- Mouseover uses the original item hyperlink for an in-game item tooltip.
- Clicking an icon sends the selected item's **original item link** directly to that bot: `/w BotName r [itemlink]` (equivalent API `SendChatMessage("r " .. itemLink, "WHISPER", nil, botName)`).
- A quest row disappears when **all its tracked bots are resolved**. Do not introduce additional completion safeguards or conditions beyond the agreed behaviour.
- No quest-accept UI, auto-pick feature, unsolicited buttons, server protocol changes, or unrelated quest controls.

### Invariants
- Primary function is to **consume known bot quest notifications, update the UI, and hide them from normal chat**.
- **One master checkbox labelled `Hide Bot Quest Messages`** controls chat suppression only:
  - Checked: recognised bot quest messages are hidden from normal chat.
  - Unchecked: the same messages remain visible for debugging.
  - In both states: the parser and Quest UI continue functioning identically.
- The master checkbox applies to all recognised bot quest messages; no per-message or per-channel controls.
- Do not hide ordinary player chat or unrelated bot messages.
- Keep quest/item hyperlinks intact; reward options can differ for each bot.

### Protocol / Data Model
- Message source: TortoiseBots world text templates in `data/sql/world/20260913090000_world.sql`, and their use in `QuestAction.cpp`, `TalkToQuestGiverAction.cpp`, and `RewardAction.cpp` (upstream `Sagiroth/TortoiseBots`).
- Bot responses can use party, raid or whisper channels (`PlayerbotAIChat.cpp`); TBM already has a chat-filter/legacy dispatch approach (`Core.lua`). Implement for Vanilla 1.12.1.
- `%quest` and `%quest_link` represent the actual quest hyperlink; `%item` is an item hyperlink. Reward prompt's `%rewards` consists of newline-separated formatted item links.
- Key exact English message templates and handling:
  - `Which reward should I pick for completing the quest %quest?%rewards` → identify bot/quest and parse all linked reward options.
  - `Okay, I will pick %item as a reward` → reward-command response, with no quest link; correlate to the relevant bot/selection.
  - `I have completed the quest %quest` → quest handed in without choice reward.
  - `I have completed the quest %quest and received %item` → quest reward awarded.
  - `I am unable to turn in the quest %quest` → unable to turn in.
  - `I have not completed the quest %quest` → incomplete.
  - `Quest %quest available`; `I have accepted %quest`; `I already have %quest`; `I have already completed %quest`; `I can’t take %quest`; `I can’t take %quest because my quest log is full`; `I can’t take %quest because my bag is full`; `I have failed the quest %quest`; `I can’t talk with the quest giver`; generic `Quest accepted` and `I can’t take this quest` → recognised quest-related messages to intercept/hide.
  - `Completed %quest_link` → **objectives completed, not quest turn-in**. Do not treat it as a resolution.
- `r` is mapped to the server `reward` action; the implementation extracts the item ID from the linked item and rewards the matching choice, even though the general commands document mentions a reward index.
- The server only sends linked reward choices in its selection-list path. Its auto-pick path may instead award an item without listing choices; for `!ai->IsAlt()` the investigated code auto-picks. No new server configuration behaviour is part of this plan.

### Active Decisions
- Preserve the agreed quest-by-bot table; do not revert to bot-per-row layout.
- Reward icons come from **links actually sent by bots**, not a static quest reward database.
- Chat debug checkbox changes only visibility, not message parsing, tracked state, or UI updates.
- Row resolution follows parsed bot messages; do not invent additional confirmations, retries, timeouts, or safeguards.

## Recent Relevant Commits
- `c1917adea82893919c987e492cce90e7b543ebcc` — initialise `main` with project README.
- `74287939a60c194169662bb8d54e5aeb7a8c80b2` — copy canonical `dev_rulebook.md` unchanged on `dev`.
- This document's creation is the next `dev` commit; obtain exact SHA from remote history.

## Completed / User-Verified
- Requirements and table orientation agreed in chat.
- Server quest text templates, newline-separated item links, reward `r [itemlink]` handling, and relevant upstream source paths researched.
- Development documentation setup: README and copied canonical rulebook; this progress/design plan.

## Implemented / Awaiting Runtime Test
- None. Addon implementation has not started.

## Static / Automated Checks
- Source inspection only; no compiler/CI or addon static checks run.

## Current Issues
- There are no captured in-game message samples from this addon yet.
- English SQL templates are confirmed; changes in server localisation/configuration could change chat text.
- The server auto-pick paths do not provide selectable reward links.
- How to map bot replies lacking quest IDs to active quest rows must be implemented against observed message ordering, without inventing extra product behaviour.

## Testing

### Last Runtime Test
- Version/commit: None.
- Passed: None.
- Failed: None.
- Not tested: All QuestControl functionality.

### Next Runtime Test
- With `Hide Bot Quest Messages` unchecked, hand in a quest and compare every raw bot message to the corresponding quest/bot UI cell.
- Enable the checkbox, repeat, and verify that recognised messages are hidden while the same UI updates occur.
- With a bot reward-choice prompt, check item textures, mouseover tooltips and `/w BotName r [itemlink]` routing.
- Verify the quest row hides when all tracked bots are resolved.

## Planned / Next Work
1. Add the minimal 1.12.1 addon `.toc` and Lua entry point on `dev`; assign the first development version in `.toc`.
2. Implement the player-turn-in row trigger and quest-by-bot table styled after TBM.
3. Parse the verified bot quest messages and their quest/item hyperlinks from party/raid/whisper.
4. Implement the single `Hide Bot Quest Messages` master checkbox so chat suppression can be switched off for debugging without disabling parsing.
5. Render square item icons and item hyperlink tooltips; wire icon click to direct `r [itemlink]` whisper to the matching bot.
6. Remove quest rows when all tracked bot entries are resolved; test in game.

## Deferred / Out of Scope
- Server changes or structured custom quest transport.
- Bot quest acceptance controls, automatic reward picking, other management features, speculative safeguards.
- Unverified claims about in-game behaviour.

## Release / Promotion Notes
- Main-only or release-only content to preserve: `main` currently contains the project README only.
- Known validation debt accepted for release: None; no release authorised.
- External/runtime prerequisites: WoW 1.12.1, TortoiseBots server, TortoiseBotsManager for visual/integration reference. Source repo `Seraphic8x2244/VanillaTemplate`.
- Apply canonical `dev_rulebook.md` rules, including a version bump for future addon-affecting code and runtime verification before release.

## Exact Next Step
On `dev`, inspect `dev_rulebook.md` and this `DEV_PROGRESS.md`, verify the current remote head, then add the **minimal addon `.toc` and Lua entry point**. Begin with player quest-turn-in detection and the verified bot-message parser plus the master `Hide Bot Quest Messages` checkbox. Do not implement additional features.
