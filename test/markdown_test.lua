--- Проверки фасада: разбор, рисование, настройки, отказ по размеру.

local json = require('json')
local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown')

---@return any
local function markdown()
    return helper.markdown
end

g.test_the_page_and_the_tree_come_from_the_same_markup = function()
    local page, meta = markdown().render('# Заголовок')

    t.assert_equals(page, '<h1>Заголовок</h1>')
    t.assert_equals(meta, {})

    local tree = markdown().parse('# Заголовок')

    t.assert_equals(
        tree,
        { { kind = 'heading', level = 1, inline = { { kind = 'text', text = 'Заголовок' } } } }
    )
    t.assert_equals(markdown().to_html(tree), page)
end

g.test_the_tree_is_the_one_the_page_is_drawn_from = function()
    -- Дерево правят и рисуют потом: на нём стоят оглавление, указатель
    -- поиска и преобразования.
    local tree = markdown().parse('# Заголовок\n\nабзац')

    tree[1].level = 2

    t.assert_equals(markdown().to_html(tree), '<h2>Заголовок</h2>\n<p>абзац</p>')
end

g.test_the_head_of_a_document_goes_to_meta = function()
    local page, meta = markdown().render('---\ntitle: Установка\nweight: 10\n---\n\n# Установка')

    t.assert_equals(page, '<h1>Установка</h1>')
    t.assert_equals(meta, { title = 'Установка', weight = '10' })

    local _, same = markdown().parse('---\ntitle: Установка\n---\n')

    t.assert_equals(same, { title = 'Установка' })
end

g.test_markup_larger_than_the_limit_is_a_refusal = function()
    local page, err = markdown().render(('a'):rep(20), { max_size = 19 })

    t.assert_equals(page, nil)
    t.assert_equals(err.kind, markdown().TOO_LARGE)
    t.assert_equals(err.kind, 'too_large')
    t.assert_equals(err.size, 20)
    t.assert_equals(err.limit, 19)
    t.assert_equals(tostring(err), 'разметка больше предела: 20 байт при пределе 19')
    t.assert_equals(
        'причина: ' .. err,
        'причина: разметка больше предела: 20 байт при пределе 19'
    )
    t.assert_equals(
        json.encode(err),
        '"разметка больше предела: 20 байт при пределе 19"'
    )
end

g.test_markup_right_at_the_limit_goes_through = function()
    t.assert_equals(markdown().render(('a'):rep(19), { max_size = 19 }), '<p>' .. ('a'):rep(19) .. '</p>')
end

g.test_the_tree_refuses_by_the_same_limit = function()
    local tree, err = markdown().parse('слишком длинно', { max_size = 5 })

    t.assert_equals(tree, nil)
    t.assert_equals(err.kind, markdown().TOO_LARGE)
end

g.test_the_limit_by_default_is_a_megabyte = function()
    t.assert_equals(markdown().MAX_SIZE, 1048576)
end

g.test_raw_html_is_escaped_until_it_is_allowed = function()
    t.assert_equals(markdown().render('<b>раз</b>'), '<p>&lt;b&gt;раз&lt;/b&gt;</p>')
    t.assert_equals(markdown().render('<b>раз</b>', {}), '<p>&lt;b&gt;раз&lt;/b&gt;</p>')
    t.assert_equals(markdown().render('<b>раз</b>', { allow_html = false }), '<p>&lt;b&gt;раз&lt;/b&gt;</p>')
    t.assert_equals(markdown().render('<b>раз</b>', { allow_html = true }), '<b>раз</b>')
end

g.test_the_settings_of_a_tree_reach_its_page = function()
    local tree = markdown().parse('<b>раз</b>', { allow_html = true })

    t.assert_equals(markdown().to_html(tree, { allow_html = true }), '<b>раз</b>')
end

g.test_a_wrong_argument_blames_the_line_that_called = function()
    helper.assert_blamed(function()
        markdown().render(helper.wrong(42))
    end, 'разметка — строка, а не число')

    helper.assert_blamed(function()
        markdown().parse(helper.wrong(nil))
    end, 'разметка — строка, а не nil')

    helper.assert_blamed(function()
        markdown().to_html(helper.wrong('страница'))
    end, 'дерево блоков — массив, а не строка')
end

g.test_an_unknown_setting_blames_the_line_that_called = function()
    helper.assert_blamed(function()
        markdown().render('текст', helper.wrong({ allow_htm = true }))
    end, 'настройки: ключа «allow_htm» нет, есть allow_html, max_size, modify')

    helper.assert_blamed(function()
        markdown().parse('текст', helper.wrong({ max_size = 0 }))
    end, 'настройки.max_size — число больше 0, а не 0')

    helper.assert_blamed(function()
        markdown().to_html({}, helper.wrong({ max_size = 'много' }))
    end, 'настройки.max_size — целое число, а не строка')

    helper.assert_blamed(function()
        markdown().render('текст', helper.wrong('настройки'))
    end, 'настройки — таблица, а не строка')
end

-- ── Конвейер преобразований ──────────────────────────────────────────

g.test_the_page_comes_through_the_pipeline_of_the_package = function()
    local page =
        markdown().render('## Как пользоваться\n\n> [!NOTE]\n> Врезка.\n\n| раз |\n|---|')

    t.assert_equals(
        page,
        table.concat({
            '<h2 id="как-пользоваться">Как пользоваться'
                .. '<a class="anchor" href="#как-пользоваться" aria-label="Ссылка на этот раздел"></a></h2>',
            '<aside class="callout callout-note">',
            '<p>Врезка.</p>',
            '</aside>',
            '<div class="table-scroll">',
            '<table>',
            '<thead>',
            '<tr>',
            '<th>раз</th>',
            '</tr>',
            '</thead>',
            '<tbody>',
            '</tbody>',
            '</table>',
            '</div>',
        }, '\n')
    )
end

g.test_an_empty_list_of_steps_gives_the_bare_parse = function()
    local source = '## Раздел\n\n> [!NOTE]\n> Врезка.'

    t.assert_equals(
        markdown().render(source, { modify = {} }),
        '<h2>Раздел</h2>\n<blockquote>\n<p>[!NOTE]\nВрезка.</p>\n</blockquote>'
    )
end

g.test_the_tree_of_parse_is_the_one_the_page_is_drawn_from = function()
    -- Конвейер проходит в parse, а to_html рисует уже готовое дерево:
    -- иначе якоря встали бы заново, а обёртка обернулась дважды.
    local source = '## Раздел\n\n| раз |\n|---|'
    local tree = markdown().parse(source)

    t.assert_equals(tree[1].anchor, 'раздел')
    t.assert_equals(tree[2].kind, 'wrap')
    t.assert_equals(markdown().to_html(tree), markdown().render(source))
end

g.test_the_set_of_the_package_is_a_new_list_with_the_three_steps = function()
    local pipeline = markdown().modifications()

    t.assert_equals(pipeline, { markdown().anchors, markdown().callouts, markdown().table_scroll })
    t.assert_equals(markdown().TABLE_CLASS, 'table-scroll')

    table.insert(pipeline, markdown().without_first_heading)

    t.assert_equals(#markdown().modifications(), 3)
end

g.test_an_application_puts_its_own_step_into_the_list = function()
    --- Своё преобразование: разделители со страницы прочь.
    ---@param blocks table[]
    ---@return table[]
    local function without_rules(blocks)
        return markdown().walk(blocks, function(node)
            if node.kind == 'rule' then
                return nil
            end

            return node
        end)
    end

    local pipeline = markdown().modifications()

    table.insert(pipeline, 1, markdown().without_first_heading)
    table.insert(pipeline, without_rules)

    local page = markdown().render('# Страница\n\n---\n\n## Раздел', { modify = pipeline })

    t.assert_equals(
        page,
        '<h2 id="раздел">Раздел<a class="anchor" href="#раздел" aria-label="Ссылка на этот раздел"></a></h2>'
    )
end

-- ── Оглавление и разделы ─────────────────────────────────────────────

g.test_the_outline_and_the_sections_come_with_the_head_of_the_document = function()
    local source =
        '---\ntitle: Установка\n---\n\n# Установка\n\n## Шаги\n\nСначала — `make deps`.'
    local headings, meta = markdown().outline(source)

    t.assert_equals(headings, { { level = 2, text = 'Шаги', anchor = 'шаги' } })
    t.assert_equals(meta, { title = 'Установка' })

    local sections, same = markdown().sections(source)

    t.assert_equals(sections, {
        { level = 2, title = 'Шаги', anchor = 'шаги', text = 'Сначала — make deps.' },
    })
    t.assert_equals(same, { title = 'Установка' })
end

g.test_the_anchor_of_the_outline_is_the_anchor_of_the_page = function()
    local source = '## Раздел\n\nтекст\n\n## Раздел'
    local page = markdown().render(source)

    for _, heading in ipairs(markdown().outline(source)) do
        t.assert_str_contains(page, ('<h%d id="%s">'):format(heading.level, heading.anchor))
    end
end

g.test_the_outline_and_the_sections_refuse_by_the_same_limit = function()
    local headings, err = markdown().outline('слишком длинно', { max_size = 5 })

    t.assert_equals(headings, nil)
    t.assert_equals(err.kind, markdown().TOO_LARGE)

    local sections, other = markdown().sections('слишком длинно', { max_size = 5 })

    t.assert_equals(sections, nil)
    t.assert_equals(other.kind, markdown().TOO_LARGE)
end

g.test_the_outline_and_the_sections_are_read_from_a_tree_too = function()
    local tree = markdown().parse('## Раздел\n\nтекст')

    tree[1].level = 3

    t.assert_equals(markdown().outline_of(tree), { { level = 3, text = 'Раздел', anchor = 'раздел' } })
    t.assert_equals(markdown().sections_of(tree), {
        { level = 3, title = 'Раздел', anchor = 'раздел', text = 'текст' },
    })
end

g.test_a_wrong_argument_of_the_outline_blames_the_line_that_called = function()
    helper.assert_blamed(function()
        markdown().outline(helper.wrong(42))
    end, 'разметка — строка, а не число')

    helper.assert_blamed(function()
        markdown().sections(helper.wrong(nil))
    end, 'разметка — строка, а не nil')

    helper.assert_blamed(function()
        markdown().outline_of(helper.wrong('страница'))
    end, 'дерево блоков — массив, а не строка')

    helper.assert_blamed(function()
        markdown().sections_of(helper.wrong(42))
    end, 'дерево блоков — массив, а не число')
end

g.test_the_links_of_a_page_go_through_the_rule_of_the_application = function()
    local pipeline = markdown().modifications()

    table.insert(
        pipeline,
        markdown().links(function(href)
            return (href:gsub('%.md', '', 1))
        end)
    )

    t.assert_equals(
        markdown().render('## Раздел\n\n[раз](one.md#два)', { modify = pipeline }),
        '<h2 id="раздел">Раздел<a class="anchor" href="#раздел" aria-label="Ссылка на этот раздел"></a></h2>'
            .. '\n<p><a href="one#два">раз</a></p>'
    )
end

g.test_the_title_of_a_page_is_the_heading_the_step_takes_away = function()
    local tree = markdown().parse('# Разбор `markdown`\n\n## Раздел')

    t.assert_equals(markdown().title_of(tree), 'Разбор markdown')
    t.assert_equals(markdown().title_of(markdown().without_first_heading(tree)), 'Раздел')
    t.assert_equals(markdown().title_of(markdown().parse('абзац')), nil)
end

g.test_a_wrong_argument_of_the_links_and_the_title_blames_the_line_that_called = function()
    helper.assert_blamed(
        function()
            markdown().links(helper.wrong('/docs'))
        end,
        'перевод ссылок — функция или вызываемая таблица, а не строка'
    )

    helper.assert_blamed(function()
        markdown().title_of(helper.wrong('страница'))
    end, 'дерево блоков — массив, а не строка')
end

g.test_a_pipeline_that_is_not_a_list_of_steps_blames_the_line_that_called = function()
    helper.assert_blamed(function()
        markdown().render('текст', helper.wrong({ modify = 'якоря' }))
    end, 'настройки.modify — массив, а не строка')

    helper.assert_blamed(
        function()
            markdown().parse('текст', helper.wrong({ modify = { 'якоря' } }))
        end,
        'настройки.modify[1] — функция или вызываемая таблица, а не строка'
    )
end
