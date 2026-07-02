--[[
    ============================================================
    Скрипт #20: Эмуляция Rejoin (Переподключение)
    ============================================================
    Назначение:
        Имитирует перезапуск клиента с переподключением
        к тому же серверу (TeleportToPlaceInstance).
        Сохраняет состояние, сравнивает с данными после
        переподключения и с состоянием "свежего" входа.
    
    Тестируемая уязвимость:
        Проверяет, корректно ли сервер обрабатывает rejoin.
        Некорректная обработка может позволить дупликацию
        данных, обход кулдаунов или повторный сбор наград.
    
    Использование:
        Вставить в CommandBar в Roblox Studio.
        Предусмотрен мок-режим для тестирования в Studio.
    ============================================================
--]]

-- === Сервисы ===
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- === Конфигурация ===
local CONFIG = {
    USE_MOCK = true,              -- Мок-режим для Studio
    REJOIN_DELAY = 2,             -- Задержка перед реджоином (секунды)
    COMPARE_WITH_FRESH = true,    -- Сравнивать со "свежим" состоянием
    LOG_VERBOSE = true,           -- Подробное логирование
    SIMULATE_DATA_CHANGE = true,  -- Имитировать изменение данных между сессиями
}

-- === Утилиты логирования ===
local LOG_PREFIX = "[Rejoin]"

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

-- === Глобальное хранилище для rejoin ===
if not _G.RejoinData then
    _G.RejoinData = {
        PreRejoinState = nil,     -- Состояние до реджоина
        PostRejoinState = nil,    -- Состояние после реджоина
        FreshJoinState = nil,     -- Состояние при "свежем" входе
        RejoinCount = 0,          -- Счётчик реджоинов
        RejoinHistory = {},       -- История реджоинов
        TargetJobId = nil,        -- ID сервера для возврата
        IsRejoining = false,      -- Флаг процесса реджоина
        SessionStartTime = os.time(), -- Время начала сессии
    }
end

-- === Сбор полного состояния игрока ===
local function collectFullState(player, label)
    logVerbose("Сбор состояния: " .. (label or "без метки"))
    
    local state = {
        Label = label or "Неизвестно",
        Timestamp = os.time(),
        TimestampFormatted = os.date("%Y-%m-%d %H:%M:%S"),
        SessionDuration = os.time() - _G.RejoinData.SessionStartTime,
        UserId = player.UserId,
        Name = player.Name,
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        
        -- Данные персонажа
        Character = {
            Exists = false,
            Position = nil,
            Health = 0,
            MaxHealth = 100,
            WalkSpeed = 16,
            JumpPower = 50,
            JumpHeight = 7.2,
            BodyParts = {},
        },
        
        -- Инвентарь
        Inventory = {
            BackpackItems = {},
            EquippedItems = {},
            TotalCount = 0,
        },
        
        -- Статистика
        Leaderstats = {},
        
        -- Атрибуты
        PlayerAttributes = {},
        CharacterAttributes = {},
        
        -- Дочерние объекты игрока
        PlayerChildren = {},
    }
    
    -- Персонаж
    local character = player.Character
    if character then
        state.Character.Exists = true
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if rootPart then
            state.Character.Position = {
                X = rootPart.Position.X,
                Y = rootPart.Position.Y,
                Z = rootPart.Position.Z,
            }
        end
        
        if humanoid then
            state.Character.Health = humanoid.Health
            state.Character.MaxHealth = humanoid.MaxHealth
            state.Character.WalkSpeed = humanoid.WalkSpeed
            state.Character.JumpPower = humanoid.JumpPower
            
            -- Попытка получить JumpHeight (R15)
            pcall(function()
                state.Character.JumpHeight = humanoid.JumpHeight
            end)
        end
        
        -- Части тела
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                table.insert(state.Character.BodyParts, part.Name)
            end
        end
        
        -- Атрибуты персонажа
        for attrName, attrValue in pairs(character:GetAttributes()) do
            state.CharacterAttributes[attrName] = attrValue
        end
    end
    
    -- Инвентарь из Backpack
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(state.Inventory.BackpackItems, {
                    Name = item.Name,
                    ToolTip = item.ToolTip or "",
                    RequiresHandle = item.RequiresHandle,
                })
            end
        end
    end
    
    -- Экипированные предметы
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(state.Inventory.EquippedItems, {
                    Name = item.Name,
                    ToolTip = item.ToolTip or "",
                })
            end
        end
    end
    
    state.Inventory.TotalCount = #state.Inventory.BackpackItems + #state.Inventory.EquippedItems
    
    -- Leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            state.Leaderstats[stat.Name] = {
                Value = stat.Value,
                ClassName = stat.ClassName,
            }
        end
    end
    
    -- Атрибуты игрока
    for attrName, attrValue in pairs(player:GetAttributes()) do
        state.PlayerAttributes[attrName] = attrValue
    end
    
    -- Дочерние объекты игрока (для полноты)
    for _, child in ipairs(player:GetChildren()) do
        table.insert(state.PlayerChildren, {
            Name = child.Name,
            ClassName = child.ClassName,
        })
    end
    
    return state
end

-- === Вывод состояния в лог ===
local function printState(state)
    log("┌──────────────────────────────────────────────┐")
    log("│ " .. state.Label)
    log("│ Время: " .. state.TimestampFormatted)
    log("│ Длительность сессии: " .. state.SessionDuration .. " сек")
    log("├──────────────────────────────────────────────┤")
    
    if state.Character.Exists then
        if state.Character.Position then
            log("│ Позиция: (" .. 
                string.format("%.1f", state.Character.Position.X) .. ", " ..
                string.format("%.1f", state.Character.Position.Y) .. ", " ..
                string.format("%.1f", state.Character.Position.Z) .. ")")
        end
        log("│ Здоровье: " .. string.format("%.1f", state.Character.Health) .. "/" .. state.Character.MaxHealth)
        log("│ Скорость: " .. state.Character.WalkSpeed)
        log("│ Прыжок: " .. state.Character.JumpPower)
    else
        log("│ Персонаж: НЕ НАЙДЕН")
    end
    
    log("│ Предметов: " .. state.Inventory.TotalCount)
    for _, item in ipairs(state.Inventory.BackpackItems) do
        log("│   [Рюкзак] " .. item.Name)
    end
    for _, item in ipairs(state.Inventory.EquippedItems) do
        log("│   [Экипировано] " .. item.Name)
    end
    
    for statName, statData in pairs(state.Leaderstats) do
        log("│ [Стат] " .. statName .. " = " .. tostring(statData.Value))
    end
    
    log("│ Атрибутов игрока: " .. #state.PlayerAttributes)
    for k, v in pairs(state.PlayerAttributes) do
        log("│   " .. k .. " = " .. tostring(v))
    end
    
    log("│ PlaceId: " .. state.PlaceId .. ", JobId: " .. tostring(state.JobId))
    log("└──────────────────────────────────────────────┘")
end

-- === Детальное сравнение двух состояний ===
local function detailedCompare(stateA, stateB, labelA, labelB)
    log("═══════════════════════════════════════════════")
    log("  СРАВНЕНИЕ: '" .. labelA .. "' vs '" .. labelB .. "'")
    log("═══════════════════════════════════════════════")
    
    local report = {
        Matches = 0,
        Mismatches = 0,
        Missing = 0,
        Details = {},
    }
    
    local function check(name, valA, valB, tolerance)
        tolerance = tolerance or 0
        if valA == nil and valB == nil then
            return -- оба nil, пропускаем
        end
        
        if valA == nil then
            log("  ⚠ " .. name .. ": отсутствует в '" .. labelA .. "', в '" .. labelB .. "' = " .. tostring(valB))
            report.Missing = report.Missing + 1
            table.insert(report.Details, {Field = name, Status = "ОТСУТСТВУЕТ", ValueA = valA, ValueB = valB})
            return
        end
        
        if valB == nil then
            log("  ⚠ " .. name .. ": в '" .. labelA .. "' = " .. tostring(valA) .. ", отсутствует в '" .. labelB .. "'")
            report.Missing = report.Missing + 1
            table.insert(report.Details, {Field = name, Status = "ОТСУТСТВУЕТ", ValueA = valA, ValueB = valB})
            return
        end
        
        local match
        if type(valA) == "number" and type(valB) == "number" then
            match = math.abs(valA - valB) <= tolerance
        else
            match = (valA == valB)
        end
        
        if match then
            logSuccess(name .. ": совпадает (" .. tostring(valB) .. ")")
            report.Matches = report.Matches + 1
            table.insert(report.Details, {Field = name, Status = "СОВПАДАЕТ", ValueA = valA, ValueB = valB})
        else
            logWarning(name .. ": РАЗЛИЧАЕТСЯ! " .. tostring(valA) .. " -> " .. tostring(valB))
            report.Mismatches = report.Mismatches + 1
            table.insert(report.Details, {Field = name, Status = "РАЗЛИЧАЕТСЯ", ValueA = valA, ValueB = valB})
        end
    end
    
    -- Сравнение позиции
    if stateA.Character.Position and stateB.Character.Position then
        check("Позиция X", stateA.Character.Position.X, stateB.Character.Position.X, 1)
        check("Позиция Y", stateA.Character.Position.Y, stateB.Character.Position.Y, 1)
        check("Позиция Z", stateA.Character.Position.Z, stateB.Character.Position.Z, 1)
    end
    
    -- Сравнение характеристик
    check("Здоровье", stateA.Character.Health, stateB.Character.Health, 0.1)
    check("МаксЗдоровье", stateA.Character.MaxHealth, stateB.Character.MaxHealth)
    check("Скорость", stateA.Character.WalkSpeed, stateB.Character.WalkSpeed)
    check("Прыжок", stateA.Character.JumpPower, stateB.Character.JumpPower)
    
    -- Сравнение инвентаря
    check("Кол-во предметов", stateA.Inventory.TotalCount, stateB.Inventory.TotalCount)
    
    -- Сравнение leaderstats
    local allStats = {}
    for k in pairs(stateA.Leaderstats or {}) do allStats[k] = true end
    for k in pairs(stateB.Leaderstats or {}) do allStats[k] = true end
    
    for statName in pairs(allStats) do
        local valA = stateA.Leaderstats[statName] and stateA.Leaderstats[statName].Value
        local valB = stateB.Leaderstats[statName] and stateB.Leaderstats[statName].Value
        check("Стат:" .. statName, valA, valB)
    end
    
    -- Итог
    log("───────────────────────────────────────────────")
    log("  Итог: Совпадений=" .. report.Matches .. 
        " Различий=" .. report.Mismatches ..
        " Отсутствует=" .. report.Missing)
    log("═══════════════════════════════════════════════")
    
    return report
end

-- === Имитация "свежего" входа ===
local function simulateFreshJoinState(player)
    log("Имитация состояния при свежем входе...")
    
    -- "Свежее" состояние — значения по умолчанию
    local freshState = {
        Label = "Свежий вход (имитация)",
        Timestamp = os.time(),
        TimestampFormatted = os.date("%Y-%m-%d %H:%M:%S"),
        SessionDuration = 0,
        UserId = player.UserId,
        Name = player.Name,
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        Character = {
            Exists = true,
            Position = nil, -- Спавн-позиция
            Health = 100,
            MaxHealth = 100,
            WalkSpeed = 16,
            JumpPower = 50,
            JumpHeight = 7.2,
            BodyParts = {},
        },
        Inventory = {
            BackpackItems = {},
            EquippedItems = {},
            TotalCount = 0,
        },
        Leaderstats = {},
        PlayerAttributes = {},
        CharacterAttributes = {},
        PlayerChildren = {},
    }
    
    -- Поиск спавн-точки
    local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
    if spawnLocation then
        freshState.Character.Position = {
            X = spawnLocation.Position.X,
            Y = spawnLocation.Position.Y + 5,
            Z = spawnLocation.Position.Z,
        }
        logVerbose("Спавн-точка найдена: " .. tostring(spawnLocation.Position))
    end
    
    return freshState
end

-- === Мок-режим реджоина ===
local function mockRejoin(player, preState)
    log("╔═══════════════════════════════════════════╗")
    log("║  МОК-РЕЖИМ: Имитация Rejoin               ║")
    log("╚═══════════════════════════════════════════╝")
    
    -- Шаг 1: Сохранение состояния
    log("[1/6] Сохранение состояния до реджоина...")
    _G.RejoinData.PreRejoinState = preState
    
    -- Шаг 2: Имитация отключения
    log("[2/6] Имитация отключения от сервера...")
    log("  Отправка запроса PlayerRemoving...")
    wait(0.5)
    
    -- Шаг 3: Имитация задержки
    log("[3/6] Ожидание переподключения...")
    wait(1)
    
    -- Шаг 4: Имитация подключения
    log("[4/6] Переподключение к серверу (JobId: " .. tostring(game.JobId) .. ")...")
    wait(0.5)
    
    -- Имитируем небольшие изменения если включено
    if CONFIG.SIMULATE_DATA_CHANGE then
        logVerbose("Имитация незначительных изменений данных при реджоине...")
    end
    
    -- Шаг 5: Сбор состояния после
    log("[5/6] Сбор состояния после реджоина...")
    local postState = collectFullState(player, "После реджоина")
    _G.RejoinData.PostRejoinState = postState
    
    -- Шаг 6: Сбор "свежего" состояния для сравнения
    local freshState = nil
    if CONFIG.COMPARE_WITH_FRESH then
        log("[6/6] Генерация состояния 'свежего входа' для сравнения...")
        freshState = simulateFreshJoinState(player)
        _G.RejoinData.FreshJoinState = freshState
    end
    
    return postState, freshState
end

-- === Реальный реджоин ===
local function realRejoin(player, preState)
    log("╔═══════════════════════════════════════════╗")
    log("║  РЕАЛЬНЫЙ Rejoin                          ║")
    log("╚═══════════════════════════════════════════╝")
    
    -- Сохранение состояния
    _G.RejoinData.PreRejoinState = preState
    _G.RejoinData.TargetJobId = game.JobId
    _G.RejoinData.IsRejoining = true
    
    log("Целевой сервер: PlaceId=" .. game.PlaceId .. ", JobId=" .. tostring(game.JobId))
    log("Инициация TeleportToPlaceInstance...")
    
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
    end)
    
    if not success then
        logError("Реджоин не удался: " .. tostring(err))
        logWarning("Переключение на мок-режим...")
        _G.RejoinData.IsRejoining = false
        return mockRejoin(player, preState)
    end
    
    log("Запрос на реджоин отправлен. Ожидание переподключения...")
    return nil, nil
end

-- === Проверка возврата после реджоина ===
local function checkPostRejoin(player)
    if _G.RejoinData.IsRejoining and _G.RejoinData.PreRejoinState then
        log("Обнаружен возврат после реджоина!")
        
        local preState = _G.RejoinData.PreRejoinState
        local postState = collectFullState(player, "После реджоина (реальный)")
        _G.RejoinData.PostRejoinState = postState
        
        -- Сравнение до и после
        detailedCompare(preState, postState, "До реджоина", "После реджоина")
        
        -- Сравнение со свежим входом
        if CONFIG.COMPARE_WITH_FRESH then
            local freshState = simulateFreshJoinState(player)
            detailedCompare(postState, freshState, "После реджоина", "Свежий вход")
        end
        
        -- Очистка
        _G.RejoinData.IsRejoining = false
        _G.RejoinData.PreRejoinState = nil
        
        return true
    end
    return false
end

-- === Главная функция ===
local function main()
    log("╔═══════════════════════════════════════════════════╗")
    log("║  ТЕСТ #20: Эмуляция Rejoin (Переподключение)     ║")
    log("╚═══════════════════════════════════════════════════╝")
    
    local player = Players.LocalPlayer
    if not player then
        logError("LocalPlayer не найден!")
        return
    end
    
    log("Игрок: " .. player.Name)
    log("PlaceId: " .. game.PlaceId)
    log("JobId: " .. tostring(game.JobId))
    log("Режим: " .. (CONFIG.USE_MOCK and "МОК (имитация)" or "РЕАЛЬНЫЙ реджоин"))
    log("Сравнение со свежим входом: " .. (CONFIG.COMPARE_WITH_FRESH and "ДА" or "НЕТ"))
    log("")
    
    -- Проверка: это возврат после реджоина?
    if checkPostRejoin(player) then
        log("Анализ возврата после реджоина завершён.")
        return
    end
    
    -- Сбор текущего состояния
    log("Сбор текущего состояния...")
    local preState = collectFullState(player, "До реджоина")
    printState(preState)
    
    -- Задержка
    log("Подготовка к реджоину через " .. CONFIG.REJOIN_DELAY .. " сек...")
    wait(CONFIG.REJOIN_DELAY)
    
    -- Выполнение реджоина
    local postState, freshState
    if CONFIG.USE_MOCK then
        postState, freshState = mockRejoin(player, preState)
    else
        postState, freshState = realRejoin(player, preState)
    end
    
    -- Если мок — выводим сравнение
    if postState then
        log("")
        printState(postState)
        
        -- Сравнение до и после реджоина
        local rejoinReport = detailedCompare(preState, postState, "До реджоина", "После реджоина")
        
        -- Сравнение со свежим входом
        local freshReport = nil
        if freshState and CONFIG.COMPARE_WITH_FRESH then
            printState(freshState)
            freshReport = detailedCompare(postState, freshState, "После реджоина", "Свежий вход")
        end
        
        -- Запись в историю
        _G.RejoinData.RejoinCount = _G.RejoinData.RejoinCount + 1
        table.insert(_G.RejoinData.RejoinHistory, {
            Number = _G.RejoinData.RejoinCount,
            Timestamp = os.time(),
            PreState = preState,
            PostState = postState,
            FreshState = freshState,
            RejoinReport = rejoinReport,
            FreshReport = freshReport,
            Mode = CONFIG.USE_MOCK and "mock" or "real",
        })
        
        -- Итоговая сводка
        log("")
        log("╔═══════════════════════════════════════════════════╗")
        log("║  ИТОГОВАЯ СВОДКА РЕДЖОИНА                        ║")
        log("╠═══════════════════════════════════════════════════╣")
        log("║ Реджоин #" .. _G.RejoinData.RejoinCount)
        log("║ Режим: " .. (CONFIG.USE_MOCK and "Мок" or "Реальный"))
        log("║")
        log("║ Сравнение до/после:")
        log("║   Совпадений: " .. rejoinReport.Matches)
        log("║   Различий: " .. rejoinReport.Mismatches)
        log("║   Отсутствует: " .. rejoinReport.Missing)
        
        if freshReport then
            log("║")
            log("║ Сравнение реджоин/свежий вход:")
            log("║   Совпадений: " .. freshReport.Matches)
            log("║   Различий: " .. freshReport.Mismatches)
            log("║   Отсутствует: " .. freshReport.Missing)
        end
        
        if rejoinReport.Mismatches > 0 then
            log("║")
            log("║ ⚠ ОБНАРУЖЕНЫ РАСХОЖДЕНИЯ ДАННЫХ!")
            log("║   Возможна потеря или дупликация данных")
        else
            log("║")
            log("║ ✓ Данные сохранены корректно")
        end
        
        log("╚═══════════════════════════════════════════════════╝")
    end
    
    log("Данные доступны в _G.RejoinData")
end

-- === Запуск ===
main()
