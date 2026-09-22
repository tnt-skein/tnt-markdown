--- Проверки таблиц: шапка, выравнивание, строки.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.tables')

--- Таблица из шапки, разделителя и строк.
---@param ... string
---@return string
local function table_of(...)
    return table.concat({ ... }, '\n')
end

g.test_a_table_takes_its_head_and_rows = function()
    t.assert_equals(
        helper.render(table_of('| раз | два |', '|-----|-----|', '| a   | b   |')),
        '<table>\n<thead>\n<tr>\n<th>раз</th>\n<th>два</th>\n</tr>\n</thead>\n'
            .. '<tbody>\n<tr>\n<td>a</td>\n<td>b</td>\n</tr>\n</tbody>\n</table>'
    )
end

g.test_the_alignment_comes_from_the_colons = function()
    local page = helper.render(table_of('| л | ц | п | — |', '|:--|:-:|--:|---|', '| 1 | 2 | 3 | 4 |'))

    t.assert_str_contains(page, '<th style="text-align: left">л</th>')
    t.assert_str_contains(page, '<th style="text-align: center">ц</th>')
    t.assert_str_contains(page, '<th style="text-align: right">п</th>')
    t.assert_str_contains(page, '<th>—</th>')
    t.assert_str_contains(page, '<td style="text-align: center">2</td>')
    t.assert_str_contains(page, '<td>4</td>')
end

g.test_cells_hold_markup = function()
    t.assert_str_contains(
        helper.render(table_of('| имя |', '|-----|', '| `код` |')),
        '<td><code>код</code></td>'
    )
end

g.test_the_outer_pipes_are_optional = function()
    t.assert_equals(
        helper.render(table_of('раз | два', '--- | ---', 'a | b')),
        '<table>\n<thead>\n<tr>\n<th>раз</th>\n<th>два</th>\n</tr>\n</thead>\n'
            .. '<tbody>\n<tr>\n<td>a</td>\n<td>b</td>\n</tr>\n</tbody>\n</table>'
    )
end

g.test_a_table_without_rows_is_still_a_table = function()
    t.assert_equals(
        helper.render(table_of('| раз |', '|-----|')),
        '<table>\n<thead>\n<tr>\n<th>раз</th>\n</tr>\n</thead>\n<tbody>\n</tbody>\n</table>'
    )
end

g.test_a_short_row_is_filled_and_a_long_one_is_cut = function()
    local page = helper.render(table_of('| раз | два |', '|-----|-----|', '| a |', '| a | b | c |'))

    t.assert_str_contains(page, '<tr>\n<td>a</td>\n<td></td>\n</tr>')
    t.assert_str_contains(page, '<tr>\n<td>a</td>\n<td>b</td>\n</tr>')
end

g.test_a_pipe_inside_a_cell_is_written_with_a_backslash = function()
    t.assert_str_contains(helper.render(table_of('| образец |', '|---------|', '| a \\| b |')), '<td>a | b</td>')
end

g.test_the_counts_of_columns_must_match = function()
    -- Иначе это не таблица, а абзац с чертой внутри.
    t.assert_equals(helper.render(table_of('| раз | два |', '|-----|')), '<p>| раз | два |\n|-----|</p>')
end

g.test_a_delimiter_without_a_pipe_is_not_a_delimiter = function()
    t.assert_equals(helper.render(table_of('раз', '---', 'a')), '<p>раз</p>\n<hr>\n<p>a</p>')
end

g.test_a_delimiter_holds_only_dashes_and_colons = function()
    t.assert_equals(helper.render(table_of('| раз |', '| a-b |')), '<p>| раз |\n| a-b |</p>')
    t.assert_equals(helper.render(table_of('| раз |', '| : |')), '<p>| раз |\n| : |</p>')
    t.assert_equals(helper.render(table_of('| раз |', '|  |')), '<p>| раз |\n|  |</p>')
end

g.test_a_table_ends_at_a_blank_line_and_at_a_line_without_a_pipe = function()
    local page = helper.render(table_of('| раз |', '|-----|', '| a |', 'абзац'))

    t.assert_str_contains(page, '</table>\n<p>абзац</p>')

    local other = helper.render(table_of('| раз |', '|-----|', '| a |', '', 'абзац'))

    t.assert_str_contains(other, '</table>\n<p>абзац</p>')
end

g.test_a_table_starts_right_inside_a_paragraph = function()
    t.assert_str_contains(helper.render(table_of('абзац', '| раз |', '|-----|')), '<p>абзац</p>\n<table>')
end

g.test_a_line_with_a_pipe_alone_is_a_paragraph = function()
    t.assert_equals(helper.render('раз | два'), '<p>раз | два</p>')
end
