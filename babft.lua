-- Gemini-XALoEX
-- Build A Boat For Treasure Copier & Autofarm Hub
-- Created by Antigravity AI

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- Check for existing GUI to avoid duplicates
local oldGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("BABFT_Copier_Hub")
if oldGui then
    oldGui:Destroy()
end

-- Main ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BABFT_Copier_Hub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Variables for status
local farmEnabled = false
local blockSubstitution = true
local selectedPlayer = nil
local savedBuildsIndex = {}

-- Block groups for substitution
local blockGroups = {
    { "WoodBlock", "WoodBlock2", "BambooBlock", "FabricBlock" },
    { "StoneBlock", "ConcreteBlock", "BrickBlock", "SandBlock", "CoalBlock", "GraniteBlock" },
    { "MetalBlock", "SteelBlock", "TitaniumBlock", "GoldBlock", "ObsidianBlock", "RustBlock" },
    { "GlassBlock", "IceBlock", "NeonBlock", "PlasticBlock" },
    { "PlasticBlock", "WoodBlock", "FabricBlock" }
}

-- File System Check
local function hasFileSystem()
    return writefile ~= nil and readfile ~= nil
end

-- Helper: Load index of saved builds
local function loadIndex()
    if not hasFileSystem() then return end
    local success, content = pcall(function()
        return readfile("babft_builds_index.json")
    end)
    if success and content then
        local status, decoded = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if status and decoded then
            savedBuildsIndex = decoded
            return
        end
    end
    savedBuildsIndex = {}
end

-- Helper: Save index of saved builds
local function saveIndex()
    if not hasFileSystem() then return end
    pcall(function()
        writefile("babft_builds_index.json", HttpService:JSONEncode(savedBuildsIndex))
    end)
end

loadIndex()

-- Helper: Find a player's plot base and blocks
local function getPlot(player)
    if not player then return nil end
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, p in ipairs(plots:GetChildren()) do
            local owner = p:FindFirstChild("Owner")
            if owner and (owner.Value == player or owner.Value == player.Name or tostring(owner.Value) == player.Name) then
                return p
            end
        end
    end
    local team = player.Team
    if team and plots then
        local p = plots:FindFirstChild(team.Name)
        if p then return p end
    end
    return nil
end

local function getPlotBase(plot)
    if not plot then return nil end
    local base = plot:FindFirstChild("Base") 
        or plot:FindFirstChild("BuildZone") 
        or plot:FindFirstChild("Ground") 
        or plot:FindFirstChild("Floor")
    if not base then
        for _, child in ipairs(plot:GetChildren()) do
            if child:IsA("BasePart") and child.Size.X > 50 and child.Size.Z > 50 then
                base = child
                break
            end
        end
    end
    return base
end

-- Get blocks from a player's plot
local function getBlocksFromPlot(plot)
    local list = {}
    local plotBase = getPlotBase(plot)
    if not plotBase then return list end
    
    for _, child in ipairs(plot:GetDescendants()) do
        if child:IsA("BasePart") and child ~= plotBase and child.Name ~= "PlotSign" and child.Name ~= "BuildZone" then
            local relCFrame = plotBase.CFrame:ToObjectSpace(child.CFrame)
            table.insert(list, {
                name = child.Name,
                relCFrame = relCFrame,
                size = child.Size,
                color = child.Color,
                material = child.Material,
                transparency = child.Transparency
            })
        end
    end
    return list
end

-- Get block inventory count
local function getBlockInventoryCount(blockName)
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local inventory = data:FindFirstChild("Inventory") or data
        local blockValue = inventory:FindFirstChild(blockName)
        if blockValue and (blockValue:IsA("IntValue") or blockValue:IsA("NumberValue")) then
            return blockValue.Value
        end
    end
    return 9999 -- Fallback default
end

-- Get block substitute
local function getAvailableSubstitute(blockName, usedCounts)
    local owned = getBlockInventoryCount(blockName)
    local used = usedCounts[blockName] or 0
    if owned - used >= 1 then
        usedCounts[blockName] = used + 1
        return blockName
    end
    
    for _, group in ipairs(blockGroups) do
        local foundOriginal = false
        for _, name in ipairs(group) do
            if name == blockName then
                foundOriginal = true
                break
            end
        end
        if foundOriginal then
            for _, subName in ipairs(group) do
                local subOwned = getBlockInventoryCount(subName)
                local subUsed = usedCounts[subName] or 0
                if subOwned - subUsed >= 1 then
                    usedCounts[subName] = subUsed + 1
                    return subName
                end
            end
        end
    end
    
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local inventory = data:FindFirstChild("Inventory") or data
        for _, child in ipairs(inventory:GetChildren()) do
            if child:IsA("IntValue") or child:IsA("NumberValue") then
                local name = child.Name
                local count = child.Value
                local used = usedCounts[name] or 0
                if count - used >= 1 then
                    usedCounts[name] = used + 1
                    return name
                end
            end
        end
    end
    
    usedCounts[blockName] = used + 1
    return blockName
end

-- Remote Action Helpers
local function scaleBlock(part, size, position)
    local provider = workspace:FindFirstChild("ItemServiceProvider")
    if not provider then return end
    local rescale = provider:FindFirstChild("Rescale")
    if rescale then
        rescale:InvokeServer(part, size, position)
        return
    end
    local scale = provider:FindFirstChild("Scale")
    if scale then
        scale:InvokeServer(part, size, position)
        return
    end
end

local function paintBlock(part, color)
    local provider = workspace:FindFirstChild("ItemServiceProvider")
    if not provider then return end
    local paint = provider:FindFirstChild("Paint")
    if paint then
        paint:InvokeServer(part, color)
    end
end

-- UI Setup
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 600, 0, 400)
MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

-- UICorner for main frame
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = MainFrame

-- UIStroke for glowing border
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(0, 255, 255)
mainStroke.Thickness = 2
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
mainStroke.Parent = MainFrame

-- UIGradient for border
local strokeGradient = Instance.new("UIGradient")
strokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 0, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 255))
})
strokeGradient.Parent = mainStroke

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundTransparency = 1
TitleBar.Parent = MainFrame

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -40, 1, 0)
TitleText.Position = UDim2.new(0, 15, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.TextSize = 18
TitleText.Font = Enum.Font.Outfit
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Text = "Gemini-XALoEX - BABFT Copier & AutoFarm"
TitleText.Parent = TitleBar

-- Close button
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -35, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
CloseButton.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseButton.Text = "X"
CloseButton.TextSize = 16
CloseButton.Font = Enum.Font.Outfit
CloseButton.Parent = TitleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = CloseButton

CloseButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Make main frame draggable
local function makeDraggable(guiObj)
    local dragging, dragInput, dragStart, startPos
    guiObj.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObj.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    guiObj.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end
makeDraggable(MainFrame)

-- Mobile Floating Toggle Button
local FloatToggle = Instance.new("TextButton")
FloatToggle.Name = "FloatToggle"
FloatToggle.Size = UDim2.new(0, 50, 0, 50)
FloatToggle.Position = UDim2.new(0.9, -10, 0.1, 0)
FloatToggle.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
FloatToggle.TextColor3 = Color3.fromRGB(0, 255, 255)
FloatToggle.Text = "Menu"
FloatToggle.TextSize = 14
FloatToggle.Font = Enum.Font.Outfit
FloatToggle.Parent = ScreenGui

local floatCorner = Instance.new("UICorner")
floatCorner.CornerRadius = UDim.new(0, 25)
floatCorner.Parent = FloatToggle

local floatStroke = Instance.new("UIStroke")
floatStroke.Color = Color3.fromRGB(0, 255, 255)
floatStroke.Thickness = 1.5
floatStroke.Parent = FloatToggle

FloatToggle.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)
makeDraggable(FloatToggle)

-- Tabs container
local TabsContainer = Instance.new("Frame")
TabsContainer.Name = "TabsContainer"
TabsContainer.Size = UDim2.new(0, 120, 1, -50)
TabsContainer.Position = UDim2.new(0, 10, 0, 45)
TabsContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
TabsContainer.BorderSizePixel = 0
TabsContainer.Parent = MainFrame

local tabsCorner = Instance.new("UICorner")
tabsCorner.CornerRadius = UDim.new(0, 8)
tabsCorner.Parent = TabsContainer

-- Tab Content Frames
local ContentContainer = Instance.new("Frame")
ContentContainer.Name = "ContentContainer"
ContentContainer.Size = UDim2.new(1, -150, 1, -50)
ContentContainer.Position = UDim2.new(0, 140, 0, 45)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

-- Copier Tab Frame
local CopierFrame = Instance.new("Frame")
CopierFrame.Name = "CopierFrame"
CopierFrame.Size = UDim2.new(1, 0, 1, 0)
CopierFrame.BackgroundTransparency = 1
CopierFrame.Visible = true
CopierFrame.Parent = ContentContainer

-- Farm Tab Frame
local FarmFrame = Instance.new("Frame")
FarmFrame.Name = "FarmFrame"
FarmFrame.Size = UDim2.new(1, 0, 1, 0)
FarmFrame.BackgroundTransparency = 1
FarmFrame.Visible = false
FarmFrame.Parent = ContentContainer

-- Saved Tab Frame
local SavedFrame = Instance.new("Frame")
SavedFrame.Name = "SavedFrame"
SavedFrame.Size = UDim2.new(1, 0, 1, 0)
SavedFrame.BackgroundTransparency = 1
SavedFrame.Visible = false
SavedFrame.Parent = ContentContainer

-- Tab Buttons Creator
local currentTab = "Copier"
local function createTabButton(name, text, positionY)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 40)
    button.Position = UDim2.new(0, 5, 0, positionY)
    button.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    button.TextColor3 = Color3.fromRGB(200, 200, 200)
    button.Text = text
    button.TextSize = 14
    button.Font = Enum.Font.Outfit
    button.Parent = TabsContainer

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = button

    button.MouseButton1Click:Connect(function()
        currentTab = name
        CopierFrame.Visible = (name == "Copier")
        FarmFrame.Visible = (name == "Farm")
        SavedFrame.Visible = (name == "Saved")
        
        -- Reset highlights
        for _, child in ipairs(TabsContainer:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                child.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
        button.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
        button.TextColor3 = Color3.fromRGB(15, 15, 20)
    end)
    
    if name == currentTab then
        button.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
        button.TextColor3 = Color3.fromRGB(15, 15, 20)
    end
end

createTabButton("Copier", "Копирование", 10)
createTabButton("Farm", "Автофарм", 60)
createTabButton("Saved", "Сохранения", 110)

-- ==========================================
-- COPIER TAB IMPLEMENTATION
-- ==========================================

-- Player Selection Scrolling List (Tierlist style)
local PlayerListScroll = Instance.new("ScrollingFrame")
PlayerListScroll.Size = UDim2.new(0.5, -5, 1, -50)
PlayerListScroll.Position = UDim2.new(0, 0, 0, 0)
PlayerListScroll.BackgroundTransparency = 1
PlayerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerListScroll.ScrollBarThickness = 4
PlayerListScroll.Parent = CopierFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = PlayerListScroll

-- Control area on the right of Copier Tab
local ControlPanel = Instance.new("Frame")
ControlPanel.Size = UDim2.new(0.5, -5, 1, -50)
ControlPanel.Position = UDim2.new(0.5, 5, 0, 0)
ControlPanel.BackgroundTransparency = 1
ControlPanel.Parent = CopierFrame

local SelectedPlayerLabel = Instance.new("TextLabel")
SelectedPlayerLabel.Size = UDim2.new(1, 0, 0, 30)
SelectedPlayerLabel.Position = UDim2.new(0, 0, 0, 10)
SelectedPlayerLabel.BackgroundTransparency = 1
SelectedPlayerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SelectedPlayerLabel.TextSize = 16
SelectedPlayerLabel.Font = Enum.Font.Outfit
SelectedPlayerLabel.Text = "Цель: не выбрана"
SelectedPlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
SelectedPlayerLabel.Parent = ControlPanel

-- Copy Button
local CopyButton = Instance.new("TextButton")
CopyButton.Size = UDim2.new(1, 0, 0, 45)
CopyButton.Position = UDim2.new(0, 0, 0, 50)
CopyButton.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
CopyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyButton.Text = "Копировать постройку"
CopyButton.TextSize = 16
CopyButton.Font = Enum.Font.Outfit
CopyButton.Parent = ControlPanel

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 8)
copyCorner.Parent = CopyButton

-- Substitution Toggle Button
local SubsButton = Instance.new("TextButton")
SubsButton.Size = UDim2.new(1, 0, 0, 40)
SubsButton.Position = UDim2.new(0, 0, 0, 105)
SubsButton.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
SubsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SubsButton.Text = "Автозамена блоков: ВКЛ"
SubsButton.TextSize = 14
SubsButton.Font = Enum.Font.Outfit
SubsButton.Parent = ControlPanel

local subsCorner = Instance.new("UICorner")
subsCorner.CornerRadius = UDim.new(0, 8)
subsCorner.Parent = SubsButton

SubsButton.MouseButton1Click:Connect(function()
    blockSubstitution = not blockSubstitution
    if blockSubstitution then
        SubsButton.Text = "Автозамена блоков: ВКЛ"
        SubsButton.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
    else
        SubsButton.Text = "Автозамена блоков: ВЫКЛ"
        SubsButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    end
end)

-- Save to Slot Text Box
local SaveNameBox = Instance.new("TextBox")
SaveNameBox.Size = UDim2.new(1, 0, 0, 35)
SaveNameBox.Position = UDim2.new(0, 0, 0, 155)
SaveNameBox.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
SaveNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveNameBox.PlaceholderText = "Имя сохранения..."
SaveNameBox.Text = ""
SaveNameBox.TextSize = 14
SaveNameBox.Font = Enum.Font.Outfit
SaveNameBox.Parent = ControlPanel

local saveNameCorner = Instance.new("UICorner")
saveNameCorner.CornerRadius = UDim.new(0, 6)
saveNameCorner.Parent = SaveNameBox

-- Save Button
local SaveButton = Instance.new("TextButton")
SaveButton.Size = UDim2.new(1, 0, 0, 40)
SaveButton.Position = UDim2.new(0, 0, 0, 200)
SaveButton.BackgroundColor3 = Color3.fromRGB(120, 50, 180)
SaveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveButton.Text = "Сохранить скопированное"
SaveButton.TextSize = 14
SaveButton.Font = Enum.Font.Outfit
SaveButton.Parent = ControlPanel

local saveCorner = Instance.new("UICorner")
saveCorner.CornerRadius = UDim.new(0, 8)
saveCorner.Parent = SaveButton

-- Status Info
local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, 0, 0, 30)
StatusText.Position = UDim2.new(0, 0, 1, -25)
StatusText.BackgroundTransparency = 1
StatusText.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.Outfit
StatusText.Text = "Готов к работе..."
StatusText.TextXAlignment = Enum.TextXAlignment.Center
StatusText.Parent = CopierFrame

-- Global variable to hold copied build in memory
local copiedBlocksMemory = nil

-- Update Player List Function
local function updatePlayerList()
    -- Clear current list
    for _, child in ipairs(PlayerListScroll:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local index = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            index = index + 1
            local pButton = Instance.new("TextButton")
            pButton.Size = UDim2.new(1, -10, 0, 35)
            pButton.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
            pButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            pButton.TextSize = 14
            pButton.Font = Enum.Font.Outfit
            pButton.Parent = PlayerListScroll
            
            local teamColor = player.Team and player.Team.TeamColor.Color or Color3.fromRGB(200, 200, 200)
            pButton.Text = player.Name .. " [" .. (player.Team and player.Team.Name or "No Team") .. "]"
            
            -- Glowing team stroke
            local stroke = Instance.new("UIStroke")
            stroke.Color = teamColor
            stroke.Thickness = 1
            stroke.Parent = pButton
            
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = pButton
            
            pButton.MouseButton1Click:Connect(function()
                selectedPlayer = player
                SelectedPlayerLabel.Text = "Цель: " .. player.Name
                -- Highlight target
                for _, child in ipairs(PlayerListScroll:GetChildren()) do
                    if child:IsA("TextButton") then
                        child.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
                    end
                end
                pButton.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            end)
        end
    end
    PlayerListScroll.CanvasSize = UDim2.new(0, 0, 0, index * 40)
end

updatePlayerList()
Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)

-- Copy and Build Execution
CopyButton.MouseButton1Click:Connect(function()
    if not selectedPlayer then
        StatusText.Text = "Ошибка: выберите игрока сначала!"
        return
    end
    
    local targetPlot = getPlot(selectedPlayer)
    if not targetPlot then
        StatusText.Text = "Ошибка: не удалось найти плот игрока!"
        return
    end
    
    StatusText.Text = "Сканирование постройки..."
    local blocks = getBlocksFromPlot(targetPlot)
    
    if #blocks == 0 then
        StatusText.Text = "Ошибка: постройка пуста!"
        return
    end
    
    copiedBlocksMemory = blocks
    StatusText.Text = "Успешно скопировано: " .. #blocks .. " блоков!"
    
    -- Now trigger building on our own plot
    task.spawn(function()
        StatusText.Text = "Постройка начата... Ждите."
        
        local myPlot = getPlot(LocalPlayer)
        local myBase = getPlotBase(myPlot)
        if not myBase then
            StatusText.Text = "Ошибка: не найден ваш плот!"
            return
        end
        
        local provider = workspace:FindFirstChild("ItemServiceProvider")
        local itemRemote = provider and provider:FindFirstChild("Item")
        if not itemRemote then
            StatusText.Text = "Ошибка: не найден remote для постройки!"
            return
        end
        
        local usedCounts = {}
        local buildSuccessCount = 0
        
        for i, block in ipairs(blocks) do
            local targetBlockName = block.name
            if blockSubstitution then
                targetBlockName = getAvailableSubstitute(block.name, usedCounts)
            end
            
            -- Translate CFrame to our plot base
            local worldCFrame = myBase.CFrame:ToWorldSpace(block.relCFrame)
            local pos = worldCFrame.Position
            
            local rx, ry, rz = worldCFrame:ToEulerAnglesXYZ()
            local rot = Vector3.new(math.deg(rx), math.deg(ry), math.deg(rz))
            
            -- Invoke server placement
            local success, placedPart = pcall(function()
                return itemRemote:InvokeServer(targetBlockName, pos, rot, nil, true, nil)
            end)
            
            if success and placedPart and placedPart:IsA("BasePart") then
                buildSuccessCount = buildSuccessCount + 1
                
                -- Rescale if different
                if (placedPart.Size - block.size).Magnitude > 0.05 then
                    scaleBlock(placedPart, block.size, pos)
                end
                
                -- Repaint if different
                if placedPart.Color ~= block.color then
                    paintBlock(placedPart, block.color)
                end
            end
            
            -- Update UI status
            StatusText.Text = "Построено: " .. buildSuccessCount .. "/" .. #blocks .. " блоков..."
            task.wait(0.015)
        end
        
        StatusText.Text = "Готово! Успешно построено " .. buildSuccessCount .. " блоков!"
    end)
end)

-- Save Build Execution
SaveButton.MouseButton1Click:Connect(function()
    if not copiedBlocksMemory or #copiedBlocksMemory == 0 then
        StatusText.Text = "Ошибка: нечего сохранять (сначала скопируйте постройку)!"
        return
    end
    
    local saveName = SaveNameBox.Text
    if saveName == "" then
        StatusText.Text = "Ошибка: укажите имя сохранения!"
        return
    end
    
    if not hasFileSystem() then
        StatusText.Text = "Ошибка: ваш эксплоит не поддерживает файловую систему!"
        return
    end
    
    -- Serialize build data
    local serializedBlocks = {}
    for _, block in ipairs(copiedBlocksMemory) do
        local rx, ry, rz = block.relCFrame:ToEulerAnglesXYZ()
        table.insert(serializedBlocks, {
            name = block.name,
            pos = { block.relCFrame.Position.X, block.relCFrame.Position.Y, block.relCFrame.Position.Z },
            rot = { rx, ry, rz },
            size = { block.size.X, block.size.Y, block.size.Z },
            color = { block.color.R, block.color.G, block.color.B }
        })
    end
    
    local buildContent = HttpService:JSONEncode(serializedBlocks)
    local fileName = "babft_build_" .. saveName .. ".json"
    
    pcall(function()
        writefile(fileName, buildContent)
        
        -- Add to index if not exists
        local exists = false
        for _, name in ipairs(savedBuildsIndex) do
            if name == saveName then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(savedBuildsIndex, saveName)
            saveIndex()
        end
        StatusText.Text = "Постройка успешно сохранена в файл!"
    end)
end)


-- ==========================================
-- SAVED BUILDS TAB IMPLEMENTATION
-- ==========================================

local SavedListScroll = Instance.new("ScrollingFrame")
SavedListScroll.Size = UDim2.new(0.5, -5, 1, -50)
SavedListScroll.Position = UDim2.new(0, 0, 0, 0)
SavedListScroll.BackgroundTransparency = 1
SavedListScroll.ScrollBarThickness = 4
SavedListScroll.Parent = SavedFrame

local savedListLayout = Instance.new("UIListLayout")
savedListLayout.Padding = UDim.new(0, 5)
savedListLayout.Parent = SavedListScroll

local SavedControlPanel = Instance.new("Frame")
SavedControlPanel.Size = UDim2.new(0.5, -5, 1, -50)
SavedControlPanel.Position = UDim2.new(0.5, 5, 0, 0)
SavedControlPanel.BackgroundTransparency = 1
SavedControlPanel.Parent = SavedFrame

local SelectedSaveLabel = Instance.new("TextLabel")
SelectedSaveLabel.Size = UDim2.new(1, 0, 0, 30)
SelectedSaveLabel.Position = UDim2.new(0, 0, 0, 10)
SelectedSaveLabel.BackgroundTransparency = 1
SelectedSaveLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SelectedSaveLabel.TextSize = 16
SelectedSaveLabel.Font = Enum.Font.Outfit
SelectedSaveLabel.Text = "Выбранный слот: нет"
SelectedSaveLabel.TextXAlignment = Enum.TextXAlignment.Left
SelectedSaveLabel.Parent = SavedControlPanel

-- Load Button
local LoadButton = Instance.new("TextButton")
LoadButton.Size = UDim2.new(1, 0, 0, 45)
LoadButton.Position = UDim2.new(0, 0, 0, 50)
LoadButton.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
LoadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
LoadButton.Text = "Построить из сохранения"
LoadButton.TextSize = 16
LoadButton.Font = Enum.Font.Outfit
LoadButton.Parent = SavedControlPanel

local loadCorner = Instance.new("UICorner")
loadCorner.CornerRadius = UDim.new(0, 8)
loadCorner.Parent = LoadButton

-- Delete Save Button
local DeleteSaveButton = Instance.new("TextButton")
DeleteSaveButton.Size = UDim2.new(1, 0, 0, 40)
DeleteSaveButton.Position = UDim2.new(0, 0, 0, 105)
DeleteSaveButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
DeleteSaveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
DeleteSaveButton.Text = "Удалить сохранение"
DeleteSaveButton.TextSize = 14
DeleteSaveButton.Font = Enum.Font.Outfit
DeleteSaveButton.Parent = SavedControlPanel

local deleteCorner = Instance.new("UICorner")
deleteCorner.CornerRadius = UDim.new(0, 8)
deleteCorner.Parent = DeleteSaveButton

local SavedStatusText = Instance.new("TextLabel")
SavedStatusText.Size = UDim2.new(1, 0, 0, 30)
SavedStatusText.Position = UDim2.new(0, 0, 1, -25)
SavedStatusText.BackgroundTransparency = 1
SavedStatusText.TextColor3 = Color3.fromRGB(200, 200, 200)
SavedStatusText.TextSize = 12
SavedStatusText.Font = Enum.Font.Outfit
SavedStatusText.Text = "Файловая система готова..."
SavedStatusText.Parent = SavedFrame

local selectedSaveName = nil

-- Update Saved Files List
local function updateSavedList()
    for _, child in ipairs(SavedListScroll:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    loadIndex()
    
    local index = 0
    for _, saveName in ipairs(savedBuildsIndex) do
        index = index + 1
        local sButton = Instance.new("TextButton")
        sButton.Size = UDim2.new(1, -10, 0, 35)
        sButton.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        sButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        sButton.Text = saveName
        sButton.TextSize = 14
        sButton.Font = Enum.Font.Outfit
        sButton.Parent = SavedListScroll
        
        local sStroke = Instance.new("UIStroke")
        sStroke.Color = Color3.fromRGB(120, 50, 180)
        sStroke.Thickness = 1
        sStroke.Parent = sButton
        
        local sCorner = Instance.new("UICorner")
        sCorner.CornerRadius = UDim.new(0, 6)
        sCorner.Parent = sButton
        
        sButton.MouseButton1Click:Connect(function()
            selectedSaveName = saveName
            SelectedSaveLabel.Text = "Выбранный слот: " .. saveName
            
            for _, child in ipairs(SavedListScroll:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
                end
            end
            sButton.BackgroundColor3 = Color3.fromRGB(50, 40, 70)
        end)
    end
    SavedListScroll.CanvasSize = UDim2.new(0, 0, 0, index * 40)
end

updateSavedList()

-- Load and Paste Build from File
LoadButton.MouseButton1Click:Connect(function()
    if not selectedSaveName then
        SavedStatusText.Text = "Ошибка: выберите сохранение из списка!"
        return
    end
    
    if not hasFileSystem() then
        SavedStatusText.Text = "Ошибка: нет доступа к файлам!"
        return
    end
    
    local fileName = "babft_build_" .. selectedSaveName .. ".json"
    local success, content = pcall(function()
        return readfile(fileName)
    end)
    
    if not success or not content then
        SavedStatusText.Text = "Ошибка: не удалось прочитать файл!"
        return
    end
    
    local status, decoded = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    
    if not status or not decoded then
        SavedStatusText.Text = "Ошибка: файл поврежден!"
        return
    end
    
    -- Reconstruct blocks list from JSON representation
    local blocks = {}
    for _, rawBlock in ipairs(decoded) do
        local relCFrame = CFrame.new(rawBlock.pos[1], rawBlock.pos[2], rawBlock.pos[3]) 
            * CFrame.fromEulerAnglesXYZ(rawBlock.rot[1], rawBlock.rot[2], rawBlock.rot[3])
        table.insert(blocks, {
            name = rawBlock.name,
            relCFrame = relCFrame,
            size = Vector3.new(rawBlock.size[1], rawBlock.size[2], rawBlock.size[3]),
            color = Color3.new(rawBlock.color[1], rawBlock.color[2], rawBlock.color[3])
        })
    end
    
    -- Build on plot
    task.spawn(function()
        SavedStatusText.Text = "Загрузка и постройка..."
        
        local myPlot = getPlot(LocalPlayer)
        local myBase = getPlotBase(myPlot)
        if not myBase then
            SavedStatusText.Text = "Ошибка: ваш плот не найден!"
            return
        end
        
        local provider = workspace:FindFirstChild("ItemServiceProvider")
        local itemRemote = provider and provider:FindFirstChild("Item")
        if not itemRemote then
            SavedStatusText.Text = "Ошибка: нет remote для постройки!"
            return
        end
        
        local usedCounts = {}
        local buildSuccessCount = 0
        
        for i, block in ipairs(blocks) do
            local targetBlockName = block.name
            if blockSubstitution then
                targetBlockName = getAvailableSubstitute(block.name, usedCounts)
            end
            
            local worldCFrame = myBase.CFrame:ToWorldSpace(block.relCFrame)
            local pos = worldCFrame.Position
            
            local rx, ry, rz = worldCFrame:ToEulerAnglesXYZ()
            local rot = Vector3.new(math.deg(rx), math.deg(ry), math.deg(rz))
            
            local placeSuccess, placedPart = pcall(function()
                return itemRemote:InvokeServer(targetBlockName, pos, rot, nil, true, nil)
            end)
            
            if placeSuccess and placedPart and placedPart:IsA("BasePart") then
                buildSuccessCount = buildSuccessCount + 1
                
                if (placedPart.Size - block.size).Magnitude > 0.05 then
                    scaleBlock(placedPart, block.size, pos)
                end
                
                if placedPart.Color ~= block.color then
                    paintBlock(placedPart, block.color)
                end
            end
            
            SavedStatusText.Text = "Построено: " .. buildSuccessCount .. "/" .. #blocks .. " блоков..."
            task.wait(0.015)
        end
        
        SavedStatusText.Text = "Постройка успешно завершена!"
    end)
end)

-- Delete Save Execution
DeleteSaveButton.MouseButton1Click:Connect(function()
    if not selectedSaveName then
        SavedStatusText.Text = "Ошибка: выберите сохранение!"
        return
    end
    
    for i, name in ipairs(savedBuildsIndex) do
        if name == selectedSaveName then
            table.remove(savedBuildsIndex, i)
            break
        end
    end
    saveIndex()
    
    if hasFileSystem() then
        pcall(function()
            -- Depending on exploit version, there may not be delfile/deletefile
            -- But we can overwrite it with empty file or just remove from index
            delfile("babft_build_" .. selectedSaveName .. ".json")
        end)
    end
    
    selectedSaveName = nil
    SelectedSaveLabel.Text = "Выбранный слот: нет"
    updateSavedList()
    SavedStatusText.Text = "Сохранение удалено."
end)


-- ==========================================
-- AUTOFARM TAB IMPLEMENTATION
-- ==========================================

local FarmTitle = Instance.new("TextLabel")
FarmTitle.Size = UDim2.new(1, 0, 0, 30)
FarmTitle.Position = UDim2.new(0, 0, 0, 10)
FarmTitle.BackgroundTransparency = 1
FarmTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
FarmTitle.TextSize = 18
FarmTitle.Font = Enum.Font.Outfit
FarmTitle.Text = "Золотой Автофарм (Безопасный)"
FarmTitle.TextXAlignment = Enum.TextXAlignment.Left
FarmTitle.Parent = FarmFrame

local FarmInfo = Instance.new("TextLabel")
FarmInfo.Size = UDim2.new(1, 0, 0, 80)
FarmInfo.Position = UDim2.new(0, 0, 0, 45)
FarmInfo.BackgroundTransparency = 1
FarmInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
FarmInfo.TextSize = 13
FarmInfo.Font = Enum.Font.Outfit
FarmInfo.TextWrapped = true
FarmInfo.TextXAlignment = Enum.TextXAlignment.Left
FarmInfo.Text = "Безопасный автофарм перемещает вашего персонажа через ключевые контрольные точки каждой зоны с небольшой задержкой (0.8с) для полноценного начисления золота сервером без бана."
FarmInfo.Parent = FarmFrame

-- Farm Toggle Button
local FarmToggleButton = Instance.new("TextButton")
FarmToggleButton.Size = UDim2.new(1, 0, 0, 50)
FarmToggleButton.Position = UDim2.new(0, 0, 0, 140)
FarmToggleButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
FarmToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
FarmToggleButton.Text = "Автофарм: ВЫКЛЮЧЕН"
FarmToggleButton.TextSize = 16
FarmToggleButton.Font = Enum.Font.Outfit
FarmToggleButton.Parent = FarmFrame

local farmToggleCorner = Instance.new("UICorner")
farmToggleCorner.CornerRadius = UDim.new(0, 10)
farmToggleCorner.Parent = FarmToggleButton

local FarmStatus = Instance.new("TextLabel")
FarmStatus.Size = UDim2.new(1, 0, 0, 30)
FarmStatus.Position = UDim2.new(0, 0, 0, 200)
FarmStatus.BackgroundTransparency = 1
FarmStatus.TextColor3 = Color3.fromRGB(0, 255, 255)
FarmStatus.TextSize = 14
FarmStatus.Font = Enum.Font.Outfit
FarmStatus.Text = "Статус: Ожидание..."
FarmStatus.Parent = FarmFrame

-- Stages extraction helper
local function getStages()
    local list = {}
    local stagesFolder = workspace:FindFirstChild("BoatStages") and workspace.BoatStages:FindFirstChild("NormalStages")
    if stagesFolder then
        for i = 1, 10 do
            local stage = stagesFolder:FindFirstChild("CaveStage" .. i)
            if stage then
                table.insert(list, stage)
            end
        end
        local endStage = stagesFolder:FindFirstChild("TheEnd") or stagesFolder:FindFirstChild("CaveStage11")
        if endStage then
            table.insert(list, endStage)
        end
    end
    return list
end

local function getStagePart(stage)
    if not stage then return nil end
    return stage:FindFirstChild("DarknessPart") 
        or stage:FindFirstChild("Stage") 
        or stage:FindFirstChild("Ground") 
        or stage:FindFirstChild("Base") 
        or stage.PrimaryPart 
        or stage:FindFirstChildOfClass("Part")
end

-- Autofarm Loop Routine
local function startAutofarm()
    task.spawn(function()
        while farmEnabled do
            local character = LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not root then
                FarmStatus.Text = "Статус: Ожидание возрождения персонажа..."
                task.wait(1)
                continue
            end
            
            -- Prevent gravity issues or falling during tp
            local platform = Instance.new("Part")
            platform.Size = Vector3.new(12, 1, 12)
            platform.Color = Color3.fromRGB(0, 255, 255)
            platform.Material = Enum.Material.ForceField
            platform.Anchored = true
            platform.Parent = workspace
            
            local stageList = getStages()
            if #stageList == 0 then
                FarmStatus.Text = "Статус: Ошибка поиска стадий! Ожидание..."
                platform:Destroy()
                task.wait(2)
                continue
            end
            
            local completedStages = 0
            for i, stage in ipairs(stageList) do
                if not farmEnabled then break end
                local part = getStagePart(stage)
                if part then
                    FarmStatus.Text = "Статус: Прохождение зоны " .. i .. "/" .. #stageList .. "..."
                    local targetPos = part.Position + Vector3.new(0, 6, 0)
                    platform.CFrame = CFrame.new(targetPos - Vector3.new(0, 3, 0))
                    root.CFrame = CFrame.new(targetPos)
                    completedStages = completedStages + 1
                    task.wait(0.85) -- Steady delay to avoid server flags
                end
            end
            
            -- Teleport to final chest
            local stagesFolder = workspace:FindFirstChild("BoatStages") and workspace.BoatStages:FindFirstChild("NormalStages")
            local theEnd = stagesFolder and stagesFolder:FindFirstChild("TheEnd")
            local chest = theEnd and theEnd:FindFirstChild("Chest")
            
            if chest and farmEnabled then
                FarmStatus.Text = "Статус: Открытие сундука с золотом..."
                platform.CFrame = CFrame.new(chest.Position - Vector3.new(0, 3, 0))
                root.CFrame = CFrame.new(chest.Position + Vector3.new(0, 3, 0))
                task.wait(2.5) -- Time to register chest touch
            end
            
            platform:Destroy()
            
            -- Auto reset to restart cycle
            if farmEnabled then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.Health = 0
                end
                FarmStatus.Text = "Статус: Перезапуск цикла..."
                task.wait(4.5) -- Wait for respawn
            end
        end
    end)
end

FarmToggleButton.MouseButton1Click:Connect(function()
    farmEnabled = not farmEnabled
    if farmEnabled then
        FarmToggleButton.Text = "Автофарм: ВКЛЮЧЕН"
        FarmToggleButton.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
        startAutofarm()
    else
        FarmToggleButton.Text = "Автофарм: ВЫКЛЮЧЕН"
        FarmToggleButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        FarmStatus.Text = "Статус: Остановлен"
    end
end)


-- GUI Toggle Key listener (RightShift)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- Initial UI state
MainFrame.Visible = true
StatusText.Text = "Hub загружен! Нажмите RightShift чтобы скрыть/показать."

-- Gemini-XALoEX
