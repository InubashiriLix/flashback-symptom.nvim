# flashback-symptom.nvim

A neovim plugin to simulate the pain of flashback.

> [!WARNING]
> This plugin is just for fun or simulation.
> It will not increase your mental capacity, or working efficiency.

## Why it comes out?

So this gonna be a long

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

The Lua entry point is still `require("flashback")`.

## Usage

```lua
require("flashback").setup({
  autostart = false,            -- 进 Neovim 就开始走神？
  fps = 30,                     -- 合成器帧率上限（特效越多越该压低）

  timer = { timer_num = 3, interval_ms = 4000, jitter = 0.5 },

  render = {
    position = "random",        -- "random" | "corner" | "cursor"
    corner = "botright",
    cursor_offset = { row = 1, col = 0 },
    max_windows = 4,            -- 0 = 不限
    allow_overlap = true,
    border = "rounded",
    winblend = 15,
  },

  effects = {
    -- 全局总开关，把某个特效设为 false 就再也不出现
    enabled = {
      typewriter = true, glitch = true, decay = true, caret = true,
      rainbow = true, flicker = true, pulse = true,
      shake = true, drift = true, fade = true, shadow = true,
      vignette = true, cursor_glow = true, cursor_harass = true,
    },
    -- murmur 没有自带 effects 时用这套
    default_effects = { typewriter = {}, flicker = {} },
  },

  trap = {
    enabled = true,             -- 关掉它，trap 素材就只是普通 murmur
    strict = true,
    escape = true,              -- 保命链：连按两次 <Esc>
    escape_key = "<Esc><Esc>",
  },

  trigger = {                   -- 什么时候发作
    enabled = { filetype = false, time = false, idle = false, mode = false, events = false },
    filetypes = { include = {}, exclude = {} },
    time = { ranges = { { from = "00:00", to = "06:00", weight = 2 } } },
    idle = { min_ms = 30000 },
    modes = { insert = true, normal = true, visual = false, replace = true },
  },

  screen = {
    cursor_harass = { enabled = false },   -- 会动你的光标，默认关
  },

  integrations = {
    diagnostics = { enabled = true, weight = 1, duration = 3500,
                    severity = { ERROR = true, WARN = true, INFO = false, HINT = false } },
    todo = { enabled = true, weight = 1, duration = 3500,
             color = "#f1fa8c", patterns = { "TODO", "FIXME", "XXX", "HACK" } },
  },

  stats = { enabled = true, path = nil, achievements = true },

  feedback = { bell = true, notify = false, notify_level = "info", only_trap = false },

  -- 素材的 JSON Schema 会自动注入给 jsonls（只注入，不替你 enable）
  lsp = {
    enabled = true,
    inject_jsonls = true,
    install_to_datadir = true,      -- 额外写一份到 stdpath("data")/flashback/ 作为稳定路径
    schema_url = nil,               -- nil = 从 git remote 推导 raw GitHub 地址
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
| `:FlashbackStart` | 开始闪回 |
| `:FlashbackStop` | 停下，并清空所有浮窗 / 屏幕特效 |
| `:FlashbackToggle` | 开/关 |
| `:FlashbackOnce` | 立刻随机闪一次 |
| `:FlashbackTrap` | 立刻强制触发一次输入劫持 |
| `:FlashbackStats` | 查看统计与成就 |
| `:FlashbackSchema` | 打印 schema 路径 / URL / jsonls 配置片段（`:FlashbackSchema yank` 复制到寄存器） |

### Lua API

```lua
local fb = require("flashback")
fb.setup(opts)        -- 配置（重建命令、加载素材、初始化统计、注入 schema）
fb.start()            -- :FlashbackStart
fb.stop()             -- :FlashbackStop
fb.toggle()           -- :FlashbackToggle
fb.once()             -- 闪一个
fb.trap_now()         -- 强制劫持
fb.reload_murmurs()   -- 改了素材文件后热重载
fb.is_running()       -- boolean
fb.stats_summary()    -- string
```

## Murmur material

素材是 **JSONC**（允许 `//` 和 `/* */` 注释、允许尾逗号）。默认用插件自带的
[`data/murmurs.jsonc`](./data/murmurs.jsonc)，用 `murmurs_path` 指向自己的文件即可覆盖。

一个文件里分四段：

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/InubashiriLix/flashback-symptom.nvim/main/schema/murmurs.schema.json",

  "palette": {
    "blood": "#ff5555",              // 颜色名，后面 style 里直接引用
    "ink": "#1a0000"
  },
  "glyph_pools": {
    "katakana": ["ﾊ", "ﾋ", "ﾌ"],    // glitch / decay 用的乱码字符池
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
      "text": "你确定这里不需要判空吗？",  // 必填
      "preset": "horror",                 // 可选，先套预设
      "style": { "fg": "ice", "attrs": ["italic", "underline"] }, // 可选，覆盖预设
      "duration": 3200,                   // 毫秒，默认 3000
      "weight": 3,                        // 触发权重，默认 1
      "effects": {                        // 可选，覆盖预设里的同名特效
        "typewriter": { "speed": 45 },
        "glitch": { "delay": 800, "color": "#ff00ff", "density": 0.3, "pool": "katakana" },
        "fade": { "delay": 2000, "duration": 800 }
      },
      "trap": true,                       // 可选，默认 false
      "unlock_text": "你确定这里不需要判空吗？", // 可选，默认取 text
      "when": { "filetypes": ["lua"], "modes": ["insert"] } // 可选，触发标签
    }
  ]
}
```

向后兼容：`"color": "#ff0000"` 等价于 `"style": { "fg": "#ff0000" }`；
`"effects": ["glitch", "flicker"]`（字符串数组）会自动升级成具名表。

## Editor support (jsonls)

仓库自带一份 JSON Schema：[`schema/murmurs.schema.json`](./schema/murmurs.schema.json)。
只要装上 `jsonls`（`vscode-json-language-server`），就能获得**键名补全、枚举补全、
悬停文档、类型校验**。两条路二选一或都用：

**A. 自动注入（推荐，离线可用）**

`setup()` 时插件会读取你现有的 jsonls 配置，把一条 `fileMatch → schema` 记录**追加**
进去（保留你原有的 schemas，且**不会**替你启用 jsonls）：

```lua
require("flashback").setup({})           -- 默认就会注入
-- 或者手动：
require("flashback.lsp").inject()
```

想看/复制现成的配置片段：

```vim
:FlashbackSchema
:FlashbackSchema yank
```

**B. 文件里写 `$schema`（可携带）**

素材文件顶部加一行，走到哪补全到哪（jsonls 需要能访问网络）：

```jsonc
"$schema": "https://raw.githubusercontent.com/InubashiriLix/flashback-symptom.nvim/main/schema/murmurs.schema.json"
```

> 写注释请把素材命名为 `.jsonc` —— Neovim 会识别为 `jsonc` filetype，
> jsonls 才会放行注释。插件自己的解析器两种后缀都能读。

## Effects

特效是**声明式 + 注册表**：内置 14 个，也能自己写。所有特效同在一帧里协作
（中央合成器 + 共享文字模型），所以任意组合都不打架。

| Effect | Channel | What it does |
| --- | --- | --- |
| `typewriter` | text | 逐字吐出 |
| `glitch` | text | 随机字符变乱码，可配颜色/密度/间隔/字符池 |
| `decay` | text | 乱码从零星到吞没整句 |
| `caret` | text | 打字机后的闪烁光标 |
| `rainbow` | style | 色相循环，`per_char = true` 则逐字不同色 |
| `flicker` | style | 前景色周期性跳到指定色 |
| `pulse` | win | 透明度呼吸 |
| `shake` | win | 窗口高频抖动 |
| `drift` | win | 窗口缓慢漂浮 |
| `fade` | win | 淡出（或淡入） |
| `shadow` | win | 背后一层阴影窗 |
| `vignette` | screen | 屏幕四周暗角 |
| `cursor_glow` | screen | 跟随光标的光晕 |
| `cursor_harass` | screen | 骚扰真实光标（默认关！） |

每个特效都可以带 `delay` / `duration` 做时间轴编排，`priority` 决定同通道覆盖顺序。

### 自定义特效

```lua
require("flashback.effects").register("my_fx", {
  channel = "win",
  priority = 0,
  defaults = { amount = 2 },
  enter = function(ctx) end,
  tick  = function(frame, ctx, t)   -- t = 本特效已运行毫秒
    frame.row_offset = (frame.row_offset or 0) + math.sin(t / 100) * ctx.params.amount
  end,
  exit  = function(ctx) end,
})
```

特效只往 `frame` / `ctx.text` 写，绝不动窗口——窗口由合成器统一应用。

## Triggers

- 全局条件（`trigger.enabled.*`）：filetype / 时间段 / 空闲时长 / 模式 / 事件
- 单条条件（murmur 的 `when`）：按 `filetypes` / `modes` 过滤
- 全部关闭就是纯随机

## Integrations

- `diagnostics`：当前 buffer 的诊断信息临时变成 murmur（severity → 配色）
- `todo`：当前 buffer 里的 `TODO` / `FIXME` / `XXX` / `HACK` 变成 murmur

## The trap

带 `"trap": true` 的 murmur 出现时，插件用 `vim.on_key` **接管键盘**：所有按键被吞掉，
直到你把 `unlock_text` 一字不差打出来为止（打错清零重来）。

> [!CAUTION]
> 默认开启紧急逃生：**连按两次 `<Esc>`** 立刻解除劫持。
> 若关掉 `trap.escape` 又碰上 bug，你就真的被锁在 Neovim 里了。
> 求生欲强的同学请保留逃生键。

## Safety

本插件**只操作自己创建的浮窗**，绝不移动、缩放或改写你的窗口布局。
`stop()` 会彻底回收所有浮窗、阴影窗、暗角窗、跟随光标的窗、autocmd 和 `vim.on_key`。
测试里专门验证过：运行前后窗口布局、光标、模式、普通窗口的 `winblend` 均不变。

## Tests

```sh
nvim --headless -l spec/cmds.lua           # 模块冒烟
nvim --headless -l spec/side_effects.lua   # 窗口系统完整性（重点）
nvim --headless -l spec/jsonc.lua          # JSONC 解析
nvim --headless -l spec/schema.lua         # schema 与特效注册表同步
nvim --headless -l spec/lsp.lua            # jsonls 注入（非破坏 + 幂等）
```

## License

MIT
