--[[
    ╔═══════════════════════════════════════════════════════╗
    ║           FlexSense Admin Panel v2.1                  ║
    ║         With Auto Key Generation System               ║
    ║              PRODUCTION VERSION                       ║
    ╚═══════════════════════════════════════════════════════╝
]]

-- ==================== КОНФИГУРАЦИЯ ====================
local CONFIG = {
    -- GitHub Configuration
    GITHUB_TOKEN = "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",
    GITHUB_USERNAME = "debugAdaga",
    GITHUB_REPO = "flexsenselua",
    KEYS_FILE_PATH = "keys.json",
    
    -- Admin Settings
    ADMIN_HWIDS = {
        "D8D74D03-9D73-40AE-8BAC-01B59E0751FB", -- Ваш HWID
        -- Добавьте дополнительные HWID здесь при необходимости
    },
    
    -- Key Generation Settings
    KEY_PREFIX = "FLEX",
    KEY_SEGMENTS = 4,
    SEGMENT_LENGTH = 4,
    DEFAULT_EXPIRY_DAYS = 30,
    
    -- GUI Settings
    SKIP_GITHUB_CHECK = false, -- Включена работа с GitHub
}

-- ==================== СЕРВИСЫ ====================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- ==================== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ====================
_G.FlexAdminPanel = _G.FlexAdminPanel or {}
_G.FlexAdminPanel.Version = "2.1.0"
_G.FlexAdminPanel.GUI = nil
_G.FlexAdminPanel.KeysData = nil
_G.FlexAdminPanel.SHA = nil

-- ==================== УТИЛИТЫ ====================
local Utils = {}

function Utils.GetHWID()
    local success, hwid = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    return success and hwid or "UNKNOWN"
end

function Utils.IsAdmin()
    local hwid = Utils.GetHWID()
    print("╔═══════════════════════════════════════════════════════╗")
    print("║         Checking Admin Authorization                 ║")
    print("╚═══════════════════════════════════════════════════════╝")
    print("Your HWID:", hwid)
    print("")
    
    for i, adminHWID in ipairs(CONFIG.ADMIN_HWIDS) do
        print("Comparing with admin #" .. i .. ":", adminHWID)
        if hwid == adminHWID then
            print("✓ MATCH FOUND! Admin authorized.")
            print("")
            return true
        end
    end
    
    print("✗ NO MATCH! Access denied.")
    print("")
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

function Utils.GenerateKey()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local segments = {}
    
    for i = 1, CONFIG.KEY_SEGMENTS do
        local segment = ""
        for j = 1, CONFIG.SEGMENT_LENGTH do
            local randomIndex = math.random(1, #chars)
            segment = segment .. chars:sub(randomIndex, randomIndex)
        end
        table.insert(segments, segment)
    end
    
    return CONFIG.KEY_PREFIX .. "-" .. table.concat(segments, "-")
end

function Utils.GetCurrentDate()
    return os.date("%Y-%m-%d")
end

function Utils.AddDaysToDate(days)
    local currentTime = os.time()
    local futureTime = currentTime + (days * 24 * 60 * 60)
    return os.date("%Y-%m-%d", futureTime)
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

function Utils.CountKeys(keys)
    local count = 0
    for _ in pairs(keys) do
        count = count + 1
    end
    return count
end

function Utils.FormatDate(dateStr)
    if not dateStr or dateStr == "" then
        return "Never"
    end
    return dateStr
end

-- ==================== GITHUB API ====================
local GitHub = {}

function GitHub.Request(method, endpoint, body)
    local url = string.format(
        "https://api.github.com/repos/%s/%s/%s",
        CONFIG.GITHUB_USERNAME,
        CONFIG.GITHUB_REPO,
        endpoint
    )
    
    local headers = {
        ["Authorization"] = "token " .. CONFIG.GITHUB_TOKEN,
        ["Accept"] = "application/vnd.github.v3+json",
        ["Content-Type"] = "application/json"
    }
    
    local requestData = {
        Url = url,
        Method = method,
        Headers = headers
    }
    
    if body then
        requestData.Body = HttpService:JSONEncode(body)
    end
    
    local success, response = pcall(function()
        if syn and syn.request then
            return syn.request(requestData)
        elseif request then
            return request(requestData)
        elseif http_request then
            return http_request(requestData)
        end
        error("No HTTP request function available")
    end)
    
    if not success then
        return nil, "Request failed: " .. tostring(response)
    end
    
    if not response then
        return nil, "No response received"
    end
    
    return response, nil
end

function GitHub.GetFileContent()
    print("📥 Fetching keys from GitHub...")
    
    local response, err = GitHub.Request("GET", "contents/" .. CONFIG.KEYS_FILE_PATH)
    
    if err then
        print("✗ Error:", err)
        return nil, nil, err
    end
    
    if response.StatusCode == 404 then
        print("⚠️ keys.json not found, creating new file...")
        return {
            version = "1.0",
            keys = {}
        }, nil, nil
    end
    
    if response.StatusCode ~= 200 then
        local error = "GitHub API Error: " .. response.StatusCode
        print("✗", error)
        return nil, nil, error
    end
    
    local data = HttpService:JSONDecode(response.Body)
    local decodedContent = game:GetService("HttpService"):Base64Decode(data.content:gsub("\n", ""))
    local keysData = HttpService:JSONDecode(decodedContent)
    
    print("✓ Keys loaded successfully")
    print("  Total keys:", Utils.CountKeys(keysData.keys or {}))
    
    return keysData, data.sha, nil
end

function GitHub.UpdateFile(keysData, sha)
    print("📤 Updating keys on GitHub...")
    
    local jsonContent = HttpService:JSONEncode(keysData)
    local base64Content = game:GetService("HttpService"):Base64Encode(jsonContent)
    
    local body = {
        message = "Update keys.json via Admin Panel",
        content = base64Content,
        sha = sha
    }
    
    local response, err = GitHub.Request("PUT", "contents/" .. CONFIG.KEYS_FILE_PATH, body)
    
    if err then
        print("✗ Error:", err)
        return false, err
    end
    
    if response.StatusCode ~= 200 and response.StatusCode ~= 201 then
        local error = "GitHub API Error: " .. response.StatusCode
        print("✗", error)
        return false, error
    end
    
    -- Обновляем SHA после успешного сохранения
    local responseData = HttpService:JSONDecode(response.Body)
    _G.FlexAdminPanel.SHA = responseData.content.sha
    
    print("✓ Keys updated successfully")
    return true, "Keys updated successfully"
end

function GitHub.CreateFile(keysData)
    print("📝 Creating keys.json on GitHub...")
    
    local jsonContent = HttpService:JSONEncode(keysData)
    local base64Content = game:GetService("HttpService"):Base64Encode(jsonContent)
    
    local body = {
        message = "Create keys.json via Admin Panel",
        content = base64Content
    }
    
    local response, err = GitHub.Request("PUT", "contents/" .. CONFIG.KEYS_FILE_PATH, body)
    
    if err then
        print("✗ Error:", err)
        return false, err
    end
    
    if response.StatusCode ~= 201 then
        local error = "GitHub API Error: " .. response.StatusCode
        print("✗", error)
        return false, error
    end
    
    local responseData = HttpService:JSONDecode(response.Body)
    _G.FlexAdminPanel.SHA = responseData.content.sha
    
    print("✓ keys.json created successfully")
    return true, "File created successfully"
end

-- ==================== KEY MANAGER ====================
local KeyManager = {}

function KeyManager.LoadKeys()
    print("")
    print("╔═══════════════════════════════════════════════════════╗")
    print("║              Loading Keys from GitHub                 ║")
    print("╚═══════════════════════════════════════════════════════╝")
    
    local keysData, sha, err = GitHub.GetFileContent()
    
    if err then
        print("⚠️ Creating new keys file...")
        keysData = {
            version = "1.0",
            keys = {}
        }
        local success, message = GitHub.CreateFile(keysData)
        if not success then
            return false, "Failed to create keys file: " .. message
        end
        sha = _G.FlexAdminPanel.SHA
    end
    
    _G.FlexAdminPanel.KeysData = keysData
    _G.FlexAdminPanel.SHA = sha
    
    print("✓ Keys loaded successfully")
    print("")
    return true, "Keys loaded successfully"
end

function KeyManager.SaveKeys()
    if not _G.FlexAdminPanel.KeysData then
        return false, "No keys data to save"
    end
    
    if not _G.FlexAdminPanel.SHA then
        print("⚠️ No SHA found, creating new file...")
        return GitHub.CreateFile(_G.FlexAdminPanel.KeysData)
    end
    
    return GitHub.UpdateFile(_G.FlexAdminPanel.KeysData, _G.FlexAdminPanel.SHA)
end

function KeyManager.AddKey(keyData)
    if not _G.FlexAdminPanel.KeysData then
        return false, "Keys not loaded"
    end
    
    local key = keyData.key or Utils.GenerateKey()
    
    if _G.FlexAdminPanel.KeysData.keys[key] then
        return false, "Key already exists"
    end
    
    _G.FlexAdminPanel.KeysData.keys[key] = {
        username = keyData.username or "Unknown",
        hwid = keyData.hwid or "ANY",
        created = Utils.GetCurrentDate(),
        expiry = keyData.expiry or Utils.AddDaysToDate(CONFIG.DEFAULT_EXPIRY_DAYS),
        active = keyData.active ~= false,
        note = keyData.note or ""
    }
    
    print("✓ Key added:", key)
    
    local success, message = KeyManager.SaveKeys()
    if success then
        return true, "Key added successfully", key
    end
    
    return false, message
end

function KeyManager.DeleteKey(key)
    if not _G.FlexAdminPanel.KeysData then
        return false, "Keys not loaded"
    end
    
    if not _G.FlexAdminPanel.KeysData.keys[key] then
        return false, "Key not found"
    end
    
    _G.FlexAdminPanel.KeysData.keys[key] = nil
    print("✓ Key deleted:", key)
    
    return KeyManager.SaveKeys()
end

function KeyManager.ToggleKey(key)
    if not _G.FlexAdminPanel.KeysData then
        return false, "Keys not loaded"
    end
    
    if not _G.FlexAdminPanel.KeysData.keys[key] then
        return false, "Key not found"
    end
    
    _G.FlexAdminPanel.KeysData.keys[key].active = not _G.FlexAdminPanel.KeysData.keys[key].active
    print("✓ Key toggled:", key, "→", _G.FlexAdminPanel.KeysData.keys[key].active)
    
    return KeyManager.SaveKeys()
end

function KeyManager.UpdateKey(key, newData)
    if not _G.FlexAdminPanel.KeysData then
        return false, "Keys not loaded"
    end
    
    if not _G.FlexAdminPanel.KeysData.keys[key] then
        return false, "Key not found"
    end
    
    for k, v in pairs(newData) do
        _G.FlexAdminPanel.KeysData.keys[key][k] = v
    end
    
    print("✓ Key updated:", key)
    
    return KeyManager.SaveKeys()
end

-- ==================== GUI ====================
local GUI = {}

function GUI.CreateButton(parent, text, position, size, callback)
    local Button = Instance.new("TextButton")
    Button.Size = size or UDim2.new(0, 150, 0, 40)
    Button.Position = position
    Button.BackgroundColor3 = Color3.fromRGB(80, 80, 255)
    Button.BorderSizePixel = 0
    Button.Text = text
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.TextSize = 14
    Button.Font = Enum.Font.GothamBold
    Button.Parent = parent
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Button
    
    Button.MouseButton1Click:Connect(callback)
    
    -- Hover effect
    Button.MouseEnter:Connect(function()
        TweenService:Create(Button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(100, 100, 255)
        }):Play()
    end)
    
    Button.MouseLeave:Connect(function()
        TweenService:Create(Button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(80, 80, 255)
        }):Play()
    end)
    
    return Button
end

function GUI.CreateTextBox(parent, placeholder, position, size)
    local TextBox = Instance.new("TextBox")
    TextBox.Size = size or UDim2.new(0, 200, 0, 35)
    TextBox.Position = position
    TextBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    TextBox.BorderSizePixel = 0
    TextBox.PlaceholderText = placeholder
    TextBox.Text = ""
    TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    TextBox.TextSize = 14
    TextBox.Font = Enum.Font.Gotham
    TextBox.ClearTextOnFocus = false
    TextBox.Parent = parent
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = TextBox
    
    return TextBox
end

function GUI.CreateLabel(parent, text, position, size)
    local Label = Instance.new("TextLabel")
    Label.Size = size or UDim2.new(0, 200, 0, 30)
    Label.Position = position
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.TextSize = 14
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = parent
    
    return Label
end

function GUI.ShowAddKeyDialog(onConfirm)
    local Dialog = Instance.new("Frame")
    Dialog.Size = UDim2.new(0, 400, 0, 350)
    Dialog.Position = UDim2.new(0.5, -200, 0.5, -175)
    Dialog.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    Dialog.BorderSizePixel = 0
    Dialog.ZIndex = 100
    Dialog.Parent = _G.FlexAdminPanel.GUI
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 12)
    Corner.Parent = Dialog
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(80, 80, 255)
    Stroke.Thickness = 2
    Stroke.Parent = Dialog
    
    -- Title
    GUI.CreateLabel(Dialog, "➕ Add New Key", UDim2.new(0, 20, 0, 15), UDim2.new(1, -40, 0, 30))
    
    -- Username
    GUI.CreateLabel(Dialog, "Username:", UDim2.new(0, 20, 0, 60), UDim2.new(0, 100, 0, 25))
    local UsernameBox = GUI.CreateTextBox(Dialog, "Enter username", UDim2.new(0, 20, 0, 85), UDim2.new(1, -40, 0, 35))
    
    -- HWID
    GUI.CreateLabel(Dialog, "HWID (optional):", UDim2.new(0, 20, 0, 130), UDim2.new(0, 150, 0, 25))
    local HWIDBox = GUI.CreateTextBox(Dialog, "ANY or specific HWID", UDim2.new(0, 20, 0, 155), UDim2.new(1, -40, 0, 35))
    
    -- Expiry Days
    GUI.CreateLabel(Dialog, "Expiry (days):", UDim2.new(0, 20, 0, 200), UDim2.new(0, 150, 0, 25))
    local ExpiryBox = GUI.CreateTextBox(Dialog, "30", UDim2.new(0, 20, 0, 225), UDim2.new(1, -40, 0, 35))
    ExpiryBox.Text = "30"
    
    -- Buttons
    GUI.CreateButton(Dialog, "✓ Create", UDim2.new(0, 20, 1, -60), UDim2.new(0, 170, 0, 40), function()
        local username = UsernameBox.Text
        local hwid = HWIDBox.Text == "" and "ANY" or HWIDBox.Text
        local days = tonumber(ExpiryBox.Text) or 30
        
        if username == "" then
            Utils.Notify("Error", "Username is required!", 3)
            return
        end
        
        local success, message, key = KeyManager.AddKey({
            username = username,
            hwid = hwid,
            expiry = Utils.AddDaysToDate(days)
        })
        
        if success then
            Utils.Notify("Success", "Key created: " .. key, 5)
            Utils.CopyToClipboard(key)
            Dialog:Destroy()
            if onConfirm then onConfirm() end
        else
            Utils.Notify("Error", message, 5)
        end
    end)
    
    GUI.CreateButton(Dialog, "✕ Cancel", UDim2.new(1, -190, 1, -60), UDim2.new(0, 170, 0, 40), function()
        Dialog:Destroy()
    end).BackgroundColor3 = Color3.fromRGB(255, 50, 50)
end

function GUI.RefreshKeysList(scrollFrame)
    -- Clear existing
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    if not _G.FlexAdminPanel.KeysData or not _G.FlexAdminPanel.KeysData.keys then
        local NoKeys = GUI.CreateLabel(scrollFrame, "No keys found. Click 'Add Key' to create one.", UDim2.new(0, 10, 0, 10), UDim2.new(1, -20, 0, 30))
        NoKeys.TextXAlignment = Enum.TextXAlignment.Center
        return
    end
    
    local yOffset = 0
    local keyCount = 0
    
    for key, data in pairs(_G.FlexAdminPanel.KeysData.keys) do
        keyCount = keyCount + 1
        
        local KeyFrame = Instance.new("Frame")
        KeyFrame.Size = UDim2.new(1, -10, 0, 100)
        KeyFrame.Position = UDim2.new(0, 5, 0, yOffset)
        KeyFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        KeyFrame.BorderSizePixel = 0
        KeyFrame.Parent = scrollFrame
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 8)
        Corner.Parent = KeyFrame
        
        -- Key info
        local statusColor = data.active and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        local statusText = data.active and "🟢 ACTIVE" or "🔴 INACTIVE"
        
        GUI.CreateLabel(KeyFrame, "🔑 " .. key, UDim2.new(0, 10, 0, 5), UDim2.new(1, -20, 0, 20)).Font = Enum.Font.GothamBold
        GUI.CreateLabel(KeyFrame, "👤 " .. data.username, UDim2.new(0, 10, 0, 25), UDim2.new(0.5, -10, 0, 18))
        GUI.CreateLabel(KeyFrame, "📅 Expires: " .. Utils.FormatDate(data.expiry), UDim2.new(0.5, 0, 0, 25), UDim2.new(0.5, -10, 0, 18))
        GUI.CreateLabel(KeyFrame, "💻 HWID: " .. (data.hwid or "ANY"), UDim2.new(0, 10, 0, 43), UDim2.new(1, -20, 0, 18))
        
        local StatusLabel = GUI.CreateLabel(KeyFrame, statusText, UDim2.new(0, 10, 0, 61), UDim2.new(0, 120, 0, 18))
        StatusLabel.TextColor3 = statusColor
        StatusLabel.Font = Enum.Font.GothamBold
        
        -- Buttons
        local buttonY = 65
        local buttonWidth = 70
        local buttonSpacing = 75
        
        -- Copy button
        GUI.CreateButton(KeyFrame, "📋", UDim2.new(1, -buttonWidth - (buttonSpacing * 3), 0, buttonY), UDim2.new(0, buttonWidth, 0, 30), function()
            Utils.CopyToClipboard(key)
            Utils.Notify("Copied", "Key copied to clipboard!", 2)
        end)
        
        -- Toggle button
        GUI.CreateButton(KeyFrame, data.active and "⏸️" or "▶️", UDim2.new(1, -buttonWidth - (buttonSpacing * 2), 0, buttonY), UDim2.new(0, buttonWidth, 0, 30), function()
            local success, message = KeyManager.ToggleKey(key)
            if success then
                Utils.Notify("Success", "Key status toggled!", 2)
                GUI.RefreshKeysList(scrollFrame)
            else
                Utils.Notify("Error", message, 3)
            end
        end)
        
        -- Delete button
        local DeleteBtn = GUI.CreateButton(KeyFrame, "🗑️", UDim2.new(1, -buttonWidth - buttonSpacing, 0, buttonY), UDim2.new(0, buttonWidth, 0, 30), function()
            local success, message = KeyManager.DeleteKey(key)
            if success then
                Utils.Notify("Success", "Key deleted!", 2)
                GUI.RefreshKeysList(scrollFrame)
            else
                Utils.Notify("Error", message, 3)
            end
        end)
        DeleteBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        
        yOffset = yOffset + 110
    end
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset)
    
    if keyCount == 0 then
        local NoKeys = GUI.CreateLabel(scrollFrame, "No keys found. Click 'Add Key' to create one.", UDim2.new(0, 10, 0, 10), UDim2.new(1, -20, 0, 30))
        NoKeys.TextXAlignment = Enum.TextXAlignment.Center
    end
end

function GUI.Create()
    print("")
    print("╔═══════════════════════════════════════════════════════╗")
    print("║         FlexSense Admin Panel v2.1                    ║")
    print("╚═══════════════════════════════════════════════════════╝")
    print("")
    
    -- Check admin
    if not Utils.IsAdmin() then
        print("✗ ACCESS DENIED!")
        Utils.Notify("Access Denied", "You are not authorized!\nYour HWID: " .. Utils.GetHWID(), 10)
        
        -- Show HWID screen
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.ResetOnSpawn = false
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(0, 500, 0, 250)
        Frame.Position = UDim2.new(0.5, -250, 0.5, -125)
        Frame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        Frame.Parent = ScreenGui
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 12)
        Corner.Parent = Frame
        
        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, -40, 0, 50)
        Title.Position = UDim2.new(0, 20, 0, 20)
        Title.BackgroundTransparency = 1
        Title.Text = "⛔ ACCESS DENIED"
        Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        Title.TextSize = 28
        Title.Font = Enum.Font.GothamBold
        Title.Parent = Frame
        
        local HWIDLabel = Instance.new("TextLabel")
        HWIDLabel.Size = UDim2.new(1, -40, 0, 140)
        HWIDLabel.Position = UDim2.new(0, 20, 0, 80)
        HWIDLabel.BackgroundTransparency = 1
        HWIDLabel.Text = "Your HWID:\n" .. Utils.GetHWID() .. "\n\nAdd this to CONFIG.ADMIN_HWIDS\n(Copied to clipboard)"
        HWIDLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        HWIDLabel.TextSize = 16
        HWIDLabel.Font = Enum.Font.Gotham
        HWIDLabel.TextWrapped = true
        HWIDLabel.Parent = Frame
        
        Utils.CopyToClipboard(Utils.GetHWID())
        
        return
    end
    
    print("✓ Admin authorized")
    
    -- Load keys
    local success, message = KeyManager.LoadKeys()
    if not success then
        Utils.Notify("Warning", message, 5)
    end
    
    -- Create GUI
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FlexAdminPanel"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999999
    
    pcall(function()
        ScreenGui.Parent = CoreGui
    end)
    
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    _G.FlexAdminPanel.GUI = ScreenGui
    
    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 900, 0, 650)
    MainFrame.Position = UDim2.new(0.5, -450, 0.5, -325)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(80, 80, 255)
    MainStroke.Thickness = 2
    MainStroke.Transparency = 0.5
    MainStroke.Parent = MainFrame
    
    -- Header
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 60)
    Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    Header.BorderSizePixel = 0
    Header.Parent = MainFrame
    
    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 12)
    HeaderCorner.Parent = Header
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -120, 1, 0)
    Title.Position = UDim2.new(0, 20, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "🔐 FlexSense Admin Panel v" .. _G.FlexAdminPanel.Version
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 24
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header
    
    -- Close Button
    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 40, 0, 40)
    CloseButton.Position = UDim2.new(1, -50, 0.5, -20)
    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    CloseButton.BorderSizePixel = 0
    CloseButton.Text = "✕"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 20
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Parent = Header
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 8)
    CloseCorner.Parent = CloseButton
    
    -- Info Bar
    local InfoBar = Instance.new("Frame")
    InfoBar.Size = UDim2.new(1, -40, 0, 50)
    InfoBar.Position = UDim2.new(0, 20, 0, 70)
    InfoBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    InfoBar.BorderSizePixel = 0
    InfoBar.Parent = MainFrame
    
    local InfoCorner = Instance.new("UICorner")
    InfoCorner.CornerRadius = UDim.new(0, 8)
    InfoCorner.Parent = InfoBar
    
    local InfoLabel = GUI.CreateLabel(InfoBar, "📊 Total Keys: " .. Utils.CountKeys(_G.FlexAdminPanel.KeysData and _G.FlexAdminPanel.KeysData.keys or {}), UDim2.new(0, 15, 0, 0), UDim2.new(0.5, -15, 1, 0))
    InfoLabel.TextSize = 16
    InfoLabel.Font = Enum.Font.GothamBold
    InfoLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    
    local HWIDLabel = GUI.CreateLabel(InfoBar, "💻 Your HWID: " .. Utils.GetHWID():sub(1, 25) .. "...", UDim2.new(0.5, 0, 0, 0), UDim2.new(0.5, -15, 1, 0))
    HWIDLabel.TextSize = 14
    
    -- Buttons Bar
    local ButtonsBar = Instance.new("Frame")
    ButtonsBar.Size = UDim2.new(1, -40, 0, 50)
    ButtonsBar.Position = UDim2.new(0, 20, 0, 130)
    ButtonsBar.BackgroundTransparency = 1
    ButtonsBar.Parent = MainFrame
    
    -- Keys List
    local KeysFrame = Instance.new("Frame")
    KeysFrame.Size = UDim2.new(1, -40, 1, -200)
    KeysFrame.Position = UDim2.new(0, 20, 0, 190)
    KeysFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    KeysFrame.BorderSizePixel = 0
    KeysFrame.Parent = MainFrame
    
    local KeysCorner = Instance.new("UICorner")
    KeysCorner.CornerRadius = UDim.new(0, 8)
    KeysCorner.Parent = KeysFrame
    
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -10, 1, -10)
    ScrollFrame.Position = UDim2.new(0, 5, 0, 5)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 255)
    ScrollFrame.Parent = KeysFrame
    
    -- Buttons
    GUI.CreateButton(ButtonsBar, "➕ Add Key", UDim2.new(0, 0, 0, 0), UDim2.new(0, 150, 0, 45), function()
        GUI.ShowAddKeyDialog(function()
            InfoLabel.Text = "📊 Total Keys: " .. Utils.CountKeys(_G.FlexAdminPanel.KeysData.keys)
            GUI.RefreshKeysList(ScrollFrame)
        end)
    end)
    
    GUI.CreateButton(ButtonsBar, "🔄 Refresh", UDim2.new(0, 160, 0, 0), UDim2.new(0, 150, 0, 45), function()
        local success, message = KeyManager.LoadKeys()
        if success then
            Utils.Notify("Success", "Keys refreshed!", 2)
            InfoLabel.Text = "📊 Total Keys: " .. Utils.CountKeys(_G.FlexAdminPanel.KeysData.keys)
            GUI.RefreshKeysList(ScrollFrame)
        else
            Utils.Notify("Error", message, 3)
        end
    end)
    
    GUI.CreateButton(ButtonsBar, "🎲 Generate Key", UDim2.new(0, 320, 0, 0), UDim2.new(0, 150, 0, 45), function()
        local key = Utils.GenerateKey()
        Utils.CopyToClipboard(key)
        Utils.Notify("Generated", "Key copied: " .. key, 5)
    end)
    
    GUI.CreateButton(ButtonsBar, "📋 Copy HWID", UDim2.new(0, 480, 0, 0), UDim2.new(0, 150, 0, 45), function()
        Utils.CopyToClipboard(Utils.GetHWID())
        Utils.Notify("Copied", "Your HWID copied to clipboard!", 2)
    end)
    
    -- Initial load
    GUI.RefreshKeysList(ScrollFrame)
    
    -- Close button event
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)
    
    -- Dragging
    local dragging = false
    local dragInput, dragStart, startPos
    
    Header.InputBegan:Connect(function(input)
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
    
    Header.InputChanged:Connect(function(input)
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
    
    print("✓ GUI created successfully!")
    print("")
    Utils.Notify("FlexSense", "Admin Panel loaded successfully!", 5)
end

-- ==================== ЗАПУСК ====================
print("")
print("╔═══════════════════════════════════════════════════════╗")
print("║         FlexSense Admin Panel v2.1                    ║")
print("║              Starting...                              ║")
print("╚═══════════════════════════════════════════════════════╝")
print("")

GUI.Create()

print("╔═══════════════════════════════════════════════════════╗")
print("║         Admin Panel Ready!                            ║")
print("╚═══════════════════════════════════════════════════════╝")
print("")

return _G.FlexAdminPanel
