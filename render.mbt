///|
/// 严重级别的短标签。
pub fn Severity::label(self : Severity) -> String {
  match self {
    Error => "error"
    Warning => "warning"
    Info => "info"
  }
}

///|
/// 文本格式输出：`文件:行:列: 级别 [规则] 说明`。
///
/// `file` 为空时省略文件前缀。
pub fn render_text(diags : Array[Diagnostic], file : String) -> String {
  let buf = StringBuilder()
  for d in diags {
    if file != "" {
      buf.write_string(file)
      buf.write_char(':')
    }
    buf.write_string(d.line.to_string())
    buf.write_char(':')
    buf.write_string(d.column.to_string())
    buf.write_string(": ")
    buf.write_string(d.severity.label())
    buf.write_string(" [")
    buf.write_string(d.rule)
    buf.write_string("] ")
    buf.write_string(d.message)
    match d.replacement {
      Some(_) => buf.write_string(" (可自动修复)")
      None => ()
    }
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
/// 单条诊断转 JSON。
pub fn Diagnostic::to_json(self : Diagnostic) -> Json {
  let fields : Map[String, Json] = {
    "rule": Json::string(self.rule),
    "severity": Json::string(self.severity.label()),
    "message": Json::string(self.message),
    "line": Json::number(self.line.to_double(), repr=self.line.to_string()),
    "column": Json::number(
      self.column.to_double(),
      repr=self.column.to_string(),
    ),
    "fixable": Json::boolean(self.replacement is Some(_)),
  }
  Json::object(fields)
}

///|
/// JSON 格式输出（便于其它工具消费）。
pub fn render_json(diags : Array[Diagnostic], file : String) -> String {
  let arr : Array[Json] = []
  for d in diags {
    arr.push(d.to_json())
  }
  let obj = Json::object({
    "file": Json::string(file),
    "diagnostics": Json::array(arr),
    "count": Json::number(
      arr.length().to_double(),
      repr=arr.length().to_string(),
    ),
  })
  obj.stringify()
}

///|
/// GitHub Actions 注解格式：`::warning file=...,line=...,col=...::消息`。
pub fn render_github(diags : Array[Diagnostic], file : String) -> String {
  let buf = StringBuilder()
  for d in diags {
    let level = match d.severity {
      Error => "error"
      Warning => "warning"
      Info => "notice"
    }
    buf.write_string("::")
    buf.write_string(level)
    buf.write_string(" file=")
    buf.write_string(file)
    buf.write_string(",line=")
    buf.write_string(d.line.to_string())
    buf.write_string(",col=")
    buf.write_string(d.column.to_string())
    buf.write_string(",title=")
    buf.write_string(d.rule)
    buf.write_string("::")
    buf.write_string(d.message)
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
/// 规则列表的文本表格（`--list-rules`）。
pub fn render_rule_list() -> String {
  let buf = StringBuilder()
  buf.write_string("规则 id                        默认  修复  说明\n")
  buf.write_string(
    "--------------------------------------------------------------------------------\n",
  )
  for info in rule_infos() {
    let mut id = info.id
    while id.length() < 30 {
      id = id + " "
    }
    let def = if info.enabled_by_default { "开  " } else { "关  " }
    let fix = if info.fixable { "是  " } else { "否  " }
    buf.write_string(id)
    buf.write_string(def)
    buf.write_string(fix)
    buf.write_string(info.description)
    buf.write_char('\n')
  }
  buf.to_string()
}
