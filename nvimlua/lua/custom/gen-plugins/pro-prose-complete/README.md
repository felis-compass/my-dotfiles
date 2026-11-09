<!-- Generated, not human-reviewed. -->
# pro-prose-complete

Phone-keyboard-style writing help for prose in Neovim: word completion ranked by how you write, and autocorrect as you type. It is meant to become a standalone plugin, and later a VS Code extension.

## What it does

- **Completion.** An nvim-cmp source for markdown, gitcommit and text buffers.
  - It offers the best known words for what you've typed and inserts a space after the accepted word.
  - A word you added with capitals is offered with them ("GitHub").
  - Misspellings are never offered. That includes the ones wordfreq happens to list, such as "teh" and "isnt".
- **Autocorrect.** When you type a space or `. , ; : ! ? )` after a misspelled word, the word is replaced with the best spelling suggestion.
  - **Misspelled** means the spell checker (`'spelllang'`) marks the whole word bad, and neither your words nor the chat list has it.
  - **The fix** is the spell checker's first suggestion, unless a lower suggestion is a word the dictionary rates clearly higher. When the first suggestion isn't in the (English) dictionary, as with a French word ("trés" → "très"), it stands.
  - **Undo.** Backspace right after a correction puts back what you typed, and the next separator leaves that word alone.
  - **Left alone:**
    - code blocks, inline code, link targets, URLs and paths;
    - words with digits, `_`, `@` or inner capitals;
    - words joined to other characters ("“teh”", "café–teh").
  - **Where it runs:** only in a prose filetype whose window has `'spell'` on, so `:setlocal nospell` turns it off for one buffer.
- **Learning.** Words you type or accept move up in completion, and among spelling suggestions.
  - Only words already in the dictionary are counted: the plugin never makes a new word known. You add words with `zg`.
  - Counts from several Neovims add up.

## Words

The sources stay separate on disk and are merged in memory:

| Source | File | Written by |
|---|---|---|
| Your words | your `'spellfile'` entries | you, with `zg` |
| Chat words | `chat-words.txt` (`word<TAB>count`) | `:ProseWordsSync` |
| Chat words, as a spell file | `chat-words.utf-8.add` (+ `.spl`) | the plugin, from `chat-words.txt` |
| English | `wordfreq-en-25000.json` | downloaded once, in the background, from a pinned URL |
| Usage counts | `usage.json` | the plugin, as you type |

**Location.** Files other than your own live in `$PRO_PROSE_DATA_DIR`. Without it, they live in `$XDG_DATA_HOME/pro-prose/` or `~/.local/share/pro-prose/`. The location is editor-neutral, so other tools can share it.

**Ranking.** Scores are on one blended scale, not strict tiers, so typing "th" still offers "the" before a rarer chat word:
- a wordfreq word scores its log frequency;
- chat words get a bonus that grows with how often you used them;
- your own words score like fairly common words;
- usage counts add on top.

The constants are at the top of `words.lua`.

**Spelling.** wordfreq only ranks words. Whether a wordfreq word is spelled right is up to the spell checker, because wordfreq also lists misspellings.

**Chat words and the spell checker.** For chat words not to be underlined, the caller adds `chat-words.utf-8.add` to `'spellfile'`, after your own file, since `zg` writes to the first entry. The plugin regenerates that file from `chat-words.txt`, so don't add words to it with `2zg`.

## Syncing chat words

`:ProseWordsSync` runs `sync.py`, which uses only the Python standard library (3.9+) and also works on its own. Run `python3 sync.py --help` for its options.

1. It counts the words in your Claude Code and Compass chats, on this machine.
   - Tokens with digits, `_`, `/` or inner capitals (code, keys, paths) are skipped whole.
   - Its own earlier review prompts are skipped.
2. Words used 3 or more times that no list knows yet go to an AI agent for review. Only the words are sent, never sentences.
   - Agents are tried in order: `claude -p`, `compass -p`, `codex exec`, then OpenRouter (`OPENROUTER_API_KEY`). If one fails, the next is tried.
   - Each agent runs in the data folder, with no tools and no saved session.
   - The agent drops typos, names, client and internal project names, and anything private.
3. Approved words are merged into `chat-words.txt`.
   - Nothing is ever replaced or removed, and counts only grow, so deleting old chats can't shrink the list.
   - To drop a word, delete its line.

**Safety.**
- Every verdict is cached in `review-cache.json`, so each word is reviewed once.
- Files are written through a temporary file and a rename, after every batch, the word list first. A failed or interrupted sync keeps what it finished.
- A lock allows one sync at a time.
- The sync refuses to run before the wordfreq list exists.

## Use

```lua
local pro = require("custom.gen-plugins.pro-prose-complete")
vim.opt.spellfile:append(pro.spellfile) -- after your own spell file
pro.enable(cmp)
```

This takes over the prose filetypes from the basic word list in `custom/plugins/completion.lua`.

## Next

- **Context-aware correction.** Rank candidates by the words around them (word-pair statistics, keyboard-aware typo costs), and catch real-word errors ("form" for "from"). A small local model may come later.
- **Portability.** A VS Code version needs its own spelling suggestions, since VS Code has no spell checker. The data files and `sync.py` can be shared as they are.
