--- Отказ разбора: таблица с родом, которая читается и как строка.
---
--- Род у разбора один: `too_large` — разметка больше предела. Всё
--- остальное, что бывает в разметке, отказом не считается: незакрытая
--- ограда, битая таблица, чужой знак не срывают показ страницы, а
--- читаются как текст. А предел размера — единственное, о чём вызывающий
--- обязан узнать: без него страница, пришедшая из чужих рук, съела бы
--- память узла.
---
--- Строкой отказ читается целиком: `tostring(err)`, `'причина: ' .. err`
--- и `json.encode` дают один и тот же текст.

local Module = {}

--- Разметка больше предела.
Module.TOO_LARGE = 'too_large'

---@class TntMarkdownFailure Отказ разбора разметки
---@field kind string Род; сейчас он один — too_large
---@field message string Что случилось и почему — его и отдаёт `tostring`
---@field size integer Сколько байт пришло
---@field limit integer Каков был предел

--- Текст отказа: его отдаёт `tostring`, он же уходит в JSON.
---@param failure TntMarkdownFailure
---@return string
local function shown(failure)
    return failure.message
end

--- Отказ, который читается и как строка.
local Failure = { __tostring = shown, __serialize = shown }

--- Склейка с любой стороны: отказ годится там, где ждали строку.
---@param left any
---@param right any
---@return string
function Failure.__concat(left, right)
    return tostring(left) .. tostring(right)
end

--- Разметка больше предела.
---@param size integer Сколько байт пришло
---@param limit integer Предел, байт
---@return TntMarkdownFailure
function Module.too_large(size, limit)
    local message = ('разметка больше предела: %d байт при пределе %d'):format(
        size,
        limit
    )

    return setmetatable({ kind = Module.TOO_LARGE, message = message, size = size, limit = limit }, Failure)
end

return Module
