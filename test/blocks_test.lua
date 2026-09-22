--- Проверки блоков: заголовки, абзацы, цитаты, разделители, сырой HTML.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.blocks')

---@return any
local function blocks()
    return helper.part('blocks')
end

-- ── Заголовки ────────────────────────────────────────────────────────

g.test_headings_go_six_levels_deep = function()
    t.assert_equals(helper.render('# раз'), '<h1>раз</h1>')
    t.assert_equals(helper.render('## два'), '<h2>два</h2>')
    t.assert_equals(helper.render('###### шесть'), '<h6>шесть</h6>')
end

g.test_the_seventh_hash_makes_a_paragraph = function()
    t.assert_equals(helper.render('####### семь'), '<p>####### семь</p>')
end

g.test_a_heading_needs_a_space_after_the_hashes = function()
    -- «#2375» в тексте — это номер, а не заголовок.
    t.assert_equals(helper.render('#2375 — сделано'), '<p>#2375 — сделано</p>')
    t.assert_equals(helper.render('#'), '<h1></h1>')
    t.assert_equals(helper.render('   ## с отступом'), '<h2>с отступом</h2>')
end

g.test_trailing_hashes_are_a_decoration = function()
    t.assert_equals(helper.render('## заголовок ##'), '<h2>заголовок</h2>')
    -- Украшения довольно и одного знака.
    t.assert_equals(helper.render('## заголовок #'), '<h2>заголовок</h2>')
    -- Перед решётками нужен пробел, иначе «C#» лишилось бы решётки.
    t.assert_equals(helper.render('## C#'), '<h2>C#</h2>')
end

g.test_a_heading_holds_markup = function()
    t.assert_equals(
        helper.render('# **жирный** заголовок'),
        '<h1><strong>жирный</strong> заголовок</h1>'
    )
end

g.test_a_heading_ends_a_paragraph = function()
    t.assert_equals(helper.render('абзац\n# заголовок'), '<p>абзац</p>\n<h1>заголовок</h1>')
end

-- ── Абзацы ───────────────────────────────────────────────────────────

g.test_lines_of_a_paragraph_are_joined_and_a_blank_line_splits_them = function()
    t.assert_equals(helper.render('раз\nдва\n\nтри'), '<p>раз\nдва</p>\n<p>три</p>')
end

g.test_the_indent_of_a_paragraph_line_does_not_matter = function()
    t.assert_equals(helper.render('   раз\n      два'), '<p>раз\nдва</p>')
end

g.test_spaces_at_the_end_of_the_last_line_are_dropped = function()
    t.assert_equals(helper.render('раз  '), '<p>раз</p>')
end

g.test_an_empty_document_gives_an_empty_page = function()
    t.assert_equals(helper.render(''), '')
    t.assert_equals(helper.render('\n\n   \n'), '')
end

-- ── Разделители ──────────────────────────────────────────────────────

g.test_a_rule_is_three_same_signs_and_more = function()
    t.assert_equals(helper.render('---'), '<hr>')
    t.assert_equals(helper.render('***'), '<hr>')
    t.assert_equals(helper.render('___'), '<hr>')
    t.assert_equals(helper.render('- - -'), '<hr>')
    t.assert_equals(helper.render('-----'), '<hr>')
    t.assert_equals(helper.render('   ---'), '<hr>')
end

g.test_two_signs_are_not_a_rule = function()
    t.assert_equals(helper.render('--'), '<p>--</p>')
end

g.test_signs_of_a_rule_are_all_the_same = function()
    t.assert_equals(helper.render('--a-'), '<p>--a-</p>')
    t.assert_equals(helper.render('-*-'), '<p>-*-</p>')
end

g.test_a_rule_ends_a_paragraph = function()
    -- Заголовков, подчёркнутых снизу, у нас нет: «---» всегда разделитель.
    t.assert_equals(helper.render('раз\n---\nдва'), '<p>раз</p>\n<hr>\n<p>два</p>')
end

-- ── Цитаты ───────────────────────────────────────────────────────────

g.test_a_quote_takes_its_lines = function()
    t.assert_equals(helper.render('> раз\n> два'), '<blockquote>\n<p>раз\nдва</p>\n</blockquote>')
    t.assert_equals(helper.render('>раз'), '<blockquote>\n<p>раз</p>\n</blockquote>')
    t.assert_equals(
        helper.render('   > с отступом'),
        '<blockquote>\n<p>с отступом</p>\n</blockquote>'
    )
end

g.test_a_quote_takes_all_of_its_lines = function()
    -- Третья строка теряться не должна: цитата кончается там, где
    -- кончается знак, а не на второй строке.
    t.assert_equals(
        helper.render('> раз\n> два\n> три'),
        '<blockquote>\n<p>раз\nдва\nтри</p>\n</blockquote>'
    )
end

g.test_a_quote_holds_blocks = function()
    t.assert_equals(
        helper.render('> # заголовок\n> - пункт'),
        '<blockquote>\n<h1>заголовок</h1>\n<ul>\n<li>пункт</li>\n</ul>\n</blockquote>'
    )
end

g.test_a_quote_lives_inside_a_quote = function()
    t.assert_equals(
        helper.render('> > вглубь'),
        '<blockquote>\n<blockquote>\n<p>вглубь</p>\n</blockquote>\n</blockquote>'
    )
end

g.test_an_empty_quote_holds_nothing = function()
    t.assert_equals(helper.render('>'), '<blockquote>\n</blockquote>')
end

g.test_a_blank_line_and_a_line_without_the_sign_end_a_quote = function()
    -- Ленивого продолжения у цитаты нет: строка без «>» — новый блок.
    t.assert_equals(helper.render('> раз\n\nдва'), '<blockquote>\n<p>раз</p>\n</blockquote>\n<p>два</p>')
    t.assert_equals(helper.render('> раз\nдва'), '<blockquote>\n<p>раз</p>\n</blockquote>\n<p>два</p>')
end

g.test_only_one_space_after_the_sign_belongs_to_the_markup = function()
    t.assert_equals(
        helper.render('>  два пробела'),
        '<blockquote>\n<p>два пробела</p>\n</blockquote>'
    )
end

-- ── Вложенность ──────────────────────────────────────────────────────

g.test_nesting_goes_as_deep_as_the_limit_and_no_deeper = function()
    -- Число уровней написано числом нарочно: сверка предела с самим
    -- собой сошлась бы при любом его значении.
    t.assert_equals(blocks().MAX_DEPTH, 32)

    local page = helper.render(('>'):rep(40) .. ' текст')

    t.assert_equals(select(2, page:gsub('<blockquote>', '')), 32)
    -- Остаток читается текстом: знак «>» уходит в страницу сущностью.
    t.assert_str_contains(page, '<p>&gt;')
end

g.test_a_document_of_nothing_but_nesting_is_still_a_page = function()
    -- Без предела глубины десятки тысяч знаков «>» подряд роняли бы
    -- разбор переполнением стека, а пакет обещает не бросать.
    local page = helper.render(('>'):rep(20000))

    t.assert_str_contains(page, '<blockquote>')

    local items = helper.render(('- '):rep(20000) .. 'пункт')

    t.assert_str_contains(items, '<ul>')
end

g.test_a_context_deeper_than_the_limit_nests_nothing = function()
    -- Предел стоит на разборе, а не на счётчике вызовов: контекст
    -- приходит аргументом, и глубина в нём бывает любой.
    local deep = {
        options = { allow_html = false },
        inner = blocks().inner,
        depth = blocks().MAX_DEPTH + 5,
    }

    t.assert_equals(blocks().parse({ '> текст' }, deep), {
        { kind = 'paragraph', inline = { { kind = 'text', text = '> текст' } } },
    })
end

-- ── Сырой HTML ───────────────────────────────────────────────────────

g.test_raw_html_is_escaped_by_default = function()
    t.assert_equals(helper.render('<div>текст</div>'), '<p>&lt;div&gt;текст&lt;/div&gt;</p>')
end

g.test_raw_html_passes_when_it_is_allowed = function()
    t.assert_equals(helper.render('<div>\nтекст\n</div>', { allow_html = true }), '<div>\nтекст\n</div>')
end

g.test_an_allowed_html_block_ends_at_a_blank_line = function()
    t.assert_equals(helper.render('<div></div>\n\nабзац', { allow_html = true }), '<div></div>\n<p>абзац</p>')
end
