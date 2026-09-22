--- Проверки голого текста: подпись картинки и текст для поиска.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.plain')

---@return any
local function plain()
    return helper.part('plain')
end

-- ── Вкрапления ───────────────────────────────────────────────────────

g.test_markup_inside_a_line_leaves_only_its_text = function()
    local tree = helper.parse(
        '**жирный** и *курсив* с `кодом` и [ссылкой](/куда "подпись")'
    )

    t.assert_equals(plain().inline(tree[1].inline), 'жирный и курсив с кодом и ссылкой')
end

g.test_a_line_break_becomes_a_space = function()
    -- Без пробела «раз» и «два» слиплись бы в одно слово, и поиск
    -- по слову «два» не нашёл бы страницы.
    local tree = helper.parse('раз\nдва  \nтри')

    t.assert_equals(plain().inline(tree[1].inline), 'раз два три')
end

g.test_the_caption_of_an_image_is_its_text = function()
    local tree = helper.parse('![схема **узла**](/a.png)')

    t.assert_equals(plain().inline(tree[1].inline), 'схема узла')
end

g.test_raw_html_of_a_line_goes_as_it_is_written = function()
    local tree = helper.parse('текст <b>жирно</b>', { allow_html = true })

    t.assert_equals(plain().inline(tree[1].inline), 'текст <b>жирно</b>')
end

g.test_a_node_without_text_and_without_children_gives_nothing = function()
    t.assert_equals(plain().inline({ { kind = 'подсветка' } }), '')
    t.assert_equals(plain().inline({}), '')
end

-- ── Блоки ────────────────────────────────────────────────────────────

g.test_blocks_are_split_by_a_line_and_a_rule_leaves_no_trace = function()
    local tree = helper.parse('первый абзац\n\n---\n\nвторой абзац')

    t.assert_equals(plain().blocks(tree), 'первый абзац\nвторой абзац')
end

g.test_a_heading_and_a_fence_are_read_as_text = function()
    local tree = helper.parse('## Раздел\n\n```lua\nlocal x = 1\n```')

    t.assert_equals(plain().blocks(tree), 'Раздел\nlocal x = 1\n')
end

g.test_items_of_a_list_go_one_per_line = function()
    local tree = helper.parse('- раз\n- два\n  - вложенный')

    t.assert_equals(plain().blocks(tree), 'раз\nдва\nвложенный')
end

g.test_a_quote_is_read_through = function()
    local tree = helper.parse('> цитата\n>\n> и второй абзац')

    t.assert_equals(plain().blocks(tree), 'цитата\nи второй абзац')
end

g.test_a_table_gives_a_line_per_row_and_a_space_between_cells = function()
    local tree =
        helper.parse('| Пакет | Кому нужен |\n|---|---|\n| `tnt-fs` | s3 |\n| tnt-str | всем |')

    t.assert_equals(plain().blocks(tree), 'Пакет Кому нужен\ntnt-fs s3\ntnt-str всем')
end

g.test_a_block_kept_by_the_pipeline_is_read_by_its_fields = function()
    -- Род узла, которого в пакете нет: текст читается по полям, поэтому
    -- узел своего преобразования попадает в поиск без правки пакета.
    local tree = {
        {
            kind = 'сноска',
            blocks = { { kind = 'paragraph', inline = { { kind = 'text', text = 'внутри' } } } },
        },
        { kind = 'подпись', text = 'снизу' },
        { kind = 'пустышка' },
    }

    t.assert_equals(plain().blocks(tree), 'внутри\nснизу')
end
