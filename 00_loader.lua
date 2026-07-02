--[[
    ============================================================
    🎮 GUI-ЗАГРУЗЧИК ТЕСТОВЫХ СКРИПТОВ v2.0
    ============================================================
    Вставьте этот скрипт в CommandBar в Roblox Studio.
    Появится GUI-панель для управления всеми тестами.
    
    Скрипты НЕ запускаются автоматически — вы включаете
    каждый вручную через кнопки в меню.
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

-- =============================================
-- ⚙️ КОНФИГУРАЦИЯ
-- =============================================
local REPO_BASE_URL = "https://raw.githubusercontent.com/katsunei/roblox-validation-tests/main/"

-- Определение всех скриптов с категориями и функциями очистки
local SCRIPT_REGISTRY = {
    -- Категория: Утилиты
    {
        category = "🔧 Утилиты",
        scripts = {
            { file = "07_whitelist.lua",             name = "Белый список",            cleanup = nil,                        type = "utility" },
            { file = "06_timing_tool.lua",           name = "Тайминоги",              cleanup = nil,                        type = "utility" },
            { file = "23_save_load_config.lua",      name = "Менеджер конфигов",       cleanup = nil,                        type = "utility" },
        }
    },
    -- Категория: Боевые
    {
        category = "⚔️ Бой",
        scripts = {
            { file = "01_style_spoof.lua",           name = "Подмена стиля",           cleanup = nil,                        type = "oneshot" },
            { file = "02_dribble_spam.lua",          name = "Спам дриблинг",           cleanup = nil,                        type = "oneshot" },
            { file = "03_auto_parry.lua",            name = "Автопарирование",         cleanup = "CleanupAutoParry",         type = "toggle" },
            { file = "08_perfect_shot.lua",          name = "Идеальный бросок",        cleanup = nil,                        type = "oneshot" },
            { file = "17_no_dodge_cooldown.lua",     name = "Dodge без КД",            cleanup = "CleanupNoDodgeCD",         type = "toggle" },
        }
    },
    -- Категория: Движение
    {
        category = "🏃 Движение",
        scripts = {
            { file = "05_face_lock.lua",             name = "Face Lock",               cleanup = "CleanupFaceLock",          type = "toggle" },
            { file = "09_flight.lua",                name = "Полёт",                   cleanup = "CleanupFlight",            type = "toggle" },
            { file = "10_speed_hack.lua",            name = "Speed Hack",              cleanup = "RestoreSpeed",             type = "toggle" },
            { file = "11_infinite_jump.lua",         name = "∞ Прыжки",               cleanup = "CleanupInfJump",           type = "toggle" },
            { file = "12_noclip.lua",                name = "Noclip",                  cleanup = "CleanupNoclip",            type = "toggle" },
            { file = "18_teleport_to_player.lua",    name = "Телепорт",               cleanup = "CleanupTeleport",          type = "toggle" },
        }
    },
    -- Категория: Состояния
    {
        category = "🛡️ Состояния",
        scripts = {
            { file = "14_infinite_stamina.lua",      name = "∞ Стамина",              cleanup = "CleanupInfStamina",        type = "toggle" },
            { file = "15_no_ragdoll.lua",            name = "No Ragdoll",              cleanup = "CleanupNoRagdoll",         type = "toggle" },
            { file = "16_stun_immunity.lua",         name = "Антистан",               cleanup = "CleanupStunImmunity",      type = "toggle" },
        }
    },
    -- Категория: Визуализация
    {
        category = "🔍 Визуализация",
        scripts = {
            { file = "04_parry_zone_visualizer.lua", name = "Зона парирования",       cleanup = "CleanupParryVisualizer",   type = "toggle" },
            { file = "13_esp.lua",                   name = "ESP",                     cleanup = "CleanupESP",               type = "toggle" },
        }
    },
    -- Категория: Разное
    {
        category = "📦 Разное",
        scripts = {
            { file = "19_server_hop.lua",            name = "Server Hop",              cleanup = nil,                        type = "oneshot" },
            { file = "20_rejoin.lua",                name = "Rejoin",                  cleanup = nil,                        type = "oneshot" },
            { file = "21_anti_afk.lua",              name = "Анти-АФК",              cleanup = "StopAntiAFK",              type = "toggle" },
            { file = "22_self_kill.lua",             name = "Самоубийство",            cleanup = nil,                        type = "oneshot" },
        }
    },
}

-- =============================================
-- 📦 СОСТОЯНИЕ
-- =============================================
local sourceCache = {}       -- Кэш загруженных исходников
local activeScripts = {}     -- Какие скрипты сейчас запущены
local downloadStatus = {}    -- Статус загрузки: "none", "loading", "ready", "error"
local buttonRefs = {}        -- Ссылки на GUI-кнопки для обновления

-- =============================================
-- 🎨 ТЕМА ОФОРМЛЕНИЯ
-- =============================================
local THEME = {
    Background     = Color3.fromRGB(18, 18, 24),
    Panel          = Color3.fromRGB(25, 25, 35),
    Card           = Color3.fromRGB(32, 32, 45),
    CardHover      = Color3.fromRGB(40, 40, 55),
    Accent         = Color3.fromRGB(88, 101, 242),   -- Discord-like синий
    AccentHover    = Color3.fromRGB(105, 117, 255),
    Green          = Color3.fromRGB(45, 185, 95),
    GreenDark      = Color3.fromRGB(35, 140, 75),
    Red            = Color3.fromRGB(235, 70, 70),
    RedDark        = Color3.fromRGB(180, 50, 50),
    Orange         = Color3.fromRGB(240, 160, 40),
    Yellow         = Color3.fromRGB(255, 210, 60),
    TextPrimary    = Color3.fromRGB(230, 230, 240),
    TextSecondary  = Color3.fromRGB(140, 140, 165),
    TextMuted      = Color3.fromRGB(90, 90, 110),
    Border         = Color3.fromRGB(50, 50, 70),
    CategoryBg     = Color3.fromRGB(22, 22, 30),
    Shadow         = Color3.fromRGB(0, 0, 0),
}

local FONT_MAIN    = Enum.Font.GothamBold
local FONT_TEXT    = Enum.Font.GothamMedium
local FONT_MONO    = Enum.Font.RobotoMono

-- =============================================
-- 🧹 УДАЛЕНИЕ СТАРОГО GUI (при повторном запуске)
-- =============================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Удаляем предыдущую версию если есть
local oldGui = playerGui:FindFirstChild("TestSuiteGUI")
if oldGui then oldGui:Destroy() end

-- =============================================
-- 🏗️ СОЗДАНИЕ ОСНОВНОГО GUI
-- =============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TestSuiteGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
screenGui.Parent = playerGui

-- =============================================
-- 📐 HELPER: Создание UI-элементов
-- =============================================
local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.Border
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function addPadding(parent, top, right, bottom, left)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, top or 8)
    p.PaddingRight = UDim.new(0, right or 8)
    p.PaddingBottom = UDim.new(0, bottom or 8)
    p.PaddingLeft = UDim.new(0, left or 8)
    p.Parent = parent
    return p
end

local function addListLayout(parent, padding, direction)
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, padding or 4)
    l.FillDirection = direction or Enum.FillDirection.Vertical
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

-- =============================================
-- 🔘 КНОПКА ВЫЗОВА МЕНЮ (всегда видна)
-- =============================================
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleButton"
toggleBtn.Size = UDim2.new(0, 44, 0, 44)
toggleBtn.Position = UDim2.new(0, 16, 0.5, -22)
toggleBtn.BackgroundColor3 = THEME.Accent
toggleBtn.Text = "🛡️"
toggleBtn.TextSize = 22
toggleBtn.Font = FONT_MAIN
toggleBtn.TextColor3 = THEME.TextPrimary
toggleBtn.AutoButtonColor = false
toggleBtn.Parent = screenGui
addCorner(toggleBtn, 22)
addStroke(toggleBtn, THEME.AccentHover, 2)

-- Эффекты наведения на кнопку
toggleBtn.MouseEnter:Connect(function()
    toggleBtn.BackgroundColor3 = THEME.AccentHover
    toggleBtn.Size = UDim2.new(0, 48, 0, 48)
    toggleBtn.Position = UDim2.new(0, 14, 0.5, -24)
end)
toggleBtn.MouseLeave:Connect(function()
    toggleBtn.BackgroundColor3 = THEME.Accent
    toggleBtn.Size = UDim2.new(0, 44, 0, 44)
    toggleBtn.Position = UDim2.new(0, 16, 0.5, -22)
end)

-- =============================================
-- 📋 ГЛАВНАЯ ПАНЕЛЬ
-- =============================================
local mainPanel = Instance.new("Frame")
mainPanel.Name = "MainPanel"
mainPanel.Size = UDim2.new(0, 320, 0, 520)
mainPanel.Position = UDim2.new(0, 70, 0.5, -260)
mainPanel.BackgroundColor3 = THEME.Panel
mainPanel.BorderSizePixel = 0
mainPanel.Visible = false
mainPanel.Parent = screenGui
addCorner(mainPanel, 12)
addStroke(mainPanel, THEME.Border, 1)

-- Тень
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 30, 1, 30)
shadow.Position = UDim2.new(0, -15, 0, -10)
shadow.BackgroundTransparency = 1
shadow.ImageColor3 = THEME.Shadow
shadow.ImageTransparency = 0.5
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(30, 30, 30, 30)
shadow.ZIndex = -1
shadow.Image = "rbxassetid://5554236805"
shadow.Parent = mainPanel

-- =============================================
-- 🔝 ЗАГОЛОВОК (перетаскиваемый)
-- =============================================
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = THEME.Background
header.BorderSizePixel = 0
header.Parent = mainPanel
addCorner(header, 12)

-- Нижние углы заголовка прямые (хак через дополнительный фрейм)
local headerBottom = Instance.new("Frame")
headerBottom.Size = UDim2.new(1, 0, 0, 14)
headerBottom.Position = UDim2.new(0, 0, 1, -14)
headerBottom.BackgroundColor3 = THEME.Background
headerBottom.BorderSizePixel = 0
headerBottom.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -90, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🛡️ Server Validation Tests"
titleLabel.TextColor3 = THEME.TextPrimary
titleLabel.TextSize = 16
titleLabel.Font = FONT_MAIN
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

-- Счётчик активных
local counterLabel = Instance.new("TextLabel")
counterLabel.Name = "Counter"
counterLabel.Size = UDim2.new(0, 40, 0, 22)
counterLabel.Position = UDim2.new(1, -80, 0.5, -11)
counterLabel.BackgroundColor3 = THEME.Accent
counterLabel.Text = "0"
counterLabel.TextColor3 = THEME.TextPrimary
counterLabel.TextSize = 13
counterLabel.Font = FONT_MAIN
counterLabel.Parent = header
addCorner(counterLabel, 11)

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -40, 0.5, -15)
closeBtn.BackgroundColor3 = THEME.Red
closeBtn.BackgroundTransparency = 0.8
closeBtn.Text = "✕"
closeBtn.TextColor3 = THEME.TextSecondary
closeBtn.TextSize = 16
closeBtn.Font = FONT_MAIN
closeBtn.AutoButtonColor = false
closeBtn.Parent = header
addCorner(closeBtn, 6)

closeBtn.MouseEnter:Connect(function()
    closeBtn.BackgroundTransparency = 0
    closeBtn.TextColor3 = THEME.TextPrimary
end)
closeBtn.MouseLeave:Connect(function()
    closeBtn.BackgroundTransparency = 0.8
    closeBtn.TextColor3 = THEME.TextSecondary
end)

-- =============================================
-- 🔀 ПЕРЕТАСКИВАНИЕ ПАНЕЛИ
-- =============================================
local dragging = false
local dragStart, startPos

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainPanel.Position
    end
end)

header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        mainPanel.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- =============================================
-- 🔍 СТРОКА ПОИСКА
-- =============================================
local searchFrame = Instance.new("Frame")
searchFrame.Name = "SearchFrame"
searchFrame.Size = UDim2.new(1, -20, 0, 32)
searchFrame.Position = UDim2.new(0, 10, 0, 55)
searchFrame.BackgroundColor3 = THEME.Card
searchFrame.BorderSizePixel = 0
searchFrame.Parent = mainPanel
addCorner(searchFrame, 8)
addStroke(searchFrame, THEME.Border, 1)

local searchIcon = Instance.new("TextLabel")
searchIcon.Size = UDim2.new(0, 30, 1, 0)
searchIcon.BackgroundTransparency = 1
searchIcon.Text = "🔍"
searchIcon.TextSize = 14
searchIcon.Parent = searchFrame

local searchBox = Instance.new("TextBox")
searchBox.Name = "SearchBox"
searchBox.Size = UDim2.new(1, -35, 1, 0)
searchBox.Position = UDim2.new(0, 30, 0, 0)
searchBox.BackgroundTransparency = 1
searchBox.Text = ""
searchBox.PlaceholderText = "Поиск скриптов..."
searchBox.PlaceholderColor3 = THEME.TextMuted
searchBox.TextColor3 = THEME.TextPrimary
searchBox.TextSize = 13
searchBox.Font = FONT_TEXT
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.Parent = searchFrame

-- =============================================
-- 📜 ОБЛАСТЬ СКРОЛЛА
-- =============================================
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ScriptList"
scrollFrame.Size = UDim2.new(1, -20, 1, -140)
scrollFrame.Position = UDim2.new(0, 10, 0, 92)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = THEME.Accent
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainPanel

local scrollLayout = addListLayout(scrollFrame, 6)

-- =============================================
-- 🔽 НИЖНЯЯ ПАНЕЛЬ УПРАВЛЕНИЯ
-- =============================================
local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.Size = UDim2.new(1, 0, 0, 44)
bottomBar.Position = UDim2.new(0, 0, 1, -44)
bottomBar.BackgroundColor3 = THEME.Background
bottomBar.BorderSizePixel = 0
bottomBar.Parent = mainPanel
addCorner(bottomBar, 12)

local bottomTop = Instance.new("Frame")
bottomTop.Size = UDim2.new(1, 0, 0, 14)
bottomTop.BackgroundColor3 = THEME.Background
bottomTop.BorderSizePixel = 0
bottomTop.Parent = bottomBar

-- Кнопка "Выключить всё"
local stopAllBtn = Instance.new("TextButton")
stopAllBtn.Name = "StopAllBtn"
stopAllBtn.Size = UDim2.new(0.48, -5, 0, 30)
stopAllBtn.Position = UDim2.new(0, 10, 0.5, -15)
stopAllBtn.BackgroundColor3 = THEME.Red
stopAllBtn.BackgroundTransparency = 0.3
stopAllBtn.Text = "⛔ Стоп все"
stopAllBtn.TextColor3 = THEME.TextPrimary
stopAllBtn.TextSize = 12
stopAllBtn.Font = FONT_MAIN
stopAllBtn.AutoButtonColor = false
stopAllBtn.Parent = bottomBar
addCorner(stopAllBtn, 6)

stopAllBtn.MouseEnter:Connect(function() stopAllBtn.BackgroundTransparency = 0 end)
stopAllBtn.MouseLeave:Connect(function() stopAllBtn.BackgroundTransparency = 0.3 end)

-- Кнопка "Перезагрузить кэш"
local reloadBtn = Instance.new("TextButton")
reloadBtn.Name = "ReloadBtn"
reloadBtn.Size = UDim2.new(0.48, -5, 0, 30)
reloadBtn.Position = UDim2.new(0.52, 0, 0.5, -15)
reloadBtn.BackgroundColor3 = THEME.Accent
reloadBtn.BackgroundTransparency = 0.3
reloadBtn.Text = "🔄 Сбросить кэш"
reloadBtn.TextColor3 = THEME.TextPrimary
reloadBtn.TextSize = 12
reloadBtn.Font = FONT_MAIN
reloadBtn.AutoButtonColor = false
reloadBtn.Parent = bottomBar
addCorner(reloadBtn, 6)

reloadBtn.MouseEnter:Connect(function() reloadBtn.BackgroundTransparency = 0 end)
reloadBtn.MouseLeave:Connect(function() reloadBtn.BackgroundTransparency = 0.3 end)

-- =============================================
-- 🔄 ЛОГИКА ЗАГРУЗКИ И ВЫПОЛНЕНИЯ
-- =============================================

local function updateCounter()
    local count = 0
    for _, v in pairs(activeScripts) do
        if v then count = count + 1 end
    end
    counterLabel.Text = tostring(count)
    if count > 0 then
        counterLabel.BackgroundColor3 = THEME.Green
    else
        counterLabel.BackgroundColor3 = THEME.Accent
    end
end

local function downloadScript(entry)
    local url = REPO_BASE_URL .. entry.file
    downloadStatus[entry.file] = "loading"

    local success, result = pcall(function()
        return game:HttpGet(url)
    end)

    if success and result and #result > 0 then
        sourceCache[entry.file] = result
        downloadStatus[entry.file] = "ready"
        return true
    else
        downloadStatus[entry.file] = "error"
        warn("[Loader] Ошибка загрузки: " .. entry.file .. " — " .. tostring(result))
        return false
    end
end

local function executeScript(entry)
    local source = sourceCache[entry.file]
    if not source then return false end

    local func, compileErr = loadstring(source)
    if not func then
        warn("[Loader] Ошибка компиляции " .. entry.file .. ": " .. tostring(compileErr))
        return false
    end

    local execOk, execErr = pcall(func)
    if not execOk then
        warn("[Loader] Ошибка выполнения " .. entry.file .. ": " .. tostring(execErr))
        return false
    end

    return true
end

local function cleanupScript(entry)
    if entry.cleanup and _G[entry.cleanup] then
        local ok, err = pcall(_G[entry.cleanup])
        if not ok then
            warn("[Loader] Ошибка очистки " .. entry.name .. ": " .. tostring(err))
        end
    end
end

local function toggleScript(entry, btn, statusDot)
    local fileKey = entry.file
    local isActive = activeScripts[fileKey]

    if isActive then
        -- ВЫКЛЮЧАЕМ
        cleanupScript(entry)
        activeScripts[fileKey] = false
        btn.BackgroundColor3 = THEME.Card
        statusDot.BackgroundColor3 = THEME.TextMuted
        statusDot.Text = "⬜"
        print("[Loader] ❌ Выключен: " .. entry.name)
    else
        -- ВКЛЮЧАЕМ
        btn.BackgroundColor3 = THEME.Card
        statusDot.Text = "⏳"
        statusDot.BackgroundColor3 = THEME.Orange

        -- Загружаем если нет в кэше
        if not sourceCache[fileKey] then
            task.spawn(function()
                local ok = downloadScript(entry)
                if ok then
                    local execOk = executeScript(entry)
                    if execOk then
                        activeScripts[fileKey] = true
                        statusDot.Text = "✅"
                        statusDot.BackgroundColor3 = THEME.Green
                        btn.BackgroundColor3 = THEME.GreenDark
                        print("[Loader] ✅ Запущен: " .. entry.name)
                    else
                        statusDot.Text = "❌"
                        statusDot.BackgroundColor3 = THEME.Red
                    end
                else
                    statusDot.Text = "❌"
                    statusDot.BackgroundColor3 = THEME.Red
                end
                updateCounter()
            end)
            updateCounter()
            return
        end

        -- Если уже в кэше — выполняем сразу
        local execOk = executeScript(entry)
        if execOk then
            activeScripts[fileKey] = true
            statusDot.Text = "✅"
            statusDot.BackgroundColor3 = THEME.Green
            btn.BackgroundColor3 = THEME.GreenDark
            print("[Loader] ✅ Запущен: " .. entry.name)
        else
            statusDot.Text = "❌"
            statusDot.BackgroundColor3 = THEME.Red
        end
    end

    updateCounter()
end

-- =============================================
-- 🏗️ ПОСТРОЕНИЕ СПИСКА СКРИПТОВ
-- =============================================
local allEntries = {}  -- Для поиска

local function buildScriptList()
    -- Очищаем
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    allEntries = {}
    buttonRefs = {}

    local layoutOrder = 0

    for _, category in ipairs(SCRIPT_REGISTRY) do
        -- Заголовок категории
        local catFrame = Instance.new("Frame")
        catFrame.Name = "Cat_" .. category.category
        catFrame.Size = UDim2.new(1, 0, 0, 28)
        catFrame.BackgroundColor3 = THEME.CategoryBg
        catFrame.BorderSizePixel = 0
        catFrame.LayoutOrder = layoutOrder
        catFrame.Parent = scrollFrame
        addCorner(catFrame, 6)

        local catLabel = Instance.new("TextLabel")
        catLabel.Size = UDim2.new(1, -10, 1, 0)
        catLabel.Position = UDim2.new(0, 10, 0, 0)
        catLabel.BackgroundTransparency = 1
        catLabel.Text = category.category
        catLabel.TextColor3 = THEME.TextSecondary
        catLabel.TextSize = 12
        catLabel.Font = FONT_MAIN
        catLabel.TextXAlignment = Enum.TextXAlignment.Left
        catLabel.Parent = catFrame

        layoutOrder = layoutOrder + 1

        -- Скрипты в категории
        for _, entry in ipairs(category.scripts) do
            local row = Instance.new("Frame")
            row.Name = "Script_" .. entry.file
            row.Size = UDim2.new(1, 0, 0, 38)
            row.BackgroundColor3 = THEME.Card
            row.BorderSizePixel = 0
            row.LayoutOrder = layoutOrder
            row.Parent = scrollFrame
            addCorner(row, 8)

            -- Кнопка (весь ряд кликабельный)
            local btn = Instance.new("TextButton")
            btn.Name = "Btn"
            btn.Size = UDim2.new(1, 0, 1, 0)
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.Parent = row

            -- Иконка типа
            local typeIcon = Instance.new("TextLabel")
            typeIcon.Size = UDim2.new(0, 24, 1, 0)
            typeIcon.Position = UDim2.new(0, 8, 0, 0)
            typeIcon.BackgroundTransparency = 1
            typeIcon.TextSize = 14
            typeIcon.Parent = row

            if entry.type == "toggle" then
                typeIcon.Text = "🔁"
            elseif entry.type == "oneshot" then
                typeIcon.Text = "▶️"
            else
                typeIcon.Text = "🔧"
            end

            -- Название
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -80, 1, 0)
            nameLabel.Position = UDim2.new(0, 34, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = entry.name
            nameLabel.TextColor3 = THEME.TextPrimary
            nameLabel.TextSize = 13
            nameLabel.Font = FONT_TEXT
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.Parent = row

            -- Статус (справа)
            local statusDot = Instance.new("TextLabel")
            statusDot.Name = "Status"
            statusDot.Size = UDim2.new(0, 30, 0, 22)
            statusDot.Position = UDim2.new(1, -40, 0.5, -11)
            statusDot.BackgroundTransparency = 1
            statusDot.Text = "⬜"
            statusDot.TextSize = 16
            statusDot.Parent = row

            -- Hover эффект
            btn.MouseEnter:Connect(function()
                if not activeScripts[entry.file] then
                    row.BackgroundColor3 = THEME.CardHover
                end
            end)
            btn.MouseLeave:Connect(function()
                if activeScripts[entry.file] then
                    row.BackgroundColor3 = THEME.GreenDark
                else
                    row.BackgroundColor3 = THEME.Card
                end
            end)

            -- Клик
            btn.MouseButton1Click:Connect(function()
                if entry.type == "oneshot" then
                    -- Одноразовые скрипты: загрузить и выполнить
                    statusDot.Text = "⏳"
                    task.spawn(function()
                        if not sourceCache[entry.file] then
                            downloadScript(entry)
                        end
                        if sourceCache[entry.file] then
                            local ok = executeScript(entry)
                            statusDot.Text = ok and "✅" or "❌"
                            task.delay(3, function()
                                statusDot.Text = "⬜"
                            end)
                        else
                            statusDot.Text = "❌"
                        end
                    end)
                else
                    -- Toggle-скрипты: включить/выключить
                    toggleScript(entry, row, statusDot)
                end
            end)

            -- Сохраняем для поиска и обновления
            table.insert(allEntries, {
                entry = entry,
                row = row,
                nameLabel = nameLabel,
                statusDot = statusDot,
                btn = btn,
                catFrame = catFrame,
            })
            buttonRefs[entry.file] = { row = row, statusDot = statusDot }

            layoutOrder = layoutOrder + 1
        end
    end
end

buildScriptList()

-- =============================================
-- 🔍 ЛОГИКА ПОИСКА
-- =============================================
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = searchBox.Text:lower()
    local visibleCategories = {}

    for _, item in ipairs(allEntries) do
        local match = query == "" 
            or item.entry.name:lower():find(query) 
            or item.entry.file:lower():find(query)

        item.row.Visible = match

        if match then
            visibleCategories[item.catFrame] = true
        end
    end

    -- Скрываем пустые категории
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name:sub(1, 4) == "Cat_" then
            child.Visible = visibleCategories[child] or (query == "")
        end
    end
end)

-- =============================================
-- 🔘 ОБРАБОТЧИКИ КНОПОК
-- =============================================

-- Показать/скрыть панель
local panelVisible = false
toggleBtn.MouseButton1Click:Connect(function()
    panelVisible = not panelVisible
    mainPanel.Visible = panelVisible
    toggleBtn.Text = panelVisible and "◀" or "🛡️"
end)

-- Закрытие
closeBtn.MouseButton1Click:Connect(function()
    panelVisible = false
    mainPanel.Visible = false
    toggleBtn.Text = "🛡️"
end)

-- Стоп все
stopAllBtn.MouseButton1Click:Connect(function()
    print("[Loader] ⛔ Выключение всех скриптов...")
    for _, category in ipairs(SCRIPT_REGISTRY) do
        for _, entry in ipairs(category.scripts) do
            if activeScripts[entry.file] then
                cleanupScript(entry)
                activeScripts[entry.file] = false
            end
        end
    end

    -- Обновляем все кнопки
    for fileKey, refs in pairs(buttonRefs) do
        refs.row.BackgroundColor3 = THEME.Card
        refs.statusDot.Text = "⬜"
    end

    updateCounter()
    print("[Loader] ✅ Все скрипты выключены")
end)

-- Сбросить кэш
reloadBtn.MouseButton1Click:Connect(function()
    sourceCache = {}
    downloadStatus = {}
    print("[Loader] 🔄 Кэш очищен. Скрипты будут загружены заново при включении.")
end)

-- =============================================
-- 🌐 ГЛОБАЛЬНЫЕ ФУНКЦИИ (для CommandBar)
-- =============================================

-- Показать/скрыть меню
_G.ToggleTestMenu = function()
    panelVisible = not panelVisible
    mainPanel.Visible = panelVisible
end

-- Уничтожить GUI полностью
_G.DestroyTestGUI = function()
    -- Выключаем всё
    for _, category in ipairs(SCRIPT_REGISTRY) do
        for _, entry in ipairs(category.scripts) do
            if activeScripts[entry.file] then
                cleanupScript(entry)
            end
        end
    end
    activeScripts = {}
    screenGui:Destroy()
    print("[Loader] GUI полностью удалён")
end

-- =============================================
-- ✅ ГОТОВО
-- =============================================
print("")
print("╔══════════════════════════════════════════════════╗")
print("║  🛡️ GUI-ЗАГРУЗЧИК ТЕСТОВ v2.0 — ГОТОВ           ║")
print("╠══════════════════════════════════════════════════╣")
print("║                                                  ║")
print("║  Нажмите 🛡️ слева экрана для открытия меню.       ║")
print("║                                                  ║")
print("║  🔁 = Toggle (вкл/выкл)                          ║")
print("║  ▶️ = Одноразовый (выполнить один раз)            ║")
print("║  🔧 = Утилита (загрузить модуль)                  ║")
print("║                                                  ║")
print("║  Команды:                                        ║")
print("║    _G.ToggleTestMenu()   — показать/скрыть        ║")
print("║    _G.DestroyTestGUI()   — удалить полностью      ║")
print("║                                                  ║")
print("╚══════════════════════════════════════════════════╝")
print("")
