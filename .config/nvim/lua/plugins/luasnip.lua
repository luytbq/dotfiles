
return {
  "L3MON4D3/LuaSnip",
  opts = function()
    ---@diagnostic disable-next-line: duplicate-set-field
    LazyVim.cmp.actions.snippet_forward = function()
      if require("luasnip").jumpable(1) then
        vim.schedule(function()
          require("luasnip").jump(1)
        end)
        return true
      end
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    LazyVim.cmp.actions.snippet_stop = function()
      if require("luasnip").expand_or_jumpable() then -- or just jumpable(1) is fine?
        require("luasnip").unlink_current()
        return true
      end
    end
  end,
  config = function(opts)
    local ls = require("luasnip")
    local s = ls.snippet
    local sn = ls.snippet_node
    local isn = ls.indent_snippet_node
    local t = ls.text_node
    local i = ls.insert_node
    local f = ls.function_node
    local c = ls.choice_node
    local d = ls.dynamic_node
    local r = ls.restore_node
    local events = require("luasnip.util.events")
    local ai = require("luasnip.nodes.absolute_indexer")
    local extras = require("luasnip.extras")
    local l = extras.lambda
    local rep = extras.rep
    local p = extras.partial
    local m = extras.match
    local n = extras.nonempty
    local dl = extras.dynamic_lambda
    local fmt = require("luasnip.extras.fmt").fmt
    local fmta = require("luasnip.extras.fmt").fmta
    local conds = require("luasnip.extras.expand_conditions")
    local postfix = require("luasnip.extras.postfix").postfix
    local types = require("luasnip.util.types")
    local parse = require("luasnip.util.parser").parse_snippet
    local ms = ls.multi_snippet
    local k = require("luasnip.nodes.key_indexer").new_key

    ls.add_snippets("go", {
      s("iferr", {
        t("if err!= nil {"),
        t({"", "\t"}),
        i(0),
        t({"", ""}),
        t("}"),
      })
    })
  end,
}
