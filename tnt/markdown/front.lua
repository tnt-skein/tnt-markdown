--- Шапка документа: пары «ключ: значение» перед разметкой.
---
--- Страница знает о себе больше, чем видно в тексте: заголовок для
--- оглавления, порядок в разделе, дата. Такие сведения пишутся шапкой
--- в начале файла, между двумя чертами, и в страницу не попадают.
---
---     ---
---     title: Установка
---     weight: 10
---     ---
---
---     # Установка
---
--- Шапкой считается только то, что разбирается целиком: первая строка —
--- черта, ниже есть вторая, а между ними одни пары и пустые строки.
--- Иначе черта в начале документа остаётся разделителем, каким её
--- и писали, — документ, начатый с `---` и заголовка, не должен терять
--- начало.
---
--- Значение остаётся строкой: парные кавычки снимаются, и на этом всё.
--- Угадывать числа и `true` пакет не берётся — что значит `weight: 10`
--- для страницы, знает приложение, а не разбор разметки.

local lines = require('tnt.markdown.lines')

local Module = {}

--- Черта, которой открывается и закрывается шапка.
Module.FENCE = '---'

--- Пара: ключ — слово, значение — остаток строки.
local PAIR = '^([%w][%w_.-]*)%s*:%s*(.*)$'

--- Значение без парных кавычек.
---@param value string
---@return string
local function unquoted(value)
    return value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
end

--- Черта ли это.
---@param line string
---@return boolean
local function fenced(line)
    return lines.trim(line) == Module.FENCE
end

--- Шапка документа и строки самой разметки.
---@param source string[]
---@return table<string, string> meta, string[] body
function Module.split(source)
    local first = source[1]

    if first == nil or not fenced(first) then
        return {}, source
    end

    local meta = {}
    local index = 2

    while index <= #source do
        local line = source[index] --[[@as string]]

        if fenced(line) then
            return meta, lines.tail(source, index + 1)
        end

        local key, value = line:match(PAIR)

        if key ~= nil then
            ---@cast value string
            meta[key] = unquoted(lines.trim(value))
        elseif not lines.blank(line) then
            -- Строка, которая не пара, — значит, это не шапка вовсе.
            return {}, source
        end

        index = index + 1
    end

    -- Закрывающей черты нет: первая была разделителем.
    return {}, source
end

return Module
