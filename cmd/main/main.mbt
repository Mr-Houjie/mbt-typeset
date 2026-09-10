// mbt-typeset 命令行入口。
//
// 具体排版逻辑位于库包 `Mr-Houjie/mbt-typeset`，这里只负责：
// 参数解析、文件读写、配置加载、输出与退出码。

///|
/// 版本号。
const VERSION : String = "0.1.0"

///|
/// 用法说明。
fn usage() -> String {
  let s = StringBuilder()
  s.write_string("mbt-typeset \{VERSION} — 中文排版校对工具\n\n")
  s.write_string("用法:\n  mbt-typeset [选项] <文件...>\n\n")
  s.write_string("选项:\n")
  s.write_string(
    "  --fix                    就地修复可自动修复的问题\n",
  )
  s.write_string(
    "  --format <text|json|github>  输出格式（默认 text）\n",
  )
  s.write_string("  --config <路径>          读取 JSON 配置\n")
  s.write_string("  --markdown               按 Markdown 文档处理\n")
  s.write_string(
    "  --max-line-length <n>    行宽上限（0 表示不检查）\n",
  )
  s.write_string(
    "  --rule <id=on|off>       启用/关闭某条规则（可重复）\n",
  )
  s.write_string("  --terminology <源=标准>  追加术语（可重复）\n")
  s.write_string("  --list-rules             列出全部规则\n")
  s.write_string("  -v, --version            显示版本\n")
  s.write_string("  -h, --help               显示本帮助\n\n")
  s.write_string("退出码:\n")
  s.write_string("  0  未发现问题\n")
  s.write_string("  1  发现 warning 及以上问题\n")
  s.write_string("  2  用法错误或读写失败\n")
  s.to_string()
}

///|
/// 命令行选项。
struct Options {
  files : Array[String]
  mut fix : Bool
  mut format : String
  mut config_path : String?
  mut markdown : Bool
  mut max_line_length : Int
  rule_overrides : Array[(String, Bool)]
  terminology : Array[(String, String)]
  mut list_rules : Bool
  mut help : Bool
  mut version : Bool
}

///|
/// JSON 取值：字符串。
fn json_string_value(j : Json) -> String? {
  match j {
    String(s) => Some(s)
    _ => None
  }
}

///|
/// 输出一段文本，去掉末尾换行，避免 `println` 追加多余空行。
fn output(text : String) -> Unit {
  let chars = text.iter().to_array()
  let mut n = chars.length()
  while n > 0 && (chars[n - 1] == '\n' || chars[n - 1] == '\r') {
    n = n - 1
  }
  if n == 0 {
    return
  }
  let buf = StringBuilder()
  for i = 0; i < n; i = i + 1 {
    buf.write_char(chars[i])
  }
  println(buf.to_string())
}

///|
/// 新建默认选项。
fn Options::new() -> Options {
  {
    files: [],
    fix: false,
    format: "text",
    config_path: None,
    markdown: false,
    max_line_length: 0,
    rule_overrides: [],
    terminology: [],
    list_rules: false,
    help: false,
    version: false,
  }
}

///|
/// 用法错误：打印提示并退出。
fn usage_error(msg : String) -> Unit {
  println("错误: \{msg}")
  println("")
  output(usage())
  @sys.exit(2)
}

///|
/// 解析非负整数，失败返回 `None`。
fn parse_uint(s : String) -> Int? {
  if s.is_empty() {
    return None
  }
  let mut v = 0
  for c in s {
    if !c.is_ascii_digit() {
      return None
    }
    v = v * 10 + (c.to_int() - 48)
  }
  Some(v)
}

///|
/// 按字符切分字符串。
fn split_char(s : String, sep : Char) -> Array[String] {
  let out : Array[String] = []
  let buf = StringBuilder()
  for c in s {
    if c == sep {
      out.push(buf.to_string())
      buf.reset()
    } else {
      buf.write_char(c)
    }
  }
  out.push(buf.to_string())
  out
}

///|
/// ASCII 转小写（用于术语表的键归一化）。
fn ascii_lower(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    buf.write_char(c.to_ascii_lowercase())
  }
  buf.to_string()
}

///|
/// 取下一个参数，越界则报用法错误。
fn next_arg(args : Array[String], i : Int, name : String) -> String {
  if i + 1 >= args.length() {
    usage_error("\{name} 需要一个参数")
  }
  args[i + 1]
}

///|
/// 解析 `id=on` 形式的布尔开关。
fn parse_bool_switch(raw : String) -> Bool? {
  match raw {
    "on" | "true" | "yes" | "1" => Some(true)
    "off" | "false" | "no" | "0" => Some(false)
    _ => None
  }
}

///|
/// 解析命令行参数。
fn parse_args(args : Array[String]) -> Options {
  let opts = Options::new()
  let mut i = 1
  while i < args.length() {
    let a = args[i]
    match a {
      "--fix" => opts.fix = true
      "--markdown" => opts.markdown = true
      "--list-rules" => opts.list_rules = true
      "--help" | "-h" => opts.help = true
      "--version" | "-v" => opts.version = true
      "--format" => {
        let v = next_arg(args, i, "--format")
        opts.format = v
        i = i + 1
      }
      "--config" => {
        opts.config_path = Some(next_arg(args, i, "--config"))
        i = i + 1
      }
      "--max-line-length" => {
        let raw = next_arg(args, i, "--max-line-length")
        match parse_uint(raw) {
          Some(n) => opts.max_line_length = n
          None =>
            usage_error(
              "--max-line-length 需要非负整数，收到「\{raw}」",
            )
        }
        i = i + 1
      }
      "--rule" => {
        let raw = next_arg(args, i, "--rule")
        let parts = split_char(raw, '=')
        if parts.length() != 2 {
          usage_error("--rule 需要形如 <id>=<on|off> 的参数")
        }
        match parse_bool_switch(parts[1]) {
          Some(b) =>
            if !@lib.is_known_rule(parts[0]) {
              usage_error(
                "未知规则 id「\{parts[0]}」，可用 --list-rules 查看",
              )
            } else {
              opts.rule_overrides.push((parts[0], b))
            }
          None => usage_error("--rule 的值只能是 on 或 off")
        }
        i = i + 1
      }
      "--terminology" => {
        let raw = next_arg(args, i, "--terminology")
        let parts = split_char(raw, '=')
        if parts.length() != 2 {
          usage_error(
            "--terminology 需要形如 <源>=<标准写法> 的参数",
          )
        }
        opts.terminology.push((parts[0], parts[1]))
        i = i + 1
      }
      _ => {
        if a.has_prefix("--") {
          usage_error("未知选项「\{a}」")
        }
        opts.files.push(a)
      }
    }
    i = i + 1
  }
  if opts.format != "text" && opts.format != "json" && opts.format != "github" {
    usage_error("--format 只支持 text / json / github")
  }
  opts
}

// ---------------------------------------------------------------------------
// 配置
// ---------------------------------------------------------------------------

///|
/// 读取文本文件。
fn read_text_file(path : String) -> Result[String, String] {
  Ok(@fs.read_file_to_string(path)) catch {
    _ => Err("读取文件失败")
  }
}

///|
/// 写入文本文件。
fn write_text_file(path : String, content : String) -> Result[Unit, String] {
  @fs.write_string_to_file(path, content) catch {
    _ => return Err("写入文件失败")
  }
  Ok(())
}

///|
/// JSON 取值：布尔。
fn json_bool(j : Json) -> Bool? {
  match j {
    True => Some(true)
    False => Some(false)
    _ => None
  }
}

///|
/// JSON 取值：整数。
fn json_int(j : Json) -> Int? {
  match j {
    Number(d, ..) => Some(d.to_int())
    _ => None
  }
}

///|
/// 把 JSON 配置应用到 `Config`。
fn apply_json_config(config : @lib.Config, j : Json) -> Unit {
  match j {
    Object(map) => {
      match map.get("markdown") {
        Some(v) =>
          match json_bool(v) {
            Some(b) => config.set_markdown(b)
            None => ()
          }
        None => ()
      }
      match map.get("maxLineLength") {
        Some(v) =>
          match json_int(v) {
            Some(n) => config.set_max_line_length(n)
            None => ()
          }
        None => ()
      }
      match map.get("rules") {
        Some(Object(rules)) =>
          for kv in rules.iter() {
            match json_bool(kv.1) {
              Some(b) => config.rules.set(kv.0, b)
              None => ()
            }
          }
        _ => ()
      }
      match map.get("terminology") {
        Some(Object(terms)) =>
          for kv in terms.iter() {
            match json_string_value(kv.1) {
              Some(v) => config.terminology.set(ascii_lower(kv.0), v)
              None => ()
            }
          }
        _ => ()
      }
    }
    _ => ()
  }
}

///|
/// 组装最终配置：文件配置 + 命令行覆盖。
fn build_config(opts : Options) -> @lib.Config {
  let config = if opts.markdown {
    @lib.Config::markdown()
  } else {
    @lib.Config::new()
  }
  match opts.config_path {
    Some(path) =>
      match read_text_file(path) {
        Err(msg) => {
          println("无法读取配置文件「\{path}」: \{msg}")
          @sys.exit(2)
        }
        Ok(text) => {
          let j = @json.parse(text) catch {
            e => {
              println("配置文件「\{path}」不是合法 JSON: \{e}")
              @sys.exit(2)
              Json::null()
            }
          }
          apply_json_config(config, j)
        }
      }
    None => ()
  }
  // 命令行覆盖优先级最高
  if opts.max_line_length > 0 {
    config.set_max_line_length(opts.max_line_length)
  }
  for kv in opts.rule_overrides {
    config.rules.set(kv.0, kv.1)
  }
  for kv in opts.terminology {
    config.terminology.set(ascii_lower(kv.0), kv.1)
  }
  config
}

// ---------------------------------------------------------------------------
// 主流程
// ---------------------------------------------------------------------------

///|
/// 处理单个文件，返回是否发现问题。
fn process_file(path : String, config : @lib.Config, opts : Options) -> Bool {
  let text = match read_text_file(path) {
    Ok(t) => t
    Err(msg) => {
      println("无法读取「\{path}」: \{msg}")
      @sys.exit(2)
      ""
    }
  }
  if opts.fix {
    let outcome = @lib.fix(text, config)
    if outcome.applied > 0 {
      match write_text_file(path, outcome.output) {
        Ok(_) => ()
        Err(msg) => {
          println("无法写入「\{path}」: \{msg}")
          @sys.exit(2)
        }
      }
    }
    println(
      "\{path}: 已应用 \{outcome.applied} 处修复，剩余 \{outcome.remaining.length()} 处问题",
    )
    if opts.format == "json" {
      output(@lib.render_json(outcome.remaining, path))
    }
    @lib.has_problems(outcome.remaining)
  } else {
    let diags = @lib.lint(text, config)
    match opts.format {
      "json" => output(@lib.render_json(diags, path))
      "github" => output(@lib.render_github(diags, path))
      _ => output(@lib.render_text(diags, path))
    }
    @lib.has_problems(diags)
  }
}

///|
/// 程序入口。
fn main {
  let args = @env.args()
  let opts = parse_args(args)
  if opts.help {
    output(usage())
    @sys.exit(0)
    return
  }
  if opts.version {
    println("mbt-typeset \{VERSION}")
    @sys.exit(0)
    return
  }
  if opts.list_rules {
    output(@lib.render_rule_list())
    @sys.exit(0)
    return
  }
  if opts.files.is_empty() {
    usage_error("至少需要一个输入文件")
  }
  let config = build_config(opts)
  let mut problems = false
  for path in opts.files {
    if process_file(path, config, opts) {
      problems = true
    }
  }
  if problems {
    @sys.exit(1)
  } else {
    @sys.exit(0)
  }
}
