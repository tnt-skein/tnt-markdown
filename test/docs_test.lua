--- Живая проверка на настоящих документах: все `docs/*.md` разбираются,
--- дают страницу с парными тегами, оглавление без повторов и разделы
--- по числу заголовков.
---
--- Двойник тут ничего не показал бы: пакет написан под настоящие
--- документы, и проверка идёт по ним самим — по каждому файлу `docs/`,
--- где заголовки, списки, ограды кода, таблицы и ссылки стоят разом.

local fio = require('fio')
local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.docs')

--- Теги, у которых закрывающей пары не бывает.
local VOID = { hr = true, br = true, img = true }

--- Разметка документа репозитория.
---@param path string
---@return string
local function read(path)
    local file = fio.open(path)
    local source = file:read()

    file:close()

    return source
end

--- Документы репозитория по порядку.
---@return string[]
local function documents()
    local files = fio.glob('docs/*.md')

    table.sort(files)

    -- Пустой список прошёл бы молча, и проверка ничего бы не значила.
    t.assert_gt(#files, 0, 'документов не найдено')

    return files
end

--- Сколько в дереве заголовков тех уровней, что получают якорь.
---@param tree table[]
---@return integer
local function leveled_headings(tree)
    local anchor = helper.part('anchor')
    local count = 0

    for _, node in ipairs(tree) do
        if node.kind == 'heading' and anchor.leveled(node.level) then
            count = count + 1
        end
    end

    return count
end

--- Первая беда в парности тегов страницы либо ничего.
---
--- Сырого `<` в странице не бывает — он ушёл бы сущностью, — поэтому
--- теги ищутся образцом, а не разбором HTML.
---@param page string
---@return string|nil
local function unbalanced(page)
    local stack = {}

    for closing, tag in page:gmatch('<(/?)(%a[%w]*)') do
        if closing == '' then
            if not VOID[tag] then
                table.insert(stack, tag)
            end
        else
            local open = table.remove(stack)

            if open ~= tag then
                return ('</%s> закрывает <%s>'):format(tag, tostring(open))
            end
        end
    end

    if stack[1] ~= nil then
        return ('не закрыт <%s>'):format(stack[#stack])
    end

    return nil
end

g.test_every_document_of_the_repository_is_parsed = function()
    for _, path in ipairs(documents()) do
        local page, meta = helper.markdown.render(read(path))

        t.assert_type(page, 'string', path)
        t.assert_type(meta, 'table', path)
        t.assert_gt(#page, 0, path)
        t.assert_equals(unbalanced(page), nil, path)

        -- Страница не должна нести ни одного сырого знака разметки:
        -- всё, что не тег, ушло сущностями.
        t.assert_equals(page:match('<[^%a/!]'), nil, path)
    end
end

g.test_the_page_of_a_document_holds_what_the_document_holds = function()
    -- Образец — этот же документ пакета: заголовки, списки, таблица,
    -- ограды кода и ссылки в одном файле.
    local page = helper.markdown.render(read('docs/markdown.md'))

    t.assert_str_contains(page, '<h1>')
    t.assert_str_contains(page, '<h2 id="как-пользоваться">')
    t.assert_str_contains(page, '<ul>')
    t.assert_str_contains(page, '<div class="table-scroll">')
    t.assert_str_contains(page, '<table>')
    t.assert_str_contains(page, '<pre><code class="language-lua">')
    t.assert_str_contains(page, '<a href="')
end

g.test_the_anchors_of_a_page_never_repeat_inside_it = function()
    local total = 0

    for _, path in ipairs(documents()) do
        local source = read(path)
        local page = helper.markdown.render(source)
        local taken = {}

        for _, heading in ipairs(helper.markdown.outline(source)) do
            t.assert_type(heading.anchor, 'string', path)
            t.assert_equals(
                taken[heading.anchor],
                nil,
                ('%s: якорь «%s» повторяется'):format(path, heading.anchor)
            )
            taken[heading.anchor] = true

            -- Якорь оглавления обязан найтись в самой странице: колонка
            -- справа иначе уводила бы в пустоту.
            t.assert_str_contains(page, ('<h%d id="%s">'):format(heading.level, heading.anchor), false, path)

            total = total + 1
        end
    end

    -- Документы без заголовков второго уровня бывают, но не все сразу.
    t.assert_gt(total, 0, 'заголовков с якорями не нашлось')
end

g.test_a_section_of_a_page_answers_every_heading_of_the_outline = function()
    local plain = helper.part('plain')

    for _, path in ipairs(documents()) do
        local source = read(path)
        local tree = helper.markdown.parse(source)
        local expected = leveled_headings(tree)
        local sections = helper.markdown.sections(source)

        -- Голый текст всей страницы: текст каждого раздела — его кусок.
        local whole = plain.blocks(tree)

        t.assert_equals(#helper.markdown.outline(source), expected, path)
        t.assert_equals(#sections, expected, path)

        for _, section in ipairs(sections) do
            local place = ('%s: раздел «%s»'):format(path, section.title)

            t.assert_type(section.anchor, 'string', path)

            -- В указатель уходит кусок страницы, а не что-то дорисованное
            -- поверх неё: разметка, теги и якоря в текст не попадают,
            -- потому что их нет и в голом тексте документа.
            if section.text ~= '' then
                t.assert_str_contains(whole, section.text, false, place)
            end
        end
    end
end
