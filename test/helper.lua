--- Общие средства проверок разбора разметки.
---
--- Пакет чистый: ни часов, ни сети, ни `box`, ни состояния, — поэтому
--- ни двойников, ни узла здесь нет. Всё, что нужно проверкам, — исходники
--- мимо `.rocks` и короткая запись «разметка — страница».
---
--- Исходники грузятся с диска, а не через `require`: у Tarantool свой
--- загрузчик `.rocks`, он идёт раньше `package.path` и подсунул бы
--- установленную копию пакета, если она есть. Проверки тогда шли бы
--- против вчерашнего кода, а покрытие считалось бы по нему. Поэтому
--- файлы читаются сами, в порядке зависимостей, и кладутся
--- в `package.loaded` под именами модулей: `require` изнутри пакета
--- находит их первыми. Зависимость пакета — `tnt-must` — берётся
--- из `.rocks` обычным `require`: она поставлена целью `make deps`.

local fio = require('fio')
local t = require('luatest')

local helper = {}

--- Модули пакета в порядке зависимостей.
helper.MODULES = {
    { name = 'tnt.markdown.lines', path = 'tnt/markdown/lines.lua' },
    { name = 'tnt.markdown.escape', path = 'tnt/markdown/escape.lua' },
    { name = 'tnt.markdown.failure', path = 'tnt/markdown/failure.lua' },
    { name = 'tnt.markdown.plain', path = 'tnt/markdown/plain.lua' },
    { name = 'tnt.markdown.anchor', path = 'tnt/markdown/anchor.lua' },
    { name = 'tnt.markdown.callout', path = 'tnt/markdown/callout.lua' },
    { name = 'tnt.markdown.link', path = 'tnt/markdown/link.lua' },
    { name = 'tnt.markdown.modify', path = 'tnt/markdown/modify.lua' },
    { name = 'tnt.markdown.outline', path = 'tnt/markdown/outline.lua' },
    { name = 'tnt.markdown.settings', path = 'tnt/markdown/settings.lua' },
    { name = 'tnt.markdown.front', path = 'tnt/markdown/front.lua' },
    { name = 'tnt.markdown.inline', path = 'tnt/markdown/inline.lua' },
    { name = 'tnt.markdown.fence', path = 'tnt/markdown/fence.lua' },
    { name = 'tnt.markdown.list', path = 'tnt/markdown/list.lua' },
    { name = 'tnt.markdown.tables', path = 'tnt/markdown/tables.lua' },
    { name = 'tnt.markdown.blocks', path = 'tnt/markdown/blocks.lua' },
    { name = 'tnt.markdown.html', path = 'tnt/markdown/html.lua' },
    { name = 'tnt.markdown', path = 'tnt/markdown.lua' },
}

--- Части пакета: имя модуля → его таблица.
---
--- Грузятся один раз на процесс: состояния у пакета нет, а мутационный
--- прогон гоняет набор тысячи раз.
---@type table<string, any>
local PARTS = {}

for _, module in ipairs(helper.MODULES) do
    local chunk, failure = loadfile(fio.abspath(module.path))

    if chunk == nil then
        error(('исходник %s не читается: %s'):format(module.name, tostring(failure)))
    end

    local value = chunk()

    -- Пустое значение в `package.loaded` для `require` значит «не загружен»,
    -- и следующий модуль списка молча взял бы зависимость из `.rocks`.
    if value == nil then
        error(('исходник %s не вернул модуль'):format(module.name))
    end

    package.loaded[module.name] = value
    PARTS[module.name] = value
end

--- Фасад пакета, собранный из исходников.
helper.markdown = PARTS['tnt.markdown']

--- Отдельная часть пакета из той же загрузки, что и фасад.
---@param name string Имя без приставки: `lines`, `inline`, `tables`
---@return any
function helper.part(name)
    local part = PARTS[('tnt.markdown.%s'):format(name)]

    if part == nil then
        error(('модуль %s не из пакета tnt-markdown'):format(name))
    end

    return part
end

--- Настройки с выключенным конвейером.
---
--- Проверки разбора судят разбор: якорь у заголовка и обёртка у таблицы
--- в их ожиданиях были бы шумом, за которым не видно самой разметки.
--- Конвейер проверяется своими наборами — `modify`, `outline`, фасад
--- и живые документы.
---@param options table|nil
---@return table
local function bare(options)
    local prepared = table.copy(options or {})

    prepared.modify = prepared.modify or {}

    return prepared
end

--- Страница из разметки без преобразований; отказа здесь не бывает.
---@param source string
---@param options table|nil
---@return string
function helper.render(source, options)
    local page = helper.markdown.render(source, bare(options))

    return page
end

--- Страница одного абзаца без обёртки: так читаются проверки разметки
--- внутри строки, где обёртка `<p>` только мешает.
---@param source string
---@return string
function helper.paragraph(source)
    return (helper.render(source):gsub('^<p>', ''):gsub('</p>$', ''))
end

--- Дерево блоков из разметки без преобразований.
---@param source string
---@param options table|nil
---@return table[]
function helper.parse(source, options)
    local tree = helper.markdown.parse(source, bare(options))

    return tree
end

--- Дерево блоков, прошедшее конвейер: набор пакета либо названный свой.
---@param source string
---@param options table|nil
---@return table[]
function helper.modified(source, options)
    local tree = helper.markdown.parse(source, options)

    return tree
end

--- Значение мимо проверки типов: негодный аргумент нарочно.
---@param value any
---@return any
function helper.wrong(value)
    return value
end

--- Сверяет, что вызов винит строку вызывающего, а не строку внутри пакета.
---
--- Вызов стоит первой строкой тела замыкания, то есть строкой ниже слова
--- `function`: место броска сверяется с ней целиком.
---@param call function
---@param message string
function helper.assert_blamed(call, message)
    local _, err = pcall(call)
    local info = debug.getinfo(call, 'S') --[[@as { short_src: string, linedefined: integer }]]

    t.assert_equals(err, ('%s:%d: %s'):format(info.short_src, info.linedefined + 1, message))
end

return helper
