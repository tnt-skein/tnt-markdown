--- Разбор markdown: дерево блоков, HTML, оглавление и разделы.
---
---     local markdown = require('tnt.markdown')
---
---     local page, meta = markdown.render(source)
---
---     if page == nil then
---         -- вход больше предела: meta здесь отказ с родом too_large
---     end
---
---     local tree = markdown.parse(source)          -- дерево блоков
---     local page = markdown.to_html(tree)          -- оно же страницей
---
---     local headings = markdown.outline(source)    -- колонка справа
---     local sections = markdown.sections(source)   -- куски для поиска
---     local title = markdown.title_of(tree)        -- заголовок для шапки
---
--- Разбирается то, чем пишут документацию: заголовки `#`–`######`,
--- абзацы и переносы, списки простые и нумерованные с вложенностью,
--- ограды кода с языком в шапке, таблицы с выравниванием, цитаты,
--- разделители, а внутри строки — `**жирный**`, `*курсив*`, `` `код` ``,
--- ссылки, автоссылки и картинки.
---
--- **Разбор не отказывает.** Незакрытая ограда, таблица без шапки, список
--- без пробела после знака, странная вложенность — всё это читается как
--- текст. Отказ у пакета один, и он про размер: вход больше `max_size`
--- (по умолчанию мегабайт) — это `nil, err` с родом `too_large`, а не
--- съеденная память узла. Негодный аргумент — ошибка программиста,
--- и она роняет вызов на месте.
---
--- **Экранируется всё.** Текст, код, адрес ссылки и подпись уходят
--- в страницу сущностями. Сырой HTML во входе по умолчанию тоже
--- экранируется и виден текстом; пустить его в страницу можно
--- настройкой `allow_html`, и тогда за вход отвечает вызывающий.
---
--- **Дерево — не подробность.** `parse` отдаёт то же дерево, из которого
--- рисуется страница: по нему строят оглавление и указатель поиска,
--- его же правят перед показом и рисуют потом через `to_html`.
---
--- **Дерево правит конвейер.** Заголовки h2–h4 получают якорь и ссылку
--- на себя, цитата с маркером (`> **Примечание.**`, `> [!WARNING]`)
--- становится врезкой со своим видом, таблица уезжает в обёртку, которая
--- прокручивается на узком экране. Шаги идут списком — настройка
--- `modify`, — и список этот меняют: `markdown.modifications()` отдаёт
--- набор пакета, в который дописывают своё, а `modify = {}` возвращает
--- голый разбор.
---
--- **Оглавление и разделы читаются из того же дерева.** `outline` отдаёт
--- заголовки h2–h4 с уровнем, текстом и якорем — по нему рисуют колонку
--- справа; `sections` — куски «заголовок и текст под ним» без разметки,
--- из которых приложение собирает указатель поиска. Якорь у обоих тот,
--- что стоит в странице: второго правила имени нет.
---
--- **Шапка документа** (`---` … `---` в начале файла, пары `ключ: значение`)
--- уходит в `meta` и в страницу не попадает. Значения остаются строками.
---
--- **Адреса не трогаются.** `[текст](docs/model.md#раздел)` остаётся
--- ссылкой на соседний документ: во что её превратить, знает приложение,
--- а не разбор разметки. Правило приложения ставится шагом конвейера
--- `markdown.links(rewrite)`: где в дереве лежат ссылки, пакет находит
--- сам.
---
--- Чем пришлось поступиться — в `docs/markdown.md`.

local must = require('tnt.must')

local blocks = require('tnt.markdown.blocks')
local failure = require('tnt.markdown.failure')
local front = require('tnt.markdown.front')
local html = require('tnt.markdown.html')
local lines = require('tnt.markdown.lines')
local modify = require('tnt.markdown.modify')
local outline = require('tnt.markdown.outline')
local settings = require('tnt.markdown.settings')

local Module = {}

--- Предел размера разметки по умолчанию, байт.
Module.MAX_SIZE = settings.MAX_SIZE

--- Разметка больше предела.
Module.TOO_LARGE = failure.TOO_LARGE

--- Класс обёртки, в которую уезжает таблица.
Module.TABLE_CLASS = modify.TABLE_CLASS

--- Набор преобразований пакета: новый список, в который дописывают своё.
Module.modifications = modify.default

--- Якоря и ссылки на себя у заголовков h2–h4.
Module.anchors = modify.anchors

--- Врезки из цитат с маркером.
Module.callouts = modify.callouts

--- Таблицы в обёртке, которая прокручивается.
Module.table_scroll = modify.table_scroll

--- Первый заголовок страницы прочь: его рисует шапка.
Module.without_first_heading = modify.without_first_heading

--- Обход дерева для своего преобразования.
Module.walk = modify.walk

--- Шаг, который переводит адреса ссылок правилом приложения.
---
--- Правило — функция от адреса: новый адрес строкой либо `nil`, чтобы
--- оставить прежний. Негодное правило — ошибка программиста, и она
--- винит строку, где шаг собран, а не первый разбор страницы.
---@param rewrite fun(href: string): string|nil
---@return fun(blocks: table[]): table[]
function Module.links(rewrite)
    must.at(2).callable(rewrite, 'перевод ссылок')

    return modify.links(rewrite)
end

--- Дерево и шапка по уже проверенным настройкам: разбор и конвейер.
---@param source string
---@param options TntMarkdownSettings
---@return table[]|nil tree, table|TntMarkdownFailure meta
local function document_of(source, options)
    if #source > options.max_size then
        return nil, failure.too_large(#source, options.max_size)
    end

    local meta, body = front.split(lines.split(source))

    return modify.apply(blocks.document(body, options), options.modify), meta
end

--- Разбор, конвейер и то, что из дерева собирают дальше.
---
--- Собран в одном месте нарочно: страница, оглавление и разделы читают
--- одно и то же дерево, и разойтись им нельзя — якорь в колонке обязан
--- совпадать с якорем в странице.
---@param source string
---@param options table|nil
---@param build fun(tree: table[], options: TntMarkdownSettings): any
---@return any|nil built, table|TntMarkdownFailure meta
local function built(source, options, build)
    local prepared = settings.normalize(options)
    local tree, meta = document_of(source, prepared)

    if tree == nil then
        return nil, meta
    end

    return build(tree, prepared), meta
end

---@class TntMarkdownOptions Настройки, какими их пишет вызывающий
---@field allow_html boolean|nil Пускать ли сырой HTML в страницу
---@field max_size integer|nil Предел размера разметки, байт
---@field modify (fun(blocks: table[]): table[])[]|nil Свой конвейер вместо набора пакета

--- Разбирает разметку в дерево блоков — уже с преобразованиями.
---@param source string
---@param options TntMarkdownOptions|nil
---@return table[]|nil tree, table|TntMarkdownFailure meta Отказ парой при переполнении
function Module.parse(source, options)
    must.at(2).string(source, 'разметка')

    return document_of(source, settings.normalize(options))
end

--- Разбирает разметку в HTML.
---@param source string
---@param options TntMarkdownOptions|nil
---@return string|nil page, table|TntMarkdownFailure meta Отказ парой при переполнении
function Module.render(source, options)
    must.at(2).string(source, 'разметка')

    return built(source, options, html.render)
end

--- Оглавление страницы: заголовки h2–h4 с уровнем, текстом и якорем.
---@param source string
---@param options TntMarkdownOptions|nil
---@return TntMarkdownHeading[]|nil headings, table|TntMarkdownFailure meta Отказ парой при переполнении
function Module.outline(source, options)
    must.at(2).string(source, 'разметка')

    return built(source, options, outline.of)
end

--- Разделы страницы: заголовок, якорь и текст под ним без разметки.
---@param source string
---@param options TntMarkdownOptions|nil
---@return TntMarkdownSection[]|nil sections, table|TntMarkdownFailure meta Отказ парой при переполнении
function Module.sections(source, options)
    must.at(2).string(source, 'разметка')

    return built(source, options, outline.sections)
end

--- Оглавление по дереву — своему либо изменённому.
---@param tree table[]
---@return TntMarkdownHeading[]
function Module.outline_of(tree)
    must.at(2).array(tree, 'дерево блоков')

    return outline.of(tree)
end

--- Заголовок страницы по дереву: текст первого блока, если это заголовок.
---
--- Тот самый заголовок, который убирает шаг `without_first_heading`:
--- шапка страницы рисует его сама, и текст ей берут отсюда.
---@param tree table[]
---@return string|nil
function Module.title_of(tree)
    must.at(2).array(tree, 'дерево блоков')

    return outline.title(tree)
end

--- Разделы по дереву — своему либо изменённому.
---@param tree table[]
---@return TntMarkdownSection[]
function Module.sections_of(tree)
    must.at(2).array(tree, 'дерево блоков')

    return outline.sections(tree)
end

--- Рисует дерево блоков — своё либо изменённое.
---
--- Конвейер к нему не применяется: дерево прошло его в `parse`, и второй
--- проход поставил бы якоря заново и обернул уже обёрнутое.
---@param tree table[]
---@param options TntMarkdownOptions|nil
---@return string
function Module.to_html(tree, options)
    must.at(2).array(tree, 'дерево блоков')

    return html.render(tree, settings.normalize(options))
end

return Module
