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

### Next session — Chunk 2 only

Implement **Quest state and reward logic** as specified in the fixed three-chunk table above. Consume `TortoiseBotQuestControl.OnQuestMessage(parsed)`; detect **player quest hand-ins**, maintain **quest rows × tracked-bot columns**, correlate per-bot reward choices/acknowledgements (including acknowledgements with no quest ID), send `SendChatMessage("r " .. itemLink, "WHISPER", nil, botName)` with the **original item link**, and remove rows when all tracked bots resolve. Treat objective completion as distinct from a quest hand-in. Defer the completed window, item widgets and checkbox UI to Chunk 3. Do not request runtime tests. Commit to `dev`, update this file and supply a short fresh-chat Chunk 3 prompt.
---


> Single live development/status document for TortoiseBotManager-QuestControl. Structure adapted from `Seraphic8x2244/VanillaTemplate/DEV_PROGRESS.md`; canonical `dev_rulebook.md` copied unchanged from the same template.

## Current
- Branch: **`dev`**. Latest original head verified before Chunk 1: `7e08331571323bb39d5e1a22eb010ce311a1f62d`.
- Version: **`0.1.0-dev`** in `TortoiseBotManager-QuestControl.toc` (authoritative source, `Interface: 11200`).
- Latest code commit: `803971f5458cb889246a0d16c8503893176ea57d`. Latest documentation commit before this handoff: `a7e0f1b978ef9b6022f19916ad951d802d16c5dc`. **Handoff HEAD is the commit containing this status update**; verify actual remote `dev` HEAD at start of Chunk 2.
- Stable/runtime baseline: **None**. `main` remains README-only at `c1917adea82893919c987e492cce90e7b543ebcc`.
- Goal: Vanilla 1.12.1 TBM-integrated quest-by-bot reward UI / selective bot quest chat suppression.
- Current state: **Chunk 1 implemented; source static checks passed; no compiler or in-game tests**. Addon is intentionally incomplete until Chunks 2 and 3. No scope additions or branch promotion.

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
- Current handoff status-only commit: this `DEV_PROGRESS.md` revision (check branch HEAD).

## Completed / User-Verified
- The prior quest-by-bot table design, original-link commands, full English SQL template list and three-chunk boundaries are preserved.
- **No gameplay code has been user-verified.** Chunk 1 implementation is described below; it is not a stable/tested runtime build.

## Implemented / Awaiting Runtime Test
- `TortoiseBotManager-QuestControl.toc`: `Interface: 11200`, `0.1.0-dev`, optional TBM dependency/load ordering, SavedVariables and locale/core loader.
- `locales/enUS.lua`: `Hide Bot Quest Messages` label, to be displayed by the Chunk 3 checkbox.
- `QuestControl.lua`: event-frame capture for party, raid, raid leader and whisper; bot attribution only through TBM's `GetRosterEntry` / `GetClaimedEntry` rather than indiscriminate player-text matching.
- Exact English quest templates: reward-choice prompt (newline-separated item links), `reward_ack` without quest ID, handed-in (with/without item), inability, incomplete, available, accepted, already-have/completed, cannot-take variations, quest failed, objective-complete and generic quest responses. `Completed %quest_link` is **objectives complete**, not hand-in.
- Original `|Hquest:...` / `|Hitem:...` hyperlinks are retained verbatim in structured event data, including ordered `rewardOptions`. `QC.ParseQuestMessage(message)` exposes parser data; `QC.ReceiveChat(channel, message, sender)` attaches bot/channel metadata and forwards once through `QC.OnQuestMessage(parsed)` when Chunk 2 installs it.
- `TortoiseBotQuestControlDB.hideBotQuestMessages` defaults to **true**; `GetHideBotQuestMessages` / `SetHideBotQuestMessages` change display **only**. Parsing and callback dispatch are independent of visibility.
- ChatFrame legacy handler is chained (including TBM's filter); native modern filter API is supported if present. Recognised bot quest messages alone are hidden; ordinary player chat and unrelated bot messages pass through.
- **Not implemented**: hand-in tracking, rows/cells, resolution and sending reward commands (Chunk 2); TBM-style window, item icons/tooltips, checkbox widget and UI integration (Chunk 3).

## Static / Automated Checks
- **Passed:** 13 read-only source assertions on committed Lua, locale, TOC and unchanged rulebook: dev metadata/interface/version source, load order and DB, independent chat parsing, compatibility of legacy filter wrapping, original link preservation, quest objective versus hand-in, linkless acknowledgement, no introduced retries/timeouts/optional controls or obvious later-Lua constructs.
- **Not run:** Lua 5.0.3 compiler. Canonical sources were inspected at `Seraphic8x2244/VanillaTemplate/tools/lua50`, but their files were not available in the executable container; direct GitHub DNS access was unavailable. Do not infer a compiler pass.
- **Not run as expressly prohibited until Chunk 3 is complete:** runtime/in-game tests or integration validation.

## Current Issues
- Actual WoW 1.12.1 chat link wire format, potential multi-line message splitting, callback/filter order, and TBM roster readiness are **untested**. No QuestControl in-game samples yet.
- Only exact English TortoiseBots templates are parsed. Non-rostered senders are deliberately left visible to avoid hiding human chat.
- Server auto-reward routes do not provide a selectable list. A `reward_ack` does not identify the quest; Chunk 2 must correlate it with pending state without inventing timeouts/retries.

## Testing
### Last Runtime Test
- Version/commit: **None**. Passed: none; failed: none; all gameplay functions untested.

### Next Runtime Test — **after Chunk 3 only**
- Compare each party/raid/whisper bot quest message to parsed bot/quest/reward cells with hiding unchecked; repeat with hiding checked, confirming the same state/UI and only the intended chat disappearance.
- Verify original reward-link whisper command, per-bot tooltip/icon, ack correlation, row removal, and preservation of unrelated chat; validate combined TBM/WoW 1.12.1 behaviour.
- Tests/defect fixes after completion of all three chunks belong to Chunk 3 stabilization, **not a fourth chunk**.

## Planned / Next Work
- **Chunk 2 only (next fresh chat):** player quest hand-in events; quest rows × tracked-bot columns; consume `QC.OnQuestMessage`; correlate no-ID replies, resolve each bot's quest state, send the exact selected hyperlink to that bot, remove rows after all tracked bots resolve. Commit and update this handoff.
- **Chunk 3 only (later):** TBM-style UI, bot headings/classes, square icons/tooltips, one checkbox, integration and final static/compiler checks, then first end-to-end runtime testing.

## Deferred / Out of Scope
- Defer all UI and checkbox widget work to Chunk 3; no interim runtime testing.
- No server changes, automatic quest accepting/picking, additional controls, retries, arbitrary timeouts or new chunks.
- No `main` promotion or claimed release/stable baseline.

## Release / Promotion Notes
- `main` stays README-only. No release authorised; all gameplay behaviour is untested.
- Dependencies/target: native WoW 1.12.1, TortoiseBots server, optional TortoiseBotsManager API for bot attribution; TBM visual style is a Chunk 3 reference.
- `dev_rulebook.md` stays unchanged; development patch versions must increase for subsequent addon code changes.

## Exact Next Step
**Start a fresh chat for Chunk 2 of 3.** Read `dev_rulebook.md` and this `DEV_PROGRESS.md` first, verify latest `dev` HEAD against the code and this status-only handoff, and implement **player hand-in-driven quest state plus per-bot reward selection and acknowledgement correlation** through Chunk 1's structured callback. No finished UI, no runtime tests, no new chunks. Commit to `dev`, update `DEV_PROGRESS.md`, then supply the Chunk 3 prompt.
