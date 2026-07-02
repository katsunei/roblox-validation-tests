--[[
    ============================================================
    СОХРАНЕНИЕ / ЗАГРУЗКА НАСТРОЕК ТЕСТОВ
    ============================================================
    Назначение: Позволяет сохранять и загружать комбинации
    активных симуляций, чтобы не включать всё вручную.
    
    Включает пресеты для типовых сценариев тестирования.
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

local HttpService = game:GetService("HttpService")

-- =============================================
-- СТРУКТУРА КОНФИГУРАЦИИ
-- =============================================
local DEFAULT_CONFIG = {
    -- Боевые симуляции
    StyleSpoof = false,
    DribbleSpam = false,
    AutoParry = false,
    FaceLock = false,
    PerfectShot = false,
    NoDodgeCooldown = false,
    StunImmunity = false,
    NoRagdoll = false,
    
    -- Движение
    Flight = false,
    SpeedHack = false,
    InfiniteJump = false,
    Noclip = false,
    TeleportToPlayer = false,
    
    -- Ресурсы
    InfiniteStamina = false,
    
    -- Утилиты
    ESP = false,
    AntiAFK = false,
    ParryVisualizer = false,
    
    -- Настройки параметров
    SpeedHackValue = 100,
    ParryRadius = 10,
    TeleportTarget = "",
    TimingDribbleDelay = 0.5,
    TimingParryDelay = 0.3,
    TimingDodgeDelay = 1.0,
}

-- =============================================
-- ХРАНИЛИЩЕ
-- =============================================
_G.SavedConfigs = _G.SavedConfigs or {}
_G.ActiveConfig = _G.ActiveConfig or {}

-- Копируем дефолтную конфигурацию
for k, v in pairs(DEFAULT_CONFIG) do
    if _G.ActiveConfig[k] == nil then
        _G.ActiveConfig[k] = v
    end
end

-- =============================================
-- ПРЕСЕТЫ
-- =============================================
local PRESETS = {
    movement_tests = {
        _name = "Тесты движения",
        _description = "Проверка серверной валидации позиции и скорости",
        Flight = true,
        SpeedHack = true,
        InfiniteJump = true,
        Noclip = true,
        TeleportToPlayer = true,
        SpeedHackValue = 100,
    },
    
    combat_tests = {
        _name = "Тесты боя",
        _description = "Проверка боевых механик и кулдаунов",
        AutoParry = true,
        FaceLock = true,
        NoDodgeCooldown = true,
        StunImmunity = true,
        NoRagdoll = true,
        DribbleSpam = true,
        ParryVisualizer = true,
    },
    
    resource_tests = {
        _name = "Тесты ресурсов",
        _description = "Проверка серверной синхронизации ресурсов",
        InfiniteStamina = true,
        AntiAFK = true,
    },
    
    visual_tests = {
        _name = "Визуальные тесты",
        _description = "ESP и визуализация (клиентская утечка данных)",
        ESP = true,
        ParryVisualizer = true,
        FaceLock = true,
    },
    
    full_suite = {
        _name = "Полный набор",
        _description = "Все симуляции включены (максимальная нагрузка)",
        StyleSpoof = true,
        DribbleSpam = true,
        AutoParry = true,
        FaceLock = true,
        PerfectShot = true,
        NoDodgeCooldown = true,
        StunImmunity = true,
        NoRagdoll = true,
        Flight = true,
        SpeedHack = true,
        InfiniteJump = true,
        Noclip = true,
        TeleportToPlayer = true,
        InfiniteStamina = true,
        ESP = true,
        AntiAFK = true,
        ParryVisualizer = true,
    },
}

-- =============================================
-- ФУНКЦИИ СОХРАНЕНИЯ / ЗАГРУЗКИ
-- =============================================

-- Сохранить текущую конфигурацию
_G.SaveConfig = function(name)
    if not name or name == "" then
        print("[Config] ❌ Укажите имя: _G.SaveConfig('my_config')")
        return
    end
    
    -- Создаём копию текущей конфигурации
    local configCopy = {}
    for k, v in pairs(_G.ActiveConfig) do
        configCopy[k] = v
    end
    configCopy._savedAt = os.date("%Y-%m-%d %H:%M:%S")
    configCopy._name = name
    
    _G.SavedConfigs[name] = configCopy
    
    -- Сериализуем в JSON для отображения
    local success, json = pcall(function()
        return HttpService:JSONEncode(configCopy)
    end)
    
    print(string.format("[Config] ✅ Конфигурация '%s' сохранена", name))
    
    if success then
        print("[Config] JSON (для копирования):")
        print(json)
    end
    
    return configCopy
end

-- Загрузить конфигурацию
_G.LoadConfig = function(name)
    if not name or name == "" then
        print("[Config] ❌ Укажите имя: _G.LoadConfig('my_config')")
        return
    end
    
    -- Сначала проверяем сохранённые конфиги
    local config = _G.SavedConfigs[name]
    
    -- Затем проверяем пресеты
    if not config then
        config = PRESETS[name]
    end
    
    if not config then
        print(string.format("[Config] ❌ Конфигурация '%s' не найдена!", name))
        print("  Доступные: ")
        _G.ListConfigs()
        return
    end
    
    -- Сбрасываем до дефолтных значений
    for k, v in pairs(DEFAULT_CONFIG) do
        _G.ActiveConfig[k] = v
    end
    
    -- Применяем загруженную конфигурацию
    local enabledCount = 0
    for k, v in pairs(config) do
        if k:sub(1, 1) ~= "_" then  -- Пропускаем мета-поля
            _G.ActiveConfig[k] = v
            if v == true then
                enabledCount = enabledCount + 1
            end
        end
    end
    
    local displayName = config._name or name
    print(string.format("[Config] ✅ Загружена: '%s'", displayName))
    if config._description then
        print(string.format("  📝 %s", config._description))
    end
    print(string.format("  Активных симуляций: %d", enabledCount))
    
    -- Применяем к глобальным конфигам других скриптов
    applyToRunningScripts()
    
    return _G.ActiveConfig
end

-- Применить конфигурацию к запущенным скриптам
function applyToRunningScripts()
    -- SpeedHack
    if _G.SpeedHackConfig then
        -- Не управляем включением напрямую, только параметры
    end
    
    -- FaceLock
    if _G.FaceLockConfig then
        _G.FaceLockConfig.Enabled = _G.ActiveConfig.FaceLock
    end
    
    -- Noclip
    if _G.NoclipConfig then
        _G.NoclipConfig.Enabled = _G.ActiveConfig.Noclip
    end
    
    -- InfiniteJump
    if _G.InfJumpConfig then
        _G.InfJumpConfig.Enabled = _G.ActiveConfig.InfiniteJump
    end
    
    -- StunImmunity
    if _G.StunImmunityConfig then
        _G.StunImmunityConfig.Enabled = _G.ActiveConfig.StunImmunity
    end
    
    -- NoRagdoll
    if _G.NoRagdollConfig then
        _G.NoRagdollConfig.Enabled = _G.ActiveConfig.NoRagdoll
    end
    
    -- NoDodgeCD
    if _G.NoDodgeCDConfig then
        _G.NoDodgeCDConfig.Enabled = _G.ActiveConfig.NoDodgeCooldown
    end
    
    -- AntiAFK
    if _G.AntiAFKConfig then
        _G.AntiAFKConfig.Enabled = _G.ActiveConfig.AntiAFK
    end
    
    -- ParryVisualizer
    if _G.ParryVisualizerConfig then
        _G.ParryVisualizerConfig.ParryRadius = _G.ActiveConfig.ParryRadius
    end
    
    -- Timings
    if _G.TimingConfig then
        _G.TimingConfig.DribbleDelay = _G.ActiveConfig.TimingDribbleDelay
        _G.TimingConfig.ParryDelay = _G.ActiveConfig.TimingParryDelay
        _G.TimingConfig.DodgeDelay = _G.ActiveConfig.TimingDodgeDelay
    end
    
    print("[Config] Настройки применены к запущенным скриптам")
end

-- Список всех конфигураций
_G.ListConfigs = function()
    print("╔════════════════════════════════════════════╗")
    print("║        ДОСТУПНЫЕ КОНФИГУРАЦИИ              ║")
    print("╚════════════════════════════════════════════╝")
    
    print("\n📦 Пресеты:")
    for name, preset in pairs(PRESETS) do
        local count = 0
        for k, v in pairs(preset) do
            if v == true then count = count + 1 end
        end
        print(string.format("  • %s (%d симуляций) — %s", 
            name, count, preset._description or ""))
    end
    
    print("\n💾 Сохранённые:")
    local hasSaved = false
    for name, config in pairs(_G.SavedConfigs) do
        hasSaved = true
        print(string.format("  • %s (сохранено: %s)", 
            name, config._savedAt or "?"))
    end
    if not hasSaved then
        print("  (нет сохранённых конфигураций)")
    end
    
    print("")
end

-- Показать текущую конфигурацию
_G.ShowConfig = function()
    print("╔════════════════════════════════════════════╗")
    print("║        ТЕКУЩАЯ КОНФИГУРАЦИЯ                ║")
    print("╚════════════════════════════════════════════╝")
    
    local categories = {
        {"⚔️  Бой", {"StyleSpoof", "DribbleSpam", "AutoParry", "FaceLock", 
                     "PerfectShot", "NoDodgeCooldown", "StunImmunity", "NoRagdoll"}},
        {"🏃 Движение", {"Flight", "SpeedHack", "InfiniteJump", "Noclip", "TeleportToPlayer"}},
        {"⚡ Ресурсы", {"InfiniteStamina"}},
        {"🔧 Утилиты", {"ESP", "AntiAFK", "ParryVisualizer"}},
    }
    
    for _, cat in ipairs(categories) do
        print("\n  " .. cat[1] .. ":")
        for _, key in ipairs(cat[2]) do
            local val = _G.ActiveConfig[key]
            local icon = val and "✅" or "⬜"
            print(string.format("    %s %s", icon, key))
        end
    end
    
    print("\n  📊 Параметры:")
    print(string.format("    SpeedHackValue: %d", _G.ActiveConfig.SpeedHackValue or 100))
    print(string.format("    ParryRadius: %d", _G.ActiveConfig.ParryRadius or 10))
    print(string.format("    TeleportTarget: '%s'", _G.ActiveConfig.TeleportTarget or ""))
    print("")
end

-- Загрузить из JSON строки
_G.LoadConfigFromJSON = function(jsonStr)
    local success, config = pcall(function()
        return HttpService:JSONDecode(jsonStr)
    end)
    
    if not success then
        print("[Config] ❌ Ошибка парсинга JSON: " .. tostring(config))
        return
    end
    
    for k, v in pairs(config) do
        if k:sub(1, 1) ~= "_" then
            _G.ActiveConfig[k] = v
        end
    end
    
    applyToRunningScripts()
    print("[Config] ✅ Конфигурация загружена из JSON")
    _G.ShowConfig()
end

-- Переключить отдельную симуляцию
_G.Toggle = function(simName)
    if _G.ActiveConfig[simName] == nil then
        print("[Config] ❌ Неизвестная симуляция: " .. tostring(simName))
        return
    end
    
    _G.ActiveConfig[simName] = not _G.ActiveConfig[simName]
    local status = _G.ActiveConfig[simName] and "✅ ВКЛ" or "❌ ВЫКЛ"
    print(string.format("[Config] %s: %s", simName, status))
    
    applyToRunningScripts()
end

-- Создать пресет из текущей конфигурации
_G.CreatePreset = function(presetName)
    if not presetName then
        print("[Config] ❌ Укажите имя пресета!")
        return
    end
    
    local preset = {}
    for k, v in pairs(_G.ActiveConfig) do
        preset[k] = v
    end
    preset._name = presetName
    preset._description = "Пользовательский пресет"
    
    PRESETS[presetName] = preset
    print(string.format("[Config] ✅ Пресет '%s' создан", presetName))
end

-- =============================================
-- ИНИЦИАЛИЗАЦИЯ
-- =============================================
print("============================================")
print("  МЕНЕДЖЕР КОНФИГУРАЦИЙ ТЕСТОВ")
print("============================================")
print("")
print("Команды:")
print("  _G.ShowConfig()                   -- текущие настройки")
print("  _G.ListConfigs()                  -- все конфигурации")
print("  _G.LoadConfig('combat_tests')     -- загрузить пресет")
print("  _G.LoadConfig('movement_tests')   -- загрузить пресет")
print("  _G.SaveConfig('my_config')        -- сохранить текущую")
print("  _G.Toggle('SpeedHack')            -- переключить симуляцию")
print("  _G.CreatePreset('my_preset')      -- создать пресет")
print("  _G.LoadConfigFromJSON('{...}')    -- загрузить из JSON")
print("")
print("Доступные пресеты:")
for name, preset in pairs(PRESETS) do
    print(string.format("  • %s — %s", name, preset._description or ""))
end
print("============================================")
