return {
  {
    "hrsh7th/nvim-cmp",
    lazy = false,
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp, luasnip = require("cmp"), require("luasnip")
      local s, t, i = luasnip.snippet, luasnip.text_node, luasnip.insert_node
      local fmt = require("luasnip.extras.fmt").fmt
      luasnip.config.setup({ history = true, updateevents = "TextChanged,TextChangedI" })
      luasnip.add_snippets("go", {
        s("iferr", fmt("if err != nil {{\n\t{}\n}}", { i(1, "return err") })),
        s("func", fmt("func {}({}) {} {{\n\t{}\n}}", { i(1, "name"), i(2), i(3), i(0) })),
        s("meth", fmt("func ({} *{}) {}({}) {} {{\n\t{}\n}}", { i(1, "s"), i(2, "Server"), i(3, "Method"), i(4), i(5), i(0) })),
        s("test", fmt("func Test{}(t *testing.T) {{\n\t{}\n}}", { i(1, "Name"), i(0) })),
        s("main", fmt("func main() {{\n\t{}\n}}", { i(0) })),
        s("forr", fmt("for {}, {} := range {} {{\n\t{}\n}}", { i(1, "i"), i(2, "v"), i(3, "items"), i(0) })),
        s("struct", fmt("type {} struct {{\n\t{}\n}}", { i(1, "Name"), i(0) })),
        s("iface", fmt("type {} interface {{\n\t{}\n}}", { i(1, "Name"), i(0) })),
        s("switch", fmt("switch {} {{\ncase {}:\n\t{}\ndefault:\n\t{}\n}}", { i(1), i(2), i(3), i(0) })),
        s("errf", { t('fmt.Errorf("'), i(1, "operation"), t(': %w", '), i(2, "err"), t(")"), i(0) }),
      })
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        completion = { completeopt = "menu,menuone,noinsert" },
        preselect = cmp.PreselectMode.None,
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then luasnip.jump(-1)
            else fallback() end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" }, { name = "luasnip" }, { name = "path" },
        }, { { name = "buffer", keyword_length = 3, max_item_count = 5 } }),
        formatting = {
          fields = { "abbr", "kind", "menu" },
          format = function(entry, item)
            if #item.abbr > 55 then item.abbr = item.abbr:sub(1, 52) .. "…" end
            item.menu = ({ nvim_lsp = "Go", luasnip = "Snippet", path = "Path", buffer = "Buffer" })[entry.source.name]
            return item
          end,
        },
      })
      require("go_ide.lsp").setup()
    end,
  },
  {
    "mfussenegger/nvim-dap",
    lazy = false,
    dependencies = {
      "leoluz/nvim-dap-go",
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
    config = function() require("go_ide.debug").setup() end,
  },
}
