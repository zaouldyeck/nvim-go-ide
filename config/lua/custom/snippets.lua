-- Personal Go snippets. Edit this file, then run :GoSnippetsReload.
local M = {}

function M.setup()
  local ls = require("luasnip")
  local s, i, t = ls.snippet, ls.insert_node, ls.text_node
  local c, sn = ls.choice_node, ls.snippet_node
  local fmt = require("luasnip.extras.fmt").fmt

  -- Each choice owns its leading space so "no returns" also formats cleanly.
  -- Nested indices restart at 1; the outer index belongs to the parent snippet.
  local function returns_choice(index)
    return c(index, {
      sn(nil, { t(" ("), i(1, "T1"), t(", "), i(2, "error"), t(")") }),
      sn(nil, { t(" "), i(1, "error") }),
      t(""),
    })
  end

  local function struct_snippet(trigger)
    return s({ trig = trigger, name = "Go struct", dscr = "Struct with a first field" },
      fmt("type {} struct {{\n\t{} {}\n\t{}\n}}", {
        i(1, "MyStruct"), i(2, "FieldName"), i(3, "string"), i(0),
      }))
  end

  local function main_snippet(trigger)
    return s({ trig = trigger, name = "main (bare)", dscr = "Go main function (barebones)" },
      fmt("func main() {{\n\t{}\n}}", { i(0) }))
  end

  ls.add_snippets("go", {
    s("iferr", fmt("if err != nil {{\n\t{}\n}}", { i(1, "return err") })),
    s({ trig = "func", dscr = "Function with multiple, single, or no return types" },
      fmt("func {}({}){} {{\n\t{}\n}}", {
        i(1, "FunctionName"), i(2), returns_choice(3), i(0),
      })),
    s({ trig = "meth", dscr = "Method with an editable receiver and return types" },
      fmt("func ({} {}) {}({}){} {{\n\t{}\n}}", {
        i(1, "m"), i(2, "MyStruct"), i(3, "MethodName"), i(4), returns_choice(5), i(0),
      })),
    s("test", fmt("func Test{}(t *testing.T) {{\n\t{}\n}}", { i(1, "Name"), i(0) })),
    main_snippet("main"),
    main_snippet("fmain"),
    s("forr", fmt("for {}, {} := range {} {{\n\t{}\n}}", { i(1, "i"), i(2, "v"), i(3, "items"), i(0) })),
    struct_snippet("struct"),
    struct_snippet("tys"),
    s("iface", fmt("type {} interface {{\n\t{}\n}}", { i(1, "Name"), i(0) })),
    s("switch", fmt("switch {} {{\ncase {}:\n\t{}\ndefault:\n\t{}\n}}", { i(1), i(2), i(3), i(0) })),
    s("errf", { t('fmt.Errorf("'), i(1, "operation"), t(': %w", '), i(2, "err"), t(")"), i(0) }),
  }, { key = "nvim-go-custom-go" })

  vim.api.nvim_create_user_command("GoSnippetsReload", function()
    package.loaded["custom.snippets"] = nil
    require("custom.snippets").setup()
  end, { desc = "Reload personal Go snippets", force = true })
end

return M
