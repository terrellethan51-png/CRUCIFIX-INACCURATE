local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

local selectedInstance = nil
local targetOutline = nil
local isChoosingTarget = false
local isMinimized = false
local isAwaitingConfirmation = false

local function formatId(rawText)
	local numeric = rawText:gsub("%D", "")
	if numeric == "" then return "" end
	return "http://roblox.com" .. numeric
end

local function parseColor3(textInput, fallback)
	local r, g, b = textInput:match("(%d+),%s*(%d+),%s*(%d+)")
	if r and g and b then
		return Color3.fromRGB(math.clamp(tonumber(r), 0, 255), math.clamp(tonumber(g), 0, 255), math.clamp(tonumber(b), 0, 255))
	end
	return fallback or Color3.fromRGB(255, 255, 255)
end

local function getTargetPositionAndParts(instance, defaultPosition)
	local partsMap = {}
	local targetPart = nil
	local targetPosition = defaultPosition

	if instance then
		targetPart = instance:FindFirstChild("HumanoidRootPart") 
			or instance:FindFirstChild("Torso") 
			or instance:FindFirstChild("UpperTorso")
			or instance:FindFirstChildOfClass("BasePart")

		if targetPart then
			targetPosition = targetPart.Position
		elseif instance:IsA("Model") then
			targetPosition = instance:GetPivot().Position
		elseif instance:IsA("BasePart") then
			targetPosition = instance.Position
		end

		if instance:IsA("Model") then
			local humanoid = instance:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.WalkSpeed = 0 end
			for _, part in ipairs(instance:GetDescendants()) do
				if part:IsA("BasePart") then partsMap[part] = part.CFrame end
			end
		elseif instance:IsA("BasePart") then
			partsMap[instance] = instance.CFrame
		end
	end

	return targetPosition, partsMap
end

-- ============================================================================
-- 🎨 SECTION 1: INTERFACE LAYER GENERATION
-- ============================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CrucifixAdvancedAdminPanel"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 240, 0, 440)
mainFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
mainFrame.BorderSizePixel = 1
mainFrame.BorderColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -65, 0, 35)
titleLabel.Position = UDim2.new(0, 5, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "CRUCIFIX COMPILER"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 25, 0, 25)
minimizeBtn.Position = UDim2.new(1, -56, 0, 5)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
minimizeBtn.BorderSizePixel = 1
minimizeBtn.BorderColor3 = Color3.fromRGB(30, 30, 30)
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.TextSize = 14
minimizeBtn.Font = Enum.Font.SourceSansBold
minimizeBtn.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 25, 0, 25)
closeBtn.Position = UDim2.new(1, -28, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
closeBtn.BorderSizePixel = 1
closeBtn.BorderColor3 = Color3.fromRGB(30, 30, 30)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.Parent = mainFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -10, 1, -100)
scrollFrame.Position = UDim2.new(0, 5, 0, 40)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 6
scrollFrame.Parent = mainFrame

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, 8)
uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
uiListLayout.Parent = scrollFrame

uiListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y + 15)
end)

local currentOrder = 1
local function createCodedRow(labelText, defaultAsset, defaultTint)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -16, 0, 45)
	container.BackgroundTransparency = 1
	container.LayoutOrder = currentOrder
	container.Parent = scrollFrame
	currentOrder = currentOrder + 1

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.4, 0, 0, 15)
	label.BackgroundTransparency = 1
	label.Text = labelText:upper()
	label.TextColor3 = Color3.fromRGB(180, 180, 180)
	label.TextSize = 10
	label.Font = Enum.Font.SourceSansBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local assetInput = Instance.new("TextBox")
	assetInput.Size = UDim2.new(0.55, -4, 0, 24)
	assetInput.Position = UDim2.new(0, 0, 0, 18)
	assetInput.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
	assetInput.BorderSizePixel = 1
	assetInput.BorderColor3 = Color3.fromRGB(40, 40, 40)
	assetInput.Text = defaultAsset
	assetInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	assetInput.TextSize = 12
	assetInput.Font = Enum.Font.SourceSans
	assetInput.ClearTextOnFocus = false
	assetInput.Parent = container

	local tintInput = Instance.new("TextBox")
	tintInput.Size = UDim2.new(0.25, -4, 0, 24)
	tintInput.Position = UDim2.new(0.55, 0, 0, 18)
	tintInput.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
	tintInput.BorderSizePixel = 1
	tintInput.BorderColor3 = Color3.fromRGB(40, 40, 40)
	tintInput.Text = defaultTint or "255, 255, 255"
	tintInput.TextColor3 = Color3.fromRGB(200, 200, 200)
	tintInput.TextSize = 11
	tintInput.Font = Enum.Font.SourceSans
	tintInput.ClearTextOnFocus = false
	tintInput.Parent = container

	local sampleBtn = Instance.new("TextButton")
	sampleBtn.Size = UDim2.new(0.2, 0, 0, 24)
	sampleBtn.Position = UDim2.new(0.8, 0, 0, 18)
	sampleBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	sampleBtn.BorderSizePixel = 1
	sampleBtn.BorderColor3 = Color3.fromRGB(40, 40, 40)
	sampleBtn.Text = labelText:find("Sound") and "🔊 HEAR" or "👁️ VIEW"
	sampleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	sampleBtn.TextSize = 10
	sampleBtn.Font = Enum.Font.SourceSansBold
	sampleBtn.Parent = container

	return assetInput, tintInput, sampleBtn
end

local inputOuterRing, tintOuterRing, viewOuterBtn   = createCodedRow("Outer Ring Decal", "", "100, 200, 255")
local inputMidRing, tintMainCircle, viewMidBtn      = createCodedRow("Middle Ring Decal", "", "255, 255, 255")
local inputInnerRing, tintInnerRing, viewInnerBtn   = createCodedRow("Inner Ring Decal", "", "0, 150, 255")
local inputCenter, tintCenter, viewCenterBtn        = createCodedRow("Very Center Decal", "", "255, 255, 255")
local inputChain, tintChain, viewChainBtn           = createCodedRow("Chain Links Decal", "", "130, 200, 255")
local inputActivationSound, _, hearActivationBtn    = createCodedRow("Active Sound ID", "", "0,0,0")
local inputScreamSound, _, hearScreamBtn            = createCodedRow("Vocal Sound ID", "", "0,0,0")
local inputMeshId, _, _                             = createCodedRow("Crucifix Mesh ID", "", "0,0,0")

local activateBtn = Instance.new("TextButton")
activateBtn.Size = UDim2.new(1, -20, 0, 38)
activateBtn.Position = UDim2.new(0, 10, 1, -48)
activateBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 60)
activateBtn.BorderSizePixel = 1
activateBtn.BorderColor3 = Color3.fromRGB(30, 30, 30)
activateBtn.Text = "ACTIVATE SYSTEM"
activateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
activateBtn.TextSize = 14
activateBtn.Font = Enum.Font.SourceSansBold
activateBtn.Parent = mainFrame

local notificationBanner = Instance.new("TextLabel")
notificationBanner.Size = UDim2.new(0, 340, 0, 40)
notificationBanner.Position = UDim2.new(0.5, -170, 0, 15)
notificationBanner.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
notificationBanner.BorderSizePixel = 1
notificationBanner.BorderColor3 = Color3.fromRGB(200, 50, 50)
notificationBanner.Text = "TAP ONCE TO HIGHLIGHT TARGET"
notificationBanner.TextColor3 = Color3.fromRGB(255, 200, 200)
notificationBanner.Font = Enum.Font.SourceSansBold
notificationBanner.TextSize = 12
notificationBanner.Visible = false
notificationBanner.Parent = screenGui

-- ============================================================================
-- 📲 SECTION 2: MOBILE DRAG WRAPPERS
-- ============================================================================
local function setupMobileFriendlyDrag()
	local dragging, dragInput, dragStart, startPos
	mainFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true; dragStart = input.Position; startPos = mainFrame.Position
			input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	mainFrame.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end
setupMobileFriendlyDrag()
minimizeBtn.MouseButton1Click:Connect(function()
isMinimized = not isMinimized
if isMinimized then scrollFrame.Visible = false; mainFrame.Size = UDim2.new(0, 240, 0, 35); minimizeBtn.Text = "+"
else scrollFrame.Visible = true; mainFrame.Size = UDim2.new(0, 240, 0, 440); minimizeBtn.Text = "-" end
end)
closeBtn.MouseButton1Click:Connect(function() if targetOutline then targetOutline:Destroy() end screenGui:Destroy() end)
-- ============================================================================
-- ⚡ SECTION 3: PURE VISUAL CALCULATION MOVEMENT PIPELINE
-- ============================================================================
local function spawnCustomCrucifix(target, fallbackRaycastPos)
-- Fallback spatial dot generation if no valid world models were captured
local targetPosition, partsMap = getTargetPositionAndParts(target, fallbackRaycastPos)
if not targetPosition then return end
local currentActiveTargetPos = targetPosition
local ringContainer = Instance.new("Part")
ringContainer.Size = Vector3.new(1, 1, 1)
ringContainer.Position = targetPosition - Vector3.new(0, 3, 0)
ringContainer.Anchored = true
ringContainer.CanCollide = false
ringContainer.Transparency = 1
ringContainer.Parent = workspace
local function makeSigilRing(name, assetField, tintField)
local ring = Instance.new("Part")
ring.Size = Vector3.new(13, 0.4, 13)
ring.Anchored = true
ring.CanCollide = false
ring.Transparency = 0
ring.Color = parseColor3(tintField, Color3.fromRGB(255, 255, 255))
ring.Parent = ringContainer
local formattedUrl = formatId(assetField)
if formattedUrl ~= "" then
ring.Transparency = 1
local function mountDecalFace(faceId)
local decal = Instance.new("Decal")
decal.Texture = formattedUrl
decal.ImageColor3 = ring.Color
decal.Face = faceId
decal.Parent = ring
end
mountDecalFace(Enum.NormalId.Top)
mountDecalFace(Enum.NormalId.Bottom)
else
ring.Material = Enum.Material.Neon
ring.Transparency = 0.45
end
return ring
end
local plateCenter = makeSigilRing("Center", inputCenter, tintCenter)
local plateInner  = makeSigilRing("Inner", inputInnerRing, tintInnerRing)
local plateMid    = makeSigilRing("Middle", inputMidRing, tintMainCircle)
local plateOuter  = makeSigilRing("Outer", inputOuterRing, tintOuterRing)
local rawActId = formatId(inputActivationSound)
if rawActId ~= "" then
local sAct = Instance.new("Sound") sAct.SoundId = rawActId sAct.Volume = 3 sAct.Parent = ringContainer sAct:Play()
end
local rawScrId = formatId(inputScreamSound)
if rawScrId ~= "" then
local sScr = Instance.new("Sound") sScr.SoundId = rawScrId sScr.Volume = 3 sScr.Parent = ringContainer sScr:Play()
end
local function createChainLine()
local p = Instance.new("Part")
p.Size = Vector3.new(0.4, 0.4, 1)
p.Anchored = true; p.CanCollide = false; p.Transparency = 0.2
p.Color = parseColor3(tintChain, Color3.fromRGB(150, 200, 255))
p.Material = Enum.Material.Neon
p.Parent = workspace
return p
end
local structuralChains = {}
for i = 1, 6 do table.insert(structuralChains, createChainLine()) end
local rAngle, cAngle = 0, 0
local ritualLoop = RunService.RenderStepped:Connect(function(dt)
if not ringContainer.Parent then return end
rAngle = (rAngle + (40 * dt)) % 360
cAngle = (cAngle + (25 * dt)) % 360
plateCenter.CFrame = ringContainer.CFrame
local currentCenterPos = ringContainer.Position
plateInner.CFrame = CFrame.new(currentCenterPos) * CFrame.Angles(0, math.radians(-rAngle * 1.5), 0)
plateMid.CFrame   = CFrame.new(currentCenterPos) * CFrame.Angles(0, math.radians(rAngle * 0.8), 0)
plateOuter.CFrame = CFrame.new(currentCenterPos) * CFrame.Angles(0, math.radians(-rAngle * 0.4), 0)
for idx, chain in ipairs(structuralChains) do
local offsetDeg = ((idx - 1) * 60) + (cAngle * 1.2)
local rad = math.radians(offsetDeg)
local perimeterPos = (ringContainer.CFrame * CFrame.new(math.cos(rad) * 6.5, targetPosition.Y - currentActiveTargetPos.Y - 3, math.sin(rad) * 6.5)).Position
local dist = (perimeterPos - currentActiveTargetPos).Magnitude
chain.Size = Vector3.new(0.4, 0.4, dist)
chain.CFrame = CFrame.lookAt(perimeterPos, currentActiveTargetPos) * CFrame.new(0, 0, -dist / 2)
end
end)
-- Frame-by-frame mathematical animation driver (Pure Client Manipulation Matrix)
task.spawn(function()
task.wait(4.0) -- Phase 1: Hold
-- Phase 2: Ascension (Math vector interpolation lift)
local tElevate = 1.5
local elapsedE = 0
while elapsedE < tElevate do
local dt = RunService.Heartbeat:Wait()
elapsedE = elapsedE + dt
local alpha = math.sin((elapsedE / tElevate) * (math.pi / 2))
currentActiveTargetPos = targetPosition + Vector3.new(0, alpha * 5.5, 0)
for part, initialCF in pairs(partsMap) do
if part.Parent then part.CFrame = initialCF * CFrame.new(0, alpha * 5.5, 0) end
end
end
task.wait(0.5)
-- Phase 3: Sinking Drag Banishment Fade Matrix
local snapCFrames = {}
for part, _ in pairs(partsMap) do if part.Parent then snapCFrames[part] = part.CFrame end end
local baseElevatedPos = currentActiveTargetPos
local tSink = 2.0
local elapsedS = 0
while elapsedS < tSink do
local dt = RunService.Heartbeat:Wait()
elapsedS = elapsedS + dt
local progress = elapsedS / tSink
local alpha = progress ^ 2
currentActiveTargetPos = baseElevatedPos - Vector3.new(0, alpha * 22, 0)
for part, snapCF in pairs(snapCFrames) do
if part.Parent then
part.CFrame = snapCF * CFrame.new(0, -alpha * 22, 0)
part.Transparency = progress
end
end
end
-- Teardown
ritualLoop:Disconnect()
if target then target:Destroy() end
for _, chain in ipairs(structuralChains) do chain:Destroy() end
ringContainer:Destroy()
end)
end
-- ============================================================================
-- 🎨 SECTION 4: TWO-TAP STATE TRACKING INPUT BINDINGS
-- ============================================================================
local function clearStagedHighlight()
if targetOutline then targetOutline:Destroy() targetOutline = nil end
selectedInstance = nil; isAwaitingConfirmation = false
end
activateBtn.MouseButton1Click:Connect(function()
mainFrame.Visible = false; isChoosingTarget = true; clearStagedHighlight()
notificationBanner.Text = "TAP ONCE TO HIGHLIGHT TARGET"; notificationBanner.Visible = true
end)
UserInputService.InputBegan:Connect(function(input, processed)
if processed or not isChoosingTarget then return end
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
if not isAwaitingConfirmation then
local ray = workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
if player.Character then castParams.FilterDescendantsInstances = {player.Character, screenGui} end
local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, castParams)
-- Banish Anything Protocol: If you click completely empty space, it captures the ray vector coordinate end
local hitPoint = result and result.Position or (ray.Origin + ray.Direction * 40)
local hitPart = result and result.Instance or nil
local ancestorModel = hitPart and hitPart:FindFirstAncestorOfClass("Model") or nil
selectedInstance = (ancestorModel and ancestorModel ~= workspace) and ancestorModel or hitPart
-- Staging visual configuration check bounds
targetOutline = Instance.new("Highlight")
targetOutline.Name = "CrucifixStagingHighlight"
targetOutline.FillColor = Color3.fromRGB(0, 255, 255)
targetOutline.FillTransparency = 0.4
targetOutline.OutlineColor = Color3.fromRGB(255, 255, 255)
if selectedInstance then
targetOutline.Adornee = selectedInstance
targetOutline.Parent = selectedInstance
else
-- If empty air space clicked, create a local glowing client vector sphere dot to highlight position context
local airMarker = Instance.new("Part")
airMarker.Size = Vector3.new(2, 2, 2)
airMarker.Shape = Enum.PartType.Ball
airMarker.Color = Color3.fromRGB(0, 255, 255)
airMarker.Material = Enum.Material.Neon
airMarker.Transparency = 0.5
airMarker.Anchored = true
airMarker.CanCollide = false
airMarker.Position = hitPoint
airMarker.Parent = workspace
selectedInstance = airMarker
Debris:AddItem(airMarker, 4.5)
end
stagedPositionVector = hitPoint
isAwaitingConfirmation = true
notificationBanner.Text = "TAP ANYWHERE ON SCREEN TO BANISH"
else
isChoosingTarget = false; isAwaitingConfirmation = false; notificationBanner.Visible = false
local activeBanishmentTarget = selectedInstance
local fallbackVector = stagedPositionVector
if targetOutline then targetOutline:Destroy() targetOutline = nil end
selectedInstance = nil
-- If it was a mock air vector, clear marker object out right before launch
if activeBanishmentTarget and activeBanishmentTarget.Name == "Part" and activeBanishmentTarget.Parent == workspace then
activeBanishmentTarget:Destroy()
activeBanishmentTarget = nil
end
spawnCustomCrucifix(activeBanishmentTarget, fallbackVector)
mainFrame.Visible = true
end
end
end)
