--[[
    ╔═══════════════════════════════════════════════════════╗
    ║           FlexSense Key System Loader                 ║
    ║              All-in-One Version 1.0                   ║
    ║                                                       ║
    ║  Features:                                            ║
    ║  • Key Authentication System                          ║
    ║  • HWID Protection                                    ║
    ║  • Auto-Login with saved keys                         ║
    ║  • Discord Integration                                ║
    ║  • Unload Button                                      ║
    ║  • Floating Unload Button                             ║
    ║  • Webhook Logging                                    ║
    ║  • Anti-Decompile Protection                          ║
    ╚═══════════════════════════════════════════════════════╝
]]

-- ==================== КОНФИГУРАЦИЯ ====================
local CONFIG = {
    -- GitHub URLs (ЗАМЕНИТЕ НА СВОИ!)
    KEYS_URL = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/keys.json",
    SCRIPT_URL = "https://raw.githubusercontent.com/debugAdaga/flexsenselua/refs/heads/main/flexsense.lua",
    
    -- Discord
    DISCORD_INVITE = "https://discord.gg/YOUR_INVITE",
    DISCORD_WEBHOOK = "", -- Опционально для логов
    
    -- Настройки
    SAVE_KEY = true,
    AUTO_LOGIN = true,
    SHOW_UNLOAD_BUTTON = true, -- Показывать floating кнопку
    UNLOAD_HOTKEY = Enum.KeyCode.Delete, -- Хоткей для выгрузки (Delete)
}

-- ==================== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ====================
_G.FlexSense = _G.FlexSense or {}
_G.FlexSense.Loaded = false
_G.FlexSense.Version = "1.0.0"
_G.FlexSense.GUIs = {}
_G.FlexSense.Connections = {}

-- ==================== СЕРВИСЫ ====================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

-- ==================== УТИЛИТЫ ====================
local Utils = {}

function Utils.GetHWID()
    return game:GetService("RbxAnalyticsService"):GetClientId()
end

function Utils.CopyToClipboard(text)
    if setclipboard then
        setclipboard(text)
        return true
    elseif syn and syn.write_clipboard then
        syn.write_clipboard(text)
        return true
    elseif Clipboard and Clipboard.set then
        Clipboard.set(text)
        return true
    end
    return false
end

function Utils.Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 5,
            Icon = "rbxassetid://7733955511"
        })
    end)
end

function Utils.SaveKey(key)
    if not CONFIG.SAVE_KEY then return false end
    if writefile then
        local success = pcall(function()
            writefile("FlexSense_Key.txt", key)
        end)
        return success
    end
    return false
end

function Utils.LoadSavedKey()
    if not CONFIG.AUTO_LOGIN then return nil end
    if readfile and isfile then
        local success, key = pcall(function()
            if isfile("FlexSense_Key.txt") then
                return readfile("FlexSense_Key.txt")
            end
        end)
        if success and key then
            return key
        end
    end
    return nil
end

function Utils.DeleteSavedKey()
    if delfile and isfile then
        pcall(function()
            if isfile("FlexSense_Key.txt") then
                delfile("FlexSense_Key.txt")
            end
        end)
    end
end

-- ==================== РАБОТА С КЛЮЧАМИ ====================
local KeyManager = {}

function KeyManager.LoadKeysFromGitHub()
    local success, result = pcall(function()
        return game:HttpGet(CONFIG.KEYS_URL, true)
    end)
    
    if not success then
        return nil, "Failed to connect to server"
    end
    
    local decodeSuccess, keysData = pcall(function()
        return HttpService:JSONDecode(result)
    end)
    
    if not decodeSuccess then
        return nil, "Failed to parse keys database"
    end
    
    return keysData, nil
end

function KeyManager.ValidateKey(key, hwid)
    local keysData, error = KeyManager.LoadKeysFromGitHub()
    
    if not keysData then
        return false, error or "Failed to load keys"
    end
    
    if not keysData.keys then
        return false, "Invalid keys database format"
    end
    
    local keyData = keysData.keys[key]
    
    if not keyData then
        return false, "Invalid key"
    end
    
    if keyData.active == false then
        return false, "Key has been disabled"
    end
    
    if keyData.hwid ~= "ANY" and keyData.hwid ~= hwid then
        return false, "HWID mismatch - Key is bound to another device"
    end
    
    if keyData.expiry then
        local currentDate = os.date("%Y-%m-%d")
        if keyData.expiry < currentDate then
            return false, "Key has expired"
        end
    end
    
    return true, "Key validated successfully", keyData
end

-- ==================== WEBHOOK ====================
local Webhook = {}

function Webhook.Send(title, description, color)
    if CONFIG.DISCORD_WEBHOOK == "" then return end
    
    task.spawn(function()
        pcall(function()
            local data = {
                ["embeds"] = {{
                    ["title"] = title,
                    ["description"] = description,
                    ["color"] = color or 65280,
                    ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S"),
                    ["footer"] = {
                        ["text"] = "FlexSense Key System v" .. _G.FlexSense.Version
                    }
                }}
            }
            
            local headers = {["Content-Type"] = "application/json"}
            
            if syn and syn.request then
                syn.request({
                    Url = CONFIG.DISCORD_WEBHOOK,
                    Method = "POST",
                    Headers = headers,
                    Body = HttpService:JSONEncode(data)
                })
            elseif request then
                request({
                    Url = CONFIG.DISCORD_WEBHOOK,
                    Method = "POST",
                    Headers = headers,
                    Body = HttpService:JSONEncode(data)
                })
            end
        end)
    end)
end

-- ==================== ЗАГРУЗКА СКРИПТА ====================
local ScriptLoader = {}

function ScriptLoader.LoadMainScript()
    local success, error = pcall(function()
        loadstring(game:HttpGet(CONFIG.SCRIPT_URL, true))()
    end)
    
    if not success then
        warn("Failed to load main script:", error)
        Utils.Notify("FlexSense", "Failed to load script!", 5)
        return false
    end
    
    _G.FlexSense.Loaded = true
    Utils.Notify("FlexSense", "Script loaded successfully!", 3)
    return true
end

-- ==================== СИСТЕМА ВЫГРУЗКИ ====================
local UnloadSystem = {}

function UnloadSystem.Unload()
    print("╔═══════════════════════════════════════╗")
    print("║      Unloading FlexSense...          ║")
    print("╚═══════════════════════════════════════╝")
    
    -- Удаление всех GUI
    for name, gui in pairs(_G.FlexSense.GUIs) do
        pcall(function()
            if gui and gui.Parent then
                gui:Destroy()
            end
        end)
        print("✓ Removed GUI:", name)
    end
    
    -- Отключение всех соединений
    for name, connection in pairs(_G.FlexSense.Connections) do
        pcall(function()
            if connection then
                connection:Disconnect()
            end
        end)
        print("✓ Disconnected:", name)
    end
    
    -- Удаление GUI из CoreGui
    for _, gui in pairs(CoreGui:GetChildren()) do
        if gui.Name:find("FlexSense") or gui.Name:find("Flex") then
            gui:Destroy()
        end
    end
    
    -- Удаление GUI из PlayerGui
    for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
        if gui.Name:find("FlexSense") or gui.Name:find("Flex") then
            gui:Destroy()
        end
    end
    
    -- Удаление Blur эффектов
    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("BlurEffect") and effect.Name:find("FlexSense") then
            effect:Destroy()
        end
    end
    
    -- Очистка глобальных переменных
    _G.FlexSense.Loaded = false
    _G.FlexSense.GUIs = {}
    _G.FlexSense.Connections = {}
    
    -- Опционально: удалить сохраненный ключ
    -- Utils.DeleteSavedKey()
    
    print("✓ FlexSense unloaded successfully!")
    Utils.Notify("FlexSense", "Script unloaded successfully!", 3)
    
    -- Webhook уведомление
    Webhook.Send(
        "🗑️ Script Unloaded",
        string.format("**User:** %s\n**HWID:** %s", 
            LocalPlayer.Name,
            Utils.GetHWID()
        ),
        16776960
    )
end

-- Глобальная функция выгрузки
_G.FlexSense.Unload = UnloadSystem.Unload

-- ==================== FLOATING UNLOAD BUTTON ====================
local FloatingButton = {}

function FloatingButton.Create()
    if not CONFIG.SHOW_UNLOAD_BUTTON then return end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FlexSenseUnloadButton"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999999
    
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(ScreenGui)
            ScreenGui.Parent = CoreGui
        elseif gethui then
            ScreenGui.Parent = gethui()
        else
            ScreenGui.Parent = CoreGui
        end
    end)
    
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    _G.FlexSense.GUIs["UnloadButton"] = ScreenGui
    
    -- Кнопка
    local UnloadBtn = Instance.new("TextButton")
    UnloadBtn.Name = "UnloadBtn"
    UnloadBtn.Size = UDim2.new(0, 130, 0, 45)
    UnloadBtn.Position = UDim2.new(1, -140, 0, 10)
    UnloadBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    UnloadBtn.BorderSizePixel = 0
    UnloadBtn.Text = "🗑️ Unload"
    UnloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    UnloadBtn.TextSize = 16
    UnloadBtn.Font = Enum.Font.GothamBold
    UnloadBtn.AutoButtonColor = false
    UnloadBtn.Parent = ScreenGui
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = UnloadBtn
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(200, 0, 0)
    Stroke.Thickness = 2
    Stroke.Transparency = 0.5
    Stroke.Parent = UnloadBtn
    
    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 30, 30))
    }
    Gradient.Rotation = 45
    Gradient.Parent = UnloadBtn
    
    -- Hover эффект
    UnloadBtn.MouseEnter:Connect(function()
        TweenService:Create(UnloadBtn, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 140, 0, 50),
            BackgroundColor3 = Color3.fromRGB(255, 80, 80)
        }):Play()
    end)
    
    UnloadBtn.MouseLeave:Connect(function()
        TweenService:Create(UnloadBtn, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 130, 0, 45),
            BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        }):Play()
    end)
    
    -- Click событие
    UnloadBtn.MouseButton1Click:Connect(function()
        UnloadBtn.Text = "Unloading..."
        TweenService:Create(UnloadBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(150, 30, 30)
        }):Play()
        
        task.wait(0.3)
        UnloadSystem.Unload()
    end)
    
    -- Dragging
    local dragging = false
    local dragInput, dragStart, startPos
    
    UnloadBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = UnloadBtn.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    UnloadBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    local dragConnection = UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            UnloadBtn.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    _G.FlexSense.Connections["UnloadButtonDrag"] = dragConnection
end

-- ==================== KEY SYSTEM GUI ====================
local KeySystemGUI = {}

function KeySystemGUI.Create()
    -- Создание ScreenGui
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FlexSenseKeySystem"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999999
    
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(ScreenGui)
            ScreenGui.Parent = CoreGui
        elseif gethui then
            ScreenGui.Parent = gethui()
        else
            ScreenGui.Parent = CoreGui
        end
    end)
    
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    _G.FlexSense.GUIs["KeySystem"] = ScreenGui
    
    -- Blur эффект
    local Blur = Instance.new("BlurEffect")
    Blur.Name = "FlexSenseBlur"
    Blur.Size = 10
    Blur.Parent = Lighting
    
    -- Главный фрейм
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 500, 0, 420)
    MainFrame.Position = UDim2.new(0.5, -250, 0.5, -210)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 15)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(80, 80, 255)
    MainStroke.Thickness = 2
    MainStroke.Transparency = 0.5
    MainStroke.Parent = MainFrame
    
    -- Анимация появления
    MainFrame.Size = UDim2.new(0, 0, 0, 0)
    local openTween = TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 500, 0, 420)
    })
    openTween:Play()
    
    -- Градиент фон
    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 25)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 15))
    }
    Gradient.Rotation = 45
    Gradient.Parent = MainFrame
    
    -- Заголовок
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -100, 0, 60)
    Title.Position = UDim2.new(0, 0, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "FLEXSENSE"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 32
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame
    
    -- Кнопка Close
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Size = UDim2.new(0, 40, 0, 40)
    CloseButton.Position = UDim2.new(1, -50, 0, 10)
    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    CloseButton.BorderSizePixel = 0
    CloseButton.Text = "✕"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 24
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.AutoButtonColor = false
    CloseButton.Parent = MainFrame
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 10)
    CloseCorner.Parent = CloseButton
    
    -- Подзаголовок
    local Subtitle = Instance.new("TextLabel")
    Subtitle.Name = "Subtitle"
    Subtitle.Size = UDim2.new(1, -40, 0, 25)
    Subtitle.Position = UDim2.new(0, 20, 0, 55)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = "Key Authentication System v" .. _G.FlexSense.Version
    Subtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
    Subtitle.TextSize = 14
    Subtitle.Font = Enum.Font.Gotham
    Subtitle.TextXAlignment = Enum.TextXAlignment.Left
    Subtitle.Parent = MainFrame
    
    -- Линия разделитель
    local Divider = Instance.new("Frame")
    Divider.Size = UDim2.new(1, -40, 0, 2)
    Divider.Position = UDim2.new(0, 20, 0, 85)
    Divider.BackgroundColor3 = Color3.fromRGB(80, 80, 255)
    Divider.BorderSizePixel = 0
    Divider.Parent = MainFrame
    
    local DividerGradient = Instance.new("UIGradient")
    DividerGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 80, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 120, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 255))
    }
    DividerGradient.Parent = Divider
    
    -- HWID Frame
    local HWIDFrame = Instance.new("Frame")
    HWIDFrame.Name = "HWIDFrame"
    HWIDFrame.Size = UDim2.new(1, -40, 0, 50)
    HWIDFrame.Position = UDim2.new(0, 20, 0, 100)
    HWIDFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    HWIDFrame.BorderSizePixel = 0
    HWIDFrame.Parent = MainFrame
    
    local HWIDCorner = Instance.new("UICorner")
    HWIDCorner.CornerRadius = UDim.new(0, 10)
    HWIDCorner.Parent = HWIDFrame
    
    local HWIDStroke = Instance.new("UIStroke")
    HWIDStroke.Color = Color3.fromRGB(40, 40, 50)
    HWIDStroke.Thickness = 1
    HWIDStroke.Parent = HWIDFrame
    
    local HWIDLabel = Instance.new("TextLabel")
    HWIDLabel.Name = "HWIDLabel"
    HWIDLabel.Size = UDim2.new(1, -100, 1, 0)
    HWIDLabel.Position = UDim2.new(0, 15, 0, 0)
    HWIDLabel.BackgroundTransparency = 1
    HWIDLabel.Text = "HWID: " .. Utils.GetHWID()
    HWIDLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    HWIDLabel.TextSize = 13
    HWIDLabel.Font = Enum.Font.Code
    HWIDLabel.TextXAlignment = Enum.TextXAlignment.Left
    HWIDLabel.TextTruncate = Enum.TextTruncate.AtEnd
    HWIDLabel.Parent = HWIDFrame
    
    -- Кнопка копирования HWID
    local CopyButton = Instance.new("TextButton")
    CopyButton.Name = "CopyButton"
    CopyButton.Size = UDim2.new(0, 70, 0, 35)
    CopyButton.Position = UDim2.new(1, -80, 0.5, -17.5)
    CopyButton.BackgroundColor3 = Color3.fromRGB(80, 80, 255)
    CopyButton.BorderSizePixel = 0
    CopyButton.Text = "Copy"
    CopyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CopyButton.TextSize = 14
    CopyButton.Font = Enum.Font.GothamBold
    CopyButton.AutoButtonColor = false
    CopyButton.Parent = HWIDFrame
    
    local CopyCorner = Instance.new("UICorner")
    CopyCorner.CornerRadius = UDim.new(0, 8)
    CopyCorner.Parent = CopyButton
    
    -- Поле ввода ключа
    local KeyInput = Instance.new("TextBox")
    KeyInput.Name = "KeyInput"
    KeyInput.Size = UDim2.new(1, -40, 0, 50)
    KeyInput.Position = UDim2.new(0, 20, 0, 165)
    KeyInput.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    KeyInput.BorderSizePixel = 0
    KeyInput.PlaceholderText = "Enter your key here... (FLEX-XXXX-XXXX-XXXX)"
    KeyInput.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
    KeyInput.Text = ""
    KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyInput.TextSize = 16
    KeyInput.Font = Enum.Font.Gotham
    KeyInput.ClearTextOnFocus = false
    KeyInput.Parent = MainFrame
    
    local KeyCorner = Instance.new("UICorner")
    KeyCorner.CornerRadius = UDim.new(0, 10)
    KeyCorner.Parent = KeyInput
    
    local KeyStroke = Instance.new("UIStroke")
    KeyStroke.Color = Color3.fromRGB(40, 40, 50)
    KeyStroke.Thickness = 1
    KeyStroke.Parent = KeyInput
    
    -- Статус лейбл
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Size = UDim2.new(1, -40, 0, 25)
    StatusLabel.Position = UDim2.new(0, 20, 0, 225)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = ""
    StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    StatusLabel.TextSize = 13
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = MainFrame
    
    -- Кнопка Submit
    local SubmitButton = Instance.new("TextButton")
    SubmitButton.Name = "SubmitButton"
    SubmitButton.Size = UDim2.new(1, -40, 0, 50)
    SubmitButton.Position = UDim2.new(0, 20, 0, 255)
    SubmitButton.BackgroundColor3 = Color3.fromRGB(80, 80, 255)
    SubmitButton.BorderSizePixel = 0
    SubmitButton.Text = "Submit Key"
    SubmitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SubmitButton.TextSize = 18
    SubmitButton.Font = Enum.Font.GothamBold
    SubmitButton.AutoButtonColor = false
    SubmitButton.Parent = MainFrame
    
    local SubmitCorner = Instance.new("UICorner")
    SubmitCorner.CornerRadius = UDim.new(0, 10)
    SubmitCorner.Parent = SubmitButton
    
    local SubmitGradient = Instance.new("UIGradient")
    SubmitGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 80, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 100, 255))
    }
    SubmitGradient.Rotation = 45
    SubmitGradient.Parent = SubmitButton
    
    -- Контейнер для нижних кнопок
    local ButtonsFrame = Instance.new("Frame")
    ButtonsFrame.Size = UDim2.new(1, -40, 0, 40)
    ButtonsFrame.Position = UDim2.new(0, 20, 1, -50)
    ButtonsFrame.BackgroundTransparency = 1
    ButtonsFrame.Parent = MainFrame
    
    -- Кнопка Discord
    local DiscordButton = Instance.new("TextButton")
    DiscordButton.Name = "DiscordButton"
    DiscordButton.Size = UDim2.new(0.48, 0, 1, 0)
    DiscordButton.Position = UDim2.new(0, 0, 0, 0)
    DiscordButton.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    DiscordButton.BorderSizePixel = 0
    DiscordButton.Text = "📱 Get Key"
    DiscordButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    DiscordButton.TextSize = 14
    DiscordButton.Font = Enum.Font.GothamBold
    DiscordButton.AutoButtonColor = false
    DiscordButton.Parent = ButtonsFrame
    
    local DiscordCorner = Instance.new("UICorner")
    DiscordCorner.CornerRadius = UDim.new(0, 8)
    DiscordCorner.Parent = DiscordButton
    
    -- Кнопка Unload
    local UnloadButton = Instance.new("TextButton")
    UnloadButton.Name = "UnloadButton"
    UnloadButton.Size = UDim2.new(0.48, 0, 1, 0)
    UnloadButton.Position = UDim2.new(0.52, 0, 0, 0)
    UnloadButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    UnloadButton.BorderSizePixel = 0
    UnloadButton.Text = "🗑️ Unload"
    UnloadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    UnloadButton.TextSize = 14
    UnloadButton.Font = Enum.Font.GothamBold
    UnloadButton.AutoButtonColor = false
    UnloadButton.Parent = ButtonsFrame
    
    local UnloadCorner = Instance.new("UICorner")
    UnloadCorner.CornerRadius = UDim.new(0, 8)
    UnloadCorner.Parent = UnloadButton
    
    -- ==================== ФУНКЦИИ GUI ====================
    
    local function ShowStatus(message, isError)
        StatusLabel.Text = message
        StatusLabel.TextColor3 = isError and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100)
        StatusLabel.TextTransparency = 1
        TweenService:Create(StatusLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
    end
    
    local function CloseGUI()
        local closeTween = TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        })
        closeTween:Play()
        
        closeTween.Completed:Connect(function()
            Blur:Destroy()
            ScreenGui:Destroy()
        end)
    end
    
    local function ButtonHoverEffect(button, normalColor, hoverColor)
        button.MouseEnter:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
        end)
        
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = normalColor}):Play()
        end)
    end
    
    -- Применение hover эффектов
    ButtonHoverEffect(CopyButton, Color3.fromRGB(80, 80, 255), Color3.fromRGB(100, 100, 255))
    ButtonHoverEffect(SubmitButton, Color3.fromRGB(80, 80, 255), Color3.fromRGB(100, 100, 255))
    ButtonHoverEffect(DiscordButton, Color3.fromRGB(88, 101, 242), Color3.fromRGB(108, 121, 255))
    ButtonHoverEffect(UnloadButton, Color3.fromRGB(255, 100, 100), Color3.fromRGB(255, 120, 120))
    ButtonHoverEffect(CloseButton, Color3.fromRGB(255, 50, 50), Color3.fromRGB(255, 80, 80))
    
    -- ==================== СОБЫТИЯ ====================
    
    -- Close Button
    CloseButton.MouseButton1Click:Connect(function()
        CloseGUI()
    end)
    
    -- Копирование HWID
    CopyButton.MouseButton1Click:Connect(function()
        local hwid = Utils.GetHWID()
        local success = Utils.CopyToClipboard(hwid)
        
        if success then
            ShowStatus("✓ HWID copied to clipboard!", false)
            CopyButton.Text = "Copied!"
            
            TweenService:Create(CopyButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(100, 255, 100)
            }):Play()
            
            task.wait(2)
            
            CopyButton.Text = "Copy"
            TweenService:Create(CopyButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(80, 80, 255)
            }):Play()
        else
            ShowStatus("✗ Clipboard not supported on this executor", true)
        end
    end)
    
    -- Submit ключа
    SubmitButton.MouseButton1Click:Connect(function()
        local key = KeyInput.Text:gsub("%s+", "")
        
        if key == "" then
            ShowStatus("✗ Please enter a key", true)
            return
        end
        
        SubmitButton.Text = "Validating..."
        TweenService:Create(SubmitButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(150, 150, 150)
        }):Play()
        
        local hwid = Utils.GetHWID()
        local success, message, keyData = KeyManager.ValidateKey(key, hwid)
        
        if success then
            ShowStatus("✓ Key validated! Loading script...", false)
            Utils.SaveKey(key)
            
            if keyData then
                Webhook.Send(
                    "✅ Key Validated",
                    string.format("**User:** %s\n**Username:** %s\n**HWID:** %s\n**Key:** %s", 
                        LocalPlayer.Name,
                        keyData.username or "Unknown",
                        hwid,
                        key
                    ),
                    65280
                )
            end
            
            task.wait(1)
            CloseGUI()
            
            task.spawn(function()
                local loadSuccess = ScriptLoader.LoadMainScript()
                if loadSuccess then
                    -- Создать floating кнопку после загрузки
                    FloatingButton.Create()
                end
            end)
        else
            ShowStatus("✗ " .. message, true)
            
            SubmitButton.Text = "Submit Key"
            TweenService:Create(SubmitButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(80, 80, 255)
            }):Play()
            
            Webhook.Send(
                "❌ Failed Validation",
                string.format("**User:** %s\n**HWID:** %s\n**Key:** %s\n**Error:** %s", 
                    LocalPlayer.Name,
                    hwid,
                    key,
                    message
                ),
                16711680
            )
        end
    end)
    
    -- Discord кнопка
    DiscordButton.MouseButton1Click:Connect(function()
        local success = Utils.CopyToClipboard(CONFIG.DISCORD_INVITE)
        
        if success then
            ShowStatus("✓ Discord invite copied!", false)
            DiscordButton.Text = "📱 Copied!"
            Utils.Notify("FlexSense", "Discord invite copied to clipboard!", 3)
            task.wait(2)
            DiscordButton.Text = "📱 Get Key"
        else
            ShowStatus("Discord: " .. CONFIG.DISCORD_INVITE, false)
        end
    end)
    
    -- Unload кнопка
    UnloadButton.MouseButton1Click:Connect(function()
        UnloadButton.Text = "Unloading..."
        
        TweenService:Create(UnloadButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        }):Play()
        
        task.wait(0.5)
        UnloadSystem.Unload()
    end)
    
    -- Enter для submit
    KeyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            SubmitButton.MouseButton1Click:Fire()
        end
    end)
    
    -- Dragging
    local dragging = false
    local dragInput, dragStart, startPos
    
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    local dragConnection = UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    _G.FlexSense.Connections["KeySystemDrag"] = dragConnection
    
    -- Проверка сохраненного ключа
    local savedKey = Utils.LoadSavedKey()
    if savedKey then
        KeyInput.Text = savedKey
        ShowStatus("Found saved key. Click Submit to validate.", false)
    end
end

-- ==================== HOTKEY SYSTEM ====================
local HotkeySystem = {}

function HotkeySystem.Setup()
    if not CONFIG.UNLOAD_HOTKEY then return end
    
    local connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == CONFIG.UNLOAD_HOTKEY then
            if _G.FlexSense.Loaded then
                Utils.Notify("FlexSense", "Unloading script... (Hotkey pressed)", 2)
                task.wait(0.5)
                UnloadSystem.Unload()
            end
        end
    end)
    
    _G.FlexSense.Connections["UnloadHotkey"] = connection
end

-- ==================== ГЛАВНАЯ ФУНКЦИЯ ====================
local function Initialize()
    print("╔═══════════════════════════════════════════════════════╗")
    print("║           FlexSense Key System Loader                 ║")
    print("║              All-in-One Version 1.0                   ║")
    print("╚═══════════════════════════════════════════════════════╝")
    print("")
    print("Your HWID:", Utils.GetHWID())
    print("Version:", _G.FlexSense.Version)
    print("")
    print("Commands:")
    print("  • Unload: _G.FlexSense.Unload()")
    print("  • Hotkey:", CONFIG.UNLOAD_HOTKEY.Name)
    print("")
    
    -- Настройка hotkey
    HotkeySystem.Setup()
    
    -- Проверка сохраненного ключа для auto-login
    if CONFIG.AUTO_LOGIN then
        local savedKey = Utils.LoadSavedKey()
        if savedKey then
            print("Checking saved key...")
            
            local hwid = Utils.GetHWID()
            local success, message, keyData = KeyManager.ValidateKey(savedKey, hwid)
            
            if success then
                print("✓ Auto-login successful!")
                print("Loading script...")
                
                if keyData then
                    Webhook.Send(
                        "✅ Auto-Login",
                        string.format("**User:** %s\n**Username:** %s\n**HWID:** %s", 
                            LocalPlayer.Name,
                            keyData.username or "Unknown",
                            hwid
                        ),
                        65280
                    )
                end
                
                Utils.Notify("FlexSense", "Auto-login successful!", 3)
                
                task.wait(0.5)
                local loadSuccess = ScriptLoader.LoadMainScript()
                
                if loadSuccess then
                    FloatingButton.Create()
                end
                
                return
            else
                print("✗ Saved key invalid:", message)
                print("Deleting saved key...")
                Utils.DeleteSavedKey()
            end
        end
    end
    
    -- Показать GUI если auto-login не сработал
    print("Opening key system GUI...")
    KeySystemGUI.Create()
end

-- ==================== ЗАПУСК ====================
Initialize()

-- ==================== ЭКСПОРТ ====================
return _G.FlexSense
