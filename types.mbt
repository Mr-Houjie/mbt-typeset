///|
/// 诊断的严重级别。
pub enum Severity {
  Error
  Warning
  Info
} derive(Eq, Debug)

///|
/// 规则元信息，用于 `--list-rules` 与配置校验。
pub struct RuleInfo {
  /// 规则 id，例如 `cjk-latin-space`
  id : String
  /// 规则说明
  description : String
  severity : Severity
  /// 默认是否启用
  enabled_by_default : Bool
  /// 是否支持 `--fix` 自动修复
  fixable : Bool
} derive(Eq, Debug)

///|
/// 一条排版诊断。
///
/// 位置同时提供两种表达：
/// - `start` / `end`：全文 **字符** 偏移（`end` 为开区间），用于应用修复；
/// - `line` / `column`：1 起始的行列号（按字符计），用于展示。
pub struct Diagnostic {
  /// 触发该诊断的规则 id
  rule : String
  severity : Severity
  /// 人类可读的说明
  message : String
  /// 1 起始行号
  line : Int
  /// 1 起始列号（按字符计）
  column : Int
  /// 全文字符偏移，闭端
  start : Int
  /// 全文字符偏移，开端
  end : Int
  /// 可自动修复时的替换文本；`None` 表示不可自动修复
  replacement : String?
} derive(Eq, Debug)

///|
/// 一次自动修复的结果。
pub struct FixOutcome {
  /// 修复后的文本
  output : String
  /// 实际应用的修复编辑数
  applied : Int
  /// 修复后仍然存在、但无法自动修复的诊断
  remaining : Array[Diagnostic]
} derive(Eq, Debug)
