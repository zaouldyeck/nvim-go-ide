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
      luasnip.config.setup({ history = true, updateevents = "TextChanged,TextChangedI" })
      require("custom.snippets").setup()
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        completion = { completeopt = "menu,menuone,noinsert" },
        preselect = cmp.PreselectMode.None,
        window = {
          completion = cmp.config.window.bordered({
            winhighlight = 'Normal:CmpPmenu,FloatBorder:CmpBorder,CursorLine:CmpSel,Search:None',
            scrollbar = true,
          }),
          documentation = cmp.config.window.bordered({
            winhighlight = 'Normal:CmpPmenu,FloatBorder:CmpBorder,Search:None',
          }),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
          -- Dedicated snippet keys also work while completion is visible.
          -- close() preserves typed text; abort() would restore the old line.
          ["<C-l>"] = cmp.mapping(function(fallback)
            if luasnip.expand_or_locally_jumpable() then
              cmp.close()
              luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<C-h>"] = cmp.mapping(function(fallback)
            if luasnip.locally_jumpable(-1) then
              cmp.close()
              luasnip.jump(-1)
            else fallback() end
          end, { "i", "s" }),
          ["<M-n>"] = cmp.mapping(function(fallback)
            if luasnip.in_snippet() and luasnip.choice_active() then
              cmp.close()
              luasnip.change_choice(1)
            else fallback() end
          end, { "i", "s" }),
          ["<M-p>"] = cmp.mapping(function(fallback)
            if luasnip.in_snippet() and luasnip.choice_active() then
              cmp.close()
              luasnip.change_choice(-1)
            else fallback() end
          end, { "i", "s" }),
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
            local icons = {
              Text = '󰉿', Method = '󰆧', Function = '󰊕', Constructor = '',
              Field = '󰜢', Variable = '󰀫', Class = '󰠱', Interface = '',
              Module = '', Property = '󰜢', Unit = '󰑭', Value = '󰎠',
              Enum = '', Keyword = '󰌋', Snippet = '', Color = '󰏘',
              File = '󰈙', Reference = '󰈇', Folder = '󰉋', EnumMember = '',
              Constant = '󰏿', Struct = '󰙅', Event = '', Operator = '󰆕',
              TypeParameter = '󰅲',
            }
            if #item.abbr > 48 then item.abbr = item.abbr:sub(1, 45) .. "…" end
            item.kind = (icons[item.kind] or '·') .. ' ' .. item.kind
            item.menu = ({ nvim_lsp = ' Go', luasnip = ' Snippet', path = ' Path', buffer = ' Buffer' })[entry.source.name]
            return item
          end,
        },
      })
      require("go_ide.lsp").setup()
    end,
  },
  {
    "mfussenegger/nvim-dap",
    lazy = true,
    dependencies = {
      "leoluz/nvim-dap-go",
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
    config = function() require("go_ide.debug").setup() end,
  },
}
