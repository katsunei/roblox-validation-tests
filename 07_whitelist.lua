--[[
    ============================================================
    Скрипт #07: Белый список для тестов
    ============================================================
    Назначение:
        Утилитарный модуль для управления белым списком игроков,
        исключённых из тестовых симуляций. Другие скрипты могут
        обращаться к _G.TestWhitelist для проверки.

    Что тестирует:
        Сам по себе не тестирует уязвимости — это вспомогательный
        инструмент для остальных тестовых скриптов.

    Использование:
        Вставить в CommandBar в Roblox Studio.
        Затем вызывать функции через _G:
            _G.AddToWhitelist("PlayerName")
            _G.RemoveFromWhitelist("PlayerName")
            _G.IsWhitelisted("PlayerName")
            _G.PrintWhitelist()
            _G.GetNonWhitelistedPlayers()
    ============================================================
--]]

-- === Сервисы ===
local Players = game:GetService("Players")

-- === Инициализация белого списка ===
-- Если список уже существует в _G, сохраняем его (повторный запуск не затрёт данные)
if not _G.TestWhitelist then
    _G.TestWhitelist = {}
    print("[Белый список] Создан новый пустой белый список.")
else
    print("[Белый список] Используется существующий белый список (" .. tostring(#_G.TestWhitelist) .. " записей).")
end

-- === Вспомогательная функция: нормализация идентификатора ===
-- Принимает строку (имя) или число (UserId) и возвращает строку в нижнем регистре
local function NormalizeEntry(entry)
    if type(entry) == "number" then
        return tostring(entry)
    elseif type(entry) == "string" then
        return string.lower(entry)
    else
        warn("[Белый список] Неверный тип записи: " .. type(entry))
        return nil
    end
end

-- === Поиск записи в белом списке (возвращает индекс или nil) ===
local function FindInWhitelist(entry)
    local normalized = NormalizeEntry(entry)
    if not normalized then return nil end

    for i, v in ipairs(_G.TestWhitelist) do
        if NormalizeEntry(v) == normalized then
            return i
        end
    end
    return nil
end

-- ============================================================
-- Функция: AddToWhitelist
-- Добавляет игрока (имя или UserId) в белый список
-- ============================================================
local function AddToWhitelist(name)
    if name == nil then
        warn("[Белый список] Необходимо указать имя или UserId!")
        return false
    end

    -- Проверяем, нет ли уже в списке
    if FindInWhitelist(name) then
        warn("[Белый список] '" .. tostring(name) .. "' уже в белом списке.")
        return false
    end

    table.insert(_G.TestWhitelist, name)
    print("[Белый список] ✅ Добавлен: " .. tostring(name))
    return true
end

-- ============================================================
-- Функция: RemoveFromWhitelist
-- Удаляет игрока из белого списка
-- ============================================================
local function RemoveFromWhitelist(name)
    if name == nil then
        warn("[Белый список] Необходимо указать имя или UserId!")
        return false
    end

    local index = FindInWhitelist(name)
    if not index then
        warn("[Белый список] '" .. tostring(name) .. "' не найден в белом списке.")
        return false
    end

    table.remove(_G.TestWhitelist, index)
    print("[Белый список] ❌ Удалён: " .. tostring(name))
    return true
end

-- ============================================================
-- Функция: IsWhitelisted
-- Проверяет, находится ли игрок в белом списке
-- ============================================================
local function IsWhitelisted(name)
    if name == nil then
        return false
    end

    local found = FindInWhitelist(name) ~= nil

    if found then
        print("[Белый список] '" .. tostring(name) .. "' — В БЕЛОМ СПИСКЕ ✅")
    else
        print("[Белый список] '" .. tostring(name) .. "' — НЕ в белом списке ❌")
    end

    return found
end

-- ============================================================
-- Функция: PrintWhitelist
-- Выводит все записи белого списка в консоль
-- ============================================================
local function PrintWhitelist()
    print("╔══════════════════════════════════════╗")
    print("║       БЕЛЫЙ СПИСОК ДЛЯ ТЕСТОВ       ║")
    print("╠══════════════════════════════════════╣")

    if #_G.TestWhitelist == 0 then
        print("║  (пусто)                             ║")
    else
        for i, entry in ipairs(_G.TestWhitelist) do
            -- Пытаемся получить информацию об игроке, если он на сервере
            local playerInfo = ""
            local player = Players:FindFirstChild(tostring(entry))
            if player then
                playerInfo = " [онлайн]"
            end
            print("║  " .. i .. ". " .. tostring(entry) .. playerInfo)
        end
    end

    print("╠══════════════════════════════════════╣")
    print("║  Всего записей: " .. tostring(#_G.TestWhitelist))
    print("╚══════════════════════════════════════╝")
end

-- ============================================================
-- Функция: GetNonWhitelistedPlayers
-- Возвращает таблицу игроков, НЕ находящихся в белом списке
-- ============================================================
local function GetNonWhitelistedPlayers()
    local nonWhitelisted = {}

    for _, player in ipairs(Players:GetPlayers()) do
        local isInList = false

        -- Проверяем по имени
        if FindInWhitelist(player.Name) then
            isInList = true
        end

        -- Проверяем по DisplayName
        if not isInList and FindInWhitelist(player.DisplayName) then
            isInList = true
        end

        -- Проверяем по UserId
        if not isInList and FindInWhitelist(player.UserId) then
            isInList = true
        end

        if not isInList then
            table.insert(nonWhitelisted, player)
        end
    end

    print("[Белый список] Игроков НЕ в белом списке: " .. #nonWhitelisted .. " из " .. #Players:GetPlayers())
    for _, p in ipairs(nonWhitelisted) do
        print("  — " .. p.Name .. " (ID: " .. p.UserId .. ")")
    end

    return nonWhitelisted
end

-- === Регистрация функций в глобальном пространстве _G ===
_G.AddToWhitelist = AddToWhitelist
_G.RemoveFromWhitelist = RemoveFromWhitelist
_G.IsWhitelisted = IsWhitelisted
_G.PrintWhitelist = PrintWhitelist
_G.GetNonWhitelistedPlayers = GetNonWhitelistedPlayers

-- === Вывод инструкций ===
print("")
print("╔══════════════════════════════════════════════════════════╗")
print("║          УТИЛИТА: БЕЛЫЙ СПИСОК ДЛЯ ТЕСТОВ              ║")
print("╠══════════════════════════════════════════════════════════╣")
print("║  Доступные команды (вставляйте в CommandBar):           ║")
print("║                                                         ║")
print("║  _G.AddToWhitelist('ИмяИгрока')                         ║")
print("║    — добавить игрока в белый список                     ║")
print("║                                                         ║")
print("║  _G.RemoveFromWhitelist('ИмяИгрока')                    ║")
print("║    — удалить игрока из белого списка                    ║")
print("║                                                         ║")
print("║  _G.IsWhitelisted('ИмяИгрока')                          ║")
print("║    — проверить, в белом ли списке                       ║")
print("║                                                         ║")
print("║  _G.PrintWhitelist()                                     ║")
print("║    — показать весь белый список                         ║")
print("║                                                         ║")
print("║  _G.GetNonWhitelistedPlayers()                           ║")
print("║    — получить игроков, НЕ в белом списке                ║")
print("║                                                         ║")
print("║  Также можно добавлять по UserId:                       ║")
print("║  _G.AddToWhitelist(123456789)                            ║")
print("╚══════════════════════════════════════════════════════════╝")
print("")
