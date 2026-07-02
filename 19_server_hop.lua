--[[
    ============================================================
    Скрипт #19: Эмуляция Server Hop
    ============================================================
    Назначение:
        Имитирует переподключение игрока к тому же серверу
        через TeleportService. Сохраняет состояние перед
        телепортом и проверяет его восстановление после.
    
    Тестируемая уязвимость:
        Проверяет, корректно ли сервер сохраняет и
        восстанавливает данные игрока при server hop.
        Некорректная обработка может привести к дупликации
        предметов или потере прогресса.
    
    Использование:
        Вставить в CommandBar в Roblox Studio.
        В Studio TeleportService может не работать полностью,
        поэтому предусмотрен мок-режим.
    ============================================================
--]]

-- === Сервисы ===
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- === Конфигурация ===
local CONFIG = {
    USE_MOCK = true,              -- Использовать мок-режим (для Studio)
    DATASTORE_NAME = "ServerHopTestStore", -- Имя DataStore для сохранения
    SAVE_KEY_PREFIX = "hop_state_", -- Префикс ключа сохранения
    HOP_DELAY = 2,                -- Задержка перед телепортом (секунды)
    LOG_VERBOSE = true,           -- Подробное логирование
}

-- === Утилиты логирования ===
local LOG_PREFIX = "[ServerHop]"

local function log(msg)
    print(LOG_PREFIX .. " " .. tostring(msg))
end

local function logVerbose(msg)
    if CONFIG.LOG_VERBOSE then
        print(LOG_PREFIX .. " [ПОДРОБНО] " .. tostring(msg))
    end
end

local function logWarning(msg)
    warn(LOG_PREFIX .. " [ПРЕДУПРЕЖДЕНИЕ] " .. tostring(msg))
end

local function logError(msg)
    warn(LOG_PREFIX .. " [ОШИБКА] " .. tostring(msg))
end

local function logSuccess(msg)
    print(LOG_PREFIX .. " [УСПЕХ] ✓ " .. tostring(msg))
end

-- === Инициализация глобального хранилища ===
if not _G.ServerHopData then
    _G.ServerHopData = {
        PreHopState = nil,    -- Состояние перед телепортом
        PostHopState = nil,   -- Состояние после телепорта
        HopCount = 0,         -- Счётчик телепортов
        HopHistory = {},      -- История телепортов
        IsHopping = false,    -- Флаг процесса телепорта
    }
end

-- === Сбор состояния игрока ===
local function collectPlayerState(player)
    -- Собираем полное состояние игрока
    local state = {
        Timestamp = os.time(),
        TimestampFormatted = os.date("%Y-%m-%d %H:%M:%S"),
        UserId = player.UserId,
        Name = player.Name,
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        Position = nil,
        Health = nil,
        MaxHealth = nil,
        WalkSpeed = nil,
        JumpPower = nil,
        Inventory = {},
        Leaderstats = {},
        Attributes = {},
    }
    
    -- Позиция и здоровье персонажа
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if rootPart then
            state.Position = {
                X = math.floor(rootPart.Position.X * 100) / 100,
                Y = math.floor(rootPart.Position.Y * 100) / 100,
                Z = math.floor(rootPart.Position.Z * 100) / 100,
            }
            logVerbose("Позиция: " .. rootPart.Position.X .. ", " .. rootPart.Position.Y .. ", " .. rootPart.Position.Z)
        end
        
        if humanoid then
            state.Health = humanoid.Health
            state.MaxHealth = humanoid.MaxHealth
            state.WalkSpeed = humanoid.WalkSpeed
            state.JumpPower = humanoid.JumpPower
            logVerbose("Здоровье: " .. humanoid.Health .. "/" .. humanoid.MaxHealth)
            logVerbose("Скорость: " .. humanoid.WalkSpeed .. ", Прыжок: " .. humanoid.JumpPower)
        end
    else
        logWarning("Персонаж не найден, данные позиции/здоровья пропущены")
    end
    
    -- Инвентарь (Backpack)
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(state.Inventory, {
                    Name = tool.Name,
                    ClassName = tool.ClassName,
                    ToolTip = tool.ToolTip or "",
                })
            end
        end
        logVerbose("Предметы в инвентаре: " .. #state.Inventory)
    end
    
    -- Экипированные инструменты
    if character then
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(state.Inventory, {
                    Name = tool.Name,
                    ClassName = tool.ClassName,
                    ToolTip = tool.ToolTip or "",
                    Equipped = true,
                })
            end
        end
    end
    
    -- Leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            state.Leaderstats[stat.Name] = stat.Value
            logVerbose("Статистика: " .. stat.Name .. " = " .. tostring(stat.Value))
        end
    end
    
    -- Атрибуты игрока
    for attrName, attrValue in pairs(player:GetAttributes()) do
        state.Attributes[attrName] = attrValue
        logVerbose("Атрибут: " .. attrName .. " = " .. tostring(attrValue))
    end
    
    return state
end

-- === Сохранение состояния ===
local function saveState(player, state)
    log("Сохранение состояния игрока...")
    
    -- Сохранение в _G (всегда доступно)
    _G.ServerHopData.PreHopState = state
    logSuccess("Состояние сохранено в _G.ServerHopData.PreHopState")
    
    -- Попытка сохранения в DataStore
    local success, err = pcall(function()
        local dataStore = DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)
        local key = CONFIG.SAVE_KEY_PREFIX .. tostring(player.UserId)
        local serialized = HttpService:JSONEncode(state)
        dataStore:SetAsync(key, serialized)
        logSuccess("Состояние сохранено в DataStore (ключ: " .. key .. ")")
    end)
    
    if not success then
        logWarning("Не удалось сохранить в DataStore: " .. tostring(err))
        logWarning("Используется только _G хранилище")
    end
    
    return true
end

-- === Загрузка состояния ===
local function loadSavedState(player)
    log("Загрузка сохранённого состояния...")
    
    -- Сначала проверяем _G
    if _G.ServerHopData.PreHopState then
        logSuccess("Состояние найдено в _G")
        return _G.ServerHopData.PreHopState
    end
    
    -- Попытка загрузки из DataStore
    local savedState = nil
    local success, err = pcall(function()
        local dataStore = DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)
        local key = CONFIG.SAVE_KEY_PREFIX .. tostring(player.UserId)
        local data = dataStore:GetAsync(key)
        if data then
            savedState = HttpService:JSONDecode(data)
            logSuccess("Состояние загружено из DataStore")
        end
    end)
    
    if not success then
        logWarning("Не удалось загрузить из DataStore: " .. tostring(err))
    end
    
    return savedState
end

-- === Сравнение состояний ===
local function compareStates(before, after)
    log("═══════════════════════════════════════════")
    log("  СРАВНЕНИЕ СОСТОЯНИЙ (ДО и ПОСЛЕ)")
    log("═══════════════════════════════════════════")
    
    local differences = {}
    local matches = 0
    local mismatches = 0
    
    -- Сравнение позиции
    if before.Position and after.Position then
        local dx = math.abs((before.Position.X or 0) - (after.Position.X or 0))
        local dy = math.abs((before.Position.Y or 0) - (after.Position.Y or 0))
        local dz = math.abs((before.Position.Z or 0) - (after.Position.Z or 0))
        local totalDist = math.sqrt(dx*dx + dy*dy + dz*dz)
        
        if totalDist < 1 then
            logSuccess("Позиция сохранена (отклонение: " .. string.format("%.2f", totalDist) .. " стадов)")
            matches = matches + 1
        else
            logWarning("Позиция изменилась! Отклонение: " .. string.format("%.2f", totalDist) .. " стадов")
            table.insert(differences, "Позиция сдвинулась на " .. string.format("%.2f", totalDist) .. " стадов")
            mismatches = mismatches + 1
        end
    end
    
    -- Сравнение здоровья
    if before.Health and after.Health then
        if math.abs(before.Health - after.Health) < 0.1 then
            logSuccess("Здоровье сохранено: " .. after.Health)
            matches = matches + 1
        else
            logWarning("Здоровье изменилось: " .. before.Health .. " -> " .. after.Health)
            table.insert(differences, "Здоровье: " .. before.Health .. " -> " .. after.Health)
            mismatches = mismatches + 1
        end
    end
    
    -- Сравнение скорости
    if before.WalkSpeed and after.WalkSpeed then
        if before.WalkSpeed == after.WalkSpeed then
            logSuccess("Скорость сохранена: " .. after.WalkSpeed)
            matches = matches + 1
        else
            logWarning("Скорость изменилась: " .. before.WalkSpeed .. " -> " .. after.WalkSpeed)
            table.insert(differences, "Скорость: " .. before.WalkSpeed .. " -> " .. after.WalkSpeed)
            mismatches = mismatches + 1
        end
    end
    
    -- Сравнение инвентаря
    local beforeItems = #(before.Inventory or {})
    local afterItems = #(after.Inventory or {})
    if beforeItems == afterItems then
        logSuccess("Количество предметов сохранено: " .. afterItems)
        matches = matches + 1
    else
        logWarning("Количество предметов изменилось: " .. beforeItems .. " -> " .. afterItems)
        table.insert(differences, "Предметы: " .. beforeItems .. " -> " .. afterItems)
        mismatches = mismatches + 1
    end
    
    -- Сравнение leaderstats
    for statName, statValue in pairs(before.Leaderstats or {}) do
        local afterValue = (after.Leaderstats or {})[statName]
        if afterValue ~= nil then
            if statValue == afterValue then
                logSuccess("Статистика '" .. statName .. "' сохранена: " .. tostring(afterValue))
                matches = matches + 1
            else
                logWarning("Статистика '" .. statName .. "' изменилась: " .. tostring(statValue) .. " -> " .. tostring(afterValue))
                table.insert(differences, statName .. ": " .. tostring(statValue) .. " -> " .. tostring(afterValue))
                mismatches = mismatches + 1
            end
        else
            logWarning("Статистика '" .. statName .. "' отсутствует после хопа!")
            table.insert(differences, statName .. " утерян")
            mismatches = mismatches + 1
        end
    end
    
    -- Итоговый отчёт
    log("═══════════════════════════════════════════")
    log("  ИТОГ СРАВНЕНИЯ:")
    log("    Совпадений: " .. matches)
    log("    Расхождений: " .. mismatches)
    if #differences > 0 then
        log("  Обнаруженные различия:")
        for i, diff in ipairs(differences) do
            log("    " .. i .. ". " .. diff)
        end
    else
        logSuccess("Все проверенные параметры совпадают!")
    end
    log("═══════════════════════════════════════════")
    
    return {
        Matches = matches,
        Mismatches = mismatches,
        Differences = differences,
    }
end

-- === Мок-телепорт (имитация для Studio) ===
local function mockServerHop(player, state)
    log("╔═══════════════════════════════════════════╗")
    log("║  МОК-РЕЖИМ: Имитация Server Hop           ║")
    log("╚═══════════════════════════════════════════╝")
    
    log("Шаг 1: Состояние сохранено (до телепорта)")
    log("  Время: " .. (state.TimestampFormatted or "N/A"))
    log("  Место: PlaceId=" .. tostring(state.PlaceId))
    
    -- Имитация задержки переподключения
    log("Шаг 2: Имитация отключения от сервера...")
    wait(1)
    
    log("Шаг 3: Имитация подключения к новому серверу...")
    wait(1)
    
    -- Сбор состояния "после" переподключения
    log("Шаг 4: Сбор состояния после переподключения...")
    local postState = collectPlayerState(player)
    _G.ServerHopData.PostHopState = postState
    
    -- Сравнение
    log("Шаг 5: Сравнение состояний...")
    local result = compareStates(state, postState)
    
    -- Запись в историю
    _G.ServerHopData.HopCount = _G.ServerHopData.HopCount + 1
    table.insert(_G.ServerHopData.HopHistory, {
        HopNumber = _G.ServerHopData.HopCount,
        Timestamp = os.time(),
        PreState = state,
        PostState = postState,
        ComparisonResult = result,
        Mode = "mock",
    })
    
    log("Мок-хоп #" .. _G.ServerHopData.HopCount .. " завершён")
    
    return result
end

-- === Реальный телепорт ===
local function realServerHop(player, state)
    log("╔═══════════════════════════════════════════╗")
    log("║  РЕАЛЬНЫЙ Server Hop                      ║")
    log("╚═══════════════════════════════════════════╝")
    
    _G.ServerHopData.IsHopping = true
    _G.ServerHopData.HopCount = _G.ServerHopData.HopCount + 1
    
    log("Сохранение состояния перед телепортом...")
    saveState(player, state)
    
    log("Инициация телепорта на PlaceId: " .. game.PlaceId)
    
    local success, err = pcall(function()
        TeleportService:Teleport(game.PlaceId, player)
    end)
    
    if not success then
        logError("Телепорт не удался: " .. tostring(err))
        logWarning("Переключение на мок-режим...")
        _G.ServerHopData.IsHopping = false
        return mockServerHop(player, state)
    end
    
    log("Запрос на телепорт отправлен. Ожидание переподключения...")
    return nil -- Результат будет доступен после переподключения
end

-- === Проверка состояния после возврата ===
local function checkPostHopState(player)
    log("Проверка: был ли выполнен server hop ранее...")
    
    local savedState = loadSavedState(player)
    
    if savedState then
        log("Обнаружено сохранённое состояние от " .. (savedState.TimestampFormatted or "N/A"))
        
        local currentState = collectPlayerState(player)
        _G.ServerHopData.PostHopState = currentState
        
        local result = compareStates(savedState, currentState)
        
        -- Очистка сохранённого состояния
        _G.ServerHopData.PreHopState = nil
        _G.ServerHopData.IsHopping = false
        
        return result
    else
        log("Сохранённое состояние не найдено (первый запуск или данные утеряны)")
        return nil
    end
end

-- === Вывод полного состояния ===
local function printFullState(label, state)
    log("┌─────────────────────────────────────────┐")
    log("│ " .. label)
    log("├─────────────────────────────────────────┤")
    log("│ Время: " .. (state.TimestampFormatted or "N/A"))
    log("│ Игрок: " .. (state.Name or "N/A") .. " (ID: " .. tostring(state.UserId) .. ")")
    log("│ PlaceId: " .. tostring(state.PlaceId))
    log("│ JobId: " .. tostring(state.JobId))
    
    if state.Position then
        log("│ Позиция: (" .. state.Position.X .. ", " .. state.Position.Y .. ", " .. state.Position.Z .. ")")
    end
    
    log("│ Здоровье: " .. tostring(state.Health) .. "/" .. tostring(state.MaxHealth))
    log("│ Скорость: " .. tostring(state.WalkSpeed))
    log("│ Прыжок: " .. tostring(state.JumpPower))
    log("│ Предметов: " .. #(state.Inventory or {}))
    
    if state.Inventory and #state.Inventory > 0 then
        for _, item in ipairs(state.Inventory) do
            local equipped = item.Equipped and " [ЭКИПИРОВАН]" or ""
            log("│   • " .. item.Name .. equipped)
        end
    end
    
    if state.Leaderstats then
        for k, v in pairs(state.Leaderstats) do
            log("│ [Стат] " .. k .. " = " .. tostring(v))
        end
    end
    
    log("└─────────────────────────────────────────┘")
end

-- === Главная функция ===
local function main()
    log("╔═══════════════════════════════════════════════╗")
    log("║  ТЕСТ #19: Эмуляция Server Hop               ║")
    log("╚═══════════════════════════════════════════════╝")
    
    local player = Players.LocalPlayer
    if not player then
        logError("LocalPlayer не найден!")
        return
    end
    
    log("Игрок: " .. player.Name)
    log("PlaceId: " .. game.PlaceId)
    log("JobId: " .. game.JobId)
    log("Режим: " .. (CONFIG.USE_MOCK and "МОК (имитация)" or "РЕАЛЬНЫЙ телепорт"))
    log("")
    
    -- Проверяем, не возврат ли это после хопа
    local postHopResult = checkPostHopState(player)
    if postHopResult then
        log("Это возврат после server hop! Результаты сравнения выше.")
        return
    end
    
    -- Сбор текущего состояния
    log("Сбор текущего состояния игрока...")
    local currentState = collectPlayerState(player)
    
    -- Вывод полного состояния
    printFullState("СОСТОЯНИЕ ДО SERVER HOP", currentState)
    
    -- Задержка перед хопом
    log("Подготовка к server hop через " .. CONFIG.HOP_DELAY .. " сек...")
    wait(CONFIG.HOP_DELAY)
    
    -- Выполнение хопа
    local result
    if CONFIG.USE_MOCK then
        result = mockServerHop(player, currentState)
    else
        result = realServerHop(player, currentState)
    end
    
    -- Вывод состояния после (если мок)
    if result and _G.ServerHopData.PostHopState then
        printFullState("СОСТОЯНИЕ ПОСЛЕ SERVER HOP", _G.ServerHopData.PostHopState)
    end
    
    -- Итоговая сводка
    log("")
    log("╔═══════════════════════════════════════════════╗")
    log("║  ИТОГОВАЯ СВОДКА                              ║")
    log("╠═══════════════════════════════════════════════╣")
    log("║ Всего хопов: " .. _G.ServerHopData.HopCount)
    if result then
        log("║ Совпадений: " .. result.Matches)
        log("║ Расхождений: " .. result.Mismatches)
        if result.Mismatches > 0 then
            log("║ ⚠ ВНИМАНИЕ: Обнаружены расхождения в данных!")
            log("║   Это может указывать на проблемы с сохранением")
        else
            logSuccess("Все данные сохранены корректно")
        end
    end
    log("╚═══════════════════════════════════════════════╝")
    log("Данные доступны в _G.ServerHopData")
end

-- === Запуск ===
main()
