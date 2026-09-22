--- Проверки рисования: экранирование, дерево руками, чужой род узла.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.html')

---@return any
local function escape()
    return helper.part('escape')
end

g.test_five_signs_leave_as_entities_and_the_rest_stays = function()
    t.assert_equals(escape().html('&<>"\''), '&amp;&lt;&gt;&quot;&#39;')
    t.assert_equals(
        escape().html('точка, тире — и (скобки)'),
        'точка, тире — и (скобки)'
    )
    t.assert_equals(escape().html(''), '')
end

g.test_the_text_of_a_page_is_escaped_everywhere = function()
    t.assert_equals(
        helper.render('текст <b> & "кавычки"'),
        '<p>текст &lt;b&gt; &amp; &quot;кавычки&quot;</p>'
    )
    t.assert_equals(helper.render('# <b> & "x"'), '<h1>&lt;b&gt; &amp; &quot;x&quot;</h1>')
    t.assert_equals(helper.render('```\n<b> & "x"\n```'), '<pre><code>&lt;b&gt; &amp; &quot;x&quot;\n</code></pre>')
    t.assert_equals(helper.render('`<b> & "x"`'), '<p><code>&lt;b&gt; &amp; &quot;x&quot;</code></p>')
end

g.test_a_tree_built_by_hand_is_drawn_too = function()
    local tree = {
        { kind = 'rule' },
        {
            kind = 'paragraph',
            inline = {
                { kind = 'text', text = 'раз' },
                { kind = 'softbreak' },
                { kind = 'emphasis', inline = { { kind = 'text', text = 'два' } } },
                { kind = 'break' },
                {
                    kind = 'image',
                    src = '/a.png',
                    title = 'подпись',
                    inline = { { kind = 'text', text = 'схема' } },
                },
                { kind = 'html', text = '<hr>' },
            },
        },
    }

    t.assert_equals(
        helper.markdown.to_html(tree),
        '<hr>\n<p>раз\n<em>два</em><br>\n<img src="/a.png" alt="схема" title="подпись"><hr></p>'
    )
end

g.test_the_caption_of_an_image_keeps_a_space_at_the_line_break = function()
    -- Подпись — голый текст, и перенос внутри неё значит пробел: иначе
    -- «схема» и «узла» слиплись бы в одно слово.
    t.assert_equals(
        helper.render('![схема\nузла](/a.png)'),
        '<p><img src="/a.png" alt="схема узла"></p>'
    )
end

g.test_an_unknown_kind_of_a_block_is_a_mistake_of_the_one_who_built_the_tree = function()
    local _, err = pcall(helper.markdown.to_html, { { kind = 'сноска' } })

    t.assert_equals(err, 'блок разметки «сноска» пакету незнаком')
end

g.test_an_unknown_kind_of_an_inline_node_is_the_same_mistake = function()
    local tree = { { kind = 'paragraph', inline = { { kind = 'подсветка' } } } }
    local _, err = pcall(helper.markdown.to_html, tree)

    t.assert_equals(err, 'узел разметки «подсветка» пакету незнаком')
end

g.test_a_node_without_a_kind_is_named_too = function()
    local _, err = pcall(helper.markdown.to_html, { {} })

    t.assert_equals(err, 'блок разметки «nil» пакету незнаком')
end

-- ── Что пришло из конвейера ──────────────────────────────────────────

g.test_a_heading_with_an_anchor_gets_an_id_and_a_link_to_itself = function()
    local tree = {
        { kind = 'heading', level = 2, anchor = 'плашки', inline = { { kind = 'text', text = 'Плашки' } } },
    }

    t.assert_equals(
        helper.markdown.to_html(tree),
        '<h2 id="плашки">Плашки<a class="anchor" href="#плашки" aria-label="Ссылка на этот раздел"></a></h2>'
    )
end

g.test_a_heading_without_an_anchor_stays_as_it_was = function()
    local tree = { { kind = 'heading', level = 1, inline = { { kind = 'text', text = 'Страница' } } } }

    t.assert_equals(helper.markdown.to_html(tree), '<h1>Страница</h1>')
end

g.test_the_anchor_of_a_heading_is_escaped_like_any_text = function()
    local tree = { { kind = 'heading', level = 3, anchor = '"раз', inline = {} } }

    t.assert_equals(
        helper.markdown.to_html(tree),
        '<h3 id="&quot;раз"><a class="anchor" href="#&quot;раз" aria-label="Ссылка на этот раздел"></a></h3>'
    )
end

g.test_a_callout_shows_its_view_by_a_class = function()
    local tree = {
        {
            kind = 'callout',
            view = 'warning',
            blocks = { { kind = 'paragraph', inline = { { kind = 'text', text = 'Осторожно' } } } },
        },
    }

    t.assert_equals(
        helper.markdown.to_html(tree),
        '<aside class="callout callout-warning">\n<p>Осторожно</p>\n</aside>'
    )
end

g.test_an_empty_callout_is_drawn_too_and_its_view_is_escaped = function()
    t.assert_equals(
        helper.markdown.to_html({ { kind = 'callout', view = '<b>', blocks = {} } }),
        '<aside class="callout callout-&lt;b&gt;">\n</aside>'
    )
end

g.test_a_wrap_carries_its_class_and_its_blocks = function()
    local tree = { { kind = 'wrap', class = 'table-scroll', blocks = { { kind = 'rule' } } } }

    t.assert_equals(helper.markdown.to_html(tree), '<div class="table-scroll">\n<hr>\n</div>')
end

g.test_the_class_of_a_wrap_is_escaped_too = function()
    t.assert_equals(
        helper.markdown.to_html({ { kind = 'wrap', class = 'a"b', blocks = {} } }),
        '<div class="a&quot;b">\n</div>'
    )
end
