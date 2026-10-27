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

### Chunk 3 source-implemented — first integrated runtime feedback received

All three chunks exist on `dev`; the first `0.1.2-dev` user playtest confirmed basic UI but exposed message-correlation, reward and persistence defects. The user explicitly authorized acceptance tracking, contextual per-bot `Talk`/`Accept` and manual row deletion **within Chunk 3 stabilization**. These amend the original hand-in-only/no-controls restriction **only as documented below**. No fourth chunk, server changes, rulebook changes or `main` promotion. **Direction only: no fixes implemented yet.**

---


> Single live development/status document for TortoiseBotManager-QuestControl. Structure adapted from `Seraphic8x2244/VanillaTemplate/DEV_PROGRESS.md`; canonical `dev_rulebook.md` copied unchanged from the same template.

## Current
- Branch: **`dev`**. Verified remote HEAD before this documentation update: **`8274163a51fa2af04d0dca6245436218d1d52cc9`**. Last addon code commit: **`86ca87998fb34cd58df2e14325522bc8135fb46e`**. Baseline code snapshot examined in prior stabilization review: **`10270cfb5cccfc7bac72e57f1f75f1d618a82fdd`**. Verify new handoff HEAD on resume.
- Version: **`0.1.2-dev`** from addon `.toc`, `Interface: 11200`; `main` still README-only at `c1917adea82893919c987e492cce90e7b543ebcc`. **No stable build.**
- Current goal: repair Chunk 3 integration so each tracked bot's acceptance is visibly confirmed **before the player leaves a quest giver**, without imposing explicit hand-in messages or breaking original reward choices.
- **All three chunks source-implemented. Partial user runtime test completed 2026-10-27:** UI basics passed; quest correlation/reward visibility and unresolved-state persistence showed defects. 20 historical Chunk 3 static assertions and 15/15 stabilization source checks passed against unchanged earlier source; Lua compiler not run.
- Runtime test provenance: screenshots show `0.1.2-dev` on Vanilla WoW 1.12.1/TortoiseBots/TBM; **exact installed client commit SHA is unverified**, so do not claim a specific SHA was conclusively user-tested. This update is **documentation-only**.

## Current Design / Development Contract

### Architecture / Ownership
- New QuestControl addon for WoW 1.12.1 (Lua 5.0.3), matching TortoiseBotsManager (TBM) window style and visual constants; integrate with TBM rather than replacing it.
- **Current implementation (to fix):** quest rows are triggered by the player's hand-in. **Approved redesign:** capture bot/player quest events independently and pair them regardless of order; preserve objective completion as distinct from hand-in.
- **Rows = quests; columns = tracked bots**. Column headers show bot name and class icon.
- Each bot's column displays its own reward options as **square item icons derived from the item hyperlinks sent in its chat message**.
- Mouseover uses the original item hyperlink for an in-game item tooltip.
- Clicking an icon sends the selected item's **original item link** directly to that bot: `/w BotName r [itemlink]` (equivalent API `SendChatMessage("r " .. itemLink, "WHISPER", nil, botName)`).
- A quest row disappears automatically once **all its tracked bots are resolved**; user additionally authorized a manual row `X`. Pending state must persist across reload/relog.
- **Approved exception after runtime feedback:** display bot acceptance confirmations and add contextual per-bot `Talk`/`Accept` recovery and row `X` controls. No auto-pick, unrelated quest controls, server protocol changes or broad scope additions.

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
- Preserve quest-by-bot rows/columns, original reward hyperlinks/item icons, the exact `/w BotName r [original itemlink]` command, and the master checkbox's visibility-only semantics.
- **Player-first gate is invalid:** capture relevant bot chat independently (including one-message multiline reward prompt) and correlate with player accept/hand-in whether bot or player event comes first. Match by bot and quest ID/link when known, carefully fall back to title. **No quest-chain database** or guessing an unrelated quest is a follow-up.
- **User's priority: bot acceptance confirmation.** Bots report successful acceptance; show accepted vs not-confirmed for every tracked bot when the player accepts the quest, including confirmations received earlier. A missing next acceptance suggests investigating earlier hand-in, but is **not proof** of failed hand-in.
- **Ordinary hand-ins are presumed successful** without a mandatory bot completion message. Preserve explicit negative outcomes, reward-choice prompts and their resolution; do **not** infer a reward choice or successfully received item from silence. `Completed [quest]` objective messages remain distinct.
- For missing acceptance, offer **user-clicked** whisper `Talk` (`/w BotName talk`) and then `Accept` (`/w BotName accept [original questlink]`), while near/targeting the right NPC/object. Retain relevant NPC/object identity if the Vanilla API permits. Only subsequent bot `I have accepted [quest]` confirms success; command click never implies success. Individual whisper behaviour and identity APIs **not yet verified**.
- Use SavedVariables for pending quest records, per-bot states, early messages, original hyperlinks and relevant NPC/object context. All-bots-resolved automatic removal; user-authorized manual row `X`.
- User tentatively proposed an observation timeout to flag **not confirmed** acceptance. No concrete duration, timer-driven retries or timeout deletion approved.

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
- `10270cfb5cccfc7bac72e57f1f75f1d618a82fdd` — latest prior handoff cleanup; verified actual `dev` HEAD on 2026-10-27.
- `8274163a51fa2af04d0dca6245436218d1d52cc9` — initial stabilization verification/status handoff; verified `dev` HEAD before this update.
- This commit — first runtime feedback and revised Chunk 3 direction, **documentation-only** (verify remote HEAD).

## Completed / User-Verified
- Fixed three-chunk scope preserved; Chunks 1 and 2 bot-attributed parser, hand-in rows, per-bot state, reward selection and exact original-link whispers remain intact.
- Chunk 3 implementation complete: TBM dark/gold panel, turtle icon/version from `.toc`, movable window with close/Escape, quest × bot table, class-coloured names/atlas icons, square linked item textures, in-game tooltips, waiting/choice/ack states, automatic show on new hand-in, `/tbmq` toggle, pooled widgets, horizontal/vertical scroll and a single `Hide Bot Quest Messages` checkbox.
- **First user runtime test (2026-10-27, displayed `0.1.2-dev`) passed:** load without reported errors, `/tbmq` opening, drag/close/reopen/Escape, master checkbox persistence across `/reload`. **Failed:** no bot acceptance display, stuck/no reward options or auto-award resolution, pending rows lost on reload. Exact installed commit unverified.

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
- **Lua 5.0.x compiler: NOT RUN / UNAVAILABLE here.** Host `cc` exists, but the VanillaTemplate `tools/lua50` checker is not mounted in the executable filesystem, shell GitHub access fails DNS, and no `luac5.0` or `lua5.0` exists. The GitHub connector can read sources but cannot place the vendored compiler files in this shell. The template checker's README currently identifies its vendor distribution as **Lua 5.0.2**, while the canonical rulebook refers to **5.0.3**; no checker execution or compiler pass is claimed. Do not edit the rulebook to reconcile this.
- **2026-10-27 first stabilization checkpoint:** verified `dev` HEAD `10270cfb5cccfc7bac72e57f1f75f1d618a82fdd` and `.toc` version `0.1.2-dev`; **15/15 additional read-only source checks passed**, including loader order, metadata, hide/parse independence, objective vs turn-in distinction, `GetQuestReward` chain, untouched original-item-link whisper, ack matching, native tooltip link, auto-open and single master checkbox. These are **static checks only**, not Lua compiler or in-game runtime checks.
- **Runtime tests: user performed first partial in-game test on 2026-10-27**, showing mixed results detailed below. Assistant has no client/TortoiseBots/TBM session for independent reproduction. Static checks remain distinct from actual runtime results.
- GitHub diff from verified starting HEAD to current pre-handoff code head: 5 commits, changes restricted to `QuestControl.lua`, `locales/enUS.lua`, `TortoiseBotManager-QuestControl.toc`, and `README.md`; `dev_rulebook.md` untouched.

## First Integrated Runtime Feedback / Development Direction — 2026-10-27

**Confirmed user observations** (screenshots and test report, displayed build `0.1.2-dev`):
- Quest Control loads without Lua errors; basic window navigation and hide-checkbox persistence work, but **unresolved quest rows disappear on `/reload`**.
- Bot `I have accepted [quest]` messages can precede the player's `Quest accepted` notification. The UI doesn't show per-bot acceptance; rogue missed a follow-up while warrior accepted it, forcing player backtracking.
- In `Mazzranache`, warrior **Revenwa's reward-choice prompt and items were one message**, but its reward options never appeared in Quest Control. Rogue **Revenro** auto-awarded and the UI did not show resolution; several other quests remained `Waiting for bot` despite relevant chat.
- `The Ravaged Caravan` **crate** required repeated **party** `talk` to hand in and later `accept [questlink]`; an ordinary NPC had similar manual-interaction requirements. Bot 1/2 progressed at different stages. Screenshots **do show explicit `I have completed the quest` messages** in some cases; don't claim they never exist. User reports hand-in messages may be absent/unreliable and rejects a universal hand-in-confirmation gate.

**Development direction — not yet implemented:**
1. Capture bot and player quest messages **independently of player-created rows**, retain early bot events and correlate by bot/quest even if messages arrive out of order. Current `findQuestCell` only pairs existing rows, a source-supported weakness, but the precise cause of `Mazzranache` rejection has **not** been proven exclusively by screenshot; diagnose before fixing.
2. On player quest acceptance, show confirmation for each tracked bot. **Missing acceptance of the next quest** is the actionable warning; do not wait on a universal explicit hand-in reply. Keep reward-choice requests actionable and original reward whisper links unchanged.
3. Retain NPC or object identity on player accept/hand-in where client APIs permit; offer per-bot manual `Talk` and `Accept [original questlink]` as whispers and rely on bot response, not command sending, to mark acceptance. **Party `talk` was tested; whisper variants, target/range and NPC capture remain untested.**
4. Persist pending quests, per-bot acceptance/hand-in/reward state, original links and relevant early events via SavedVariables through reload/relog. Only remove automatically when **all tracked bots resolved**, with user-authorized row `X` override.
5. Preserve native Vanilla 1.12.1, TBM bot attribution, hiding only recognised bot quest chat, quest-by-bot table, original reward logic and exact `r [itemlink]`. Any product code change must increment the patch `.toc` `-dev` version.

## Current Issues
- **Confirmed in-game:** missing acceptance visibility, original reward prompts/options not rendered, auto-award/completion not always paired, player-first correlation vulnerability, loss of pending rows on reload.
- **Not yet conclusively diagnosed:** root cause of the specific `Mazzranache` reward miss (single chat event as confirmed); sender/quest matching, events arriving before player submission, quest-title ambiguity, multi-channel behaviour.
- **To verify:** NPC/object identity in 1.12.1 API; whisper `talk`/`accept` response and range; saved-state replay without false matches; original reward option/link accuracy; duplicate/late replies; observation window timing if needed. No arbitrary timeout/retry selected.
- **Other open checks:** canonical Lua compiler check not run; tooltip, cached item textures, scrolling under load, chat filter coexistence, TBM roster timing.
- No source fixes yet; do not mark new design or these integration defects stable.

## Testing
### Last Runtime Test
- **2026-10-27 — first partial user-integrated Vanilla WoW 1.12.1/TortoiseBots/TBM test, displayed `0.1.2-dev`. Installed code commit unverified.**
- **PASS:** addon/TBM load without reported errors; `/tbmq`, window dragging, close/reopen/Escape, checkbox setting persistence across `/reload`.
- **FAIL:** unsaved pending rows after reload; lack of bot acceptance confirmation; `Mazzranache` reward-choice and auto-award outcomes not reflected despite party/chat evidence.
- **Observed externally:** bot acceptance can precede player notification; manual party `talk` and `accept [questlink]` needed for crate and ordinary NPC, with bots progressing differently. Individual whispers and revised UI not tested.
- No stable/released or fully runtime-verified addon baseline.

### Next Runtime Test — after Chunk 3 stabilization fixes
1. Verify acceptance-by-bot when bot acceptance occurs **before** and **after** the player's notification; no false confirmation for missing bot.
2. Reproduce `Mazzranache` single-message multi-choice prompt and rogue auto-award; verify per-bot options, native original-link tooltips, exact `r [original itemlink]` whisper and resolution.
3. Verify ordinary NPC/crate hand-in without mandatory completion message and per-bot **whisper** `talk` then `accept [original questlink]` near targeted quest giver; no false acceptance on action click.
4. Verify SavedVariables pending/early event/reward recovery over reload/relog, all-bots-resolved removal and deliberate row `X` deletion.
5. Verify hide-chat parity, party/raid/whisper matching, duplicate/same-title handling, scrolling/checkbox, no Lua errors. Record exact version **and installed commit** if possible.

No fourth chunk; do not infer any untested stage from an adjacent pass.

## Planned / Next Work
- **This update is status-only.** Next implementation session: inspect quest/chat event pipeline, `GetQuestReward`/acceptance hooks, `Talk`/`Accept` bot protocol and target API, then implement only these approved Chunk 3 stabilization fixes, preserving existing reward-selection command.
- After addon-affecting code changes, bump `.toc` patch `-dev` version; run source/compiler checks where executable and request targeted user runtime retests.

## Deferred / Out of Scope
- No fourth chunk, server changes, prebuilt quest-chain database, auto-accept/auto-pick feature, unrelated controls, arbitrary automatic retry/timeouts, architecture splitting or changes to `dev_rulebook.md`. Original no-acceptance-UI limitation is explicitly amended only for requested acceptance status and recovery actions.
- No `main` promotion or stable/released claims until the changed addon is actually tested; canonical compiler pass is still outstanding.

## Release / Promotion Notes
- `main` stays README-only; no release authorized or performed.
- Dependencies/target: native WoW 1.12.1, Lua 5.0.3, TortoiseBots server, optional TortoiseBotsManager API for identifying/tracking bots. Missing TBM makes reliable bot identification unavailable in the existing core.
- `dev_rulebook.md` is unchanged. Development patch version increased from `0.1.1-dev` to `0.1.2-dev`; neither Lua compilation nor runtime compatibility may be claimed from static source assertions.

## Exact Next Step
**Resume Chunk 3 stabilization, not new development chunk:** read unchanged `dev_rulebook.md` and this `DEV_PROGRESS.md`; verify actual remote `dev` HEAD, `.toc` `0.1.2-dev` and latest code SHA. Investigate player-first message dropping and single-message reward processing; design persistent order-independent correlation and acceptance-by-bot display, with approved manual `Talk`/`Accept` and row `X` controls. Verify NPC/object capture and whisper semantics before relying on them. Preserve original linked reward logic and presume routine hand-ins successful without universal completion gate. **No code changes were part of this feedback-recording commit.** Run compiler and user in-game retests against exact later code version; no rulebook edits, Chunk 4 or `main` promotion.
