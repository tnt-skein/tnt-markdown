--- Блоки документа: заголовки, абзацы, цитаты, разделители — и всё, что
--- разбирают соседние модули.
---
--- Разбор идёт по строкам сверху вниз. Каждую непустую строку по очереди
--- предлагают разборщикам блоков, и первый, кто её узнал, забирает и её,
--- и столько следующих, сколько ему нужно. Строка, которую не узнал
--- никто, — строка абзаца; пустая строка абзац кончает.
---
--- Кода отступом (четыре пробела) пакет не знает нарочно: у нас код
--- пишется оградами, а продолжение пункта списка с отступом иначе
--- молча превращалось бы в код. Отступ перед блоком поэтому ни на что
--- не влияет.
---
--- Заголовков, подчёркнутых снизу (`===` и `---` строкой ниже), тоже нет:
--- строка из трёх дефисов у нас всегда разделитель, и ею разделены
--- разделы доброй половины документов.
---
--- Вложенность идёт вглубь не дальше предела: цитата в цитате и список
--- в списке разбираются вызовом того же разбора, и глубина вложенности —
--- это глубина стека. Документ из десятков тысяч знаков «>» подряд ронял
--- бы разбор переполнением, а пакет обещает не бросать: за пределом
--- вложенность кончается и строки читаются текстом.

local must = require('tnt.must')

local fence = require('tnt.markdown.fence')
local inline = require('tnt.markdown.inline')
local lines = require('tnt.markdown.lines')
local list = require('tnt.markdown.list')
local tables = require('tnt.markdown.tables')

local Module = {}

--- Сколько решёток бывает у заголовка.
Module.MAX_LEVEL = 6

--- Из скольких знаков складывается разделитель.
Module.RULE_MIN = 3

--- Сколько уровней вложенности разбирается. В наших документах вглубь
--- идут на три-четыре уровня, и запас тут велик нарочно: предел стоит
--- против переполнения стека, а не против вложенности как таковой.
Module.MAX_DEPTH = 32

--- Строка цитаты: «>» и не больше одного пробела за ним.
local QUOTED = '^ *>%s?(.*)$'

--- Заголовок: решётка, сколько угодно решёток за ней и текст.
local HASHES = '^ *(##*)(.*)$'

--- Решётки-украшение в конце заголовка. Пробел перед ними обязателен,
--- иначе «C#» лишилось бы решётки, а самих решёток довольно и одной.
local DECORATION = '^(.-)%s+##*$'

--- Абзац без пробелов в конце: переносить их уже некуда.
local WITHOUT_TAIL_SPACES = '^(.-)%s*$'

--- Заголовок: решётки и текст за ними.
---@param source string[]
---@param index integer
---@param context table
---@return table|nil node, integer|nil after
local function heading(source, index, context)
    local line = source[index] --[[@as string]]
    local hashes, rest = line:match(HASHES)

    if hashes == nil or #hashes > Module.MAX_LEVEL then
        return nil
    end

    ---@cast rest string

    -- За решётками обязан стоять пробел: «#хэштег» — это текст.
    if rest ~= '' and rest:find('^%s') == nil then
        return nil
    end

    local text = lines.trim(rest)

    -- Решётки в конце — украшение, а не текст заголовка.
    local titled = text:match(DECORATION) or text

    return { kind = 'heading', level = #hashes, inline = inline.parse(titled, context.options) }, index + 1
end

--- Разделитель: три одинаковых знака и больше, между ними пробелы.
---@param source string[]
---@param index integer
---@return table|nil node, integer|nil after
local function rule(source, index)
    local line = source[index] --[[@as string]]
    local char = line:match('^ *([-*_])')

    if char == nil then
        return nil
    end

    local body = (line:gsub('%s', ''))

    if #body < Module.RULE_MIN or body ~= char:rep(#body) then
        return nil
    end

    return { kind = 'rule' }, index + 1
end

--- Цитата: строки со знаком «>» в начале.
---@param source string[]
---@param index integer
---@param context table
---@return table|nil node, integer|nil after
local function quote(source, index, context)
    local first = (source[index] --[[@as string]]):match(QUOTED)

    if first == nil then
        return nil
    end

    local collected = { first }
    local at = index + 1

    while at <= #source do
        local text = (source[at] --[[@as string]]):match(QUOTED)

        if text == nil then
            break
        end

        table.insert(collected, text)
        at = at + 1
    end

    return { kind = 'quote', blocks = Module.inner(collected, context) }, at
end

--- Сырой HTML блоком: строки до пустой. Только с `allow_html`.
---@param source string[]
---@param index integer
---@param context table
---@return table|nil node, integer|nil after
local function raw_html(source, index, context)
    local line = source[index] --[[@as string]]

    if not context.options.allow_html or line:find('^ *<') == nil then
        return nil
    end

    local collected = {}
    local at = index

    while
        at <= #source and not lines.blank(source[at] --[[@as string]])
    do
        table.insert(collected, source[at])
        at = at + 1
    end

    return { kind = 'html', text = table.concat(collected, '\n') }, at
end

--- Разборщики блоков по очереди: первый, кто узнал строку, её и берёт.
---
--- Порядок важен дважды. Ограда идёт первой: внутри неё разметки нет.
--- Разделитель — раньше списка: «---» и «***» иначе стали бы пунктами.
local STARTERS = { fence.parse, heading, rule, quote, list.parse, tables.parse, raw_html }

--- Блок, начатый этой строкой, либо ничего.
---@param source string[]
---@param index integer
---@param context table
---@param in_paragraph boolean Идёт ли сейчас абзац
---@return table|nil node, integer|nil after
local function dispatch(source, index, context, in_paragraph)
    -- Глубже предела вложенности нет вовсе: строка читается текстом,
    -- а не уводит разбор ещё на уровень вниз.
    if context.depth >= Module.MAX_DEPTH then
        return nil
    end

    for _, starter in ipairs(STARTERS) do
        local node, after = starter(source, index, context, in_paragraph)

        if node ~= nil then
            return node, after
        end
    end

    return nil
end

--- Разбирает строки в блоки.
---@param source string[]
---@param context table Настройки и разбор блоков для вложенных частей
---@return table[]
function Module.parse(source, context)
    local blocks = {}
    local pending = {}

    local function flush()
        if #pending == 0 then
            return
        end

        -- Пробелы в конце последней строки абзаца ничего не значат:
        -- переносить их уже некуда.
        local text = table.concat(pending, '\n'):match(WITHOUT_TAIL_SPACES) --[[@as string]]

        table.insert(blocks, { kind = 'paragraph', inline = inline.parse(text, context.options) })

        pending = {}
    end

    local index = 1

    while index <= #source do
        local line = source[index] --[[@as string]]

        if lines.blank(line) then
            flush()
            index = index + 1
        else
            local node, after = dispatch(source, index, context, #pending > 0)

            if node == nil then
                table.insert(pending, lines.trim_left(line))
                index = index + 1
            else
                flush()
                table.insert(blocks, node)

                -- Разборщик обязан сдвинуть место вперёд. Место,
                -- оставшееся на месте, закольцевало бы разбор и подвесило
                -- узел, а подвешенный узел не показывает ни страницы,
                -- ни поломки: об ошибке лучше узнать броском.
                index = must.greater_than(after, 'место за блоком', index)
            end
        end
    end

    flush()

    return blocks
end

--- Разбор вложенного содержимого: тот же самый, но уровнем глубже.
---
--- Зовут его и цитата, и пункт списка; пункт — через поле контекста,
--- потому что разбор блоков знает о списках, а списки о нём знать
--- не должны.
---@param source string[]
---@param context table
---@return table[]
function Module.inner(source, context)
    local deeper = { options = context.options, inner = Module.inner, depth = context.depth + 1 }

    return Module.parse(source, deeper)
end

--- Дерево блоков документа.
---@param source string[]
---@param options TntMarkdownSettings
---@return table[]
function Module.document(source, options)
    return Module.parse(source, { options = options, inner = Module.inner, depth = 0 })
end

return Module
