--- Проверки врезок: маркеры, виды, содержимое без маркера.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.callout')

---@return any
local function callout()
    return helper.part('callout')
end

--- Врезка из первой цитаты разметки либо ничего.
---@param source string
---@return any
local function of(source)
    return callout().of(helper.parse(source)[1])
end

--- Вид врезки из первой цитаты разметки.
---@param source string
---@return string|nil
local function view_of(source)
    local node = of(source)

    if node == nil then
        return nil
    end

    return node.view
end

-- ── Маркеры ──────────────────────────────────────────────────────────

g.test_a_bold_russian_word_names_the_view = function()
    t.assert_equals(view_of('> **Примечание.** Текст.'), 'note')
    t.assert_equals(view_of('> **Важно.** Текст.'), 'note')
    t.assert_equals(view_of('> **Осторожно.** Текст.'), 'warning')
    t.assert_equals(view_of('> **Внимание.** Текст.'), 'warning')
    t.assert_equals(view_of('> **Совет.** Текст.'), 'tip')
end

g.test_a_bracketed_label_names_the_same_views = function()
    t.assert_equals(view_of('> [!NOTE]\n> Текст.'), 'note')
    t.assert_equals(view_of('> [!IMPORTANT]\n> Текст.'), 'note')
    t.assert_equals(view_of('> [!WARNING]\n> Текст.'), 'warning')
    t.assert_equals(view_of('> [!CAUTION]\n> Текст.'), 'warning')
    t.assert_equals(view_of('> [!TIP]\n> Текст.'), 'tip')
end

g.test_the_marker_is_read_without_case_and_without_the_dot = function()
    t.assert_equals(view_of('> **ПРИМЕЧАНИЕ** Текст.'), 'note')
    t.assert_equals(view_of('> **примечание.** Текст.'), 'note')
    t.assert_equals(view_of('> [!note]\n> Текст.'), 'note')
end

g.test_a_word_that_is_not_a_marker_leaves_the_quote_a_quote = function()
    t.assert_equals(of('> **Проверено отдельно, вручную.** Три находки.'), nil)
    t.assert_equals(of('> [!DANGER]\n> Текст.'), nil)
    t.assert_equals(of('> [!НЕИЗВЕСТНО]\n> Текст.'), nil)
    t.assert_equals(of('> Обычная цитата.'), nil)
    t.assert_equals(of('> *Примечание.* Курсивом маркер не пишется.'), nil)
end

g.test_a_quote_that_starts_not_with_a_paragraph_is_not_a_callout = function()
    t.assert_equals(of('> - пункт\n> - другой'), nil)
    t.assert_equals(of('> ```\n> код\n> ```'), nil)
end

g.test_only_a_quote_becomes_a_callout = function()
    t.assert_equals(of('## Примечание.'), nil)
    t.assert_equals(of('**Примечание.** Абзац, а не цитата.'), nil)
    t.assert_equals(callout().of({ kind = 'quote', blocks = {} }), nil)
    t.assert_equals(callout().of({ kind = 'quote', blocks = { { kind = 'paragraph', inline = {} } } }), nil)
end

-- ── Содержимое врезки ────────────────────────────────────────────────

g.test_the_marker_leaves_the_text_and_the_space_after_it_too = function()
    local node = of('> **Примечание.** Пул выбрасывает соединение.')

    t.assert_equals(node.kind, 'callout')
    t.assert_equals(node.blocks, {
        {
            kind = 'paragraph',
            inline = { { kind = 'text', text = 'Пул выбрасывает соединение.' } },
        },
    })
end

g.test_a_marker_on_a_line_of_its_own_leaves_the_text_below = function()
    local node = of('> [!WARNING]\n> POST не повторяется никогда.')

    t.assert_equals(node.blocks, {
        {
            kind = 'paragraph',
            inline = { { kind = 'text', text = 'POST не повторяется никогда.' } },
        },
    })
end

g.test_a_bold_marker_on_a_line_of_its_own_leaves_the_text_below_too = function()
    local node = of('> **Осторожно.**\n> Строка ниже.')

    t.assert_equals(node.blocks, {
        { kind = 'paragraph', inline = { { kind = 'text', text = 'Строка ниже.' } } },
    })
end

g.test_a_hard_break_right_after_the_marker_goes_away_too = function()
    -- Две пробела в конце строки — жёсткий перенос, и в начале врезки
    -- он значил бы пустую строку там, где автор ничего не писал.
    local node = of('> **Примечание.**  \n> Строка ниже.')

    t.assert_equals(node.blocks, {
        { kind = 'paragraph', inline = { { kind = 'text', text = 'Строка ниже.' } } },
    })
end

g.test_a_marker_without_a_space_after_it_starts_the_text_at_once = function()
    local node = of('> **Примечание.**Текст вплотную.')

    t.assert_equals(node.blocks, {
        { kind = 'paragraph', inline = { { kind = 'text', text = 'Текст вплотную.' } } },
    })
end

g.test_markup_right_after_the_marker_starts_the_text_of_the_callout = function()
    -- За маркером пробел, а сразу за ним разметка: пустой текст уходит,
    -- а код остаётся первым узлом врезки.
    local node = of('> **Примечание.** `make quick` перед коммитом.')

    t.assert_equals(node.blocks[1].inline, {
        { kind = 'code', text = 'make quick' },
        { kind = 'text', text = ' перед коммитом.' },
    })
end

g.test_the_markup_after_the_marker_stays_markup = function()
    local node = of('> [!TIP] Берите `make quick` перед коммитом.')

    t.assert_equals(node.blocks, {
        {
            kind = 'paragraph',
            inline = {
                { kind = 'text', text = 'Берите ' },
                { kind = 'code', text = 'make quick' },
                { kind = 'text', text = ' перед коммитом.' },
            },
        },
    })
end

g.test_the_other_blocks_of_the_quote_stay_in_place = function()
    local node = of('> **Совет.** Первый абзац.\n>\n> Второй абзац.\n>\n> - пункт')

    t.assert_equals(#node.blocks, 3)
    t.assert_equals(node.blocks[1].inline, { { kind = 'text', text = 'Первый абзац.' } })
    t.assert_equals(node.blocks[2].inline, { { kind = 'text', text = 'Второй абзац.' } })
    t.assert_equals(node.blocks[3].kind, 'list')
end

g.test_a_quote_of_the_marker_alone_keeps_no_empty_paragraph = function()
    t.assert_equals(of('> [!NOTE]').blocks, {})
    t.assert_equals(of('> **Примечание.**').blocks, {})
    t.assert_equals(of('> **Примечание.**\n>\n> Текст ниже.').blocks, {
        { kind = 'paragraph', inline = { { kind = 'text', text = 'Текст ниже.' } } },
    })
end
