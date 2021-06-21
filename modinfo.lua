name = "Assisted Geometry"
description = "With this you can build orderliness and structure"
author = "zkm2erjfdb, levorto"
version = "1.3"

forumthread = "/files/file/145-architectural-geometry/"

api_version = 6

-- Compatible with the base game & ROG
dont_starve_compatible = true
reign_of_giants_compatible = true

icon_atlas = "arcgeo.xml"
icon = "arcgeo.tex"

local alpha = {"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"}
local KEY_A = 97
local keyslist = {}
for i = 1,#alpha do keyslist[i] = {description = alpha[i],data = i + KEY_A - 1} end

configuration_options =
{
    {
        name = "togglekey",
        label = "Toggle Button",
        options = keyslist,
        default = 109,
    },    
}