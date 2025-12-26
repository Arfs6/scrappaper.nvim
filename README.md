# Scrap Paper

Scrap Paper is a small Neovim plugin that provides a **single, persistent scratch buffer** for temporary writing.

You can quickly swap into the Scrap Paper buffer, jot something down, save it, cycle through previously saved scraps, and swap back to exactly where you were.

## Why Scrap Paper

Scrap Paper works with **one scratch buffer**:

- `:ScrapPaper swap` toggles between your current buffer and the Scrap Paper buffer.
- The Scrap Paper buffer is a scratch buffer (see `:help scratch-buffer` for more info).
- Saved scraps are stored on disk as json files and persist across Neovim sessions.
- You can cycle through saved scraps in most recent / least recent order.

This is **not** a **notes** manager and it **doesn't** use a **floating window**.

## Installation

Install using your plugin manager or Neovim’s built-in package system.

Here is an example using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ 'arfs6/scrappaper.nvim' }
```

There is no setup required. The plugin loads automatically.

## Commands

The plugin defines a single command with subcommands:

### `:ScrapPaper swap`

- If you are **not** in Scrap Paper:

  * Remembers the current buffer so you can return to it later
  * Switches to the Scrap Paper buffer
- If you **are** in Scrap Paper:

  * Returns you to the previously active buffer

### `:ScrapPaper save`

- Saves the current Scrap Paper content to disk
- Does nothing if:

  * You are not in the Scrap Paper buffer
  * The buffer is empty
  * The content is already the most recently saved scrap paper
- Saved scrap papers are stored in MRU order (most recent first)
- A maximum of **16** scrap papers are kept:

    * You can modify `scrapaper.max_saved_scrap_papers` to adjust the number.

### `:ScrapPaper prev`

- Replaces the Scrap Paper content with an **older** saved scrap paper
- Cycles from most recently saved → least recently saved
- Wraps around when the end is reached

### `:ScrapPaper next`

- Replaces the Scrap Paper content with a **newer** saved scrap paper
- Cycles from least recently saved → most recently saved
- Wraps around when the end is reached

## Storage

Saved scraps are stored as JSON at:

```
stdpath('data')/scrappaper_storage.json
```

Each saved scrap is a list of lines, preserving exact buffer content.

## Typical Workflow

1. Editing a file
2. `:ScrapPaper swap` → write temporary notes
3. `:SwapPaper swap` return to your file

**OR**

1. Editing a file
2. `:ScrapPaper swap` → write temporary notes
3. `:ScrapPaper save` → keep it for later
5. Later, cycle between saved scrap papers with `:ScrapPaper prev` / `:ScrapPaper next`
4. `:ScrapPaper swap` → return to your file

## Contributing

This plugin is part of my personal Neovim configuration.

I’m not actively developing it further, but:

- Issues and pull requests are welcome
- Reviews may be slow

The project is MIT licensed — feel free to fork and adapt it.

## License

Licensed under the MIT License. See [LICENSE](./LICENSE) for details.
