--- Проверки шапки документа.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.front')

--- Шапка и страница из разметки.
---@param source string
---@return table meta, string page
local function split(source)
    local page, meta = helper.markdown.render(source)

    return meta, page
end

g.test_the_head_holds_pairs_and_stays_out_of_the_page = function()
    local meta, page = split('---\ntitle: Установка\nweight: 10\n---\n# Установка')

    t.assert_equals(meta, { title = 'Установка', weight = '10' })
    t.assert_equals(page, '<h1>Установка</h1>')
end

g.test_a_value_stays_a_string = function()
    -- Что значит «10» для страницы, знает приложение, а не разбор.
    local meta = split('---\nweight: 10\ndraft: true\n---\n')

    t.assert_equals(meta, { weight = '10', draft = 'true' })
end

g.test_paired_quotes_come_off_a_value = function()
    local meta = split('---\na: "раз: два"\nb: \'три\'\nc: "без пары\n---\n')

    t.assert_equals(meta, { a = 'раз: два', b = 'три', c = '"без пары' })
end

g.test_a_pair_needs_no_space_after_the_colon = function()
    t.assert_equals(split('---\na:1\nb:\n---\n'), { a = '1', b = '' })
end

g.test_a_blank_line_inside_the_head_is_legal = function()
    t.assert_equals(split('---\na: 1\n\nb: 2\n---\n'), { a = '1', b = '2' })
end

g.test_an_empty_head_gives_an_empty_meta = function()
    local meta, page = split('---\n---\nтекст')

    t.assert_equals(meta, {})
    t.assert_equals(page, '<p>текст</p>')
end

g.test_a_document_without_a_head_keeps_its_first_line = function()
    local meta, page = split('---\n# Заголовок\n---\n')

    t.assert_equals(meta, {})
    t.assert_equals(page, '<hr>\n<h1>Заголовок</h1>\n<hr>')
end

g.test_a_head_without_the_second_line_is_not_a_head = function()
    local meta, page = split('---\ntitle: Установка\n')

    t.assert_equals(meta, {})
    t.assert_equals(page, '<hr>\n<p>title: Установка</p>')
end

g.test_a_head_is_read_only_at_the_very_top = function()
    local meta, page = split('текст\n\n---\ntitle: Установка\n---\n')

    t.assert_equals(meta, {})
    t.assert_equals(page, '<p>текст</p>\n<hr>\n<p>title: Установка</p>\n<hr>')
end

g.test_the_markup_starts_right_after_the_head = function()
    t.assert_equals(select(2, split('---\na: 1\n---\nпервый абзац')), '<p>первый абзац</p>')
end

g.test_an_empty_document_has_no_head = function()
    t.assert_equals(split(''), {})
end
