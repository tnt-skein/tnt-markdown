--- Списки: простые, нумерованные, с вложенностью.
---
---     - раз
---     - два
---       - вложенный: отступ под содержимое пункта
---
---     1. первый
---     2. второй
---
--- Содержимое пункта начинается там, где начался его текст, и продолжение
--- пишется с тем же отступом. Строка без отступа пункт кончает: «ленивого»
--- продолжения, при котором строка без отступа всё равно считается частью
--- пункта, пакет не знает — зато и не гадает, чьё это содержимое.
---
--- Между знаком и текстом обязан стоять пробел: «-текст» — это текст.
---
--- Список бывает плотным и просторным. Пустая строка внутри списка или
--- между пунктами делает его просторным, и тогда каждый пункт
--- показывается абзацем; без неё содержимое пункта идёт как есть.
---
--- Нумерованный список начинается с того номера, который написан:
--- `start` попадает в `<ol start="…">`. Смена знака начинает новый
--- список: `-` и `*` подряд — это два списка, а не один.

local lines = require('tnt.markdown.lines')

local Module = {}

--- Номер, с которого нумерованный список начинается сам собой.
Module.FIRST = 1

--- Пункт простого списка: отступ, знак, остаток строки.
local BULLET = '^( *)([-*+])(.*)$'

--- Пункт нумерованного: отступ, число, знак за ним, остаток строки.
local ORDERED = '^( *)(%d+)([.)])(.*)$'

--- Пункт, начатый этой строкой.
---@param line string
---@return table|nil
local function item_at(line)
    local spaces, marker, rest = line:match(BULLET)
    local family = marker
    local number = nil

    if marker == nil then
        local digits, delimiter

        spaces, digits, delimiter, rest = line:match(ORDERED)

        if delimiter == nil then
            return nil
        end

        ---@cast digits string
        marker = digits .. delimiter
        family = delimiter
        number = tonumber(digits)
    end

    ---@cast spaces string
    ---@cast rest string
    local gap, text = rest:match('^( *)(.*)$')

    -- Между знаком и текстом обязан стоять пробел; пункт без текста
    -- вовсе — пустой пункт, и это законно.
    if gap == '' and text ~= '' then
        return nil
    end

    return {
        family = family,
        indent = #spaces,
        number = number,
        ordered = number ~= nil,
        text = text,
        width = #spaces + #marker + #gap,
    }
end

--- Может ли такой пункт начать список прямо посреди абзаца.
---
--- Простой — да, если в пункте есть текст. Нумерованный — только
--- с первого номера: строка абзаца, начатая с «3008.» или «200.», — это
--- номер кода, перенесённый на новую строку, а не начало списка. Так
--- написано в наших же документах, и без этого правила они разъезжаются.
---@param item table
---@return boolean
local function interrupts(item)
    return item.text ~= '' and (not item.ordered or item.number == Module.FIRST)
end

--- Строки содержимого пункта, снятые до его отступа.
---@param source string[]
---@param index integer
---@param item table
---@return string[] content, integer after, boolean trailing, boolean spaced
local function content_of(source, index, item)
    local content = { item.text }
    local at = index + 1
    local trailing = false
    local spaced = false

    while at <= #source do
        local line = source[at] --[[@as string]]
        local blank = lines.blank(line)

        -- Строка со своим отступом принадлежит пункту, пустая — тоже;
        -- строка без отступа пункт кончает.
        if not blank and lines.indent_of(line) < item.width then
            break
        end

        -- Содержимое сразу после пустой строки делает список просторным,
        -- а сама пустая строка в конце пункта — только разделитель перед
        -- следующим, и решает её судьбу разбор списка, а не пункта.
        spaced = spaced or (trailing and not blank)
        trailing = blank

        table.insert(content, lines.strip(line, item.width))

        at = at + 1
    end

    return content, at, trailing, spaced
end

--- Список, начатый этой строкой.
---@param source string[]
---@param index integer
---@param context table
---@param in_paragraph boolean|nil Идёт ли сейчас абзац
---@return table|nil node, integer|nil after
function Module.parse(source, index, context, in_paragraph)
    local first = item_at(source[index] --[[@as string]])

    if first == nil or (in_paragraph and not interrupts(first)) then
        return nil
    end

    local items = {}
    local loose = false
    local blank = false
    local at = index

    while at <= #source do
        local item = item_at(source[at] --[[@as string]])

        -- Смена знака начинает новый список, а вложенный пункт сюда
        -- не доходит: его забирает содержимое пункта выше.
        if item == nil or item.family ~= first.family then
            break
        end

        local content, after, trailing, spaced = content_of(source, at, item)

        loose = loose or blank or spaced
        blank = trailing
        at = after

        table.insert(items, { blocks = context.inner(content, context) })
    end

    return { kind = 'list', items = items, ordered = first.ordered, start = first.number, tight = not loose }, at
end

return Module
