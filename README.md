# mbt-typeset

[English](README.md) | 简体中文

**中文排版校对工具（MoonBit 实现）** —— 像 ESLint 一样检查中文排版，支持一键自动修复与 CI 集成。

`mbt-typeset` 用纯 MoonBit 编写，把「中英文之间有没有空格」「标点是不是全角」「术语大小写是否统一」这类
中文写作中反复出现的排版问题，变成**可检查、可自动修复、可放进 CI** 的工程化流程。

```console
$ mbt-typeset --markdown 文档.md
文档.md:3:5: warning [cjk-latin-space] 中文与英文或数字之间应插入一个空格 (可自动修复)
文档.md:3:14: warning [fullwidth-punct] 中文语境中应使用全角标点「，」 (可自动修复)
文档.md:3:24: warning [ellipsis] 省略号应使用中文省略号「……」 (可自动修复)
```

```console
$ mbt-typeset --markdown --fix 文档.md
文档.md: 已应用 34 处修复，剩余 0 处问题
```

> 修复前：`本文使用MoonBit编写,演示常见的排版问题...`
> 修复后：`本文使用 MoonBit 编写，演示常见的排版问题……`

完整的前后对比见 [`examples/before.md`](examples/before.md) 与 [`examples/after.md`](examples/after.md)。

---

## 为什么做这个项目

在动手之前，我们对 mooncakes.io 的**官方索引**（728 个用户 / 2396 个模块）做了全量排查：

| 方向 | 生态现状 |
| --- | --- |
| Markdown 解析 / 渲染 | 已有 `mizchi/markdown`、`moon-ssg` 等 |
| JSON Schema / 校验 | 已有 `mizchi/jsonschema`、`Betterlol/moon_zod` |
| CSV / SQL / 数据库 | 已有 `maria/csv_parser`、`uiwcvb/moonsql`、`sqlparser` |
| 序列化 / 网络协议 | 已有 `mizchi/cbor`、`hackwaly/msgpack`、`http11`、`moonbit-mqtt` |
| 拼音 / 分词 / emoji | 已有 `walkzzz/pinyin`、`colmugx/jieba`、`fundon/emoji` |
| **中文排版校对** | **索引中不存在任何排版检查 / 校对类包** |

于是我们把目标定在了一个生态空白、边界清晰、且能**客观验收**的题目上：
把成熟生态里已有的工具（如 textlint、pangu.js、中文文案排版指北）所覆盖的能力，在 MoonBit 里从零实现一遍，
并提供命令行工具与可复用的库。

## 特性

- **30 条排版规则**，覆盖间距、标点、引号、术语、Markdown 结构五大类
- **一键自动修复**，满足幂等性：修完再修不会产生新改动
- **Markdown 感知**：自动跳过代码围栏、行内代码、链接地址、URL、前置元数据（front matter）
- **三种输出格式**：`text`（人读）、`json`（机器读）、`github`（Actions 注解）
- **可配置**：JSON 配置文件 + 命令行覆盖，规则可逐条开关
- **零外部依赖**：纯 MoonBit 实现，只依赖标准库与 `moonbitlang/x` 的文件 API

## 规则一览

| 规则 id | 默认 | 可修复 | 说明 |
| --- | --- | --- | --- |
| `cjk-latin-space` | 开 | 是 | 中文与英文、数字之间插入空格 |
| `fullwidth-punct` | 开 | 是 | 中文语境中的半角标点改为全角 |
| `fullwidth-alnum` | 开 | 是 | 中文语境中的全角字母数字改为半角 |
| `curly-quote` | 开 | 是 | 中文语境中的直引号改为弯引号 |
| `quote-pairing` | 开 | 否 | 引号必须成对出现 |
| `duplicate-punct` | 开 | 是 | 重复标点只保留一个 |
| `ellipsis` | 开 | 是 | 省略号统一为「……」 |
| `dash` | 开 | 是 | 中文破折号统一为「——」 |
| `number-range` | 开 | 是 | 数字区间号统一为半角 `~` |
| `space-around-punct` | 开 | 是 | 全角标点周围不应有多余空格 |
| `number-unit-space` | 开 | 是 | 数字与单位之间插入空格 |
| `percent-sign` | 开 | 是 | 百分号与数字之间不应有空格 |
| `terminology` | 开 | 是 | 术语大小写与写法统一（如 `github` → `GitHub`） |
| `trailing-whitespace` | 开 | 是 | 行尾不应有多余空白 |
| `blank-line-collapse` | 开 | 是 | 连续空行压缩为 1 个 |
| `heading-space` | 开 | 是 | Markdown 标题的 `#` 之后应有空格 |
| `heading-level-jump` | 开 | 否 | Markdown 标题层级不应跳跃 |
| `heading-trailing-punct` | 开 | 是 | 标题末尾不应有句读标点 |
| `list-marker-space` | 开 | 是 | Markdown 列表标记之后应有空格 |
| `list-marker-consistency` | 开 | 是 | 同文档内列表标记保持一致 |
| `blockquote-space` | 开 | 是 | Markdown 引用块的 `>` 之后应有空格 |
| `table-separator` | 开 | 否 | 表格分隔行列数与表头一致 |
| `link-bare` | 开 | 是 | 链接文字与地址相同时可简写为 `<地址>` |
| `image-alt` | 开 | 否 | Markdown 图片应提供 alt 文本 |
| `inline-code-space` | 开 | 是 | 行内代码与中文之间加空格 |
| `emoji-space` | 开 | 是 | emoji 与中文之间加空格 |
| `unclosed-code-fence` | 开 | 否 | Markdown 代码围栏未闭合（error 级） |
| `halfwidth-punct-in-latin` | 关 | 是 | 英文语境中的全角标点改为半角 |
| `consecutive-spaces` | 关 | 是 | 正文中不应出现连续空格 |
| `line-length` | 关 | 否 | 行宽上限检查（需设置 `maxLineLength`） |

用 `mbt-typeset --list-rules` 可在终端查看同样的一张表。

## 安装与构建

前置条件：已安装 [MoonBit 工具链](https://www.moonbitlang.com/download/) 与 `git`。

Windows（PowerShell）：

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm https://cli.moonbitlang.cn/install/powershell.ps1 | iex
```

Linux / macOS：

```bash
curl -fsSL https://cli.moonbitlang.cn/install/unix.sh | bash
```

获取源码并构建：

```bash
git clone <this-repo>
cd mbt-typeset
moon check        # 类型检查
moon build        # 构建
```

## 命令行用法

```text
用法:
  mbt-typeset [选项] <文件...>

选项:
  --fix                        就地修复可自动修复的问题
  --format <text|json|github>  输出格式（默认 text）
  --config <路径>              读取 JSON 配置
  --markdown                   按 Markdown 文档处理
  --max-line-length <n>        行宽上限（0 表示不检查）
  --rule <id=on|off>           启用/关闭某条规则（可重复）
  --terminology <源=标准>      追加术语（可重复）
  --list-rules                 列出全部规则
  -v, --version                显示版本
  -h, --help                   显示帮助

退出码:
  0  未发现问题
  1  发现 warning 及以上问题
  2  用法错误或读写失败
```

在仓库内直接运行：

```bash
moon run cmd/main -- --markdown examples/before.md            # 检查
moon run cmd/main -- --markdown --fix examples/after.md        # 修复
moon run cmd/main -- --format json examples/before.md          # JSON 输出
moon run cmd/main -- --list-rules                              # 规则表
```

### 只检查某几条规则

```bash
# 关闭术语规则，并开启「英文语境用半角标点」
moon run cmd/main -- --markdown \
  --rule terminology=off \
  --rule halfwidth-punct-in-latin=on \
  examples/before.md
```

## 配置文件

`--config` 指向一个 JSON 文件，命令行参数优先级更高：

```json
{
  "markdown": true,
  "maxLineLength": 120,
  "rules": {
    "halfwidth-punct-in-latin": true,
    "consecutive-spaces": false
  },
  "terminology": {
    "moonbit": "MoonBit",
    "javascript": "JavaScript"
  }
}
```

完整示例见 [`examples/config.json`](examples/config.json)。

## 作为库使用

库包为 `Mr-Houjie/mbt-typeset`，核心 API 只有三个：

```moonbit
// 1. 检查：返回按位置排序的诊断列表
let diags = @lib.lint(source, @lib.Config::markdown())

// 2. 修复：返回修复结果、应用的编辑数与剩余问题
let outcome = @lib.fix(source, @lib.Config::markdown())
println(outcome.output)     // 修复后的文本
println(outcome.applied)    // 应用了多少处修复
println(outcome.remaining)  // 仍然存在、但无法自动修复的问题

// 3. 渲染：text / json / github 三种输出
let report = @lib.render_text(diags, "文档.md")
```

### 诊断结构

```moonbit
pub struct Diagnostic {
  rule : String          // 规则 id
  severity : Severity    // Error | Warning | Info
  message : String       // 说明
  line : Int             // 1 起始行号
  column : Int           // 1 起始列号（按字符计）
  start : Int            // 全文字符偏移（闭端，用于修复）
  end : Int              // 全文字符偏移（开端）
  replacement : String?  // 可自动修复时的替换文本
}
```

## 测试与验收

项目提供两条相互独立的验证路径：

### 1. 标准单元测试

```bash
moon test
```

测试分两层：

- **一致性语料**（`conformance.mbt`）：69 条「输入 → 期望输出」用例，是全部规则的单一事实来源；
  每条用例都会校验 `lint` 报告了期望的规则、`fix` 的结果等于期望文本、并对结果再跑一次 `fix` 确认幂等。
- **黑盒单元测试**（`mbt-typeset_test.mbt`）：只通过公开 API 覆盖位置计算、保护掩码、渲染输出、规则表、配置等细节。

### 2. 自检程序（无需 `moon test` 也能跑）

```bash
moon run cmd/verify
# mbt-typeset 自检：共 69 条用例，失败 0 条
# 全部通过
```

`cmd/verify` 直接遍历同一份一致性语料，适合在没有 `moon test` 支持的环境或 CI 之外做快速回归。

## 设计要点

```
mbt-typeset/
├── charclass.mbt      # Unicode 字符分类：CJK 文字 / CJK 标点 / 全角 / ASCII
├── types.mbt          # Diagnostic、Severity、RuleInfo、FixOutcome
├── config.mbt         # 运行配置与内置术语表
├── segment.mbt        # 扫描：切行、识别代码区域、构造逐字符「保护掩码」
├── blocks.mbt         # 块级分析：标题 / 列表 / 表格 / 缩进代码块
├── quotes.mbt         # 引号配对状态机与中文弯引号转换
├── rules.mbt          # 30 条规则 + 规则注册表
├── engine.mbt         # lint / fix（迭代到不动点）+ 位置计算
├── render.mbt         # text / json / github 渲染 + 规则表
├── conformance.mbt    # 一致性语料 + 自检入口
├── mbt-typeset_test.mbt # 黑盒测试（只走公开 API）
├── cmd/main           # 命令行工具
├── cmd/verify         # 自检程序
├── examples/          # 前后对比示例、配置示例
└── PROJECT_PROPOSAL.md # 大赛项目申报书
```

### 为什么修复是幂等的

`fix` 不是「一条规则改一遍」，而是反复执行「检查 → 应用互不重叠的可修复项」，直到没有任何可修复项
（最多 8 轮）。因此：

- 规则之间即使相互影响（例如先把半角逗号改成全角，再去掉标点旁的空格），最终也会收敛到稳定结果；
- 对同一份输入重复调用 `fix`，第二次不会再产生任何改动，这一点由一致性语料对每条用例强制校验。

### 如何避免误伤代码

扫描阶段会为每一行构造逐字符的**保护掩码**：行内代码（`` `code` ``）、Markdown 链接目标、URL、邮箱、
尖括号包裹的内容都会被标记为「受保护」，所有内容类规则都会跳过这些位置。代码围栏与 front matter
则整块标记为 `code`，完全不参与检查。

## 已知边界

- 只做「确定性强」的排版规则：不做标点语义判断、不做语法检查、不做引号弯直转换（避免误伤）。
- 数字与单位规则采用保守的单位白名单（不包含单字母单位，避免把 `5G` 误判为 `5 G`）。
- `halfwidth-punct-in-latin`、`consecutive-spaces`、`line-length` 默认关闭，因为它们依赖具体写作约定。

## 许可证

[MIT](LICENSE)
