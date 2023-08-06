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

local function RevertTerraform(inst, group)
    if group == nil or group ~= nil and GLOBAL.TheWorld.dl_setpieces[group] == nil then
        return
    end

    for k, v in pairs(GLOBAL.TheWorld.dl_setpieces[group].tiles) do
        GLOBAL.TheWorld.Map:SetTile(v.x, v.y, v.original_tile)
        if k == #GLOBAL.TheWorld.dl_setpieces[group].tiles then
            GLOBAL.TheWorld:PushEvent("finishedterraform")
        end
    end

    GLOBAL.TheWorld.dl_setpieces[group].tiles = {}

    for k, v in pairs(GLOBAL.TheWorld.dl_setpieces[group].prefabs) do
        if v ~= nil and v.prefab ~= nil then
            GLOBAL.SpawnSaveRecord(v)
        end
    end

    GLOBAL.TheWorld.dl_setpieces[group].prefabs = {}
    local num = 0
    for k, v in pairs(GLOBAL.Ents) do
        if v.group == group then
            num = num + 1
            v:Remove()
        end
    end
end

AddPrefabPostInit("world", function(inst)
    if not GLOBAL.TheWorld.ismastersim then return end
    if GLOBAL.TheWorld.dl_setpieces == nil then
        GLOBAL.TheWorld.dl_setpieces = {}
    end

    GLOBAL.TheWorld:ListenForEvent("revertterraform", RevertTerraform)

    local _OnSave = GLOBAL.TheWorld.OnSave
    local _OnLoad = GLOBAL.TheWorld.OnLoad

    GLOBAL.TheWorld.OnSave = function(inst, data)
        if data ~= nil then
            data.dl_setpieces = inst.dl_setpieces
        end
        if _OnSave ~= nil then
            return _OnSave(inst, data)
        end
        return data
    end

    GLOBAL.TheWorld.OnLoad = function(inst, data)
        if data ~= nil then
            inst.dl_setpieces = data.dl_setpieces
            --inst.dl_tasks = data.dl_tasks
        end
        if _OnLoad ~= nil then
            return _OnLoad(inst, data)
        end
        return data
    end
end)
