///|
/// 内部规则表示：元信息 + 检查函数。
priv struct Rule {
  info : RuleInfo
  check : (Ctx) -> Array[Diagnostic]
}

///|
/// 构造一条诊断（`line` / `column` 由引擎补齐）。
fn mk_diag(
  rule : String,
  severity : Severity,
  message : String,
  start : Int,
  end : Int,
  replacement : String?,
) -> Diagnostic {
  { rule, severity, message, line: 0, column: 0, start, end, replacement, }
}

///|
/// 把 `chars[start, end)` 拼成字符串。
fn chars_to_string(chars : Array[Char], start : Int, end : Int) -> String {
  let buf = StringBuilder()
  let mut i = start
  while i < end && i < chars.length() {
    buf.write_char(chars[i])
    i = i + 1
  }
  buf.to_string()
}

///|
/// 在非代码行上执行 `f`，收集诊断。
fn scan_lines(
  ctx : Ctx,
  f : (SLine, Array[Diagnostic]) -> Unit,
) -> Array[Diagnostic] {
  let out : Array[Diagnostic] = []
  for line in ctx.lines {
    if !line.code {
      f(line, out)
    }
  }
  out
}

///|
/// 是否为可折叠的重复标点。
fn is_collapsible_punct(c : Char) -> Bool {
  match c {
    '。' | '，' | '、' | '；' | '：' | '！' | '？' => true
    _ => false
  }
}

///|
/// 是否为「左括号类」全角标点（其后不应有空格）。
fn is_left_fullwidth_punct(c : Char) -> Bool {
  match c {
    '（' | '“' | '‘' | '【' | '《' | '〈' | '「' | '『' => true
    _ => false
  }
}

///|
/// 是否为「右括号类 / 句读类」全角标点（其前不应有空格）。
fn is_right_fullwidth_punct(c : Char) -> Bool {
  match c {
    '）'
    | '”'
    | '’'
    | '】'
    | '》'
    | '〉'
    | '」'
    | '』'
    | '。'
    | '，'
    | '、'
    | '；'
    | '：'
    | '！'
    | '？'
    | '…'
    | '—' => true
    _ => false
  }
}

///|
/// 半角标点 -> 全角标点。
fn halfwidth_to_fullwidth(c : Char) -> Char? {
  match c {
    ',' => Some('，')
    ';' => Some('；')
    ':' => Some('：')
    '!' => Some('！')
    '?' => Some('？')
    '(' => Some('（')
    ')' => Some('）')
    _ => None
  }
}

///|
/// 全角标点 -> 半角标点（含补空格，用于英文语境）。
fn fullwidth_to_halfwidth(c : Char) -> String? {
  match c {
    '，' => Some(", ")
    '。' => Some(". ")
    '；' => Some("; ")
    '：' => Some(": ")
    '！' => Some("! ")
    '？' => Some("? ")
    _ => None
  }
}

///|
/// 数字与单位之间的空格：单位表（全部小写，按长度从长到短排列）。
///
/// 匹配时大小写不敏感，只插入空格、不改写单位本身的大小写，
/// 因此 `KB` / `kb` 都能匹配到 `kb`。
fn unit_list() -> Array[String] {
  [
    "gbps", "mbps", "kbps", "mmol", "kcal", "mah", "kwh", "ghz", "mhz", "khz", "dbi",
    "rpm", "fps", "dpi", "gb", "tb", "pb", "mb", "kb", "ms", "ns", "us", "min", "px",
    "kg", "mg", "km", "cm", "mm", "ml", "hz", "kj", "mol",
  ]
}

///|
/// 单词字符（用于术语匹配的边界判断）。
fn is_word_char(c : Char) -> Bool {
  is_ascii_alnum(c) || c == '_'
}

///|
/// 大小写不敏感地判断 `chars[i..]` 是否等于小写 `key`。
fn match_ci(chars : Array[Char], i : Int, key : String) -> Bool {
  let klen = key.char_length()
  if i + klen > chars.length() {
    return false
  }
  let mut k = 0
  for c in key {
    if chars[i + k].to_ascii_lowercase() != c {
      return false
    }
    k = k + 1
  }
  true
}

// ---------------------------------------------------------------------------
// 规则实现
// ---------------------------------------------------------------------------

///|
/// `cjk-latin-space`：中文与西文/数字之间需要空格。
fn check_cjk_latin_space(ctx : Ctx) -> Array[Diagnostic] {
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    let mut i = 0
    while i + 1 < n {
      if line.is_protected(i) || line.is_protected(i + 1) {
        i = i + 1
        continue
      }
      let a = line.chars[i]
      let b = line.chars[i + 1]
      let need = (is_cjk_ideograph(a) && is_ascii_alnum(b)) ||
        (is_ascii_alnum(a) && is_cjk_ideograph(b))
      if need {
        out.push(
          mk_diag(
            "cjk-latin-space",
            Warning,
            "中文与英文或数字之间应插入一个空格",
            line.start + i + 1,
            line.start + i + 1,
            Some(" "),
          ),
        )
      }
      i = i + 1
    }
  })
}

///|
/// `fullwidth-punct`：中文语境中的半角标点应使用全角。
fn check_fullwidth_punct(ctx : Ctx) -> Array[Diagnostic] {
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    let mut i = 0
    while i < n {
      if line.is_protected(i) {
        i = i + 1
        continue
      }
      match halfwidth_to_fullwidth(line.chars[i]) {
        None => i = i + 1
        Some(full) => {
          let prev = line.char_at(i - 1)
          let next = line.char_at(i + 1)
          let near_cjk = is_cjk_ideograph(prev) || is_cjk_ideograph(next)
          let left_ok = i == 0 || !line.is_protected(i - 1)
          let right_ok = i + 1 >= n || !line.is_protected(i + 1)
          let fire = match line.chars[i] {
            '(' => is_cjk_ideograph(next) && right_ok
            ')' => is_cjk_ideograph(prev) && left_ok
            _ => near_cjk && left_ok && right_ok
          }
          if fire {
            out.push(
              mk_diag(
                "fullwidth-punct",
                Warning,
                "中文语境中应使用全角标点「\{full}」",
                line.start + i,
                line.start + i + 1,
                Some(full.to_string()),
              ),
            )
          }
          i = i + 1
        }
      }
    }
  })
}

///|
/// `duplicate-punct`：重复标点只保留一个。
fn check_duplicate_punct(ctx : Ctx) -> Array[Diagnostic] {
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    let mut i = 0
    while i < n {
      if line.is_protected(i) || !is_collapsible_punct(line.chars[i]) {
        i = i + 1
        continue
      }
      let c = line.chars[i]
      let mut j = i
      while j < n && line.chars[j] == c {
        j = j + 1
      }
      let run = j - i
      if run >= 2 && !(c == '。' && run >= 3) {
        out.push(
          mk_diag(
            "duplicate-punct",
            Warning,
            "重复的标点，应只保留一个",
            line.start + i,
            line.start + j,
            Some(c.to_string()),
          ),
        )
      }
      i = j
    }
  })
}

///|
/// `ellipsis`：省略号统一为「……」。
fn check_ellipsis(ctx : Ctx) -> Array[Diagnostic] {
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    let mut i = 0
    while i < n {
      if line.is_protected(i) {
        i = i + 1
        continue
      }
      let c = line.chars[i]
      if c == '.' {
        let mut j = i
        while j < n && line.chars[j] == '.' {
          j = j + 1
        }
        if j - i >= 3 && line.chars[j - 1] == '.' {
          let prev_cjk = i > 0 && is_cjk_ideograph(line.char_at(i - 1))
          let next_cjk = is_cjk_ideograph(line.char_at(j))
          if prev_cjk || next_cjk {
            out.push(
              mk_diag(
                "ellipsis",
                Warning,
                "省略号应使用中文省略号「……」",
                line.start + i,
                line.start + j,
                Some("……"),
              ),
            )
          }
        }
        i = j
      } else if c == '。' {
        let mut j = i
        while j < n && line.chars[j] == '。' {
          j = j + 1
        }
        if j - i >= 3 {
          out.push(
            mk_diag(
              "ellipsis",
              Warning,
              "省略号应使用中文省略号「……」",
              line.start + i,
              line.start + j,
              Some("……"),
            ),
          )
        }
        i = j
      } else if c == '…' {
        let prev_is = i > 0 && line.char_at(i - 1) == '…'
        let next_is = line.char_at(i + 1) == '…'
        if !prev_is && !next_is {
          out.push(
            mk_diag(
              "ellipsis",
              Warning,
              "省略号应使用「……」而非单个「…」",
              line.start + i,
              line.start + i + 1,
              Some("……"),
            ),
          )
        }
        i = i + 1
      } else {
        i = i + 1
      }
    }
  })
}

///|
/// `dash`：中文语境中的 `--` / `---` 应使用破折号「——」。
fn check_dash(ctx : Ctx) -> Array[Diagnostic] {
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    let line_head = first_non_space(line.chars)
    let mut i = 0
    while i < n {
      if line.is_protected(i) || line.chars[i] != '-' {
        i = i + 1
        continue
      }
      let mut j = i
      while j < n && line.chars[j] == '-' {
        j = j + 1
      }
      let run = j - i
      let prev = line.char_at(i - 1)
      let next = line.char_at(j)
      let direct_cjk = is_cjk_ideograph(prev) || is_cjk_ideograph(next)
      // 形如「中文 -- 英文」：两侧带空格时，看空格外的字符
      let mut p = i - 1
      while p >= 0 && line.char_at(p) == ' ' {
        p = p - 1
      }
      let mut q = j
      while q < n && line.char_at(q) == ' ' {
        q = q + 1
      }
      let left_space = i == 0 || prev == ' '
      let right_space = j >= n || next == ' '
      let spaced_cjk = left_space &&
        right_space &&
        (is_cjk_ideograph(line.char_at(p)) || is_cjk_ideograph(line.char_at(q)))
      let near_cjk = direct_cjk || spaced_cjk
      let safe = i != line_head &&
        prev != '<' &&
        next != '>' &&
        prev != '|' &&
        next != '|' &&
        prev != '-' &&
        next != '-'
      if run >= 2 && run <= 3 && near_cjk && safe {
        out.push(
          mk_diag(
            "dash",
            Warning,
            "中文破折号应写作「——」",
            line.start + i,
            line.start + j,
            Some("——"),
          ),
        )
      }
      i = j
    }
  })
}

///|
/// `space-around-punct`：全角标点周围不应有多余空格。
fn check_space_around_punct(ctx : Ctx) -> Array[Diagnostic] {
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    let mut i = 0
    while i < n {
      if line.is_protected(i) {
        i = i + 1
        continue
      }
      let c = line.chars[i]
      if is_right_fullwidth_punct(c) && i > 0 && line.chars[i - 1] == ' ' {
        if !line.is_protected(i - 1) {
          out.push(
            mk_diag(
              "space-around-punct",
              Warning,
              "全角标点前不应有空格",
              line.start + i - 1,
              line.start + i,
              Some(""),
            ),
          )
        }
      }
      if is_left_fullwidth_punct(c) &&
        i >= 2 &&
        line.chars[i - 1] == ' ' &&
        is_cjk_ideograph(line.chars[i - 2]) &&
        !line.is_protected(i - 1) {
        out.push(
          mk_diag(
            "space-around-punct",
            Warning,
            "全角标点前不应有空格",
            line.start + i - 1,
            line.start + i,
            Some(""),
          ),
        )
      }
      if is_left_fullwidth_punct(c) && i + 1 < n && line.chars[i + 1] == ' ' {
        if !line.is_protected(i + 1) {
          out.push(
            mk_diag(
              "space-around-punct",
              Warning,
              "全角标点后不应有空格",
              line.start + i + 1,
              line.start + i + 2,
              Some(""),
            ),
          )
        }
      }
      if is_right_fullwidth_punct(c) && i + 1 < n && line.chars[i + 1] == ' ' {
        let after = line.char_at(i + 2)
        if !line.is_protected(i + 1) &&
          i + 2 < n &&
          (
            is_cjk_ideograph(after) ||
            is_cjk_punct(after) ||
            after.is_ascii_digit()
          ) {
          out.push(
            mk_diag(
              "space-around-punct",
              Warning,
              "全角标点后不应有空格",
              line.start + i + 1,
              line.start + i + 2,
              Some(""),
            ),
          )
        }
      }
      i = i + 1
    }
  })
}

///|
/// `number-unit-space`：数字与单位之间应有空格。
fn check_number_unit_space(ctx : Ctx) -> Array[Diagnostic] {
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    let units = unit_list()
    let mut i = 0
    while i < n {
      if line.is_protected(i) || !line.chars[i].is_ascii_alphabetic() {
        i = i + 1
        continue
      }
      let mut matched = ""
      for u in units {
        if match_ci(line.chars, i, u) {
          let len = u.char_length()
          let after = line.char_at(i + len)
          if is_ascii_alnum(after) {
            continue
          }
          matched = u
          break
        }
      }
      if matched == "" || i == 0 || !line.chars[i - 1].is_ascii_digit() {
        i = i + 1
        continue
      }
      out.push(
        mk_diag(
          "number-unit-space",
          Info,
          "数字与单位之间应插入一个空格",
          line.start + i,
          line.start + i,
          Some(" "),
        ),
      )
      i = i + matched.char_length()
    }
  })
}

///|
/// `terminology`：术语大小写 / 写法统一。
fn check_terminology(ctx : Ctx) -> Array[Diagnostic] {
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    for entry in ctx.config.terminology.iter() {
      let key = entry.0
      let preferred = entry.1
      let klen = key.char_length()
      if klen == 0 {
        continue
      }
      let mut i = 0
      while i < n {
        if i + klen > n {
          break
        }
        if line.is_protected(i) ||
          line.is_protected(i + klen - 1) ||
          !match_ci(line.chars, i, key) {
          i = i + 1
          continue
        }
        let prev_ok = i == 0 || !is_word_char(line.chars[i - 1])
        let next = line.char_at(i + klen)
        let next_ok = i + klen >= n || !is_word_char(next)
        if prev_ok && next_ok {
          let extracted = chars_to_string(line.chars, i, i + klen)
          if extracted != preferred {
            out.push(
              mk_diag(
                "terminology",
                Warning,
                "术语「\{extracted}」建议写作「\{preferred}」",
                line.start + i,
                line.start + i + klen,
                Some(preferred),
              ),
            )
          }
        }
        i = i + klen
      }
    }
  })
}

///|
/// `trailing-whitespace`：行尾不应有多余空白。
fn check_trailing_whitespace(ctx : Ctx) -> Array[Diagnostic] {
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    if n == 0 {
      return
    }
    let mut end = n
    while end > 0 && is_space_char(line.chars[end - 1]) {
      end = end - 1
    }
    if end == n {
      return
    }
    let trailing = n - end
    // Markdown 中「行尾恰好两个空格」是硬换行，属合法语法
    if ctx.config.markdown && trailing == 2 {
      return
    }
    out.push(
      mk_diag(
        "trailing-whitespace",
        Warning,
        "行尾有多余空白",
        line.start + end,
        line.start + n,
        Some(""),
      ),
    )
  })
}

///|
/// `heading-space`：Markdown 标题的 `#` 之后应有空格。
fn check_heading_space(ctx : Ctx) -> Array[Diagnostic] {
  if !ctx.config.markdown {
    return []
  }
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    let s = first_non_space(line.chars)
    if s >= n || line.chars[s] != '#' {
      return
    }
    let mut j = s
    while j < n && line.chars[j] == '#' {
      j = j + 1
    }
    let level = j - s
    if level < 1 || level > 6 || j >= n {
      return
    }
    let c = line.chars[j]
    if c != ' ' && c != '\t' && c != '#' {
      out.push(
        mk_diag(
          "heading-space",
          Warning,
          "标题的「#」之后应加一个空格",
          line.start + j,
          line.start + j,
          Some(" "),
        ),
      )
    }
  })
}

///|
/// `list-marker-space`：Markdown 列表标记之后应有空格。
fn check_list_marker_space(ctx : Ctx) -> Array[Diagnostic] {
  if !ctx.config.markdown {
    return []
  }
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    let s = first_non_space(line.chars)
    if s >= n {
      return
    }
    let c = line.chars[s]
    if c == '-' || c == '*' || c == '+' {
      if s + 1 < n {
        let next = line.chars[s + 1]
        if next != ' ' && next != '\t' && next != c && next != '*' {
          out.push(
            mk_diag(
              "list-marker-space",
              Warning,
              "列表标记之后应加一个空格",
              line.start + s + 1,
              line.start + s + 1,
              Some(" "),
            ),
          )
        }
      }
    } else if c.is_ascii_digit() {
      let mut d = s
      while d < n && line.chars[d].is_ascii_digit() {
        d = d + 1
      }
      if d < n && line.chars[d] == '.' && d + 1 < n {
        let next = line.chars[d + 1]
        if next != ' ' && next != '\t' && !next.is_ascii_digit() {
          out.push(
            mk_diag(
              "list-marker-space",
              Warning,
              "有序列表标记之后应加一个空格",
              line.start + d + 1,
              line.start + d + 1,
              Some(" "),
            ),
          )
        }
      }
    }
  })
}

///|
/// `blockquote-space`：Markdown 引用块的 `>` 之后应有空格。
fn check_blockquote_space(ctx : Ctx) -> Array[Diagnostic] {
  if !ctx.config.markdown {
    return []
  }
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    let s = first_non_space(line.chars)
    if s >= n || line.chars[s] != '>' {
      return
    }
    let j = s + 1
    if j < n {
      let next = line.chars[j]
      if next != ' ' && next != '\t' && next != '>' {
        out.push(
          mk_diag(
            "blockquote-space",
            Warning,
            "引用块的「>」之后应加一个空格",
            line.start + j,
            line.start + j,
            Some(" "),
          ),
        )
      }
    }
  })
}

///|
/// `halfwidth-punct-in-latin`：英文语境中的全角标点应使用半角。
fn check_halfwidth_punct_in_latin(ctx : Ctx) -> Array[Diagnostic] {
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    let mut i = 0
    while i < n {
      if line.is_protected(i) {
        i = i + 1
        continue
      }
      match fullwidth_to_halfwidth(line.chars[i]) {
        None => i = i + 1
        Some(repl) => {
          let prev = line.char_at(i - 1)
          let next = line.char_at(i + 1)
          if (is_ascii_alnum(prev) || prev == ')') &&
            (is_ascii_alnum(next) || next == '(') {
            out.push(
              mk_diag(
                "halfwidth-punct-in-latin",
                Info,
                "英文语境中应使用半角标点",
                line.start + i,
                line.start + i + 1,
                Some(repl),
              ),
            )
          }
          i = i + 1
        }
      }
    }
  })
}

///|
/// `consecutive-spaces`：正文中不应出现连续空格。
fn check_consecutive_spaces(ctx : Ctx) -> Array[Diagnostic] {
  if ctx.config.markdown {
    return []
  }
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    let mut i = 1
    while i < n {
      if line.chars[i] == ' ' &&
        line.chars[i - 1] == ' ' &&
        !line.is_protected(i) {
        let mut j = i
        while j < n && line.chars[j] == ' ' {
          j = j + 1
        }
        let only_trailing = j >= n
        if !only_trailing {
          out.push(
            mk_diag(
              "consecutive-spaces",
              Info,
              "存在连续空格，应只保留一个",
              line.start + i - 1,
              line.start + j,
              Some(" "),
            ),
          )
        }
        i = j
      } else {
        i = i + 1
      }
    }
  })
}

///|
/// `line-length`：行宽上限。
fn check_line_length(ctx : Ctx) -> Array[Diagnostic] {
  if ctx.config.max_line_length <= 0 {
    return []
  }
  let limit = ctx.config.max_line_length
  scan_lines(ctx, fn(line, out) {
    let n = line.chars.length()
    if n > limit {
      out.push(
        mk_diag(
          "line-length",
          Info,
          "行宽超过 \{limit} 个字符（当前 \{n}）",
          line.start + limit,
          line.start + n,
          None,
        ),
      )
    }
  })
}

///|
/// `unclosed-code-fence`：Markdown 代码围栏未闭合。
fn check_unclosed_code_fence(ctx : Ctx) -> Array[Diagnostic] {
  if !ctx.config.markdown || ctx.unclosed_fence <= 0 {
    return []
  }
  let idx = ctx.unclosed_fence - 1
  if idx >= ctx.lines.length() {
    return []
  }
  let line = ctx.lines[idx]
  [
    mk_diag(
      "unclosed-code-fence",
      Error,
      "代码围栏未闭合：文档结尾缺少配对的 ``` 或 ~~~",
      line.start,
      line.start + line.chars.length(),
      None,
    ),
  ]
}

// ---------------------------------------------------------------------------
// 规则注册表
// ---------------------------------------------------------------------------

///|
/// 全部规则。数组顺序即为诊断的默认排序优先级（同位置时）。
pub fn rules() -> Array[RuleInfo] {
  let out : Array[RuleInfo] = []
  for r in rule_set() {
    out.push(r.info)
  }
  out
}

///|
/// 内部规则表。
fn rule_set() -> Array[Rule] {
  [
    {
      info: {
        id: "unclosed-code-fence",
        description: "Markdown 代码围栏未闭合",
        severity: Error,
        enabled_by_default: true,
        fixable: false,
      },
      check: fn(ctx) { check_unclosed_code_fence(ctx) },
    },
    {
      info: {
        id: "cjk-latin-space",
        description: "中文与英文、数字之间插入空格",
        severity: Warning,
        enabled_by_default: true,
        fixable: true,
      },
      check: fn(ctx) { check_cjk_latin_space(ctx) },
    },
    {
      info: {
        id: "fullwidth-punct",
        description: "中文语境中的半角标点改为全角",
        severity: Warning,
        enabled_by_default: true,
        fixable: true,
      },
      check: fn(ctx) { check_fullwidth_punct(ctx) },
    },
    {
      info: {
        id: "duplicate-punct",
        description: "重复标点只保留一个",
        severity: Warning,
        enabled_by_default: true,
        fixable: true,
      },
      check: fn(ctx) { check_duplicate_punct(ctx) },
    },
    {
      info: {
        id: "ellipsis",
        description: "省略号统一为「……」",
        severity: Warning,
        enabled_by_default: true,
        fixable: true,
      },
      check: fn(ctx) { check_ellipsis(ctx) },
    },
    {
      info: {
        id: "dash",
        description: "中文破折号统一为「——」",
        severity: Warning,
        enabled_by_default: true,
        fixable: true,
      },
      check: fn(ctx) { check_dash(ctx) },
    },
    {
      info: {
        id: "space-around-punct",
        description: "全角标点周围不应有多余空格",
        severity: Warning,
        enabled_by_default: true,
        fixable: true,
      },
      check: fn(ctx) { check_space_around_punct(ctx) },
    },
    {
      info: {
        id: "number-unit-space",
        description: "数字与单位之间插入空格",
        severity: Info,
        enabled_by_default: true,
        fixable: true,
      },
      check: fn(ctx) { check_number_unit_space(ctx) },
    },
    {
      info: {
        id: "terminology",
        description: "术语大小写与写法统一",
        severity: Warning,
        enabled_by_default: true,
        fixable: true,
      },
      check: fn(ctx) { check_terminology(ctx) },
    },
    {
      info: {
        id: "trailing-whitespace",
        description: "行尾不应有多余空白",
        severity: Warning,
        enabled_by_default: true,
        fixable: true,
      },
      check: fn(ctx) { check_trailing_whitespace(ctx) },
    },
    {
      info: {
        id: "heading-space",
        description: "Markdown 标题的 # 之后应有空格",
        severity: Warning,
        enabled_by_default: true,
        fixable: true,
      },
      check: fn(ctx) { check_heading_space(ctx) },
    },
    {
      info: {
        id: "list-marker-space",
        description: "Markdown 列表标记之后应有空格",
        severity: Warning,
        enabled_by_default: true,
        fixable: true,
      },
      check: fn(ctx) { check_list_marker_space(ctx) },
    },
    {
      info: {
        id: "blockquote-space",
        description: "Markdown 引用块的 > 之后应有空格",
        severity: Warning,
        enabled_by_default: true,
        fixable: true,
      },
      check: fn(ctx) { check_blockquote_space(ctx) },
    },
    {
      info: {
        id: "halfwidth-punct-in-latin",
        description: "英文语境中的全角标点改为半角（默认关闭）",
        severity: Info,
        enabled_by_default: false,
        fixable: true,
      },
      check: fn(ctx) { check_halfwidth_punct_in_latin(ctx) },
    },
    {
      info: {
        id: "consecutive-spaces",
        description: "正文中不应出现连续空格（默认关闭）",
        severity: Info,
        enabled_by_default: false,
        fixable: true,
      },
      check: fn(ctx) { check_consecutive_spaces(ctx) },
    },
    {
      info: {
        id: "line-length",
        description: "行宽上限检查（默认关闭，需设置 maxLineLength）",
        severity: Info,
        enabled_by_default: false,
        fixable: false,
      },
      check: fn(ctx) { check_line_length(ctx) },
    },
  ]
}
