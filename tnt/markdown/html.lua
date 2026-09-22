--- Дерево блоков в HTML.
---
--- Разметка разбирается один раз, а рисуется отсюда: у дерева есть и
--- другие читатели — оглавление, указатель поиска, преобразования, — и
--- ни один из них не должен разбирать текст заново.
---
--- Правило вывода одно и держится всюду: **текст экранируется**. Текст
--- абзаца, содержимое ограды, адрес ссылки и подпись уходят в страницу
--- сущностями, и `<b>` во входе остаётся `<b>` на экране. Не
--- экранируется только то, что пакет собрал сам: сами теги и класс языка,
--- у которого экранировано имя.
---
--- Блоки разделены переводом строки, и вложенные — тоже: так страницу
--- можно прочитать глазами, а проверка сравнивает её целиком, а не
--- «где-то там есть тег».
---
--- Кто рисует узел, решает его род: две таблицы «род — рисовальщик»
--- вместо цепочки условий. Род, которого в таблице нет, — ошибка того,
--- кто собрал дерево руками, и она называется вслух.
---
--- Что пришло из конвейера преобразований, рисуется тут же и классом:
--- якорь заголовка — `id` и ссылка на себя, вид врезки — класс, обёртка —
--- `div` со своим классом. Оформление — цвет врезки, значок ссылки,
--- прокрутка обёртки — остаётся приложению: пакет называет, что это
--- за место, а не как оно выглядит.

local escape = require('tnt.markdown.escape')
local fail = require('tnt.must.fail')
local list = require('tnt.markdown.list')
local plain = require('tnt.markdown.plain')

local Module = {}

--- Класс ссылки, которой заголовок ссылается на себя, и её подпись для
--- чтеца. Сама ссылка пуста: знак, значок и то, видна ли она до наведения
--- мыши, рисует приложение по классу. Без подписи чтец прочёл бы её
--- как «ссылка» и ничего больше, а с `aria-hidden` она осталась бы
--- в обходе табуляцией, но без имени.
local ANCHOR_CLASS = 'anchor'
local ANCHOR_LABEL = 'Ссылка на этот раздел'

--- Класс врезки: общий и по виду. Общий несёт оформление всех врезок
--- сразу, второй — только цвет и значок своего вида.
local CALLOUT_CLASS = 'callout'

--- Стиль ячейки по выравниванию столбца. Выравнивание в HTML5 задаётся
--- стилем: атрибута `align` у ячейки больше нет.
local STYLES = {
    left = ' style="text-align: left"',
    center = ' style="text-align: center"',
    right = ' style="text-align: right"',
}

--- Объявлены заранее: рисовальщики зовут друг друга через род узла.
---@type fun(node: table, options: TntMarkdownSettings): string
local block_html
---@type fun(nodes: table[], options: TntMarkdownSettings): string
local inline_html

--- Кто рисует узел этого рода.
---
--- Чужой род — ошибка того, кто собрал дерево руками: разбор таких
--- не делает. Бросок без места: сообщение читает человек, а место внутри
--- пакета ему ничего не скажет.
---@param registry table<string, function>
---@param node table
---@param name string Как назвать узел в отказе
---@return function
local function renderer_of(registry, node, name)
    local render = registry[node.kind]

    if render == nil then
        fail.raise(('%s разметки «%s» пакету незнаком'):format(name, tostring(node.kind)))
    end

    return render
end

--- Открывающий тег, содержимое и закрывающий — каждый со своей строки.
---@param open string
---@param body string
---@param close string
---@return string
local function wrapped(open, body, close)
    if body == '' then
        return open .. '\n' .. close
    end

    return open .. '\n' .. body .. '\n' .. close
end

--- Подпись ссылки либо пусто.
---@param title string|nil
---@return string
local function titled(title)
    if title == nil then
        return ''
    end

    return ' title="' .. escape.html(title) .. '"'
end

--- Кто рисует вкрапление каждого рода.
local INLINES = {
    text = function(node)
        return escape.html(node.text)
    end,

    code = function(node)
        return '<code>' .. escape.html(node.text) .. '</code>'
    end,

    strong = function(node, options)
        return '<strong>' .. inline_html(node.inline, options) .. '</strong>'
    end,

    emphasis = function(node, options)
        return '<em>' .. inline_html(node.inline, options) .. '</em>'
    end,

    link = function(node, options)
        local body = inline_html(node.inline, options)

        return ('<a href="%s"%s>%s</a>'):format(escape.html(node.href), titled(node.title), body)
    end,

    image = function(node)
        local alt = escape.html(plain.inline(node.inline))

        return ('<img src="%s" alt="%s"%s>'):format(escape.html(node.src), alt, titled(node.title))
    end,

    ['break'] = function()
        return '<br>\n'
    end,

    softbreak = function()
        return '\n'
    end,

    html = function(node)
        return node.text
    end,
}

inline_html = function(nodes, options)
    local parts = {}

    for _, node in ipairs(nodes) do
        table.insert(parts, renderer_of(INLINES, node, 'узел')(node, options))
    end

    return table.concat(parts)
end

--- Содержимое пункта: в плотном списке абзац идёт без обёртки.
---@param item table
---@param tight boolean
---@param options TntMarkdownSettings
---@return string
local function item_html(item, tight, options)
    local parts = {}

    for _, block in ipairs(item.blocks) do
        if tight and block.kind == 'paragraph' then
            table.insert(parts, inline_html(block.inline, options))
        else
            table.insert(parts, block_html(block, options))
        end
    end

    local body = table.concat(parts, '\n')

    if tight then
        return '<li>' .. body .. '</li>'
    end

    return wrapped('<li>', body, '</li>')
end

--- Строка таблицы: ячейки одного рода со своим выравниванием.
---@param cells table[][]
---@param align string[]
---@param tag string th либо td
---@param options TntMarkdownSettings
---@return string
local function row_html(cells, align, tag, options)
    local parts = { '<tr>' }

    for index, cell in ipairs(cells) do
        local style = STYLES[align[index]] or ''

        table.insert(parts, ('<%s%s>%s</%s>'):format(tag, style, inline_html(cell, options), tag))
    end

    table.insert(parts, '</tr>')

    return table.concat(parts, '\n')
end

--- Кто рисует блок каждого рода.
local BLOCKS = {
    paragraph = function(node, options)
        return '<p>' .. inline_html(node.inline, options) .. '</p>'
    end,

    heading = function(node, options)
        local body = inline_html(node.inline, options)

        if node.anchor == nil then
            return ('<h%d>%s</h%d>'):format(node.level, body, node.level)
        end

        local id = escape.html(node.anchor)
        local link = ('<a class="%s" href="#%s" aria-label="%s"></a>'):format(ANCHOR_CLASS, id, ANCHOR_LABEL)

        return ('<h%d id="%s">%s%s</h%d>'):format(node.level, id, body, link, node.level)
    end,

    code = function(node)
        local class = ''

        if node.language ~= nil then
            class = ' class="language-' .. escape.html(node.language) .. '"'
        end

        return '<pre><code' .. class .. '>' .. escape.html(node.text) .. '</code></pre>'
    end,

    rule = function()
        return '<hr>'
    end,

    html = function(node)
        return node.text
    end,

    quote = function(node, options)
        return wrapped('<blockquote>', Module.render(node.blocks, options), '</blockquote>')
    end,

    callout = function(node, options)
        local open = ('<aside class="%s %s-%s">'):format(CALLOUT_CLASS, CALLOUT_CLASS, escape.html(node.view))

        return wrapped(open, Module.render(node.blocks, options), '</aside>')
    end,

    wrap = function(node, options)
        local open = ('<div class="%s">'):format(escape.html(node.class))

        return wrapped(open, Module.render(node.blocks, options), '</div>')
    end,

    list = function(node, options)
        local parts = {}

        for _, item in ipairs(node.items) do
            table.insert(parts, item_html(item, node.tight, options))
        end

        local body = table.concat(parts, '\n')

        if not node.ordered then
            return wrapped('<ul>', body, '</ul>')
        end

        -- Номер начала пишется только тогда, когда он не первый: иначе
        -- у каждого списка страницы висел бы start="1".
        local open = '<ol>'

        if node.start ~= list.FIRST then
            open = ('<ol start="%d">'):format(node.start)
        end

        return wrapped(open, body, '</ol>')
    end,

    table = function(node, options)
        local parts = { '<table>', '<thead>', row_html(node.head, node.align, 'th', options), '</thead>', '<tbody>' }

        for _, row in ipairs(node.rows) do
            table.insert(parts, row_html(row, node.align, 'td', options))
        end

        table.insert(parts, '</tbody>')
        table.insert(parts, '</table>')

        return table.concat(parts, '\n')
    end,
}

block_html = function(node, options)
    return renderer_of(BLOCKS, node, 'блок')(node, options)
end

--- Рисует дерево блоков.
---@param blocks table[]
---@param options TntMarkdownSettings
---@return string
function Module.render(blocks, options)
    local parts = {}

    for _, block in ipairs(blocks) do
        table.insert(parts, block_html(block, options))
    end

    return table.concat(parts, '\n')
end

return Module
