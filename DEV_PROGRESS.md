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

### Chunk 3 complete — first integrated runtime test next

All three fixed implementation chunks now exist on `dev`. Chunk 3 adds the TBM-styled window with quest rows × tracked-bot columns, class icons/names, original linked reward icons and tooltips, single hide-chat checkbox, scrollable layout, `/tbmq` reopening, and state-change integration. **No in-game validation has occurred**; initial 1.12.1 runtime tests and resulting defect fixes are Chunk 3 stabilization, not a new chunk.

---


> Single live development/status document for TortoiseBotManager-QuestControl. Structure adapted from `Seraphic8x2244/VanillaTemplate/DEV_PROGRESS.md`; canonical `dev_rulebook.md` copied unchanged from the same template.

## Current
- Branch: **`dev`**. Verified Chunk 3 starting HEAD: **`292db94d7a9845553c9918dd43aacaa1203fceea`** (identical to remote `dev` before changes). Last code commit: **`86ca87998fb34cd58df2e14325522bc8135fb46e`**. README commit: **`3a61c448fe176c4185d2ae89ccade8ecda0a3514`**. The handoff commit is the commit carrying this document; verify remote HEAD on resume.
- Version: **`0.1.2-dev`** from `TortoiseBotManager-QuestControl.toc`, `Interface: 11200`.
- Stable/runtime baseline: **None**. `main` remains README-only at `c1917adea82893919c987e492cce90e7b543ebcc`.
- Goal: Vanilla 1.12.1 TBM-styled, quest-by-bot reward UI and selective quest-chat hiding.
- Current state: **All 3 fixed chunks implemented on `dev`**; 20 read-only static source assertions passed after final integration. **Lua 5.0.3 compiler and gameplay/runtime tests NOT run.** This is a candidate for the *first* integrated user runtime test, not a stable or released build.

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
- `c1917adea82893919c987e492cce90e7b543ebcc` — initial `main` README/stable repository baseline (not a tested addon release).
- `74287939a60c194169662bb8d54e5aeb7a8c80b2` — canonical unchanged rulebook.
- `7e08331571323bb39d5e1a22eb010ce311a1f62d` — fixed three-chunk contract.
- `803971f5458cb889246a0d16c8503893176ea57d` — Chunk 1 message handling.
- `8e40699b2ed51adb1bd5884e15cf58f40add8532` — Chunk 1 handoff.
- `92a93746476923cda03e0a369cc697bcd7937766` — Chunk 2 quest and reward state.
- `292db94d7a9845553c9918dd43aacaa1203fceea` — verified Chunk 2 handoff / Chunk 3 starting HEAD.
- `f7ea430edaf80bc9c3522f6d53f9d1235e0beb49` — `.toc` bump to `0.1.2-dev`.
- `11e79cd688ec543f2867d6775ddf6b01e053aa8a` — window/status locale strings.
- `e02008aa7bbbb1bd9259ab42a0359b623cd89e17` — TBM-style UI, class headers, per-bot rewards, scrolling, checkbox and integration.
- `3a61c448fe176c4185d2ae89ccade8ecda0a3514` — README window usage and testing status.
- `86ca87998fb34cd58df2e14325522bc8135fb46e` — extract original item-link payload for native tooltip API.
- Handoff/status-only commit: this `DEV_PROGRESS.md` revision (verify exact remote `dev` HEAD).

## Completed / User-Verified
- Fixed three-chunk scope preserved; Chunks 1 and 2 bot-attributed parser, hand-in rows, per-bot state, reward selection and exact original-link whispers remain intact.
- Chunk 3 implementation complete: TBM dark/gold panel, turtle icon/version from `.toc`, movable window with close/Escape, quest × bot table, class-coloured names/atlas icons, square linked item textures, in-game tooltips, waiting/choice/ack states, automatic show on new hand-in, `/tbmq` toggle, pooled widgets, horizontal/vertical scroll and a single `Hide Bot Quest Messages` checkbox.
- **No gameplay has been user-verified; all implemented paths remain runtime-untested.**

## Implemented / Awaiting Runtime Test
- `TortoiseBotManager-QuestControl.toc`: `Interface: 11200`, `Version: 0.1.2-dev`, `OptionalDeps: TortoiseBotsManager`, unchanged locale/core loader order and DB declaration; no additional loader modules.
- `locales/enUS.lua`: label, headings, empty state, per-cell statuses. No additional checkbox or quest action buttons.
- `QuestControl.lua` parser, `QC.ReceiveChat`, visibility-only `QC.SetHideBotQuestMessages`, player `GetQuestReward` chaining, quest rows, `QC.GetQuestRows()`, `QC.GetBotColumns()`, `QC.OnQuestMessage` and `QC.ChooseReward` unchanged in business logic. `objectives_completed` remains distinct from turn-in. Exact `SendChatMessage("r " .. option.link, "WHISPER", nil, botName)` remains.
- `QC.InitUI()` is invoked after DB/filter/hook initialization on addon load. `QC.OnStateChanged()` calls `QC.RefreshUI()`, auto-opens on new hand-in, and respects manual close between bot responses.
- Icon images use `GetItemInfo(option.link)` or `GetItemIcon(option.id)` with question-mark fallback if unavailable; native `GameTooltip:SetHyperlink` receives the `item:...` payload extracted from that bot's **original** option link, not a synthetic reward link. `QC.ChooseReward` continues to receive the same row key, bot name and option index.
- Window can be reopened via `/tbmq`; only ordinary UI navigation (close and scrolling) was added. No server changes, timeout/retry mechanism or new chunk.

## Static / Automated Checks
- **Chunk 1 passed:** 13 preexisting source assertions (historical).
- **Chunk 2 passed:** 10 preexisting structural assertions (historical).
- **Chunk 3 passed:** 20 read-only source assertions, covering **byte-for-byte equality of the original parser/reward business logic after comment-only normalization**, exact linked whisper, state ownership and callback, hand-in hook initialization, 1 checkbox, tooltip payload taken from original link, per-bot link-based icons, class headers, two-axis scroll, loader/version, all new localized strings, no obvious later-Lua syntax/APIs, no speculative timeout code, and a GitHub comparison confirming only intended files changed. Total `local` tokens counted in file: 145 (a coarse source observation, **not** a Lua compiler limit proof).
- **Lua 5.0.3 compiler: NOT RUN / UNAVAILABLE here.** Host `cc` exists, but the canonical VanillaTemplate `tools/lua50` checker is not present in the executable filesystem, direct GitHub access from the shell fails DNS, and no `luac5.0` or `lua5.0` exists. The GitHub connector can read sources but cannot turn them into an executable checker in this shell. **No compiler pass claimed.**
- **Runtime/in-game tests: NOT RUN** (prohibited until all three chunks were implemented; first test is now permitted).
- GitHub diff from verified starting HEAD to current pre-handoff code head: 5 commits, changes restricted to `QuestControl.lua`, `locales/enUS.lua`, `TortoiseBotManager-QuestControl.toc`, and `README.md`; `dev_rulebook.md` untouched.

## Current Issues
- `GetQuestReward` is a client submission, not a server acknowledgement; quest-frame timing, quest title ambiguity for repeated/same-title quests and success/error ordering are unverified.
- Linkless same-item acknowledgements for the same bot choose the oldest pending matching selection; actual response ordering is untested.
- Multi-line reward delivery, party/raid/whisper sender attribution, TBM roster readiness, optional TBM dependency, auto-pick outcome and chat-filter coexistence remain untested.
- UI-specific: exact 1.12 class atlas coordinates, scroll frame/slider behavior, checkbox persistence and tooltip parsing are not runtime tested. Uncached item links can show a question-mark texture until the item is cached and the UI redraws. No speculative polling or refresh timeouts added.
- No Lua 5.0.3 compiler run; static assertions are not gameplay or compiler validation.

## Testing
### Last Runtime Test
- **None**. Version/commit tested in the game: **none**. Passed: none; failed: none.

### Next Runtime Test — first full integrated Chunk 3 validation
1. Load `0.1.2-dev` with TBM on actual WoW 1.12.1. Open/close via `/tbmq`, drag/close/Escape and verify only one master checkbox persists across reloads.
2. With one or more tracked bots grouped, hand in a quest. Verify a row appears for that player hand-in and columns show correct bot name/class, including UI scrolling with multiple rows/bots. Ensure `Completed %quest_link` alone does not create/resolve a row.
3. Hand in a multi-choice quest; compare each bot's square icons and native tooltips with the original link(s) in its own reward message. Click a choice and verify the exact `/w BotName r [original itemlink]` action, resulting response, linkless acknowledgement matching and all-bots-resolved row removal.
4. Repeat party/raid/whisper quest traffic with hiding unchecked and checked. UI/reward states must match; only recognised bot quest messages disappear when checked; ordinary player/unrelated bot chat stays visible.
5. Verify auto-awarded/no-choice quests, failed/incomplete/unable responses, duplicate item IDs and same-title quests where possible. Record exact failures and their circumstances; do **not** declare stable without successful testing.

Any issues discovered in these tests are **Chunk 3 stabilization**, not a fourth implementation chunk.

## Planned / Next Work
- **All fixed implementation chunks completed.** Next action: first integrated **user** runtime test of `0.1.2-dev` after confirming the final code/handoff commit. Address confirmed defects within Chunk 3 stabilization without changing the agreed scope.

## Deferred / Out of Scope
- No additional chunks, server changes, quest pickup/auto-pick UI, unrelated controls, arbitrary retry/timeout machinery, architecture splitting or editing `dev_rulebook.md`.
- No `main` promotion, stable/released label or user-tested status until actual in-game evidence exists. Lua 5.0.3 canonical compiler pass remains outstanding wherever its executable source becomes available.

## Release / Promotion Notes
- `main` stays README-only; no release authorized or performed.
- Dependencies/target: native WoW 1.12.1, Lua 5.0.3, TortoiseBots server, optional TortoiseBotsManager API for identifying/tracking bots. Missing TBM makes reliable bot identification unavailable in the existing core.
- `dev_rulebook.md` is unchanged. Development patch version increased from `0.1.1-dev` to `0.1.2-dev`; neither Lua compilation nor runtime compatibility may be claimed from static source assertions.

## Exact Next Step
**Resume in a fresh chat for Chunk 3 runtime stabilization.** Read `dev_rulebook.md` and `DEV_PROGRESS.md`, verify remote `dev` HEAD and `0.1.2-dev`. Perform the numbered first end-to-end runtime checks on actual Vanilla WoW 1.12.1/TortoiseBots/TBM, report results bound to exact tested commit/version, and fix only confirmed integration issues within Chunk 3. Run canonical Lua 5.0.3 compilation whenever checker sources are accessible in an executable environment. Do not create Chunk 4 or promote to `main`.

