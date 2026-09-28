// 内置排版一致性语料（conformance corpus）。
//
// 这里是本项目所有排版规则的「单一事实来源」：
// - `moon test` 里的用例会遍历它；
// - `cmd/verify` 自检程序也遍历它，便于在没有 `moon test` 的环境下回归；
// - 新增/修改规则时，只需在这里补一条用例。

///|
/// 一条排版一致性用例。
pub struct Case {
  /// 用例名，失败信息里会带上
  name : String
  /// 输入文本
  input : String
  /// 期望 `fix` 之后得到的文本
  expected : String
  /// 期望在输入上报告的规则 id（全部都要出现）
  rules : Array[String]
  /// 是否按 Markdown 解析
  markdown : Bool
  /// 额外启用的规则
  enable : Array[String]
  /// 关闭的规则
  disable : Array[String]
  /// 行宽上限，0 表示不检查
  max_line_length : Int
} derive(Eq, Debug)

///|
/// 构造一条用例（只有前 3 个参数必填）。
fn mk(
  name : String,
  input : String,
  expected : String,
  markdown? : Bool = false,
  rules? : Array[String] = [],
  enable? : Array[String] = [],
  disable? : Array[String] = [],
  max_line_length? : Int = 0,
) -> Case {
  { name, input, expected, rules, markdown, enable, disable, max_line_length, }
}

///|
/// 内置用例集。
pub fn conformance_cases() -> Array[Case] {
  [
    // 中英文/数字间距
    mk("cjk-latin", "使用MoonBit开发", "使用 MoonBit 开发", rules=[
      "cjk-latin-space",
    ]),
    mk("cjk-digit", "共3个", "共 3 个", rules=["cjk-latin-space"]),
    mk("cjk-already-spaced", "使用 MoonBit 开发", "使用 MoonBit 开发"),
    mk("cjk-inline-code", "使用`code`开发", "使用 `code` 开发", rules=[
      "inline-code-space",
    ]),
    // 全角标点
    mk("fullwidth", "你好,世界!", "你好，世界！", rules=[
      "fullwidth-punct",
    ]),
    mk("fullwidth-eol", "这是一行:", "这是一行：", rules=[
      "fullwidth-punct",
    ]),
    mk("fullwidth-thousand", "合计 1,000 元", "合计 1,000 元"),
    mk("fullwidth-english", "Hello, world!", "Hello, world!"),
    // 重复标点
    mk("duplicate-bang", "太好了！！！", "太好了！", rules=[
      "duplicate-punct",
    ]),
    mk("duplicate-dun", "甲、、乙", "甲、乙", rules=["duplicate-punct"]),
    // 省略号
    mk("ellipsis-dots", "等等...", "等等……", rules=["ellipsis"]),
    mk("ellipsis-circles", "等等。。。", "等等……", rules=["ellipsis"]),
    mk("ellipsis-single", "等等…", "等等……", rules=["ellipsis"]),
    mk("ellipsis-english", "Loading...", "Loading..."),
    // 破折号
    mk("dash", "中文--英文", "中文——英文", rules=["dash"]),
    mk("dash-spaced", "破折号 -- 这样写", "破折号——这样写", rules=[
      "dash",
    ]),
    mk("dash-flag", "使用 --fix 参数", "使用 --fix 参数"),
    // 全角标点周围空格
    mk("space-after-period", "句子。 下一句", "句子。下一句", rules=[
      "space-around-punct",
    ]),
    mk(
      "space-paren",
      "中文 （括号） 测试",
      "中文（括号）测试",
      rules=["space-around-punct"],
    ),
    mk("space-colon-digit", "大小: 100 字节", "大小：100 字节", rules=[
      "fullwidth-punct",
    ]),
    mk("space-after-colon", "大小： 100 字节", "大小：100 字节", rules=[
      "space-around-punct",
    ]),
    // 数字与单位
    mk("unit-upper", "文件 100KB", "文件 100 KB", rules=[
      "number-unit-space",
    ]),
    mk("unit-lower", "耗时 30min", "耗时 30 min", rules=[
      "number-unit-space",
    ]),
    mk("unit-none", "买 5G 套餐", "买 5G 套餐"),
    // 术语
    mk(
      "terminology",
      "使用 github 与 javascript",
      "使用 GitHub 与 JavaScript",
      rules=["terminology"],
    ),
    mk("terminology-boundary", "mysql 与 postgresql", "mysql 与 postgresql"),
    mk("terminology-ok", "使用 MoonBit", "使用 MoonBit"),
    // 行尾空白
    mk("trailing", "abc   \ndef", "abc\ndef", rules=["trailing-whitespace"]),
    mk(
      "trailing-md-hardbreak",
      "第一行  \n第二行",
      "第一行  \n第二行",
      markdown=true,
    ),
    mk("trailing-non-md", "第一行  \n第二行", "第一行\n第二行", rules=[
      "trailing-whitespace",
    ]),
    // Markdown 结构
    mk("heading", "#标题", "# 标题", markdown=true, rules=["heading-space"]),
    mk("list-unordered", "-项目", "- 项目", markdown=true, rules=[
      "list-marker-space",
    ]),
    mk("list-ordered", "1.项目", "1. 项目", markdown=true, rules=[
      "list-marker-space",
    ]),
    mk("list-decimal", "1.5 倍", "1.5 倍", markdown=true),
    mk("blockquote", ">引用", "> 引用", markdown=true, rules=[
      "blockquote-space",
    ]),
    mk(
      "md-fence-content",
      "```\n使用MoonBit,并且使用github\n```\n",
      "```\n使用MoonBit,并且使用github\n```\n",
      markdown=true,
    ),
    mk(
      "md-inline-code",
      "执行 `npm run build` 即可",
      "执行 `npm run build` 即可",
      markdown=true,
    ),
    mk(
      "md-front-matter",
      "---\ntitle: 使用MoonBit\n---\n正文使用MoonBit\n",
      "---\ntitle: 使用MoonBit\n---\n正文使用 MoonBit\n",
      markdown=true,
    ),
    mk(
      "md-link-url",
      "见 [文档](https://x.com/中文)及 https://example.com/abc",
      "见 [文档](https://x.com/中文)及 https://example.com/abc",
      markdown=true,
    ),
    // 可选规则
    mk("opt-halfwidth-latin", "Hello，world", "Hello, world", enable=[
      "halfwidth-punct-in-latin",
    ]),
    mk("opt-consecutive-spaces", "a   b", "a b", enable=["consecutive-spaces"]),
    // 开关
    mk("disable-rule", "使用MoonBit", "使用MoonBit", disable=[
      "cjk-latin-space",
    ]),
    // 引号
    mk("curly-double", "他说\"你好\"", "他说“你好”", rules=[
      "curly-quote",
    ]),
    mk("curly-single", "中文'引号'", "中文‘引号’", rules=[
      "curly-quote",
    ]),
    mk("curly-nested", "他说\"她喊'喂'\"", "他说“她喊‘喂’”", rules=[
      "curly-quote",
    ]),
    mk("curly-apostrophe", "don't 不变", "don't 不变"),
    mk("curly-english", "the \"best\" practice", "the \"best\" practice"),
    mk("curly-already", "他说“你好”", "他说“你好”"),
    mk("curly-multiline", "\"跨行\n引号\"", "“跨行\n引号”", rules=[
      "curly-quote",
    ]),
    mk(
      "curly-inline-code",
      "执行 `echo \"hi\"` 命令",
      "执行 `echo \"hi\"` 命令",
      markdown=true,
    ),
    mk("curly-pairing", "这里有\"未闭合", "这里有“未闭合", rules=[
      "quote-pairing",
    ]),
    // 缩进代码块
    mk(
      "indented-code",
      "正文\n\n    使用MoonBit代码\n\n正文使用MoonBit",
      "正文\n\n    使用MoonBit代码\n\n正文使用 MoonBit",
      markdown=true,
    ),
    mk(
      "indented-code-quotes",
      "正文使用MoonBit\n\n    代码里的\"引号\"\n",
      "正文使用 MoonBit\n\n    代码里的\"引号\"\n",
      markdown=true,
    ),
    mk(
      "indented-lookalike-list",
      "- 第一项\n\n  续行使用MoonBit",
      "- 第一项\n\n  续行使用 MoonBit",
      markdown=true,
    ),
    // 第二批规则：内容与结构
    mk("fullwidth-alnum", "版本Ｖ２发布", "版本 V2 发布", rules=[
      "fullwidth-alnum",
    ]),
    mk("number-range", "第1～3章", "第 1~3 章", rules=["number-range"]),
    mk("percent-sign", "占比 50 %", "占比 50%", rules=["percent-sign"]),
    mk("blank-lines", "甲\n\n\n\n乙", "甲\n\n乙", rules=[
      "blank-line-collapse",
    ]),
    mk(
      "heading-jump",
      "# 一\n\n### 三\n",
      "# 一\n\n### 三\n",
      rules=["heading-level-jump"],
      markdown=true,
    ),
    mk(
      "heading-punct",
      "## 标题。\n",
      "## 标题\n",
      rules=["heading-trailing-punct"],
      markdown=true,
    ),
    // 第三批规则：Markdown 结构与间距
    mk("inline-code-spaced", "使用 `code` 开发", "使用 `code` 开发"),
    mk(
      "list-marker",
      "- 甲\n- 乙\n* 丙\n",
      "- 甲\n- 乙\n- 丙\n",
      rules=["list-marker-consistency"],
      markdown=true,
    ),
    mk(
      "table-columns",
      "| a | b |\n| --- |\n",
      "| a | b |\n| --- |\n",
      rules=["table-separator"],
      markdown=true,
    ),
    mk(
      "link-bare",
      "[https://x.com](https://x.com)",
      "<https://x.com>",
      rules=["link-bare"],
      markdown=true,
    ),
    mk("emoji-space", "完成✅很好", "完成 ✅ 很好", rules=[
      "emoji-space",
    ]),
    mk(
      "image-alt",
      "![](a.png)",
      "![](a.png)",
      rules=["image-alt"],
      markdown=true,
    ),
    // 换行与边界
    mk("crlf", "使用MoonBit\r\n", "使用 MoonBit\r\n"),
    mk("empty", "", ""),
    mk("multi-line", "第一行\n使用MoonBit", "第一行\n使用 MoonBit"),
  ]
}

///|
/// 根据用例构造配置。
fn case_config(c : Case) -> Config {
  let config = if c.markdown { Config::markdown() } else { Config::new() }
  for id in c.enable {
    let _ = config.with_rule(id, true)
  }
  for id in c.disable {
    let _ = config.with_rule(id, false)
  }
  if c.max_line_length > 0 {
    config.set_max_line_length(c.max_line_length)
  }
  config
}

///|
/// 把字符串转成便于阅读的带引号形式。
fn show_string(s : String) -> String {
  Json::string(s).stringify()
}

///|
/// 运行全部内置用例。
///
/// 返回失败描述列表；返回空数组表示全部通过。
/// 每条用例都会验证三件事：
/// 1. `lint` 报告了期望的规则；
/// 2. `fix` 的结果等于期望文本；
/// 3. 对结果再跑一次 `fix` 不再产生改动（幂等）。
pub fn run_conformance() -> Array[String] {
  let failures : Array[String] = []
  for c in conformance_cases() {
    let config = case_config(c)
    let diags = lint(c.input, config)
    for wanted in c.rules {
      let mut found = false
      for d in diags {
        if d.rule == wanted {
          found = true
          break
        }
      }
      if !found {
        failures.push("\{c.name}: 未报告期望的规则 \{wanted}")
      }
    }
    let outcome = fix(c.input, config)
    if outcome.output != c.expected {
      failures.push(
        "\{c.name}: 修复结果不符，期望 \{show_string(c.expected)}，实际 \{show_string(outcome.output)}",
      )
    }
    let again = fix(outcome.output, config)
    if again.applied != 0 {
      failures.push(
        "\{c.name}: 修复不幂等，第二次仍应用了 \{again.applied} 处",
      )
    }
  }
  failures
}
