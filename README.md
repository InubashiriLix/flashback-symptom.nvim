# flashback-symptom.nvim

**English** | [简体中文](./README.zh-CN.md)

A Neovim plugin to simulate the pain of flashback.

> [!WARNING]
> This plugin is just for fun or simulation.
> It will not increase your mental capacity, or working efficiency.

Coloured "murmurs" pop up out of nowhere while you edit. They type themselves
out, glitch, flicker, drift, stack shadows, and occasionally hijack your keyboard
until you retype the prompt character for character.

- **Composer-driven effects** — one frame clock, per-effect timeline, so effects
  compose instead of fighting over the same window.
- **14 built-in effects** across text / style / window / screen channels, plus a
  three-phase API so you can register your own.
- **Declarative material** — JSONC with palette, presets, glyph pools, weights
  and per-murmur trigger tags.
- **JSON Schema** for the material, auto-injected into `jsonls`.
- **Strict safety** — only ever touches its own float windows, and `stop()` puts
  everything back.

## Install

```lua
-- lazy.nvim
{
  "InubashiriLix/flashback-symptom.nvim",
  config = function()
    require("flashback").setup({})
  end,
}
```

The Lua entry point is `require("flashback")`. Documentation lives in
`:help flashback`.

## Usage

```lua
require("flashback").setup({
  autostart = false,            -- start murmuring on VimEnter?
  language = "en",              -- "en" | "zh-CN" | "auto" (reads $LANG)
  fps = 30,                     -- composer frame rate cap

  timer = { timer_num = 3, interval_ms = 4000, jitter = 0.5 },

  render = {
    position = "random",        -- "random" | "corner" | "cursor"
    corner = "botright",
    cursor_offset = { row = 1, col = 0 },
    max_windows = 4,            -- 0 = unlimited
    allow_overlap = true,
    border = "rounded",
    winblend = 15,
  },

  effects = {
    enabled = {                 -- per-effect master switches
      typewriter = true, glitch = true, decay = true, caret = true,
      rainbow = true, flicker = true, pulse = true,
      shake = true, drift = true, fade = true, shadow = true,
      vignette = true, cursor_glow = true, cursor_harass = true,
    },
    default_effects = { typewriter = {}, flicker = {} },
  },

  trap = {
    enabled = true,
    strict = true,
    escape = true,              -- double <Esc> emergency escape
    escape_key = "<Esc><Esc>",
  },

  trigger = {
    enabled = { filetype = false, time = false, idle = false, mode = false, events = false },
    filetypes = { include = {}, exclude = {} },
    time = { ranges = { { from = "00:00", to = "06:00", weight = 2 } } },
    idle = { min_ms = 30000 },
    modes = { insert = true, normal = true, visual = false, replace = true },
  },

  screen = {
    cursor_harass = { enabled = false },   -- touches your cursor; off by default
  },

  integrations = {
    diagnostics = { enabled = true, weight = 1, duration = 3500,
                    severity = { ERROR = true, WARN = true, INFO = false, HINT = false } },
    todo = { enabled = true, weight = 1, duration = 3500,
             color = "#f1fa8c", patterns = { "TODO", "FIXME", "XXX", "HACK" } },
  },

  stats = { enabled = true, path = nil, achievements = true },
  feedback = { bell = true, notify = false, notify_level = "info", only_trap = false },

  lsp = {
    enabled = true,
    inject_jsonls = true,
    install_to_datadir = true,
    schema_url = nil,           -- nil = derived from the git remote
    file_match = {
      "flashback.json", "flashback.jsonc",
      "*murmurs*.json", "*murmurs*.jsonc",
      "*/flashback/*.json", "*/flashback/*.jsonc",
      ".flashback/*.json", ".flashback/*.jsonc",
    },
  },

  cmds = {
    start = "FlashbackStart", stop = "FlashbackStop", toggle = "FlashbackToggle",
    once = "FlashbackOnce", trap = "FlashbackTrap",
    stats = "FlashbackStats", schema = "FlashbackSchema",
  },
})
```

### Commands

| Command | Meaning |
| --- | --- |
| `:FlashbackStart` | Start the murmurs |
| `:FlashbackStop` | Stop and tear down every window and input hook |
| `:FlashbackToggle` | Toggle |
| `:FlashbackOnce` | Show one random murmur now |
| `:FlashbackTrap` | Force a trap now |
| `:FlashbackStats` | Show counters and achievements |
| `:FlashbackSchema` | Show the schema path, URL and a jsonls snippet (`yank` copies it) |

### Lua API

```lua
local fb = require("flashback")
fb.setup(opts)        -- rebuild commands, load material, init stats, inject schema
fb.start()            fb.stop()          fb.toggle()
fb.once()             fb.trap_now()
fb.reload_murmurs()   -- after editing the material file
fb.is_running()       fb.stats_summary()
```

## Murmur material

Material is **JSONC**: comments (`//`, `/* */`) and trailing commas are allowed.
The plugin ships [`data/murmurs.jsonc`](./data/murmurs.jsonc) as a default; a
much more thorough reference lives in
[`examples/showcase.jsonc`](./examples/showcase.jsonc).

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/InubashiriLix/flashback-symptom.nvim/main/schema/murmurs.schema.json",

  "palette": {
    "blood": "#ff5555",              // named colours, referenced from style
    "ink": "#1a0000"
  },
  "glyph_pools": {
    "katakana": ["ﾊ", "ﾋ", "ﾌ"],    // noise for glitch / decay
    "blocks": ["░", "▒", "▓", "█"]
  },
  "presets": {
    "horror": {
      "style":   { "fg": "blood", "bg": "ink", "attrs": ["bold"] },
      "effects": { "glitch": { "color": "#ff00ff", "density": 0.2 },
                   "shake":  { "amplitude": 1 },
                   "vignette": { "strength": 0.6 } }
    }
  },
  "murmurs": [
    {
      "text": "Do you really not need a nil check here?",  // required
      "preset": "horror",                 // optional: merge a preset first
      "style": { "fg": "ice", "attrs": ["italic", "underline"] }, // overrides it
      "duration": 3200,                   // ms, default 3000
      "weight": 3,                        // trigger weight, default 1
      "effects": {                        // named effects with parameters
        "typewriter": { "speed": 45 },
        "glitch": { "delay": 800, "color": "#ff00ff", "density": 0.3, "pool": "katakana" },
        "fade": { "delay": 2000, "duration": 800 }
      },
      "trap": true,                       // optional, default false
      "unlock_text": "Do you really not need a nil check here?",
      "when": { "filetypes": ["lua"], "modes": ["insert"] } // optional tags
    }
  ]
}
```

Backwards compatible: `"color": "#ff0000"` equals `"style": { "fg": "#ff0000" }`,
and `"effects": ["glitch", "flicker"]` is upgraded to the named form.

## Effects

Effects are declarative and registry-driven: 14 built-ins plus your own. Every
effect writes into a shared frame, so any combination composes.

| Effect | Channel | What it does |
| --- | --- | --- |
| `typewriter` | text | reveals the line character by character |
| `glitch` | text | replaces glyphs with noise; colour/density/interval/pool |
| `decay` | text | corruption grows until the line is eaten |
| `caret` | text | blinking caret trailing the typewriter |
| `rainbow` | style | hue cycling; `per_char` colours every glyph |
| `flicker` | style | foreground jumps to a jarring colour |
| `pulse` | win | breathing transparency |
| `shake` | win | high-frequency jitter |
| `drift` | win | slow floaty drift |
| `fade` | win | fades out (or in) |
| `shadow` | win | a darker copy behind the window |
| `vignette` | screen | darkens the screen edges |
| `cursor_glow` | screen | a halo that follows the cursor |
| `cursor_harass` | screen | nudges the real cursor (off by default!) |

Every effect accepts `delay` / `duration` for timeline scheduling and `priority`
for write order within a channel.

### Custom effects

```lua
require("flashback.effects").register("my_fx", {
  channel = "win",
  priority = 0,
  defaults = { amount = 2 },
  enter = function(ctx) end,
  tick  = function(frame, ctx, t)   -- t: ms since this effect started
    frame.row_offset = (frame.row_offset or 0) + math.sin(t / 100) * ctx.params.amount
  end,
  exit  = function(ctx) end,
})
```

Effects only write into `frame` / `ctx.text`; the composer applies the result.

## Triggers

- Global conditions (`trigger.enabled.*`): filetype / time ranges / idle /
  mode / events
- Per-murmur tags (`when`): `filetypes`, `modes`
- Everything off means pure random

## Integrations

- `diagnostics` — current diagnostics become murmurs, coloured by severity
- `todo` — `TODO` / `FIXME` / `XXX` / `HACK` comments become murmurs

## Editor support (jsonls)

The repository ships [`schema/murmurs.schema.json`](./schema/murmurs.schema.json).
With `jsonls` installed you get key completion, enum completion, hover docs and
validation. Two independent routes:

**A. Automatic injection (recommended, works offline)**

On `setup()` the plugin reads your existing jsonls config and *appends* a
`fileMatch → schema` entry. Your own schemas are preserved and jsonls is never
enabled for you.

```vim
:FlashbackSchema        " print path, URL and a paste-ready snippet
:FlashbackSchema yank   " copy it to the + register
```

**B. In-file `$schema`**

Put the raw GitHub URL at the top of the material file so completion travels
with the file.

> Name your material `*.jsonc` if it contains comments so jsonls accepts them.

## The trap

A murmur with `"trap": true` takes over the keyboard with `vim.on_key`. Every
keystroke is swallowed until you type `unlock_text` character for character.

> [!CAUTION]
> The emergency escape is a **double `<Esc>`**, on by default.
> If you disable `trap.escape` and something goes wrong, you can be locked
> inside Neovim for real.

## Statistics

Counters are persisted to `stdpath("data")/flashback/stats.json` and shown with
`:FlashbackStats`; achievements unlock as they grow.

## Language

`language` is `"en"` (default), `"zh-CN"`, or `"auto"` to derive it from `$LANG`.
It covers notifications, the trap prompt, statistics labels, achievements, error
messages and command descriptions. The help file ships in English
(`doc/flashback.txt`) and Chinese (`doc/flashback.cnx`); with
`set helplang=cn`, `:help flashback` opens the Chinese version.

## Health

```vim
:checkhealth flashback
```

Reports the Neovim version, whether the material is readable and parses, whether
the schema is present, whether jsonls was found and the schema injected, and
whether the stats directory is writable.

## Safety

The plugin only touches windows, buffers, autocommands and timers it created
itself, clamps every window position to the screen, and `stop()` is idempotent.
The test suite asserts that window layout, cursor position, mode and the options
of your own windows are unchanged after a full run.

## Tests

```sh
nvim --headless -l spec/cmds.lua           # module smoke tests
nvim --headless -l spec/side_effects.lua   # window-system integrity (the important one)
nvim --headless -l spec/jsonc.lua          # JSONC parsing
nvim --headless -l spec/schema.lua         # schema / registry / example drift guard
nvim --headless -l spec/lsp.lua            # jsonls injection (non-destructive + idempotent)
```

## License

MIT
