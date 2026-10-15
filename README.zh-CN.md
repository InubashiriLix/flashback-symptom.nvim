# flashback-symptom.nvim

[English](./README.md) | **简体中文**

一个用来模拟「闪回之痛」的 Neovim 插件。

> [!WARNING]
> 本插件只为娱乐与模拟而生。
> 它不会提升你的脑容量，也不会提升你的工作效率。

> [!CAUTION]
> **内容警告。** 默认素材是作者围绕「侵入性思维」做的实验性书写：第二人称、
> 自我否定，含自伤与死亡的意象，会在你干活时不断闪到你脸上。
> 详见[内容与安全](#内容与安全)。想要中性、功能完整的示例请用
> [`examples/showcase.jsonc`](./examples/showcase.jsonc)。

你写代码的时候，会凭空弹出一些带颜色的「喃喃自语」（murmur）：它们自己打字、
乱码、闪烁、飘移、叠影子，偶尔还会劫持你的键盘，直到你把提示文字一字不差地
重新打出来。

- **合成器驱动特效** —— 统一时钟 + 逐特效时间轴，特效之间互相叠加而不是抢窗口。
- **18 个内置特效**，分属 文字 / 样式 / 窗口 / 屏幕 四个通道；并提供三阶段 API
  让你注册自己的特效。
- **小窗 / 大窗 / 全屏** —— 一条 murmur 可以是小浮窗、占屏 60% 的大窗，或者
  背景不透明、糊满整屏的全屏接管。
- **声明式素材** —— JSONC，支持调色板、预设、乱码字符池、权重与逐条触发标签。
- **JSON Schema**，自动注入 `jsonls`。
- **严格的安全性** —— 只碰自己创建的窗口，光标一定还原，`stop()` 会把一切复原。

## 安装

```lua
-- lazy.nvim
{
  "InubashiriLix/flashback-symptom.nvim",
  config = function()
    require("flashback").setup({})
  end,
}
```

Lua 入口是 `require("flashback")`。完整文档见 `:help flashback`（有中文版）。

## 配置

```lua
require("flashback").setup({
  autostart = false,            -- 进 Neovim 就自动开始？
  language = "en",              -- "en" | "zh-CN" | "auto"（按 $LANG 推导）
  fps = 30,                     -- 合成器帧率上限

  timer = { timer_num = 3, interval_ms = 4000, jitter = 0.5 },

  render = {
    mode = "float",             -- "float" | "large" | "overlay"
    large   = { cover = 0.6, align = "center", padding = 2, border = "rounded" },
    overlay = { cover = 1.0, align = "center", padding = 3, border = "none",
                opaque = true },
    position = "random",        -- "random" | "corner" | "cursor"
    corner = "botright",
    cursor_offset = { row = 1, col = 0 },
    max_windows = 4,            -- 0 = 不限
    allow_overlap = true,
    border = "rounded",
    winblend = 15,
  },

  effects = {
    enabled = {                 -- 单个特效的总开关
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
    escape = true,              -- 连按两次 <Esc> 紧急逃生
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
    cursor_harass = { enabled = false },   -- 会碰你的光标，默认关
  },

  integrations = {
    diagnostics = { enabled = true, weight = 1, duration = 3500,
                    severity = { ERROR = true, WARN = true, INFO = false, HINT = false } },
    todo = { enabled = true, weight = 1, duration = 3500,
             color = "#f1fa8c", patterns = { "TODO", "FIXME", "XXX", "HACK" } },
  },

  stats = { enabled = true, path = nil, achievements = true },
  feedback = { bell = true, notify = false, notify_level = "info", only_trap = false },

  hijack = {                    -- 全屏 overlay 会吞掉键盘
    enabled = true,             -- 连按两次 <Esc> 的保命链永远可用
    only_fullscreen = true,
  },

  lsp = {
    enabled = true,
    inject_jsonls = true,
    install_to_datadir = true,
    schema_url = nil,           -- nil = 从 git remote 推导
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

### 命令

| 命令 | 作用 |
| --- | --- |
| `:FlashbackStart` | 开始闪回 |
| `:FlashbackStop` | 停止，并回收所有窗口与输入钩子 |
| `:FlashbackToggle` | 开关 |
| `:FlashbackOnce` | 立刻随机闪一次 |
| `:FlashbackTrap` | 立刻强制触发一次劫持 |
| `:FlashbackStats` | 查看计数与成就 |
| `:FlashbackSchema` | 显示 schema 路径、URL 与 jsonls 配置片段（`yank` 复制） |

### Lua API

```lua
local fb = require("flashback")
fb.setup(opts)        -- 重建命令、加载素材、初始化统计、注入 schema
fb.start()            fb.stop()          fb.toggle()
fb.once()             fb.trap_now()
fb.reload_murmurs()   -- 改完素材后热重载
fb.is_running()       fb.stats_summary()
```

## 内容与安全

默认素材 [`data/murmurs.jsonc`](./data/murmurs.jsonc) **不是**功能演示，
它是作者的自我表达：一个第二人称的声音，指责、升级，然后把侵入性思维原样念回来。

- 它是**实验性虚构**。不是诊断，不是任何人临床状态的描述，也不是建议。
- 作者本人的真实症状很轻微。这些文本是**刻意加重**过的表达。
- 装上插件就意味着：这些字会在你工作时、毫无预兆地、一分钟好几次地出现在屏幕上。
- 只想要机制、不想要内容？把 `murmurs_path` 指向中性的、功能完整的
  [`examples/showcase.jsonc`](./examples/showcase.jsonc)。

如果你在里面认出了自己，请告诉一个**能回话**的人。
[findahelpline.com](https://findahelpline.com/) 按国家列出了免费求助热线。
中国大陆：**12356**（全国心理援助热线）或 **010-82951332**（北京心理危机研究与干预中心）。
去用它们，不丢人。

这份素材是作为**作品**公开的，不是建议你把它挂在自己身上跑。

## 节奏

默认是故意"吵"的 —— 3 个定时器、4 秒基准间隔，因为要的就是那种侵扰感。
如果你想保住注意力：

```lua
require("flashback").setup({
  timer = { timer_num = 1, interval_ms = 60000, jitter = 0.5 },
})
```

## murmur 素材

素材是 **JSONC**：允许 `//`、`/* */` 注释和尾逗号。

插件自带的默认素材是 [`data/murmurs.jsonc`](./data/murmurs.jsonc)
—— 作者的自我表达版本（见[内容与安全](#内容与安全)）。
中性的、功能完整的参考在
[`examples/showcase.jsonc`](./examples/showcase.jsonc)。

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/InubashiriLix/flashback-symptom.nvim/main/schema/murmurs.schema.json",

  "palette": {
    "blood": "#ff5555",              // 命名颜色，style 里按名字引用
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
      "preset": "horror",                 // 可选：先套预设
      "style": { "fg": "ice", "attrs": ["italic", "underline"] }, // 再覆盖它
      "duration": 3200,                   // 毫秒，默认 3000
      "weight": 3,                        // 触发权重，默认 1
      "effects": {                        // 具名特效及其参数
        "typewriter": { "speed": 45 },
        "glitch": { "delay": 800, "color": "#ff00ff", "density": 0.3, "pool": "katakana" },
        "fade": { "delay": 2000, "duration": 800 }
      },
      "trap": true,                       // 可选，默认 false
      "unlock_text": "你确定这里不需要判空吗？",
      "when": { "filetypes": ["lua"], "modes": ["insert"] } // 可选触发标签
    }
  ]
}
```

向后兼容：`"color": "#ff0000"` 等价于 `"style": { "fg": "#ff0000" }`；
`"effects": ["glitch", "flicker"]` 会自动升级成具名表。

## 特效

特效是声明式 + 注册表：14 个内置，你也可以自己写。所有特效都写进同一帧，
因此任意组合都能叠加。

| 特效 | 通道 | 做什么 |
| --- | --- | --- |
| `typewriter` | text | 逐字吐出 |
| `glitch` | text | 随机字符变乱码；可配颜色/密度/间隔/字符池 |
| `decay` | text | 乱码不断增长直到整句被吃掉 |
| `caret` | text | 打字机后面的闪烁光标 |
| `rainbow` | style | 色相循环；`per_char` 让每个字不同色 |
| `flicker` | style | 前景色周期性跳到刺眼的颜色 |
| `pulse` | win | 透明度呼吸 |
| `shake` | win | 高频抖动 |
| `drift` | win | 缓慢漂浮 |
| `fade` | win | 淡出（或淡入） |
| `shadow` | win | 窗口背后的一层阴影窗 |
| `grow` | win | 窗口长大到目标尺寸 |
| `shrink` | win | 窗口缩到没有 |
| `wipe` | win | 从某条边像窗帘一样揭开 |
| `vignette` | screen | 屏幕四周变暗 |
| `cursor_glow` | screen | 跟随光标的光晕 |
| `cursor_harass` | screen | 骚扰真实光标（默认关！） |
| `cursor_grab` | screen | 抓取并锁住真实光标，结束后还原 |

每个特效都可以带 `delay` / `duration` 做时间轴，`priority` 决定同通道覆盖顺序。

### 自定义特效

```lua
require("flashback.effects").register("my_fx", {
  channel = "win",
  priority = 0,
  defaults = { amount = 2 },
  enter = function(ctx) end,
  tick  = function(frame, ctx, t)   -- t：本特效已运行的毫秒数
    frame.row_offset = (frame.row_offset or 0) + math.sin(t / 100) * ctx.params.amount
  end,
  exit  = function(ctx) end,
})
```

特效只往 `frame` / `ctx.text` 里写，窗口由合成器统一应用。

## 显示模式

每条 murmur 由三种显示模式之一绘制：

| mode | 尺寸 | 位置 | 说明 |
| --- | --- | --- | --- |
| `float` | 文字尺寸 + 2 | `render.position` | 经典小浮窗 |
| `large` | 默认占编辑器 60% | `render.position` | 大，但还看得见编辑器的边 |
| `overlay` | 默认铺满 100% | 居中 | 把背后的一切都盖住 |

全局默认由 `render.mode` 决定，逐条可以覆盖：

```jsonc
"display": {
  "mode": "overlay",
  "cover": 1.0,        // 占编辑器区的比例 0.01~1
  "align": "center",   // center/top/bottom/left/right/...
  "padding": 3,        // 文字块四周的留白格数
  "border": "none",    // 或 rounded/single/...
  "opaque": true       // false 时会隐约透出背后的代码
}
```

`opaque`（默认）会把 `style.bg` 铺满整个窗口，所以 `overlay` 是真的把编辑器
盖黑。`align` 既决定窗口位置，也决定文字块在窗口内的对齐。

窗口矩形由 `grow` / `shrink` / `wipe` 做动画；`anchor` 决定从哪儿长出来
（`center` 从中间胀开，`top` 就是窗帘式下拉）。

## 键盘劫持

全屏 `overlay` 出现时（`hijack.enabled`）会吞掉所有按键，真的把你占住；
murmur 结束时自动放行。

> [!CAUTION]
> 唯一的出路是硬编码的**连按两次 `<Esc>`**，而且**关不掉**。没有逃生口的
> 全屏输入抓取就是个坑。

`trap` 永远优先：它生效期间 hijack 不会启动。

## 触发条件

- 全局条件（`trigger.enabled.*`）：filetype / 时间段 / 空闲 / 模式 / 事件
- 单条标签（`when`）：`filetypes`、`modes`
- 全部关闭 = 纯随机

## 集成

- `diagnostics` —— 当前诊断信息会变成 murmur，颜色按严重级别
- `todo` —— `TODO` / `FIXME` / `XXX` / `HACK` 注释会变成 murmur

## 编辑器支持（jsonls）

仓库自带 [`schema/murmurs.schema.json`](./schema/murmurs.schema.json)。装上
`jsonls` 就能获得键名补全、枚举补全、悬停文档与校验。两条独立的路：

**A. 自动注入（推荐，离线可用）**

`setup()` 时插件会读取你现有的 jsonls 配置，**追加**一条
`fileMatch → schema` 记录。你原有的 schema 会被保留，插件绝不会替你启用 jsonls。

```vim
:FlashbackSchema        " 打印路径、URL 与可直接粘贴的片段
:FlashbackSchema yank   " 复制到 + 寄存器
```

**B. 文件内 `$schema`**

把 raw GitHub URL 写到素材顶部，补全就能跟着文件走。

> 素材里写了注释就请命名为 `*.jsonc`，jsonls 才会放行注释。

## 劫持

带 `"trap": true` 的 murmur 会用 `vim.on_key` 接管键盘：所有按键被吞掉，直到你
把 `unlock_text` 一字不差打出来（打错清零重来）。

> [!CAUTION]
> 紧急逃生是**连按两次 `<Esc>`**，默认开启。
> 如果你关掉 `trap.escape` 又碰上问题，你就真的被锁在 Neovim 里了。

## 统计

计数持久化到 `stdpath("data")/flashback/stats.json`，用 `:FlashbackStats` 查看；
计数增长会解锁成就。

## 多语言

`language` 可以是 `"en"`（默认）、`"zh-CN"`，或 `"auto"`（按 `$LANG` 推导）。
它覆盖通知、劫持提示、统计标签、成就、错误信息与命令描述。帮助文档提供英文
（`doc/flashback.txt`）与中文（`doc/flashback.cnx`）；把 `helplang` 设为 `cn`，
`:help flashback` 就会显示中文版。

## 健康检查

```vim
:checkhealth flashback
```

会报告：Neovim 版本、素材是否可读且可解析、schema 是否存在、是否检测到 jsonls
以及 schema 是否已注入、统计目录是否可写。

## 安全性

插件只碰自己创建的窗口、缓冲区、autocmd 和定时器，窗口位置一律夹在屏幕范围内，
`stop()` 是幂等的。测试套件断言一次完整运行之后，你的窗口布局、光标位置、模式
和自有窗口的选项都保持不变。

## 测试

```sh
nvim --headless -l spec/cmds.lua           # 模块冒烟
nvim --headless -l spec/side_effects.lua   # 窗口系统完整性（重点）
nvim --headless -l spec/jsonc.lua          # JSONC 解析
nvim --headless -l spec/schema.lua         # schema / 注册表 / 示例 防漂移
nvim --headless -l spec/lsp.lua            # jsonls 注入（非破坏 + 幂等）
nvim --headless -l spec/overlay.lua        # 大窗/全屏几何、尺寸动画、夺键、光标抓取
```

## 许可

MIT
