--- Проверки оглавления и разделов: что попадает в колонку и в указатель.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.outline')

---@return any
local function outline()
    return helper.part('outline')
end

-- ── Заголовок страницы ───────────────────────────────────────────────

g.test_the_title_is_the_text_of_the_first_block_when_it_is_a_heading = function()
    t.assert_equals(
        outline().title(helper.parse('# Разбор `markdown`\n\n## Раздел')),
        'Разбор markdown'
    )
    -- Правило то же, что у шага, убирающего заголовок: уровень не важен.
    t.assert_equals(
        outline().title(helper.parse('### Третий уровень\n\nабзац')),
        'Третий уровень'
    )
end

g.test_a_page_that_starts_not_with_a_heading_has_no_title = function()
    t.assert_equals(outline().title(helper.parse('абзац\n\n# Заголовок')), nil)
    t.assert_equals(outline().title({}), nil)
end

-- ── Оглавление ───────────────────────────────────────────────────────

g.test_the_outline_holds_the_headings_of_the_second_third_and_fourth_level = function()
    local tree = helper.modified(
        '# Страница\n\n## Раздел\n\n### Подраздел\n\n#### Глубже\n\n##### Подпись'
    )

    t.assert_equals(outline().of(tree), {
        { level = 2, text = 'Раздел', anchor = 'раздел' },
        { level = 3, text = 'Подраздел', anchor = 'подраздел' },
        { level = 4, text = 'Глубже', anchor = 'глубже' },
    })
end

g.test_the_text_of_a_heading_comes_without_markup = function()
    local tree = helper.modified('## **Плашки** и `код`')

    t.assert_equals(
        outline().of(tree),
        { { level = 2, text = 'Плашки и код', anchor = 'плашки-и-код' } }
    )
end

g.test_a_page_without_headings_has_an_empty_outline = function()
    t.assert_equals(outline().of(helper.modified('просто абзац')), {})
end

g.test_without_the_anchors_step_the_outline_stays_without_anchors = function()
    -- Якорь берётся из дерева, а не считается заново: второго правила
    -- имени у пакета нет.
    local tree = helper.modified('## Раздел', { modify = {} })

    t.assert_equals(outline().of(tree), { { level = 2, text = 'Раздел' } })
end

-- ── Разделы ──────────────────────────────────────────────────────────

g.test_a_section_holds_the_heading_and_the_text_under_it = function()
    local tree = helper.modified('## Раздел\n\nПервый абзац.\n\nВторой абзац.')

    t.assert_equals(outline().sections(tree), {
        {
            level = 2,
            title = 'Раздел',
            anchor = 'раздел',
            text = 'Первый абзац.\nВторой абзац.',
        },
    })
end

g.test_a_section_ends_at_the_next_heading_of_any_level = function()
    -- Текст подраздела в родителя не входит: найденное слово обязано
    -- вести к тому якорю, где оно и написано.
    local tree = helper.modified(
        '## Раздел\n\nТекст раздела.\n\n### Подраздел\n\nТекст подраздела.'
    )

    t.assert_equals(outline().sections(tree), {
        { level = 2, title = 'Раздел', anchor = 'раздел', text = 'Текст раздела.' },
        {
            level = 3,
            title = 'Подраздел',
            anchor = 'подраздел',
            text = 'Текст подраздела.',
        },
    })
end

g.test_the_text_before_the_first_heading_belongs_to_no_section = function()
    local tree = helper.modified('# Страница\n\nВступление.\n\n## Раздел\n\nТекст.')

    t.assert_equals(outline().sections(tree), {
        { level = 2, title = 'Раздел', anchor = 'раздел', text = 'Текст.' },
    })
end

g.test_a_heading_of_another_level_ends_the_section_without_starting_one = function()
    -- Заголовок пятого уровня раздела не заводит, но прежний кончает:
    -- текст под ним принадлежит ему, а не разделу выше.
    local tree =
        helper.modified('## Раздел\n\nСвой текст.\n\n##### Подпись\n\nЧужой текст.')

    t.assert_equals(outline().sections(tree), {
        { level = 2, title = 'Раздел', anchor = 'раздел', text = 'Свой текст.' },
    })
end

g.test_a_section_without_text_holds_an_empty_string = function()
    local tree = helper.modified('## Раздел\n\n## Другой\n\nТекст.')

    t.assert_equals(outline().sections(tree), {
        { level = 2, title = 'Раздел', anchor = 'раздел', text = '' },
        { level = 2, title = 'Другой', anchor = 'другой', text = 'Текст.' },
    })
end

g.test_the_text_of_a_section_holds_code_tables_and_lists = function()
    local source = table.concat({
        '## Раздел',
        '',
        '```lua',
        "local page = markdown.render('# раз')",
        '```',
        '',
        '| Настройка | Умолчание |',
        '|---|---|',
        '| `modify` | набор пакета |',
        '',
        '- пункт списка',
        '',
        '> **Примечание.** Врезка тоже в тексте.',
    }, '\n')

    t.assert_equals(
        outline().sections(helper.modified(source))[1].text,
        table.concat({
            "local page = markdown.render('# раз')\n",
            'Настройка Умолчание',
            'modify набор пакета',
            'пункт списка',
            'Врезка тоже в тексте.',
        }, '\n')
    )
end

g.test_a_page_without_headings_has_no_sections = function()
    t.assert_equals(outline().sections(helper.modified('просто абзац')), {})
end
