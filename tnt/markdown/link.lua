--- Ссылки, картинки и автоссылки.
---
---     [текст](docs/model.md#раздел)     ссылка
---     [текст](адрес "подпись")          ссылка с подписью
---     ![что на ней](/img/схема.png)     картинка
---     <https://example.org>             автоссылка
---     <duty@example.org>                почта
---     https://example.org               голый адрес в тексте
---
--- Адрес остаётся таким, каким его написали: ни кодирования, ни
--- приведения к маршруту сайта здесь нет. Ссылка на соседний документ —
--- `docs/model.md` — это ссылка на соседний документ, а во что её
--- превратить, решает приложение, которое одно и знает свои адреса.
---
--- Схема, исполняющая код в браузере, в ссылку не пускается: адрес
--- становится пустым, а текст ссылки остаётся виден. Разметку пишут
--- не всегда свои, и `javascript:` в адресе — это готовый межсайтовый
--- сценарий, который не остановит никакое экранирование. Ищется схема
--- в адресе без невидимых знаков: браузер выбрасывает их сам, и запрет,
--- глядящий на другой адрес, чем браузер, ничего не запрещает.
---
--- Ссылок по метке (`[текст][метка]` с объявлением ниже) пакет не знает:
--- такая запись остаётся текстом. В наших документах её нет, а вторая
--- таблица меток — это ещё один проход по документу и ещё один вид
--- висящей ссылки.

local lines = require('tnt.markdown.lines')

local Module = {}

--- Начала адресов, которым в ссылке не место. Схема пишется вместе
--- с двоеточием: сверяется начало адреса целиком, а не слово из него.
local DANGEROUS = { 'javascript:', 'vbscript:', 'data:', 'file:' }

--- Сколько знаков занимают угловые скобки вокруг автоссылки.
local ANGLES = 2

--- Невидимые знаки: браузер выбрасывает их из адреса сам.
local INVISIBLE = '%c'

--- Адрес без хвоста предложения: точка и скобка в конце фразы в него
--- не входят.
local WITHOUT_SENTENCE_TAIL = '^(.-)[.,;:!%?%)]*$'

--- Закрывающая ёлочка на конце. Своим образцом, а не знаком в наборе:
--- второй байт у неё тот же, что у русской буквы «л», и набор байтов
--- срезал бы у адреса, кончившегося на «л», половину знака.
local CLOSING_TAIL = '»$'

--- Голый адрес в тексте: схема, разделитель и хотя бы знак хозяина.
local BARE = '^https?://[^%s<>]+'

--- Адрес и подпись: подпись стоит последней и взята в кавычки.
local TITLED_DOUBLE = '^(.-)%s+"(.*)"$'
local TITLED_SINGLE = "^(.-)%s+'(.*)'$"

--- Адрес, годный для страницы.
---
--- Невидимые знаки убираются: адрес обязан значить в разметке то же, что
--- и в браузере, а тот выбрасывает их сам. Перенос строки попадает
--- в адрес легко — строки абзаца склеены им же, — и `java\nscript:`
--- иначе прошло бы мимо запрета, а в браузере собралось бы в рабочую
--- схему.
---
--- Схема, исполняющая код, не пускается вовсе: адрес пустеет, а текст
--- ссылки остаётся виден.
---
--- Правило одно на разбор и на перевод ссылок приложением
--- (`tnt.markdown.modify`): адрес, собранный правилом приложения из того
--- же входа, иначе протащил бы запрещённую схему мимо разбора.
---@param url string
---@return string
function Module.safe(url)
    local readable = (url:gsub(INVISIBLE, ''))
    local lowered = lines.trim(readable):lower()

    for _, scheme in ipairs(DANGEROUS) do
        if lowered:startswith(scheme) then
            return ''
        end
    end

    return readable
end

--- Адрес без хвоста предложения.
---
--- Срезается хвост по кругу: в записи `«https://узел.»` точка прячется
--- за ёлочкой, и одного прохода на такой хвост не хватает.
---@param url string
---@return string
local function without_tail(url)
    local body = url:match(WITHOUT_SENTENCE_TAIL) --[[@as string]]
    local cut = (body:gsub(CLOSING_TAIL, ''))

    if cut == url then
        return cut
    end

    return without_tail(cut)
end

--- Место парной скобки с учётом вложенных пар.
---
--- Скобки в тексте ссылки и в адресе бывают вложенными, а
--- экранированная скобка парой не считается.
---@param text string
---@param at integer Место открывающей скобки
---@param open string
---@param close string
---@return integer|nil
local function closing(text, at, open, close)
    local depth = 0
    local pos = at

    while pos <= #text do
        local char = text:sub(pos, pos)

        if char == '\\' then
            pos = pos + 1
        elseif char == open then
            depth = depth + 1
        elseif char == close then
            depth = depth - 1

            if depth == 0 then
                return pos
            end
        end

        pos = pos + 1
    end

    return nil
end

--- Адрес и подпись из хвоста ссылки.
---@param target string
---@return string href, string|nil title
local function target_of(target)
    local trimmed = lines.trim(target)
    local url, title = trimmed:match(TITLED_DOUBLE)

    if url == nil then
        url, title = trimmed:match(TITLED_SINGLE)
    end

    if url == nil then
        url = trimmed
    end

    return Module.safe(url:match('^<(.*)>$') or url), title
end

--- Ссылка, у которой текст — сам адрес.
---@param shown string
---@param href string
---@return table
local function autolink(shown, href)
    return { kind = 'link', href = href, inline = { { kind = 'text', text = shown } } }
end

--- Ссылка `[текст](адрес)`.
---@param text string
---@param at integer Место открывающей квадратной скобки
---@param options TntMarkdownSettings
---@param parse fun(text: string, options: TntMarkdownSettings, linked: boolean|nil): table[]
---@return table|nil node, integer|nil after
function Module.link(text, at, options, parse)
    local label_to = closing(text, at, '[', ']')

    if label_to == nil then
        return nil
    end

    local target_at = label_to + 1

    if text:sub(target_at, target_at) ~= '(' then
        return nil
    end

    local target_to = closing(text, target_at, '(', ')')

    if target_to == nil then
        return nil
    end

    local href, title = target_of(text:sub(target_at + 1, target_to - 1))

    -- Текст ссылки разбирается как содержимое ссылки: ссылки в ссылке
    -- не бывает, и адрес, записанный текстом, остаётся текстом.
    local inline = parse(text:sub(at + 1, label_to - 1), options, true)

    return { kind = 'link', href = href, title = title, inline = inline }, target_to + 1
end

--- Картинка `![что на ней](адрес)`.
---@param text string
---@param at integer Место восклицательного знака
---@param options TntMarkdownSettings
---@param parse fun(text: string, options: TntMarkdownSettings, linked: boolean|nil): table[]
---@return table|nil node, integer|nil after
function Module.image(text, at, options, parse)
    local label_at = at + 1

    if text:sub(label_at, label_at) ~= '[' then
        return nil
    end

    local node, after = Module.link(text, label_at, options, parse)

    if node == nil then
        return nil
    end

    return { kind = 'image', src = node.href, title = node.title, inline = node.inline }, after
end

--- Автоссылка `<адрес>`, почта `<кто@где>`, а с `allow_html` — и сырой тег.
---@param text string
---@param at integer Место открывающей угловой скобки
---@param options TntMarkdownSettings
---@return table|nil node, integer|nil after
function Module.angle(text, at, options)
    local url = text:match('^<(%a[%w+.-]*:[^%s<>]*)>', at)

    if url ~= nil then
        return autolink(url, Module.safe(url)), at + #url + ANGLES
    end

    local mail = text:match('^<([%w._%%+-]+@[%w.-]+%.%a%a+)>', at)

    if mail ~= nil then
        return autolink(mail, 'mailto:' .. mail), at + #mail + ANGLES
    end

    if not options.allow_html then
        return nil
    end

    local tag = text:match('^<[%a/!?][^<>]*>', at)

    if tag == nil then
        return nil
    end

    return { kind = 'html', text = tag }, at + #tag
end

--- Голый адрес в тексте: `https://example.org`.
---
--- Внутри слова адрес не начинается, а хвост предложения — точка,
--- скобка, закрывающая ёлочка — в него не входит: ссылка кончается там,
--- где кончается сам адрес, а не предложение.
---@param text string
---@param at integer Место первой буквы схемы
---@return table|nil node, integer|nil after
function Module.bare(text, at)
    if lines.wordy(lines.char_before(text, at)) then
        return nil
    end

    local url = text:match(BARE, at)

    if url == nil then
        return nil
    end

    local trimmed = without_tail(url)

    -- Хвост предложения, срезанный целиком, хозяина не оставил: «http://»
    -- в тексте — это пример записи, а не адрес, и ссылкой он не станет.
    if trimmed:match(BARE) == nil then
        return nil
    end

    return autolink(trimmed, trimmed), at + #trimmed
end

return Module
