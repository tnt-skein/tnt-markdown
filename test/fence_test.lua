--- Проверки оград кода.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.fence')

g.test_content_of_a_fence_is_not_markup = function()
    t.assert_equals(helper.render('```\n*не курсив*\n```'), '<pre><code>*не курсив*\n</code></pre>')
end

g.test_content_of_a_fence_is_escaped = function()
    t.assert_equals(helper.render('```\nif a < b then\n```'), '<pre><code>if a &lt; b then\n</code></pre>')
end

g.test_the_first_word_of_the_head_becomes_the_class = function()
    t.assert_equals(
        helper.render('```lua\nlocal x = 1\n```'),
        '<pre><code class="language-lua">local x = 1\n</code></pre>'
    )
    t.assert_equals(helper.render('```sh title=x\nls\n```'), '<pre><code class="language-sh">ls\n</code></pre>')
end

g.test_a_fence_without_a_head_has_no_class = function()
    t.assert_equals(helper.render('```\nкод\n```'), '<pre><code>код\n</code></pre>')
    t.assert_equals(helper.render('```   \nкод\n```'), '<pre><code>код\n</code></pre>')
end

g.test_the_name_of_the_language_is_escaped = function()
    t.assert_equals(helper.render('```<b>\nкод\n```'), '<pre><code class="language-&lt;b&gt;">код\n</code></pre>')
end

g.test_an_unclosed_fence_ends_with_the_document = function()
    t.assert_equals(helper.render('```\nкод'), '<pre><code>код\n</code></pre>')
end

g.test_an_empty_fence_holds_nothing = function()
    t.assert_equals(helper.render('```\n```'), '<pre><code></code></pre>')
end

g.test_an_empty_line_inside_a_fence_stays = function()
    t.assert_equals(helper.render('```\n\nкод\n```'), '<pre><code>\nкод\n</code></pre>')
end

g.test_a_fence_needs_three_signs = function()
    t.assert_equals(helper.render('``код``'), '<p><code>код</code></p>')
    -- Две кавычки без пары — текст, а не ограда до конца документа.
    t.assert_equals(helper.render('``код'), '<p>``код</p>')
end

g.test_a_longer_fence_is_closed_by_a_longer_one = function()
    t.assert_equals(helper.render('````\n```\n````'), '<pre><code>```\n</code></pre>')
    t.assert_equals(helper.render('```\nкод\n````'), '<pre><code>код\n</code></pre>')
end

g.test_nothing_but_the_signs_closes_a_fence = function()
    t.assert_equals(
        helper.render('```\nкод\n``` хвост\n```'),
        '<pre><code>код\n``` хвост\n</code></pre>'
    )
end

g.test_a_fence_of_tildes_works_the_same = function()
    t.assert_equals(helper.render('~~~\nкод\n~~~'), '<pre><code>код\n</code></pre>')
    -- Ограду из тильд обратная кавычка в шапке не отменяет.
    t.assert_equals(helper.render('~~~ `x`\nкод\n~~~'), '<pre><code class="language-`x`">код\n</code></pre>')
end

g.test_a_backtick_in_the_head_means_no_fence = function()
    -- Иначе строка «а``б``» в тексте открывала бы ограду до конца документа.
    t.assert_equals(helper.render('```x`\nтекст'), '<p>```x`\nтекст</p>')
end

g.test_a_fence_with_an_indent_takes_the_indent_off_its_content = function()
    t.assert_equals(helper.render('  ```\n    код\n  ```'), '<pre><code>  код\n</code></pre>')
end

g.test_a_fence_ends_a_paragraph = function()
    t.assert_equals(
        helper.render('абзац\n```\nкод\n```'),
        '<p>абзац</p>\n<pre><code>код\n</code></pre>'
    )
end
