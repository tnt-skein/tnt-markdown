--- Конвейер преобразований: дерево до страницы правят списком шагов.
---
--- Страница документации получается не одним разбором. Заголовку нужен
--- якорь и ссылка на себя, цитате с маркером — вид врезки, таблице —
--- обёртка, которая прокручивается на узком экране, а заголовок страницы
--- из содержимого убирается, потому что его рисует шапка. Каждое такое
--- дело — отдельный шаг «дерево → дерево», и порядок шагов задаёт список:
--- набор пакета берётся `default`, а приложение собирает свой и дописывает
--- в него что угодно своё.
---
--- Шаги правят дерево, а не готовую страницу. У дерева есть и другие
--- читатели — оглавление и указатель поиска, — и якорь, поставленный
--- в дереве, виден всем троим сразу. Правка страницы строкой этого
--- не даёт: она не знает ни вложенности, ни того, что уже экранировано.
---
--- Вглубь обход идёт **до** шага, а не после: узел, который шаг только
--- что завёл, обходить нельзя. Обёртка таблицы иначе снова встретила бы
--- в себе таблицу и оборачивалась бы без конца, пока не кончится стек.

local fail = require('tnt.must.fail')
local types = require('tnt.must.types')

local anchor = require('tnt.markdown.anchor')
local callout = require('tnt.markdown.callout')
local link = require('tnt.markdown.link')
local plain = require('tnt.markdown.plain')

local Module = {}

--- Класс обёртки, которая прокручивается по горизонтали. Прокрутка —
--- оформление, и задаёт её приложение; пакет называет место, где она
--- нужна, а не пишет стиль.
Module.TABLE_CLASS = 'table-scroll'

--- Обходит дерево вглубь и заменяет каждый узел тем, что вернул шаг.
---
--- Шаг, вернувший `nil`, убирает узел из дерева; вернувший тот же узел —
--- оставляет его на месте.
---@param blocks table[]
---@param visit fun(node: table): table|nil
---@return table[]
function Module.walk(blocks, visit)
    local kept = {}

    for _, node in ipairs(blocks) do
        if node.blocks ~= nil then
            node.blocks = Module.walk(node.blocks, visit)
        end

        if node.items ~= nil then
            for _, item in ipairs(node.items) do
                item.blocks = Module.walk(item.blocks, visit)
            end
        end

        local changed = visit(node)

        if changed ~= nil then
            table.insert(kept, changed)
        end
    end

    return kept
end

--- Якоря заголовкам: `id` у h2–h4 и ссылка на себя в странице.
---
--- Идут только заголовки верхнего уровня: раздел страницы бывает только
--- им, а заголовок внутри цитаты или пункта списка — часть примера,
--- и в колонке оглавления ему не место.
---@param blocks table[]
---@return table[]
function Module.anchors(blocks)
    local taken = {}

    for _, node in ipairs(blocks) do
        if node.kind == 'heading' and anchor.leveled(node.level) then
            node.anchor = anchor.take(taken, plain.inline(node.inline))
        end
    end

    return blocks
end

--- Врезки: цитата с маркером становится блоком со своим видом.
---@param blocks table[]
---@return table[]
function Module.callouts(blocks)
    return Module.walk(blocks, function(node)
        return callout.of(node) or node
    end)
end

--- Таблицы в обёртке: на узком экране она прокручивается, а страница
--- не разъезжается по ширине.
---@param blocks table[]
---@return table[]
function Module.table_scroll(blocks)
    return Module.walk(blocks, function(node)
        if node.kind ~= 'table' then
            return node
        end

        return { kind = 'wrap', class = Module.TABLE_CLASS, blocks = { node } }
    end)
end

--- Первый заголовок страницы: его рисует шапка, и в содержимом он лишний.
---
--- Убирается только заголовок, стоящий первым блоком: страница, начатая
--- абзацем, ничего не теряет, а «первый заголовок где-то посреди текста»
--- значил бы, что содержимое пропадает неизвестно откуда.
---@param blocks table[]
---@return table[]
function Module.without_first_heading(blocks)
    local first = blocks[1]

    if first ~= nil and first.kind == 'heading' then
        table.remove(blocks, 1)
    end

    return blocks
end

--- Переводит адреса ссылок одного списка вкраплений правилом приложения.
---
--- Внутрь идёт по полю `inline` у любого узла, а не по списку родов:
--- ссылка стоит и в выделении, и в подписи, и в узле, который завело
--- преобразование приложения, и забытый род молча оставил бы ссылку
--- на `.md` посреди страницы сайта.
---@param nodes table[]
---@param rewrite fun(href: string): string|nil
local function relink(nodes, rewrite)
    for _, node in ipairs(nodes) do
        if node.kind == 'link' then
            local href = rewrite(node.href)

            if href ~= nil then
                -- Правило пишет приложение, и бросок назван целиком, без
                -- места: строка внутри пакета ему ничего не скажет.
                local complaint = types.string(href, 'адрес от перевода ссылок')

                if complaint ~= nil then
                    fail.raise(complaint)
                end

                node.href = link.safe(href)
            end
        end

        if node.inline ~= nil then
            relink(node.inline, rewrite)
        end
    end
end

--- Переводит адреса ссылок в ячейках одной строки таблицы.
---@param cells table[][]
---@param rewrite fun(href: string): string|nil
local function relink_cells(cells, rewrite)
    for _, cell in ipairs(cells) do
        relink(cell, rewrite)
    end
end

--- Шаг, который переводит адреса ссылок правилом приложения.
---
--- Во что превратить ссылку на соседний документ, знает приложение: адреса
--- сайта — его. Пакет знает другое — где в дереве лежат ссылки: в абзацах
--- и заголовках, в ячейках таблиц, внутри выделения, — и обходит их сам,
--- чтобы приложению не повторять у себя форму дерева.
---
--- Правило получает адрес и отдаёт новый; `nil` оставляет адрес как был.
--- Новый адрес проходит тот же запрет схем, что и написанный в разметке.
---@param rewrite fun(href: string): string|nil
---@return fun(blocks: table[]): table[]
function Module.links(rewrite)
    return function(blocks)
        return Module.walk(blocks, function(node)
            if node.inline ~= nil then
                relink(node.inline, rewrite)
            end

            if node.head ~= nil then
                relink_cells(node.head, rewrite)

                for _, row in ipairs(node.rows) do
                    relink_cells(row, rewrite)
                end
            end

            return node
        end)
    end
end

--- Набор преобразований пакета — тот, без которого раздела документации
--- не собрать.
---
--- Список новый на каждый вызов: в него дописывают своё, и общий на всех
--- однажды унёс бы чужой шаг в другое приложение.
---@return (fun(blocks: table[]): table[])[]
function Module.default()
    return { Module.anchors, Module.callouts, Module.table_scroll }
end

--- Прогоняет дерево через список преобразований.
---@param blocks table[]
---@param pipeline (fun(blocks: table[]): table[])[]
---@return table[]
function Module.apply(blocks, pipeline)
    for index, step in ipairs(pipeline) do
        local changed = step(blocks)

        -- Шаг обязан вернуть дерево. Шаг, вернувший ничего, ронял бы
        -- разбор внутри следующего шага, и человек искал бы поломку
        -- не там, где она есть; бросок без места назван целиком:
        -- шаг писало приложение, и строка внутри пакета ему не скажет.
        local complaint = types.array(changed, ('дерево от преобразования %d'):format(index))

        if complaint ~= nil then
            fail.raise(complaint)
        end

        blocks = changed
    end

    return blocks
end

return Module
