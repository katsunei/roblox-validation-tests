--[[
	=============================================================
	  ТЕСТОВЫЙ СКРИПТ #13 — ESP (ExtraSensory Perception)
	=============================================================
	  Назначение:
	    Симуляция ESP-чита. Рисует клиентские визуальные
	    элементы для каждого игрока: имя, полоску здоровья,
	    полоску выносливости, дистанцию, Highlight-обводку,
	    линию-трейсер от локального игрока и текст атрибутов.

	  Что тестируется на стороне сервера:
	    • Передаёт ли сервер клиенту избыточную информацию
	      (здоровье, выносливость, уровень, стиль и т.д.)
	    • Доступны ли персонажи других игроков через Workspace
	    • Можно ли считать атрибуты чужих персонажей

	  Использование:
	    Вставить в CommandBar Roblox Studio.
	    _G.ESP_Cleanup() — удалить все ESP-элементы.
	=============================================================
--]]

-- ============================================================
-- Сервисы
-- ============================================================
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local LocalPlayer        = Players.LocalPlayer

-- ============================================================
-- Конфигурация
-- ============================================================
local CONFIG = {
	-- Цвета полосок
	HealthBarColorFull   = Color3.fromRGB(0, 255, 0),    -- Зелёный (полное здоровье)
	HealthBarColorLow    = Color3.fromRGB(255, 0, 0),    -- Красный (мало здоровья)
	StaminaBarColor      = Color3.fromRGB(50, 120, 255),  -- Синий (выносливость)

	-- Цвета обводки по дистанции
	HighlightColorClose  = Color3.fromRGB(255, 50, 50),   -- Близко (< 50 стадов)
	HighlightColorMid    = Color3.fromRGB(255, 200, 50),  -- Средне (50–120)
	HighlightColorFar    = Color3.fromRGB(50, 200, 255),  -- Далеко (> 120)

	-- Пороги дистанции
	CloseRange           = 50,
	MidRange             = 120,

	-- Прозрачность обводки
	HighlightFillAlpha   = 0.7,  -- 0 = непрозрачно, 1 = полностью прозрачно
	HighlightOutlineAlpha = 0,

	-- Атрибуты, которые пытаемся прочитать
	AttributeNames       = {"Style", "Level", "Stamina", "Class", "Rank", "Faction"},

	-- Максимальная дистанция отображения ESP
	MaxRenderDistance     = 2000,
}

-- ============================================================
-- Хранилище ESP-элементов для каждого игрока
-- ============================================================
local espData        = {}  -- [Player] -> { gui, highlight, beam, ... }
local espConnection  = nil -- RenderStepped-соединение
local espActive      = false

-- ============================================================
-- Вспомогательные функции
-- ============================================================

--- Возвращает дистанцию между двумя персонажами (или math.huge)
local function getDistance(charA, charB)
	if not charA or not charB then return math.huge end
	local rootA = charA:FindFirstChild("HumanoidRootPart")
	local rootB = charB:FindFirstChild("HumanoidRootPart")
	if not rootA or not rootB then return math.huge end
	return (rootA.Position - rootB.Position).Magnitude
end

--- Цвет обводки на основе дистанции
local function getColorByDistance(dist)
	if dist < CONFIG.CloseRange then
		return CONFIG.HighlightColorClose
	elseif dist < CONFIG.MidRange then
		return CONFIG.HighlightColorMid
	else
		return CONFIG.HighlightColorFar
	end
end

--- Цвет обводки по команде игрока (если есть TeamColor)
local function getColorByTeam(player)
	if player.Team then
		return player.TeamColor.Color
	end
	return nil
end

--- Линейная интерполяция цвета для полоски здоровья
local function lerpHealthColor(fraction)
	-- fraction: 0 = мёртв, 1 = полное здоровье
	fraction = math.clamp(fraction, 0, 1)
	return CONFIG.HealthBarColorLow:Lerp(CONFIG.HealthBarColorFull, fraction)
end

--- Собирает строку атрибутов персонажа / игрока
local function collectAttributes(player, character)
	local parts = {}
	for _, attrName in ipairs(CONFIG.AttributeNames) do
		-- Пытаемся прочитать атрибут из нескольких мест
		local val = nil
		if character then
			val = character:GetAttribute(attrName)
		end
		if val == nil then
			val = player:GetAttribute(attrName)
		end
		-- Ищем NumberValue / StringValue в персонаже
		if val == nil and character then
			local obj = character:FindFirstChild(attrName)
			if obj and (obj:IsA("NumberValue") or obj:IsA("StringValue") or obj:IsA("IntValue")) then
				val = obj.Value
			end
		end
		if val ~= nil then
			table.insert(parts, attrName .. ": " .. tostring(val))
		end
	end
	return table.concat(parts, " | ")
end

--- Считывает выносливость из разных источников
local function getStamina(player, character)
	-- 1. Атрибут на персонаже
	if character then
		local s = character:GetAttribute("Stamina")
		if s then return s end
	end
	-- 2. Атрибут на объекте игрока
	local s = player:GetAttribute("Stamina")
	if s then return s end
	-- 3. NumberValue в персонаже
	if character then
		local obj = character:FindFirstChild("Stamina")
		if obj and (obj:IsA("NumberValue") or obj:IsA("IntValue")) then
			return obj.Value
		end
	end
	return nil
end

local function getMaxStamina(player, character)
	if character then
		local s = character:GetAttribute("MaxStamina")
		if s then return s end
	end
	local s = player:GetAttribute("MaxStamina")
	if s then return s end
	return 100 -- Значение по умолчанию
end

-- ============================================================
-- Создание ESP-интерфейса для одного игрока
-- ============================================================
local function createESP(targetPlayer)
	if targetPlayer == LocalPlayer then return end
	if espData[targetPlayer] then return end -- Уже существует

	local data = {}
	espData[targetPlayer] = data

	-- ============================
	-- BillboardGui — имя + дистанция + атрибуты
	-- ============================
	local billboard = Instance.new("BillboardGui")
	billboard.Name              = "ESP_Billboard_" .. targetPlayer.Name
	billboard.AlwaysOnTop       = true
	billboard.Size              = UDim2.new(0, 220, 0, 100)
	billboard.StudsOffset       = Vector3.new(0, 3.5, 0)
	billboard.LightInfluence    = 0
	billboard.MaxDistance        = CONFIG.MaxRenderDistance

	-- Контейнер (вертикальный список)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection  = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder      = Enum.SortOrder.LayoutOrder
	layout.Padding        = UDim.new(0, 2)
	layout.Parent         = billboard

	-- a) Имя игрока
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name             = "NameLabel"
	nameLabel.Size             = UDim2.new(1, 0, 0, 16)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3       = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Font             = Enum.Font.GothamBold
	nameLabel.TextSize         = 14
	nameLabel.Text             = targetPlayer.Name
	nameLabel.LayoutOrder      = 1
	nameLabel.Parent           = billboard

	-- b) Полоска здоровья (фон + заполнение)
	local healthBarBg = Instance.new("Frame")
	healthBarBg.Name             = "HealthBarBg"
	healthBarBg.Size             = UDim2.new(0.85, 0, 0, 6)
	healthBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	healthBarBg.BorderSizePixel  = 0
	healthBarBg.LayoutOrder      = 2
	healthBarBg.Parent           = billboard

	local healthBarFill = Instance.new("Frame")
	healthBarFill.Name             = "HealthBarFill"
	healthBarFill.Size             = UDim2.new(1, 0, 1, 0)
	healthBarFill.BackgroundColor3 = CONFIG.HealthBarColorFull
	healthBarFill.BorderSizePixel  = 0
	healthBarFill.Parent           = healthBarBg

	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, 3)
	healthCorner.Parent       = healthBarBg
	local healthFillCorner = Instance.new("UICorner")
	healthFillCorner.CornerRadius = UDim.new(0, 3)
	healthFillCorner.Parent       = healthBarFill

	-- c) Полоска выносливости (синяя)
	local staminaBarBg = Instance.new("Frame")
	staminaBarBg.Name             = "StaminaBarBg"
	staminaBarBg.Size             = UDim2.new(0.85, 0, 0, 4)
	staminaBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	staminaBarBg.BorderSizePixel  = 0
	staminaBarBg.LayoutOrder      = 3
	staminaBarBg.Parent           = billboard

	local staminaBarFill = Instance.new("Frame")
	staminaBarFill.Name             = "StaminaBarFill"
	staminaBarFill.Size             = UDim2.new(1, 0, 1, 0)
	staminaBarFill.BackgroundColor3 = CONFIG.StaminaBarColor
	staminaBarFill.BorderSizePixel  = 0
	staminaBarFill.Parent           = staminaBarBg

	local stamCorner = Instance.new("UICorner")
	stamCorner.CornerRadius = UDim.new(0, 2)
	stamCorner.Parent       = staminaBarBg
	local stamFillCorner = Instance.new("UICorner")
	stamFillCorner.CornerRadius = UDim.new(0, 2)
	stamFillCorner.Parent       = staminaBarFill

	-- d) Текст дистанции
	local distLabel = Instance.new("TextLabel")
	distLabel.Name             = "DistLabel"
	distLabel.Size             = UDim2.new(1, 0, 0, 14)
	distLabel.BackgroundTransparency = 1
	distLabel.TextColor3       = Color3.fromRGB(200, 200, 200)
	distLabel.TextStrokeTransparency = 0.4
	distLabel.Font             = Enum.Font.Gotham
	distLabel.TextSize         = 12
	distLabel.Text             = "0 studs"
	distLabel.LayoutOrder      = 4
	distLabel.Parent           = billboard

	-- g) Текст атрибутов
	local attrLabel = Instance.new("TextLabel")
	attrLabel.Name             = "AttrLabel"
	attrLabel.Size             = UDim2.new(1, 0, 0, 12)
	attrLabel.BackgroundTransparency = 1
	attrLabel.TextColor3       = Color3.fromRGB(180, 180, 255)
	attrLabel.TextStrokeTransparency = 0.5
	attrLabel.Font             = Enum.Font.Gotham
	attrLabel.TextSize         = 10
	attrLabel.Text             = ""
	attrLabel.LayoutOrder      = 5
	attrLabel.TextWrapped      = true
	attrLabel.Parent           = billboard

	-- e) Highlight (обводка персонажа)
	local highlight = Instance.new("Highlight")
	highlight.Name              = "ESP_Highlight_" .. targetPlayer.Name
	highlight.FillTransparency  = CONFIG.HighlightFillAlpha
	highlight.OutlineTransparency = CONFIG.HighlightOutlineAlpha
	highlight.FillColor         = CONFIG.HighlightColorFar
	highlight.OutlineColor      = CONFIG.HighlightColorFar
	highlight.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop

	-- f) Линия-трейсер (Beam между Attachment'ами)
	--    Создаём два аттачмента: один на локальном, другой на целевом персонаже
	local beamAttachLocal  = Instance.new("Attachment")
	beamAttachLocal.Name   = "ESP_BeamAttach_Local_" .. targetPlayer.Name

	local beamAttachTarget = Instance.new("Attachment")
	beamAttachTarget.Name  = "ESP_BeamAttach_Target_" .. targetPlayer.Name

	local beam = Instance.new("Beam")
	beam.Name          = "ESP_Beam_" .. targetPlayer.Name
	beam.Width0        = 0.05
	beam.Width1        = 0.05
	beam.Color         = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	beam.FaceCamera    = true
	beam.Transparency  = NumberSequence.new(0.5)
	beam.Attachment0   = beamAttachLocal
	beam.Attachment1   = beamAttachTarget
	beam.Segments      = 1

	-- Сохраняем ссылки
	data.billboard        = billboard
	data.nameLabel        = nameLabel
	data.healthBarFill    = healthBarFill
	data.staminaBarFill   = staminaBarFill
	data.distLabel        = distLabel
	data.attrLabel        = attrLabel
	data.highlight        = highlight
	data.beam             = beam
	data.beamAttachLocal  = beamAttachLocal
	data.beamAttachTarget = beamAttachTarget

	print("[ESP] Создан ESP для игрока:", targetPlayer.Name)
end

-- ============================================================
-- Привязка ESP-элементов к персонажу (при появлении)
-- ============================================================
local function attachESP(targetPlayer)
	local data = espData[targetPlayer]
	if not data then return end

	local character = targetPlayer.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	local hrp  = character:FindFirstChild("HumanoidRootPart")

	-- Привязываем BillboardGui к голове
	if head then
		data.billboard.Adornee = head
		data.billboard.Parent  = head  -- Альтернатива: PlayerGui, но так проще
	end

	-- Привязываем Highlight к модели персонажа
	data.highlight.Adornee = character
	data.highlight.Parent  = character

	-- Привязываем Beam-аттачменты
	if hrp then
		data.beamAttachTarget.Parent = hrp
	end

	local localChar = LocalPlayer.Character
	local localHRP  = localChar and localChar:FindFirstChild("HumanoidRootPart")
	if localHRP then
		data.beamAttachLocal.Parent = localHRP
		data.beam.Parent            = localHRP
	end
end

-- ============================================================
-- Удаление ESP для одного игрока
-- ============================================================
local function removeESP(targetPlayer)
	local data = espData[targetPlayer]
	if not data then return end

	-- Безопасно уничтожаем все элементы
	pcall(function() data.billboard:Destroy() end)
	pcall(function() data.highlight:Destroy() end)
	pcall(function() data.beam:Destroy() end)
	pcall(function() data.beamAttachLocal:Destroy() end)
	pcall(function() data.beamAttachTarget:Destroy() end)

	espData[targetPlayer] = nil
	print("[ESP] Удалён ESP для игрока:", targetPlayer.Name)
end

-- ============================================================
-- Обновление ESP каждый кадр
-- ============================================================
local function updateAllESP()
	local localChar = LocalPlayer.Character
	local localHRP  = localChar and localChar:FindFirstChild("HumanoidRootPart")

	for player, data in pairs(espData) do
		-- Проверяем, что игрок ещё в игре
		if not player.Parent then
			removeESP(player)
			continue
		end

		local character = player.Character
		if not character then
			-- Персонаж не загружен — скрываем
			data.billboard.Enabled = false
			data.highlight.Enabled = false
			data.beam.Enabled      = false
			continue
		end

		local head = character:FindFirstChild("Head")
		local hrp  = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")

		-- Перепривязываем, если нужно
		if head and data.billboard.Adornee ~= head then
			attachESP(player)
		end

		-- Дистанция
		local dist = getDistance(localChar, character)

		-- Если слишком далеко — скрываем
		if dist > CONFIG.MaxRenderDistance then
			data.billboard.Enabled = false
			data.highlight.Enabled = false
			data.beam.Enabled      = false
			continue
		end

		data.billboard.Enabled = true
		data.highlight.Enabled = true
		data.beam.Enabled      = true

		-- b) Обновляем полоску здоровья
		if humanoid then
			local fraction = humanoid.Health / humanoid.MaxHealth
			fraction = math.clamp(fraction, 0, 1)
			data.healthBarFill.Size = UDim2.new(fraction, 0, 1, 0)
			data.healthBarFill.BackgroundColor3 = lerpHealthColor(fraction)
		end

		-- c) Обновляем полоску выносливости
		local stamina    = getStamina(player, character) or 0
		local maxStamina = getMaxStamina(player, character)
		local stamFrac   = math.clamp(stamina / maxStamina, 0, 1)
		data.staminaBarFill.Size = UDim2.new(stamFrac, 0, 1, 0)

		-- d) Обновляем дистанцию
		data.distLabel.Text = string.format("%.0f studs", dist)

		-- Цвет по команде или дистанции
		local color = getColorByTeam(player) or getColorByDistance(dist)
		data.highlight.FillColor    = color
		data.highlight.OutlineColor = color
		data.nameLabel.TextColor3   = color

		-- Цвет трейсера по дистанции
		data.beam.Color = ColorSequence.new(color)

		-- g) Обновляем атрибуты
		local attrText = collectAttributes(player, character)
		data.attrLabel.Text    = attrText
		data.attrLabel.Visible = (attrText ~= "")

		-- Перепривязываем Beam, если локальный HRP изменился
		if localHRP and data.beamAttachLocal.Parent ~= localHRP then
			data.beamAttachLocal.Parent = localHRP
			data.beam.Parent            = localHRP
		end
		if hrp and data.beamAttachTarget.Parent ~= hrp then
			data.beamAttachTarget.Parent = hrp
		end
	end
end

-- ============================================================
-- Инициализация ESP для всех текущих игроков
-- ============================================================
local function startESP()
	if espActive then
		warn("[ESP] ESP уже активен!")
		return
	end
	espActive = true
	print("[ESP] ===== ЗАПУСК ESP =====")

	-- Создаём ESP для каждого игрока
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			createESP(player)
			if player.Character then
				attachESP(player)
			end
			-- Подписываемся на появление персонажа
			player.CharacterAdded:Connect(function()
				task.wait(0.5) -- Ждём загрузку модели
				attachESP(player)
			end)
		end
	end

	-- Новые игроки
	Players.PlayerAdded:Connect(function(player)
		if not espActive then return end
		createESP(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			attachESP(player)
		end)
		if player.Character then
			attachESP(player)
		end
	end)

	-- Уходящие игроки
	Players.PlayerRemoving:Connect(function(player)
		removeESP(player)
	end)

	-- Цикл обновления каждый кадр
	espConnection = RunService.RenderStepped:Connect(updateAllESP)

	print("[ESP] ESP запущен. Отслеживается", #Players:GetPlayers() - 1, "игроков.")
	print("[ESP] Для отключения вызовите: _G.ESP_Cleanup()")
end

-- ============================================================
-- Функция очистки — удаляет все ESP-элементы
-- ============================================================
local function cleanupESP()
	print("[ESP] ===== ОЧИСТКА ESP =====")
	espActive = false

	-- Отключаем RenderStepped
	if espConnection then
		espConnection:Disconnect()
		espConnection = nil
	end

	-- Удаляем все элементы
	for player, _ in pairs(espData) do
		removeESP(player)
	end
	espData = {}

	print("[ESP] Все ESP-элементы удалены.")
end

-- Регистрируем функцию очистки глобально
_G.ESP_Cleanup = cleanupESP

-- ============================================================
-- Запуск
-- ============================================================
startESP()
