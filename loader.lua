--[[
    FlexSense Key System Loader
    Version: 1.0.0
    Made by FlexDev
]]

local KeySystem = {}

-- ==================== КОНФИГУРАЦИЯ ====================
local CONFIG = {
    -- Замените на свои ссылки!
    KEYS_URL = "https://raw.githubusercontent.com/debugAdaga/flexsenselua/main/keys.json",
    SCRIPT_URL = "https://raw.githubusercontent.com/debugAdaga/flexsenselua/refs/heads/main/flexsense.lua",
    
    -- Опционально
    DISCORD_INVITE = "https://discord.gg/7AmNUUWf",
    DISCORD_WEBHOOK = "", -- Для логов
    
    -- Настройки
    SAVE_KEY = true, -- Сохранять ключ локально
    AUTO_LOGIN = true, -- Автоматический вход с сохраненным ключом
}

-- ==================== СЕРВИСЫ ====================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ==================== ФУНКЦИИ HWID ====================
local function GetHWID()
    local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
    return hwid
end

local function CopyToClipboard(text)
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

-- ==================== РАБОТА С КЛЮЧАМИ ====================
local function SaveKey(key)
    if not CONFIG.SAVE_KEY then return end
    
    if writefile then
        local success = pcall(function()
            writefile("FlexSense_Key.txt", key)
        end)
        return success
    end
    return false
end

local function LoadSavedKey()
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

local function DeleteSavedKey()
    if delfile and isfile then
        pcall(function()
            if isfile("FlexSense_Key.txt") then
                delfile("FlexSense_Key.txt")
            end
        end)
    end
end

-- ==================== ЗАГРУЗКА КЛЮЧЕЙ ====================
local function LoadKeysFromGitHub()
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

-- ==================== ВАЛИДАЦИЯ КЛЮЧА ====================
local function ValidateKey(key, hwid)
    -- Загрузка базы ключей
    local keysData, error = LoadKeysFromGitHub()
    
    if not keysData then
        return false, error or "Failed to load keys"
    end
    
    if not keysData.keys then
        return false, "Invalid keys database format"
    end
    
    -- Проверка существования ключа
    local keyData = keysData.keys[key]
    
    if not keyData then
        return false, "Invalid key"
    end
    
    -- Проверка активности
    if keyData.active == false then
        return false, "Key has been disabled"
    end
    
    -- Проверка HWID
    if keyData.hwid ~= "ANY" and keyData.hwid ~= hwid then
        return false, "HWID mismatch - Key is bound to another device"
    end
    
    -- Проверка срока действия
    if keyData.expiry then
        local currentDate = os.date("%Y-%m-%d")
        if keyData.expiry < currentDate then
            return false, "Key has expired"
        end
    end
    
    return true, "Key validated successfully", keyData
end

-- ==================== ЗАГРУЗКА СКРИПТА ====================
local function LoadMainScript()
    local success, error = pcall(function()
        loadstring(game:HttpGet(CONFIG.SCRIPT_URL, true))()
    end)
    
    if not success then
        warn("Failed to load main script:", error)
        return false
    end
    
    return true
end

-- ==================== DISCORD WEBHOOK ====================
local function SendWebhook(title, description, color)
    if CONFIG.DISCORD_WEBHOOK == "" then return end
    
    pcall(function()
        local data = {
            ["embeds"] = {{
                ["title"] = title,
                ["description"] = description,
                ["color"] = color or 65280,
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S"),
                ["footer"] = {
                    ["text"] = "FlexSense Key System"
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
end

-- ==================== GUI ====================
local function CreateKeyGUI()
    -- Создание ScreenGui
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FlexSenseKeySystem"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999999
    
    -- Защита GUI
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(ScreenGui)
            ScreenGui.Parent = game:GetService("CoreGui")
        elseif gethui then
            ScreenGui.Parent = gethui()
        else
            ScreenGui.Parent = game:GetService("CoreGui")
        end
    end)
    
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    -- Blur эффект
    local Blur = Instance.new("BlurEffect")
    Blur.Size = 10
    Blur.Parent = game:GetService("Lighting")
    
    -- Главный фрейм
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 500, 0, 350)
    MainFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
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
        Size = UDim2.new(0, 500, 0, 350)
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
    Title.Size = UDim2.new(1, 0, 0, 60)
    Title.Position = UDim2.new(0, 0, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "FLEXSENSE"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 32
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame
    
    -- Подзаголовок
    local Subtitle = Instance.new("TextLabel")
    Subtitle.Name = "Subtitle"
    Subtitle.Size = UDim2.new(1, -40, 0, 25)
    Subtitle.Position = UDim2.new(0, 20, 0, 55)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = "Key Authentication System"
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
    HWIDLabel.Text = "HWID: " .. GetHWID()
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
    KeyInput.PlaceholderText = "Enter your key here..."
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
    
    -- Кнопка Discord
    local DiscordButton = Instance.new("TextButton")
    DiscordButton.Name = "DiscordButton"
    DiscordButton.Size = UDim2.new(0, 140, 0, 30)
    DiscordButton.Position = UDim2.new(0.5, -70, 1, -40)
    DiscordButton.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    DiscordButton.BorderSizePixel = 0
    DiscordButton.Text = "Get Key (Discord)"
    DiscordButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    DiscordButton.TextSize = 13
    DiscordButton.Font = Enum.Font.GothamBold
    DiscordButton.AutoButtonColor = false
    DiscordButton.Parent = MainFrame
    
    local DiscordCorner = Instance.new("UICorner")
    DiscordCorner.CornerRadius = UDim.new(0, 8)
    DiscordCorner.Parent = DiscordButton
    
    -- ==================== ФУНКЦИИ GUI ====================
    
    local function ShowStatus(message, isError)
        StatusLabel.Text = message
        StatusLabel.TextColor3 = isError and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100)
        
        -- Анимация появления
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
    
    -- ==================== СОБЫТИЯ ====================
    
    -- Копирование HWID
    CopyButton.MouseButton1Click:Connect(function()
        local hwid = GetHWID()
        local success = CopyToClipboard(hwid)
        
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
        
        -- Анимация загрузки
        SubmitButton.Text = "Validating..."
        TweenService:Create(SubmitButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(150, 150, 150)
        }):Play()
        
        local hwid = GetHWID()
        local success, message, keyData = ValidateKey(key, hwid)
        
        if success then
            ShowStatus("✓ Key validated! Loading script...", false)
            SaveKey(key)
            
            -- Webhook уведомление
            if keyData then
                SendWebhook(
                    "✅ Key Validated",
                    string.format("**User:** %s\n**HWID:** %s\n**Key:** %s", 
                        keyData.username or "Unknown",
                        hwid,
                        key
                    ),
                    65280
                )
            end
            
            task.wait(1)
            CloseGUI()
            
            -- Загрузка основного скрипта
            task.spawn(function()
                local loadSuccess = LoadMainScript()
                if not loadSuccess then
                    warn("Failed to load main script")
                end
            end)
        else
            ShowStatus("✗ " .. message, true)
            
            SubmitButton.Text = "Submit Key"
            TweenService:Create(SubmitButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(80, 80, 255)
            }):Play()
            
            -- Webhook уведомление об ошибке
            SendWebhook(
                "❌ Failed Validation",
                string.format("**HWID:** %s\n**Key:** %s\n**Error:** %s", 
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
        local success = CopyToClipboard(CONFIG.DISCORD_INVITE)
        
        if success then
            ShowStatus("✓ Discord invite copied!", false)
            DiscordButton.Text = "Copied!"
            task.wait(2)
            DiscordButton.Text = "Get Key (Discord)"
        else
            ShowStatus("Discord: " .. CONFIG.DISCORD_INVITE, false)
        end
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
    
    UserInputService.InputChanged:Connect(function(input)
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
    
    -- Проверка сохраненного ключа
    local savedKey = LoadSavedKey()
    if savedKey then
        KeyInput.Text = savedKey
        ShowStatus("Found saved key. Click Submit to validate.", false)
    end
end

-- ==================== ГЛАВНАЯ ФУНКЦИЯ ====================
function KeySystem:Init()
    print("╔═══════════════════════════════════════╗")
    print("║     FlexSense Key System v1.0.0      ║")
    print("╚═══════════════════════════════════════╝")
    print("")
    print("Your HWID:", GetHWID())
    print("")
    
    -- Проверка сохраненного ключа
    if CONFIG.AUTO_LOGIN then
        local savedKey = LoadSavedKey()
        if savedKey then
            print("Checking saved key...")
            
            local hwid = GetHWID()
            local success, message, keyData = ValidateKey(savedKey, hwid)
            
            if success then
                print("✓ Auto-login successful!")
                print("Loading script...")
                
                -- Webhook
                if keyData then
                    SendWebhook(
                        "✅ Auto-Login",
                        string.format("**User:** %s\n**HWID:** %s", 
                            keyData.username or "Unknown",
                            hwid
                        ),
                        65280
                    )
                end
                
                task.wait(0.5)
                LoadMainScript()
                return
            else
                print("✗ Saved key invalid:", message)
                print("Deleting saved key...")
                DeleteSavedKey()
            end
        end
    end
    
    -- Показать GUI
    print("Opening key system GUI...")
    CreateKeyGUI()
end

-- ==================== ЗАПУСК ====================
KeySystem:Init()

return KeySystem
