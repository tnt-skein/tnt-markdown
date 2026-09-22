--- Проверки якорей: имя из текста, кириллица, повторы внутри страницы.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.anchor')

---@return any
local function anchor()
    return helper.part('anchor')
end

-- ── Имя якоря ────────────────────────────────────────────────────────

g.test_a_russian_heading_keeps_its_letters = function()
    t.assert_equals(anchor().slug('Как пользоваться'), 'как-пользоваться')
    t.assert_equals(
        anchor().slug('ЧЕМ ПРИШЛОСЬ ПОСТУПИТЬСЯ'),
        'чем-пришлось-поступиться'
    )
    t.assert_equals(anchor().slug('Ёлка'), 'ёлка')
end

g.test_everything_but_letters_and_digits_separates_words = function()
    t.assert_equals(anchor().slug('Как пользоваться?'), 'как-пользоваться')
    t.assert_equals(anchor().slug('markdown.render — что отдаёт'), 'markdown-render-что-отдаёт')
    t.assert_equals(anchor().slug('tnt-markdown'), 'tnt-markdown')
    t.assert_equals(anchor().slug('имя_поля'), 'имя-поля')
end

g.test_separators_in_a_row_give_one_dash_and_the_edges_stay_clean = function()
    t.assert_equals(anchor().slug('  Список,  узлов!  '), 'список-узлов')
    t.assert_equals(anchor().slug('§3.11. Уровень вины'), '3-11-уровень-вины')
end

g.test_digits_are_a_word_of_their_own = function()
    t.assert_equals(anchor().slug('Волна 0'), 'волна-0')
    t.assert_equals(anchor().slug('HTTP 429'), 'http-429')
end

g.test_a_heading_without_letters_and_digits_is_still_reachable = function()
    t.assert_equals(anchor().slug('—'), 'section')
    t.assert_equals(anchor().slug(''), 'section')
    t.assert_equals(anchor().NAMELESS, 'section')
end

-- ── Повторы внутри страницы ──────────────────────────────────────────

g.test_a_repeated_heading_gets_a_number = function()
    local taken = {}

    t.assert_equals(anchor().take(taken, 'Как пользоваться'), 'как-пользоваться')
    t.assert_equals(anchor().take(taken, 'Как пользоваться'), 'как-пользоваться-2')
    t.assert_equals(anchor().take(taken, 'Как пользоваться'), 'как-пользоваться-3')
end

g.test_the_number_goes_up_to_a_free_name = function()
    -- «Раздел 2» занимает имя, которое иначе досталось бы второму
    -- «Разделу», и ссылка на второй уводила бы к третьему.
    local taken = {}

    t.assert_equals(anchor().take(taken, 'Раздел'), 'раздел')
    t.assert_equals(anchor().take(taken, 'Раздел 2'), 'раздел-2')
    t.assert_equals(anchor().take(taken, 'Раздел'), 'раздел-3')
end

g.test_different_headings_do_not_bother_each_other = function()
    local taken = {}

    t.assert_equals(anchor().take(taken, 'Первый'), 'первый')
    t.assert_equals(anchor().take(taken, 'Второй'), 'второй')
    t.assert_equals(taken, { ['первый'] = true, ['второй'] = true })
end

-- ── Какие уровни ─────────────────────────────────────────────────────

g.test_only_the_second_third_and_fourth_level_get_an_anchor = function()
    t.assert_equals(anchor().leveled(1), false)
    t.assert_equals(anchor().leveled(2), true)
    t.assert_equals(anchor().leveled(3), true)
    t.assert_equals(anchor().leveled(4), true)
    t.assert_equals(anchor().leveled(5), false)
    t.assert_equals(anchor().MIN_LEVEL, 2)
    t.assert_equals(anchor().MAX_LEVEL, 4)
end
