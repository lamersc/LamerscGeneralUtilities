--[[
General purpose mod for Trailmakers.
Copyright (C) 2023  lamersc (contact@lamersc.com)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>
]]

local character_set = "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890"
function random_id(length)
    local id = ""
    for i = 1, length do
        local random_index = math.random(#character_set)
        id = id .. string.sub(character_set, random_index, random_index)
    end
    return id
end

function typeof_number(number)
    if number % 1 == 0 then
        return "int"
    else
        return "float"
    end
end

function split_newline(string)
    local split_string = {}
    if string.find(string, "\n") ~= nil or string.find(string, [[\n]]) ~= nil then

        for token in string.gmatch(string.gsub(string, [[\n]], "\n"), "[^\n]+") do 
            table.insert(split_string, token)
        end
    else
        split_string = {string}
    end
    return split_string
end

function table.shallow_copy(t)
    local t2 = {}
    for k,v in pairs(t) do
      t2[k] = v
    end
    return t2
  end

function render_ui(player_id, definition, meta)
    if meta == nil then
        meta = {}
    end

    for i = 1, #definition do
        local object = definition[i]
        local name = object[1]
        local parameter = object[2]

        local object_id = nil
        if name == "label" then
            if type(parameter) == "table" then
                object_id = parameter[1]
                parameter = parameter[2]
            elseif type(parameter) == "function" then
                parameter = parameter(nil, {player_id, meta})
            end

            for _, token in ipairs(split_newline(parameter)) do
                tm.playerUI.AddUILabel(player_id, object_id, token or " ")
            end
        --------
        elseif string.sub(name, 1, 5) == "field" then
            local default_value = parameter[1]()
            local field_type = string.sub(name, 8, #name) -- skips the "::" in the object name
            if field_type == "int" or field_type == "float" then
                tm.playerUI.AddUIText(player_id, random_id(8), default_value,
                    function(data)
                        local value = tonumber(data.value)
                        if data.value == nil or data.value == "" or value == nil or (typeof_number(value) ~= field_type and field_type ~= "float") then
                            value = nil
                        end
                        return parameter[2](value, {player_id, meta})
                    end
                )
            elseif field_type == "vector3" then
                tm.playerUI.AddUIText(player_id, random_id(8), default_value,
                    function(data)
                        local vector = tm.vector3.Create()
                        local vector_components = {}
                        for component in data.value:gmatch("%S+") do table.insert(vector_components, component) end

                        for _, component in ipairs(vector_components) do 
                            local letter_identifier = string.sub(component, 1, 1)
                            if letter_identifier == "x" or letter_identifier == "y" or letter_identifier == "z" then
                                local coordinate = tonumber(string.match(component, ":(.*)"))
                                if coordinate == nil then
                                    return parameter[2](nil, {player_id, meta})
                                else
                                    vector[letter_identifier] = tonumber(string.match(component, ":(.*)"))
                                end
                            end
                        end
                        return parameter[2](vector, {player_id, meta})
                    end
                )
            elseif field_type == "text" then
                tm.playerUI.AddUIText(player_id, random_id(8), default_value,
                    function(data)
                        return parameter[2](data.value, {player_id, meta})
                    end
                )
            else
                -- left for future cases
            end
        --------
        elseif string.sub(name, 1, 6) == "button" then
            local button_name = string.sub(name, 9, #name) -- skips the "::" in the object name
            if type(parameter) == "table" then
                object_id = parameter[1]
                parameter = parameter[2]
            end
            tm.playerUI.AddUIButton(player_id, object_id or random_id(8), button_name,
                function(data)
                    return parameter(data, {player_id, meta})
                end
            )
        --------
        elseif string.sub(name, 1, 6) == "toggle" then
            local button_name = string.sub(name, 9, #name) -- skips the "::" in the object name
            tm.playerUI.AddUIButton(player_id, object_id or random_id(8), button_name:gsub("%$", tostring(parameter[1](nil, {player_id, meta}))),
                function(data)
                    local toggle_value = parameter[2](data, {player_id, meta})
                    tm.playerUI.SetUIValue(player_id, data.id, button_name:gsub("%$", tostring(toggle_value)))
                end
            )
        --------
        elseif string.sub(name, 1, 4) == "page" then
            local button_name = string.sub(name, 7, #name) -- skips the "::" in the object name

            local temporary_definition = table.shallow_copy(parameter[2])
            tm.playerUI.AddUIButton(player_id, random_id(8), button_name,
                function(data)
                    table.insert(temporary_definition, 1, 
                        {"button::<- Back",
                            function()
                                tm.playerUI.ClearUI(player_id)
                                render_ui(player_id, table.remove(parameter[1](), 1), meta)
                            end
                        }
                    )
                    table.insert(parameter[1](), 1, definition)
                    tm.playerUI.ClearUI(player_id)
                    render_ui(player_id, temporary_definition, meta)
                end
            )
        --------
        elseif string.sub(name, 1, 8) == "switcher" then
            local button_name = string.sub(name, 11, #name)
            local button_onclick = parameter[1]
            local parameter = parameter[2]

            tm.playerUI.AddUIButton(player_id, random_id(8), button_name,
                function(data)
                    button_onclick(data)
                    for i = 1, #parameter do
                        local object = parameter[i]
                        local conditional = object[1]()
                        local inner_definition = object[2]
                        if conditional == true then
                            tm.playerUI.ClearUI(player_id)
                            render_ui(player_id, definition, meta)
                        end
                    end
                end
            )
            for i = 1, #parameter do
                local object = parameter[i]
                local conditional = object[1]()
                local inner_definition = object[2]
                if conditional == true then
                    render_ui(player_id, inner_definition, meta)
                end
            end
        --------
        elseif name == "dynamic_pages" then
            -- local page_cache = parameter[1]
            local page_objects = parameter[2]()
            local page_meta = page_objects[1]
            local page_definition = table.shallow_copy(page_objects[2])

            for i = 1, #page_meta do
                local button_definition = {
                    {"button::" .. page_meta[i]["name"], 
                        function()
                            table.insert(page_definition, 1, 
                                {"button::<- Back",
                                    function()
                                        tm.playerUI.ClearUI(player_id)
                                        render_ui(player_id, table.remove(parameter[1](), 1), meta)
                                    end
                                }
                            )
                            table.insert(parameter[1](), 1, definition)
                            tm.playerUI.ClearUI(player_id)
                            render_ui(player_id, page_definition, page_meta[i])
                        end
                    }
                }
                render_ui(player_id, button_definition, meta)
            end
        --------
        else
            tm.os.Log("Undefined definition element: " .. name)
        end
    end
end




function build_template(player_id, message)
    local message = string.gsub(message, "%$([%a%_]+)",
        function(template_element)
            if template_element == "p" then
                return tm.players.GetPlayerName(player_id)
            elseif template_element == "pid" then
                return tostring(player_id)
            elseif template_element == "mname" then
                return tm.physics.GetMapName()
            elseif template_element == "pamt" then
                return tostring(#tm.players.CurrentPlayers())
            elseif template_element == "stime" then
                return tostring(math.floor(tm.os.GetTime()))
            else
                return "[INVALID TEMPLATE]"
            end
        end
    )
    return message
end
-- default variable values
local storage = {
    page_cache = {},
    complexity_limit = 700,
    time_scale = math.floor(tm.physics.GetTimeScale()),
    gravity = {
        at_load = {
            strength = tm.physics.GetGravity(),
        },
        type = "normal",
        strength = tm.physics.GetGravity(),
    },
    allow_player_jetpacks = true,
    welcome_message = "Welcome, $p!",
    loaded_maps = {},
}

local ui_definition = {
    {"label", "Preview build 4 (July 10th, 2023)\nMenu is still work-in-progress."},
    {"page::Game Behaviour", 
        {
            || storage["page_cache"],
            {
                {"label", {"complexity_label", "Complexity Limit"}},
                {"field::int", 
                    {
                        || storage["complexity_limit"],
                        function(value, misc)
                            if value == nil then
                                tm.playerUI.SetUIValue(misc[1], "complexity_label", "Error: expected int")
                            else
                                storage["complexity_limit"] = value
                                tm.physics.SetBuildComplexity(value)
                                tm.playerUI.SetUIValue(misc[1], "complexity_label", "Complexity Limit √ updated")
                            end
                        end
                    }
                },
                {"label", {"timescale_label", "Time Scale"}},
                {"field::float",
                    {
                        || storage["time_scale"],
                        function(value, misc)
                            if value == nil then
                                tm.playerUI.SetUIValue(misc[1], "timescale_label", "Error: expected float")
                            else
                                storage["time_scale"] = value
                                tm.physics.SetTimeScale(value)
                                tm.playerUI.SetUIValue(misc[1], "timescale_label", "Time Scale √ updated")
                            end
                        end
                    }
                },
                {"label", "Advanced:"},
                {"page::Gravity", 
                    {
                        || storage["page_cache"],
                        {
                            {"switcher::Gravity Type",
                                {
                                    function()
                                        if storage["gravity"]["type"] == "normal" then
                                            storage["gravity"]["type"] = "point"
                                        else
                                            storage["gravity"]["type"] = "normal"
                                        end
                                        local default_gravity = storage["gravity"]["at_load"]["strength"]
                                        storage["gravity"]["strength"] = default_gravity
                                        tm.physics.SetGravity(default_gravity)
                                    end,
                                    {
                                        {
                                            || storage["gravity"]["type"] == "normal",
                                            {
                                                {"label", "∟ Normal"},
                                                {"label", {"gravity_strength_label", "Gravity Strength"}},
                                                {"field::vector3",
                                                    {
                                                        || storage["gravity"]["strength"],
                                                        function(value, misc)
                                                            if value == nil then
                                                                tm.playerUI.SetUIValue(misc[1], "gravity_strength_label", "Error: invalid vector")
                                                            else
                                                                tm.physics.SetGravity(value)
                                                                storage["gravity"]["strength"] = value
                                                                tm.playerUI.SetUIValue(misc[1], "gravity_strength_label", "Gravity Strength √ updated")
                                                            end
                                                        end
                                                    }
                                                },
                                            },
                                        },
                                        {
                                            || storage["gravity"]["type"] == "point",
                                            {
                                                {"label", "∟ Point"},
                                                {"label", "Planned for preview 5!"},
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    },
    {"page::Server Management",
        {
            || storage["page_cache"],
            {
                {"label", "Management Options:"},
                {"page::Configuration",
                    {
                        || storage["page_cache"],
                        {
                            {"label", {"welcome_message_label", "Welcome Message"}},
                            {"field::text",
                                {
                                    || storage["welcome_message"],
                                    function(value, misc)
                                        if #value >= 64 then
                                            tm.playerUI.SetUIValue(misc[1], "welcome_message_label", "Error: length must be < 64 chars")
                                        else
                                            storage["welcome_message"] = value
                                            tm.playerUI.SetUIValue(misc[1], "welcome_message_label", "Welcome Message √ updated")
                                        end
                                    end
                                },
                            },
                            {"page::~ Message Templates ~",
                                {
                                    || storage["page_cache"],
                                    {
                                        {"label",
                                            "Available Templates:\n" ..
                                            "$p = The players name\n" ..
                                            "$pid = The players ID\n" ..
                                            "$pamt = Number of players online\n" ..
                                            "$mname = Current map name\n" ..
                                            "$stime = Session time in seconds"
                                        },
                                    },
                                },
                            },
                            {"page::Preview Message",
                                {
                                    || storage["page_cache"],
                                    {
                                        {"label", || build_template(0, storage["welcome_message"])}
                                    },
                                },
                            },
                            {"label", "General Options:"},
                            {"toggle::Allow Player Jetpacks: $",
                                {
                                    || storage["allow_player_jetpacks"],
                                    function(_, misc)
                                        storage["allow_player_jetpacks"] = not storage["allow_player_jetpacks"]
                                        local jetpacks_allowed = storage["allow_player_jetpacks"]

                                        for i, player in ipairs(tm.players.CurrentPlayers()) do
                                            tm.players.SetJetpackEnabled(player.playerId, jetpacks_allowed)
                                        end
                                        return jetpacks_allowed
                                    end
                                }
                            },
                        },
                    },
                },
                {"page::Player Permissions",
                    {
                        || storage["page_cache"],
                        {
                            {"label", "Individual player permissions\ncoming in preview 5."},
                        },
                    },
                },
            },
        },
    },
    {"page::Map Tools",
        {
            || storage["page_cache"],
            {
                {"label", "Select an option below:"},
                {"page::Load Map(s)",
                    {
                        || storage["page_cache"],
                        {
                            {"label", "Select a map below:"},
                            {"page::-- How To Add Maps --",
                                {
                                    || storage["page_cache"],
                                    {
                                        {"label",
                                            "∟Your dynamic data path:\n"                                      ..
                                            "C:\\Program Files (x86)\\Steam\n\\userdata\\{{your steam ID}}\n" ..
                                            "\\585420\\remote\\Mods\\2998765957\n\\data_dynamic\\\n"          ..
                                            "=============================\n"                                 ..
                                            "∟To add a new map, go to the\n"                                  ..
                                            "above path and place your\n"                                     ..
                                            "(.json) map file into the\n"                                     ..
                                            "\"/data_dynamic\" directory.\n"
                                        },
                                        {"page::Continued ->",
                                            {
                                                || storage["page_cache"],
                                                {
                                                    {"label",
                                                        "∟At this point, you should see a\n"          ..
                                                        "\"maps.list\" file in\n\"/data_dynamic\".\n" ..
                                                        "∟Open this file, and change the\n"           ..
                                                        "`__example.json` to the name of\n"           ..
                                                        "the file you added earlier.\n"               ..
                                                        "∟Open Trailmakers, run this mod,\n"          ..
                                                        "and your new map should appear!"
                                                    },
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                            {"dynamic_pages",
                                {
                                    --[[
                                        While pulling map data each time the page loads
                                        may be inefficient, it allows the user to make 
                                        changes to the map and load them without refresshing
                                        the mod; in the future, I may turn this into a
                                        "map developer" toggle.
                                    ]]
                                    || storage["page_cache"],
                                    function()
                                        local button_attributes = {}

                                        local saved_maps = tm.os.ReadAllText_Dynamic("maps.list")
                                        if saved_maps == "" then
                                            tm.os.WriteAllText_Dynamic("maps.list", "__example.json")
                                        end

                                        if saved_maps != "__example.json" then
                                            for file_name in string.gmatch(saved_maps, "[^\r\n]+") do
                                                local map_content = tm.os.ReadAllText_Dynamic(file_name)
                                                local status, result = pcall(
                                                    function()
                                                        return json.parse(map_content)
                                                    end
                                                )
                                                if status == true and result["ObjectList"] ~= nil then
                                                    table.insert(button_attributes, {
                                                        name = result["Name"],
                                                        author = nil,
                                                        format = "trailmappers",
                                                        data = result,
                                                    })
                                                else
                                                    table.insert(button_attributes, {
                                                        name = "work-in-progress",
                                                        author = nil,
                                                        format = "lamf", -- Lamersc's Advanced Map Format
                                                        data = nil,
                                                    })
                                                end
                                            end
                                        end

                                        return {
                                            button_attributes,
                                            {
                                                {"label", 
                                                    function(value, misc)
                                                        local map_data = misc[2]
                                                        return (
                                                            map_data["name"] ..
                                                            "\n∟ Author: " .. (map_data["author"] or "unknown") ..
                                                            "\n∟ Format: " .. map_data["format"]
                                                        )
                                                    end
                                                },
                                                {"toggle::$",
                                                    {
                                                        function(_, misc)
                                                            local map_data = misc[2]
                                                            if storage["loaded_maps"][map_data["name"]] == nil then
                                                                return "Load Map"
                                                            else
                                                                return "Unload Map"
                                                            end
                                                        end,
                                                        function(_, misc)
                                                            local map_data = misc[2]
                                                            local loaded_maps = storage["loaded_maps"]

                                                            -- load map
                                                            if loaded_maps[map_data["name"]] == nil then
                                                                if map_data["format"] == "trailmappers" then
                                                                    loaded_maps[map_data["name"]] = {}
                                                                    local current_map = loaded_maps[map_data["name"]]
                                                                    current_map["game_objects"] = {}

                                                                    for _, object in ipairs(map_data["data"]["ObjectList"]) do
                                                                        local desired_position = object["P"]
                                                                        local game_object = tm.physics.SpawnObject(
                                                                            -- 300 is a "special" number I needed to get the maps above ground. This was horrible trial and error.
                                                                            tm.vector3.Create(desired_position["x"], desired_position["y"] + 300, desired_position["z"]), -- position
                                                                            object["N"]
                                                                        )
                        
                                                                        local object_information = object["I"]
                                                                        if object_information["CanCollide"] == false then
                                                                            game_object.SetIsTrigger(true)
                                                                        end
                                                                        if object_information["IsStatic"] == true then
                                                                            game_object.SetIsStatic(true)
                                                                        end
                                                                        if object_information["IsVisible"] == false then
                                                                            game_object.SetIsVisible(false)
                                                                        end
                        
                                                                        local game_object_transform = game_object.GetTransform()
                        
                                                                        local desired_rotation = object["R"]
                                                                        if desired_rotation["x"] ~= 0 or desired_rotation["y"] ~= 0 or desired_rotation["z"] ~= 0 then
                                                                            game_object_transform.SetRotation(desired_rotation["x"], desired_rotation["y"], desired_rotation["z"])
                                                                        end
                        
                                                                        local desired_scale = object["S"]
                                                                        if desired_scale["x"] ~= 0 or desired_scale["y"] ~= 0 or desired_scale["z"] ~= 0 then
                                                                            game_object_transform.SetScale(desired_scale["x"], desired_scale["y"], desired_scale["z"])
                                                                        end
                                                                        table.insert(current_map["game_objects"], game_object)
                                                                    end

                                                                    local spawnpoint_information = map_data["data"]["SpawnpointInfo"]
                                                                    if spawnpoint_information ~= nil then
                                                                        for _, player in ipairs(tm.players.CurrentPlayers()) do
                                                                            local player_transform = tm.players.GetPlayerTransform(player.playerId)
                                                                            player_transform.SetPosition(
                                                                                spawnpoint_information["P"]["x"],
                                                                                spawnpoint_information["P"]["y"] + 300,
                                                                                spawnpoint_information["P"]["z"]
                                                                            )
                                                                            player_transform.SetRotation(
                                                                                spawnpoint_information["R"]["x"],
                                                                                spawnpoint_information["R"]["y"],
                                                                                spawnpoint_information["R"]["z"]
                                                                            )
                                                                        end
                                                                    end
                                                                    return "Unload Map"
                                                                else
                                                                    -- work-in-progress
                                                                end
                                                            else -- unload map
                                                                for _, game_object in ipairs(loaded_maps[map_data["name"]]["game_objects"]) do
                                                                    game_object.Despawn()
                                                                end
                                                                loaded_maps[map_data["name"]] = nil
                                                                return "Load Map"
                                                            end
                                                        end
                                                    }
                                                },
                                            },
                                        }
                                    end
                                },
                            },
                        },
                    },
                },
                {"page::Create New Map",
                    {
                        || storage["page_cache"],
                        {
                            {"label", "Coming in preview 5."}
                        },
                    },
                },
            },
        },
    },
    {"page::Credits / Licensing",
        {
            || storage["page_cache"],
            {
                {"label",
                    "* Developed by lamersc\n"           ..
                    "∟ https://lamersc.com\n"            ..
                    "* Licensed under the:\n"            ..
                    "∟GNU General Public License V3\n"   ..
                    "∟ https://www.gnu.org/licenses\n"   ..
                    "* Find me in Trailmakers Discord\n" ..
                    "∟ Mainly the #modding channel.\n"   ..
                    "∟ https://discord.gg/trailmakers\n" ..
                    "Leave a review on steam!"
                },
            },
        },
    },
}

render_ui(0, ui_definition)

tm.players.OnPlayerJoined.add(
    function(data)
        local player_id = data.playerId
        if storage["welcome_message"] ~= "" and player_id ~= 0 then
            local welcome_definition = {
                {"label", build_template(player_id, storage["welcome_message"])},
            }
            render_ui(player_id, welcome_definition)
        end
    end
)