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

### Chunk 3 stabilization — two narrowly scoped chat filters pending runtime verification

`0.1.4-dev` added the resolved-row 7-second hold plus 3-second fade. **User has now confirmed the fade works in-game with one bot**, but multi-bot and reward outcomes are untested. `0.1.5-dev` replaces the single chat-filter checkbox with **Filter Owned Bot Messages** and **Filter Other Bot Messages**. Only recognised/parsed quest-template messages on the existing party/raid/whisper channels qualify. TBM's owned roster/claimed lookups classify the first group authoritatively. Senders outside TBM's owned roster are classified as 'other' **for filtering only**, using the same template match: this is not independent proof they are bots, so a non-bot deliberately emitting an identical template can also match. Owned-bot quest state processing remains unchanged, regardless of either filter setting. Migrate the old checkbox's explicit value to the owned setting; both filters default OFF on fresh installs as of `0.1.7-dev`. Existing saved preferences are preserved. `The Harvest Golem Mystery` incomplete-hand-in bug remains **unfixed**.

Only filter settings/UI labels, configuration migration and documentation changed. No parser, quest classification, reward commands, acceptance/hand-in hooks, quest data, server changes, rulebook changes, Chunk 4, or `main` promotion. Source-implemented; Lua 5.0.3 compiler and runtime testing of `0.1.5-dev` outstanding.

---


> Single live development/status document for TortoiseBotManager-QuestControl. Structure adapted from `Seraphic8x2244/VanillaTemplate/DEV_PROGRESS.md`; canonical `dev_rulebook.md` copied unchanged from the same template.

## Implemented Revision — Compact QuestControl UI + TBM Quest Button (`0.1.6-dev`, in-game verification pending)

**Implemented scope (`7287ed9` + `892d109`):** Replaced the oversized ~690×470 window with a compact, class-coloured quest-by-bot matrix inspired by `Seraphic8x2244/pfQuest_Group` (`main`). Includes near-23px ordinary rows, contextual Blizzard !/? art, direct linked item choices, ready-check positive/negative/unknown status symbols, gossip Talk, clipboard Accept, trash Remove, compact settings popover, adaptive two-axis scrolling and persistent resize/move. TBM's Quest button is styled by `TB.StyleButton`, positioned relative to `TB.infoButton`, re-anchors the drag overlay and retries after late TBM UI init; no TBM source changes. The new UI is source-implemented, not yet in-game validated.

### TBM header entry point
- Create a **Quest** button, immediately **LEFT** of TBM's existing **Info** button, with visual parity to Info/Mini: `TB.StyleButton(CreateFrame("Button", nil, TB.frame, "UIPanelButtonTemplate"))`, 44×20, matching spacing, label and tooltip. **Anchor it relatively to `TB.infoButton`**, e.g. `quest:SetPoint("RIGHT", TB.infoButton, "LEFT", -4, 0)`. Do **not** use guessed absolute header coordinates or alter TBM's source.
- TBM's `UI.lua` exposes `TB.infoButton`, `TB.dragHeader` and `TB.frame` after `TB.InitUI`. Its mouse-enabled drag header currently ends at Info; when adding Quest to the left, **re-anchor that drag-header boundary to Quest** and set the new button at an appropriate higher frame level so the overlay does not intercept clicks. Do not break Info/Mini/close or header dragging. Initialize only once when TBM UI is ready, including late UI initialization; gracefully handle absent TBM frame. Avoid stale/duplicate button creation.
- Clicking Quest toggles the QuestControl window; preserve `/tbmq`, close and Escape behaviours.

### Compact window — visual contract
- Heavily follow **pfQuest_Group**: near-20px high rows when possible, low-profile title, minimal borders/spacing, compact scrollable body, resizing, movable/persisted position/size and optional pfUI skin where available with a native fallback. Default footprint **far smaller** than existing QuestControl, but width must accommodate full class-coloured bot names and reward icons; size should adapt gracefully to grouped bot count and available screen space rather than enforcing an unusably narrow 300px grid.
- Preserve the **quest-row × grouped-owned-bot-column matrix**. **Only quest names and bot names as persistent visible text**. No persistent stage labels, status sentences, explanations, oversized buttons or toolbars.
- **Quest cell:** Blizzard quest art `Interface\\GossipFrame\\AvailableQuestIcon` (`!`) for pickup/acceptance; `Interface\\GossipFrame\\ActiveQuestIcon` (`?`) for hand-in/reward context, then the quest title. Tooltip for truncated titles/context if useful.
- **Bot headers:** existing class icon followed by **full** bot name, class-coloured. Preserve per-bot identity and usable widths, with scrolling for many bots.
- **Bot status icons:** green tick for confirmed positive, red X for confirmed negative, neutral question mark for genuinely unconfirmed. Do not equate missing bot reply with failure. Icon hover reveals meaning.
- **Reward selection:** **all original linked reward item icons visible directly in the relevant bot cell** (no generic reward icon and no click-to-expand step). Allow that specific row to grow/wrap only to fit item icons; item hover shows the original game item tooltip; clicking sends the exact original `/w BotName r [itemlink]` command. Preserve per-bot choice differences.
- **Minimal recovery/removal controls, existing artwork only:** Remove = `pfQuest_Group/assets/trash-2.tga` (bin) on quest row; Talk = Blizzard `Interface\\GossipFrame\\GossipGossipIcon`; Accept = `pfQuest_Group/assets/clipboard-check.tga`. Use small icon hit targets with meaningful tooltips, show recovery only when applicable, and never imply bot success on a recovery click. Copy only the needed TGA assets into QuestControl's own `assets/` (respect upstream licence) so pfQuest_Group need not be installed. Blizzard textures stay referenced natively. No new art, speechbox/thumbsup drawing or wordy replacements.
- **Settings:** put existing independent **Filter Owned Bot Messages** and **Filter Other Bot Messages** checkboxes behind a compact settings/gear control, away from the main quest matrix. Preserve settings values, migration and exact successfully-parsed-message-only filtering semantics.

### Behaviour and scope boundaries
- **Presentation/integration redesign only**: retain the existing order-agnostic quest observations, TBM roster/claimed authority, acceptance/recovery and per-character saved state, independent owned/other filtering, original hyperlinks/tooltips/whisper commands, manual dismissal, 7-second hold plus 3-second resolved-row fade, and silent hand-in behaviour.
- **Do not fix or conflate** the separately reported `The Harvest Golem Mystery` erroneous *Hand-in / Not complete* row in this UI revision. Do not reinterpret bot messages, alter parser, introduce auto-accept, quest database, server changes, unrelated controls or a fourth chunk.
- Bump addon `.toc` to **`0.1.6-dev` when implementation actually changes**, keep `dev_rulebook.md` unchanged, use only WoW 1.12.1/Lua 5.0.3 compatible APIs and update `DEV_PROGRESS.md`. No release or `main` promotion.

### Acceptance / runtime checks (pending user test)
1. TBM **Quest | Info | Mini | X** button spacing/style/clicks, correct **relative Info anchoring**, drag-header hit testing, load order, TBM Mini mode, and `/tbmq` toggle.
2. Compact pfQuest_Group-like look under one bot, multiple bots and longer class-coloured full names; move/resize/scroll/persist window size/position.
3. Blizzard `!`/`?` quest art, per-bot green tick/red X/neutral ?, remove bin, gossip Talk, clipboard Accept; accurate hover tooltips without visible prose.
4. Direct all-item icon reward choices, hover tooltip and exact original whisper; action availability without a captured original quest hyperlink; per-bot state.
5. Settings gear/two independently persisted filters, chat parsing unaffected, existing 10-second resolved-row fade and manually dismissed rows.
6. Relevant source checks and the **canonical Lua 5.0.3 compiler check when executable tools are available**. Record checks honestly; in-game validation is separate. No release.

## Narrow Runtime Feedback Fix — `0.1.8-dev` (implemented, awaiting in-game verification)

User screenshot of compact QuestControl alongside pfQuest_Group showed the `Patrolling Westfall` reward-choice row unnecessarily tall. The floating "Choose a reward" hover was the neutral **status icon button**, not an actual reward-item button. The old layout reserved 22px for that status and placed the linked reward choices on a second line; the row-height formula then forced 45px for even two items. **Now:** hide the redundant status icon only when that bot has live reward choices/awaits an ack, render all original item icons at the top of the bot cell, and keep a normal 23px row for the first line (wrap only when choices exceed the column). Item tooltips, selection highlights and original `r [itemlink]` whisper are unchanged.

The corner resize interaction already worked but its Blizzard `UI-ChatIM-SizeGrabber-Up` texture rendered blank. It now uses small native solid-colour texture marks for a visible grip without requiring a client-specific atlas; dragging, persisted size and highlights remain.

Also reported: a bot's explicit **`I have completed the quest [questlink]`** was not shown as a green tick. The existing parser already classified `turned_in` and `turned_in_reward`, but a silent assumed-success hand-in row can be removed before that late bot message, leaving no row to render. When there is no matching reward/hand-in row, **only an explicit linked completion** now creates a short-lived `handin` confirmation row, marks the confirming bot resolved (green tick and "Quest handed in" hover), leaves other bots neutral, and uses the unchanged 7s hold + 3s fade. A later confirming bot refreshes that display. Ordinary silent assumed-success hand-in cleanup remains intact. No change to the separately deferred `The Harvest Golem Mystery` stage-classification issue.

**Implementation:** `6f2c41b873518acfd6b540b6ba2a3885fa3d4cb4`, TOC `0.1.8-dev`; source checks **15/15 passed** for previous parser/filters/recovery/hook/reward-command invariants, only-explicit-positive row creation, neutral other-bot status, inline reward choices, wrap-height mathematics, visible grip and fade. No Lua 5.0.3 compiler pass or in-game test of this new code; rendering and message sequencing need user verification.

## Follow-up Visual and Scroll Fix — `0.1.9-dev` (source-implemented; runtime test pending)

**Feedback on `0.1.8-dev`:** User confirmed **(1) reward-choice row height FIXED in-game**. **(2) Resize grip markings visible for a friend, not visible for the user** despite hover/highlight and working drag. **(3) Neither green tick nor red cross visibly renders.** Additionally, **horizontal scroll is backwards**: dragging its thumb right reveals less of the bot columns instead of more. This is not proof that bot completion messages failed to parse; the status art can be absent separately from state correlation. The prior `0.1.8-dev` explicit linked completion-row creation remains untouched.

**`537c3667a29d91515036b31b77008a3196c612db` / `0.1.9-dev`:** Replace client-dependent `Interface\\RaidFrame\\ReadyCheck-*` status textures with three bundled 32×32 alpha TGA marks (`status-yes` green check, `status-no` red cross, `status-neutral` neutral question), all drawn at existing 15×15 hit targets with original status tooltips. The earlier 16px resize-grip with 2px glyph dots is now 20px with high-contrast dark backing, larger 4px golden glyph marks in the OVERLAY layer and higher frame level, still using native Vanilla solid-colour texture primitives. Negate the horizontal scroll offset consistently in the slider callback **and** UI refresh so slider value zero remains the initial leftmost quest column while thumb-right motion scrolls toward farther-right bot columns on the user-reported 1.12 client. Preserve positive-message parser, existing `0.1.8-dev` explicit-positive confirmation display path/7+3 fade, reward icon row sizing, filters and exact whisper commands.

**Checks:** 11/11 focused static/source assertions passed at implementation. Pre-UI quest/parser/state segment was verified byte-identical; no altered hand-in classification, reward logic, defaults or event hooks. Newly bundled assets need client verification; native Lua 5.0.3 compiler and in-game pass **not run**. The horizontal offset sign depends on the actual 1.12 client semantics and must be tested with enough grouped bots to overflow the viewport; do not mark verified from source inspection.

## Current
- Branch: **`dev`**. Verified starting HEAD **`87f6294d0e2724dd0d847b4540a3980a35de1f53`**; **`0.1.9-dev` implementation commit `537c3667a29d91515036b31b77008a3196c612db`**. Handoff/README updated afterward in a documentation-only commit. Verify remote HEAD before subsequent edits; `main` unchanged.
- Version: **`0.1.9-dev`** in addon `.toc`, `Interface: 11200`. **`0.1.8-dev` reward-choice row height user-confirmed FIXED**; earlier first quest reward-choice flow passed (`0.1.6-dev`). Resize grip shows for a friend but not the user, tick/cross absent and horizontal direction wrong in user's previous build. These are targeted by untested `0.1.9-dev`. Earlier `0.1.4-dev` one-bot fade passed. No stable release.
- Current scoped goal: **in-game test of `0.1.9-dev` packaged status symbols, high-contrast resize glyph, horizontal scroll direction, and explicit hand-in confirmation visibility**, plus remaining dual-filter/group checks. Reward-row height already passed. Unrelated hand-in classification anomaly deferred.
- **All three chunks implemented.** `0.1.9-dev` changes only status artwork, resize grip visuals and horizontal scroll offset mapping; `0.1.8-dev` explicit linked completion-row logic remains intact and must be tested separately from icon visibility. `0.1.7-dev` defaults/migration remain intact. Reward-row height verified on `0.1.8-dev`, first reward flow earlier PASS, one-bot fade earlier PASS. Lua 5.0.3 compiler outstanding.
- Runtime provenance: screenshots show `0.1.2-dev` and `0.1.3-dev`; user reported **`0.1.4-dev` one-bot fade working** and **the first `0.1.6-dev` quest-choice flow working smoothly through quest completion**. Installed source SHAs not verified. Neither filter mode has been tested on `0.1.7-dev`.

## Current Design / Development Contract

### Architecture / Ownership
- New QuestControl addon for WoW 1.12.1 (Lua 5.0.3), matching TortoiseBotsManager (TBM) window style and visual constants; integrate with TBM rather than replacing it.
- **Current implementation:** per-character SavedVariables retain player quest records and independent bot observations; early bot links, accepts, auto-awards and reward prompts replay against matching quest identity regardless of arrival order. Objective completion remains distinct from hand-in.
- **Rows = quests; columns = tracked bots**. Column headers show bot name and class icon.
- Each bot's column displays its own reward options as **square item icons derived from the item hyperlinks sent in its chat message**.
- Mouseover uses the original item hyperlink for an in-game item tooltip.
- Clicking an icon sends the selected item's **original item link** directly to that bot: `/w BotName r [itemlink]` (equivalent API `SendChatMessage("r " .. itemLink, "WHISPER", nil, botName)`).
- A quest row disappears automatically once **all its tracked bots are resolved**; user additionally authorized a manual row `X`. Pending state must persist across reload/relog.
- **Approved exception after runtime feedback:** display bot acceptance confirmations and add contextual per-bot `Talk`/`Accept` recovery and row `X` controls. No auto-pick, unrelated quest controls, server protocol changes or broad scope additions.

### Invariants
- Primary function is to **consume known bot quest notifications, update the UI, and hide them from normal chat**.
- **Two independent account-wide suppression checkboxes** control chat visibility only:
  - `Filter Owned Bot Messages`: TBM roster or claimed-lookup bot senders, with the former `hideBotQuestMessages` SavedVariable migrated to `filterOwnedBotMessages` (new installations default OFF as of `0.1.7-dev`; existing values including migrated legacy ON are preserved).
  - `Filter Other Bot Messages`: senders not found by TBM's owned lookups; `filterOtherBotMessages` defaults false. It filters **only parsed quest-template messages**, not whole senders or unrelated messages. It cannot authoritatively distinguish an unknown bot from a human intentionally repeating the exact bot quest template.
  - Both use the existing party/raid/raid-leader/whisper channels. Filtering does **not** gate `QC.ReceiveChat`; only owned bots are delivered to quest state, regardless of either checkbox.
- Unrecognised chat, unrelated bot messages and ordinary player conversation remain visible; a byte-for-byte matching bot quest template from an unknown sender may be hidden with the other filter enabled.
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
- Preserve quest-by-bot rows/columns, original reward hyperlinks/item icons, the exact `/w BotName r [original itemlink]` command, and both checkboxes' visibility-only semantics.
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
- `21b24c1df7a1de63d0907d77e2928e7b0256d84a` — first runtime feedback and revised Chunk 3 direction, documentation-only.
- `3622e360551e0ac63a9e2ec291295f8d0f567942` — order-independent persistent quest correlation, acceptance/recovery controls and `0.1.3-dev` code; **not yet tested in-game**.
- `b5d245f4c859104be1b41033322973d551b1bc04` — **`0.1.4-dev` 7+3 second resolved-row fade**, **user confirmed one-bot fade PASS**; multi-bot/reward untested.
- `e09eb4d535c7657a4047dd966fe774ec4590ccc0` — **`0.1.5-dev` dual owned/other parsed-message chat filters**, migration of previous preference, two UI checkboxes and labels, no quest-state change.

## Completed / User-Verified
- Fixed three-chunk scope preserved; Chunks 1 and 2 bot-attributed parser, hand-in rows, per-bot state, reward selection and exact original-link whispers remain intact.
- Chunk 3 implementation complete: TBM dark/gold panel, turtle icon/version from `.toc`, movable window with close/Escape, quest × bot table, class-coloured names/atlas icons, square linked item textures, in-game tooltips, waiting/choice/ack states, automatic show on new hand-in, `/tbmq` toggle, pooled widgets, horizontal/vertical scroll and a single `Hide Bot Quest Messages` checkbox.
- **First user runtime test (2026-10-27, displayed `0.1.2-dev`) passed:** load without reported errors, `/tbmq` opening, drag/close/reopen/Escape, master checkbox persistence across `/reload`. **Failed:** no bot acceptance display, stuck/no reward options or auto-award resolution, pending rows lost on reload. Exact installed commit unverified. **This is not a test of `0.1.3-dev`.**

## Implemented / Awaiting Runtime Test — `0.1.3-dev`
- `.toc`: `Interface: 11200`, patch version `0.1.3-dev`, original account-wide hide-checkbox DB plus **per-character `TortoiseBotQuestControlState` SavedVariables**. Existing loader order and optional TBM dependency preserved.
- `QuestControl.lua` retains the **unchanged message classification/parser, bot attribution and selective chat-filter behaviour**. Bot messages are recorded independently as persistent observations (bot, quest ID/title, original links, reward options); rows are matched and replayed without requiring a preceding player hand-in. Title-only matching is conservative when multiple IDs are seen.
- Native `AcceptQuest` and `GetQuestReward` wrappers track player pickup and hand-in separately. Bot `accepted`/`already_have` messages are the only confirmed pickup outcomes; other statuses remain unconfirmed/actionable. `available` preserves an exact quest link but does not assert successful pickup.
- Silent hand-ins are assumed complete; explicit unable/incomplete notifications and selection prompts remain actionable. Bot `turned_in_reward` before player progression is retained for later association. `reward_ack` continues to match the bot's selected item ID. Exact `SendChatMessage("r " .. option.link, "WHISPER", nil, botName)` and original-link tooltip behaviour preserved.
- Existing quest-by-bot UI now displays acceptance vs hand-in vs reward stage, contextual per-bot **Talk** and **Accept** whisper buttons, and a manual row **X**. Accept is disabled when no trustworthy original quest hyperlink has been captured, and sending a command never sets success. Selected unit name is stored as an **unverified hint**, not asserted as the quest giver.
- Pending rows, per-bot states, item options, selected index, original hyperlinks and unresolved early observations persist through reload/relog. Row auto-removal depends on the relevant stage; explicit reward prompts stay visible until confirmed or manually dismissed. No automatic retry/timeout or quest-chain database.
- **API limitation:** stock Vanilla 1.12.1 does not provide `GetQuestLink`. Prefer original linked bot messages; an optional `GetQuestLinkForLogIndex` extension path is validated against title if it exists. Ordinary quest-object identity cannot be reliably captured through stock targeting APIs.
- **Unverified:** actual `AcceptQuest` hook/dialogue coverage, TortoiseBots whisper `talk`/`accept` semantics, dynamic bot roster state, game-object context, persistence and runtime rewards. No user playtest of this version.

## Stabilization test matrix (new implementation)

1. Bot acceptance **before** player's AcceptQuest: row confirms that bot, leaves other unconfirmed; repeat with bot acceptance **after** player and with no confirmation.
2. Bot announces a linked quest as **available** before player accepts: keep its exact link without falsely confirming pickup. After an actual linked acceptance by another bot, missing bot has enabled Accept; with no link, Accept must remain disabled.
3. **Mazzranache:** one bot sends a multi-item reward prompt before player hand-in; another auto-receives its item before player hand-in. Verify per-bot state, tooltip and exact item-link whisper, then reward ack cleanup.
4. Ordinary hand-in with no bot reply: do not create a stuck waiting row. Explicit unable-to-turn-in creates a repairable Talk row.
5. Target nearby NPC, use each **Talk**, then **Accept**, and check actual bot chat before treating pickup as confirmed. Test game objects separately; selected unit is only a hint.
6. Reload and relog with pending acceptance and reward choices; original quest/item links and selected item index survive; X removes a stuck row.
7. Run with hide checkbox on/off through party/raid/whisper bot channels and unrelated player chat; no false filters. Check scroll and UI initialization, no Lua errors.

## Static / Automated Checks
- **2026-10-28 `0.1.9-dev`: 11/11 targeted static/source checks PASS**, including byte-identical pre-UI quest parser/confirmation state/reward logic, bundled positive/negative/neutral mark paths replacing unavailable ReadyCheck dependencies, inverse horizontal scroll offset in callback and refresh, thicker/high-contrast grip preserving resize action, intact compact reward row height, exact item-link reward whisper, retained default-OFF filters, 7+3 fade, current `0.1.9-dev` TOC. Does **not** prove Lua 5.0.3 compiler compatibility or actual in-game scroll/status/size behaviour.
- **2026-10-27 `0.1.8-dev`: 15/15 targeted static/source assertions PASS.** Unchanged original message classifier, independent chat filters, player hand-in/acceptance hooks, reward commands, no change to silent assumed hand-in cleanup, exact-only explicit positive completion row fallback with individual-bot tick, direct original reward icons starting at top of row, no placeholder status for active choices, 23px one-line reward layout with wrapping only when needed, visible native resize-grip marks, unchanged 7+3 fade and TBM button anchor. New `STATUS_TURNED_IN` tooltip key, TOC bump. Neither actual Lua compiler nor runtime was executed on `0.1.8-dev`.
- **2026-10-27 `0.1.7-dev` filter-default patch: 8/8 targeted static assertions PASS.** Confirmed the sole Lua alteration is `previous` fallback `true` -> `false` when the legacy owned setting is missing; preexisting saved `filterOwnedBotMessages` values are never overwritten, explicit legacy `hideBotQuestMessages` preference remains migrated unchanged, and other remains OFF by default. TOC patch version `0.1.7-dev` only; original reward whisper, filters/quest handling, and loader untouched. No Lua 5.0.3 compiler pass or in-game verification for this change.
- **2026-10-27 `0.1.6-dev` compact UI source verification: 20/20 targeted read-only assertions passed**, covering unchanged pre-UI quest parser/state/reward/filter logic (byte-identical), original item-link whisper, 7+3 resolved-row fade, distinct settings checkboxes, relative Info anchoring, mouse-safe TB.dragHeader, single button/late init handling, class-coloured bot name render, native status and !/? art, item tooltips/actions, icon assets in repo, persisted move/resize, TOC metadata, slash/Escape integration, rulebook and locale unchanged. This is NOT a Lua compiler pass. Observed 62 column-zero local declarations, not a compiler-limit proof. **Canonical Lua 5.0.3 compiler and WoW runtime tests remain unexecuted**: no `lua5.0`/`luac5.0` or mounted vendor checker, and shell GitHub access cannot resolve hosts. Avoid claiming in-game PASS.
- **Icon provenance:** the repository includes 32×32 RGBA TGA renderings of the established pfQuest_Group `trash-2` (bin) and `clipboard-check` motifs, used only by QuestControl. The GitHub connection rejected the upstream binary files, so these are local Lucide-style re-rasterisations, **not byte-exact copies** of the pfQuest_Group TGAs. Confirm icon appearance in WoW and, when binary asset transfer is available, prefer copying the upstream TGAs exactly. The native Blizzard gossip/status/quest art needs no local assets.
- **Chunk 1 passed:** 13 preexisting source assertions (historical).
- **Chunk 2 passed:** 10 preexisting structural assertions (historical).
- **Chunk 3 passed:** 20 read-only source assertions, covering **byte-for-byte equality of the original parser/reward business logic after comment-only normalization**, exact linked whisper, state ownership and callback, hand-in hook initialization, 1 checkbox, tooltip payload taken from original link, per-bot link-based icons, class headers, two-axis scroll, loader/version, all new localized strings, no obvious later-Lua syntax/APIs, no speculative timeout code, and a GitHub comparison confirming only intended files changed. Total `local` tokens counted in file: 145 (a coarse source observation, **not** a Lua compiler limit proof).
- **Lua 5.0.x compiler: NOT RUN / UNAVAILABLE here.** Host `cc` exists, but the VanillaTemplate `tools/lua50` checker is not mounted in the executable filesystem, shell GitHub access fails DNS, and no `luac5.0` or `lua5.0` exists. The GitHub connector can read sources but cannot place the vendored compiler files in this shell. The template checker's README currently identifies its vendor distribution as **Lua 5.0.2**, while the canonical rulebook refers to **5.0.3**; no checker execution or compiler pass is claimed. Do not edit the rulebook to reconcile this.
- **2026-10-27 first stabilization checkpoint:** verified `dev` HEAD `10270cfb5cccfc7bac72e57f1f75f1d618a82fdd` and `.toc` version `0.1.2-dev`; **15/15 additional read-only source checks passed**, including loader order, metadata, hide/parse independence, objective vs turn-in distinction, `GetQuestReward` chain, untouched original-item-link whisper, ack matching, native tooltip link, auto-open and single master checkbox. These are **static checks only**, not Lua compiler or in-game runtime checks.
- **2026-10-27 `0.1.5-dev` static verification: 20/20 targeted source assertions passed**, including byte-identical parser, unchanged `ReceiveChat` and quest state, independent owned/other filter gates, legacy preference migration, default off for other, new labels and UI checkbox binding, no chat hides without successful parse, original fade retained. **No Lua 5.0.3 compiler or in-game test run on `0.1.5-dev`.**
- **2026-10-27 `0.1.4-dev` static verification: 17/17 targeted source assertions passed**, including unchanged parser/quest classification, original reward and manual recovery whispers, 7+3 second fade arithmetic, cancelling fades if re-opened, silent hand-in clearing, no persisting completed visual-only rows, OnUpdate cleanup, row opacity reset on UI reuse, TOC bump and no new loader. **No Lua 5.0.3 compiler or in-game test was run for the fade.**
- **2026-10-27 `0.1.3-dev` static verification: 18/18 source assertions passed** before commit: exact original parser/filter segment preserved byte-for-byte; unchanged original item-link reward whisper/tooltip; independent persistent observations and multi-pass replay; AcceptQuest/GetQuestReward wrappers; `available` never marking accepted; Accept disabled without trustworthy quest link; Talk/Accept buttons never marking success; per-character SavedVariables; X; locale keys; TOC version/loader; no obvious later-Lua syntax. **These are source checks, not a Lua 5.0.3 compiler pass nor an execution test.**
- **Runtime tests: user performed first partial in-game test on 2026-10-27 against `0.1.2-dev`**, showing mixed results detailed below. Assistant has no client/TortoiseBots/TBM session for independent reproduction; `0.1.3-dev` remains untested.
- **Current stabilization code diff:** from `21b24c1` to `3622e360`, changed `QuestControl.lua`, `locales/enUS.lua`, `TortoiseBotManager-QuestControl.toc` and `README.md`; `dev_rulebook.md` untouched. Historical Chunk 3 source checks apply only to older code.

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

## Latest Runtime Feedback — 2026-10-27 (`0.1.3-dev`)

User supplied screenshot of **The Harvest Golem Mystery**. Chat displayed Reven(d)a announcing the quest available, explicitly accepting it, the player's subsequent quest acceptance, and the bot saying "I have not completed the quest". Meanwhile QuestControl presented a separate **Hand-in / Not complete / Talk** row, even though the player and bot had just picked up the quest. This is a **separate potential stage-classification bug**, not evidence that the bot failed to accept; its root cause should be investigated only when requested. User specifically requested **no other code fixes** at this point.

Resolved acceptance rows disappeared immediately, leaving no useful chance to see the confirmation. **Approved narrow change:** fully resolved non-silent rows visible for 10 seconds total (7 seconds opaque, 3 seconds fade); cancel fade if row becomes unresolved; ordinary silent hand-in cleanup unchanged. An animation-only resolved row must not be saved or resurrected over reload. Version patch bump `0.1.4-dev` required; checks and in-game retest remain distinct.

## Current Issues
- **`0.1.5-dev` chat-filter runtime checks pending:** two independent checkboxes and settings persistence; owned/other parsed-message suppression; unknown/ordinary chat stays visible; TBM not loaded results in no suppression; unaffected quest state. 'Other' is defined by absence from owned roster plus a recognised template, not independently verified bot identity.
- **Confirmed in-game on `0.1.2-dev`, now targeted by `0.1.3-dev` fixes:** missing acceptance visibility, reward prompts/options missing after early bot events, auto-award/completion mispairing, player-first correlation vulnerability, lost pending rows on reload. **No fixed outcome has yet been runtime-confirmed.**
- **Cause clarified by user:** the `Mazzranache` reward miss was due to bot event sequencing ahead of the player-created row, **not** multiline parsing. The reward parser has been kept unchanged in `0.1.3-dev`; runtime retest of the corrected correlation is still needed.
- **To verify:** narrow `0.1.4-dev` fade timing/alpha/removal and unresolved-row persistence; optional client quest-link capture; whisper `talk`/`accept` response and range, especially game objects; SavedVariables replay without false matches; original reward links and choice ack; duplicate/late replies. The user explicitly approved only the resolved-row delay; **no retry or observation timer**.
- **Other open checks:** canonical Lua compiler check not run; tooltip, cached item textures, scrolling under load, chat filter coexistence, TBM roster timing.
- The stabilization fixes are source-implemented in `0.1.3-dev` but **not runtime-confirmed**. Do not mark them stable until the integrated test passes.

## Testing
### Last Runtime Test
- **2026-10-28 — user feedback on prior compact build (presumed `0.1.8-dev`, exact installed SHA not confirmed):** reward-choice row height FIXED; resize grip visible for a friend but not the user (interaction/highlight work); neither green tick nor red cross visible; horizontal scrollbar scrolling direction reversed. New `0.1.9-dev` visual/status artwork and offset fixes untested; the absent icons do not establish whether completion parsing or transient timing succeeded.
- **2026-10-27 — screenshot feedback on compact UI (precise installed SHA/version not supplied):** Reward choice row was ~45px because icons occupied a second line with a redundant 'Choose a reward' hover/button; resize grip interactive but texture invisible. User also reported explicit bot hand-in completion chat gave no green tick. **These three defects are targeted in untested `0.1.8-dev`.** Do not mark them fixed in-game until retested.
- **2026-10-27 — user reported `0.1.6-dev` first in-game quest-choice interaction and quest completion working smoothly. PASS: this one reward-choice flow only.** Exact installed commit not supplied. Does not establish full grid/UI, filter defaults, other quests, reward variants, or multi-bot behaviour.
- **2026-10-27 — user confirmed `0.1.4-dev` one-bot resolved-row fade behaves correctly in-game. PASS: fade with one bot only.** No claim about multi-bot, unresolved/reward rows, source SHA, or `0.1.5-dev` filtering.
- **2026-10-27 — earlier partial user-integrated Vanilla WoW 1.12.1/TortoiseBots/TBM test, displayed `0.1.2-dev`. Installed code commit unverified.**
- **PASS:** addon/TBM load without reported errors; `/tbmq`, window dragging, close/reopen/Escape, checkbox setting persistence across `/reload`.
- **FAIL:** unsaved pending rows after reload; lack of bot acceptance confirmation; `Mazzranache` reward-choice and auto-award outcomes not reflected despite party/chat evidence.
- **Observed externally:** bot acceptance can precede player notification; manual party `talk` and `accept [questlink]` needed for crate and ordinary NPC, with bots progressing differently. Individual whispers and revised UI not tested.
- No stable/released or fully runtime-verified addon baseline.

### Next Runtime Test — after Chunk 3 stabilization fixes
1. Verify acceptance-by-bot when bot acceptance occurs **before** and **after** the player's notification; no false confirmation for missing bot.
2. Reproduce `Mazzranache` single-message multi-choice prompt and rogue auto-award; verify per-bot options, native original-link tooltips, exact `r [original itemlink]` whisper and resolution.
3. Verify ordinary NPC/crate hand-in without mandatory completion message and per-bot **whisper** `talk` then `accept [original questlink]` near targeted quest giver; no false acceptance on action click.
4. Verify SavedVariables pending/early event/reward recovery over reload/relog, all-bots-resolved removal and deliberate row `X` deletion.
5. Verify independently the **owned and other** chat filters (both on/off, recognised vs unrecognised chat, default/migrated settings through reload), party/raid/whisper matching, duplicate/same-title handling, scrolling and no Lua errors. Record exact version **and installed commit** if possible.

No fourth chunk; do not infer any untested stage from an adjacent pass.

## Planned / Next Work
- **Test `0.1.9-dev` first:** reward rows were already verified compact on `0.1.8-dev`; check bundled green tick/red X/neutral ? appearance for bot accept, negative and explicit hand-in states, confirm temporary hand-in row appears for a parsed linked completion and fades 7+3 seconds, verify grip is visible at user's UI scale, and horizontally scroll right through 2+ bot columns (never backward/empty). Then continue TBM Quest/Info/Mini/close, scroll, persistence and icon-fidelity tests: verify TBM Quest/Info/Mini/close clicks with overlay boundaries, TBM late loading and Mini swap; compare icon fidelity to pfQuest_Group, group sizes, full bot names, scroll, persist move/resize, native and pfUI skin, tooltip and exact per-bot reward/recovery commands. Fix only concrete new UI defects on a new patch version.
- **`0.1.7-dev` default-OFF dual-filter in-game validation remains pending on `0.1.8-dev`:** on a fresh settings table both filters default OFF; explicit existing owned/other selections stay unchanged after update; explicit legacy `hideBotQuestMessages` migration stays unchanged; each checkbox changes only parsed-message chat visibility, ordinary dialogue remains, and owned quest events still update state under both switch settings. Observe other-ownership path in a party/raid/whisper and confirm whether any human text resembles exact templates; note this is not an authenticated bot classifier.
- **Continue visual checks:** one-bot fade already PASS in `0.1.4-dev`; still verify multi-bot resolved, unconfirmed persistence, reward acknowledgement and relog. Do not infer these passes from one-bot test.
- Separately, if explicitly requested, investigate the screenshot's incomplete-hand-in row on an active quest; do not conflate with the fade change. Continue broader `0.1.3-dev` acceptance/reward/whisper/persistence retests as useful, recording exact installed commit. No Chunk 4.

## Deferred / Out of Scope
- No fourth chunk, server changes, prebuilt quest-chain database, auto-accept/auto-pick feature, unrelated controls, arbitrary automatic retry/timeouts, architecture splitting or changes to `dev_rulebook.md`. Original no-acceptance-UI limitation is explicitly amended only for requested acceptance status and recovery actions.
- No `main` promotion or stable/released claims until the changed addon is actually tested; canonical compiler pass is still outstanding.

## Release / Promotion Notes
- `main` stays README-only; no release authorized or performed.
- Dependencies/target: native WoW 1.12.1, Lua 5.0.3, TortoiseBots server, optional TortoiseBotsManager API for identifying/tracking bots. Missing TBM makes reliable bot identification unavailable in the existing core.
- `dev_rulebook.md` unchanged. Current version `0.1.9-dev` for packaged status symbols, a more visible resize grip and reversed horizontal scroll offset. Keeps `0.1.8-dev` direct compact rewards/explicit-positive ephemeral hand-in, `0.1.7-dev` default-OFF filters and saved setting migration. Static checks passed; Lua compiler and actual `0.1.9-dev` runtime test outstanding.

## Exact Next Step
**Test `0.1.9-dev` from `dev` with exact installed commit if practical.** (1) With a recent explicit bot `I have completed the quest [questlink]` notice, the matching quest should briefly display that bot's **green tick**, neutral ? for other bots, then the existing 7+3 second fade; negative `I have not completed ...` should display red X and remain actionable. If the whole confirmation row is absent, distinguish parser/state correlation from missing art before another fix. (2) Check corner grip is always plainly visible at current UI scale and pfUI setup and resizing continues working. (3) Scroll horizontally with enough grouped bots for overflow; dragging right should reveal **rightmost** bot columns without blank space, left returns to quest titles. Confirm reward-choice row remains compact with working icons/tooltips, both filters still default OFF for new installs and retain prior saved values, and no Lua errors. The separately deferred `The Harvest Golem Mystery` erroneous hand-in classification is **untouched**. No `main` promotion/stable release; Lua 5.0.3 compilation **not performed**.
