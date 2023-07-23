local require = GLOBAL.require
PrefabFiles =
{
    "dl_prefabs",
    "dl_biometable",
}

local SignGenerator = GLOBAL.require "signgenerator"
local UpvalueHacker = GLOBAL.require("tools/upvaluehacker")
local writeables = GLOBAL.require("writeables")

local kinds = UpvalueHacker.GetUpvalue(writeables.makescreen, "kinds")

if kinds == nil then
    return
end

TUNING.DL = {
    MODROOT = MODROOT,
}

local function itemtestfn(container, item, slot)
    return item.prefab == "log" or item.prefab == "boards"
end

local containers = GLOBAL.require("containers")

containers.params.dl_recorder = GLOBAL.deepcopy(containers.params.shadowchester)
containers.params.dl_recorder.itemtestfn = itemtestfn

kinds["dl_recorder"] = {
    prompt = GLOBAL.STRINGS.SIGNS.MENU.PROMPT,
    animbank = "ui_board_5x3",
    animbuild = "ui_board_5x3",
    menuoffset = GLOBAL.Vector3(6, -70, 0),

    cancelbtn = { text = GLOBAL.STRINGS.SIGNS.MENU.CANCEL, cb = nil, control = GLOBAL.CONTROL_CANCEL },
    middlebtn = {
        text = GLOBAL.STRINGS.SIGNS.MENU.RANDOM,
        cb = function(inst, doer, widget)
            widget:OverrideText(SignGenerator(inst, doer))
        end,
        control = GLOBAL.CONTROL_MENU_MISC_2
    },
    acceptbtn = { text = GLOBAL.STRINGS.SIGNS.MENU.ACCEPT, cb = nil, control = GLOBAL.CONTROL_ACCEPT },

    --defaulttext = SignGenerator,
}

kinds["dl_spawner"] = kinds["dl_recorder"]

require "map/terrain"

local _SetTile = GLOBAL.Map.SetTile
function GLOBAL.Map:SetTile(x, y, tile, data, ...)
    local original_tile = GLOBAL.TheWorld.Map:GetTile(x, y)
    if data ~= nil and data.reversible then
        table.insert(GLOBAL.TheWorld.dl_setpieces[data.group].tiles, { x = x, y = y, original_tile = original_tile })
    end

    _SetTile(self, x, y, tile, data, ...)
end

AddPlayerPostInit(function(inst)
    inst:AddComponent("reviveablecorpse")
end)

AddPrefabPostInit("world", function(inst)
    if not GLOBAL.TheWorld.ismastersim then return end

    inst:ListenForEvent("revertterraform", function(inst, group)
        for k, v in pairs(inst.dl_setpieces[group].tiles) do
            inst:DoTaskInTime(math.random(), function(inst)
                GLOBAL.TheWorld.Map:SetTile(v.x, v.y, v.original_tile)
                inst.dl_setpieces[group].tiles[k] = nil
            end)
        end

        for k, v in pairs(inst.dl_setpieces[group].prefabs) do
            inst:DoTaskInTime(math.random(), function(inst)
                GLOBAL.SpawnSaveRecord(v)
                inst.dl_setpieces[group].prefabs[k] = nil
            end)
        end

        for k, v in pairs(GLOBAL.Ents) do
            inst:DoTaskInTime(math.random(), function(inst)
                if v.group == group then
                    v:Remove()
                end
            end)
        end
    end)
end)
