--[[
	============================================================
	  01_style_spoof.lua — Симуляция подмены игрового стиля
	============================================================
	  Назначение:
	    Проверяет серверную валидацию при попытке изменить
	    игровой стиль персонажа на неавторизованное значение.
	    Сервер ДОЛЖЕН отклонять любые несанкционированные
	    изменения стиля, приходящие от клиента.

	  Что тестируется:
	    1. Прямая установка атрибута 'GameStyle' на игрока
	    2. Изменение StringValue 'Style' внутри игрока/персонажа
	    3. Отправка RemoteEvent 'ChangeStyle' с поддельными данными
	    4. Попытка установить несуществующие / запрещённые стили

	  Ожидаемый результат:
	    Сервер должен отклонить ВСЕ попытки. Стиль должен
	    остаться прежним или вернуться к значению по умолчанию.

	  Использование:
	    Вставить в CommandBar в Roblox Studio (режим Play Solo
	    или Play с локальным сервером).
	============================================================
]]

-- === Сервисы ===
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- === Получаем локального игрока ===
local localPlayer = Players.LocalPlayer
if not localPlayer then
	warn("[StyleSpoof] Ошибка: LocalPlayer не найден. Запустите в режиме Play.")
	return
end

print("==============================================")
print("[StyleSpoof] Начинаем тест подмены стиля")
print("[StyleSpoof] Игрок: " .. localPlayer.Name)
print("==============================================")

-- === Список неавторизованных значений для тестирования ===
local spoofedStyles = {
	"HACKED_STYLE",          -- Несуществующий стиль
	"Admin",                 -- Попытка выдать себя за админа
	"",                      -- Пустая строка
	"Style'; DROP TABLE--",  -- SQL-инъекция (на всякий случай)
	string.rep("A", 1000),   -- Очень длинная строка
	"Default",               -- Легитимное имя, но не присвоенное
	"VIP_EXCLUSIVE",         -- Стиль, требующий покупку
	"__internal__",          -- Системное имя
}

-- ============================================================
-- ТЕСТ 1: Прямая установка атрибута 'GameStyle'
-- ============================================================
print("\n--- Тест 1: Установка атрибута 'GameStyle' на игрока ---")

local originalAttribute = localPlayer:GetAttribute("GameStyle")
print("[StyleSpoof] Текущее значение атрибута 'GameStyle': " .. tostring(originalAttribute))

for i, style in ipairs(spoofedStyles) do
	local displayStyle = (#style > 50) and (style:sub(1, 50) .. "...") or style
	print(string.format("  [%d/%d] Устанавливаю атрибут 'GameStyle' = '%s'", i, #spoofedStyles, displayStyle))

	local success, err = pcall(function()
		localPlayer:SetAttribute("GameStyle", style)
	end)

	if success then
		local newValue = localPlayer:GetAttribute("GameStyle")
		print(string.format("    → Установлено. Текущее значение: '%s'", tostring(newValue)))
		print("    ⚠ ВНИМАНИЕ: Клиент смог установить атрибут. Сервер должен проверить и откатить.")
	else
		print(string.format("    ✓ Отклонено на клиенте: %s", tostring(err)))
	end

	task.wait(0.1) -- Небольшая задержка между попытками
end

-- ============================================================
-- ТЕСТ 2: Изменение StringValue 'Style' внутри игрока
-- ============================================================
print("\n--- Тест 2: Изменение StringValue 'Style' внутри игрока ---")

-- Ищем StringValue 'Style' в игроке
local styleValue = localPlayer:FindFirstChild("Style")
if not styleValue then
	-- Ищем в персонаже
	local character = localPlayer.Character
	if character then
		styleValue = character:FindFirstChild("Style")
	end
end

if styleValue and styleValue:IsA("StringValue") then
	local originalValue = styleValue.Value
	print("[StyleSpoof] Найден StringValue 'Style'. Текущее значение: " .. tostring(originalValue))

	for i, style in ipairs(spoofedStyles) do
		local displayStyle = (#style > 50) and (style:sub(1, 50) .. "...") or style
		print(string.format("  [%d/%d] Устанавливаю Style.Value = '%s'", i, #spoofedStyles, displayStyle))

		local success, err = pcall(function()
			styleValue.Value = style
		end)

		if success then
			print(string.format("    → Значение изменено на: '%s'", tostring(styleValue.Value)))
			print("    ⚠ Сервер должен обнаружить и откатить изменение.")
		else
			print(string.format("    ✓ Отклонено: %s", tostring(err)))
		end

		task.wait(0.1)
	end

	-- Восстанавливаем оригинальное значение
	pcall(function()
		styleValue.Value = originalValue
	end)
	print("[StyleSpoof] Восстановлено оригинальное значение: " .. tostring(originalValue))
else
	print("[StyleSpoof] StringValue 'Style' не найден в игроке/персонаже. Пропускаем тест 2.")
end

-- ============================================================
-- ТЕСТ 3: Отправка RemoteEvent 'ChangeStyle' с поддельными данными
-- ============================================================
print("\n--- Тест 3: Отправка RemoteEvent 'ChangeStyle' ---")

-- Ищем RemoteEvent в разных местах
local remoteEvent = nil
local searchPaths = {
	ReplicatedStorage:FindFirstChild("ChangeStyle"),
	ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ChangeStyle"),
	ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("ChangeStyle"),
	ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("ChangeStyle"),
}

for _, found in ipairs(searchPaths) do
	if found and found:IsA("RemoteEvent") then
		remoteEvent = found
		break
	end
end

if remoteEvent then
	print("[StyleSpoof] Найден RemoteEvent 'ChangeStyle': " .. remoteEvent:GetFullName())

	for i, style in ipairs(spoofedStyles) do
		local displayStyle = (#style > 50) and (style:sub(1, 50) .. "...") or style
		print(string.format("  [%d/%d] Отправляю RemoteEvent с значением '%s'", i, #spoofedStyles, displayStyle))

		local success, err = pcall(function()
			remoteEvent:FireServer(style)
		end)

		if success then
			print("    → Запрос отправлен. Ожидаем отклонение сервером.")
		else
			print(string.format("    ✓ Ошибка при отправке: %s", tostring(err)))
		end

		task.wait(0.2) -- Задержка между отправками
	end

	-- Дополнительный тест: отправляем некорректные типы данных
	print("\n  Дополнительно: отправка некорректных типов данных...")
	local badPayloads = {
		{value = 12345, desc = "число вместо строки"},
		{value = true, desc = "boolean"},
		{value = {nested = "table"}, desc = "таблица"},
		{value = nil, desc = "nil"},
		{value = Instance.new("Part"), desc = "Instance (Part)"},
	}

	for _, payload in ipairs(badPayloads) do
		print(string.format("  → Отправляю %s (%s)", tostring(payload.value), payload.desc))
		pcall(function()
			remoteEvent:FireServer(payload.value)
		end)
		task.wait(0.1)
	end
else
	print("[StyleSpoof] RemoteEvent 'ChangeStyle' не найден. Пропускаем тест 3.")
	print("[StyleSpoof] Подсказка: создайте RemoteEvent 'ChangeStyle' в ReplicatedStorage для полного теста.")
end

-- ============================================================
-- ИТОГИ
-- ============================================================
print("\n==============================================")
print("[StyleSpoof] Тестирование завершено!")
print("[StyleSpoof] Проверьте серверный лог (Output) на наличие:")
print("  - Сообщений об отклонении подмены стиля")
print("  - Предупреждений о несанкционированном доступе")
print("  - Откат изменённых значений к оригинальным")
print("[StyleSpoof] Ожидаемое поведение сервера:")
print("  ✓ Все попытки подмены ОТКЛОНЕНЫ")
print("  ✓ Стиль игрока НЕ изменился")
print("  ✓ Попытки залогированы для анализа")
print("==============================================")
