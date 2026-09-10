///|
/// 全部规则的元信息。
pub fn rule_infos() -> Array[RuleInfo] {
  rules()
}

///|
/// 判断规则 id 是否已知。
pub fn is_known_rule(id : String) -> Bool {
  let mut found = false
  for info in rules() {
    if info.id == id {
      found = true
      break
    }
  }
  found
}

///|
/// 复制一条诊断并补上行列信息。
fn with_location(d : Diagnostic, line : Int, column : Int) -> Diagnostic {
  {
    rule: d.rule,
    severity: d.severity,
    message: d.message,
    line,
    column,
    start: d.start,
    end: d.end,
    replacement: d.replacement,
  }
}

///|
/// 为诊断补齐 1 起始的行列号。
fn locate(diags : Array[Diagnostic], lines : Array[SLine]) -> Unit {
  let n_lines = lines.length()
  for i = 0; i < diags.length(); i = i + 1 {
    let d = diags[i]
    let mut line_no = 1
    let mut column = 1
    let mut found = false
    for k = 0; k < n_lines; k = k + 1 {
      let line = lines[k]
      let line_end = line.start + line.chars.length()
      if d.start >= line.start && d.start <= line_end {
        line_no = k + 1
        column = d.start - line.start + 1
        found = true
        break
      }
    }
    if !found && n_lines > 0 {
      line_no = n_lines
      column = lines[n_lines - 1].chars.length() + 1
    }
    diags[i] = with_location(d, line_no, column)
  }
}

///|
/// 按起始位置、结束位置、规则 id 稳定排序诊断。
fn sort_diags(diags : Array[Diagnostic]) -> Unit {
  diags.sort_by(fn(a, b) {
    if a.start != b.start {
      return a.start - b.start
    }
    if a.end != b.end {
      return a.end - b.end
    }
    a.rule.compare(b.rule)
  })
}

///|
/// 对文本做排版检查。
///
/// 返回值按位置排序，`line` / `column` 已填充。
pub fn lint(source : String, config : Config) -> Array[Diagnostic] {
  let scan = scan_source(source, config.markdown)
  let ctx = Ctx::{
    lines: scan.lines,
    config,
    unclosed_fence: scan.unclosed_fence,
  }
  let out : Array[Diagnostic] = []
  for rule in rule_set() {
    if config.is_enabled(rule.info.id, rule.info.enabled_by_default) {
      out.append((rule.check)(ctx))
    }
  }
  locate(out, scan.lines)
  sort_diags(out)
  out
}

///|
/// 是否存在严重级别 >= Warning 的诊断（用于 CLI 退出码）。
pub fn has_problems(diags : Array[Diagnostic]) -> Bool {
  let mut found = false
  for d in diags {
    match d.severity {
      Error | Warning => {
        found = true
        break
      }
      Info => ()
    }
  }
  found
}

///|
/// 对文本执行排版检查。
pub fn lint_with_default_config(source : String) -> Array[Diagnostic] {
  lint(source, Config::new())
}

///|
/// 应用一批互不重叠的诊断修复，返回修复后的文本。
fn apply_edits(chars : Array[Char], edits : Array[Diagnostic]) -> String {
  let sorted = edits.copy()
  sort_diags(sorted)
  let buf = StringBuilder()
  let mut pos = 0
  let mut last_start = -1
  let mut last_end = -1
  for d in sorted {
    if d.start < pos {
      // 与前一个编辑重叠，留到下一轮再处理
      continue
    }
    if d.start == last_start && d.end == last_end {
      // 同一位置的重复插入，跳过
      continue
    }
    match d.replacement {
      None => ()
      Some(repl) => {
        while pos < d.start {
          buf.write_char(chars[pos])
          pos = pos + 1
        }
        buf.write_string(repl)
        pos = d.end
        last_start = d.start
        last_end = d.end
      }
    }
  }
  while pos < chars.length() {
    buf.write_char(chars[pos])
    pos = pos + 1
  }
  buf.to_string()
}

///|
/// 自动修复文本。
///
/// 反复「检查 -> 应用可修复项」直到收敛（最多 8 轮），因此结果是幂等的：
/// 对同一份输入重复调用 `fix`，第二次不会再产生任何改动。
pub fn fix(source : String, config : Config) -> FixOutcome {
  let mut text = source
  let mut applied = 0
  let mut remaining : Array[Diagnostic] = []
  let mut round = 0
  while round < 8 {
    let diags = lint(text, config)
    let edits : Array[Diagnostic] = []
    for d in diags {
      match d.replacement {
        Some(_) => edits.push(d)
        None => ()
      }
    }
    if edits.is_empty() {
      remaining = diags
      break
    }
    let chars = text.iter().to_array()
    text = apply_edits(chars, edits)
    applied = applied + edits.length()
    round = round + 1
    if round >= 8 {
      remaining = lint(text, config)
    }
  }
  { output: text, applied, remaining, }
}
