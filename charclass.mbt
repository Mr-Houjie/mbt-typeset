///|
/// 判断是否为 CJK 文字（汉字 / 假名 / 谚文）。
///
/// 注意：这里刻意 **不** 包含 CJK 标点与全角符号，
/// 标点需要单独判断（见 `is_cjk_punct`），否则「中文，英文」之间的逗号会被误判为文字。
pub fn is_cjk_ideograph(c : Char) -> Bool {
  let n = c.to_int()
  (n >= 0x4E00 && n <= 0x9FFF) || // CJK 统一表意文字
  (n >= 0x3400 && n <= 0x4DBF) || // 扩展 A
  (n >= 0xF900 && n <= 0xFAFF) || // 兼容表意文字
  (n >= 0x3040 && n <= 0x30FF) || // 平假名 / 片假名
  (n >= 0xAC00 && n <= 0xD7A3) || // 谚文音节
  (n >= 0x20000 && n <= 0x3FFFF) // 扩展 B 及以后
}

///|
/// 判断是否为 CJK 标点（、。，；：？！「」『』【】《》（）— … · 等）。
pub fn is_cjk_punct(c : Char) -> Bool {
  let n = c.to_int()
  (n >= 0x3000 && n <= 0x303F) || // CJK 符号和标点
  (n >= 0xFE30 && n <= 0xFE4F) || // CJK 兼容形式
  (n >= 0xFF01 && n <= 0xFF0F) || // ！＂＃＄％＆＇（）＊＋，－．／
  (n >= 0xFF1A && n <= 0xFF20) || // ：；＜＝＞？＠
  (n >= 0xFF3B && n <= 0xFF40) || // ［＼］＾＿｀
  (n >= 0xFF5B && n <= 0xFF65) || // ｛｜｝～ 等
  n == 0x2018 ||
  n == 0x2019 ||
  n == 0x201C ||
  n == 0x201D || // 弯引号
  n == 0x2014 ||
  n == 0x2013 || // 破折号 / 连接号
  n == 0x2026 || // 省略号
  n == 0x00B7 // 间隔号
}

///|
/// 判断是否为全角标点（中文语境中使用的标点）。
pub fn is_fullwidth_punct(c : Char) -> Bool {
  let n = c.to_int()
  (n >= 0xFF01 && n <= 0xFF0F) ||
  (n >= 0xFF1A && n <= 0xFF20) ||
  (n >= 0xFF3B && n <= 0xFF40) ||
  (n >= 0xFF5B && n <= 0xFF65) ||
  n == 0x3001 ||
  n == 0x3002 ||
  n == 0x2018 ||
  n == 0x2019 ||
  n == 0x201C ||
  n == 0x201D ||
  n == 0x2014 ||
  n == 0x2026
}

///|
/// 判断是否为全角 ASCII 变体（Ａ-Ｚ ａ-ｚ ０-９ 等，U+FF01..U+FF5E）。
pub fn is_fullwidth_form(c : Char) -> Bool {
  let n = c.to_int()
  n >= 0xFF01 && n <= 0xFF5E
}

///|
/// 判断是否为 ASCII 字母或数字。
pub fn is_ascii_alnum(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c.is_ascii_digit()
}

///|
/// 判断是否为 ASCII 标点。
pub fn is_ascii_punct(c : Char) -> Bool {
  c.is_ascii_punctuation()
}
