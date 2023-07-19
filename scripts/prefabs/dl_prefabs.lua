require "prefabutil"
require "json"

local io = require("io")
local file_name = TUNING.DL.MODROOT .. "scripts/capture_output.json"

local function CheckValidEntities(inst, reset)
	for k, v in pairs(Ents) do
		if v.AnimState ~= nil and v:IsValid() and v:HasTag("DL_VALID") then
			v.AnimState:SetAddColour(0, 0, 0, 0)
		end
	end

	if reset then 
		return
	end

	inst.range = 0

    local itemsinside = inst.components.container:GetAllItems()

	for i, v in ipairs(itemsinside) do
		if v.prefab == "log" then
			inst.range = inst.range + v.components.stackable:StackSize()
		end
		if v.prefab == "boards" then
			inst.range = inst.range + (v.components.stackable:StackSize() * TILE_SCALE)
		end
		v:AddTag("NOCAPTURE")
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local ents = TheSim:FindEntities(x, y, z, inst.range, nil,
		{ "NOCAPTURE", "player", "bird", "NOCLICK", "CLASSIFIED", "FX", "INLIMBO", "smalloceancreature", "DECOR",
			"walkingplank" }) --gets all valid entities aroiund


	for k, v in pairs(ents) do
		if v.AnimState ~= nil then
			v.AnimState:SetAddColour(0, 1, 0, 0)
			v:AddTag("DL_VALID")
		end
	end
end

local function onopen(inst)
	if not inst:HasTag("burnt") then
		inst.AnimState:PlayAnimation("open")
		inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_open")
	end

	CheckValidEntities(inst)
end

local function onclose(inst)
	if not inst:HasTag("burnt") then
		inst.AnimState:PlayAnimation("close")
		inst.AnimState:PushAnimation("closed", false)
		inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_close")
	end

	CheckValidEntities(inst)
end

local function onhammered(inst, worker)
	inst:Remove()
end

local function onhit(inst, worker)
	inst:Remove()
end

local function onbuilt(inst)
	inst.AnimState:PlayAnimation("place")
	inst.AnimState:PushAnimation("closed", false)
	inst.SoundEmitter:PlaySound("dontstarve/common/chest_craft")
end

local function OnStopChanneling(inst)
	inst.channeler = nil
end

local function Capture(inst, channeler)
	local x, y, z = inst.Transform:GetWorldPosition()
	local itemsinside = inst.components.container:GetAllItems()
	local ents = TheSim:FindEntities(x, y, z, inst.range, nil,
		{ "NOCAPTURE", "player", "bird", "NOCLICK", "CLASSIFIED", "FX", "INLIMBO", "smalloceancreature", "DECOR" })
	local saved_ents = {}
	local num = tostring(math.random(1000))
	local text = (inst.components.writeable.text == nil and "returnedTable" .. num) or
		string.gsub(inst.components.writeable.text, " ", "_")
	local file = io.open(file_name, "r+")

	for i, v in ipairs(itemsinside) do
		if v.prefab == "log" then
			inst.range = inst.range + v.components.stackable:StackSize()
		end -- since each log is 1, 4 logs = 1 tile!
		if v.prefab == "boards" then
			inst.range = inst.range + (v.components.stackable:StackSize() * TILE_SCALE)
		end
		v:AddTag("NOCAPTURE")
	end

	for k, v in ipairs(ents) do
		local vx, vy, vz = v.Transform:GetWorldPosition()
		local px, py, pz = vx - x, vy - y, vz - z

		if saved_ents[text] == nil then
			saved_ents[text] = {}
		end

		local thedata = { relative_x = px, relative_y = py, relative_z = pz, v:GetSaveRecord() }
		if v.prefab == "dl_tileflag" then
			thedata.tile = TheWorld.Map:GetTileAtPoint(vx, vy, vz)
		end

		table.insert(saved_ents[text], thedata)
	end

	if file then
		local file_str = file:read("*a")
		local data
		local file_data = {}

		if file_str == "" then
			file_data[text] = saved_ents[text]
		else
			file_data = json.decode(file_str)
		end

		file:close()
		file_data[text] = saved_ents[text]

		local str = json.encode(file_data)

		file = io.open(file_name, "w")
		--while, yes, the IDE is telling me I need to add a nil check here, there really isn't a way for the file we *just* opened to be nil, consdering we checked for that previously.
		data = file:write(str)
		file:close()
		TheNet:Announce("Successfully captured!")
		CheckValidEntities(inst, true) --reset range
		inst:Remove()

		return data
	else
		TheNet:Announce("Failed to write: file invalid! Or something.")
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:AddTag("structure")
	inst:AddTag("chest")
	inst:AddTag("NOCAPTURE")

	inst.AnimState:SetBank("chest")
	inst.AnimState:SetBuild("treasure_chest")
	inst.AnimState:PlayAnimation("closed")

	inst:AddTag("_writeable")
	inst:AddTag("capturer")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddTag("_writeable")

	inst:AddComponent("inspectable")
	inst:AddComponent("writeable")
	inst:AddComponent("lootdropper")

	inst:AddComponent("container")
	inst.components.container:WidgetSetup("dl_recorder")
	inst.components.container.onopenfn = onopen
	inst.components.container.onclosefn = onclose
	inst.components.container.skipclosesnd = true
	inst.components.container.skipopensnd = true

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(2)
	inst.components.workable:SetOnFinishCallback(onhammered)
	inst.components.workable:SetOnWorkCallback(onhit)

	inst:ListenForEvent("onbuilt", onbuilt)

	inst:AddComponent("channelable")
	inst.components.channelable:SetChannelingFn(Capture, OnStopChanneling)
	inst.components.channelable.use_channel_longaction_noloop = true
	-- inst.components.channelable.skip_state_stopchanneling = true
	inst.components.channelable.skip_state_channeling = true

	inst:DoTaskInTime(0, function(inst)
		local x, y, z = inst.Transform:GetWorldPosition()
		local tile_x, tile_y, tile_z = TheWorld.Map:GetTileCenterPoint(x, 0, z)
		inst.Transform:SetPosition(tile_x, tile_y, tile_z)
	end)

	inst:ListenForEvent("itemlose", CheckValidEntities)
	inst:ListenForEvent("itemget", CheckValidEntities)
	inst:ListenForEvent("onremoved", function()
		for k, v in pairs(Ents) do
			if v.AnimState ~= nil and v:IsValid() and v:HasTag("DL_VALID") then
				v.AnimState:SetAddColour(0, 0, 0, 0)
			end
		end
	end)

	return inst
end

local function OnDropped(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	local tile_x, tile_y, tile_z = TheWorld.Map:GetTileCenterPoint(x, 0, z)
	if tile_x ~= nil and tile_y ~= nil and tile_z ~= nil then
		inst.Transform:SetPosition(tile_x, tile_y, tile_z)
	end
end

local function TileFlag(inst)
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("gridplacer")
	inst.AnimState:SetBuild("gridplacer")
	inst.AnimState:PlayAnimation("anim")
	inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)

	inst.AnimState:SetMultColour(math.random(5, 10) / 10, math.random(5, 10) / 10, 0, 1)

	inst:AddTag("DYNLAYOUT_FLAG")

	-- MakeInventoryPhysics(inst)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end
	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem:SetOnDroppedFn(OnDropped)

	inst:AddComponent("stackable")
	inst.components.stackable.maxsize = 60

	inst:DoTaskInTime(0, OnDropped)
	inst.OnEntityWake = OnDropped

	return inst
end

local function SpawnDynamicLayout(inst)
	if inst.components.writeable.text == "" or inst.components.writeable.text == nil then
		return
	end
	local rotx, rotz = 1, 1
	if math.random() > 0.5 then
		rotx = -1
	end
	if math.random() > 0.5 then
		rotz = -1
	end

	local file = io.open(file_name, "r+")
	local x, y, z = inst.Transform:GetWorldPosition()

	if file then
		local file_string = file:read("*a")
		file:close()
		local data = json.decode(file_string)

		if data[inst.components.writeable.text] == nil or type(data[inst.components.writeable.text]) ~= "table" then
			TheNet:Announce("Invalid data!")
			print(data[inst.components.writeable.text])
			return
		end

		for k, v in pairs(data[inst.components.writeable.text]) do
			if v.tile ~= nil then
				local tile_x, tile_z = TheWorld.Map:GetTileCoordsAtPoint(v.relative_x * rotx + x,
					v.relative_y * rotz + y,
					v.relative_z + z)
				TheWorld.Map:SetTile(tile_x, tile_z, v.tile)
			else
				local prefab = SpawnSaveRecord(v["1"])
				prefab.Transform:SetPosition(v.relative_x * rotx + x, v.relative_y + y, v.relative_z * rotz + z)
			end
		end
	end
end

local function spawnerfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:AddTag("structure")
	inst:AddTag("chest")
	inst:AddTag("NOCAPTURE")
	inst:AddTag("_writeable")

	inst.AnimState:SetBank("chest")
	inst.AnimState:SetBuild("treasure_chest")
	inst.AnimState:PlayAnimation("closed")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst:AddComponent("writeable")
	inst:AddComponent("lootdropper")

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(2)
	inst.components.workable:SetOnFinishCallback(onhammered)
	inst.components.workable:SetOnWorkCallback(onhit)

	inst:ListenForEvent("onbuilt", onbuilt)

	inst:AddComponent("channelable")
	inst.components.channelable:SetChannelingFn(SpawnDynamicLayout, OnStopChanneling)
	inst.components.channelable.use_channel_longaction_noloop = true
	inst.components.channelable.skip_state_channeling = true

	inst:DoTaskInTime(0, function(inst)
		local x, y, z = inst.Transform:GetWorldPosition()
		local tile_x, tile_y, tile_z = TheWorld.Map:GetTileCenterPoint(x, 0, z)
		inst.Transform:SetPosition(tile_x, tile_y, tile_z)

		if inst.layout ~= nil and type(inst.layout) == "string" or inst.components.writeable.text ~= nil or inst.components.writeable.text ~= "" then --this defines
			inst.components.writeable.text = inst.layout
			SpawnDynamicLayout(inst)
		end
	end)

	return inst
end

return Prefab("dl_recorder", fn), -- Version 1.0
	Prefab("dl_tileflag", TileFlag), Prefab("dl_spawner", spawnerfn)
