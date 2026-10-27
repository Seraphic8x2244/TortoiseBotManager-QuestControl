# TortoiseBotManager-QuestControl

Vanilla World of Warcraft 1.12.1 addon for tracking quest pickup, hand-in issues and linked reward choices by grouped TortoiseBotsManager bot.

## Development

Active development lives on `dev`. See `dev_rulebook.md` for the copied VanillaTemplate engineering standard and `DEV_PROGRESS.md` for current design, validation and handoff.

Status: **0.1.5-dev**, Chunk 3 runtime stabilization. The 10-second resolved-row fade in **0.1.4-dev** was confirmed in-game with one bot. The new dual chat filters in **0.1.5-dev** have not been runtime-tested. The earlier quest hand-in classification issue is separate and remains unresolved. No stable release has been promoted.

## Quest Control window

Type `/tbmq` to show or hide the window. The quest-by-bot grid has class-coloured bot headers and horizontal/vertical scrolling.

Accepting a quest creates a pickup checkpoint for each currently grouped TBM bot. An explicit linked bot acceptance confirms pickup, even if the bot message arrives before your action. Otherwise the bot shows **Not confirmed**, not a claimed failure. Use **Talk** to ask the bot to interact with your nearby selected quest giver, then **Accept** to send the original linked quest when QuestControl has captured that link. A greyed-out Accept button means no trustworthy quest link is available. Neither button fabricates a success response; verify the bot's subsequent chat.

Ordinary quest hand-ins are assumed successful without requiring every bot to chat confirmation. Explicit hand-in problems and reward-choice requests create actionable entries; a linked reward prompt is recorded even before the player's hand-in. Each reward choice uses the individual bot's original item link: hover for the item tooltip or click to whisper `r [original itemlink]`. A reply acknowledges the selected reward. Rows clear when the tracked bots have resolved their relevant checkpoint; **X** manually dismisses a row.

Pending state and original links are saved per character across reloads and relogs. The two account-wide chat visibility settings are **Filter Owned Bot Messages** (TBM roster/claimed bots, migrated from the previous checkbox) and **Filter Other Bot Messages** (senders outside the TBM roster, disabled by default). **Only messages successfully recognised as quest notification templates are hidden** on party/raid/whisper channels; unrelated chat remains visible. Other-sender recognition is a template match, not independently verified bot identity. Filtering never changes owned-bot quest processing, rows or original reward messages. Stock Vanilla 1.12 cannot reliably identify quest-giver game objects or construct a missing original quest link.

The UI and quests require in-game retesting. See `DEV_PROGRESS.md` for known limitations and test steps.
