--- Настройки разбора: предел размера, сырой HTML и конвейер.
---
--- Две настройки — про безопасность. `max_size` держит потолок входа:
--- разбор строит дерево в памяти, и мегабайтный документ разворачивается
--- в неё целиком — предел отказывает раньше, чем узел начнёт задыхаться.
--- `allow_html` решает судьбу сырого HTML во входе: по умолчанию он
--- экранируется и виден на странице как текст. Умолчание названо вслух
--- нарочно — правило «в страницу уходит только то, что собрали мы»
--- простое и проверяемое, а разметку пишут не всегда свои.
---
--- Третья — про то, чем дерево правят до страницы. `modify` — список
--- преобразований, и умолчание у него не пустое: без якорей, врезок
--- и обёртки таблиц раздела документации не собрать. Свой список
--- отменяет умолчание целиком, потому что порядок шагов — тоже решение
--- вызывающего: пустой список даёт голый разбор, каким он был до
--- конвейера.

local must = require('tnt.must')

local modify = require('tnt.markdown.modify')

local Module = {}

--- Предел входа по умолчанию, байт.
Module.MAX_SIZE = 1024 * 1024

--- Настройки, которые пакет знает.
local KNOWN = { allow_html = '?boolean', max_size = '?integer', modify = { '?array_of', 'callable' } }

--- Уровень вины: строка того, кто позвал фасад.
local owner = must.at(3)

---@class TntMarkdownSettings Настройки разбора
---@field allow_html boolean Пускать ли сырой HTML в страницу
---@field max_size integer Предел размера разметки, байт
---@field modify (fun(blocks: table[]): table[])[] Преобразования дерева по порядку

--- Настройки с подставленными умолчаниями.
---@param options table|nil
---@return TntMarkdownSettings
function Module.normalize(options)
    if options == nil then
        return { allow_html = false, max_size = Module.MAX_SIZE, modify = modify.default() }
    end

    owner.options(options, 'настройки', KNOWN)

    local max_size = options.max_size or Module.MAX_SIZE

    owner.positive(max_size, 'настройки.max_size')

    return {
        allow_html = options.allow_html == true,
        max_size = max_size,
        modify = options.modify or modify.default(),
    }
end

return Module
