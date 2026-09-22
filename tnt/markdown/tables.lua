--- Таблицы: шапка, разделитель с выравниванием, строки.
---
---     | Пакет      | Зависит от | Кому нужен |
---     |------------|:----------:|-----------:|
---     | `tnt-fs`   | —          | s3, config |
---
--- Таблицей считается только то, что разбирается целиком: в шапке есть
--- черта, под ней строка-разделитель с чертой, и столбцов в них поровну.
--- Иначе это абзац с чертой внутри, и показать его надо текстом —
--- «таблица без шапки» не должна съедать следующий абзац.
---
--- Выравнивание задаётся двоеточиями в разделителе: `:---` — влево,
--- `---:` — вправо, `:---:` — по центру. В страницу оно уходит
--- стилем ячейки, а не устаревшим атрибутом `align`, которого в HTML5
--- уже нет.
---
--- Строка таблицы кончается пустой строкой или строкой без черты.
--- Ячеек в строке бывает меньше, чем столбцов, — недостающие пустые;
--- лишние отбрасываются. Черта внутри ячейки пишется как `\|`.

local inline = require('tnt.markdown.inline')
local lines = require('tnt.markdown.lines')

local Module = {}

--- Выравнивание, о котором в разделителе ничего не сказано.
Module.NONE = 'none'

--- Байт, которым на время разбиения подменяется экранированная черта:
--- в разметке страницы его не бывает.
local GUARD = '\1'

--- Черта, которой разгорожена строка таблицы.
local PIPE = '|'

--- Есть ли в строке черта: без неё это не таблица вовсе.
---@param line string
---@return boolean
local function piped(line)
    return line:find(PIPE) ~= nil
end

--- Ячейки строки таблицы.
---@param line string
---@return string[]
local function cells_of(line)
    local body = (lines.trim(line):gsub('^|', ''):gsub('|$', ''))
    local cells = (body:gsub('\\|', GUARD)):split(PIPE)

    for index, cell in ipairs(cells) do
        cells[index] = lines.trim((cell:gsub(GUARD, '|')))
    end

    return cells
end

--- Выравнивание столбца по его ячейке в разделителе.
---@param cell string
---@return string
local function alignment_of(cell)
    local left = cell:startswith(':')
    local right = cell:endswith(':')

    if left and right then
        return 'center'
    end

    if left then
        return 'left'
    end

    if right then
        return 'right'
    end

    return Module.NONE
end

--- Выравнивания столбцов по строке-разделителю либо ничего.
---@param line string|nil
---@return string[]|nil
local function alignments(line)
    if line == nil or not piped(line) then
        return nil
    end

    local align = {}

    for _, cell in ipairs(cells_of(line)) do
        local dashes = (cell:gsub('^:', ''):gsub(':$', ''))

        if dashes == '' or dashes ~= ('-'):rep(#dashes) then
            return nil
        end

        table.insert(align, alignment_of(cell))
    end

    return align
end

--- Разобранные ячейки строки, подогнанные под число столбцов.
---@param cells string[]
---@param count integer
---@param options TntMarkdownSettings
---@return table[][]
local function row_of(cells, count, options)
    local row = {}

    for index = 1, count do
        table.insert(row, inline.parse(cells[index] or '', options))
    end

    return row
end

--- Таблица, начатая этой строкой.
---@param source string[]
---@param index integer
---@param context table
---@return table|nil node, integer|nil after
function Module.parse(source, index, context)
    local header = source[index] --[[@as string]]

    if not piped(header) then
        return nil
    end

    local align = alignments(source[index + 1])

    if align == nil then
        return nil
    end

    local head = cells_of(header)

    -- Столбцов в шапке и в разделителе обязано быть поровну.
    if #head ~= #align then
        return nil
    end

    local rows = {}
    local at = index + 2

    while at <= #source do
        local line = source[at] --[[@as string]]

        -- Таблица кончается пустой строкой или строкой без черты.
        if lines.blank(line) or not piped(line) then
            break
        end

        table.insert(rows, row_of(cells_of(line), #align, context.options))
        at = at + 1
    end

    return { kind = 'table', align = align, head = row_of(head, #align, context.options), rows = rows }, at
end

return Module
