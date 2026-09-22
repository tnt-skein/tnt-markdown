--- Плашки: цитата, начатая маркером, — врезка со своим видом.
---
---     > **Примечание.** Пул при ошибке в теле выбрасывает соединение.
---
---     > [!WARNING]
---     > POST не повторяется никогда.
---
--- Маркер пишется двояко нарочно. Жирное слово в начале цитаты читается
--- и в самом файле разметки, и в любом чужом показе markdown; скобочная
--- метка короче и не требует знать язык документа. Оба сводятся к одному
--- виду: `note`, `warning`, `tip`.
---
--- Вид уходит в страницу классом, а нарисовать врезку — заголовок, цвет,
--- значок — дело приложения: пакет не знает ни его цветов, ни его
--- значков, а вид у врезки один и тот же в любом оформлении.
---
--- Сам маркер из содержимого убирается: он сказал всё, что должен был,
--- видом. Подпись «Примечание» приложение рисует по классу — тогда она
--- одинакова у всех врезок страницы и переводится вместе с оформлением,
--- а не берётся из того, как её написал автор.
---
--- Цитата без маркера остаётся цитатой: врезкой становится только то,
--- что названо врезкой явно.

local utf8 = require('utf8')

local lines = require('tnt.markdown.lines')
local plain = require('tnt.markdown.plain')

local Module = {}

--- Скобочная метка в начале абзаца и всё, что за ней. Слово внутри
--- скобок ничем не ограничено: годное проверяет таблица видов, а образец
--- «одни буквы» отличался бы от «любого слова» только на записи `[!]`,
--- где и тот и другой метки не находят.
local BRACKETED = '^%[!(.-)%](.*)$'

--- Точка в конце маркера: «Примечание.» и «Примечание» — один маркер.
local TAIL_DOT = '%.$'

--- Текст без пробелов в начале.
local LEADING_SPACE = '^%s*(.*)$'

--- Узлы, которые в начале врезки ничего не значат: перенос строки сразу
--- за маркером — часть записи, а не пустая строка врезки.
---@type table<string, boolean>
local BREAKS = { ['break'] = true, softbreak = true }

--- Какой вид у какого маркера. Ключ — слово маркера строчными буквами
--- и без точки, поэтому русское слово и скобочная метка приходят
--- в одну и ту же таблицу.
local VIEWS = {
    ['примечание'] = 'note',
    ['важно'] = 'note',
    ['note'] = 'note',
    ['important'] = 'note',
    ['осторожно'] = 'warning',
    ['внимание'] = 'warning',
    ['warning'] = 'warning',
    ['caution'] = 'warning',
    ['совет'] = 'tip',
    ['tip'] = 'tip',
}

--- Слово маркера, приведённое к ключу таблицы видов.
---@param text string
---@return string
local function keyed(text)
    return (utf8.lower(lines.trim(text)):gsub(TAIL_DOT, ''))
end

--- Узлы, начиная с названного места.
---@param nodes table[]
---@param from integer
---@return table[]
local function tail_of(nodes, from)
    local rest = {}

    for index = from, #nodes do
        table.insert(rest, nodes[index])
    end

    return rest
end

--- Те же узлы без пробелов и переносов в начале.
---
--- За маркером стоит пробел или перенос строки, и без этого они остались
--- бы в начале первого абзаца врезки — там, где автор ничего не писал.
---@param nodes table[]
---@return table[]
local function without_leading_space(nodes)
    while nodes[1] ~= nil do
        local first = nodes[1]

        if BREAKS[first.kind] then
            table.remove(nodes, 1)
        elseif first.kind ~= 'text' then
            return nodes
        else
            local text = first.text:match(LEADING_SPACE) --[[@as string]]

            if text ~= '' then
                nodes[1] = { kind = 'text', text = text }

                return nodes
            end

            table.remove(nodes, 1)
        end
    end

    return nodes
end

--- Маркер в начале первого абзаца цитаты.
---
--- Вид и остаток абзаца отдаются одной таблицей, а не парой: остаток
--- без вида ничего не значит, и вернуть его рядом с `nil` значило бы
--- завести значение, которого никто не читает.
---@param nodes table[]
---@return { view: string, rest: table[] }|nil
local function marker_of(nodes)
    local first = nodes[1]

    if first == nil then
        return nil
    end

    -- Жирное слово — маркер целым узлом, и текст врезки начинается
    -- со следующего узла.
    if first.kind == 'strong' then
        local view = VIEWS[keyed(plain.inline(first.inline))]

        if view == nil then
            return nil
        end

        return { view = view, rest = tail_of(nodes, 2) }
    end

    if first.kind ~= 'text' then
        return nil
    end

    local label, rest = first.text:match(BRACKETED)

    if label == nil then
        return nil
    end

    local view = VIEWS[
        keyed(label --[[@as string]])
    ]

    if view == nil then
        return nil
    end

    -- Скобочная метка стоит внутри текстового узла, и на его место
    -- становится остаток той же строки.
    local nodes_after = tail_of(nodes, 2)

    table.insert(nodes_after, 1, {
        kind = 'text',
        text = rest --[[@as string]],
    })

    return { view = view, rest = nodes_after }
end

--- Врезка из цитаты либо ничего, если маркера в ней нет.
---@param node table
---@return table|nil
function Module.of(node)
    if node.kind ~= 'quote' then
        return nil
    end

    local first = node.blocks[1]

    -- Маркер стоит в начале текста, а цитата, начатая списком или
    -- оградой кода, врезкой не объявлялась.
    if first == nil or first.kind ~= 'paragraph' then
        return nil
    end

    local marker = marker_of(first.inline)

    if marker == nil then
        return nil
    end

    local body = without_leading_space(marker.rest)
    local blocks = {}

    -- Абзац из одного маркера в содержимое не идёт: у записи в две
    -- строки весь текст врезки лежит ниже.
    if body[1] ~= nil then
        table.insert(blocks, { kind = 'paragraph', inline = body })
    end

    for index = 2, #node.blocks do
        table.insert(blocks, node.blocks[index])
    end

    return { kind = 'callout', view = marker.view, blocks = blocks }
end

return Module
