# Examples

## `showcase.jsonc`

A deliberately exhaustive material file. Use it as a reference, or point
`murmurs_path` straight at a copy of it.

It demonstrates:

- `palette` — named colours referenced from `style`
- `glyph_pools` — named noise pools, plus a literal inline pool
- `presets` — `calm`, `dreamy`, `horror`, `panic`, `retro`
- every built-in effect at least once, with parameters:
  `typewriter` `glitch` `decay` `caret` `rainbow` `flicker` `pulse` `shake`
  `drift` `fade` `shadow` `vignette` `cursor_glow` `cursor_harass`
- combos: typewriter + delayed glitch + caret + fade; rainbow + drift + shadow
  + pulse
- timeline fields: `delay`, `duration`, `priority`
- `weight`, multi-line text, legacy `color`
- `when` tags (`filetypes`, `modes`)
- `trap` with both the default `unlock_text` and an explicit one

The murmur texts are Simplified Chinese; swap them for any language you like,
the schema only constrains the shape.

```lua
require("flashback").setup({
  murmurs_path = vim.fn.stdpath("config") .. "/flashback/murmurs.jsonc",
})
```

Autocompletion and validation come from `schema/murmurs.schema.json`; see
`:help flashback-lsp` or run `:FlashbackSchema`.
