--- Проверки строк и знаков разметки.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.lines')

---@return any
local function lines()
    return helper.part('lines')
end

g.test_line_endings_of_three_kinds_become_one = function()
    t.assert_equals(
        lines().split('раз\nдва\r\nтри\rчетыре'),
        { 'раз', 'два', 'три', 'четыре' }
    )
end

g.test_the_last_line_ending_does_not_add_a_line = function()
    t.assert_equals(lines().split('раз\n'), { 'раз' })
    t.assert_equals(lines().split('раз\n\n'), { 'раз', '' })
    t.assert_equals(lines().split('раз'), { 'раз' })
    t.assert_equals(lines().split(''), {})
    -- Файл из одного перевода строки — одна пустая строка, а не пустота.
    t.assert_equals(lines().split('\r\n'), { '' })
end

g.test_a_tab_becomes_four_spaces = function()
    -- Отступ решает, чьё это содержимое, и таб, оставленный собой,
    -- считался бы за один пробел.
    t.assert_equals(lines().split('\tраз'), { '    раз' })
    t.assert_equals(lines().split('a\tb'), { 'a    b' })
    t.assert_equals(lines().TAB, 4)
end

g.test_a_blank_line_is_one_without_a_single_visible_sign = function()
    t.assert_equals(lines().blank(''), true)
    t.assert_equals(lines().blank('   '), true)
    t.assert_equals(lines().blank('  a  '), false)
end

g.test_the_indent_is_counted_in_spaces = function()
    t.assert_equals(lines().indent_of('раз'), 0)
    t.assert_equals(lines().indent_of('   раз'), 3)
    t.assert_equals(lines().indent_of('   '), 3)
end

g.test_trimming_takes_spaces_off_the_edges = function()
    t.assert_equals(lines().trim('  раз два  '), 'раз два')
    t.assert_equals(lines().trim('   '), '')
    t.assert_equals(lines().trim('раз'), 'раз')
    t.assert_equals(lines().trim_left('  раз  '), 'раз  ')
    t.assert_equals(lines().trim_left('раз'), 'раз')
    t.assert_equals(lines().trim_left('   '), '')
end

g.test_stripping_takes_the_indent_but_no_more = function()
    -- Лишние пробелы внутри ограды — часть кода, а не разметки.
    t.assert_equals(lines().strip('      код', 4), '  код')
    t.assert_equals(lines().strip('  код', 4), 'код')
    t.assert_equals(lines().strip('код', 4), 'код')
    t.assert_equals(lines().strip('  код', 0), '  код')
end

g.test_a_sign_is_taken_whole_and_not_by_its_last_byte = function()
    -- У «л» и у закрывающей ёлочки последний байт один и тот же, и по
    -- нему букву от кавычки не отличить.
    t.assert_equals(lines().char_before('имя!', 7), 'я')
    t.assert_equals(lines().char_before('ab', 3), 'b')
    t.assert_equals(lines().char_before('abc', 1), '')
    t.assert_equals(lines().char_at('яд', 1), 'я')
    t.assert_equals(lines().char_at('ad', 1), 'a')
    t.assert_equals(lines().char_at('a', 2), '')
end

g.test_a_letter_is_a_part_of_a_word_and_a_quotation_mark_is_not = function()
    -- Без букв вне ASCII «имя_поля», написанное по-русски, разъезжалось
    -- бы на курсив; со всеми высокими байтами подряд курсив не взялся бы
    -- в «_курсиве_».
    t.assert_equals(lines().wordy('a'), true)
    t.assert_equals(lines().wordy('7'), true)
    t.assert_equals(lines().wordy('я'), true)
    t.assert_equals(lines().wordy('«'), false)
    t.assert_equals(lines().wordy('—'), false)
    t.assert_equals(lines().wordy(' '), false)
    t.assert_equals(lines().wordy('.'), false)
    t.assert_equals(lines().wordy(''), false)
end

g.test_the_tail_starts_where_it_was_told = function()
    t.assert_equals(lines().tail({ 'раз', 'два', 'три' }, 2), { 'два', 'три' })
    t.assert_equals(lines().tail({ 'раз' }, 2), {})
end
