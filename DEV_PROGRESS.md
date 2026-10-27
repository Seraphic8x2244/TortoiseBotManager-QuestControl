# Development Progress

## Fixed three-chunk implementation plan — authoritative

**Exactly three implementation chunks, one fresh development chat per chunk. No fourth chunk and no additional subdivision.** The chunks are work/handoff boundaries, not independent releases or independently functional builds. The addon is not expected to work end-to-end until **all three are implemented**.

| Chunk / chat | Scope | Deliverable |
| --- | --- | --- |
| **1 — Foundation and message handling** | Create the Vanilla 1.12.1 `.toc`, Lua entry point, initialization and necessary localization; handle bot identification, recognised quest messages, item/quest hyperlinks, party/raid/whisper event capture, chat interception, and the global `Hide Bot Quest Messages` setting. Parsing works identically whether chat suppression is enabled or not. | Message-handling foundation and structured data for later logic. No standalone working build required. |
| **2 — Quest state and reward logic** | Detect **player quest hand-ins**, maintain **quest rows × tracked-bot columns**, correlate bot messages and reward responses (including replies with no quest identifier), track per-bot choices and resolution, send `/w BotName r [itemlink]` with the **original item link**, and remove rows when all tracked bots resolve. | Complete internal quest/reward logic, ready for the final UI. No standalone working build required. |
| **3 — Interface and final integration** | Implement the TBM-styled window, quest rows, bot headers/classes, square reward icons, hyperlink tooltips and checkbox UI; connect all systems, repair integration issues, and perform static and Lua 5.0.3/WoW 1.12.1 compatibility checks where available. | Fully implemented addon ready for its first end-to-end runtime test. |

### Fixed boundaries and testing policy

- **No runtime or in-game testing between chunks.** Do not require intermediate builds to function independently or add interim runtime-testing milestones.
- Runtime testing begins **only after all three chunks are implemented**. First integrated tests and resulting defect fixes belong to the completion/stabilization of Chunk 3, not a fourth chunk.
- Static review and Lua 5.0.3 compiler checks are permitted during development when actually available, but must never be represented as runtime tests.
- Keep the project scope and detailed behavioural invariants below unchanged. Do not add server changes, unsolicited controls, retry/timeout safeguards, or artificial module splits just to match chat boundaries.
- **End-of-chunk handoff:** Commit coherent code/status to `dev` and update this file with branch, exact commit(s), `.toc` version, completed work, untested work, deferred work and exact next step. Keep `dev_rulebook.md` unchanged.
- **Mandatory next-chat prompts:** At the end of Chunk 1, provide a **short copy-paste prompt for Chunk 2**. At the end of Chunk 2, provide the same for Chunk 3. Each fresh chat must read the rulebook and this status document and verify remote `dev` HEAD before changing code.

### Next session — Chunk 3 only

Implement the fixed **Interface and final integration** chunk: the TBM-styled quest-by-bot window, bot name/class headers, square icons from actual reward links with tooltip support, and one `Hide Bot Quest Messages` checkbox. Wire `QC.GetQuestRows()`, `QC.GetBotColumns()`, `QC.ChooseReward(rowKey, botName, optionIndex)`, and `QC.OnStateChanged`. Preserve original links, state and parser semantics. Run static/compiler checks where available, then prepare first runtime tests **only after** all three chunks exist. No new chunks, unsolicited controls, timeouts, server modifications or rulebook edits.

---


> Single live development/status document for TortoiseBotManager-QuestControl. Structure adapted from `Seraphic8x2244/VanillaTemplate/DEV_PROGRESS.md`; canonical `dev_rulebook.md` copied unchanged from the same template.

## Current
- Branch: **`dev`**. Chunk 2 verified starting HEAD: `8e40699b2ed51adb1bd5884e15cf58f40add8532`. Chunk 2 code commit: **`92a93746476923cda03e0a369cc697bcd7937766`**. Current handoff HEAD: the status-only commit containing this revision (verify actual remote HEAD when resuming).
- Version: **`0.1.1-dev`** from `TortoiseBotManager-QuestControl.toc` (`Interface: 11200`).
- Stable/runtime baseline: **None**; `main` remains README-only at `c1917adea82893919c987e492cce90e7b543ebcc`.
- Goal: Vanilla 1.12.1 TBM-integrated quest-by-bot reward UI and selective bot quest-chat suppression.
- Current state: **Chunks 1 and 2 implemented; static source assertions passed; no Lua 5.0.3 compiler or runtime tests.** Integration remains intentionally incomplete until Chunk 3. No releases or promotions.

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
- `c1917adea82893919c987e492cce90e7b543ebcc` — initial `main` README.
- `74287939a60c194169662bb8d54e5aeb7a8c80b2` — canonical unchanged rulebook.
- `231a3e02522e7ecfa97224d1b22b43d97c808962` — initial protocol/design.
- `7e08331571323bb39d5e1a22eb010ce311a1f62d` — fixed three-chunk contract.
- `1cf87ff9bee052f7a56fa933bb4e8727127f6550` — Chunk 1 `.toc`.
- `da988457bd307abf9c87e326f9419e43d57c5415` — localization label.
- `803971f5458cb889246a0d16c8503893176ea57d` — core message-handling foundation.
- `a7e0f1b978ef9b6022f19916ad951d802d16c5dc` — README Chunk 1 status.
- `8e40699b2ed51adb1bd5884e15cf58f40add8532` — verified Chunk 1 handoff/Chunk 2 starting HEAD.
- `92a93746476923cda03e0a369cc697bcd7937766` — Chunk 2 reward/hand-in state; version 0.1.1-dev.
- Current handoff status-only commit: this `DEV_PROGRESS.md` revision (check remote `dev` HEAD).

## Completed / User-Verified
- Fixed three-chunk plan, original-link whisper contract, full English quest templates and quest-by-bot table design preserved.
- Chunk 1: bot-attributed chat parser, original hyperlinks, channel capture and visibility-only chat suppression retained.
- Chunk 2: player hand-in capture; grouped bot snapshot, quest rows/bot cells, per-bot reward choice/ack handling, original-link whispers and removal once all tracked bots resolve.
- **No gameplay has been user-verified; no standalone stable build exists.**

## Implemented / Awaiting Runtime Test
- `TortoiseBotManager-QuestControl.toc`: `Interface: 11200`, **`0.1.1-dev`**, same loader and optional TBM dependency.
- Chunk 1 `QuestControl.lua`: `ParseQuestMessage`/ `ReceiveChat`/ recognised chat hiding remain unchanged. Full item/quest link records are passed into `QC.OnQuestMessage(parsed)`; `objectives_completed` is not a hand-in.
- Native `GetQuestReward` is chained and its visible reward-frame quest title captured at final player reward submission. Rows are created for currently grouped, known bots using client group units plus TBM's server-owned `GetGroupedBotNames()` snapshot; not from `QUEST_COMPLETE` or chat objectives.
- `QC.GetQuestRows()`, `QC.GetTrackedBots()`, `QC.GetBotColumns()`, `QC.RecordPlayerHandIn(title)`, and optional `QC.OnStateChanged()` support Chunk 3. Each ordered quest row has stable key/title, bound quest-link ID when learned, bot names, per-bot metadata/options/selection/status/result.
- `QC.ChooseReward(rowKey, botName, optionIndex)` whispers the bot **`SendChatMessage("r " .. option.link, "WHISPER", nil, botName)`**, using the original linked reward item exactly. The cell awaits a bot response.
- Bot `reward_ack` without a quest ID matches bot + selected item ID against the oldest eligible pending cell. Quest-linked `turned_in`, `turned_in_reward`, `unable_to_turn_in`, `incomplete`, `already_completed`, and `failed` resolve per-bot cells; when all tracked bots are resolved, the row is removed. Other message kinds do not change hand-in state.
- **Not implemented** (Chunk 3): window, bot headers/class icons, square reward icons/tooltips, checkbox widget, and complete end-to-end UI integration.

## Static / Automated Checks
- **Chunk 1 passed:** previously documented 13 read-only source assertions.
- **Chunk 2 passed:** 10 structural assertions on the generated Lua, README and TOC: scoped hand-in hook, version/interface, quest/objective distinction, bot+item acknowledgement matching, original-link reward command, row removal, no new UI/loader module and Lua 5.0-compatible source conventions. The GitHub commit comparison verified `92a93746476923cda03e0a369cc697bcd7937766` is one commit ahead of the verified base and modifies only `QuestControl.lua`, `README.md`, and the `.toc` (rulebook untouched).
- **Not run:** Lua **5.0.3 compiler**. The canonical VanillaTemplate checker was not available in the executable container and container GitHub cloning failed due to DNS; source assertions are not a compiler pass.
- **Not run:** runtime/in-game tests (prohibited until Chunk 3 complete).

## Current Issues
- `GetQuestReward` is a client hand-in submission, not a server-confirmation event; actual reward completion, success/error ordering and 1.12 frame behaviour remain unverified.
- Vanilla quest log has no native quest ID in `GetQuestLogTitle`. First match uses the player's quest title (bot link display brackets removed), then binds the bot's quest-link ID. Same-name distinct or repeatable quests may be ambiguous before binding.
- Linkless reward acknowledgements sharing identical item IDs for the same bot use oldest eligible pending selection; exact server sequencing is untested. Other linkless notices are not assigned to quests.
- TBM group/roster readiness, the order of bot responses, multi-line rewards, whisper/item hyperlink format, UI notifications and server auto-pick outcomes remain untested.

## Testing
### Last Runtime Test
- Version/commit: **None**. Passed: none; failed: none; all gameplay functions untested.

### Next Runtime Test — **after Chunk 3 only**
- Compare each party/raid/whisper bot quest message to parsed bot/quest/reward cells with hiding unchecked; repeat with hiding checked, confirming the same state/UI and only the intended chat disappearance.
- Verify original reward-link whisper command, per-bot tooltip/icon, ack correlation, row removal, and preservation of unrelated chat; validate combined TBM/WoW 1.12.1 behaviour.
- Tests/defect fixes after completion of all three chunks belong to Chunk 3 stabilization, **not a fourth chunk**.

## Planned / Next Work
- **Chunk 3 only:** TBM-style quest-by-bot UI, class headings, square reward icons with original-link tooltip, one hide-chat checkbox, integration fixes and relevant static/5.0.3 compiler checks if available. Complete all three chunks before first runtime tests; testing and defect fixes remain in Chunk 3, not a fourth.

## Deferred / Out of Scope
- Window, icon, tooltip and checkbox widget implementation deferred strictly to Chunk 3. No runtime tests between chunks.
- No server modifications, accepting/auto-picking quests, unrelated controls, retry/timeout machinery, split modules or extra chunks.
- No `main` promotion, stable/released label or gameplay validation claims.

## Release / Promotion Notes
- `main` stays README-only. No release authorised; all gameplay behaviour is untested.
- Dependencies/target: native WoW 1.12.1, TortoiseBots server, optional TortoiseBotsManager API for bot attribution; TBM visual style is a Chunk 3 reference.
- `dev_rulebook.md` stays unchanged; development patch versions must increase for subsequent addon code changes.

## Exact Next Step
**Start a fresh chat for Chunk 3 of 3.** Read `dev_rulebook.md` and this `DEV_PROGRESS.md` first; verify the actual remote `dev` HEAD against this status-only handoff. Build the TBM-styled window and full quest-by-bot UI on top of Chunk 2 commit `92a93746476923cda03e0a369cc697bcd7937766`, integrate the existing APIs, preserve exact original link commands and Vanilla 1.12.1/Lua 5.0.3 compatibility, and run static/compiler checks where available. Only begin runtime testing after all three chunks are implemented; do not edit the rulebook or invent a fourth chunk.
