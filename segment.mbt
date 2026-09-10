///|
/// 切分后的一行原始内容。
priv struct RawLine {
  chars : Array[Char]
  newline : String
}

///|
/// 扫描结果：所有扫描行 + 未闭合代码围栏的行号（1 起始，0 表示没有）。
priv struct ScanResult {
  lines : Array[SLine]
  unclosed_fence : Int
}

///|
/// 扫描单元：一行文本 + 位置 + 是否位于「不检查」区域 + 逐字符保护掩码。
///
/// `mask[i]` 为 `true` 表示第 i 个字符处于受保护区间（例如行内代码、URL），
/// 内容类规则应当跳过这些位置。
priv struct SLine {
  chars : Array[Char]
  /// 该行首字符在全文中的字符偏移
  start : Int
  /// 是否属于代码块 / 前置元数据等「不检查」区域
  code : Bool
  /// 逐字符保护掩码，长度与 `chars` 相同
  mask : Array[Bool]
}

///|
/// 判断是否为空白字符（空格或制表符）。
fn is_space_char(c : Char) -> Bool {
  c == ' ' || c == '\t'
}

///|
/// 返回第一个非空白字符的下标；全为空白时返回长度。
fn first_non_space(chars : Array[Char]) -> Int {
  let mut i = 0
  while i < chars.length() && is_space_char(chars[i]) {
    i = i + 1
  }
  i
}

///|
/// 判断去掉首尾空白后是否等于 `s`。
fn trimmed_equals(chars : Array[Char], s : String) -> Bool {
  let start = first_non_space(chars)
  let mut end = chars.length()
  while end > start && is_space_char(chars[end - 1]) {
    end = end - 1
  }
  if end - start != s.char_length() {
    return false
  }
  let mut i = start
  let mut ok = true
  for c in s {
    if i >= end || chars[i] != c {
      ok = false
      break
    }
    i = i + 1
  }
  ok
}

///|
/// 若该行是一个代码围栏（``` 或 ~~~），返回围栏使用的字符。
fn fence_marker(chars : Array[Char]) -> Char? {
  let i = first_non_space(chars)
  if i >= chars.length() {
    return None
  }
  let c = chars[i]
  if c != '`' && c != '~' {
    return None
  }
  let mut j = i
  while j < chars.length() && chars[j] == c {
    j = j + 1
  }
  if j - i >= 3 {
    Some(c)
  } else {
    None
  }
}

///|
/// 逐字符切分为行，保留各行原本的换行符（`\n` 或 `\r\n`）。
fn split_raw_lines(source : String) -> Array[RawLine] {
  let out : Array[RawLine] = []
  let cur : Array[Char] = []
  for c in source {
    if c == '\n' {
      let mut nl = "\n"
      if cur.length() > 0 && cur[cur.length() - 1] == '\r' {
        let _ = cur.pop()
        nl = "\r\n"
      }
      out.push(RawLine::{ chars: cur.copy(), newline: nl, })
      cur.clear()
    } else {
      cur.push(c)
    }
  }
  if cur.length() > 0 {
    out.push(RawLine::{ chars: cur, newline: "", })
  }
  out
}

///|
/// 在 `chars` 中从 `from` 开始查找连续 `ticks` 个反引号的结束位置（返回其后的下标），找不到返回 -1。
fn find_ticks_close(chars : Array[Char], from : Int, ticks : Int) -> Int {
  let n = chars.length()
  let mut k = from
  while k < n {
    if chars[k] == '`' {
      let mut m = k
      while m < n && chars[m] == '`' {
        m = m + 1
      }
      if m - k == ticks {
        return m
      }
      k = m
    } else {
      k = k + 1
    }
  }
  -1
}

///|
/// 判断 `chars` 从 `i` 开始是否匹配 ASCII 前缀 `p`。
fn matches_at(chars : Array[Char], i : Int, p : String) -> Bool {
  let plen = p.char_length()
  if i + plen > chars.length() {
    return false
  }
  let mut k = 0
  let mut ok = true
  for c in p {
    if chars[i + k] != c {
      ok = false
      break
    }
    k = k + 1
  }
  ok
}

///|
/// 检测常见 URL / 邮箱前缀，返回前缀长度；不匹配返回 0。
fn url_prefix_len(chars : Array[Char], i : Int) -> Int {
  let prefixes : Array[String] = [
    "https://", "http://", "ftp://", "mailto:", "www.", "git@",
  ]
  for p in prefixes {
    if matches_at(chars, i, p) {
      return p.char_length()
    }
  }
  0
}

///|
/// URL 的终止字符：空白、CJK 文字、CJK 标点，以及成对的括号与引号。
fn is_url_terminator(c : Char) -> Bool {
  is_space_char(c) ||
  is_cjk_ideograph(c) ||
  is_cjk_punct(c) ||
  c == '"' ||
  c == '\'' ||
  c == '<' ||
  c == '>' ||
  c == '`'
}

///|
/// 构造一行的保护掩码：行内代码、URL、Markdown 链接目标、尖括号包裹的内容。
fn build_mask(chars : Array[Char]) -> Array[Bool] {
  let n = chars.length()
  let mask = Array::make(n, false)
  let mut i = 0
  while i < n {
    let c = chars[i]
    if c == '`' {
      let mut j = i
      while j < n && chars[j] == '`' {
        j = j + 1
      }
      let ticks = j - i
      let close = find_ticks_close(chars, j, ticks)
      if close >= 0 {
        for p = i; p < close; p = p + 1 {
          mask[p] = true
        }
        i = close
      } else {
        i = j
      }
    } else if c == ']' && i + 1 < n && chars[i + 1] == '(' {
      // Markdown 链接 / 图片目标
      let mut k = i + 2
      let mut close = -1
      while k < n {
        if chars[k] == ')' {
          close = k
          break
        }
        k = k + 1
      }
      if close >= 0 {
        for p = i; p <= close; p = p + 1 {
          mask[p] = true
        }
        i = close + 1
      } else {
        i = i + 1
      }
    } else if c == '(' && i > 0 && chars[i - 1] == ']' {
      // 理论上已由上一条分支处理，这里跳过避免重复
      i = i + 1
    } else if c == '<' {
      let mut k = i + 1
      let mut close = -1
      let mut has_space = false
      while k < n {
        if chars[k] == '>' {
          close = k
          break
        }
        if is_space_char(chars[k]) {
          has_space = true
        }
        k = k + 1
      }
      if close >= 0 && !has_space {
        for p = i; p <= close; p = p + 1 {
          mask[p] = true
        }
        i = close + 1
      } else {
        i = i + 1
      }
    } else if url_prefix_len(chars, i) > 0 {
      let mut k = i
      while k < n && !is_url_terminator(chars[k]) {
        k = k + 1
      }
      for p = i; p < k; p = p + 1 {
        mask[p] = true
      }
      i = k
    } else if c == '@' && i > 0 {
      // 邮箱：向左吃掉单词字符，向右直到终止符
      let mut start = i
      while start > 0 &&
            !is_space_char(chars[start - 1]) &&
            !is_cjk_punct(chars[start - 1]) {
        start = start - 1
      }
      let mut k = i + 1
      while k < n && !is_url_terminator(chars[k]) {
        k = k + 1
      }
      if k > i + 1 {
        for p = start; p < k; p = p + 1 {
          mask[p] = true
        }
        i = k
      } else {
        i = i + 1
      }
    } else {
      i = i + 1
    }
  }
  mask
}

///|
/// 把全文切分为扫描行，并标注代码区域与保护掩码。
fn scan_source(source : String, markdown : Bool) -> ScanResult {
  let raws = split_raw_lines(source)
  let out : Array[SLine] = []
  let mut offset = 0
  let mut fence : Char? = None
  let mut fence_line = 0
  let mut in_front_matter = false
  let mut k = 0
  while k < raws.length() {
    let raw = raws[k]
    let mut code = false
    if markdown && k == 0 && trimmed_equals(raw.chars, "---") {
      in_front_matter = true
      code = true
    } else if in_front_matter {
      code = true
      if trimmed_equals(raw.chars, "---") || trimmed_equals(raw.chars, "...") {
        in_front_matter = false
      }
    }
    if !code {
      match fence {
        Some(f) => {
          code = true
          if fence_marker(raw.chars) == Some(f) {
            fence = None
            fence_line = 0
          }
        }
        None =>
          match fence_marker(raw.chars) {
            Some(f) => {
              fence = Some(f)
              fence_line = k + 1
              code = true
            }
            None => ()
          }
      }
    }
    let mask = if code {
      Array::make(raw.chars.length(), true)
    } else {
      build_mask(raw.chars)
    }
    out.push(SLine::{ chars: raw.chars, start: offset, code, mask, })
    offset = offset + raw.chars.length() + raw.newline.length()
    k = k + 1
  }
  { lines: out, unclosed_fence: fence_line, }
}

///|
/// 规则执行上下文。
priv struct Ctx {
  lines : Array[SLine]
  config : Config
  /// 未闭合代码围栏所在行号（1 起始，0 表示没有）
  unclosed_fence : Int
}

///|
/// 位置是否落在受保护区间内（越界视为受保护）。
fn SLine::is_protected(self : SLine, i : Int) -> Bool {
  if i < 0 || i >= self.mask.length() {
    return true
  }
  self.mask[i]
}

///|
/// 取第 i 个字符；越界返回换行（便于统一处理行尾）。
fn SLine::char_at(self : SLine, i : Int) -> Char {
  if i < 0 || i >= self.chars.length() {
    return '\n'
  }
  self.chars[i]
}
