--- Якорь заголовка: имя, по которому на раздел ссылаются.
---
--- Кириллица в якоре остаётся кириллицей: «## Как пользоваться» даёт
--- `как-пользоваться`. Ссылки внутри документов пишутся по-русски
--- (`markdown.md#плашки`), и транслитерация разошлась бы с ними —
--- к тому же она необратима: `ё` и `йо` дают одно и то же имя, и два
--- разных раздела получили бы один якорь. В `id` по HTML годится любой
--- знак, кроме пробельного, а хвост адреса с русскими буквами браузер
--- кодирует сам.
---
--- Правил три. Буквы — в строчные: ссылку набирают руками, и «Плашки»
--- не должны отличаться от «плашки». Всё, что не буква и не цифра, —
--- разделитель, и подряд идущие разделители дают один дефис: заголовок
--- «Как пользоваться?» и заголовок «Как  пользоваться» дают одно имя.
--- Повтор внутри страницы получает числовой хвост.
---
--- Хвост считается до свободного имени, а не просто «второй по счёту»:
--- страница, где есть и «Раздел», и «Раздел 2», иначе получила бы два
--- якоря `раздел-2`, и ссылка на второй уводила бы к третьему.

local utf8 = require('utf8')

local lines = require('tnt.markdown.lines')

local Module = {}

--- Какие заголовки получают якорь.
---
--- Выше — заголовок страницы: его рисует шапка, и ссылаться на него
--- незачем. Ниже — подпись внутри раздела: в колонке оглавления ей
--- не место, а колонка и якоря обязаны совпадать.
Module.MIN_LEVEL = 2
Module.MAX_LEVEL = 4

--- Чем разделены слова в якоре.
Module.SEPARATOR = '-'

--- Якорь заголовка, в котором не нашлось ни буквы, ни цифры: заголовок
--- из одного значка или тире тоже обязан быть достижим ссылкой.
Module.NAMELESS = 'section'

--- Получает ли заголовок этого уровня якорь.
---@param level integer
---@return boolean
function Module.leveled(level)
    return level >= Module.MIN_LEVEL and level <= Module.MAX_LEVEL
end

--- Имя якоря по тексту заголовка.
---@param text string Текст заголовка без разметки
---@return string
function Module.slug(text)
    -- Знак разбирается целиком: у русской буквы байтов несколько,
    -- и по одному байту не решить, буква это или знак препинания.
    local lowered = utf8.lower(text)
    local words = {}
    local word = {}
    local at = 1

    while at <= #lowered do
        local char = lines.char_at(lowered, at)

        if lines.wordy(char) then
            table.insert(word, char)
        elseif #word > 0 then
            table.insert(words, table.concat(word))
            word = {}
        end

        at = at + #char
    end

    if #word > 0 then
        table.insert(words, table.concat(word))
    end

    if #words == 0 then
        return Module.NAMELESS
    end

    return table.concat(words, Module.SEPARATOR)
end

--- Якорь, которым на этой странице ещё никто не назвался.
---@param taken table<string, boolean> Занятые имена страницы; пополняется
---@param text string Текст заголовка без разметки
---@return string
function Module.take(taken, text)
    local base = Module.slug(text)
    local name = base
    local index = 1

    while taken[name] do
        index = index + 1
        name = ('%s%s%d'):format(base, Module.SEPARATOR, index)
    end

    taken[name] = true

    return name
end

return Module
