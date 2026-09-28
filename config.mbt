///|
/// 运行配置。
///
/// 默认配置面向「纯文本 + 中文排版」，`Config::markdown()` 会额外打开
/// 与 Markdown 结构相关的规则（标题、列表、引用块），并跳过代码块内容。
pub struct Config {
  /// 规则开关覆盖：规则 id -> 是否启用
  rules : Map[String, Bool]
  /// 术语表：小写形式 -> 权威写法
  terminology : Map[String, String]
  /// 是否按 Markdown 文档处理
  mut markdown : Bool
  /// 行宽上限（按字符计），0 表示不检查
  mut max_line_length : Int
} derive(Debug)

///|
pub extend Config with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// 内置术语表：小写形式 -> 权威写法。
///
/// 只收录「几乎不会误伤」的专有名词，避免把普通英文单词也一起改了。
pub fn default_terminology() -> Array[(String, String)] {
  [
    ("moonbit", "MoonBit"),
    ("github", "GitHub"),
    ("gitlab", "GitLab"),
    ("github actions", "GitHub Actions"),
    ("vscode", "VS Code"),
    ("javascript", "JavaScript"),
    ("typescript", "TypeScript"),
    ("nodejs", "Node.js"),
    ("node.js", "Node.js"),
    ("webassembly", "WebAssembly"),
    ("json", "JSON"),
    ("html", "HTML"),
    ("css", "CSS"),
    ("sql", "SQL"),
    ("url", "URL"),
    ("uri", "URI"),
    ("http", "HTTP"),
    ("https", "HTTPS"),
    ("api", "API"),
    ("sdk", "SDK"),
    ("cli", "CLI"),
    ("gui", "GUI"),
    ("ios", "iOS"),
    ("macos", "macOS"),
    ("linux", "Linux"),
    ("windows", "Windows"),
    ("android", "Android"),
    ("python", "Python"),
    ("openai", "OpenAI"),
    ("chatgpt", "ChatGPT"),
  ]
}

///|
/// 纯文本默认配置。
pub fn Config::new() -> Config {
  let rules : Map[String, Bool] = Map([])
  let terminology : Map[String, String] = Map([])
  for pair in default_terminology() {
    terminology.set(pair.0, pair.1)
  }
  { rules, terminology, markdown: false, max_line_length: 0, }
}

///|
/// Markdown 默认配置。
pub fn Config::markdown() -> Config {
  let config = Config::new()
  config.markdown = true
  config
}

///|
/// 设置是否按 Markdown 文档处理。
pub fn Config::set_markdown(self : Config, value : Bool) -> Unit {
  self.markdown = value
}

///|
/// 设置行宽上限（0 表示不检查）。
pub fn Config::set_max_line_length(self : Config, value : Int) -> Unit {
  self.max_line_length = value
}

///|
/// 打开 / 关闭某条规则。
pub fn Config::with_rule(self : Config, id : String, enabled : Bool) -> Config {
  self.rules.set(id, enabled)
  self
}

///|
/// 追加 / 覆盖一条术语。
pub fn Config::with_terminology(
  self : Config,
  from : String,
  to : String,
) -> Config {
  self.terminology.set(from, to)
  self
}

///|
/// 设置行宽上限（0 表示不检查）。
pub fn Config::with_max_line_length(self : Config, n : Int) -> Config {
  self.max_line_length = n
  self
}

///|
/// 查询某条规则是否启用；未显式配置时回落到该规则的默认值。
pub fn Config::is_enabled(self : Config, id : String, default : Bool) -> Bool {
  match self.rules.get(id) {
    Some(v) => v
    None => default
  }
}
