--- Голый текст дерева: подпись картинки и текст для поиска.
---
--- Текст нужен там, где разметку показать нельзя: в атрибуте `alt`
--- у картинки и в куске страницы, по которому строят указатель поиска.
--- Оба случая — один и тот же обход дерева, и второй копии его быть
--- не должно: разойдясь, они дали бы в поиске не то, что видно на
--- странице.
---
--- Узел читается по полям, а не по роду: `inline` — внутрь, `blocks`
--- и `items` — вглубь, `text` — как есть. Поэтому узел, который завело
--- преобразование приложения, попадает и в подпись, и в указатель сам,
--- без правки этого модуля; список родов пришлось бы дописывать на
--- каждое такое преобразование, и забытый род молча выпал бы из поиска.
---
--- Перенос строки значит пробел: слова по обе стороны переноса иначе
--- слиплись бы в одно, и поиск по такому слову не нашёл бы страницы.
--- А блоки разделены переводом строки — по нему приложение режет
--- найденное на куски для показа.

local Module = {}

--- Узлы, которые в тексте значат пробел.
---@type table<string, boolean>
local BREAKS = { ['break'] = true, softbreak = true }

--- Чем разделены блоки в тексте.
local BETWEEN_BLOCKS = '\n'

--- Пробел: им разделены ячейки строки таблицы — ячейка это слово-другое,
--- и перевод строки между ними разорвал бы строку таблицы на куски, —
--- и он же встаёт вместо переноса внутри абзаца.
local SPACE = ' '

--- Объявлен заранее: блок читается вглубь через дерево, а дерево — через
--- блок.
---@type fun(node: table): string
local block_text

--- Голый текст вкраплений: выделение, ссылка и картинка читаются внутрь.
---@param nodes table[]
---@return string
function Module.inline(nodes)
    local parts = {}

    for _, node in ipairs(nodes) do
        if BREAKS[node.kind] then
            table.insert(parts, SPACE)
        elseif node.inline ~= nil then
            table.insert(parts, Module.inline(node.inline))
        elseif node.text ~= nil then
            table.insert(parts, node.text)
        end
    end

    return table.concat(parts)
end

--- Строка таблицы одним куском текста.
---@param cells table[][]
---@return string
local function row_text(cells)
    local parts = {}

    for _, cell in ipairs(cells) do
        table.insert(parts, Module.inline(cell))
    end

    return table.concat(parts, SPACE)
end

--- Таблица: шапка и строки, каждая со своей строки текста.
---@param node table
---@return string
local function table_text(node)
    local parts = { row_text(node.head) }

    for _, row in ipairs(node.rows) do
        table.insert(parts, row_text(row))
    end

    return table.concat(parts, BETWEEN_BLOCKS)
end

--- Голый текст блоков.
---@param blocks table[]
---@return string
function Module.blocks(blocks)
    local parts = {}

    for _, node in ipairs(blocks) do
        local text = block_text(node)

        -- Блок без текста в куске не оставляет следа: пустая строка
        -- между абзацами сдвинула бы место найденного слова.
        if text ~= '' then
            table.insert(parts, text)
        end
    end

    return table.concat(parts, BETWEEN_BLOCKS)
end

--- Голый текст одного блока.
---@param node table
---@return string
block_text = function(node)
    if node.blocks ~= nil then
        return Module.blocks(node.blocks)
    end

    if node.items ~= nil then
        local parts = {}

        for _, item in ipairs(node.items) do
            table.insert(parts, Module.blocks(item.blocks))
        end

        return table.concat(parts, BETWEEN_BLOCKS)
    end

    if node.head ~= nil then
        return table_text(node)
    end

    if node.inline ~= nil then
        return Module.inline(node.inline)
    end

    -- Ограда кода несёт текст сама, а у разделителя текста нет вовсе.
    return node.text or ''
end

return Module
