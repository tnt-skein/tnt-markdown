--- Проверки конвейера: обход дерева, сами преобразования, порядок шагов.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.modify')

---@return any
local function modify()
    return helper.part('modify')
end

--- Дерево разметки без преобразований — вход любого шага.
---@param source string
---@return table[]
local function tree_of(source)
    return helper.parse(source)
end

-- ── Обход дерева ─────────────────────────────────────────────────────

g.test_the_walk_replaces_every_node_the_step_returns = function()
    local seen = {}
    local kept = modify().walk(tree_of('# раз\n\nдва'), function(node)
        table.insert(seen, node.kind)

        return node
    end)

    t.assert_equals(seen, { 'heading', 'paragraph' })
    t.assert_equals(#kept, 2)
end

g.test_the_walk_goes_into_a_quote_and_into_the_items_of_a_list = function()
    local seen = {}

    modify().walk(tree_of('> цитата\n\n- пункт\n- другой'), function(node)
        table.insert(seen, node.kind)

        return node
    end)

    -- Вглубь обход идёт до самого узла: содержимое цитаты и пунктов
    -- встречается раньше, чем они сами.
    t.assert_equals(seen, { 'paragraph', 'quote', 'paragraph', 'paragraph', 'list' })
end

g.test_a_step_that_returns_nothing_takes_the_node_out = function()
    local kept = modify().walk(tree_of('# раз\n\nдва\n\n---'), function(node)
        if node.kind == 'rule' then
            return nil
        end

        return node
    end)

    t.assert_equals(#kept, 2)
    t.assert_equals(kept[1].kind, 'heading')
    t.assert_equals(kept[2].kind, 'paragraph')
end

g.test_the_node_a_step_has_just_made_is_not_walked_again = function()
    -- Обёртка таблицы иначе снова встретила бы в себе таблицу
    -- и оборачивалась бы, пока не кончится стек.
    local wrapped = 0
    local kept = modify().walk(tree_of('| раз |\n|---|'), function(node)
        if node.kind ~= 'table' then
            return node
        end

        wrapped = wrapped + 1

        return { kind = 'wrap', class = 'раз', blocks = { node } }
    end)

    t.assert_equals(wrapped, 1)
    t.assert_equals(kept[1].kind, 'wrap')
    t.assert_equals(kept[1].blocks[1].kind, 'table')
end

-- ── Якоря ────────────────────────────────────────────────────────────

g.test_anchors_go_to_the_headings_of_the_second_third_and_fourth_level = function()
    local kept =
        modify().anchors(tree_of('# один\n\n## два\n\n### три\n\n#### четыре\n\n##### пять'))

    t.assert_equals(kept[1].anchor, nil)
    t.assert_equals(kept[2].anchor, 'два')
    t.assert_equals(kept[3].anchor, 'три')
    t.assert_equals(kept[4].anchor, 'четыре')
    t.assert_equals(kept[5].anchor, nil)
end

g.test_the_anchor_is_taken_from_the_text_of_the_heading_without_markup = function()
    local kept = modify().anchors(tree_of('## **Плашки** и `код`'))

    t.assert_equals(kept[1].anchor, 'плашки-и-код')
end

g.test_a_repeated_heading_of_a_page_gets_a_number = function()
    local kept = modify().anchors(tree_of('## Раздел\n\n## Раздел\n\n### Раздел'))

    t.assert_equals(kept[1].anchor, 'раздел')
    t.assert_equals(kept[2].anchor, 'раздел-2')
    t.assert_equals(kept[3].anchor, 'раздел-3')
end

g.test_a_heading_inside_a_quote_is_a_part_of_the_example = function()
    -- Раздел страницы бывает только верхним уровнем: заголовок внутри
    -- цитаты в колонку оглавления не попадает, и якоря ему не нужно.
    local kept = modify().anchors(tree_of('> ## внутри цитаты'))

    t.assert_equals(kept[1].blocks[1].anchor, nil)
end

-- ── Врезки ───────────────────────────────────────────────────────────

g.test_callouts_turn_a_marked_quote_into_a_callout = function()
    local kept = modify().callouts(tree_of('> **Примечание.** Текст.\n\n> Обычная цитата.'))

    t.assert_equals(kept[1].kind, 'callout')
    t.assert_equals(kept[1].view, 'note')
    t.assert_equals(kept[2].kind, 'quote')
end

g.test_a_callout_inside_a_quote_is_found_too = function()
    local kept = modify().callouts(tree_of('> цитата\n>\n> > [!WARNING]\n> > Осторожно.'))

    t.assert_equals(kept[1].kind, 'quote')
    t.assert_equals(kept[1].blocks[2].kind, 'callout')
    t.assert_equals(kept[1].blocks[2].view, 'warning')
end

-- ── Обёртка таблиц ───────────────────────────────────────────────────

g.test_a_table_goes_into_a_wrap_with_the_class_of_the_package = function()
    local kept = modify().table_scroll(tree_of('| раз |\n|---|\n| два |'))

    t.assert_equals(kept[1].kind, 'wrap')
    t.assert_equals(kept[1].class, 'table-scroll')
    t.assert_equals(kept[1].class, modify().TABLE_CLASS)
    t.assert_equals(kept[1].blocks[1].kind, 'table')
end

g.test_a_table_inside_a_list_item_is_wrapped_too = function()
    local kept = modify().table_scroll(tree_of('- пункт\n\n  | раз |\n  |---|'))

    t.assert_equals(kept[1].items[1].blocks[2].kind, 'wrap')
end

g.test_everything_but_a_table_stays_as_it_is = function()
    local kept = modify().table_scroll(tree_of('абзац\n\n---'))

    t.assert_equals(kept[1].kind, 'paragraph')
    t.assert_equals(kept[2].kind, 'rule')
end

-- ── Первый заголовок ─────────────────────────────────────────────────

g.test_the_first_heading_of_a_page_goes_away = function()
    local kept = modify().without_first_heading(tree_of('# Заголовок\n\nабзац\n\n## Раздел'))

    t.assert_equals(#kept, 2)
    t.assert_equals(kept[1].kind, 'paragraph')
    t.assert_equals(kept[2].kind, 'heading')
end

g.test_a_page_that_starts_not_with_a_heading_loses_nothing = function()
    local kept = modify().without_first_heading(tree_of('абзац\n\n# Заголовок'))

    t.assert_equals(#kept, 2)
    t.assert_equals(kept[1].kind, 'paragraph')
    t.assert_equals(kept[2].kind, 'heading')
end

g.test_a_page_of_one_heading_becomes_empty = function()
    t.assert_equals(modify().without_first_heading(tree_of('# Заголовок')), {})
end

g.test_an_empty_tree_survives_the_step = function()
    t.assert_equals(modify().without_first_heading({}), {})
end

-- ── Список шагов ─────────────────────────────────────────────────────

g.test_the_set_of_the_package_holds_anchors_callouts_and_the_wrap = function()
    local pipeline = modify().default()

    t.assert_equals(pipeline, { modify().anchors, modify().callouts, modify().table_scroll })
end

g.test_the_set_is_a_new_list_every_time = function()
    -- Общий на всех список однажды унёс бы чужой шаг в другое приложение.
    local pipeline = modify().default()

    table.insert(pipeline, modify().without_first_heading)

    t.assert_equals(#modify().default(), 3)
    t.assert_equals(#pipeline, 4)
end

g.test_the_steps_go_in_the_order_of_the_list = function()
    local order = {}

    --- Шаг, который называет себя и отдаёт дерево как есть.
    ---@param name string
    ---@return fun(blocks: table[]): table[]
    local function step(name)
        return function(blocks)
            table.insert(order, name)

            return blocks
        end
    end

    local kept = modify().apply(tree_of('абзац'), { step('первый'), step('второй') })

    t.assert_equals(order, { 'первый', 'второй' })
    t.assert_equals(kept[1].kind, 'paragraph')
end

g.test_an_empty_list_leaves_the_tree_as_it_is = function()
    local tree = tree_of('абзац')

    t.assert_equals(modify().apply(tree, {}), tree)
end

g.test_a_step_that_returns_no_tree_is_named_by_its_place_in_the_list = function()
    local function silent()
        return nil
    end

    local _, err = pcall(modify().apply, tree_of('абзац'), { modify().anchors, silent })

    t.assert_equals(err, 'дерево от преобразования 2 — массив, а не nil')

    local _, other = pcall(modify().apply, tree_of('абзац'), {
        function()
            return 'страница'
        end,
    })

    t.assert_equals(other, 'дерево от преобразования 1 — массив, а не строка')
end

-- ── Перевод ссылок ───────────────────────────────────────────────────

--- Правило приложения: ссылка на соседний документ уходит в адрес
--- сайта, прочие остаются как были.
---@param href string
---@return string|nil
local function to_site(href)
    local name, rest = href:match('^([%w_-]+)%.md(.*)$')

    if name == nil then
        return nil
    end

    return '/docs/' .. name .. rest
end

--- Страница разметки после одного шага перевода ссылок.
---@param source string
---@param rewrite (fun(href: string): any)|nil Правило; без него — `to_site`
---@return string
local function relinked(source, rewrite)
    local step = modify().links(rewrite or to_site)

    return helper.markdown.to_html(step(tree_of(source)))
end

g.test_a_link_takes_the_address_the_rule_of_the_application_gives = function()
    t.assert_equals(
        relinked('См. [маршруты](router.md#параметры) и [узел](https://tarantool.io).'),
        '<p>См. <a href="/docs/router#параметры">маршруты</a>'
            .. ' и <a href="https://tarantool.io">узел</a>.</p>'
    )
end

g.test_links_are_found_in_headings_emphasis_lists_quotes_and_tables = function()
    local page = relinked(table.concat({
        '## Про [кэш](cache.md)',
        '',
        '**жирный [раз](one.md)** и *курсив [два](two.md)*',
        '',
        '- пункт [три](three.md)',
        '',
        '> цитата [четыре](four.md)',
        '',
        '| [шапка](head.md) | вторая |',
        '|---|---|',
        '| [ячейка](cell.md) | [соседка](next.md) |',
    }, '\n'))

    for _, name in ipairs({ 'cache', 'one', 'two', 'three', 'four', 'head', 'cell', 'next' }) do
        t.assert_str_contains(page, ('href="/docs/%s"'):format(name))
    end

    t.assert_not_str_contains(page, '.md"')
end

g.test_a_picture_keeps_its_address = function()
    local seen = {}

    local page = relinked('![схема](scheme.md) и [раз](one.md)', function(href)
        table.insert(seen, href)

        return to_site(href)
    end)

    t.assert_equals(seen, { 'one.md' })
    t.assert_equals(page, '<p><img src="scheme.md" alt="схема"> и <a href="/docs/one">раз</a></p>')
end

g.test_the_new_address_passes_the_same_ban_of_schemes = function()
    t.assert_equals(
        relinked('[клик](one.md)', function()
            return 'java\nscript:alert(1)'
        end),
        '<p><a href="">клик</a></p>'
    )

    -- Невидимые знаки уходят и из нового адреса: браузер выбросил бы их сам.
    t.assert_equals(
        relinked('[раз](one.md)', function()
            return '/docs/\tone'
        end),
        '<p><a href="/docs/one">раз</a></p>'
    )
end

g.test_a_rule_that_gives_not_a_string_is_named_whole = function()
    local _, err = pcall(relinked, '[раз](one.md)', function()
        return 42
    end)

    t.assert_equals(err, 'адрес от перевода ссылок — строка, а не число')
end
