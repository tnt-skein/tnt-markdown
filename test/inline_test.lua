--- Проверки разметки внутри строки: код, выделение, переносы.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.inline')

-- ── Код ──────────────────────────────────────────────────────────────

g.test_code_is_not_markup = function()
    t.assert_equals(helper.paragraph('`*не курсив*`'), '<code>*не курсив*</code>')
    t.assert_equals(helper.paragraph('`<имя>`'), '<code>&lt;имя&gt;</code>')
end

g.test_a_double_backtick_holds_a_backtick = function()
    t.assert_equals(helper.paragraph('`` ` ``'), '<code>`</code>')
end

g.test_code_of_spaces_alone_keeps_them = function()
    t.assert_equals(helper.paragraph('` `'), '<code> </code>')
end

g.test_a_pair_of_spaces_goes_off_only_together = function()
    t.assert_equals(helper.paragraph('` код`'), '<code> код</code>')
    t.assert_equals(helper.paragraph('` код `'), '<code>код</code>')
end

g.test_a_line_ending_inside_code_becomes_a_space = function()
    t.assert_equals(helper.paragraph('`раз\nдва`'), '<code>раз два</code>')
end

g.test_a_backtick_without_a_pair_stays_itself = function()
    t.assert_equals(helper.paragraph('`код'), '`код')
    t.assert_equals(helper.paragraph('``код`'), '``код`')
end

-- ── Выделение ────────────────────────────────────────────────────────

g.test_one_sign_is_italic_and_two_are_bold = function()
    t.assert_equals(helper.paragraph('*курсив*'), '<em>курсив</em>')
    t.assert_equals(helper.paragraph('**жирный**'), '<strong>жирный</strong>')
    t.assert_equals(helper.paragraph('_курсив_'), '<em>курсив</em>')
    t.assert_equals(helper.paragraph('__жирный__'), '<strong>жирный</strong>')
end

g.test_three_signs_are_just_signs = function()
    t.assert_equals(helper.paragraph('***x***'), '***x***')
end

g.test_emphasis_lives_inside_emphasis = function()
    t.assert_equals(
        helper.paragraph('**жирный с *курсивом* внутри**'),
        '<strong>жирный с <em>курсивом</em> внутри</strong>'
    )
    t.assert_equals(
        helper.paragraph('*курсив с **жирным** внутри*'),
        '<em>курсив с <strong>жирным</strong> внутри</em>'
    )
end

g.test_a_sign_without_a_pair_stays_itself = function()
    t.assert_equals(helper.paragraph('**без пары'), '**без пары')
    t.assert_equals(helper.paragraph('раз * два * три'), 'раз * два * три')
end

g.test_a_space_inside_emphasis_is_an_ordinary_sign = function()
    -- Пробел решает только на самом краю серии.
    t.assert_equals(helper.paragraph('*раз два*'), '<em>раз два</em>')
end

g.test_a_sign_that_started_nothing_gives_up_one_sign = function()
    -- Восклицательный знак без ссылки остаётся собой, а разметка сразу
    -- за ним разбирается как ни в чём не бывало.
    t.assert_equals(helper.paragraph('!*курсив*'), '!<em>курсив</em>')
end

g.test_a_space_after_the_opening_sign_means_no_emphasis = function()
    -- Звёздочка в начале строки — знак списка, поэтому случай берётся
    -- из середины абзаца.
    t.assert_equals(helper.paragraph('раз * курсив*'), 'раз * курсив*')
    t.assert_equals(helper.paragraph('*курсив *'), '*курсив *')
end

g.test_an_underscore_does_not_work_inside_a_word = function()
    -- Иначе «имя_поля_таблицы» разъезжалось бы на курсив.
    t.assert_equals(helper.paragraph('имя_поля_таблицы'), 'имя_поля_таблицы')
    t.assert_equals(helper.paragraph('request_id и trace_id'), 'request_id и trace_id')
    t.assert_equals(helper.paragraph('слово_раз_два'), 'слово_раз_два')
end

g.test_a_star_works_inside_a_word = function()
    t.assert_equals(helper.paragraph('не*жирный*текст'), 'не<em>жирный</em>текст')
end

g.test_an_underscore_closes_only_at_the_edge_of_a_word = function()
    t.assert_equals(helper.paragraph('_курсив_ю'), '_курсив_ю')
    t.assert_equals(helper.paragraph('(_курсив_)'), '(<em>курсив</em>)')
end

g.test_a_quotation_mark_and_a_dash_are_not_a_word = function()
    -- Байты у ёлочки и у тире такие же высокие, как у русской буквы,
    -- но словом они не бывают: курсив в кавычках обязан взяться.
    t.assert_equals(helper.paragraph('«_курсив_»'), '«<em>курсив</em>»')
    t.assert_equals(
        helper.paragraph('раз — _курсив_ — два'),
        'раз — <em>курсив</em> — два'
    )
end

-- ── Экранирование ────────────────────────────────────────────────────

g.test_a_backslash_takes_the_meaning_off_a_sign = function()
    t.assert_equals(helper.paragraph('\\*не курсив\\*'), '*не курсив*')
    t.assert_equals(helper.paragraph('\\`не код\\`'), '`не код`')
end

g.test_a_backslash_before_a_letter_stays_itself = function()
    t.assert_equals(helper.paragraph('C:\\path'), 'C:\\path')
    t.assert_equals(helper.paragraph('хвост\\'), 'хвост\\')
end

-- ── Переносы ─────────────────────────────────────────────────────────

g.test_two_spaces_at_the_end_of_a_line_make_a_break = function()
    t.assert_equals(helper.paragraph('раз  \nдва'), 'раз<br>\nдва')
    t.assert_equals(helper.paragraph('раз   \nдва'), 'раз<br>\nдва')
end

g.test_one_space_at_the_end_of_a_line_makes_nothing = function()
    t.assert_equals(helper.paragraph('раз \nдва'), 'раз\nдва')
    t.assert_equals(helper.paragraph('раз\nдва'), 'раз\nдва')
end

g.test_a_backslash_at_the_end_of_a_line_makes_a_break = function()
    t.assert_equals(helper.paragraph('раз\\\nдва'), 'раз<br>\nдва')
end

g.test_a_break_right_after_markup = function()
    t.assert_equals(helper.paragraph('**раз**  \nдва'), '<strong>раз</strong><br>\nдва')
    t.assert_equals(helper.paragraph('**раз**\nдва'), '<strong>раз</strong>\nдва')
end

-- ── Дерево ───────────────────────────────────────────────────────────

g.test_the_text_of_a_paragraph_goes_in_one_piece = function()
    t.assert_equals(helper.parse('раз **два** три'), {
        {
            kind = 'paragraph',
            inline = {
                { kind = 'text', text = 'раз ' },
                { kind = 'strong', inline = { { kind = 'text', text = 'два' } } },
                { kind = 'text', text = ' три' },
            },
        },
    })
end

g.test_a_sign_without_markup_does_not_split_the_text = function()
    -- Знак, у которого нет разборщика, остаётся в тексте одним куском
    -- с соседями: знак равенства и прочая пунктуация в документации
    -- встречаются постоянно, и лишний узел разрывал бы текст раздела.
    t.assert_equals(helper.parse('a = b')[1].inline, { { kind = 'text', text = 'a = b' } })
    t.assert_equals(
        helper.paragraph('x=1; y := 2 + 3 - 4 / 5 % 6 ^ 7 | 8 & 9 ~ 0 # @ ? , . : ; ( ) { }'),
        'x=1; y := 2 + 3 - 4 / 5 % 6 ^ 7 | 8 &amp; 9 ~ 0 # @ ? , . : ; ( ) { }'
    )
    t.assert_equals(
        helper.parse('x=1; y := 2 + 3 - 4 / 5 % 6 ^ 7 | 8 & 9 ~ 0 # @ ? , . : ; ( ) { }')[1].inline,
        { { kind = 'text', text = 'x=1; y := 2 + 3 - 4 / 5 % 6 ^ 7 | 8 & 9 ~ 0 # @ ? , . : ; ( ) { }' } }
    )
end

g.test_the_tree_of_a_line_break = function()
    t.assert_equals(helper.parse('раз  \nдва')[1].inline, {
        { kind = 'text', text = 'раз' },
        { kind = 'break' },
        { kind = 'text', text = 'два' },
    })
end

g.test_the_tree_holds_no_empty_text = function()
    -- Пустая строка копится перед каждым вкраплением, и узлом она
    -- засоряла бы и оглавление, и указатель поиска.
    t.assert_equals(helper.parse('**раз**\nдва')[1].inline, {
        { kind = 'strong', inline = { { kind = 'text', text = 'раз' } } },
        { kind = 'softbreak' },
        { kind = 'text', text = 'два' },
    })
    t.assert_equals(helper.parse('`код`')[1].inline, { { kind = 'code', text = 'код' } })
end
