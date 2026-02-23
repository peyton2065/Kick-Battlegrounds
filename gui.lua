--[[
    ╔══════════════════════════════════════════╗
    ║          KICK MASTER PRO v3.1            ║
    ║    Auto-kick + God Mode for kick games   ║
    ║       Compatible with Xeno Executor      ║
    ╚══════════════════════════════════════════╝
    
    Controls:
      • RightShift — Toggle GUI visibility
      • Drag titlebar to reposition
      • Adjust kick delay via input box
      • Drag shield speed slider to adjust
--]]

---------------------------------------------------------------
-- SERVICES
---------------------------------------------------------------
local Players      = game:GetService("Players")
local RepStorage   = game:GetService("ReplicatedStorage")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local LocalPlayer  = Players.LocalPlayer

---------------------------------------------------------------
-- CONFIGURATION
---------------------------------------------------------------
local Config = {
    ToggleKey    = Enum.KeyCode.RightShift,
    DefaultDelay = 0.15,
    MinDelay     = 0.01,
    MaxDelay     = 5,

    ShieldMin     = 0.01,
    ShieldMax     = 1.0,
    ShieldDefault = 0.05,

    KickRemotePath = function()
        local ok, remote = pcall(function()
            local lp = Players.LocalPlayer
            local tool = lp.Backpack:FindFirstChild("Kick")
            if not tool and lp.Character then
                tool = lp.Character:FindFirstChild("Kick")
            end
            return tool and tool:FindFirstChild("KickEvent") or nil
        end)
        return ok and remote or nil
    end,

    ShieldRemotePath = function()
        local ok, remote = pcall(function()
            return RepStorage:FindFirstChild("ShieldEvent")
        end)
        return ok and remote or nil
    end,

    Theme = {
        Bg            = Color3.fromRGB(18, 18, 26),
        Surface       = Color3.fromRGB(28, 28, 40),
        SurfaceLight  = Color3.fromRGB(38, 38, 54),
        Accent        = Color3.fromRGB(110, 68, 255),
        AccentHover   = Color3.fromRGB(135, 98, 255),
        Text          = Color3.fromRGB(242, 242, 248),
        TextSub       = Color3.fromRGB(155, 155, 175),
        TextMuted     = Color3.fromRGB(95, 95, 115),
        Green         = Color3.fromRGB(68, 195, 112),
        GreenHover    = Color3.fromRGB(88, 215, 132),
        Cyan          = Color3.fromRGB(56, 189, 248),
        CyanDim       = Color3.fromRGB(30, 100, 140),
        Red           = Color3.fromRGB(245, 66, 66),
        RedHover      = Color3.fromRGB(255, 95, 95),
        Yellow        = Color3.fromRGB(250, 190, 50),
        Border        = Color3.fromRGB(48, 48, 68),
    },
}

local T = Config.Theme

---------------------------------------------------------------
-- STATE
---------------------------------------------------------------
local State = {
    kickActive    = false,
    shieldActive  = false,
    minimized     = false,
    visible       = true,
    delay         = Config.DefaultDelay,
    shieldDelay   = Config.ShieldDefault,
    kicks         = 0,
    shieldFires   = 0,
    dragging      = false,
    dragStart     = Vector3.zero,
    framePos      = UDim2.new(),
    sliderDrag    = false,
}

---------------------------------------------------------------
-- UI HELPERS
---------------------------------------------------------------
local function tw(obj, props, dur)
    TweenService:Create(obj,
        TweenInfo.new(dur or 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        props
    ):Play()
end

local function addCorner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c
end

local function addStroke(p, col, th)
    local s = Instance.new("UIStroke")
    s.Color = col or T.Border; s.Thickness = th or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
end

local function addPadding(p, t, r, b, l)
    local pd = Instance.new("UIPadding")
    pd.PaddingTop    = UDim.new(0, t or 0)
    pd.PaddingRight  = UDim.new(0, r or t or 0)
    pd.PaddingBottom = UDim.new(0, b or t or 0)
    pd.PaddingLeft   = UDim.new(0, l or r or t or 0)
    pd.Parent = p; return pd
end

local function label(props)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.BorderSizePixel = 0
    for k, v in pairs(props) do lbl[k] = v end
    return lbl
end

---------------------------------------------------------------
-- SCREEN GUI
---------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "KickMasterPro_" .. tostring(math.random(1e4, 9e4))
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

---------------------------------------------------------------
-- NOTIFICATION SYSTEM
---------------------------------------------------------------
local notifHolder = Instance.new("Frame")
notifHolder.Name = "Notifs"
notifHolder.Size = UDim2.new(0, 260, 1, -20)
notifHolder.Position = UDim2.new(1, -270, 0, 10)
notifHolder.BackgroundTransparency = 1
notifHolder.Parent = gui

local notifLayout = Instance.new("UIListLayout")
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifLayout.Padding = UDim.new(0, 5)
notifLayout.Parent = notifHolder

local function notify(msg, col, dur)
    col = col or T.Accent; dur = dur or 3

    local n = Instance.new("Frame")
    n.Size = UDim2.new(1, 0, 0, 34)
    n.BackgroundColor3 = T.Surface
    n.BackgroundTransparency = 1
    n.BorderSizePixel = 0
    n.Parent = notifHolder
    addCorner(n, 8); addStroke(n, col, 1)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0.55, 0)
    bar.Position = UDim2.new(0, 8, 0.225, 0)
    bar.BackgroundColor3 = col; bar.BorderSizePixel = 0
    bar.Parent = n; addCorner(bar, 2)

    label{
        Size = UDim2.new(1, -22, 1, 0),
        Position = UDim2.new(0, 18, 0, 0),
        Text = msg, TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextColor3 = T.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = n,
    }

    tw(n, {BackgroundTransparency = 0.05}, 0.25)
    task.delay(dur, function()
        tw(n, {BackgroundTransparency = 1}, 0.25)
        task.wait(0.28)
        pcall(function() n:Destroy() end)
    end)
end

---------------------------------------------------------------
-- MAIN WINDOW
---------------------------------------------------------------
local W, H = 370, 580
local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.new(0, W, 0, H)
window.Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2)
window.BackgroundColor3 = T.Bg
window.BorderSizePixel = 0
window.ClipsDescendants = true
window.Parent = gui
addCorner(window, 12); addStroke(window, T.Border, 1.5)

-- ========== TITLE BAR ==========
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = T.Surface
titleBar.BorderSizePixel = 0
titleBar.Parent = window
addCorner(titleBar, 12)

local tbFix = Instance.new("Frame")
tbFix.Size = UDim2.new(1, 0, 0, 14)
tbFix.Position = UDim2.new(0, 0, 1, -14)
tbFix.BackgroundColor3 = T.Surface; tbFix.BorderSizePixel = 0
tbFix.Parent = titleBar

local accentLine = Instance.new("Frame")
accentLine.Size = UDim2.new(1, 0, 0, 2)
accentLine.Position = UDim2.new(0, 0, 0, 46)
accentLine.BackgroundColor3 = T.Accent; accentLine.BorderSizePixel = 0
accentLine.Parent = window

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, T.Accent),
    ColorSequenceKeypoint.new(0.5, T.AccentHover),
    ColorSequenceKeypoint.new(1, T.Accent),
}; grad.Parent = accentLine

label{
    Size = UDim2.new(0, 24, 1, 0), Position = UDim2.new(0, 14, 0, 0),
    Text = "🦶", TextSize = 18, Font = Enum.Font.SourceSans,
    TextColor3 = T.Text, Parent = titleBar,
}

label{
    Size = UDim2.new(0, 160, 1, 0), Position = UDim2.new(0, 40, 0, 0),
    Text = "KICK MASTER PRO", TextSize = 14, Font = Enum.Font.GothamBold,
    TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
    Parent = titleBar,
}

local verBadge = label{
    Size = UDim2.new(0, 30, 0, 16), Position = UDim2.new(0, 188, 0.5, -8),
    Text = "v3.1", TextSize = 9, Font = Enum.Font.GothamBold,
    TextColor3 = T.AccentHover, Parent = titleBar,
}
verBadge.BackgroundTransparency = 0.75
verBadge.BackgroundColor3 = T.Accent
addCorner(verBadge, 4)

local function ctrlBtn(text, color, posX)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 28, 0, 28)
    b.Position = UDim2.new(1, posX, 0.5, -14)
    b.BackgroundColor3 = color; b.BackgroundTransparency = 0.85
    b.Text = text; b.TextSize = 12; b.Font = Enum.Font.GothamBold
    b.TextColor3 = color; b.BorderSizePixel = 0; b.AutoButtonColor = false
    b.Parent = titleBar; addCorner(b, 6)
    b.MouseEnter:Connect(function() tw(b, {BackgroundTransparency = 0.45}, 0.12) end)
    b.MouseLeave:Connect(function() tw(b, {BackgroundTransparency = 0.85}, 0.12) end)
    return b
end

local closeBtn    = ctrlBtn("✕", T.Red,    -38)
local minimizeBtn = ctrlBtn("─", T.Yellow, -70)

-- ========== CONTENT AREA ==========
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, -24, 1, -60)
content.Position = UDim2.new(0, 12, 0, 54)
content.BackgroundTransparency = 1
content.ClipsDescendants = true
content.Parent = window

-- ========== STATUS PANEL (3 rows) ==========
local statusPanel = Instance.new("Frame")
statusPanel.Size = UDim2.new(1, 0, 0, 120)
statusPanel.BackgroundColor3 = T.Surface; statusPanel.BorderSizePixel = 0
statusPanel.Parent = content; addCorner(statusPanel, 8)

-- ======== ROW 1: KICK STATUS ========
local kickRing = Instance.new("Frame")
kickRing.Size = UDim2.new(0, 14, 0, 14)
kickRing.Position = UDim2.new(0, 10, 0, 10)
kickRing.BackgroundColor3 = T.Red; kickRing.BackgroundTransparency = 0.8
kickRing.BorderSizePixel = 0; kickRing.Parent = statusPanel; addCorner(kickRing, 7)

local kickDot = Instance.new("Frame")
kickDot.Size = UDim2.new(0, 6, 0, 6)
kickDot.Position = UDim2.new(0, 14, 0, 14)
kickDot.BackgroundColor3 = T.Red; kickDot.BorderSizePixel = 0
kickDot.Parent = statusPanel; addCorner(kickDot, 3)

local kickStatusLabel = label{
    Size = UDim2.new(0, 140, 0, 14), Position = UDim2.new(0, 30, 0, 8),
    Text = "KICK: INACTIVE", TextSize = 11, Font = Enum.Font.GothamBold,
    TextColor3 = T.Red, TextXAlignment = Enum.TextXAlignment.Left,
    Parent = statusPanel,
}

local kickStatsLabel = label{
    Size = UDim2.new(0, 180, 0, 12), Position = UDim2.new(0, 30, 0, 23),
    Text = "Fires: 0  •  Delay: 0.15s", TextSize = 9, Font = Enum.Font.Gotham,
    TextColor3 = T.TextSub, TextXAlignment = Enum.TextXAlignment.Left,
    Parent = statusPanel,
}

-- kick delay input
label{
    Size = UDim2.new(0, 32, 0, 14), Position = UDim2.new(1, -98, 0, 10),
    Text = "Kick:", TextSize = 10, Font = Enum.Font.Gotham,
    TextColor3 = T.TextSub, TextXAlignment = Enum.TextXAlignment.Right,
    Parent = statusPanel,
}

local delayInput = Instance.new("TextBox")
delayInput.Size = UDim2.new(0, 50, 0, 22)
delayInput.Position = UDim2.new(1, -60, 0, 7)
delayInput.BackgroundColor3 = T.SurfaceLight
delayInput.Text = tostring(Config.DefaultDelay)
delayInput.PlaceholderText = "0.15"
delayInput.TextSize = 11; delayInput.Font = Enum.Font.GothamBold
delayInput.TextColor3 = T.Text; delayInput.BorderSizePixel = 0
delayInput.ClearTextOnFocus = false
delayInput.Parent = statusPanel
addCorner(delayInput, 5); addStroke(delayInput, T.Border)

label{
    Size = UDim2.new(0, 10, 0, 22), Position = UDim2.new(1, -10, 0, 7),
    Text = "s", TextSize = 9, Font = Enum.Font.Gotham,
    TextColor3 = T.TextMuted, Parent = statusPanel,
}

-- ======== SEPARATOR 1 ========
local sep1 = Instance.new("Frame")
sep1.Size = UDim2.new(1, -20, 0, 1)
sep1.Position = UDim2.new(0, 10, 0, 40)
sep1.BackgroundColor3 = T.Border; sep1.BorderSizePixel = 0
sep1.Parent = statusPanel

-- ======== ROW 2: SHIELD STATUS ========
local shieldRing = Instance.new("Frame")
shieldRing.Size = UDim2.new(0, 14, 0, 14)
shieldRing.Position = UDim2.new(0, 10, 0, 48)
shieldRing.BackgroundColor3 = T.Red; shieldRing.BackgroundTransparency = 0.8
shieldRing.BorderSizePixel = 0; shieldRing.Parent = statusPanel; addCorner(shieldRing, 7)

local shieldDot = Instance.new("Frame")
shieldDot.Size = UDim2.new(0, 6, 0, 6)
shieldDot.Position = UDim2.new(0, 14, 0, 52)
shieldDot.BackgroundColor3 = T.Red; shieldDot.BorderSizePixel = 0
shieldDot.Parent = statusPanel; addCorner(shieldDot, 3)

local shieldStatusLabel = label{
    Size = UDim2.new(0, 160, 0, 14), Position = UDim2.new(0, 30, 0, 46),
    Text = "SHIELD: INACTIVE", TextSize = 11, Font = Enum.Font.GothamBold,
    TextColor3 = T.Red, TextXAlignment = Enum.TextXAlignment.Left,
    Parent = statusPanel,
}

local shieldStatsLabel = label{
    Size = UDim2.new(0, 140, 0, 12), Position = UDim2.new(0, 30, 0, 61),
    Text = "Fires: 0", TextSize = 9, Font = Enum.Font.Gotham,
    TextColor3 = T.TextSub, TextXAlignment = Enum.TextXAlignment.Left,
    Parent = statusPanel,
}

-- god mode badge
local godBadge = label{
    Size = UDim2.new(0, 68, 0, 18),
    Position = UDim2.new(1, -78, 0, 48),
    Text = "⛊ GOD MODE", TextSize = 8, Font = Enum.Font.GothamBold,
    TextColor3 = T.Cyan, Parent = statusPanel,
}
godBadge.BackgroundTransparency = 0.8
godBadge.BackgroundColor3 = T.Cyan
godBadge.Visible = false
addCorner(godBadge, 4)

-- ======== SEPARATOR 2 ========
local sep2 = Instance.new("Frame")
sep2.Size = UDim2.new(1, -20, 0, 1)
sep2.Position = UDim2.new(0, 10, 0, 80)
sep2.BackgroundColor3 = T.Border; sep2.BorderSizePixel = 0
sep2.Parent = statusPanel

-- ======== ROW 3: SHIELD SPEED SLIDER ========
label{
    Size = UDim2.new(0, 80, 0, 12), Position = UDim2.new(0, 10, 0, 86),
    Text = "SHIELD SPEED", TextSize = 9, Font = Enum.Font.GothamBold,
    TextColor3 = T.TextMuted, TextXAlignment = Enum.TextXAlignment.Left,
    Parent = statusPanel,
}

local sliderValueLabel = label{
    Size = UDim2.new(0, 40, 0, 12), Position = UDim2.new(1, -48, 0, 86),
    Text = string.format("%.2fs", Config.ShieldDefault), TextSize = 10,
    Font = Enum.Font.GothamBold, TextColor3 = T.Cyan,
    TextXAlignment = Enum.TextXAlignment.Right, Parent = statusPanel,
}

-- slider track background
local sliderTrack = Instance.new("Frame")
sliderTrack.Name = "SliderTrack"
sliderTrack.Size = UDim2.new(1, -20, 0, 6)
sliderTrack.Position = UDim2.new(0, 10, 0, 103)
sliderTrack.BackgroundColor3 = T.SurfaceLight
sliderTrack.BorderSizePixel = 0
sliderTrack.Parent = statusPanel
addCorner(sliderTrack, 3)

-- slider fill
local sliderFill = Instance.new("Frame")
sliderFill.Name = "Fill"
sliderFill.BackgroundColor3 = T.Cyan
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderTrack
addCorner(sliderFill, 3)

-- slider fill glow
local fillGlow = Instance.new("Frame")
fillGlow.BackgroundColor3 = T.Cyan; fillGlow.BackgroundTransparency = 0.7
fillGlow.BorderSizePixel = 0; fillGlow.Size = UDim2.new(1, 0, 1, 4)
fillGlow.Position = UDim2.new(0, 0, 0, -2)
fillGlow.Parent = sliderFill; addCorner(fillGlow, 4)

-- slider thumb
local sliderThumb = Instance.new("Frame")
sliderThumb.Name = "Thumb"
sliderThumb.Size = UDim2.new(0, 16, 0, 16)
sliderThumb.BackgroundColor3 = T.Cyan
sliderThumb.BorderSizePixel = 0
sliderThumb.ZIndex = 3
sliderThumb.Parent = sliderTrack
addCorner(sliderThumb, 8)
addStroke(sliderThumb, T.Bg, 2)

-- thumb inner dot
local thumbDot = Instance.new("Frame")
thumbDot.Size = UDim2.new(0, 4, 0, 4)
thumbDot.Position = UDim2.new(0.5, -2, 0.5, -2)
thumbDot.BackgroundColor3 = T.Bg; thumbDot.BorderSizePixel = 0
thumbDot.ZIndex = 4; thumbDot.Parent = sliderThumb
addCorner(thumbDot, 2)

-- invisible hitbox over the entire slider area for easier clicking
local sliderHitbox = Instance.new("TextButton")
sliderHitbox.Name = "SliderHitbox"
sliderHitbox.Size = UDim2.new(1, -12, 0, 26)
sliderHitbox.Position = UDim2.new(0, 6, 0, 93)
sliderHitbox.BackgroundTransparency = 1
sliderHitbox.Text = ""; sliderHitbox.AutoButtonColor = false
sliderHitbox.ZIndex = 5
sliderHitbox.Parent = statusPanel

---------------------------------------------------------------
-- SLIDER LOGIC
---------------------------------------------------------------
local function delayToAlpha(d)
    return math.clamp((d - Config.ShieldMin) / (Config.ShieldMax - Config.ShieldMin), 0, 1)
end

local function alphaToDelay(a)
    local raw = Config.ShieldMin + a * (Config.ShieldMax - Config.ShieldMin)
    return math.floor(raw * 100 + 0.5) / 100
end

local function updateSlider(alpha)
    alpha = math.clamp(alpha, 0, 1)
    State.shieldDelay = alphaToDelay(alpha)

    sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
    sliderThumb.Position = UDim2.new(alpha, -8, 0.5, -8)
    sliderValueLabel.Text = string.format("%.2fs", State.shieldDelay)

    -- color shift: cyan when fast, yellow when slow
    local col
    if alpha < 0.35 then
        col = T.Cyan
    elseif alpha < 0.7 then
        col = T.Yellow
    else
        col = T.Red
    end
    sliderFill.BackgroundColor3  = col
    fillGlow.BackgroundColor3    = col
    sliderThumb.BackgroundColor3 = col
    sliderValueLabel.TextColor3  = col
end

-- set initial position
updateSlider(delayToAlpha(Config.ShieldDefault))

-- slider interaction
sliderHitbox.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        State.sliderDrag = true
        local trackX = sliderTrack.AbsolutePosition.X
        local trackW = sliderTrack.AbsoluteSize.X
        local alpha  = math.clamp((input.Position.X - trackX) / trackW, 0, 1)
        updateSlider(alpha)
        tw(sliderThumb, {Size = UDim2.new(0, 20, 0, 20)}, 0.1)
    end
end)

sliderHitbox.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        State.sliderDrag = false
        tw(sliderThumb, {Size = UDim2.new(0, 16, 0, 16)}, 0.1)
    end
end)

UIS.InputChanged:Connect(function(input)
    if State.sliderDrag and
       (input.UserInputType == Enum.UserInputType.MouseMovement
       or input.UserInputType == Enum.UserInputType.Touch) then
        local trackX = sliderTrack.AbsolutePosition.X
        local trackW = sliderTrack.AbsoluteSize.X
        local alpha  = math.clamp((input.Position.X - trackX) / trackW, 0, 1)
        updateSlider(alpha)
    end
end)

UIS.InputEnded:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch) and State.sliderDrag then
        State.sliderDrag = false
        tw(sliderThumb, {Size = UDim2.new(0, 16, 0, 16)}, 0.1)
    end
end)

-- hover glow on track
sliderHitbox.MouseEnter:Connect(function()
    if not State.sliderDrag then
        tw(fillGlow, {BackgroundTransparency = 0.5}, 0.12)
    end
end)
sliderHitbox.MouseLeave:Connect(function()
    if not State.sliderDrag then
        tw(fillGlow, {BackgroundTransparency = 0.7}, 0.12)
    end
end)

-- ========== PLAYER LIST HEADER ==========
local plHeader = Instance.new("Frame")
plHeader.Size = UDim2.new(1, 0, 0, 26)
plHeader.Position = UDim2.new(0, 0, 0, 128)
plHeader.BackgroundTransparency = 1; plHeader.Parent = content

label{
    Size = UDim2.new(0.5, 0, 1, 0),
    Text = "PLAYERS IN SERVER", TextSize = 10, Font = Enum.Font.GothamBold,
    TextColor3 = T.TextMuted, TextXAlignment = Enum.TextXAlignment.Left,
    Parent = plHeader,
}

local plCountLabel = label{
    Size = UDim2.new(0.5, 0, 1, 0),
    Text = "0 players", TextSize = 10, Font = Enum.Font.Gotham,
    TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Right,
    Parent = plHeader,
}

-- ========== PLAYER LIST ==========
local playerList = Instance.new("ScrollingFrame")
playerList.Name = "PlayerList"
playerList.Size = UDim2.new(1, 0, 1, -230)
playerList.Position = UDim2.new(0, 0, 0, 156)
playerList.BackgroundColor3 = T.Surface; playerList.BorderSizePixel = 0
playerList.ScrollBarThickness = 3
playerList.ScrollBarImageColor3 = T.Accent
playerList.ScrollBarImageTransparency = 0.3
playerList.CanvasSize = UDim2.new(0, 0, 0, 0)
playerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerList.Parent = content
addCorner(playerList, 8); addPadding(playerList, 5, 5, 5, 5)

Instance.new("UIListLayout", playerList).Padding = UDim.new(0, 3)

-- ========== BOTTOM SECTION ==========
local bottom = Instance.new("Frame")
bottom.Size = UDim2.new(1, 0, 0, 66)
bottom.Position = UDim2.new(0, 0, 1, -66)
bottom.BackgroundTransparency = 1; bottom.Parent = content

-- kick button (left)
local kickBtn = Instance.new("TextButton")
kickBtn.Size = UDim2.new(0.485, 0, 0, 42)
kickBtn.Position = UDim2.new(0, 0, 0, 0)
kickBtn.BackgroundColor3 = T.Accent
kickBtn.Text = "▶  AUTO KICK"
kickBtn.TextSize = 12; kickBtn.Font = Enum.Font.GothamBold
kickBtn.TextColor3 = T.Text; kickBtn.BorderSizePixel = 0
kickBtn.AutoButtonColor = false
kickBtn.Parent = bottom; addCorner(kickBtn, 8)

local kickBtnColors = {normal = T.Accent, hover = T.AccentHover}
kickBtn.MouseEnter:Connect(function() tw(kickBtn, {BackgroundColor3 = kickBtnColors.hover}, 0.1) end)
kickBtn.MouseLeave:Connect(function() tw(kickBtn, {BackgroundColor3 = kickBtnColors.normal}, 0.1) end)

-- shield button (right)
local shieldBtn = Instance.new("TextButton")
shieldBtn.Size = UDim2.new(0.485, 0, 0, 42)
shieldBtn.Position = UDim2.new(0.515, 0, 0, 0)
shieldBtn.BackgroundColor3 = T.Green
shieldBtn.Text = "🛡  GOD MODE"
shieldBtn.TextSize = 12; shieldBtn.Font = Enum.Font.GothamBold
shieldBtn.TextColor3 = T.Text; shieldBtn.BorderSizePixel = 0
shieldBtn.AutoButtonColor = false
shieldBtn.Parent = bottom; addCorner(shieldBtn, 8)

local shieldBtnColors = {normal = T.Green, hover = T.GreenHover}
shieldBtn.MouseEnter:Connect(function() tw(shieldBtn, {BackgroundColor3 = shieldBtnColors.hover}, 0.1) end)
shieldBtn.MouseLeave:Connect(function() tw(shieldBtn, {BackgroundColor3 = shieldBtnColors.normal}, 0.1) end)

label{
    Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
    Text = "Press [RightShift] to toggle GUI", TextSize = 10,
    Font = Enum.Font.Gotham, TextColor3 = T.TextMuted,
    Parent = bottom,
}

---------------------------------------------------------------
-- PLAYER LIST ENTRIES
---------------------------------------------------------------
local function createEntry(player)
    if player == LocalPlayer then return end

    local entry = Instance.new("Frame")
    entry.Name = player.Name
    entry.Size = UDim2.new(1, 0, 0, 34)
    entry.BackgroundColor3 = T.SurfaceLight
    entry.BackgroundTransparency = 0.5
    entry.BorderSizePixel = 0
    entry.Parent = playerList
    addCorner(entry, 6)

    local av = Instance.new("ImageLabel")
    av.Size = UDim2.new(0, 24, 0, 24)
    av.Position = UDim2.new(0, 6, 0.5, -12)
    av.BackgroundColor3 = T.Surface; av.BorderSizePixel = 0
    av.Parent = entry; addCorner(av, 12)

    task.spawn(function()
        pcall(function()
            av.Image = Players:GetUserThumbnailAsync(
                player.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size48x48
            )
        end)
    end)

    label{
        Size = UDim2.new(0.45, -10, 1, 0), Position = UDim2.new(0, 36, 0, 0),
        Text = player.DisplayName, TextSize = 12, Font = Enum.Font.GothamBold,
        TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = entry,
    }

    label{
        Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.new(0.45, 0, 0, 0),
        Text = "@" .. player.Name, TextSize = 10, Font = Enum.Font.Gotham,
        TextColor3 = T.TextMuted, TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = entry,
    }

    local distBadge = label{
        Name = "Dist",
        Size = UDim2.new(0, 42, 0, 18), Position = UDim2.new(1, -48, 0.5, -9),
        Text = "—", TextSize = 9, Font = Enum.Font.GothamBold,
        TextColor3 = T.TextMuted, Parent = entry,
    }
    distBadge.BackgroundTransparency = 0.8
    distBadge.BackgroundColor3 = T.TextMuted
    addCorner(distBadge, 4)

    entry.MouseEnter:Connect(function() tw(entry, {BackgroundTransparency = 0.15}, 0.1) end)
    entry.MouseLeave:Connect(function() tw(entry, {BackgroundTransparency = 0.5},  0.1) end)

    return entry
end

local function updatePlayerCount()
    local c = #Players:GetPlayers() - 1
    plCountLabel.Text = c .. (c == 1 and " player" or " players")
end

local function refreshList()
    for _, ch in ipairs(playerList:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
    for _, p in ipairs(Players:GetPlayers()) do createEntry(p) end
    updatePlayerCount()
end

---------------------------------------------------------------
-- DISTANCE UPDATER
---------------------------------------------------------------
RunService.Heartbeat:Connect(function()
    if not gui.Parent then return end

    local myRoot
    pcall(function()
        myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    end)

    for _, entry in ipairs(playerList:GetChildren()) do
        if not entry:IsA("Frame") then continue end
        local badge = entry:FindFirstChild("Dist")
        if not badge then continue end

        local plr = Players:FindFirstChild(entry.Name)
        if plr and myRoot then
            local theirRoot
            pcall(function()
                theirRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            end)

            if theirRoot then
                local d = math.floor((myRoot.Position - theirRoot.Position).Magnitude)
                badge.Text = d .. "m"

                if d < 15 then
                    badge.TextColor3       = T.Green
                    badge.BackgroundColor3 = T.Green
                elseif d < 40 then
                    badge.TextColor3       = T.Yellow
                    badge.BackgroundColor3 = T.Yellow
                else
                    badge.TextColor3       = T.TextMuted
                    badge.BackgroundColor3 = T.TextMuted
                end
            else
                badge.Text      = "—"
                badge.TextColor3 = T.TextMuted
            end
        else
            badge.Text      = "—"
            badge.TextColor3 = T.TextMuted
        end
    end
end)

---------------------------------------------------------------
-- STATUS HELPERS
---------------------------------------------------------------
local function setKickStatus(active)
    local col = active and T.Green or T.Red
    kickDot.BackgroundColor3  = col
    kickRing.BackgroundColor3 = col
    kickStatusLabel.Text       = active and "KICK: ACTIVE" or "KICK: INACTIVE"
    kickStatusLabel.TextColor3 = col
end

local function setShieldStatus(active)
    local col = active and T.Cyan or T.Red
    shieldDot.BackgroundColor3  = col
    shieldRing.BackgroundColor3 = col
    shieldStatusLabel.Text       = active and "SHIELD: ACTIVE" or "SHIELD: INACTIVE"
    shieldStatusLabel.TextColor3 = col
    godBadge.Visible = active
end

local function updateKickStats()
    kickStatsLabel.Text = "Fires: " .. State.kicks .. "  •  Delay: " .. State.delay .. "s"
end

local function updateShieldStats()
    shieldStatsLabel.Text = "Fires: " .. State.shieldFires .. "  •  Speed: " .. State.shieldDelay .. "s"
end

---------------------------------------------------------------
-- PULSE ANIMATION HELPER
---------------------------------------------------------------
local function pulseLoop(ring, stateKey)
    task.spawn(function()
        while State[stateKey] do
            tw(ring, {BackgroundTransparency = 0.35}, 0.55)
            task.wait(0.55)
            if not State[stateKey] then break end
            tw(ring, {BackgroundTransparency = 0.85}, 0.55)
            task.wait(0.55)
        end
        ring.BackgroundTransparency = 0.8
    end)
end

---------------------------------------------------------------
-- AUTO-KICK ENGINE
---------------------------------------------------------------
local function startAutoKick()
    if State.kickActive then return end
    State.kickActive = true
    setKickStatus(true)

    kickBtn.Text = "■  STOP KICK"
    kickBtnColors.normal = T.Red
    kickBtnColors.hover  = T.RedHover
    kickBtn.BackgroundColor3 = T.Red

    notify("Auto Kick started", T.Green)
    pulseLoop(kickRing, "kickActive")

    task.spawn(function()
        while State.kickActive do
            local remote = Config.KickRemotePath()
            if remote then
                local ok = pcall(function() remote:FireServer() end)
                if ok then
                    State.kicks += 1
                    updateKickStats()
                end
            else
                kickStatusLabel.Text       = "KICK: NO REMOTE"
                kickStatusLabel.TextColor3 = T.Yellow
                task.wait(1.5)
                if State.kickActive then setKickStatus(true) end
            end
            task.wait(State.delay)
        end
    end)
end

local function stopAutoKick()
    if not State.kickActive then return end
    State.kickActive = false
    setKickStatus(false)

    kickBtn.Text = "▶  AUTO KICK"
    kickBtnColors.normal = T.Accent
    kickBtnColors.hover  = T.AccentHover
    kickBtn.BackgroundColor3 = T.Accent

    notify("Auto Kick stopped", T.Red)
end

---------------------------------------------------------------
-- SHIELD / GOD MODE ENGINE
---------------------------------------------------------------
local function startShield()
    if State.shieldActive then return end
    State.shieldActive = true
    setShieldStatus(true)

    shieldBtn.Text = "■  STOP SHIELD"
    shieldBtnColors.normal = T.Red
    shieldBtnColors.hover  = T.RedHover
    shieldBtn.BackgroundColor3 = T.Red

    notify("God Mode activated — Speed: " .. State.shieldDelay .. "s", T.Cyan)
    pulseLoop(shieldRing, "shieldActive")

    -- god mode badge pulse
    task.spawn(function()
        while State.shieldActive do
            tw(godBadge, {BackgroundTransparency = 0.55}, 0.6)
            task.wait(0.6)
            if not State.shieldActive then break end
            tw(godBadge, {BackgroundTransparency = 0.85}, 0.6)
            task.wait(0.6)
        end
    end)

    task.spawn(function()
        while State.shieldActive do
            local remote = Config.ShieldRemotePath()
            if remote then
                local ok = pcall(function()
                    remote:FireServer("Activate")
                end)
                if ok then
                    State.shieldFires += 1
                    updateShieldStats()
                end
            else
                shieldStatusLabel.Text       = "SHIELD: NO REMOTE"
                shieldStatusLabel.TextColor3 = T.Yellow
                task.wait(1.5)
                if State.shieldActive then setShieldStatus(true) end
            end
            task.wait(State.shieldDelay)
        end
    end)
end

local function stopShield()
    if not State.shieldActive then return end
    State.shieldActive = false
    setShieldStatus(false)

    shieldBtn.Text = "🛡  GOD MODE"
    shieldBtnColors.normal = T.Green
    shieldBtnColors.hover  = T.GreenHover
    shieldBtn.BackgroundColor3 = T.Green

    notify("God Mode deactivated", T.Yellow)
end

---------------------------------------------------------------
-- EVENT WIRING
---------------------------------------------------------------

kickBtn.MouseButton1Click:Connect(function()
    if State.kickActive then stopAutoKick() else startAutoKick() end
end)

shieldBtn.MouseButton1Click:Connect(function()
    if State.shieldActive then stopShield() else startShield() end
end)

delayInput.FocusLost:Connect(function()
    local v = tonumber(delayInput.Text)
    if v and v >= Config.MinDelay and v <= Config.MaxDelay then
        State.delay = v
        updateKickStats()
        notify("Kick delay → " .. v .. "s", T.Accent, 2)
    else
        delayInput.Text = tostring(State.delay)
        notify("Invalid delay (" .. Config.MinDelay .. " – " .. Config.MaxDelay .. ")", T.Yellow, 2.5)
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    stopAutoKick()
    stopShield()
    tw(window, {Size = UDim2.new(0, W, 0, 0), BackgroundTransparency = 1}, 0.28)
    task.delay(0.3, function() gui:Destroy() end)
end)

minimizeBtn.MouseButton1Click:Connect(function()
    State.minimized = not State.minimized
    if State.minimized then
        tw(window, {Size = UDim2.new(0, W, 0, 48)}, 0.22)
        minimizeBtn.Text = "+"
    else
        tw(window, {Size = UDim2.new(0, W, 0, H)}, 0.22)
        minimizeBtn.Text = "─"
    end
end)

-- window dragging
do
    local dragInput

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            State.dragging  = true
            State.dragStart = input.Position
            State.framePos  = window.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    State.dragging = false
                end
            end)
        end
    end)

    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if not State.sliderDrag and input == dragInput and State.dragging then
            local d = input.Position - State.dragStart
            window.Position = UDim2.new(
                State.framePos.X.Scale, State.framePos.X.Offset + d.X,
                State.framePos.Y.Scale, State.framePos.Y.Offset + d.Y
            )
        end
    end)
end

-- toggle GUI visibility
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Config.ToggleKey then
        State.visible = not State.visible
        gui.Enabled = State.visible
    end
end)

-- player join / leave
Players.PlayerAdded:Connect(function(p)
    task.wait(0.3)
    createEntry(p)
    updatePlayerCount()
    notify(p.DisplayName .. " joined", T.Green, 2.5)
end)

Players.PlayerRemoving:Connect(function(p)
    local e = playerList:FindFirstChild(p.Name)
    if e then e:Destroy() end
    updatePlayerCount()
    notify(p.DisplayName .. " left", T.Yellow, 2.5)
end)

---------------------------------------------------------------
-- INIT
---------------------------------------------------------------
refreshList()
updateKickStats()
updateShieldStats()
notify("Kick Master Pro v3.1 loaded!", T.Accent, 4)
