vim.keymap.set("n", "<leader>ls", "<cmd>source ~/.config/nvim/lua/config/luasnip.lua<CR>")

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
	parse("if err", "if err != nil {\n\t$1\n}")
})

ls.add_snippets("html", {
	parse("class=", "class=\"$1\"")
})

ls.add_snippets("javascript", {
	s("consolelog", fmt("console.log({})", { i(1, 'x') }))
})

ls.add_snippets("typescript", {
	s("consolelog", fmt("console.log({})", { i(1, 'x') }))
})

ls.add_snippets("lua", {
	s("local require", fmt("local {} = require\"{}\"", { i(1, "default"), rep(1) }))
})

ls.add_snippets("java", {
	s("log", fmt("logger.{}({})", { i(2, "info"), i(1, "content") } )),
	s("ifequals", fmt("if ({}.equals({}) {{\n\t{}\n}}", {
		i(1, "first"), i(2, "second"), i(0)}
	)),
})

vim.keymap.set({ "i", "s" }, "<c-y>", function()
	if require "luasnip".expand_or_jumpable() then
		require "luasnip".expand_or_jump()
	end
end)
