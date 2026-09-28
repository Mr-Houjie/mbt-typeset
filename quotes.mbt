///|
/// 引号类型。
pub enum QuoteKind {
  DoubleQuote
  SingleQuote
} derive(Eq, Debug)

///|
pub extend QuoteKind with Eq::{not_equal, equal}

///|
pub extend QuoteKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// 一次引号替换编辑。
pub struct QuoteEdit {
  /// 全文字符偏移（闭端）
  start : Int
  /// 全文字符偏移（开端）
  end : Int
  /// 替换文本
  text : String
  /// 是否为开引号
  opening : Bool
} derive(Eq, Debug)

///|
pub extend QuoteEdit with Eq::{not_equal, equal}

///|
pub extend QuoteEdit with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// 未配对的引号。
pub struct UnpairedQuote {
  /// 全文字符偏移（闭端）
  start : Int
  /// 全文字符偏移（开端）
  end : Int
  kind : QuoteKind
  /// `true` 表示这是一个缺少闭引号的开引号
  opening : Bool
} derive(Eq, Debug)

///|
pub extend UnpairedQuote with Eq::{not_equal, equal}

///|
pub extend UnpairedQuote with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// 一行的引号扫描结果。
pub struct QuoteScan {
  /// 需要替换的引号编辑，按位置升序
  edits : Array[QuoteEdit]
  /// 扫描过程中发现的未配对引号
  unpaired : Array[UnpairedQuote]
} derive(Debug)

///|
pub extend QuoteScan with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// 判断是否为直引号（`"` 或 `'`）。
pub fn is_straight_quote(c : Char) -> Bool {
  c == '"' || c == '\''
}

///|
/// 判断是否为开括号类字符：其后的引号应为开引号。
fn is_open_bracket_char(c : Char) -> Bool {
  match c {
    '('
    | '['
    | '{'
    | '（'
    | '［'
    | '｛'
    | '【'
    | '《'
    | '〈'
    | '「'
    | '『'
    | '〔'
    | '“'
    | '‘' => true
    _ => false
  }
}

///|
/// 判断是否为闭括号 / 句读类字符：其前的引号应为闭引号。
fn is_close_punct_char(c : Char) -> Bool {
  match c {
    ')'
    | ']'
    | '}'
    | '）'
    | '］'
    | '｝'
    | '】'
    | '》'
    | '〉'
    | '」'
    | '』'
    | '〕'
    | '”'
    | '’'
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
/// 向左找最近的非空白字符。
fn prev_non_space_char(chars : Array[Char], i : Int) -> Char? {
  let mut k = i - 1
  while k >= 0 {
    if !is_space_char(chars[k]) {
      return Some(chars[k])
    }
    k = k - 1
  }
  None
}

///|
/// 向右找最近的非空白字符。
fn next_non_space_char(chars : Array[Char], i : Int) -> Char? {
  let mut k = i + 1
  while k < chars.length() {
    if !is_space_char(chars[k]) {
      return Some(chars[k])
    }
    k = k + 1
  }
  None
}

///|
/// 判断位置 `i` 附近是否出现 CJK 文字，用于界定「中文语境」。
///
/// 只有处于中文语境的直引号才会被转换为弯引号，纯英文段落不受影响。
fn has_cjk_nearby(chars : Array[Char], i : Int, radius : Int) -> Bool {
  let mut k = i - radius
  while k <= i + radius {
    if k >= 0 && k < chars.length() && is_cjk_ideograph(chars[k]) {
      return true
    }
    k = k + 1
  }
  false
}

///|
/// 判断该位置的 `'` 是否为英文撇号（如 `don't`）。
///
/// 只有两侧都是 ASCII 字母数字时才视为撇号；中文两侧的单引号仍按引号处理。
fn is_apostrophe(chars : Array[Char], i : Int) -> Bool {
  if chars[i] != '\'' {
    return false
  }
  match (prev_non_space_char(chars, i), next_non_space_char(chars, i)) {
    (Some(p), Some(n)) => is_ascii_alnum(p) && is_ascii_alnum(n)
    _ => false
  }
}

///|
/// 判断引号方向：`true` 为开引号。
///
/// 先看上下文（前面的字符、后面的字符），上下文不明确时退回「交替」状态。
fn classify_quote(chars : Array[Char], i : Int, inside : Bool) -> Bool {
  match prev_non_space_char(chars, i) {
    None => true
    Some(prev) =>
      if is_open_bracket_char(prev) {
        true
      } else {
        match next_non_space_char(chars, i) {
          None => false
          Some(next) => {
            let prev_is_word = is_cjk_ideograph(prev) ||
              is_ascii_alnum(prev) ||
              is_close_punct_char(prev)
            let next_is_boundary = is_cjk_punct(next) ||
              is_ascii_punct(next) ||
              is_close_punct_char(next)
            if prev_is_word && next_is_boundary {
              false
            } else if is_ascii_punct(prev) && !is_straight_quote(prev) {
              true
            } else {
              !inside
            }
          }
        }
      }
  }
}

///|
/// 跨行扫描时需要在行间传递的引号状态。
priv struct QuoteCarry {
  in_double : Bool
  in_single : Bool
  /// 未闭合开引号的绝对偏移，`-1` 表示没有
  double_open : Int
  single_open : Int
}

///|
/// 空状态。
fn QuoteCarry::empty() -> QuoteCarry {
  { in_double: false, in_single: false, double_open: -1, single_open: -1, }
}

///|
/// 当前仍未闭合的开引号。
fn QuoteCarry::dangling(self : QuoteCarry) -> Array[UnpairedQuote] {
  let out : Array[UnpairedQuote] = []
  if self.double_open >= 0 {
    out.push({
      start: self.double_open,
      end: self.double_open + 1,
      kind: DoubleQuote,
      opening: true,
    })
  }
  if self.single_open >= 0 {
    out.push({
      start: self.single_open,
      end: self.single_open + 1,
      kind: SingleQuote,
      opening: true,
    })
  }
  out
}

///|
/// 扫描一行的直引号。
///
/// - `mask[i]` 为 `true` 的位置被跳过（行内代码、URL 等受保护区域）；
/// - `base` 为该行首字符在全文中的偏移，用于换算绝对位置；
/// - `carry` 为进入本行时的引号状态，返回值是离开本行的状态。
fn scan_quotes_in_line(
  chars : Array[Char],
  mask : Array[Bool],
  base : Int,
  carry : QuoteCarry,
) -> (QuoteScan, QuoteCarry) {
  let edits : Array[QuoteEdit] = []
  let unpaired : Array[UnpairedQuote] = []
  let n = chars.length()
  let mut in_double = carry.in_double
  let mut in_single = carry.in_single
  let mut double_open = carry.double_open
  let mut single_open = carry.single_open
  let mut i = 0
  while i < n {
    let c = chars[i]
    let skip = i < mask.length() && mask[i]
    if !skip &&
      is_straight_quote(c) &&
      has_cjk_nearby(chars, i, 8) &&
      !is_apostrophe(chars, i) {
      let is_double = c == '"'
      let inside = if is_double { in_double } else { in_single }
      let opening = classify_quote(chars, i, inside)
      if opening {
        let prev_open = if is_double { double_open } else { single_open }
        if prev_open >= 0 {
          unpaired.push({
            start: prev_open,
            end: prev_open + 1,
            kind: if is_double {
              DoubleQuote
            } else {
              SingleQuote
            },
            opening: true,
          })
        }
        if is_double {
          in_double = true
          double_open = base + i
        } else {
          in_single = true
          single_open = base + i
        }
      } else if inside {
        if is_double {
          in_double = false
          double_open = -1
        } else {
          in_single = false
          single_open = -1
        }
      } else {
        unpaired.push({
          start: base + i,
          end: base + i + 1,
          kind: if is_double {
            DoubleQuote
          } else {
            SingleQuote
          },
          opening: false,
        })
      }
      let repl = if opening {
        if is_double {
          "“"
        } else {
          "‘"
        }
      } else if is_double {
        "”"
      } else {
        "’"
      }
      edits.push({ start: base + i, end: base + i + 1, text: repl, opening, })
    }
    i = i + 1
  }
  unpaired.sort_by(fn(a, b) { a.start - b.start })
  ({ edits, unpaired, }, { in_double, in_single, double_open, single_open, })
}

///|
/// 把中文语境中的直引号转换为弯引号。
///
/// 这是纯文本级 API（不做 Markdown 区域识别）；库内规则使用掩码版本，
/// 会自动跳过行内代码、URL 等区域。
pub fn convert_straight_quotes(text : String) -> String {
  let raws = split_raw_lines(text)
  let buf = StringBuilder()
  let mut carry = QuoteCarry::empty()
  for raw in raws {
    let chars = raw.chars
    let mask = Array::make(chars.length(), false)
    let (scan, next) = scan_quotes_in_line(chars, mask, 0, carry)
    carry = next
    let mut pos = 0
    for e in scan.edits {
      if e.start < pos {
        continue
      }
      while pos < e.start {
        buf.write_char(chars[pos])
        pos = pos + 1
      }
      buf.write_string(e.text)
      pos = e.end
    }
    while pos < chars.length() {
      buf.write_char(chars[pos])
      pos = pos + 1
    }
    buf.write_string(raw.newline)
  }
  buf.to_string()
}

///|
/// 找出文本中未配对的引号（同时覆盖直引号与弯引号场景）。
pub fn find_unpaired_quotes(text : String) -> Array[UnpairedQuote] {
  let raws = split_raw_lines(text)
  let out : Array[UnpairedQuote] = []
  let mut carry = QuoteCarry::empty()
  let mut base = 0
  for raw in raws {
    let chars = raw.chars
    let mask = Array::make(chars.length(), false)
    let (scan, next) = scan_quotes_in_line(chars, mask, base, carry)
    carry = next
    for u in scan.unpaired {
      out.push(u)
    }
    base = base + chars.length() + raw.newline.length()
  }
  for u in carry.dangling() {
    out.push(u)
  }
  out.sort_by(fn(a, b) { a.start - b.start })
  out
}

///|
/// 单引号 / 双引号的显示名，用于诊断与展示。
pub fn QuoteKind::label(self : QuoteKind) -> String {
  match self {
    DoubleQuote => "双引号"
    SingleQuote => "单引号"
  }
}

///|
/// 规则 `curly-quote`：中文语境中的直引号应改为弯引号。
fn check_curly_quote(ctx : Ctx) -> Array[Diagnostic] {
  let out : Array[Diagnostic] = []
  let mut carry = QuoteCarry::empty()
  for line in ctx.lines {
    if line.code {
      continue
    }
    let (scan, next) = scan_quotes_in_line(
      line.chars,
      line.mask,
      line.start,
      carry,
    )
    carry = next
    for e in scan.edits {
      let kind = if e.opening { "开引号" } else { "闭引号" }
      out.push(
        mk_diag(
          "curly-quote",
          Warning,
          "中文语境应使用弯引号（此处为" + kind + "）",
          e.start,
          e.end,
          Some(e.text),
        ),
      )
    }
  }
  out
}

///|
/// 规则 `quote-pairing`：引号必须成对出现。
fn check_quote_pairing(ctx : Ctx) -> Array[Diagnostic] {
  let out : Array[Diagnostic] = []
  let mut carry = QuoteCarry::empty()
  for line in ctx.lines {
    if line.code {
      continue
    }
    let (scan, next) = scan_quotes_in_line(
      line.chars,
      line.mask,
      line.start,
      carry,
    )
    carry = next
    for u in scan.unpaired {
      out.push(unpaired_diag(u))
    }
  }
  for u in carry.dangling() {
    out.push(unpaired_diag(u))
  }
  out
}

///|
/// 把一条未配对引号转换为诊断。
fn unpaired_diag(u : UnpairedQuote) -> Diagnostic {
  let msg = if u.opening {
    u.kind.label() + "缺少配对的闭引号"
  } else {
    u.kind.label() + "缺少配对的开引号"
  }
  mk_diag("quote-pairing", Warning, msg, u.start, u.end, None)
}
