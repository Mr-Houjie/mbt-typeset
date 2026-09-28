// 黑盒测试：只通过公开 API 使用本库（与 mbt-email 的测试组织方式保持一致）。
//
// 覆盖两部分：
// 1. 一致性语料（见 `conformance.mbt`）—— 全部排版规则的单一事实来源；
// 2. 公开 API 细节 —— 位置计算、保护掩码、渲染输出、规则表、配置。

///|
/// 对 `source` 执行修复，断言结果等于 `expected`，并顺带验证幂等性。
fn assert_fix(
  source : String,
  expected : String,
  config : @Mr-Houjie/mbt-typeset.Config,
) -> Unit raise {
  let outcome = @Mr-Houjie/mbt-typeset.fix(source, config)
  assert_eq(outcome.output, expected)
  let again = @Mr-Houjie/mbt-typeset.fix(outcome.output, config)
  assert_eq(again.applied, 0)
  assert_eq(again.output, outcome.output)
}

///|
/// 断言语料全部通过，并把失败信息打印出来便于定位。
fn assert_conformance() -> Unit raise {
  let failures = @Mr-Houjie/mbt-typeset.run_conformance()
  for f in failures {
    println("FAIL \{f}")
  }
  assert_eq(failures.length(), 0)
}

///|
test "conformance: 全部内置用例通过" {
  assert_conformance()
}

// ---------------------------------------------------------------------------
// 位置计算
// ---------------------------------------------------------------------------

///|
test "locate: 行列号按字符计" {
  let diags = @Mr-Houjie/mbt-typeset.lint(
    "使用MoonBit",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  assert_eq(diags.length(), 1)
  assert_eq(diags[0].line, 1)
  assert_eq(diags[0].column, 3)
}

///|
test "locate: 多行时行号正确" {
  let diags = @Mr-Houjie/mbt-typeset.lint(
    "第一行\n使用MoonBit",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  assert_eq(diags.length(), 1)
  assert_eq(diags[0].line, 2)
  assert_eq(diags[0].column, 3)
}

///|
test "locate: 诊断按位置排序" {
  let diags = @Mr-Houjie/mbt-typeset.lint(
    "使用MoonBit,并且使用github",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  assert_true(diags.length() >= 3)
  for i = 1; i < diags.length(); i = i + 1 {
    assert_true(diags[i - 1].start <= diags[i].start)
  }
}

// ---------------------------------------------------------------------------
// 保护掩码
// ---------------------------------------------------------------------------

///|
test "mask: 双反引号代码片段整体受保护" {
  let src = "使用``a`b``开发"
  let diags = @Mr-Houjie/mbt-typeset.lint(
    src,
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  // 只应有「使用|``」与「``|开发」两处间距问题，代码片段内部不受影响
  for d in diags {
    assert_true(d.rule == "cjk-latin-space")
  }
  let outcome = @Mr-Houjie/mbt-typeset.fix(
    src,
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  assert_true(outcome.output.contains("``a`b``"))
}

///|
test "mask: 未闭合反引号不吞掉整行" {
  let outcome = @Mr-Houjie/mbt-typeset.fix(
    "使用`code 与MoonBit",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  assert_true(outcome.output.contains("与 MoonBit"))
}

///|
test "mask: 邮箱地址不受影响" {
  let outcome = @Mr-Houjie/mbt-typeset.fix(
    "联系 someone@example.com 谢谢",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  assert_eq(outcome.output, "联系 someone@example.com 谢谢")
}

// ---------------------------------------------------------------------------
// 渲染
// ---------------------------------------------------------------------------

///|
test "render_text: 含文件、位置、规则" {
  let diags = @Mr-Houjie/mbt-typeset.lint(
    "使用MoonBit",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  let text = @Mr-Houjie/mbt-typeset.render_text(diags, "a.md")
  assert_true(text.contains("a.md:1:3"))
  assert_true(text.contains("warning [cjk-latin-space]"))
  assert_true(text.contains("可自动修复"))
}

///|
test "render_text: 文件名为空时省略前缀" {
  let diags = @Mr-Houjie/mbt-typeset.lint(
    "使用MoonBit",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  assert_true(@Mr-Houjie/mbt-typeset.render_text(diags, "").has_prefix("1:3: "))
}

///|
test "render_json: 字段完整" {
  let diags = @Mr-Houjie/mbt-typeset.lint(
    "使用MoonBit",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  let text = @Mr-Houjie/mbt-typeset.render_json(diags, "a.md")
  assert_true(text.contains("\"rule\""))
  assert_true(text.contains("\"severity\""))
  assert_true(text.contains("\"line\""))
  assert_true(text.contains("\"column\""))
  assert_true(text.contains("\"fixable\""))
  assert_true(text.contains("\"count\""))
  assert_true(text.contains("\"a.md\""))
}

///|
test "render_github: 注解格式" {
  let diags = @Mr-Houjie/mbt-typeset.lint(
    "使用MoonBit",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  let text = @Mr-Houjie/mbt-typeset.render_github(diags, "a.md")
  assert_true(
    text.has_prefix("::warning file=a.md,line=1,col=3,title=cjk-latin-space::"),
  )
}

///|
test "render_rule_list: 列出全部规则" {
  let text = @Mr-Houjie/mbt-typeset.render_rule_list()
  assert_true(text.contains("cjk-latin-space"))
  assert_true(text.contains("unclosed-code-fence"))
}

// ---------------------------------------------------------------------------
// 严重级别与规则表
// ---------------------------------------------------------------------------

///|
test "has_problems: info 不算问题" {
  let diags = @Mr-Houjie/mbt-typeset.lint(
    "文件 100KB",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  assert_eq(diags.length(), 1)
  assert_eq(diags[0].severity.label(), "info")
  assert_false(@Mr-Houjie/mbt-typeset.has_problems(diags))
}

///|
test "has_problems: warning 算问题" {
  let diags = @Mr-Houjie/mbt-typeset.lint(
    "使用MoonBit",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  assert_eq(diags[0].severity.label(), "warning")
  assert_true(@Mr-Houjie/mbt-typeset.has_problems(diags))
}

///|
test "rule_infos: id 唯一且可查询" {
  let infos = @Mr-Houjie/mbt-typeset.rule_infos()
  assert_true(infos.length() >= 16)
  let seen : Map[String, Bool] = Map([])
  for info in infos {
    assert_false(seen.contains(info.id))
    seen.set(info.id, true)
  }
  assert_true(@Mr-Houjie/mbt-typeset.is_known_rule("cjk-latin-space"))
  assert_false(@Mr-Houjie/mbt-typeset.is_known_rule("not-a-rule"))
}

///|
test "severity: label 输出稳定" {
  let info_diags = @Mr-Houjie/mbt-typeset.lint(
    "文件 100KB",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  assert_eq(info_diags[0].severity.label(), "info")
  let warn_diags = @Mr-Houjie/mbt-typeset.lint(
    "使用MoonBit",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  assert_eq(warn_diags[0].severity.label(), "warning")
  let err_diags = @Mr-Houjie/mbt-typeset.lint(
    "```\nabc\n",
    @Mr-Houjie/mbt-typeset.Config::markdown(),
  )
  assert_eq(err_diags[0].severity.label(), "error")
}

// ---------------------------------------------------------------------------
// 语料不好表达的规则
// ---------------------------------------------------------------------------

///|
test "terminology: 支持自定义术语（含中文）" {
  let config = @Mr-Houjie/mbt-typeset.Config::new().with_terminology(
    "阿发", "Alpha",
  )
  assert_fix("这是 阿发 项目", "这是 Alpha 项目", config)
}

///|
test "line-length: 需要显式开启并设置上限" {
  let off = @Mr-Houjie/mbt-typeset.Config::new().with_max_line_length(5)
  assert_eq(@Mr-Houjie/mbt-typeset.lint("abcdefgh", off).length(), 0)
  let on = @Mr-Houjie/mbt-typeset.Config::new()
    .with_max_line_length(5)
    .with_rule("line-length", true)
  let diags = @Mr-Houjie/mbt-typeset.lint("abcdefgh", on)
  assert_eq(diags.length(), 1)
  assert_eq(diags[0].rule, "line-length")
  assert_eq(diags[0].column, 6)
  assert_true(diags[0].replacement is None)
}

///|
test "unclosed-code-fence: 报 error 且不可修复" {
  let diags = @Mr-Houjie/mbt-typeset.lint(
    "```\nabc\n",
    @Mr-Houjie/mbt-typeset.Config::markdown(),
  )
  assert_eq(diags.length(), 1)
  assert_eq(diags[0].rule, "unclosed-code-fence")
  assert_eq(diags[0].severity.label(), "error")
  assert_eq(diags[0].line, 1)
  assert_true(diags[0].replacement is None)
  let outcome = @Mr-Houjie/mbt-typeset.fix(
    "```\nabc\n",
    @Mr-Houjie/mbt-typeset.Config::markdown(),
  )
  assert_eq(outcome.applied, 0)
  assert_eq(outcome.remaining.length(), 1)
}

///|
test "config: 未显式配置时回落到默认值" {
  let config = @Mr-Houjie/mbt-typeset.Config::new()
  assert_true(config.is_enabled("cjk-latin-space", true))
  assert_false(config.is_enabled("cjk-latin-space", false))
  assert_false(config.is_enabled("halfwidth-punct-in-latin", false))
  assert_true(config.is_enabled("halfwidth-punct-in-latin", true))
}

///|
test "config: Markdown 模式默认值" {
  assert_false(@Mr-Houjie/mbt-typeset.Config::new().markdown)
  assert_true(@Mr-Houjie/mbt-typeset.Config::markdown().markdown)
  let config = @Mr-Houjie/mbt-typeset.Config::new()
  config.set_markdown(true)
  assert_true(config.markdown)
}

///|
test "quotes: 中文语境直引号转弯引号" {
  assert_eq(
    @Mr-Houjie/mbt-typeset.convert_straight_quotes("他说\"你好\""),
    "他说“你好”",
  )
  assert_eq(
    @Mr-Houjie/mbt-typeset.convert_straight_quotes("中文'引号'"),
    "中文‘引号’",
  )
}

///|
test "quotes: 撇号与纯英文段落不受影响" {
  assert_eq(
    @Mr-Houjie/mbt-typeset.convert_straight_quotes("don't 不变"),
    "don't 不变",
  )
  assert_eq(
    @Mr-Houjie/mbt-typeset.convert_straight_quotes("the \"best\" practice"),
    "the \"best\" practice",
  )
}

///|
test "quotes: 嵌套引号方向正确" {
  assert_eq(
    @Mr-Houjie/mbt-typeset.convert_straight_quotes("他说\"她喊'喂'\""),
    "他说“她喊‘喂’”",
  )
}

///|
test "quotes: 跨行引号可正确配对" {
  assert_eq(
    @Mr-Houjie/mbt-typeset.convert_straight_quotes("\"跨行\n引号\""),
    "“跨行\n引号”",
  )
}

///|
test "quotes: 已是弯引号时保持原样" {
  let text = "他说“你好”"
  assert_eq(@Mr-Houjie/mbt-typeset.convert_straight_quotes(text), text)
}

///|
test "quotes: 未配对引号可被检出" {
  let unpaired = @Mr-Houjie/mbt-typeset.find_unpaired_quotes(
    "这里有\"未闭合",
  )
  assert_eq(unpaired.length(), 1)
  assert_true(unpaired[0].opening)
  assert_eq(unpaired[0].kind.label(), "双引号")
  assert_eq(unpaired[0].start, 3)
  let balanced = @Mr-Houjie/mbt-typeset.find_unpaired_quotes("他说\"你好\"")
  assert_eq(balanced.length(), 0)
}

///|
test "quotes: 行内代码中的引号受保护" {
  let text = "执行 `echo \"hi\"` 命令"
  let config = @Mr-Houjie/mbt-typeset.Config::markdown()
  let diags = @Mr-Houjie/mbt-typeset.lint(text, config)
  for d in diags {
    assert_true(d.rule != "curly-quote")
  }
  assert_eq(@Mr-Houjie/mbt-typeset.fix(text, config).output, text)
}

///|
test "quotes: quote-pairing 报告但不可自动修复" {
  let diags = @Mr-Houjie/mbt-typeset.lint(
    "这里有\"未闭合",
    @Mr-Houjie/mbt-typeset.Config::new(),
  )
  let mut found = false
  for d in diags {
    if d.rule == "quote-pairing" {
      found = true
      assert_true(d.replacement is None)
    }
  }
  assert_true(found)
}

///|
test "quotes: 规则元信息已注册" {
  let mut curly = false
  let mut pairing = false
  for info in @Mr-Houjie/mbt-typeset.rule_infos() {
    if info.id == "curly-quote" {
      curly = true
      assert_true(info.fixable)
      assert_true(info.enabled_by_default)
    }
    if info.id == "quote-pairing" {
      pairing = true
      assert_false(info.fixable)
    }
  }
  assert_true(curly)
  assert_true(pairing)
}
