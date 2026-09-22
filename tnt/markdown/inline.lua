--- Разметка внутри строки: код, выделение, ссылки, переносы.
---
---     **жирный**, *курсив*, `код`, [ссылка](адрес), ![картинка](адрес)
---
--- Разбор идёт слева направо и никогда не отказывает: знак, за которым
--- не нашлось пары, остаётся собой. Незакрытая звёздочка — это
--- звёздочка, а не поломка страницы.
---
--- Три правила, которые стоит знать.
---
--- **Код разбирается первым.** Всё внутри обратных кавычек — текст:
--- `*` в нём значит умножение, а `<имя>` — образец, а не тег.
---
--- **Выделение считается сериями.** Серия из одного знака — курсив,
--- из двух — жирный, из трёх и больше — просто знаки. Закрывает серию
--- только серия ровно такой же длины, поэтому `**жирный с *курсивом*
--- внутри**` разбирается вложенно, а `**` без пары остаётся текстом.
---
--- **Подчёркивание не работает внутри слова.** `имя_поля_таблицы`
--- остаётся собой: знак вне ASCII при этом считается частью слова,
--- иначе русское слово с подчёркиванием разъезжалось бы на курсив.
--- У звёздочки такого правила нет — ею выделяют и часть слова.
---
--- Ссылки в ссылке не бывает: внутри текста ссылки ни `[…](…)`,
--- ни автоссылка, ни голый адрес ссылкой не становятся. Иначе
--- `[https://узел](https://узел)` — запись, которой полон любой
--- документ, — давала бы вложенный `<a>` внутри `<a>`, чего браузер
--- не примет.

local must = require('tnt.must')

local lines = require('tnt.markdown.lines')
local link = require('tnt.markdown.link')

local Module = {}

--- Сколько пробелов в конце строки значат жёсткий перенос.
Module.HARD_BREAK = 2

--- Знаки, с которых может начаться вкрапление. Буква «h» — начало
--- голого адреса, и разбирается он тоже здесь.
local SPECIAL = '[\\`*_%[!<\nh]'

--- Серия знака: образец у каждого свой, и звёздочка в нём пишется через
--- «%» — сама по себе она значит повтор.
local RUNS = { ['*'] = '%*+', ['_'] = '_+', ['`'] = '`+' }

--- Та же серия, привязанная к месту. Образец один на два дела: без
--- привязки им ищется следующая серия, с привязкой — читается та,
--- что под рукой; два разных образца однажды разошлись бы.
local ANCHORED = {}

for char, run in pairs(RUNS) do
    ANCHORED[char] = '^' .. run
end

--- Подчёркивание: у него своё правило про середину слова.
local UNDERSCORE = '_'

--- Что значит серия такой длины; длиннее — просто знаки.
local WIDTHS = { [1] = 'emphasis', [2] = 'strong' }

--- Содержимое кода без пары пробелов по краям.
---
--- Пробелы нужны, когда сам код начинается или кончается кавычкой:
--- `` ` `` иначе не записать. Код из одних пробелов остаётся как есть.
---@param code string
---@return string
local function tidy(code)
    local joined = (code:gsub('\n', ' '))
    local stripped = joined:match('^ (.*) $')

    if stripped ~= nil and stripped:find('%S') ~= nil then
        return stripped
    end

    return joined
end

--- Место следующей серии ровно такой же длины, которую принял судья.
---@param text string
---@param from integer
---@param char string
---@param width integer
---@param accepts fun(at: integer, run: string): boolean
---@return integer|nil
local function run_after(text, from, char, width, accepts)
    local search = from

    -- Предела обхода нет нарочно: за краем строки серия не находится,
    -- и поиск кончается сам.
    while true do
        local found = text:find(RUNS[char] --[[@as string]], search)

        if found == nil then
            return nil
        end

        local run = text:match(ANCHORED[char] --[[@as string]], found) --[[@as string]]

        if #run == width and accepts(found, run) then
            return found
        end

        search = found + #run
    end
end

--- Открывает ли серия выделение: за ней стоит не пробел, а подчёркивание
--- к тому же не приходится на середину слова.
---@param text string
---@param at integer
---@param char string
---@param run string
---@return boolean
local function opens(text, at, char, run)
    local following = lines.char_at(text, at + #run)

    return following ~= ''
        and following:find('%s') == nil
        and (char ~= UNDERSCORE or not lines.wordy(lines.char_before(text, at)))
end

--- Закрывает ли серия выделение: перед ней стоит не пробел, а после
--- подчёркивания не начинается слово.
---@param text string
---@param at integer
---@param char string
---@param run string
---@return boolean
local function closes(text, at, char, run)
    return lines.char_before(text, at):find('%s') == nil
        and (char ~= UNDERSCORE or not lines.wordy(lines.char_at(text, at + #run)))
end

--- Код в обратных кавычках.
---
--- Серия кавычек не делится: у серии, которой не нашлось пары, текстом
--- остаётся вся серия целиком, а не первая её кавычка. Иначе внутри
--- «```x`» нашлась бы пара из второй и третьей кавычки, и код взялся бы
--- там, где его не писали.
---@param text string
---@param at integer
---@return table|nil node, integer after
local function code_span(text, at)
    local open = text:match(ANCHORED['`'] --[[@as string]], at) --[[@as string]]
    local from = at + #open
    local close_at = run_after(text, from, '`', #open, function()
        return true
    end)

    if close_at == nil then
        return nil, from
    end

    return { kind = 'code', text = tidy(text:sub(from, close_at - 1)) }, close_at + #open
end

--- Выделение: серия знаков вокруг куска разметки.
---@param text string
---@param at integer
---@param options TntMarkdownSettings
---@param parse fun(text: string, options: TntMarkdownSettings, linked: boolean|nil): table[]
---@param linked boolean|nil Идёт ли разбор внутри ссылки
---@return table|nil node, integer|nil after
local function emphasis(text, at, options, parse, linked)
    local char = text:sub(at, at)
    local run = text:match(ANCHORED[char] --[[@as string]], at) --[[@as string]]
    local kind = WIDTHS[#run]

    if kind == nil or not opens(text, at, char, run) then
        return nil
    end

    local from = at + #run
    local close_at = run_after(text, from, char, #run, function(found, other)
        return closes(text, found, char, other)
    end)

    if close_at == nil then
        return nil
    end

    return { kind = kind, inline = parse(text:sub(from, close_at - 1), options, linked) }, close_at + #run
end

--- Экранированный знак: обратная косая черта и знак препинания за ней.
--- Она же перед концом строки — жёсткий перенос.
---@param text string
---@param at integer
---@return table|nil node, integer|nil after
local function escaped(text, at)
    local following = text:sub(at + 1, at + 1)

    if following == '\n' then
        return { kind = 'break' }, at + 2
    end

    if following:find('%p') == nil then
        return nil
    end

    return { kind = 'text', text = following }, at + 2
end

--- Знаки, с которых начинается ссылка: внутри ссылки их разбирать
--- нельзя, и они остаются текстом.
local LINKING = { ['['] = true, ['<'] = true, ['h'] = true }

--- Кто разбирает вкрапление, начатое этим знаком.
local HANDLERS = {
    ['\\'] = escaped,
    ['`'] = code_span,
    ['*'] = emphasis,
    ['_'] = emphasis,
    ['['] = link.link,
    ['!'] = link.image,
    ['<'] = link.angle,
    ['h'] = link.bare,
}

--- Каким переносом кончилась строка.
---
--- Пробелы в конце строки значения не имеют — кроме того случая, когда
--- их два и больше: так пишут перенос, который обязан остаться
--- переносом. Сами они в текст не идут.
---@param plain string[] Накопленный текст; хвостовые пробелы снимаются
---@return string
local function break_kind(plain)
    local last = #plain
    local tail = plain[last] or ''
    local trimmed = tail:match('^(.-) *$') --[[@as string]]

    plain[last] = trimmed

    if #tail - #trimmed >= Module.HARD_BREAK then
        return 'break'
    end

    return 'softbreak'
end

--- Разбирает разметку внутри строки.
---@param text string
---@param options TntMarkdownSettings
---@param linked boolean|nil Идёт ли разбор внутри ссылки
---@return table[]
function Module.parse(text, options, linked)
    local nodes = {}
    local plain = {}

    -- Накопленное отдаётся узлом, только если в нём есть что показать:
    -- пустая строка копится перед каждым вкраплением, и узел из неё
    -- засорял бы дерево тем, чего в разметке не было.
    local function flush()
        local collected = table.concat(plain)

        plain = {}

        if collected ~= '' then
            table.insert(nodes, { kind = 'text', text = collected })
        end
    end

    local pos = 1

    while pos <= #text do
        local at = text:find(SPECIAL, pos)

        if at == nil then
            table.insert(plain, text:sub(pos))
            break
        end

        table.insert(plain, text:sub(pos, at - 1))

        local char = text:sub(at, at)
        local node, after

        if char == '\n' then
            node, after = { kind = break_kind(plain) }, at + 1
        elseif not (linked and LINKING[char]) then
            local handler = HANDLERS[char] --[[@as fun(...): table|nil, integer|nil]]

            node, after = handler(text, at, options, Module.parse, linked)
        end

        -- Место за вкраплением разборщик называет всегда: и когда
        -- разобрал, и когда остаток остаётся текстом. Назад оно
        -- не смотрит: место, не ушедшее вперёд, закольцевало бы разбор
        -- и подвесило узел, а об ошибке лучше узнать броском.
        local next_pos = must.greater_than(after or (at + 1), 'место за вкраплением', at) --[[@as integer]]

        if node == nil then
            table.insert(plain, text:sub(at, next_pos - 1))
        else
            flush()
            table.insert(nodes, node)
        end

        pos = next_pos
    end

    flush()

    return nodes
end

return Module
