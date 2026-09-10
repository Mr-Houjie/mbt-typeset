// 自检程序：运行库内置的排版一致性语料，输出报告并以退出码反映结果。
//
// 用途：
// - 在没有 `moon test` 的环境（或 CI 之外）快速回归全部规则；
// - 演示「可运行、可复现」的验收方式。
//
// 运行：moon run cmd/verify

///|
fn main {
  let cases = @lib.conformance_cases()
  let failures = @lib.run_conformance()
  println(
    "mbt-typeset 自检：共 \{cases.length()} 条用例，失败 \{failures.length()} 条",
  )
  for f in failures {
    println("  FAIL \{f}")
  }
  if failures.length() > 0 {
    @sys.exit(1)
  } else {
    println("全部通过")
    @sys.exit(0)
  }
}
