--- Строки и знаки разметки: переводы строк, табы, отступы, слова.
---
--- Разбор блоков идёт по строкам, и всё, что зависит от того, как строка
--- записана, собрано здесь. Переводы строк трёх видов (`\n`, `\r\n`, `\r`)
--- сводятся к одному: документ, написанный в Windows, обязан разобраться
--- так же, как написанный в Unix. Табы разворачиваются в четыре пробела
--- везде, а не только в начале строки: отступ решает, чьё это содержимое —
--- пункта списка, ограды или нового блока, — и таб, оставленный собой,
--- считался бы за один пробел.
---
--- Здесь же разбор знаков UTF-8: документы у нас русские, и решения
--- «часть ли это слова» по одному байту не принять.

local utf8 = require('utf8')

local Module = {}

--- Во сколько пробелов разворачивается таб.
Module.TAB = 4

--- Байт продолжения знака UTF-8: у такого старшие биты — 10.
local CONTINUATION = '^[\128-\191]$'

--- Строка без пробелов по краям и она же без пробелов в начале.
local TRIMMED = '^%s*(.-)%s*$'
local TRIMMED_LEFT = '^%s*(.*)$'

--- Строки разметки.
---@param source string
---@return string[]
function Module.split(source)
    local unified = (source:gsub('\r\n?', '\n'))
    local list = (unified:gsub('\t', (' '):rep(Module.TAB))):split('\n')

    -- Перевод строки в конце файла кончает последнюю строку, а не заводит
    -- пустую за ней: иначе у каждого документа появлялся бы лишний
    -- пустой абзац в хвосте.
    if list[#list] == '' then
        table.remove(list)
    end

    return list
end

--- Пустая ли строка: ничего, кроме пробелов.
---@param line string
---@return boolean
function Module.blank(line)
    return line:find('%S') == nil
end

--- Сколько пробелов в начале строки.
---@param line string
---@return integer
function Module.indent_of(line)
    return #line:match('^ *')
end

--- Строка без пробелов по краям.
---@param text string
---@return string
function Module.trim(text)
    return text:match(TRIMMED) --[[@as string]]
end

--- Строка без пробелов в начале.
---@param line string
---@return string
function Module.trim_left(line)
    return line:match(TRIMMED_LEFT) --[[@as string]]
end

--- Снимает отступ, но не больше названной ширины.
---
--- Содержимое пункта списка и ограды кода лежит со своим отступом,
--- и снять надо ровно его: лишние пробелы внутри ограды — часть кода,
--- а не разметки.
---@param line string
---@param width integer
---@return string
function Module.strip(line, width)
    local cut = math.min(Module.indent_of(line), width)

    return line:sub(cut + 1)
end

--- Знак, который кончается перед этим местом, целиком.
---
--- Один байт брать нельзя: у русской буквы их несколько, и последний
--- байт у «л» тот же самый, что у закрывающей ёлочки. Поэтому байты
--- продолжения отматываются назад до ведущего, а за краем строки
--- знака нет вовсе.
---@param text string
---@param at integer Место, перед которым стоит знак
---@return string Знак; в начале строки — пустая строка
function Module.char_before(text, at)
    local first = at - 1

    while text:sub(first, first):find(CONTINUATION) ~= nil do
        first = first - 1
    end

    return text:sub(first, at - 1)
end

--- Знак, который начинается в этом месте, целиком.
---@param text string
---@param at integer Место ведущего байта знака
---@return string Знак; за краем строки — пустая строка
function Module.char_at(text, at)
    local last = at

    while text:sub(last + 1, last + 1):find(CONTINUATION) ~= nil do
        last = last + 1
    end

    return text:sub(at, last)
end

--- Часть ли знак слова.
---
--- Буква и цифра — часть слова, кавычка и тире — нет. У подчёркивания
--- в середине слова выделения нет (`имя_поля` остаётся собой), и решает
--- это как раз эта проверка; кириллица при этом обязана считаться
--- буквами, хотя для стандартной библиотеки её байты не буквы. А вот
--- «_курсив_» в ёлочках курсивом остаться обязан — поэтому знак
--- разбирается целиком, а не по последнему байту, который у буквы
--- и у ёлочки совпадает.
---@param char string Знак целиком; за краем строки — пустая строка
---@return boolean
function Module.wordy(char)
    return utf8.isalpha(char) or utf8.isdigit(char)
end

--- Строки, начиная с названной.
---@param list string[]
---@param from integer
---@return string[]
function Module.tail(list, from)
    local rest = {}

    for index = from, #list do
        table.insert(rest, list[index])
    end

    return rest
end

return Module
