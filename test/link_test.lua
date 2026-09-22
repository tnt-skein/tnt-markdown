--- Проверки ссылок, картинок и автоссылок.

local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.markdown.link')

-- ── Ссылки ───────────────────────────────────────────────────────────

g.test_a_link_keeps_the_address_as_it_is_written = function()
    -- Во что превратить ссылку на соседний документ, решает приложение.
    t.assert_equals(
        helper.paragraph('[модель](docs/model.md#раздел)'),
        '<a href="docs/model.md#раздел">модель</a>'
    )
end

g.test_a_link_holds_markup_inside = function()
    t.assert_equals(helper.paragraph('[**жирный**](/a)'), '<a href="/a"><strong>жирный</strong></a>')
end

g.test_a_link_takes_a_title = function()
    t.assert_equals(
        helper.paragraph('[текст](/a "подпись")'),
        '<a href="/a" title="подпись">текст</a>'
    )
    t.assert_equals(
        helper.paragraph("[текст](/a 'подпись')"),
        '<a href="/a" title="подпись">текст</a>'
    )
end

g.test_a_title_is_told_from_the_address_by_a_space = function()
    -- Без пробела перед кавычкой подписи нет: это всё ещё адрес.
    t.assert_equals(
        helper.paragraph('[текст](/a"подпись")'),
        '<a href="/a&quot;подпись&quot;">текст</a>'
    )
    -- Пустая подпись — тоже подпись.
    t.assert_equals(helper.paragraph('[текст](/a "")'), '<a href="/a" title="">текст</a>')
end

g.test_the_text_after_a_link_stays_where_it_was = function()
    t.assert_equals(helper.paragraph('[текст](/a) хвост'), '<a href="/a">текст</a> хвост')
end

g.test_an_address_in_angle_brackets = function()
    t.assert_equals(helper.paragraph('[текст](</a b>)'), '<a href="/a b">текст</a>')
end

g.test_brackets_inside_a_link_are_counted_in_pairs = function()
    t.assert_equals(
        helper.paragraph('[текст [в скобках]](/a)'),
        '<a href="/a">текст [в скобках]</a>'
    )
    t.assert_equals(helper.paragraph('[текст](/a(b))'), '<a href="/a(b)">текст</a>')
end

g.test_an_escaped_bracket_is_not_a_pair = function()
    t.assert_equals(helper.paragraph('[текст \\] всё](/a)'), '<a href="/a">текст ] всё</a>')
    -- Закрывающая скобка сразу за экранированной: пропускается ровно
    -- один знак, иначе пара нашлась бы не там.
    t.assert_equals(helper.paragraph('[a\\]](/x)'), '<a href="/x">a]</a>')
end

g.test_a_broken_link_stays_text = function()
    t.assert_equals(helper.paragraph('[без пары'), '[без пары')
    t.assert_equals(helper.paragraph('[текст] без адреса'), '[текст] без адреса')
    t.assert_equals(helper.paragraph('[текст](без скобки'), '[текст](без скобки')
end

g.test_a_link_by_a_label_is_not_a_link = function()
    -- Ссылок по метке пакет не знает: такая запись остаётся текстом.
    t.assert_equals(helper.paragraph('[текст][метка]'), '[текст][метка]')
end

g.test_the_address_and_the_title_are_escaped = function()
    t.assert_equals(
        helper.paragraph('[текст](/a?x=1&y="2" "с <тегом>")'),
        '<a href="/a?x=1&amp;y=&quot;2&quot;" title="с &lt;тегом&gt;">текст</a>'
    )
end

g.test_a_scheme_that_runs_code_is_not_let_in = function()
    -- Текст ссылки остаётся виден, а адрес пустеет: разметку пишут
    -- не всегда свои.
    t.assert_equals(helper.paragraph('[клик](javascript:alert(1))'), '<a href="">клик</a>')
    t.assert_equals(helper.paragraph('[клик](JavaScript:alert(1))'), '<a href="">клик</a>')
    t.assert_equals(helper.paragraph('[клик](vbscript:x)'), '<a href="">клик</a>')
    t.assert_equals(helper.paragraph('[клик](data:text/html;base64,x)'), '<a href="">клик</a>')
    t.assert_equals(helper.paragraph('[клик](file:///etc/passwd)'), '<a href="">клик</a>')
    t.assert_equals(helper.paragraph('[клик](https://example.org)'), '<a href="https://example.org">клик</a>')
end

g.test_a_scheme_split_by_a_line_break_is_not_let_in_either = function()
    -- Строки абзаца склеены переносом, а браузер выбрасывает его
    -- из адреса сам: запрет обязан смотреть на тот же адрес, что и он.
    t.assert_equals(helper.render('[клик](java\nscript:alert(1))'), '<p><a href="">клик</a></p>')
    t.assert_equals(helper.render('![к](java\nscript:alert(1))'), '<p><img src="" alt="к"></p>')
end

g.test_invisible_signs_leave_the_address = function()
    t.assert_equals(helper.paragraph('[текст](/a\nb)'), '<a href="/ab">текст</a>')
end

-- ── Картинки ─────────────────────────────────────────────────────────

g.test_an_image_carries_its_address_and_alt = function()
    t.assert_equals(
        helper.paragraph('![схема](/img/схема.png)'),
        '<img src="/img/схема.png" alt="схема">'
    )
end

g.test_the_alt_of_an_image_is_plain_text = function()
    t.assert_equals(
        helper.paragraph('![**жирный** текст](/a.png)'),
        '<img src="/a.png" alt="жирный текст">'
    )
end

g.test_an_image_takes_a_title = function()
    t.assert_equals(
        helper.paragraph('![схема](/a.png "подпись")'),
        '<img src="/a.png" alt="схема" title="подпись">'
    )
end

g.test_an_exclamation_mark_without_a_link_stays_itself = function()
    t.assert_equals(helper.paragraph('вот так!'), 'вот так!')
    t.assert_equals(helper.paragraph('![без пары'), '![без пары')
end

-- ── Автоссылки ───────────────────────────────────────────────────────

g.test_an_address_in_angle_brackets_becomes_a_link = function()
    t.assert_equals(
        helper.paragraph('см. <https://example.org/a?b=1> дальше'),
        'см. <a href="https://example.org/a?b=1">https://example.org/a?b=1</a> дальше'
    )
end

g.test_mail_in_angle_brackets_becomes_a_link = function()
    t.assert_equals(helper.paragraph('<duty@example.org>'), '<a href="mailto:duty@example.org">duty@example.org</a>')
    t.assert_equals(
        helper.paragraph('<duty@example.org> хвост'),
        '<a href="mailto:duty@example.org">duty@example.org</a> хвост'
    )
    t.assert_equals(helper.paragraph('<a+b@c.ru>'), '<a href="mailto:a+b@c.ru">a+b@c.ru</a>')
    t.assert_equals(helper.paragraph('<a-b@c.ru>'), '<a href="mailto:a-b@c.ru">a-b@c.ru</a>')
end

g.test_what_is_not_mail_stays_text = function()
    -- Ни имени, ни хозяина, ни домена короче двух букв почта не бывает.
    t.assert_equals(helper.paragraph('<@example.org>'), '&lt;@example.org&gt;')
    t.assert_equals(helper.paragraph('<a@.ru>'), '&lt;a@.ru&gt;')
    t.assert_equals(helper.paragraph('<a@b.r>'), '&lt;a@b.r&gt;')
end

g.test_an_autolink_takes_a_short_scheme_and_an_empty_path = function()
    t.assert_equals(helper.paragraph('<x:y>'), '<a href="x:y">x:y</a>')
    t.assert_equals(helper.paragraph('<ftp:>'), '<a href="ftp:">ftp:</a>')
end

g.test_an_angle_bracket_inside_an_autolink_ends_it = function()
    -- Иначе автоссылка съела бы тег, начавшийся следом.
    t.assert_equals(helper.paragraph('<https://a<b>'), '&lt;<a href="https://a">https://a</a>&lt;b&gt;')
end

g.test_an_angle_bracket_with_anything_else_stays_text = function()
    t.assert_equals(helper.paragraph('<имя>'), '&lt;имя&gt;')
    t.assert_equals(helper.paragraph('a < b'), 'a &lt; b')
end

g.test_a_dangerous_scheme_in_an_autolink_is_not_let_in = function()
    t.assert_equals(helper.paragraph('<javascript:alert(1)>'), '<a href="">javascript:alert(1)</a>')
end

g.test_raw_html_inside_a_line_passes_when_it_is_allowed = function()
    t.assert_equals(helper.render('раз <b>два</b>', { allow_html = true }), '<p>раз <b>два</b></p>')
    t.assert_equals(helper.render('раз <b>два</b>'), '<p>раз &lt;b&gt;два&lt;/b&gt;</p>')
end

g.test_an_unfinished_tag_stays_text_even_when_html_is_allowed = function()
    t.assert_equals(helper.render('раз < два', { allow_html = true }), '<p>раз &lt; два</p>')
    -- Угловая скобка внутри тега его кончает, а знак равенства — нет.
    t.assert_equals(helper.render('раз <b<c> два', { allow_html = true }), '<p>раз &lt;b<c> два</p>')
    t.assert_equals(
        helper.render('раз <a href="x">тут</a> два', { allow_html = true }),
        '<p>раз <a href="x">тут</a> два</p>'
    )
end

-- ── Голые адреса ─────────────────────────────────────────────────────

g.test_a_bare_address_becomes_a_link = function()
    t.assert_equals(
        helper.paragraph('морда https://example.org тут'),
        'морда <a href="https://example.org">https://example.org</a> тут'
    )
    t.assert_equals(
        helper.paragraph('http://127.0.0.1:8025'),
        '<a href="http://127.0.0.1:8025">http://127.0.0.1:8025</a>'
    )
end

g.test_the_end_of_a_sentence_is_not_a_part_of_the_address = function()
    t.assert_equals(
        helper.paragraph('см. https://example.org/a.'),
        'см. <a href="https://example.org/a">https://example.org/a</a>.'
    )
    t.assert_equals(
        helper.paragraph('(https://example.org)'),
        '(<a href="https://example.org">https://example.org</a>)'
    )
end

g.test_a_bare_address_in_quotation_marks_becomes_a_link = function()
    -- Ёлочка не буква, и адрес за ней начинается; её же срезает хвост
    -- предложения вместе с точкой за ней.
    t.assert_equals(
        helper.paragraph('см. «https://example.org» тут'),
        'см. «<a href="https://example.org">https://example.org</a>» тут'
    )
    t.assert_equals(
        helper.paragraph('см. «https://example.org».'),
        'см. «<a href="https://example.org">https://example.org</a>».'
    )
    -- Точка за ёлочкой: одного прохода по хвосту на такой не хватает.
    t.assert_equals(
        helper.paragraph('см. «https://example.org.»'),
        'см. «<a href="https://example.org">https://example.org</a>.»'
    )
end

g.test_a_russian_address_keeps_its_last_letter = function()
    -- Второй байт у «л» тот же, что у закрывающей ёлочки: набором байтов
    -- хвост предложения срезал бы половину буквы.
    t.assert_equals(
        helper.paragraph('https://пример.рф/файл'),
        '<a href="https://пример.рф/файл">https://пример.рф/файл</a>'
    )
end

g.test_an_address_without_a_host_is_not_a_link = function()
    -- «http://» в тексте — это пример записи, а не адрес.
    t.assert_equals(
        helper.paragraph('строка «http://» плюс сто'),
        'строка «http://» плюс сто'
    )
end

g.test_a_bare_address_ends_at_an_angle_bracket_and_holds_a_query = function()
    t.assert_equals(
        helper.paragraph('https://example.org/a?b=1'),
        '<a href="https://example.org/a?b=1">https://example.org/a?b=1</a>'
    )
    -- Тег, начавшийся вплотную, в адрес не входит.
    t.assert_equals(
        helper.paragraph('https://example.org<b>'),
        '<a href="https://example.org">https://example.org</a>&lt;b&gt;'
    )
end

g.test_an_address_inside_a_word_is_not_an_address = function()
    t.assert_equals(helper.paragraph('xhttps://example.org'), 'xhttps://example.org')
    t.assert_equals(helper.paragraph('hhttp'), 'hhttp')
end

g.test_a_link_does_not_live_inside_a_link = function()
    -- Иначе браузер получил бы <a> внутри <a>.
    t.assert_equals(
        helper.paragraph('[https://example.org](https://example.org)'),
        '<a href="https://example.org">https://example.org</a>'
    )
    t.assert_equals(helper.paragraph('[<https://a>](/b)'), '<a href="/b">&lt;https://a&gt;</a>')
    t.assert_equals(helper.paragraph('[текст [ещё](/c)](/b)'), '<a href="/b">текст [ещё](/c)</a>')
end

g.test_markup_inside_a_link_still_works = function()
    t.assert_equals(
        helper.paragraph('[*курсив* и `код`](/b)'),
        '<a href="/b"><em>курсив</em> и <code>код</code></a>'
    )
end
