# TortoiseBotManager-QuestControl

Vanilla World of Warcraft 1.12.1 addon for tracking quest pickup, hand-in issues and linked reward choices by grouped TortoiseBotsManager bot.

## Development

Active development lives on `dev`. See `dev_rulebook.md` for the copied VanillaTemplate engineering standard and `DEV_PROGRESS.md` for current design, validation and handoff.

Status: **0.1.7-dev**, both chat filters default OFF on fresh installs while preserving existing saved choices and explicit legacy migration. The `0.1.6-dev` compact UI and TBM Quest button are implemented, with one first quest reward-choice/completion flow user-reported successful in-game; broader integration remains unverified. The 10-second resolved-row fade in **0.1.4-dev** was confirmed in-game with one bot. Filter defaults from **0.1.7-dev** remain runtime-untested. The earlier quest hand-in classification issue is separate and remains unresolved. No stable release has been promoted.

## Quest Control window

Click **Quest** directly left of TBM's **Info** header button, or type `/tbmq`, to toggle the compact window. It has full class-coloured bot names, Blizzard `!`/`?` icons beside quest titles, green tick/red X/neutral question mark per bot (hover for meaning), direct per-bot item reward icons and contextual small Talk, Accept and bin controls. No persistent stage/status prose appears in the main matrix. Resize the bottom-right corner, drag the title header or scroll in either direction; window position and manual size persist per character. Click the gear in the title bar to access the two message filters. The compact UI uses native game elements with optional pfUI backdrop.

Accepting a quest creates a pickup checkpoint for each currently grouped TBM bot. An explicit linked bot acceptance confirms pickup, even if the bot message arrives before your action. Otherwise the bot shows **Not confirmed**, not a claimed failure. Use the **gossip Talk icon** to ask the bot to interact with your nearby selected quest giver, then the **clipboard Accept icon** to send the original linked quest when QuestControl has captured that link. A greyed-out Accept icon means no trustworthy quest link is available. Neither action fabricates a success response; verify the bot's subsequent chat.

Ordinary quest hand-ins are assumed successful without requiring every bot to chat confirmation. Explicit hand-in problems and reward-choice requests create actionable entries; a linked reward prompt is recorded even before the player's hand-in. Each reward choice uses the individual bot's original item link: hover for the item tooltip or click to whisper `r [original itemlink]`. A reply acknowledges the selected reward. Rows clear when the tracked bots have resolved their relevant checkpoint; the **bin icon** manually dismisses a row.

Pending state and original links are saved per character across reloads and relogs. The two account-wide chat visibility settings are **Filter Owned Bot Messages** (TBM roster/claimed bots, migrated from the previous checkbox) and **Filter Other Bot Messages** (senders outside the TBM roster). **Both filters default OFF for new installs in `0.1.7-dev`; existing saved choices, including the explicit legacy-owned setting, are preserved.** **Only messages successfully recognised as quest notification templates are hidden** on party/raid/whisper channels; unrelated chat remains visible. Other-sender recognition is a template match, not independently verified bot identity. Filtering never changes owned-bot quest processing, rows or original reward messages. Stock Vanilla 1.12 cannot reliably identify quest-giver game objects or construct a missing original quest link.

The bundled bin and clipboard-check TGA assets are local renderings of the existing pfQuest_Group/Lucide icon shapes, not byte-identical upstream files (binary transfer was unavailable). Verify their appearance in game. The UI and quests require in-game retesting. See `DEV_PROGRESS.md` for known limitations and test steps.
