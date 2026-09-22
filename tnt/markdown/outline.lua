--- Оглавление страницы, её заголовок и разделы для указателя поиска.
---
--- Оба списка читаются из того же дерева, из которого рисуется страница,
--- и якорь берут из него же — тот, что поставил конвейер. Считать якорь
--- заново значило бы завести второе правило имени: разойдясь с первым
--- на одном заголовке, колонка оглавления уводила бы в пустоту, и заметно
--- это стало бы только по жалобе читателя.
---
--- **Оглавление** — заголовки h2–h4 подряд, с уровнем, текстом и якорем:
--- по нему рисуется колонка справа, а вложенность колонка выводит
--- из уровня сама.
---
--- **Раздел** — заголовок и текст под ним до следующего заголовка, какого
--- бы уровня тот ни был. Текст подраздела в родителя поэтому не входит:
--- найденное слово обязано вести к тому якорю, где оно и написано, а не
--- к началу большого раздела, где его придётся искать глазами.
---
--- Текст раздела — голый: без разметки, без тегов, зато с содержимым
--- ограды кода и ячеек таблицы. По документации ищут и имя функции,
--- и строку настройки, и они стоят как раз в примерах и таблицах.

local anchor = require('tnt.markdown.anchor')
local plain = require('tnt.markdown.plain')

local Module = {}

---@class TntMarkdownHeading Заголовок в оглавлении страницы
---@field level integer Уровень заголовка: 2–4
---@field text string Текст заголовка без разметки
---@field anchor string|nil Якорь, поставленный конвейером

---@class TntMarkdownSection Раздел страницы для указателя поиска
---@field level integer Уровень заголовка раздела
---@field title string Заголовок раздела без разметки
---@field anchor string|nil Якорь, поставленный конвейером
---@field text string Текст под заголовком без разметки

--- Заголовок ли это, и такого ли он уровня, чтобы попасть в оглавление.
---@param node table
---@return boolean
local function listed(node)
    return node.kind == 'heading' and anchor.leveled(node.level)
end

--- Оглавление страницы.
---@param blocks table[]
---@return TntMarkdownHeading[]
function Module.of(blocks)
    local headings = {}

    for _, node in ipairs(blocks) do
        if listed(node) then
            table.insert(headings, { level = node.level, text = plain.inline(node.inline), anchor = node.anchor })
        end
    end

    return headings
end

--- Заголовок страницы: голый текст первого блока, если это заголовок.
---
--- Правило то же, что у шага `without_first_heading`: тот убирает
--- заголовок из содержимого, потому что его рисует шапка, а шапке
--- нужен его текст. Разойдись правила — шапка показала бы одно,
--- а из страницы пропало бы другое.
---@param blocks table[]
---@return string|nil
function Module.title(blocks)
    local first = blocks[1]

    if first ~= nil and first.kind == 'heading' then
        return plain.inline(first.inline)
    end

    return nil
end

--- Разделы страницы: заголовок, якорь и текст под ним.
---@param blocks table[]
---@return TntMarkdownSection[]
function Module.sections(blocks)
    local sections = {}
    local body = {}

    ---@type TntMarkdownSection|nil
    local current = nil

    --- Текст, накопленный под заголовком, уходит в его раздел.
    local function close()
        if current ~= nil then
            current.text = plain.blocks(body)
        end

        body = {}
    end

    for _, node in ipairs(blocks) do
        if node.kind == 'heading' then
            close()

            -- Заголовок уровнем выше или ниже нужных раздела не заводит,
            -- но прежний кончает: текст под ним принадлежит ему, а не
            -- разделу выше.
            current = nil

            if listed(node) then
                current = {
                    level = node.level,
                    title = plain.inline(node.inline),
                    anchor = node.anchor,
                    text = '',
                }

                table.insert(sections, current)
            end
        elseif current ~= nil then
            table.insert(body, node)
        end
    end

    close()

    return sections
end

return Module
