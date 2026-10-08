-- Connected Discord-GitHub
-- CREDITS: Discord account-> divyansh_0p25_ | Roblox Account-> Divyansh_Op25


local Cache = {
	Pipelines = {}, -- stores data for pipeline to be used later
	Config = {}, -- stores the config for the pipeline
	isDebugAllowed = false,
}

local function Debug(msg: string)
	local RunService = game:GetService("RunService")
	if not Cache.isDebugAllowed and not RunService:IsStudio() then return end
	if not msg then warn("Missing argument msg!") return end

	print(msg)
end

local function SetupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"
	
	local money = Instance.new("IntValue", leaderstats)
	money.Name = "Money"
	money.Value = 0
end

local function AddPlayerMoney(player: Player, newValue: number)
	local leaderstats = player:WaitForChild("leaderstats")
	local money = leaderstats:WaitForChild("Money")
	
	money.Value = newValue
end

local function FetchPipelines() -- fetch the models and config it.
	
	local CollectionService = game:GetService("CollectionService")
	local pipelinesModel = CollectionService:GetTagged("ProductionPipeline")
	
	if not pipelinesModel then return end
	if #pipelinesModel < 1 then return end
	
	for i, model: Model in pairs(pipelinesModel) do
		if not model:IsA('Model') then continue end
		
		local producer = model:GetAttribute("Producer"):Get()
		local packager = model:GetAttribute("Packager"):Get()
		local convertor = model:GetAttribute("Convertor"):Get()
		
		if  
			(not producer) or
			(not packager) or 
			(not convertor)
		then
			warn("missing attributes for pipeline, ")	
			
			Debug("Producer: ", producer and "Found" or "Not Found")	
			Debug("Packager: ", packager and "Found" or "Not Found")	
			Debug("Convertor: ", convertor and "Found" or "Not Found")
		continue end
	
		local owner = model:GetAttribute("Owner") or "None"
		
		Cache.Pipelines[i] = {
			Producer = producer,
			Packager = packager,
			Convertor = convertor,
			Owner = owner,
			MetaData = Cache.Config
		}
		
		local producerUIMain = producer:WaitForChild("InteractionUI"):WaitForChild("Main")
		local packagerUIMain = packager:WaitForChild("InteractionUI"):WaitForChild("Main")
		local convertorUIMain = convertor:WaitForChild("InteractionUI"):WaitForChild("Main")
		
		local producerProgressBar = producerUIMain:FindFirstChild("Bar")
		local packagerProgressBar = packagerUIMain:FindFirstChild("Bar")
		local convertorProgressBar = convertorUIMain:FindFirstChild("Bar")
	
		producerUIMain.Visible = false
		packagerUIMain.Visible = false
		convertorUIMain.Visible = false
		
		local producerClicker: ClickDetector = producer:FindFirstChildOfClass("ClickDetector")
		local packagerClicker = packager:FindFirstChildOfClass("ClickDetector")
		local convertorClicker = convertor:FindFirstChildOfClass("ClickDetector")
		
		local progressBarGoal = {Size = UDim2.new(1,0,1,0)}
		
		local product = nil
		local productTemplate = Instance.new("Part")
		productTemplate.Size = Vector3.one
		productTemplate.Anchored = true
		productTemplate.CanCollide = false
		productTemplate.Color = Color3.fromRGB(40, 82, 199)
		productTemplate.Material = Enum.Material.Neon
		
		local moneyGenerated = 0
		local productLocation = "Producer"
		
		local function transportProduct(at: Vector3, locationName: "Producer"|"Packager"|"Convertor")
			if not at then return end
			if not product then return end
			local dist = (product.Position - at).Magnitude
			local transportingTime = dist/Cache.Pipelines[i].MetaData.TransportingSpeed
			local tweenInfo = TweenInfo.new(transportingTime, Enum.EasingStyle.Linear)
			local tween = game:GetService("TweenService"):Create(product, tweenInfo, {Position = at})
			productLocation = "Transporting"
			tween:Play()
			tween.Completed:Wait()
			productLocation = locationName
			
			if productLocation == "Convertor" then
				moneyGenerated += Cache.Pipelines[i].MetaData.MoneyPerProduct
				convertorUIMain:FindFirstChildOfClass("TextLabel").Text = `${moneyGenerated}`
				product.Position = producer.Position
				if not convertorUIMain.Visible then
					convertorUIMain.Visible = true
				end
				
				task.wait()
				productLocation = "Producer"
			end
		end
		
		producerClicker.MouseClick:Connect(function(player: Player)
			if not Cache.Pipelines[i].Owner or player.UserId ~= Cache.Pipelines[i].Owner then return end
			
			if producer:GetAttribute("InProgress") then return end
			if productLocation ~= "Producer" then return end

			producer:SetAttribute("InProgress", true)
				
			if not product then
				product = productTemplate:Clone()
			end
			product.Position = producer.Position
			product.Parent = workspace
			local producingTime = Cache.Pipelines[i].MetaData.ProducingTime			
			producerUIMain.Visible = true
			
			producerProgressBar.Size = UDim2.new(0,0,1,0) -- reset progress bar
			local tween = game:GetService("TweenService"):Create(producerProgressBar, TweenInfo.new(producingTime, Enum.EasingStyle.Linear), progressBarGoal)
			tween:Play()
			tween.Completed:Wait()
			producer:SetAttribute("InProgress", false)
			producerUIMain.Visible = false
			transportProduct(packager.Position, "Packager")
		end)
		
		packagerClicker.MouseClick:Connect(function(player: Player)
			if not owner or player.UserId ~= Cache.Pipelines[i].Owner then return end

			if packager:GetAttribute("InProgress") or not product then return end
			if productLocation ~= "Packager" then return end
			packager:SetAttribute("InProgress", true)
			packagerUIMain.Visible = true

			local packingTime = Cache.Pipelines[i].MetaData.PackingTime

			packagerProgressBar.Size = UDim2.new(0,0,1,0) -- reset progress bar
			local tween = game:GetService("TweenService"):Create(packagerProgressBar, TweenInfo.new(packingTime, Enum.EasingStyle.Linear), progressBarGoal)
			tween:Play()
			tween.Completed:Wait()
			packager:SetAttribute("InProgress", false)
			packagerUIMain.Visible = false
			transportProduct(convertor.Position, "Convertor")
		end)
		
		convertorClicker.MouseClick:Connect(function(player: Player)
			if not Cache.Pipelines[i].Owner or player.UserId ~= Cache.Pipelines[i].Owner then return end
			
			AddPlayerMoney(player, moneyGenerated)
			moneyGenerated = 0
			convertorUIMain.Visible = false
		end)
	end
end

local function AssignPipeline(player: Player) -- Assign pipeline to the player
	task.spawn(SetupLeaderstats, player)
	for i, data in ipairs(Cache.Pipelines) do
		if data.Owner ~= "None" and type(data.Owner) ~= "number" then continue end
		
		Cache.Pipelines[i].Owner = player.UserId
		player:SetAttribute("IsPipelineAssigned", true) -- to check if a player is assigned to pipeline or not
		player:SetAttribute("PipelineIndex", i) -- to get the pipeline player got assigned
		
		print(player.Name, " has been assigned to pipeline ", i)
	end
end

local function Init() -- Fetch instances, modules, etc before scripts run.
	Cache.Config = require(script.Config)	
end

local function Start() -- run the scripts functions after init.
	FetchPipelines()
	
	local players = game:GetService("Players")
	players.PlayerAdded:Connect(AssignPipeline) -- When player join...
	
	for _, player in pairs(players:GetPlayers()) do -- if a player got missed due to unexpected reason
		if player:GetAttribute("IsPipelineAssigned") then continue end -- Filter players who already gets pipeline assigned
		
		task.spawn(AssignPipeline, player)
	end
end

Init()
Start()
