# TortoiseBotManager-QuestControl

Vanilla World of Warcraft 1.12.1 addon project for a quest-by-bot reward selection UI that consumes recognised TortoiseBots quest chat messages.

## Development

Active development lives on the `dev` branch. See `dev_rulebook.md` for the copied VanillaTemplate engineering standard and `DEV_PROGRESS.md` for the current design, project status, and exact next step.

Source template: [Seraphic8x2244/VanillaTemplate](https://github.com/Seraphic8x2244/VanillaTemplate).

Status: All three implementation chunks are complete on `dev` as `0.1.2-dev`. Static source checks are documented in `DEV_PROGRESS.md`; Lua 5.0.3 compilation and first in-game runtime validation remain pending. This is not a stable release.

## Quest Control window

When you hand in a quest while grouped with tracked TortoiseBots, the quest-by-bot window opens. Each bot column lists that bot's own linked reward choices; hover an icon for the original item tooltip or click it to send the original item link directly to that bot. The window has one `Hide Bot Quest Messages` checkbox: turning it off reveals recognised messages in chat without changing parsing or rewards.

Type `/tbmq` to open or close the window manually. The window scrolls horizontally for many bots and vertically for many quest rows. Completed rows disappear after all tracked bots resolve.
