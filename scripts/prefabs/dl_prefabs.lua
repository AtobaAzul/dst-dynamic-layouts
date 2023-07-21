require "prefabutil"
require "json"                 --required for the json sheneniganery.

local io = require("io")       --required for the file manipulation things
local output_file = TUNING.DL.MODROOT ..
	"scripts/capture_output.json" --the file wheere captured prefags will be recorded to.

local NO_CAPTURE_TAGS =        --all the tags that shouldn't be captured
{
	"NOCAPTURE",               --this includes the capturer itself
	"player",                  --players
	"bird",                    --hecking birds man
	"NOCLICK",                 --stuff you can't click
	"CLASSIFIED",              --stuff you can't see
	"FX",                      --FX, usually temporary stuff
	"INLIMBO",                 --stuff like items inside containers. so they don't get registered twice. Among other things.
	"smalloceancreature",      --hecking fishes man.
	"DECOR",
}

--this function checks for valid entitites, highlights them green and returns them.
local function CheckAndGetValidEntities(inst, reset)
	for k, v in pairs(Ents) do --iterates over all entitites to clear the highlighting on existing things.
		if v.AnimState ~= nil and v:IsValid() and v:HasTag("DL_VALID") then
			v.AnimState:SetAddColour(0, 0, 0, 0)
		end
	end

	if reset == true then --"itemget" event pushes the second param as some table. Need to do explicit true check
		return         --reset param is for resetting the highlighting only.
	end

	inst.range = 0

	local itemsinside = inst.components.container:GetAllItems() --get all items inside

	for i, v in ipairs(itemsinside) do                       --iterate over all of them...
		if v.prefab == "log" then                            --if it's a log, increase range by 1 of each in the stack.
			inst.range = inst.range + v.components.stackable:StackSize()
		end
		if v.prefab == "boards" then --if it's a log, increase it by 4.
			inst.range = inst.range + (v.components.stackable:StackSize() * TILE_SCALE)
		end
		v:AddTag("NOCAPTURE") --add the "NOCAPTURE" tag just to be safe.
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local ents = TheSim:FindEntities(x, y, z, inst.range, nil, NO_CAPTURE_TAGS) --find all entities around

	for k, v in pairs(ents) do
		if v.AnimState ~= nil and v ~= inst then --if they're valid
			v.AnimState:SetAddColour(0, 1, 0, 0) --highlight them green!
			v:AddTag("DL_VALID")           --and add this tag, for use in the first for loop above.
		end
	end

	return ents --and return the entities so we can use this function to shorten some code in the Capture function below
end


--some main cosmetic functions, but also includes checking valid entities
local function onopen(inst)
	if not inst:HasTag("burnt") then
		inst.AnimState:PlayAnimation("open")
		inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_open")
	end

	CheckAndGetValidEntities(inst)
end

local function onclose(inst)
	if not inst:HasTag("burnt") then
		inst.AnimState:PlayAnimation("close")
		inst.AnimState:PushAnimation("closed", false)
		inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_close")
	end

	CheckAndGetValidEntities(inst)
end

--remove itself if it gets hammered.
local function onhammered(inst, worker)
	inst:Remove()
end

local function onhit(inst, worker)
	inst:Remove()
end

--I'm pretty sure this goes unused.
local function onbuilt(inst)
	inst.AnimState:PlayAnimation("place")
	inst.AnimState:PushAnimation("closed", false)
	inst.SoundEmitter:PlaySound("dontstarve/common/chest_craft")
end

local function OnStopChanneling(inst)
	inst.channeler = nil
end

--this function is the main function for the dl_recorder.
--it captures all prefabs, and handles all the file writing and json magic.
local function Capture(inst, channeler)
	local x, y, z = inst.Transform:GetWorldPosition()
	local ents = CheckAndGetValidEntities(inst)
	local saved_ents = {}
	local num = tostring(math.random(1000))
	local text = (inst.components.writeable.text == nil and "returnedTable" .. num) or
		string.gsub(inst.components.writeable.text, " ", "_")
	local file = io.open(output_file, "r+")

	if saved_ents[text] == nil then
		saved_ents[text] = {}
	end

	-- some parameters for customization
	saved_ents[text].has_tiles = false        --automatically set, you may overwrite. Limits rotation to multiples of 90
	saved_ents[text].spawn_in_water = false   --controls whether the setpiece can spawn prefabs/tiles on water.
	saved_ents[text].only_spawn_in_water = false --controls wheter the setpiece can ONLY spawn in water.
	saved_ents[text].smooth_rorate = false    --if false,  rotateable and with no tiles, setpieces rotate on multiples of 45. if true, rotation is between 0-360
	saved_ents[text].no_rotation = false      --if true, disables rotation entirely.
	saved_ents[text].use_angle_away_from_spawn = false

	for k, v in ipairs(ents) do
		if v ~= inst then
			local vx, vy, vz = v.Transform:GetWorldPosition()
			local px, py, pz = vx - x, vy - y, vz - z --this gets the relative coodinates from the recorder.



			local thedata = { relative_x = px, relative_y = py, relative_z = pz, v:GetSaveRecord(), options = v.layout }
			--this is the data stored for the entity. GetSaveRecord gets all sort of data related to the entity, from deciduoustrees's colour to heatrock heat.

			if v.prefab == "dl_tileflag" then              --if the prefab is a tileflag, some extra data gets added
				thedata.tile = TheWorld.Map:GetTileAtPoint(vx, vy, vz) --such as the tile
				saved_ents[text].has_tiles = true          --setting the "has_tiles" parameter to true, so it can only spawn in right angles.
				saved_ents[text].spawn_in_water = true     --and setting this to true as well.
			end

			table.insert(saved_ents[text], thedata) --insert the prefab data into the main data table.
		end
	end

	--I would explain this to you if I remembered what it did.
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

		file = io.open(output_file, "w")
		--while, yes, the IDE is telling me I need to add a nil check here, there really isn't a way for the file we *just* opened to be nil, consdering we checked for that previously.
		data = file:write(str)
		file:close()
		TheNet:Announce("Successfully captured!")
		CheckAndGetValidEntities(inst, true) --reset range
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

	inst:ListenForEvent("itemlose", CheckAndGetValidEntities)
	inst:ListenForEvent("itemget", CheckAndGetValidEntities)
	inst:ListenForEvent("onremoved", CheckAndGetValidEntities)

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

local function SpawnDynamicLayout(inst, angle_override)
	if type(angle_override) == "number" then
		print("angle_override", angle_override)
		print(math.deg(angle_override))
	end
	if inst.layout ~= nil then
		local layout = weighted_random_choice(inst.layout)
		print("layout", inst.layout)
		if layout ~= "End" then
			inst.components.writeable.text = layout
		else
			inst:Remove()
			return
		end
	end

	if inst.components.writeable.text == "" or inst.components.writeable.text == nil then
		return
	end

	local file = io.open(output_file, "r+")
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

		local has_tiles = data[inst.components.writeable.text].has_tiles
		local spawn_in_water = data[inst.components.writeable.text].spawn_in_water
		local only_spawn_in_water = data[inst.components.writeable.text].only_spawn_in_water
		local smooth_rorate = data[inst.components.writeable.text].smooth_rotate
		local no_rotation = data[inst.components.writeable.text].no_rotation
		local angles, angle
		local use_angle_away_from_spawn = data[inst.components.writeable.text].use_angle_away_from_spawn
		if has_tiles then
			angles = { 0, 90, 180, 270, 360 }
		else
			angles = { 0, 45, 90, 135, 180, 215, 270, 315, 360 }
		end

		if no_rotation then
			angle = 0
		elseif smooth_rorate then
			angle = math.rad(math.random(360))
		else
			angle = math.rad(angles[math.random(#angles)])
		end

		if inst.angle_away ~= nil then
			angle = inst.angle_away
		end

		angle = type(angle_override) == "number" and angle_override or angle

		print(angle, inst.angle_away)
		for k, v in pairs(data[inst.components.writeable.text]) do
			if type(v) == "table" and v.relative_x ~= nil then
				local px = math.cos(angle) * (v.relative_x) - math.sin(angle) * (v.relative_z) +
					x --huge thanks to KorenWaffles for helping with math. because MAN I suck at it.
				local pz = math.sin(angle) * (v.relative_x) + math.cos(angle) * (v.relative_z) + z

				local nearbyents = TheSim:FindEntities(px, v.relative_y + y, pz, 3, nil,
					{ "noreplaceremove", "CLASSIFIED", "INLIMBO", "irreplaceable", "player", "playerghost",
						"companion", "abigail" })
				for k, v in pairs(nearbyents) do
					v:Remove()
				end


				if v.tile ~= nil then
					local tile_x, tile_z = TheWorld.Map:GetTileCoordsAtPoint(px, v.relative_y + y, pz)
					if not spawn_in_water and TheWorld.Map:IsPassableAtPoint(px, v.relative_y + y, pz) or spawn_in_water then
						TheWorld.Map:SetTile(tile_x, tile_z, v.tile)
					end
				else
					if not spawn_in_water and TheWorld.Map:IsPassableAtPoint(px, v.relative_y + y, pz) or spawn_in_water or only_spawn_in_water and TheWorld.Map:IsOceanAtPoint(px, v.relative_y + y, pz) then
						local prefab = SpawnSaveRecord(v["1"])

						if prefab.prefab == "dl_spawner" and use_angle_away_from_spawn then
							print("math.rad", math.rad(prefab:GetAngleToPoint(x, 0, z) + 180))
							print("prefab.angleaway", prefab.angle_away)
						end

						prefab.Transform:SetPosition(px, v.relative_y + y, pz)
						prefab:AddTag("noreplaceremove")
						if prefab.prefab == "dl_spawner" then
							print("options", v.options)
							prefab.layout = v.options

							prefab:DoTaskInTime(2.5, function(_inst)
								SpawnDynamicLayout(_inst, math.atan2(x - px, pz - z) + math.rad(180))
							end)
						end
					end
				end
			end
		end
		inst:DoTaskInTime(0, inst.Remove)
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
		inst.Transform:SetPosition(tile_x, 0, tile_z)
	end)

	return inst
end

return Prefab("dl_recorder", fn), Prefab("dl_tileflag", TileFlag), Prefab("dl_spawner", spawnerfn) -- Version 1.0
