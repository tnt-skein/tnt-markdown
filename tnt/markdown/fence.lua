--- Ограда кода: содержимое не разбирается, язык уходит классом.
---
---     ```lua
---     local x = 1
---     ```
---
--- Содержимое ограды — код, и разбирать его нельзя: звёздочка в нём
--- значит умножение, а не выделение. В страницу оно уходит экранированным
--- внутри `<pre><code>`, а первое слово шапки — классом `language-<имя>`:
--- по нему подсветку ставит браузер, а пакету незачем знать ни одного
--- языка.
---
--- Незакрытая ограда кончается вместе с документом. Отказом это не
--- считается: половина страницы, показанная кодом, читается, а отказ
--- не показал бы ничего.

local lines = require('tnt.markdown.lines')

local Module = {}

--- Сколько знаков открывают ограду.
Module.MIN = 3

--- Знаки, которыми бывает ограда.
local BACKTICK = '`'
local TILDE = '~'

--- Образец ограды: отступ, серия знака не короче `MIN` и шапка за ней.
---
--- Длина живёт в самом образце, а не отдельной проверкой: иначе образец
--- и проверка говорили бы об одном и том же двумя способами, и разойтись
--- им ничего бы не мешало.
---@param char string
---@return string
local function pattern_of(char)
    return '^( *)(' .. char:rep(Module.MIN) .. '+)(.*)$'
end

--- Чем ограда бывает и как её узнать.
local FENCES = { [BACKTICK] = pattern_of(BACKTICK), [TILDE] = pattern_of(TILDE) }

--- Открывает ли строка ограду.
---@param line string
---@return { char: string, indent: integer, marker: string, info: string }|nil
local function opening(line)
    for char, pattern in pairs(FENCES) do
        local spaces, marker, info = line:match(pattern)

        if marker ~= nil then
            ---@cast spaces string
            ---@cast info string

            -- В шапке ограды из обратных кавычек самой кавычки быть
            -- не может: иначе строка `а``б` в тексте открывала бы ограду
            -- до конца документа.
            local own = char == BACKTICK and info:match(BACKTICK) ~= nil

            if not own then
                return { char = char, indent = #spaces, marker = marker, info = lines.trim(info) }
            end
        end
    end

    return nil
end

--- Закрывает ли строка эту ограду: та же серия, не короче, и ничего сверх.
---@param line string
---@param open { char: string, marker: string }
---@return boolean
local function closes(line, open)
    local body = lines.trim(line)

    return #body >= #open.marker and body == open.char:rep(#body)
end

--- Язык из шапки ограды: первое слово либо ничего.
---@param info string
---@return string|nil
local function language_of(info)
    return info:match('^(%S+)')
end

--- Ограда кода, начатая этой строкой.
---@param source string[]
---@param index integer
---@return table|nil block, integer|nil after
function Module.parse(source, index)
    local open = opening(source[index] --[[@as string]])

    if open == nil then
        return nil
    end

    local collected = {}
    local at = index + 1

    -- Строка считается прочитанной до решения о ней: так место за оградой
    -- одно и то же и у закрытой, и у кончившейся вместе с документом.
    while at <= #source do
        local line = source[at] --[[@as string]]

        at = at + 1

        if closes(line, open) then
            break
        end

        -- Ограда, записанная с отступом, снимает его и с содержимого:
        -- отступ принадлежит разметке, а не коду.
        table.insert(collected, lines.strip(line, open.indent) .. '\n')
    end

    return { kind = 'code', language = language_of(open.info), text = table.concat(collected) }, at
end

return Module
