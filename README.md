# TortoiseBotManager-QuestControl

Vanilla World of Warcraft 1.12.1 addon for tracking quest pickup, hand-in issues and linked reward choices by grouped TortoiseBotsManager bot.

## Development

Active development lives on `dev`. See `dev_rulebook.md` for the copied VanillaTemplate engineering standard and `DEV_PROGRESS.md` for current design, validation and handoff.

Status: **0.1.3-dev**, Chunk 3 runtime stabilization. The previous **0.1.2-dev** UI was tested in-game, but quest correlation, reward display and persistence had confirmed defects. The revised version has not yet been runtime-tested or promoted to a stable release.

## Quest Control window

Type `/tbmq` to show or hide the window. The quest-by-bot grid has class-coloured bot headers and horizontal/vertical scrolling.

Accepting a quest creates a pickup checkpoint for each currently grouped TBM bot. An explicit linked bot acceptance confirms pickup, even if the bot message arrives before your action. Otherwise the bot shows **Not confirmed**, not a claimed failure. Use **Talk** to ask the bot to interact with your nearby selected quest giver, then **Accept** to send the original linked quest when QuestControl has captured that link. A greyed-out Accept button means no trustworthy quest link is available. Neither button fabricates a success response; verify the bot's subsequent chat.

Ordinary quest hand-ins are assumed successful without requiring every bot to chat confirmation. Explicit hand-in problems and reward-choice requests create actionable entries; a linked reward prompt is recorded even before the player's hand-in. Each reward choice uses the individual bot's original item link: hover for the item tooltip or click to whisper `r [original itemlink]`. A reply acknowledges the selected reward. Rows clear when the tracked bots have resolved their relevant checkpoint; **X** manually dismisses a row.

Pending state and original links are saved per character across reloads and relogs. The separate master **Hide Bot Quest Messages** checkbox changes chat visibility, not message processing, and retains its prior account-wide setting. Stock Vanilla 1.12 cannot reliably identify quest-giver game objects or construct a missing original quest link.

The UI and quests require in-game retesting. See `DEV_PROGRESS.md` for known limitations and test steps.
