name = "Dynamic Layouts"
-- borrowed from IA
folder_name = folder_name or "workshop-"
if not folder_name:find("workshop-") then
    name = "[LOCAL] - " .. name
end

description = [[A modding tool for empowering modders with setpiece making utilities.]]

author = "󰀈 The Uncomp Dev Team 󰀈"

version = "0"
-- VERSION SCHEME
-- first num is major release (e.g. "Under the weather", so, 2, UTW2 will be 3, and so on.) DO NOT BRING THIS NUMBER *DOWN* AGAIN PLEASE
-- second is new content (something like a new large addition)
-- third is minor (minor things like tweaks and some fixes)
-- fourth is hotfix (bug fixes, very tiny misc changes)

api_version = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
hamlet_compatible = false

forge_compatible = false

all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = {}

priority = -10
 
------------------------------
-- local functions to makes things prettier

local function Header(title)
    return {
        name = "",
        label = title,
        hover = "",
        options = { { description = "", data = false } },
        default = false
    }
end

local function SkipSpace()
    return {
        name = "",
        label = "",
        hover = "",
        options = { { description = "", data = false } },
        default = false
    }
end

local function BinaryConfig(name, label, hover, default)
    return {
        name = name,
        label = label,
        hover = hover,
        options = { { description = "Enabled", data = true, hover = "Enabled." },
            { description = "Disabled", data = false, hover = "Disabled." } },
        default = default
    }
end
------------------------------

configuration_options = {
}
