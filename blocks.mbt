///|
/// 块级元素类型。
pub enum BlockKind {
  Heading
  ListItem
  BlockQuote
  TableRow
  TableSeparator
  FencedCode
  IndentedCode
  ThematicBreak
  Blank
  Paragraph
} derive(Eq, Debug)

///|
/// 列表标记。
pub enum ListMarker {
  /// 无序标记：`-` `*` `+`
  Bullet(Char)
  /// 有序标记：`.` 或 `)`
  Ordered(Char)
} derive(Eq, Debug)

///|
/// 一个块级元素（以行为单位）。
pub struct Block {
  kind : BlockKind
  /// 该行首字符在全文中的字符偏移
  start : Int
  /// 该行尾字符在全文中的字符偏移（开端，不含换行）
  end : Int
  /// 1 起始行号
  line : Int
  /// 缩进宽度（tab 记为 4）
  indent : Int
  /// 标题层级（1-6）；非标题为 0
  level : Int
  /// 列表标记；非列表为 `None`
  marker : ListMarker?
  /// 表格列数；非表格行为 0
  columns : Int
} derive(Eq, Debug)

///|
/// 计算行首缩进宽度，`tab` 记为 4 列。
pub fn indent_width(chars : Array[Char]) -> Int {
  let mut width = 0
  let mut i = 0
  while i < chars.length() {
    match chars[i] {
      ' ' => width = width + 1
      '\t' => width = width + 4
      _ => break
    }
    i = i + 1
  }
  width
}

///|
/// 是否为空白行（只含空格与制表符）。
pub fn is_blank_line(chars : Array[Char]) -> Bool {
  let mut i = 0
  while i < chars.length() {
    if !is_space_char(chars[i]) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// 是否为缩进代码块行（缩进 >= 4 且行内有内容）。
///
/// Markdown 中缩进 4 空格（或 1 个制表符）的连续行构成代码块，
/// 其中的内容不应参与排版检查。
pub fn is_indented_code_line(chars : Array[Char]) -> Bool {
  if is_blank_line(chars) {
    return false
  }
  indent_width(chars) >= 4
}

///|
/// 判断一行是否以指定字符开头（忽略行首缩进）。
fn starts_with_char(chars : Array[Char], c : Char) -> Bool {
  let i = first_non_space(chars)
  i < chars.length() && chars[i] == c
}

///|
/// 标题层级：`#` 开头返回 1-6，否则 0。
pub fn heading_level_of(chars : Array[Char]) -> Int {
  let mut i = first_non_space(chars)
  if i >= chars.length() || chars[i] != '#' {
    return 0
  }
  let mut level = 0
  while i < chars.length() && chars[i] == '#' && level < 7 {
    level = level + 1
    i = i + 1
  }
  if level > 6 {
    return 0
  }
  if i < chars.length() && !is_space_char(chars[i]) {
    return 0
  }
  level
}

///|
/// 列表标记：返回标记种类，非列表行为 `None`。
pub fn list_marker_of(chars : Array[Char]) -> ListMarker? {
  let i = first_non_space(chars)
  if i >= chars.length() {
    return None
  }
  let c = chars[i]
  if c == '-' || c == '*' || c == '+' {
    if i + 1 < chars.length() && is_space_char(chars[i + 1]) {
      return Some(Bullet(c))
    }
    return None
  }
  let mut k = i
  while k < chars.length() && chars[k].is_ascii_digit() {
    k = k + 1
  }
  if k > i && k < chars.length() && (chars[k] == '.' || chars[k] == ')') {
    if k + 1 < chars.length() && is_space_char(chars[k + 1]) {
      return Some(Ordered(chars[k]))
    }
  }
  None
}

///|
/// 是否为分割线（`---` / `***` / `___`，至少 3 个）。
pub fn is_thematic_break(chars : Array[Char]) -> Bool {
  let i = first_non_space(chars)
  if i >= chars.length() {
    return false
  }
  let c = chars[i]
  if c != '-' && c != '*' && c != '_' {
    return false
  }
  let mut count = 0
  let mut k = i
  while k < chars.length() {
    let ch = chars[k]
    if ch == c {
      count = count + 1
    } else if !is_space_char(ch) {
      return false
    }
    k = k + 1
  }
  count >= 3
}

///|
/// 统计表格列数；非表格行返回 0。
///
/// 以不在受保护区域内的 `|` 作为分隔符统计，首尾的 `|` 不计入列数。
pub fn table_column_count(chars : Array[Char]) -> Int {
  let start = first_non_space(chars)
  let mut end = chars.length()
  while end > start && is_space_char(chars[end - 1]) {
    end = end - 1
  }
  if end <= start {
    return 0
  }
  let mut pipes = 0
  let mut i = start
  while i < end {
    if chars[i] == '|' {
      pipes = pipes + 1
    }
    i = i + 1
  }
  if pipes == 0 {
    return 0
  }
  if chars[start] == '|' && chars[end - 1] == '|' {
    pipes - 1
  } else if chars[start] == '|' || chars[end - 1] == '|' {
    pipes
  } else {
    pipes + 1
  }
}

///|
/// 是否为 Markdown 表格的分隔行（`|---|---|`、`| :--- | ---: |` 等）。
pub fn is_table_separator(chars : Array[Char]) -> Bool {
  if table_column_count(chars) == 0 {
    return false
  }
  let mut has_dash = false
  let mut i = first_non_space(chars)
  while i < chars.length() {
    match chars[i] {
      '-' => has_dash = true
      '|' | ':' | ' ' | '\t' => ()
      _ => return false
    }
    i = i + 1
  }
  has_dash
}

///|
/// 统计一行中表格单元格的文本内容（去掉首尾空白）；非表格行返回空数组。
pub fn table_cells(chars : Array[Char]) -> Array[String] {
  let out : Array[String] = []
  if table_column_count(chars) == 0 {
    return out
  }
  let buf = StringBuilder()
  let mut i = first_non_space(chars)
  let n = chars.length()
  while i < n {
    let c = chars[i]
    if c == '|' {
      out.push(trim_string(buf.to_string()))
      buf.reset()
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  let tail = trim_string(buf.to_string())
  if tail != "" {
    out.push(tail)
  }
  out
}

///|
/// 去掉字符串首尾空白。
fn trim_string(s : String) -> String {
  let chars = s.iter().to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && is_space_char(chars[start]) {
    start = start + 1
  }
  while end > start && is_space_char(chars[end - 1]) {
    end = end - 1
  }
  chars_to_string(chars, start, end)
}

///|
/// 对单行做块级分类。
fn classify_line(line : SLine) -> BlockKind {
  if line.code {
    if is_indented_code_line(line.chars) {
      IndentedCode
    } else {
      FencedCode
    }
  } else if is_blank_line(line.chars) {
    Blank
  } else if heading_level_of(line.chars) > 0 {
    Heading
  } else if is_thematic_break(line.chars) {
    ThematicBreak
  } else if is_table_separator(line.chars) {
    TableSeparator
  } else if table_column_count(line.chars) > 0 {
    TableRow
  } else if list_marker_of(line.chars) is Some(_) {
    ListItem
  } else if starts_with_char(line.chars, '>') {
    BlockQuote
  } else {
    Paragraph
  }
}

///|
/// 为整个文档构建块序列（每行一个块）。
fn build_blocks(ctx : Ctx) -> Array[Block] {
  let out : Array[Block] = []
  let mut no = 0
  for line in ctx.lines {
    no = no + 1
    let kind = classify_line(line)
    let marker = list_marker_of(line.chars)
    let level = heading_level_of(line.chars)
    let columns = if kind == TableRow || kind == TableSeparator {
      table_column_count(line.chars)
    } else {
      0
    }
    out.push({
      kind,
      start: line.start,
      end: line.start + line.chars.length(),
      line: no,
      indent: indent_width(line.chars),
      level,
      marker,
      columns,
    })
  }
  out
}

///|
/// 分析文本的块级结构（每行一个块）。
///
/// 库级入口，供外部工具直接获取块结构；内部规则复用同一实现。
pub fn analyze_blocks(source : String, markdown : Bool) -> Array[Block] {
  let scan = scan_source(source, markdown)
  let ctx = Ctx::{
    lines: scan.lines,
    config: Config::new(),
    unclosed_fence: scan.unclosed_fence,
  }
  build_blocks(ctx)
}

///|
/// 块级元素类型的显示名。
pub fn BlockKind::label(self : BlockKind) -> String {
  match self {
    Heading => "标题"
    ListItem => "列表项"
    BlockQuote => "引用块"
    TableRow => "表格行"
    TableSeparator => "表格分隔行"
    FencedCode => "围栏代码块"
    IndentedCode => "缩进代码块"
    ThematicBreak => "分割线"
    Blank => "空行"
    Paragraph => "段落"
  }
}
