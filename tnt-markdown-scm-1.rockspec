rockspec_format = '3.0'

package = 'tnt-markdown'
version = 'scm-1'

source = {
    url = 'git+https://github.com/tnt-skein/tnt-markdown.git',
    branch = 'main',
}

description = {
    summary = 'Разбор markdown в дерево блоков, в HTML, в оглавление и разделы',
    detailed = [[
        Разбор markdown для Tarantool: страница документации рисуется
        из разметки прямо на узле. Разбираются заголовки, абзацы, списки
        с вложенностью, ограды кода с языком в шапке, таблицы чертами
        с выравниванием, цитаты, разделители и разметка внутри строки —
        выделение, код, ссылки, автоссылки и картинки.

        Разбор отдаёт дерево блоков, и дерево до страницы правит конвейер
        преобразований: якоря и ссылки на себя у заголовков, врезки
        из цитат с маркером, обёртка таблиц для узкого экрана, заголовок
        страницы прочь. Шаги идут списком, и приложение дописывает в него
        своё. По тому же дереву читаются оглавление страницы и её разделы
        для указателя поиска: якорь в колонке оглавления тот же, что
        в странице.

        Разбор ничего не бросает на плохом входе: незакрытая ограда, битая
        таблица, странная вложенность читаются как текст. Текст и код
        экранируются всегда, сырой HTML во входе по умолчанию тоже; шапка
        документа уходит в meta, а вход больше предела — отказ парой,
        а не съеденная память.

        Зависимость одна — tnt-must, проверка аргументов. Покрытие строк
        и убитых мутантов — 100 %.
    ]],
    homepage = 'https://github.com/tnt-skein/tnt-markdown',
    issues_url = 'https://github.com/tnt-skein/tnt-markdown/issues',
    maintainer = 'tnt-skein',
    license = 'MIT',
    labels = { 'tarantool', 'markdown', 'html', 'documentation', 'parser' },
}

dependencies = {
    'lua >= 5.1',
    'tnt-must',
}

build = {
    type = 'builtin',
    modules = {
        ['tnt.markdown'] = 'tnt/markdown.lua',
        ['tnt.markdown.anchor'] = 'tnt/markdown/anchor.lua',
        ['tnt.markdown.blocks'] = 'tnt/markdown/blocks.lua',
        ['tnt.markdown.callout'] = 'tnt/markdown/callout.lua',
        ['tnt.markdown.escape'] = 'tnt/markdown/escape.lua',
        ['tnt.markdown.failure'] = 'tnt/markdown/failure.lua',
        ['tnt.markdown.fence'] = 'tnt/markdown/fence.lua',
        ['tnt.markdown.front'] = 'tnt/markdown/front.lua',
        ['tnt.markdown.html'] = 'tnt/markdown/html.lua',
        ['tnt.markdown.inline'] = 'tnt/markdown/inline.lua',
        ['tnt.markdown.lines'] = 'tnt/markdown/lines.lua',
        ['tnt.markdown.link'] = 'tnt/markdown/link.lua',
        ['tnt.markdown.list'] = 'tnt/markdown/list.lua',
        ['tnt.markdown.modify'] = 'tnt/markdown/modify.lua',
        ['tnt.markdown.outline'] = 'tnt/markdown/outline.lua',
        ['tnt.markdown.plain'] = 'tnt/markdown/plain.lua',
        ['tnt.markdown.settings'] = 'tnt/markdown/settings.lua',
        ['tnt.markdown.tables'] = 'tnt/markdown/tables.lua',
    },
}
