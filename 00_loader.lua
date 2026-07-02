--[[
    ============================================================
    🔄 ГЛАВНЫЙ ЗАГРУЗЧИК ТЕСТОВЫХ СКРИПТОВ
    ============================================================
    Назначение: Автоматически загружает и выполняет все 23
    тестовых скрипта из GitHub-репозитория одной командой.
    
    Использование:
      1. Вставьте этот скрипт в CommandBar в Roblox Studio
      2. Все тесты загрузятся и выполнятся автоматически
      3. Для перезапуска: _G.ReloadAllTests()
    
    Настройка:
      - Измените REPO_BASE_URL на ваш репозиторий
      - Добавляйте новые файлы в массив SCRIPT_FILES
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

-- =============================================
-- ⚙️ КОНФИГУРАЦИЯ
-- =============================================

-- Базовый URL вашего репозитория (raw-ссылки GitHub)
-- Формат: https://raw.githubusercontent.com/<USER>/<REPO>/<BRANCH>/
local REPO_BASE_URL = "https://raw.githubusercontent.com/katsunei/roblox-validation-tests/main/"

-- Список всех тестовых файлов (порядок загрузки важен:
-- утилиты загружаются первыми, зависимые скрипты — после)
local SCRIPT_FILES = {
    -- 🔧 Утилиты (загружаются первыми, т.к. другие скрипты могут на них ссылаться)
    { file = "07_whitelist.lua",             name = "Белый список",                enabled = true },
    { file = "06_timing_tool.lua",           name = "Инструмент таймингов",        enabled = true },
    { file = "23_save_load_config.lua",      name = "Менеджер конфигов",           enabled = true },

    -- ⚔️ Боевые симуляции
    { file = "01_style_spoof.lua",           name = "Подмена стиля",               enabled = true },
    { file = "02_dribble_spam.lua",          name = "Спам дриблингом",             enabled = true },
    { file = "03_auto_parry.lua",            name = "Автопарирование",             enabled = true },
    { file = "04_parry_zone_visualizer.lua", name = "Визуализатор парирования",    enabled = true },
    { file = "08_perfect_shot.lua",          name = "Идеальный бросок",            enabled = true },
    { file = "17_no_dodge_cooldown.lua",     name = "Dodge без кулдауна",          enabled = true },

    -- 🏃 Движение
    { file = "05_face_lock.lua",             name = "Face Lock (аимлок)",          enabled = true },
    { file = "09_flight.lua",                name = "Полёт",                       enabled = true },
    { file = "10_speed_hack.lua",            name = "Speed Hack",                  enabled = true },
    { file = "11_infinite_jump.lua",         name = "Бесконечные прыжки",          enabled = true },
    { file = "12_noclip.lua",                name = "Noclip",                      enabled = true },
    { file = "18_teleport_to_player.lua",    name = "Телепортация к игроку",       enabled = true },

    -- 🛡️ Состояния персонажа
    { file = "14_infinite_stamina.lua",      name = "Бесконечная стамина",         enabled = true },
    { file = "15_no_ragdoll.lua",            name = "No Ragdoll",                  enabled = true },
    { file = "16_stun_immunity.lua",         name = "Иммунитет к стану",           enabled = true },

    -- 🔍 Визуализация
    { file = "13_esp.lua",                   name = "ESP",                         enabled = true },

    -- 🔧 Остальные утилиты
    { file = "19_server_hop.lua",            name = "Server Hop",                  enabled = true },
    { file = "20_rejoin.lua",                name = "Rejoin",                      enabled = true },
    { file = "21_anti_afk.lua",              name = "Анти-АФК",                   enabled = true },
    { file = "22_self_kill.lua",             name = "Самоубийство",                enabled = true },
}

-- =============================================
-- 📊 СОСТОЯНИЕ ЗАГРУЗЧИКА
-- =============================================
_G._TestLoaderState = _G._TestLoaderState or {
    LoadedScripts = {},      -- Успешно загруженные скрипты
    FailedScripts = {},      -- Неудачные загрузки
    LoadCount = 0,           -- Счётчик полных загрузок
    LastLoadTime = nil,      -- Время последней загрузки
    SourceCache = {},        -- Кэш исходников (для быстрого перезапуска)
}

local State = _G._TestLoaderState

-- =============================================
-- 🛠️ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- =============================================

-- Форматированный вывод в консоль
local function log(icon, message)
    print(string.format("[Loader] %s %s", icon, message))
end

-- Полоска прогресса в текстовом виде
local function progressBar(current, total, width)
    width = width or 30
    local filled = math.floor((current / total) * width)
    local empty = width - filled
    return string.format("[%s%s] %d/%d",
        string.rep("█", filled),
        string.rep("░", empty),
        current, total
    )
end

-- =============================================
-- 🔽 ЗАГРУЗКА И ВЫПОЛНЕНИЕ ОДНОГО СКРИПТА
-- =============================================
local function loadAndExecuteScript(entry, index, total)
    local url = REPO_BASE_URL .. entry.file
    local displayName = string.format("#%02d %s", index, entry.name)

    -- Шаг 1: Загрузка исходника через HttpGet
    local source
    local fetchSuccess, fetchError = pcall(function()
        source = game:HttpGet(url)
    end)

    if not fetchSuccess or not source or #source == 0 then
        log("❌", string.format("%s — ОШИБКА ЗАГРУЗКИ: %s",
            displayName, tostring(fetchError or "пустой ответ")))
        log("🔗", string.format("URL: %s", url))
        table.insert(State.FailedScripts, {
            File = entry.file,
            Name = entry.name,
            Error = tostring(fetchError or "пустой ответ"),
            Phase = "download",
        })
        return false
    end

    -- Кэшируем исходник для быстрого перезапуска
    State.SourceCache[entry.file] = source

    -- Шаг 2: Компиляция через loadstring
    local func, compileError = loadstring(source)

    if not func then
        log("❌", string.format("%s — ОШИБКА КОМПИЛЯЦИИ: %s",
            displayName, tostring(compileError)))
        table.insert(State.FailedScripts, {
            File = entry.file,
            Name = entry.name,
            Error = tostring(compileError),
            Phase = "compile",
        })
        return false
    end

    -- Шаг 3: Выполнение
    local execSuccess, execError = pcall(func)

    if not execSuccess then
        log("⚠️", string.format("%s — ОШИБКА ВЫПОЛНЕНИЯ: %s",
            displayName, tostring(execError)))
        table.insert(State.FailedScripts, {
            File = entry.file,
            Name = entry.name,
            Error = tostring(execError),
            Phase = "execute",
        })
        return false
    end

    -- Успех
    log("✅", string.format("%s  %s", displayName, progressBar(index, total)))
    table.insert(State.LoadedScripts, {
        File = entry.file,
        Name = entry.name,
    })
    return true
end

-- =============================================
-- 🔽 ВЫПОЛНЕНИЕ ИЗ КЭША (без повторной загрузки)
-- =============================================
local function executeFromCache(entry, index, total)
    local source = State.SourceCache[entry.file]
    local displayName = string.format("#%02d %s", index, entry.name)

    if not source then
        log("⚠️", string.format("%s — нет в кэше, загружаю заново...", displayName))
        return loadAndExecuteScript(entry, index, total)
    end

    local func, compileError = loadstring(source)
    if not func then
        log("❌", string.format("%s — ОШИБКА КОМПИЛЯЦИИ: %s", displayName, tostring(compileError)))
        return false
    end

    local execSuccess, execError = pcall(func)
    if not execSuccess then
        log("⚠️", string.format("%s — ОШИБКА ВЫПОЛНЕНИЯ: %s", displayName, tostring(execError)))
        return false
    end

    log("✅", string.format("%s (из кэша)  %s", displayName, progressBar(index, total)))
    return true
end

-- =============================================
-- 🚀 ГЛАВНАЯ ФУНКЦИЯ ЗАГРУЗКИ
-- =============================================
local function loadAllTests(useCache)
    local startTime = os.clock()
    State.LoadedScripts = {}
    State.FailedScripts = {}
    State.LoadCount = State.LoadCount + 1

    -- Собираем только включённые скрипты
    local enabledScripts = {}
    for _, entry in ipairs(SCRIPT_FILES) do
        if entry.enabled then
            table.insert(enabledScripts, entry)
        end
    end

    local total = #enabledScripts
    local skipped = #SCRIPT_FILES - total

    print("")
    print("╔══════════════════════════════════════════════════╗")
    print("║     🔄 ЗАГРУЗЧИК ТЕСТОВЫХ СКРИПТОВ v1.0         ║")
    print("╠══════════════════════════════════════════════════╣")
    print(string.format("║  Загрузка #%-3d | Скриптов: %-3d | Пропущено: %-3d   ║",
        State.LoadCount, total, skipped))
    print(string.format("║  Режим: %-40s ║",
        useCache and "из кэша (быстрый)" or "загрузка с GitHub"))
    print("╚══════════════════════════════════════════════════╝")
    print("")


    -- Загружаем и выполняем каждый скрипт
    for i, entry in ipairs(enabledScripts) do
        if useCache then
            executeFromCache(entry, i, total)
        else
            loadAndExecuteScript(entry, i, total)
        end

        -- Небольшая пауза между скриптами, чтобы не перегружать
        if i < total then
            task.wait(0.1)
        end
    end

    -- Итоги
    local elapsed = os.clock() - startTime
    State.LastLoadTime = os.date("%H:%M:%S")

    print("")
    print("══════════════════════════════════════════════════")
    log("📊", string.format("ИТОГО: ✅ %d успешно | ❌ %d ошибок | ⏱️ %.1fс",
        #State.LoadedScripts, #State.FailedScripts, elapsed))

    if #State.FailedScripts > 0 then
        print("")
        log("⚠️", "Неудачные загрузки:")
        for _, fail in ipairs(State.FailedScripts) do
            log("  ❌", string.format("%s (%s): %s", fail.Name, fail.Phase, fail.Error))
        end
    end

    print("══════════════════════════════════════════════════")
    print("")
end

-- =============================================
-- 🌐 ГЛОБАЛЬНЫЕ ФУНКЦИИ УПРАВЛЕНИЯ
-- =============================================

--- Перезагрузить все скрипты с GitHub (полная загрузка)
_G.ReloadAllTests = function()
    log("🔄", "Перезагрузка всех скриптов с GitHub...")
    loadAllTests(false)
end

--- Перезапустить скрипты из кэша (без повторной загрузки)
_G.RestartAllTests = function()
    if next(State.SourceCache) == nil then
        log("⚠️", "Кэш пуст — выполняю полную загрузку")
        loadAllTests(false)
    else
        log("⚡", "Быстрый перезапуск из кэша...")
        loadAllTests(true)
    end
end

--- Загрузить один конкретный скрипт по имени файла или номеру
_G.LoadTest = function(identifier)
    for i, entry in ipairs(SCRIPT_FILES) do
        local match = false
        if type(identifier) == "number" then
            match = (i == identifier)
        elseif type(identifier) == "string" then
            match = (entry.file == identifier) 
                or (entry.file:find(identifier)) 
                or (entry.name:lower():find(identifier:lower()))
        end

        if match then
            log("🔽", string.format("Загрузка: %s (%s)", entry.name, entry.file))
            loadAndExecuteScript(entry, i, #SCRIPT_FILES)
            return
        end
    end

    log("❌", "Скрипт не найден: " .. tostring(identifier))
    log("💡", "Используйте _G.ListTests() для списка")
end

--- Включить/выключить конкретный скрипт по имени
_G.ToggleTest = function(identifier, enabled)
    for _, entry in ipairs(SCRIPT_FILES) do
        local match = (entry.file:find(tostring(identifier))) 
            or (entry.name:lower():find(tostring(identifier):lower()))

        if match then
            entry.enabled = (enabled ~= false)
            local status = entry.enabled and "✅ ВКЛ" or "❌ ВЫКЛ"
            log("🔀", string.format("%s: %s", entry.name, status))
            return
        end
    end

    log("❌", "Скрипт не найден: " .. tostring(identifier))
end

--- Показать список всех тестовых скриптов
_G.ListTests = function()
    print("")
    print("╔══════════════════════════════════════════════════╗")
    print("║          📋 СПИСОК ТЕСТОВЫХ СКРИПТОВ             ║")
    print("╚══════════════════════════════════════════════════╝")

    for i, entry in ipairs(SCRIPT_FILES) do
        local status = entry.enabled and "✅" or "⬜"
        local cached = State.SourceCache[entry.file] and "💾" or "  "
        print(string.format("  %s %s %02d. %-30s  %s",
            status, cached, i, entry.name, entry.file))
    end

    print("")
    print("  ✅ = включён | ⬜ = выключен | 💾 = в кэше")
    print("")
end

--- Показать статус загрузчика
_G.LoaderStatus = function()
    print("")
    print("═══ СТАТУС ЗАГРУЗЧИКА ═══")
    print(string.format("  Загрузок:         %d", State.LoadCount))
    print(string.format("  Последняя:        %s", State.LastLoadTime or "—"))
    print(string.format("  Успешно:          %d", #State.LoadedScripts))
    print(string.format("  С ошибками:       %d", #State.FailedScripts))

    local cachedCount = 0
    for _ in pairs(State.SourceCache) do cachedCount = cachedCount + 1 end
    print(string.format("  В кэше:           %d", cachedCount))

    local enabledCount = 0
    for _, entry in ipairs(SCRIPT_FILES) do
        if entry.enabled then enabledCount = enabledCount + 1 end
    end
    print(string.format("  Включено:         %d/%d", enabledCount, #SCRIPT_FILES))
    print("═════════════════════════")
    print("")
end

--- Изменить базовый URL репозитория
_G.SetRepoURL = function(url)
    -- Убеждаемся, что URL заканчивается на /
    if url:sub(-1) ~= "/" then
        url = url .. "/"
    end
    REPO_BASE_URL = url
    log("🔗", "Базовый URL изменён: " .. url)
end

--- Очистить кэш (следующий перезапуск загрузит всё заново)
_G.ClearTestCache = function()
    State.SourceCache = {}
    log("🧹", "Кэш исходников очищен")
end

-- =============================================
-- 🚀 АВТОЗАПУСК ПРИ ПЕРВОЙ ВСТАВКЕ
-- =============================================
print("")
print("╔══════════════════════════════════════════════════╗")
print("║   🔄 ЗАГРУЗЧИК ТЕСТОВ СЕРВЕРНОЙ ВАЛИДАЦИИ        ║")
print("╠══════════════════════════════════════════════════╣")
print("║                                                  ║")
print("║  Команды:                                        ║")
print("║    _G.ReloadAllTests()  — загрузить с GitHub      ║")
print("║    _G.RestartAllTests() — перезапуск из кэша      ║")
print("║    _G.LoadTest('noclip') — один скрипт            ║")
print("║    _G.ListTests()       — список скриптов         ║")
print("║    _G.ToggleTest('esp', false) — вкл/выкл         ║")
print("║    _G.LoaderStatus()    — статус загрузчика       ║")
print("║    _G.SetRepoURL(url)   — сменить репозиторий     ║")
print("║    _G.ClearTestCache()  — очистить кэш            ║")
print("║                                                  ║")
print("╚══════════════════════════════════════════════════╝")
print("")

-- Автоматически запускаем загрузку
loadAllTests(false)
