--- Проверки списков: простых, нумерованных, вложенных.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.list')

g.test_a_simple_list_takes_any_of_three_signs = function()
    t.assert_equals(helper.render('- раз\n- два'), '<ul>\n<li>раз</li>\n<li>два</li>\n</ul>')
    t.assert_equals(helper.render('* раз'), '<ul>\n<li>раз</li>\n</ul>')
    t.assert_equals(helper.render('+ раз'), '<ul>\n<li>раз</li>\n</ul>')
end

g.test_a_numbered_list_takes_a_dot_and_a_bracket = function()
    t.assert_equals(helper.render('1. раз\n2. два'), '<ol>\n<li>раз</li>\n<li>два</li>\n</ol>')
    t.assert_equals(helper.render('1) раз'), '<ol>\n<li>раз</li>\n</ol>')
end

g.test_a_numbered_list_starts_where_it_was_told = function()
    -- Номер начала пишется, только когда он не первый.
    t.assert_equals(
        helper.render('3. три\n4. четыре'),
        '<ol start="3">\n<li>три</li>\n<li>четыре</li>\n</ol>'
    )
    t.assert_equals(helper.render('1. раз'), '<ol>\n<li>раз</li>\n</ol>')
end

g.test_a_sign_without_a_space_is_not_a_list = function()
    t.assert_equals(helper.render('-текст'), '<p>-текст</p>')
    t.assert_equals(helper.render('1.текст'), '<p>1.текст</p>')
end

g.test_an_empty_item_is_a_legal_item = function()
    t.assert_equals(helper.render('-\n- два'), '<ul>\n<li></li>\n<li>два</li>\n</ul>')
end

g.test_the_content_of_an_item_starts_where_its_text_starts = function()
    t.assert_equals(
        helper.render('- раз\n  продолжение'),
        '<ul>\n<li>раз\nпродолжение</li>\n</ul>'
    )
    -- Строка без отступа пункт кончает: ленивого продолжения нет.
    t.assert_equals(
        helper.render('- раз\nотдельно'),
        '<ul>\n<li>раз</li>\n</ul>\n<p>отдельно</p>'
    )
end

g.test_the_content_of_an_empty_item_starts_right_after_the_sign = function()
    t.assert_equals(helper.render('-\n продолжение'), '<ul>\n<li>продолжение</li>\n</ul>')
    t.assert_equals(helper.render('-\nотдельно'), '<ul>\n<li></li>\n</ul>\n<p>отдельно</p>')
end

g.test_the_content_of_an_item_takes_a_deeper_indent_too = function()
    t.assert_equals(
        helper.render('- раз\n      продолжение'),
        '<ul>\n<li>раз\nпродолжение</li>\n</ul>'
    )
end

g.test_a_sign_without_a_number_is_not_a_list = function()
    -- «. текст» и «) текст» — это текст: числа перед знаком нет.
    t.assert_equals(helper.render('. текст'), '<p>. текст</p>')
    t.assert_equals(helper.render(') текст'), '<p>) текст</p>')
end

g.test_a_list_lives_inside_a_list = function()
    t.assert_equals(
        helper.render('- раз\n  - вложенный'),
        '<ul>\n<li>раз\n<ul>\n<li>вложенный</li>\n</ul></li>\n</ul>'
    )
end

g.test_an_item_holds_blocks = function()
    t.assert_equals(
        helper.render('- раз\n\n  ```lua\n  local x = 1\n  ```'),
        '<ul>\n<li>\n<p>раз</p>\n<pre><code class="language-lua">local x = 1\n</code></pre>\n</li>\n</ul>'
    )
end

g.test_a_blank_line_between_items_makes_the_list_spacious = function()
    t.assert_equals(
        helper.render('- раз\n\n- два'),
        '<ul>\n<li>\n<p>раз</p>\n</li>\n<li>\n<p>два</p>\n</li>\n</ul>'
    )
end

g.test_a_blank_line_inside_an_item_makes_the_list_spacious = function()
    t.assert_equals(
        helper.render('- раз\n\n  ещё\n- два'),
        '<ul>\n<li>\n<p>раз</p>\n<p>ещё</p>\n</li>\n<li>\n<p>два</p>\n</li>\n</ul>'
    )
end

g.test_a_list_without_blank_lines_is_tight = function()
    t.assert_equals(
        helper.render('- раз\n- два\n- три'),
        '<ul>\n<li>раз</li>\n<li>два</li>\n<li>три</li>\n</ul>'
    )
end

g.test_a_change_of_the_sign_starts_a_new_list = function()
    t.assert_equals(helper.render('- раз\n* два'), '<ul>\n<li>раз</li>\n</ul>\n<ul>\n<li>два</li>\n</ul>')
    t.assert_equals(helper.render('1. раз\n1) два'), '<ol>\n<li>раз</li>\n</ol>\n<ol>\n<li>два</li>\n</ol>')
end

g.test_a_blank_line_after_a_list_ends_it = function()
    t.assert_equals(helper.render('- раз\n\nабзац'), '<ul>\n<li>раз</li>\n</ul>\n<p>абзац</p>')
end

g.test_a_simple_list_starts_right_inside_a_paragraph = function()
    -- Так написаны наши документы: «Что развязать:» и список следом.
    t.assert_equals(
        helper.render('Порядок работ:\n- раз'),
        '<p>Порядок работ:</p>\n<ul>\n<li>раз</li>\n</ul>'
    )
end

g.test_a_numbered_list_interrupts_a_paragraph_only_from_the_first_number = function()
    -- «медленный клиент рвётся кодом\n3008. Свой протокол…» — это номер
    -- кода, перенесённый на новую строку, а не начало списка.
    t.assert_equals(
        helper.render('рвётся кодом\n3008. Свой протокол'),
        '<p>рвётся кодом\n3008. Свой протокол</p>'
    )
    t.assert_equals(
        helper.render('Порядок работ:\n1. Написать'),
        '<p>Порядок работ:</p>\n<ol>\n<li>Написать</li>\n</ol>'
    )
end

g.test_an_empty_item_does_not_interrupt_a_paragraph = function()
    t.assert_equals(helper.render('абзац\n-'), '<p>абзац\n-</p>')
end

g.test_a_numbered_list_starts_a_document_from_any_number = function()
    t.assert_equals(
        helper.render('3008. Свой протокол'),
        '<ol start="3008">\n<li>Свой протокол</li>\n</ol>'
    )
end
