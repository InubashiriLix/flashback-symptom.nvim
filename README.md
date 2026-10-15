

**English** | [简体中文](./README.zh-CN.md)

A Neovim plugin to simulate the pain of flashback.

> [!WARNING]
> This plugin is just for fun or simulation.
> It will not increase your mental capacity, or working efficiency.

> [!CAUTION]
> **Content warning.** The material shipped by default is the author's own
> experimental writing about intrusive thoughts: second person, self-hatred,
> and imagery of self-harm and death, flashed at you while you work.
> See [Content & safety](#content--safety). The neutral, feature-complete
> example is [`examples/showcase.jsonc`](./examples/showcase.jsonc).

> Demo Video:


https://github.com/user-attachments/assets/b04e2e1e-671a-456c-acf7-7d19c0286e99



Coloured "murmurs" pop up out of nowhere while you edit. They type themselves
out, glitch, flicker, drift, stack shadows, and occasionally hijack your keyboard
until you retype the prompt character for character.

- **Composer-driven effects** — one frame clock, per-effect timeline, so effects
  compose instead of fighting over the same window.
- **18 built-in effects** across text / style / window / screen channels, plus a
  three-phase API so you can register your own.
- **Small, large or full-screen** — a murmur can be a tiny float, a 60% window,
  or a full-screen takeover with an opaque background that hides everything.
- **Declarative material** — JSONC with palette, presets, glyph pools, weights
  and per-murmur trigger tags.
- **JSON Schema** for the material, auto-injected into `jsonls`.
- **Strict safety** — only ever touches windows it created, always restores the
  cursor, and `stop()` puts everything back.

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
    mode = "float",             -- "float" | "large" | "overlay"
    large   = { cover = 0.6, align = "center", padding = 2, border = "rounded" },
    overlay = { cover = 1.0, align = "center", padding = 3, border = "none",
                opaque = true },
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

  hijack = {                    -- full-screen overlays swallow the keyboard
    enabled = true,             -- the double-<Esc> escape is always available
    only_fullscreen = true,
  },

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

## Content & safety

The default material in [`data/murmurs.jsonc`](./data/murmurs.jsonc) is **not**
a feature demo — it is the author's self-expression: a second-person voice that
accuses, escalates, and quotes intrusive thoughts back at the reader.

- It is **experimental fiction**. Not a diagnosis, not a description of anyone's
  clinical state, and not advice.
- The author's own symptoms are mild. The material is deliberately dramatised
  and intensified for effect.
- Installing the plugin means these lines appear on your screen while you work,
  without warning, several times a minute.
- If you want the mechanics without the content, point `murmurs_path` at the
  neutral, feature-complete [`examples/showcase.jsonc`](./examples/showcase.jsonc).

If you recognise any of it in yourself, please tell someone who can answer.
[findahelpline.com](https://findahelpline.com/) lists free lines by country.
In mainland China: **12356** (全国心理援助热线) or **010-82951332**
(北京心理危机研究与干预中心). Using them is not a weakness.

This material is published as art, not as a recommendation to run it on
yourself.

## Pacing

The defaults fire often — 3 timers on a 4-second base interval — because the
whole point is to be intrusive. If you would rather keep your focus:

```lua
require("flashback").setup({
  timer = { timer_num = 1, interval_ms = 60000, jitter = 0.5 },
})
```

## Murmur material

Material is **JSONC**: comments (`//`, `/* */`) and trailing commas are allowed.

The shipped default is [`data/murmurs.jsonc`](./data/murmurs.jsonc) — the
author's self-expression set (see [Content & safety](#content--safety)).
The feature-complete, neutral reference lives in
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
| `grow` | win | grows the window up to its size |
| `shrink` | win | shrinks the window away |
| `wipe` | win | curtain reveal from one edge |
| `vignette` | screen | darkens the screen edges |
| `cursor_glow` | screen | a halo that follows the cursor |
| `cursor_harass` | screen | nudges the real cursor (off by default!) |
| `cursor_grab` | screen | grabs and holds the real cursor, then restores it |

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

## Display modes

A murmur is drawn by one of three display modes:

| mode | size | placement | notes |
| --- | --- | --- | --- |
| `float` | text size + 2 | `render.position` | the classic small window |
| `large` | 60% of the editor by default | `render.position` | big, still leaves the frame visible |
| `overlay` | 100% of the editor by default | centred | hides everything behind it |

Set the global default with `render.mode` and override it per murmur:

```jsonc
"display": {
  "mode": "overlay",
  "cover": 1.0,        // 0.01..1 of the editor area
  "align": "center",   // center/top/bottom/left/right/...
  "padding": 3,        // blank cells around the text block
  "border": "none",    // or rounded/single/...
  "opaque": true       // false lets the code show through
}
```

With `opaque` (the default) `style.bg` is painted across the whole window, so an
overlay really does black out the editor. `align` both places the window and
aligns the text inside it.

The window rect is animated by `grow` / `shrink` / `wipe`; `anchor` decides
where it grows from (`center` grows out of the middle, `top` is a curtain).

## The keyboard hijack

A full-screen `overlay` swallows every keystroke while it is on screen
(`hijack.enabled`), so it really occupies you. It is released when the murmur
ends.

> [!CAUTION]
> The only way out is a hard-coded **double `<Esc>`**, and it cannot be
> disabled. A full-screen input grab with no escape hatch would be a foot-gun.

A `trap` always wins: while one is active the hijack never starts.

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
nvim --headless -l spec/overlay.lua        # large/overlay geometry, size animation, hijack, cursor grab
```

## License

MIT
