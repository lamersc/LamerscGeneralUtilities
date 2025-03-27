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
tm.os.Log("_")
local print = tm.os.Log
local get_time = tm.os.GetTime
local tm_spawn_object = tm.physics.SpawnObject
local clear_ui = tm.playerUI.ClearUI
local new_button = tm.playerUI.AddUIButton
local new_label = tm.playerUI.AddUILabel
local new_input = tm.playerUI.AddUIText
local change_ui = tm.playerUI.SetUIValue
local new_vector3 = tm.vector3.Create
local add_vector3 = tm.vector3.op_Addition
local subtract_vector3 = tm.vector3.op_Subtraction
local multiply_vector3 = tm.vector3.op_Multiply
local divide_vector3 = tm.vector3.op_Division
local trailmakers_prefabs = tm.physics.SpawnableNames()

local character_set = "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890"
function random_id(length)
  local id = ""
  for i = 1, length do
    local random_index = math.random(#character_set)
    id = id .. string.sub(character_set, random_index, random_index)
  end
  return id
end
function table_contains(table, value)
  for _, element in ipairs(table) do
      if element == value then
          return true
      end
  end
  return false
end
function table_shallowcopy(t)
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end
function split_newline(target_string)
  local split_string = {}
  if string.find(target_string, "\n") ~= nil or string.find(target_string, [[\n]]) ~= nil then
    for token in string.gmatch(string.gsub(target_string, [[\n]], "\n"), "[^\n]+") do 
      table.insert(split_string, token)
    end
  else
    split_string = {target_string}
  end
  return split_string
end
function number_type(number)
  if number % 1 == 0 then
      return "integer"
  else
      return "float"
  end
end
function multiline_string(text)
  local last_space = 1
  for i = 1, #text do
    if text:sub(i, i) == " " then
      last_space = i
    end
    if i % 31 == 0 then
      text = text:sub(1, last_space) .. "\n" .. text:sub(last_space + 1)
    end
  end
  return text
end


-- user interface framework for Trailmakers
function render_ui(definition, player_id)
  local meta_data = {
    _ = {
      player_id = player_id
    }
  }
  if definition.meta ~= nil then
    for key, value in pairs(definition.meta) do
      -- `_` is used to represent internal renderer data
      if key == "_" then
        for key2, value2 in pairs(value) do
          meta_data["_"][key2] = value2
        end
      else
        meta_data[key] = value
      end
    end
  end
  for i = 1, #definition do
    local element = definition[i]
    local name = element[1]
    local parameters = table_shallowcopy(element[2]) -- removes the risk of accidently modifying the table
    
    -- set player permissions
    if parameters.access == nil then
      parameters.access = { 0 }
    end

    -- check for dynamic elements
    if type(parameters.text) == "function" and name ~= "page-carousel" then
      parameters.text = parameters.text(meta_data)
    end
    if table_contains(parameters.access, player_id) == true then
      if name == "meta" then
        for key, value in pairs(parameters.data) do
          meta_data[key] = value
        end
      elseif name == "event" then
        local event_type = parameters.type
        if event_type == "load" or event_type == "draw" then
          local new_meta = parameters.callback(meta_data) or {}
          for key, value in pairs(new_meta) do
            meta_data[key] = value
          end
        else
          
        end
      elseif name == "label" then
        for _, string in ipairs(split_newline(parameters.text)) do
          new_label(player_id, parameters.id or random_id(8), string)
        end
      elseif name == "button" then
        local callback = parameters.callback
        new_button(
          player_id,
          parameters.id or random_id(8),
          parameters.text,
          function(data)
            local new_meta = callback(data, meta_data) or {}
            for key, value in pairs(new_meta) do
              meta_data[key] = value
            end
          end
        )
      elseif name == "input" then
        local input_type = parameters.type
        local field_title = nil
        local default_input = parameters.text or ""
        local colon_character = default_input:find(":")
        if colon_character ~= nil then
          field_title = default_input:sub(1, colon_character) .. " "
        end
        local callback = parameters.callback
        if input_type == "text" then
          new_input(
            player_id,
            parameters.id or random_id(8),
            default_input,
            function(data)
              if field_title ~= nil then
                local value = data.value:sub(colon_character + 2, -1)
                local i = 1
                while value:sub(i, 1) == " " do
                  i = i + 1
                end
                value = value:sub(i, -1)
                change_ui(player_id, data.id, field_title .. value)
                data.value = value
              end
              callback(data, meta_data)
            end
          )
        elseif input_type == "number" then
          local default_number = tonumber(parameters.text:match("%-?%d+%.?%d*"))
          if number_type(default_number) == "integer" then
            default_number = default_number .. ".0"
          end
          new_input(
            player_id,
            parameters.id or random_id(8),
            (field_title or "") .. default_number .. "  (←←←←|→→→→)",
            function(data)
              local value = data.value
              local number = tonumber(value:match("%-?%d+%.?%d*"))
              local slider_values = value:match("%((.-)%)")

              if number == nil then
                number = 0
              end
              if slider_values ~= nil then
                local _, _, left_arrow, right_arrow = slider_values:find("(.-)|(.-)")
                local arrows = {}
                for arrow in slider_values:gmatch("([^|]+)") do
                  table.insert(arrows, arrow)
                end
                
                if #arrows == 2 then
                  local left_length = #arrows[1]
                  local right_length = #arrows[2]
                  if right_length > 4 or 4 > right_length then
                    number = number + 1
                  elseif left_length > 4 or 4 > left_length then
                    number = number - 1
                  end
                end
              end
              
              local virtual_number = tostring(number)
              if number_type(number) == "integer" then
                virtual_number = virtual_number .. ".0"
              end
              if field_title ~= nil then
                change_ui(player_id, data.id, (field_title or "") .. virtual_number .. "  (←←←←|→→→→)")
              else

              end
              callback(
                {
                  playerId = player_id,
                  id = data.id,
                  value = number
                },
                meta_data
              )
            end
          )
        elseif input_type == "vector3" then
          new_input(
            player_id,
            parameters.id or random_id(8),
            parameters.text or "",
            function(data)
              local vector = new_vector3()
              if field_title ~= nil then
                data.value = data.value:sub(colon_character + 2, -1)
              end
              local i = 0
              for component in data.value:gmatch("%S+") do
                local axis = component:sub(1, 1)
                if axis == "x" or axis == "y" or axis == "z" then
                  local position = tonumber(
                    component:match(":(.*)")
                  )
                  if position ~= nil then
                    vector[axis] = position
                    i = i + 1
                  end
                end
              end
              if i ~= 3 then -- fix incorrect vector display
                change_ui(player_id, data.id, (field_title or "") .. vector.ToString())
              end
              -- have to redefine the data returned to allow vector to be passed through
              callback(
                {
                  playerId = data.playerId,
                  id = data.id,
                  value = vector
                },
                meta_data
              )
            end
          )
        else
          error("invalid input type provided.")
        end
      elseif name == "search" then
        local config = parameters.configuration
        local query_results = {}
        for _, value in ipairs(config.searchables) do
          if value:lower():find(config.query) then
            table.insert(query_results, value)
          end
        end
        local page = parameters.page or 1
        local callback = parameters.callback
        local results_ui = {}
        local results_found = {}
        for i = 1, 5 do
          local id = random_id(8)
          local result = query_results[i]
          if result == nil then
            new_button(
              player_id,
              id,
              "-",
              function(data)
                callback(
                  {
                    type = "interact",
                    data = {i, results_found[i]}
                  }
                )
              end
            )
          else
            new_button(
              player_id,
              id,
              result:sub(1, 27),
              function(data)
                callback(
                  {
                    type = "interact",
                    data = {i, results_found[i]}
                  }
                )
              end
            )
            table.insert(results_found, result)
          end
          table.insert(results_ui, id)
        end
        callback({
          type = "update",
          data = results_found
        })
        local results_found_id = random_id(8)
        new_label(player_id, results_found_id, "∟ " .. #query_results .. " results found                   ")
        table.insert(results_ui, results_found_id)
  
        local paginator_id = random_id(8)
        new_input(
          player_id,
          paginator_id,
          "←←←←←←(  01  )→→→→→→",
          function(data)
            results_found = {}
            local arrow_state = data.value
            local left_arrow = arrow_state:match("(.*)%(")
            if left_arrow == nil then left_arrow = 6 else left_arrow = #left_arrow end
            local right_arrow = arrow_state:match("%)(.*)")
            if right_arrow == nil then right_arrow = 6 else right_arrow = #right_arrow end
  
            if right_arrow > 6 or 6 > right_arrow then
              page = page + 1
            end
            if left_arrow > 6 or 6 > left_arrow then
              page = page - 1
            end
            if 0 >= page then
              page = 1
            end
            for i = 1, 5 do
              local result = query_results[(page - 1) * 5 + i]
              if result == nil then
                change_ui(player_id, results_ui[i], "-")
              else
                change_ui(player_id, results_ui[i], result:sub(1, 27))
                table.insert(results_found, result)
              end
            end
            local page_text = tostring(page)
            if 10 > page then
              page_text = "0" .. page
            end
            change_ui(player_id, data.id, "←←←←←←(  " .. page_text .. "  )→→→→→→")
            callback(
              {
                type = "update",
                data = results_found
              }
            )
          end
        )
        local search_bar_id = random_id(8)
        new_input(
          player_id,
          search_bar_id,
          "Search: " .. config.query,
          function(data)
            results_found = {}
            config.query = data.value:sub(9, -1)
            local value = data.value:sub(9, -1):lower()
            query_results = {}
            if value == "" then
              query_results = table_shallowcopy(config.searchables)
            else
              for _, ivalue in ipairs(config.searchables) do
                if ivalue:lower():find(value) then
                  table.insert(query_results, ivalue)
                end
              end
            end
  
            for i = 1, 5 do
              local result = query_results[i]
              if result == nil then
                change_ui(player_id, results_ui[i], "-")
              else
                change_ui(player_id, results_ui[i], result:sub(1, 27))
                table.insert(results_found, result)
              end
            end
            page = 1
            change_ui(player_id, results_found_id, "∟ " .. #query_results .. " results found                   ")
            change_ui(player_id, paginator_id, "←←←←←←(  01  )→→→→→→")
            change_ui(player_id, search_bar_id, "Search: " .. config.query)
            callback(
              {
                type = "update",
                data = results_found
              }
            )
          end
        )
      elseif name == "page" then
        -- first, store a copy of the current page being rendered
        local definition_copy = nil
        if type(parameters.definition) == "function" then
          definition_copy = table_shallowcopy(parameters.definition(meta_data) or {})
        else
          definition_copy = table_shallowcopy(parameters.definition or {})
        end
        definition_copy.meta = meta_data
        local callback = parameters.callback

        local player_id = player_id
        local ui_call = nil
        if parameters.type == nil then
          ui_call = new_button
        elseif parameters.type == "expanded" then
          ui_call = new_input
        else
          error("Invalid page type provided")
        end
        local previous_definition = parameters.previous or table_shallowcopy(definition) -- protects original definition
        ui_call(
          player_id,
          parameters.id or random_id(8),
          parameters.text,
          function(data)
            clear_ui(player_id)
            for i, element in ipairs(previous_definition) do
              if element[1] == "event" then
                if element[2].type == "load" then
                  table.remove(previous_definition, i)
                  break
                end
              end
            end
            table.insert(
              definition_copy,
              1,
              {"button",
                {
                  access = { player_id },
                  text = "← Back",
                  callback = function(data, meta_data)
                    clear_ui(player_id)
                    for i, element in ipairs(definition_copy) do
                      if element[1] == "event" then
                        if element[2].type == "unload" then
                          element[2].callback()
                        end
                      end
                    end
                    if parameters.preserve_meta == true then
                      local previous_meta = previous_definition.meta
                      for key, value in pairs(meta_data) do
                        if key ~= "_" then
                          previous_meta[key] = value
                        end
                      end
                    end
                    render_ui(previous_definition, player_id)
                  end
                }
              }
            )
            if callback ~= nil then
              local new_meta = callback(data, meta_data) or {}
              for key, value in pairs(new_meta) do
                definition_copy.meta[key] = value
              end
            end
            definition_copy.meta["_"].previous_definition = previous_definition
            definition_copy.meta["_"].definition = definition_copy
            render_ui(definition_copy, player_id)
          end
        )
      elseif name == "page-carousel" then
        local page_array = parameters.callback(meta_data)
        local page = 1
        local maximum_results = parameters.display or 5
        local button_data = {
          --[[
            1: `id` reference
            2: `meta_data` for callback
          ]]
        }
        for i = 1, maximum_results do
          local id = random_id(8)
          local page_meta = page_array[i]
          local display_text = "-"
          button_data[i] = {}
          button_data[i][1] = id
          if page_meta ~= nil then
            display_text = parameters.text(page_meta)
            button_data[i][2] = page_meta
          end
          render_ui(
            {
              {"page",
                {
                  id = id,
                  previous = definition.previous or definition,
                  text = display_text,
                  callback = function()
                    return button_data[i][2]
                  end,
                  definition = function()
                    local meta_data = button_data[i][2]
                    if meta_data == nil then
                      return {
                        {"event",
                          {
                            type = "load",
                            callback = function(meta_data)
                              clear_ui(player_id)
                              render_ui(meta_data["_"].previous_definition, player_id)
                            end
                          }
                        }
                      }
                    else
                      return parameters.definition(button_data[i][2])
                    end
                  end
                }
              }
            },
            player_id
          )
        end
        new_label(
          player_id,
          random_id(8),
          (
            function()
              local results_found = #page_array
              if results_found > 1 or results_found == 0 then
                return "∟ " .. results_found .. " results found"
              else
                return "∟ 1 result found"
              end
            end
          )()
        )
        new_input(
          player_id,
          random_id(8),
          "←←←←←←(  01  )→→→→→→",
          function(data)
            local arrow_state = data.value
            local left_arrow = arrow_state:match("(.*)%(")
            if left_arrow == nil then left_arrow = 6 else left_arrow = #left_arrow end
            local right_arrow = arrow_state:match("%)(.*)")
            if right_arrow == nil then right_arrow = 6 else right_arrow = #right_arrow end

            if right_arrow > 6 or 6 > right_arrow then
              page = page + 1
            end
            if left_arrow > 6 or 6 > left_arrow then
              page = page - 1
            end
            if 0 >= page then
              page = 1
            end

            local iteration_limit = page * maximum_results
            for i = 1, maximum_results do
              local page_meta = page_array[page * maximum_results - maximum_results + i]
              button_data[i][2] = page_meta
              if page_meta == nil then
                change_ui(player_id, button_data[i][1], "-")
              else
                change_ui(
                  player_id,
                  button_data[i][1],
                  parameters.text(page_meta)
                )
              end
            end

            local page_text = tostring(page)
            if 10 > page then
              page_text = "0" .. page
            end
            change_ui(player_id, data.id, "←←←←←←(  " .. page_text .. "  )→→→→→→")
          end
        )
        
      elseif name == "loop" then
        local loop_array = parameters.callback(meta_data)

        for i, value in ipairs(loop_array) do
          local definition_copy = table_shallowcopy(parameters.definition or {})
          definition_copy.meta = value
          for _, element in ipairs(definition_copy) do
            if element[1] == "page" then
              element[2].previous = definition.previous or definition
            end
          end
          render_ui(definition_copy, player_id)
        end

      elseif name == "conditional" then
        if parameters.callback(meta_data) == true then
          parameters.definition.meta = meta_data
          parameters.definition.previous = definition
          for _, element in ipairs(parameters.definition) do
            if element[1] == "page" then
              element[2].previous = definition.previous or definition
            end
          end
          render_ui(parameters.definition, player_id)
        end
      else
        print("undefined element: ".. name)
      end
    end
  end
end


---- QUEUE SYSTEM ----
-- all tasks execute each update
local interval_queue = {}
local iq_len = 0
-- only one task executes on each update
local ordered_queue = {}
local oq_len = 0
local oq_pos = 1
tm.os.SetModTargetDeltaTime(60)


function schedule_task(queue_type, task)
  if queue_type == "ordered" then
    table.insert(ordered_queue, task)
    oq_len = oq_len + 1
  elseif queue_type == "critical" then
    table.insert(interval_queue, task)
    iq_len = iq_len + 1
  else
    error("Invalid scheduler type")
  end
  if _G["update"] == nil then
    tm.os.SetModTargetDeltaTime(1/60)
    _G["update"] = function()
      if iq_len == 0 and oq_len == 0 then
        _G["update"] = nil
        tm.os.SetModTargetDeltaTime(60)
      else
        for i = 1, iq_len do
          local iq_item = interval_queue[i]
          if coroutine.status(iq_item) == "dead" then
            table.remove(interval_queue, i)
            iq_len = iq_len - 1
          else
            coroutine.resume(iq_item)
          end
        end
        if oq_len > 0 then
          if oq_pos > oq_len then
            oq_pos = 1
          end
          local oq_item = ordered_queue[oq_pos]
          if coroutine.status(oq_item) == "dead" then
            table.remove(ordered_queue, oq_pos)
            oq_len = oq_len - 1
          else
            coroutine.resume(oq_item)
          end
          oq_pos = oq_pos + 1
        end
      end
    end
  end
end
---- QUEUE SYSTEM END ----

---- KEYBOARD INPUT ----
local letters = "abcdefghijklmnopqrstuvwxyz1234567890"
local keyboard_states = {
  {}, -- host
  {}, -- player 2
  {}, -- player 3
  {}, -- player 4
  {}, -- player 5
  {}, -- player 6
  {}, -- player 7
  {}, -- player 8
}

for i = 1, #letters do
  local key = letters:sub(i, i)

  -- setup the callbacks
  _G["keypress_" .. key .. "_down"] = function(player_id)
    keyboard_states[player_id + 1][key] = true
  end
  _G["keypress_" .. key .. "_up"] = function(player_id)
    keyboard_states[player_id + 1][key] = false
  end

  -- initate the keyboard calls for all players
  for i = 0, 7 do
    keyboard_states[i + 1][key] = {
      active = false
    }
    tm.input.RegisterFunctionToKeyDownCallback(i, "keypress_" .. key .. "_down", key)
    tm.input.RegisterFunctionToKeyUpCallback(i, "keypress_" .. key .. "_up", key)
  end
end
---- KEYBOARD INPUT END ----

local prefab_search_results = {}
for _, prefab in ipairs(trailmakers_prefabs) do
  if (
      prefab ~= "PFB_PoisonCloud_Explosion" and
      prefab ~= "PFB_KungfuFlaglol" and
      prefab ~= "PFB_Runner-Monkey"
     ) then
    table.insert(prefab_search_results, prefab:sub(5, -1))
  end
end

local storage = {
  maps = {},
  editor = {
    map_name = "",
    enabled = false,
    attributes = {
      name = "",
      group = ""
    },
    objects = {

    },
    search_config = {
      searchables = prefab_search_results,
      query = ""
    },
    export = {
      name = "",
      authors = ""
    },
    key_selectables = {}
  }
}

--[[
  {
    name,
    group,
    object
  }
]]
function new_editor_object(data, position)
  local name = data.name
  local grouping = data.group

  local lookup_value = nil
  if type(grouping) == "table" then
    lookup_value = grouping
  elseif grouping ~= "" then
    lookup_value = storage.editor.objects
    for group in string.gmatch(grouping, '([^%/]+)') do
      if lookup_value[group] == nil then
        lookup_value[group] = {}
      end
      lookup_value = lookup_value[group]
    end
  else
    lookup_value = storage.editor.objects
  end
  
  if lookup_value.object ~= nil then
    return false, "group_object_name_collision"
  elseif lookup_value[name] ~= nil then
    return false, "object_collision"
  elseif type(lookup_value[name]) == "table" then
    return false, "group_collision"
  else
    local spawn_position = position or new_vector3()
    local gameobj = tm_spawn_object(
      spawn_position,
      "PFB_" .. data.object
    )
    gameobj.SetIsStatic(true)
    lookup_value[name] = {
      object = gameobj,
      prefab_id = "PFB_" .. data.object,
      transform = gameobj.GetTransform(),
      attributes = {
        is_trigger = false,
        static = true,
        visible = true
      }
    }
    return true, nil
  end
end

local editor_message_reset_delay = nil
function update_editor_message(message, reset_delay)
  editor_message_reset_delay = get_time() + reset_delay
  if #message > 64 then
    message = message:sub(1, 64)
  end
  schedule_task(
    "ordered",
    coroutine.create(
      function()
        change_ui(0, "editor_message", message)
        while editor_message_reset_delay > get_time() do
          coroutine.yield()
        end
        change_ui(0, "editor_message", "---------No Editor Messages---------")
      end
    )
  )
end
local message_reset_delay = nil
function timed_change_ui(player_id, element_id, message_data, delay)
  message_reset_delay = get_time() + delay
  local original = message_data.original
  local new = message_data.new
  if #new > 64 then
    new = new:sub(1, 64)
  end
  schedule_task(
    "ordered",
    coroutine.create(
      function()
        change_ui(player_id, element_id, new)
        while message_reset_delay > get_time() do
          coroutine.yield()
        end
        change_ui(player_id, element_id, original)
      end
    )
  )
end

_G.map_editor_object_component = {
  {"conditional",
    {
      callback = function(meta_data)
        return meta_data.type == "group" or meta_data.type == nil
      end,
      definition = {
        {"conditional",
          {
            callback = function(meta_data)
              return meta_data.type == "group"
            end,
            definition = {
              {"label",
                {
                  text = "Group Information:"
                }
              },
              {"input",
                {
                  type = "text",
                  text = |meta_data| "Name: " .. meta_data.name,
                  callback = function(data, meta_data)
                    local value = data.value
                    local player_id = meta_data["_"].player_id
                    if value == "" then
                      value = "group_" .. random_id(4)
                    end
                    while meta_data.reference[value] ~= nil do
                      value = data.value .. "_" .. random_id(4)
                      if #value > 48 then
                        value = "group_" .. random_id(4)
                      end
                    end
                    meta_data.reference[value] = meta_data.reference[meta_data.name]
                    meta_data.reference[meta_data.name] = nil
                    meta_data.name = value
      
                    -- requires a full redraw to properly update all children with new meta data.
                    -- it's odd, but works well.
                    clear_ui(player_id)
                    meta_data["_"].definition.meta = meta_data
                    render_ui(meta_data["_"].definition, player_id)
                  end
                }
              },
              {"page",
                {
                  text = "Properties",
                  definition = {
                    {"event",
                      {
                        type = "draw",
                        callback = function(meta_data)
                          local lookup_data = {}
                          local transforms = {}
                          local game_objects = {}
                          local center_point = new_vector3()
                          local object_count = 0

                          for _, value in pairs(meta_data.reference[meta_data.name]) do
                            table.insert(lookup_data, value)
                          end

                          local i = 1
                          while #lookup_data >= i do
                            local value = lookup_data[i]
                            local transform = value.transform
                            if transform ~= nil then
                              table.insert(transforms, transform)
                              local position = transform.GetPosition()
                              local rotation = transform.GetRotation()
                              local scale = transform.GetScale()
                              table.insert(game_objects,
                                {
                                  transform = transform,
                                  object = value.object,
                                  initial_pos = new_vector3(
                                    position.x,
                                    position.y,
                                    position.z
                                  ),
                                  real_pos = new_vector3(
                                    position.x,
                                    position.y,
                                    position.z
                                  ),
                                  initial_rot = new_vector3(
                                    rotation.x,
                                    rotation.y,
                                    rotation.z
                                  ),
                                  initial_scale = new_vector3(
                                    scale.x,
                                    scale.y,
                                    scale.z
                                  )
                                }
                              )
                              center_point = add_vector3(center_point, position)
                              object_count = object_count + 1
                            else
                              for _, inner_value in pairs(value) do
                                table.insert(lookup_data, inner_value)
                              end
                            end
                            i = i + 1
                          end
                          center_point = divide_vector3(center_point, object_count)
                          return {
                            center_point = center_point,
                            transforms = transforms,
                            game_objects = game_objects,
                            position_offset = new_vector3(),
                            scale_offset = new_vector3(1, 1, 1)
                          }
                        end
                      }
                    },
                    {"label",
                      {
                        text = "Position Offset:"
                      }
                    },
                    {"input",
                      {
                        type = "number",
                        text = "x: 0",
                        callback = function(data, meta_data)
                          local value = math.floor(data.value * 1000) / 1000
                          local position_offset = meta_data.position_offset
                          position_offset.x = value

                          for _, gameobj in ipairs(meta_data.game_objects) do
                            gameobj.transform.SetPosition(
                              add_vector3(gameobj.real_pos, position_offset)
                            )
                          end
                        end
                      }
                    },
                    {"input",
                      {
                        type = "number",
                        text = "y: 0",
                        callback = function(data, meta_data)
                          local value = math.floor(data.value * 1000) / 1000
                          local position_offset = meta_data.position_offset
                          position_offset.y = value

                          for _, gameobj in ipairs(meta_data.game_objects) do
                            gameobj.transform.SetPosition(
                              add_vector3(gameobj.real_pos, position_offset)
                            )
                          end
                        end
                      }
                    },
                    {"input",
                      {
                        type = "number",
                        text = "z: 0",
                        callback = function(data, meta_data)
                          local value = math.floor(data.value * 1000) / 1000
                          local position_offset = meta_data.position_offset
                          position_offset.z = value

                          for _, gameobj in ipairs(meta_data.game_objects) do
                            gameobj.transform.SetPosition(
                              add_vector3(gameobj.real_pos, position_offset)
                            )
                          end
                        end
                      }
                    },
                    {"label",
                      {
                        text = "Scale Offset:"
                      }
                    },
                    {"input",
                      {
                        type = "number",
                        text = "x: 1",
                        callback = function(data, meta_data)
                          local value = math.floor(data.value * 1000) / 1000
                          local center_point = meta_data.center_point
                          local scale_offset = meta_data.scale_offset
                          
                          for _, gameobj in ipairs(meta_data.game_objects) do
                            local real_pos = gameobj.real_pos
                            local initial_scale = gameobj.initial_scale
                            local object_transform = gameobj.transform

                            scale_offset.x = value
                            object_transform.SetScale(
                              initial_scale.x * value,
                              initial_scale.y * scale_offset.y,
                              initial_scale.z * scale_offset.z
                            )

                            real_pos.x = center_point.x + (gameobj.initial_pos.x - center_point.x) * value
                            object_transform.SetPosition(
                              add_vector3(
                                real_pos,
                                meta_data.position_offset
                              )
                            )
                          end
                        end
                      }
                    },
                    {"input",
                      {
                        type = "number",
                        text = "y: 1",
                        callback = function(data, meta_data)
                          local value = math.floor(data.value * 1000) / 1000
                          local center_point = meta_data.center_point
                          local scale_offset = meta_data.scale_offset

                          for _, gameobj in ipairs(meta_data.game_objects) do
                            local real_pos = gameobj.real_pos
                            local initial_scale = gameobj.initial_scale
                            local object_transform = gameobj.transform

                            scale_offset.y = value
                            object_transform.SetScale(
                              initial_scale.x * scale_offset.x,
                              initial_scale.y * value,
                              initial_scale.z * scale_offset.z
                            )

                            real_pos.y = center_point.y + (gameobj.initial_pos.y - center_point.y) * value
                            object_transform.SetPosition(
                              add_vector3(
                                real_pos,
                                meta_data.position_offset
                              )
                            )
                          end
                        end
                      }
                    },
                    {"input",
                      {
                        type = "number",
                        text = "z: 1",
                        callback = function(data, meta_data)
                          local value = math.floor(data.value * 1000) / 1000
                          local center_point = meta_data.center_point
                          local scale_offset = meta_data.scale_offset

                          for _, gameobj in ipairs(meta_data.game_objects) do
                            local real_pos = gameobj.real_pos
                            local initial_scale = gameobj.initial_scale
                            local object_transform = gameobj.transform

                            scale_offset.z = value
                            object_transform.SetScale(
                              initial_scale.x * scale_offset.x,
                              initial_scale.y * scale_offset.y,
                              initial_scale.z * value
                            )

                            real_pos.z = center_point.z + (gameobj.initial_pos.z - center_point.z) * value
                            object_transform.SetPosition(
                              add_vector3(
                                real_pos,
                                meta_data.position_offset
                              )
                            )
                          end
                        end
                      }
                    },
                    {"label",
                      {
                        text = "Rotation Offset:"
                      }
                    },
                    {"page",
                      {
                        text = "Click Me!",
                        definition = {
                          {"label",
                            {
                              text = "Note: page will be moved in\nthe future."
                            }
                          },
                          {"input",
                            {
                              type = "number",
                              text = "y: 0",
                              callback = function(data, meta_data)
                                local value = math.floor(data.value * 1000) / 1000
                                local center_point = meta_data.center_point
      
                                local sin_angle = math.sin(math.rad(value))
                                local cos_angle = math.cos(math.rad(value))
      
                                for _, gameobj in ipairs(meta_data.game_objects) do
                                  local initial_pos = gameobj.initial_pos
                                  local initial_rot = gameobj.initial_rot
                                  local real_pos = gameobj.real_pos
                                  local x_pos = initial_pos.x - center_point.x
                                  local z_pos = initial_pos.z - center_point.z
                                  
                                  local new_position = new_vector3(
                                    x_pos * cos_angle - z_pos * sin_angle + center_point.x,
                                    initial_pos.y,
                                    x_pos * sin_angle + z_pos * cos_angle + center_point.z
                                  )
                                  gameobj.real_pos = new_position
                                  gameobj.transform.SetRotation(
                                    initial_rot.x,
                                    initial_rot.y - value,
                                    initial_rot.z
                                  )
                                  gameobj.transform.SetPosition(
                                    add_vector3(
                                      new_position,
                                      meta_data.position_offset
                                    )
                                  )
                                end
                              end
                            }
                          }
                        }
                      },
                    },
                    {"label",
                      {
                        text = "………………………………………."
                      }
                    },
                    {"button",
                      {
                        text = "Delete Group",
                        callback = function(data, meta_data)
                          local player_id = meta_data["_"].player_id
                          local value = data.value
                          if value == "Delete Group" then
                            timed_change_ui(
                              meta_data["_"].player_id,
                              data.id,
                              {
                                original = "Delete Group",
                                new = "are you sure?"
                              },
                              1
                            )
                          else
                            local player_id = meta_data["_"].player_id
                            for _, transform_data in ipairs(meta_data.game_objects) do
                              transform_data.object.Despawn()
                            end
                            meta_data.reference[meta_data.name] = nil
                            clear_ui(player_id)
                            render_ui(
                              -- back track two pages
                              meta_data["_"].previous_definition.meta["_"].previous_definition,
                              player_id
                            )
                          end    
                        end
                      }
                    }
                  }
                }
              },
              {"label",
                {
                  text = "……………………………………….\n" ..
                         "Inner Groups & Objects:"
                }
              }
            }
          }
        },
        {"conditional",
          {
            callback = function(meta_data)
              return meta_data.type == nil
            end,
            definition = {
              {"label",
                {
                  text = "Group & Objects:"
                }
              }
            }
          }
        },
        {"page-carousel",
          {
            display = 5,
            callback = function(meta_data)
              local groupings = {}
              local group = nil
              if meta_data.reference ~= nil then
                group = meta_data.reference[meta_data.name]
              else
                group = storage.editor.objects
              end
              if type(group) == "table" then
                for key, value in pairs(group) do
                  table.insert(groupings,
                    {
                      reference = group,
                      name = key,
                      type = (
                        function()
                          if value.object == nil then
                            return "group"
                          else
                            return "object"
                          end
                        end
                      )()
                    }
                  )
                end
              end
              return groupings
            end,
            text = |meta_data| "[" .. meta_data.type .. "] " .. (
              function()
                local name = meta_data.name
                if #name > 22 then
                  return name:sub(1, 18) .. ".."
                else
                  return name
                end
              end
            )(),
            definition = function(meta_data)
              return map_editor_object_component
            end
          }
        },
        --[[
        {"loop",
          {
            callback = function(meta_data)
              local groupings = {}
              local group = nil
              if meta_data.reference ~= nil then
                group = meta_data.reference[meta_data.name]
              else
                group = storage.editor.objects
              end
              if type(group) == "table" then
                for key, value in pairs(group) do
                  table.insert(groupings,
                    {
                      reference = group,
                      name = key,
                      type = (
                        function()
                          if value.object == nil then
                            return "group"
                          else
                            return "object"
                          end
                        end
                      )()
                    }
                  )
                end
              end
              return groupings
            end,
            definition = {
              {"page",
                {
                  text = |meta_data| "[" .. meta_data.type .. "] " .. (
                    function()
                      local name = meta_data.name
                      if #name > 22 then
                        return name:sub(1, 18) .. ".."
                      else
                        return name
                      end
                    end
                  )(),
                  definition = function(meta_data)
                    return map_editor_object_component
                  end
                }
              }
            }
          }
        }
        ]]
      }
    }
  },
  {"conditional",
    {
      callback = function(meta_data)
        return meta_data.type == "object"
      end,
      definition = {
        {"event",
          {
            type = "load",
            callback = function(meta_data)
              local object_reference = meta_data.reference[meta_data.name]
              local object = object_reference.object
              local transform = object_reference.transform
              return {
                object = object,
                attributes = object_reference.attributes,
                transform = transform,
                position = transform.GetPosition(),
                rotation = transform.GetRotation(),
                scale = transform.GetScale()
              }
            end
          }
        },
        {"label",
          {
            text = "Object Information:"
          }
        },
        {"input",
          {
            type = "text",
            text = |meta_data| "Name: " .. meta_data.name,
            callback = function(data, meta_data)
              local value = data.value
              if value == "" then
                value = "Name: obj_" .. random_id(4)
                change_ui(0, data.id, value)
              end
              while meta_data.reference[value] ~= nil do
                value = data.value .. "_" .. random_id(4)
                if #value > 48 then
                  value = "obj_" .. random_id(4)
                end
                change_ui(0, data.id, "Name: " .. value)
              end
              meta_data.reference[value] = meta_data.reference[meta_data.name]
              meta_data.reference[meta_data.name] = nil
              meta_data.name = value
            end
          }
        },
        {"page",
          {
            text = "Properties",
            definition = {
              {"label",
                {
                  text = "General Properties:"
                }
              },
              {"button",
                {
                  text = function(meta_data)
                    return "visible: " .. tostring(meta_data.attributes.visible)
                  end,
                  callback = function(data, meta_data)
                    meta_data.attributes.visible = not meta_data.attributes.visible

                    local is_visible = meta_data.attributes.visible
                    meta_data.object.SetIsVisible(is_visible)
                    change_ui(meta_data["_"].player_id, data.id, "visible: " .. tostring(is_visible))
                  end
                }
              },
              {"button",
                {
                  text = function(meta_data)
                    return "static: " .. tostring(meta_data.attributes.static)
                  end,
                  callback = function(data, meta_data)
                    meta_data.attributes.static = not meta_data.attributes.static

                    local is_static = meta_data.attributes.static
                    meta_data.object.SetIsStatic(is_static)
                    change_ui(meta_data["_"].player_id, data.id, "static: " .. tostring(is_static))
                  end
                }
              },
              {"button",
                {
                  text = function(meta_data)
                    return "is trigger: " .. tostring(meta_data.attributes.is_trigger)
                  end,
                  callback = function(data, meta_data)
                    meta_data.attributes.is_trigger = not meta_data.attributes.is_trigger

                    local is_trigger = meta_data.attributes.is_trigger
                    meta_data.object.SetIsTrigger(is_trigger)
                    change_ui(meta_data["_"].player_id, data.id, "is trigger: " .. tostring(is_trigger))
                  end
                }
              }
            }
          }
        },
        {"button",
          {
            id = "duplicate_button",
            text = "Duplicate Object",
            callback = function(data, meta_data)
              --[[
              object = gameobj,
              prefab_id = "PFB_" .. data.object,
              transform = gameobj.GetTransform(),
              attributes = {
                is_trigger = false,
                static = true,
                visible = true
              }
              ]]
              local name = meta_data.name
              local group_reference = meta_data.reference
              local current_object = group_reference[name]
              local current_attributes = current_object.attributes
              local transform = current_object.transform
              local position = transform.GetPosition()
              while true do
                local new_name = name .. "_" .. random_id(4)
                local status, new_gameobj = new_editor_object(
                  {
                    name = new_name,
                    group = group_reference,
                    object = current_object.prefab_id:sub(5, -1)
                  },
                  position
                )
                if status == true then
                  local new_gameobj = group_reference[new_name]
                  local object_reference = new_gameobj.object
                  local new_transform = new_gameobj.transform
                  new_transform.SetRotation(transform.GetRotation())
                  new_transform.SetScale(transform.GetScale())
                  local new_attributes = new_gameobj.attributes
                  new_attributes.is_trigger = current_attributes.is_trigger
                  object_reference.SetIsTrigger(new_attributes.is_trigger)
                  new_attributes.static = current_attributes.static
                  object_reference.SetIsStatic(new_attributes.static)
                  new_attributes.visible = current_attributes.visible
                  object_reference.SetIsVisible(new_attributes.visible)
                  break
                end
              end
              timed_change_ui(
                0,
                "duplicate_button",
                {
                  original = "Duplicate Object",
                  new = "Duplicated Successfully!"
                },
                1
              )
            end
          }
        },
        {"page",
          {
            preserve_meta = true,
            text = "Change Group",
            definition = {
              {"label",
                {
                  text = "Enter the new target group:"
                }
              },
              {"input",
                {
                  type = "text",
                  text = |meta_data| meta_data.new_group_path or "",
                  callback = function(data, meta_data)
                    meta_data.new_group_path = data.value
                  end
                }
              },
              {"button",
                {
                  id = "change_group_button",
                  text = "Change Group",
                  callback = function(data, meta_data)
                    local name = meta_data.name
                    local lookup_value = storage.editor.objects
                    for group in string.gmatch((meta_data.new_group_path or ""), '([^%/]+)') do
                      if lookup_value[group] == nil then
                        lookup_value[group] = {}
                      end
                      lookup_value = lookup_value[group]
                    end
                    if lookup_value.object ~= nil then
                      timed_change_ui(
                        0,
                        "change_group_button",
                        {
                          original = "Change Group",
                          new = "group name →|← object name."
                        },
                        3
                      )
                    elseif lookup_value[name] ~= nil then
                      timed_change_ui(
                        0,
                        "change_group_button",
                        {
                          original = "Change Group",
                          new = "object name exists in group."
                        },
                        3
                      )
                    elseif type(lookup_value[name]) == "table" then
                      timed_change_ui(
                        0,
                        "change_group_button",
                        {
                          original = "Change Group",
                          new = "object name →|← group name."
                        },
                        3
                      )
                    else
                      lookup_value[name] = meta_data.reference[name]
                      meta_data.reference[name] = nil
                      local player_id = meta_data["_"].player_id
                      clear_ui(player_id)
                      render_ui(meta_data["_"].previous_definition.meta["_"].previous_definition, player_id)
                    end
                  end
                }
              }
            }
          }
        },
        {"label",
          {
            text = "Position:"
          }
        },
        {"input",
          {
            type = "number",
            id = "position_x",
            text = |meta_data| "x: " .. math.floor(meta_data.position.x * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.transform
              local current_position = transform.GetPosition()
              meta_data.reference[meta_data.name].transform.SetPosition(value, current_position.y, current_position.z)
            end
          }
        },
        {"input",
          {
            type = "number",
            id = "position_y",
            text = |meta_data| "y: " .. math.floor(meta_data.position.y * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.transform
              local current_position = transform.GetPosition()
              meta_data.reference[meta_data.name].transform.SetPosition(current_position.x, value, current_position.z)
            end
          }
        },
        {"input",
          {
            type = "number",
            id = "position_z",
            text = |meta_data| "z: " .. math.floor(meta_data.position.z * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.transform
              local current_position = transform.GetPosition()
              meta_data.reference[meta_data.name].transform.SetPosition(current_position.x, current_position.y, value)
            end
          }
        },
        {"label",
          {
            text = "Rotation:"
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "x: " .. math.floor(meta_data.rotation.x * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.transform
              local current_rotation = transform.GetRotation()
              meta_data.reference[meta_data.name].transform.SetRotation(value, current_rotation.y, current_rotation.z)
            end
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "y: " .. math.floor(meta_data.rotation.y * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.transform
              local current_rotation = transform.GetRotation()
              meta_data.reference[meta_data.name].transform.SetRotation(current_rotation.x, value, current_rotation.z)
            end
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "z: " .. math.floor(meta_data.rotation.z * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.transform
              local current_rotation = transform.GetRotation()
              meta_data.reference[meta_data.name].transform.SetRotation(current_rotation.x, current_rotation.y, value)
            end
          }
        },
        {"label",
          {
            text = "Scale:"
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "x: " .. math.floor(meta_data.scale.x * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.transform
              local current_scale = transform.GetScale()
              meta_data.reference[meta_data.name].transform.SetScale(value, current_scale.y, current_scale.z)
            end
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "y: " .. math.floor(meta_data.scale.y * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.transform
              local current_scale = transform.GetScale()
              meta_data.reference[meta_data.name].transform.SetScale(current_scale.x, value, current_scale.z)
            end
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "z: " .. math.floor(meta_data.scale.z * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.transform
              local current_scale = transform.GetScale()
              meta_data.reference[meta_data.name].transform.SetScale(current_scale.x, current_scale.y, value)
            end
          }
        },
        {"button",
          {
            text = "Delete Object",
            callback = function(data, meta_data)
              local value = data.value
              if value == "Delete Object" then
                timed_change_ui(
                  meta_data["_"].player_id,
                  data.id,
                  {
                    original = "Delete Object",
                    new = "are you sure?"
                  },
                  1
                )
              else
                local player_id = meta_data["_"].player_id
                meta_data.reference[meta_data.name].object.Despawn()
                meta_data.reference[meta_data.name] = nil
                clear_ui(player_id)
                render_ui(meta_data["_"].previous_definition, player_id)
              end
            end
          }
        }
      }
    }
  }
}

-- converts a table into lmf json
function generate_save_json(object_table)
  local save_table = {
    objects = {}
  }
  for key, value in pairs(object_table) do
    if value.object == nil then
      value = generate_save_json(value)
      save_table.objects[key] = value.objects
    else
      local position = value.transform.GetPosition()
      local rotation = value.transform.GetRotation()
      local scale = value.transform.GetScale()
      local attributes = value.attributes
      -- only a maximum of three decimal places is permitted
      save_table.objects[key] = {
        prefab = value.prefab_id,
        position = {
          math.floor(position.x * 1000) / 1000,
          math.floor(position.y * 1000) / 1000,
          math.floor(position.z * 1000) / 1000
        },
        rotation = {
          math.floor(rotation.x * 1000) / 1000,
          math.floor(rotation.y * 1000) / 1000,
          math.floor(rotation.z * 1000) / 1000
        },
        scale = {
          math.floor(scale.x * 1000) / 1000,
          math.floor(scale.y * 1000) / 1000,
          math.floor(scale.z * 1000) / 1000
        },
        -- [is static, is visible, is trigger]
        attributes = {attributes.static, attributes.visible, attributes.is_trigger}
      }
    end
  end
  return save_table
end

-- loads objects that are formatted in lmf json
function load_objects(map_table)
  local objects = {}
  for key, value in pairs(map_table) do
    --[[
      if a prefab key isn't found, then we assume the table is a group;
      this means we need to recursively check and enact on this groups
      objects.
    ]]
    if value.prefab == nil then
      value = load_objects(value)
      objects[key] = value
    else
      -- define values
      local json_position = value.position
      local json_rotation = value.rotation
      local json_scale = value.scale
      local json_attributues = value.attributes
      local is_static = json_attributues[1]
      local is_visible = json_attributues[2]
      local is_trigger = json_attributues[3]

      -- set object data
      local game_object = tm.physics.SpawnObject(
        new_vector3(json_position[1], json_position[2], json_position[3]),
        value.prefab
      )
      game_object.SetIsStatic(true)
      game_object.SetIsVisible(is_visible)
      game_object.SetIsTrigger(is_trigger)
      local transform = game_object.GetTransform()
      transform.SetRotation(json_rotation[1], json_rotation[2], json_rotation[3])
      transform.SetScale(json_scale[1], json_scale[2], json_scale[3])

      -- store data in object cache
      objects[key] = {
        object = game_object,
        prefab_id = value.prefab,
        transform = transform,
        attributes = {
          static = is_static,
          visible = is_visible,
          is_trigger = is_trigger
        }
      }
    end
  end
  return objects
end

local map_editor = {
  {"page",
    {
      text = "Need Help?"
    }
  },
  {"event",
    {
      type = "load",
      callback = function(meta_data)
        -- check for pre-existing map save
        local map_name = meta_data.name
        storage.editor.map_name = map_name
        local map_save = tm.os.ReadAllText_Dynamic("maps/projects/" .. map_name)
        if map_save ~= "" and map_save ~= "__empty" then
          -- if a save exists, initialize all the objects
          storage.editor.objects = load_objects(
            json.parse(map_save).objects
          )
        end
      end
    }
  },
  {"event",
    {
      type = "unload",
      callback = function(meta_data)
        local map_name = storage.editor.map_name
        storage.editor.enabled = false
        local object_cache = storage.editor.objects

        -- saves data to file, and checks if file needs to be mentioned in projects file
        local save_json = generate_save_json(object_cache)
        tm.os.WriteAllText_Dynamic("maps/projects/" .. map_name, json.serialize(save_json))
        local projects_file = tm.os.ReadAllText_Dynamic("maps/projects/_")
        local projects_string = ""
        if projects_file:find(map_name) == nil then
          projects_string = map_name
        end
        for project in string.gmatch(projects_file, "[^\r\n]+") do
          if project ~= "__empty" then
            projects_string = projects_string .. ((projects_string == "") and "" or "\n") .. project
          end
        end
        tm.os.WriteAllText_Dynamic(
          "maps/projects/_", 
          projects_string
        )

        -- converts top layer of objects into arra
        local game_objects = {}
        for _, value in pairs(object_cache) do
          table.insert(game_objects, value)
        end
        -- further expands on `game_objects` array, recursively finding game objects and unloading them
        local i = 1
        while #game_objects >= i do
          local value = game_objects[i]
          local transform = value.transform
          if transform ~= nil then
            value.object.Despawn()
          else
            for _, inner_value in pairs(value) do
              table.insert(game_objects, inner_value)
            end
          end
          i = i + 1
        end

        --resets editor variables
        storage.editor.objects = {}
        storage.editor.map_name = ""
        storage.editor.search_config.query = ""
        storage.editor.attributes = {
          name = "",
          group = ""
        }
      end
    }
  },
  {"input",
    {
      id = "editor_message",
      type = "text",
      text = "---------No Editor Messages---------",
      callback = function(data)
        change_ui(0, data.id, "---------No Editor Messages---------")
      end
    }
  },
  {"label",
    {
      text = "Object Attributes:"
    }
  },
  {"input",
    {
      type = "text",
      text = function()
        return "Group: " .. storage.editor.attributes.group
      end,
      callback = function(data)
        storage.editor.attributes.group = data.value
      end
    }
  },
  {"input",
    {
      type = "text",
      text = function()
        return "Name: " .. storage.editor.attributes.name
      end,
      callback = function(data)
        if #data.value > 48 then
          data.value = data.value:sub(1, 48)
          change_ui(0, data.id, "Name: " .. data.value)
          update_editor_message("[x]: object names cannot exceed 48 characters.", 5)
        end
        storage.editor.attributes.name = data.value
      end
    }
  },
  {"page",
    {
      text = "Advanced",
      definition = {
        {"label",
          {
            text = "Variable Rotation"
          }
        },
        {"input",
          {
            type = "number",
            text = "min: 0",
            callback = function(data, meta_data)

            end
          }
        }
      }
    }
  },
  {"label",
    {
      text = "Available Objects:"
    }
  },
  {"search",
    {
      configuration = storage.editor.search_config,
      callback = function(response, meta_data)
        local response_type = response.type
        local data = response.data
        if response_type == "update" then
          storage.editor.key_selectables = data
        else
          local object_name = data[2]
          if object_name == nil then
            return
          else
            local attributes = storage.editor.attributes
            local name = attributes.name
            local group = attributes.group
            if name == "" then
              name = "obj"
            end
            
            local player_position = tm.players.GetPlayerTransform(0).GetPosition()
            local status, result = new_editor_object(
              {
                name = name,
                group = attributes.group,
                object = object_name
              },
              player_position
            )
            if status == false then
              if result == "group_object_name_collision" then
                update_editor_message("[x]: group name cannot match existing object name.", 5)
              else
                while true do
                  local temp_name = name .. "_" .. random_id(4)
                  local status, result = new_editor_object(
                    {
                      name = temp_name,
                      group = attributes.group,
                      object = object_name
                    },
                    player_position
                  )
                  if status == true then
                    name = temp_name
                    break
                  end
                end
                timed_change_ui(
                  0,
                  "editor_message",
                  {
                    original = "---------No Editor Messages---------",
                    new = "[√]: " .. name .. "→\"" .. object_name .. "\" " .. " has been added."
                  },
                  5
                )
              end
            else
              timed_change_ui(
                0,
                "editor_message",
                {
                  original = "---------No Editor Messages---------",
                  new = "[√]: " .. name .. "→\"" .. object_name .. "\" " .. " has been added."
                },
                5
              )
            end
          end
          print("index: " .. data[1])
          print("value: " .. (data[2] or "no value found"))
        end
      end
    }
  },
  {"page",
    {
      text = "Modify Groups & Objects",
      definition = map_editor_object_component
    }
  },
  {"label",
    {
      text = "::::::::::::::::::::::::::::::::::::::::::::::::::\n" ..
             "Miscellaneous:"
    }
  },
  {"page",
    {
      text = "Map Options",
      definition = {
        {"label",
          {
            text = "Dangerous:"
          }
        },
        {"button",
          {
            text = "Delete Map",
            callback = function(data, meta_data)
              local value = data.value
              local player_id = meta_data["_"].player_id
              if value == "Delete Map" then
                timed_change_ui(
                  player_id,
                  data.id,
                  {
                    original = "Delete Map",
                    new = "This cannot be reversed."
                  },
                  2
                )
              elseif value == "This cannot be reversed." then
                timed_change_ui(
                  player_id,
                  data.id,
                  {
                    original = "Delete Map",
                    new = "Press to confirm deletion."
                  },
                  2
                )
              else
                local projects_file = tm.os.ReadAllText_Dynamic("maps/projects/_")
                local projects_string = ""
                local map_name = meta_data.name
                for project in string.gmatch(projects_file, "[^\r\n]+") do
                  if project ~= map_name then
                    projects_string = projects_string .. ((projects_string == "") and "" or "\n") .. project
                  end
                end
                if projects_string == "" then
                  projects_string = "__empty"
                end
                tm.os.WriteAllText_Dynamic("maps/projects/_", projects_string)
                tm.os.WriteAllText_Dynamic("maps/projects/" .. map_name, "__empty")
                clear_ui(player_id)
                render_ui(
                  meta_data["_"].previous_definition.meta["_"].previous_definition,
                  player_id
                )
              end
            end
          }
        }
      }
    }
  },
  {"page",
    {
      text = "Export Map",
      definition = {
        {"event",
          {
            type = "draw",
            callback = function()
              return {
                export = storage.editor.export
              }
            end
          }
        },
        {"label",
          {
            text = "Map Name:"
          }
        },
        {"input",
          {
            type = "text",
            text = |meta_data| meta_data.export.name,
            callback = function(data, meta_data)
              meta_data.export.name = data.value
            end
          }
        },
        {"label",
          {
            text = "Author(s):"
          }
        },
        {"input",
          {
            type = "text",
            text = |meta_data| meta_data.export.authors,
            callback = function(data, meta_data)
              meta_data.export.authors = data.value
            end
          }
        },
        {"page",
          {
            text = "Preview Content",
            definition = {
              {"label",
                {
                  text = ":::::::::::::::::::Preview:::::::::::::::::::"
                }
              },
              {"conditional",
                {
                  callback = |meta_data| meta_data.export.name ~= "",
                  definition = {
                    {"label",
                      {
                        text = |meta_data| meta_data.export.name
                      }
                    }
                  }
                }
              },
              {"conditional",
                {
                  callback = |meta_data| meta_data.export.authors ~= "",
                  definition = {
                    {"label",
                      {
                        text = |meta_data| "∟ " .. meta_data.export.authors
                      }
                    }
                  }
                }
              }
            }
          }
        },
        {"label",
          {
            text = "::::::::::::::::::::::::::::::::::::::::::::::::::"
          }
        },
        {"button",
          {
            text = "Loader Type: gradual",
            callback = function(data, meta_data)

            end
          }
        },
        {"button",
          {
            text = "Click to Export Map",
            callback = function(data, meta_data)
              tm.os.WriteAllText_Dynamic(
                "maps/projects/exported/" .. storage.editor.map_name .. "/data_static/map",
                json.serialize(generate_save_json(storage.editor.objects))
              )
              tm.os.WriteAllText_Dynamic(
                "maps/projects/exported/" .. storage.editor.map_name .. "/main.lua",
                tm.os.ReadAllText_Static("gradual_loader.lua")
              )
            end
          }
        }
      },
    }
  }
}

local versioning = "v0.5.0"
local definition = {
  {"label",
    {
      access = { 0, 1, 2, 3, 4, 5, 6, 7 },
      text = "     Lamersc's General Utiliities     \n" ..
             ":::::::::::::::::::::" .. versioning .. ":::::::::::::::::::::"
    }
  },
  {"page",
    {
      access = { 0 },
      text = "Game Options",
      definition = {}
    }
  },
  {"page",
    {
      access = { 0 },
      text = "Multiplayer Options",
      definition = {}
    }
  },
  {"page",
    {
      access = { 0 },
      text = "Map Tools",
      definition = {
        {"label",
          {
            text = "Select an option below:                "
          }
        },
        {"page",
          {
            access = { 0 },
            text = "Load Maps",
            definition = {
              {"page",
                {
                  text = "Need Help?",
                  definition = {
                    {"label",
                      {
                        text = "Tutorials:"
                      }
                    },
                    {"page",
                      {
                        text = "How to Add Custom Maps"
                      }
                    }
                  }
                }
              },
              {"label",
                {
                  text = "::::::::::::::::::::::::::::::::::::::::::::::::::\n" ..
                         "Available Maps:"
                }
              },
              {"loop",
                {
                  callback = function()
                    local maps_table = {}
                    local shipped_maps = tm.os.ReadAllText_Static("maps/maps.list")
                    for folder in string.gmatch(shipped_maps, "[^\r\n]+") do
                      if folder ~= "" then
                        table.insert(maps_table,
                          {
                            name = folder,
                            static = true
                          }
                        )
                      end
                    end
                    local custom_maps = tm.os.ReadAllText_Dynamic("maps/maps.list")
                    for folder in string.gmatch(custom_maps, "[^\r\n]+") do
                      if folder ~= "" then
                        table.insert(maps_table,
                          {
                            name = folder,
                            static = false
                          }
                        )
                      end
                    end
                    return maps_table
                  end,
                  definition = {
                    {"page",
                      {
                        text = |meta_data| meta_data.name,
                        definition = {
                          {"event",
                            {
                              type = "draw",
                              callback = function(meta_data)
                                local map_meta = {}
                                local name = meta_data.name
                                local is_static = meta_data.static
                                local content = nil
                                if is_static == true then
                                  content = tm.os.ReadAllText_Static("maps/" .. name)
                                  if content == "" then
                                    content = tm.os.ReadAllText_Static("maps/" .. name .. "/_")
                                  end
                                else
                                  content = tm.os.ReadAllText_Dynamic("maps/" .. name)
                                  if content == "" then
                                    content = tm.os.ReadAllText_Dynamic("maps/" .. name .. "/_")
                                  end
                                end

                                local json_status, json_result = pcall(
                                  function()
                                    return json.parse(content)
                                  end
                                )
                                if json_status == true then
                                  if json_result["ObjectList"] ~= nil then
                                    map_meta.map_name = json_result["Name"] or "Unknown"
                                    map_meta.authors = json_result["Authors"] or "Unknown"
                                    map_meta.format = "Trailmappers"
                                    map_meta.description = json_result["Description"] or "No Description Found."
                                    map_meta.prefab_total = #json_result["ObjectList"]
                                    map_meta.method = "normal"
                                    map_meta.content = json_result
                                  elseif json_result["Spawns"] ~= nil then
                                    map_meta.map_name = "Unknown"
                                    map_meta.authors = json_result["Authors"] or "Unknown"
                                    map_meta.format = "Trailedit [modded]"
                                    map_meta.description = json_result["Description"] or "No Description Found."
                                    map_meta.prefab_total = "Unimplemented."
                                    map_meta.method = "normal"
                                    map_meta.content = json_result
                                  else
                                    map_meta.map_name = "Unknown"
                                    map_meta.authors = "Unknown"
                                    map_meta.format = "Unsupported"
                                    map_meta.description = "No Description Found."
                                    map_meta.prefab_total = "None"
                                    map_meta.content = nil
                                  end
                                else
                                  map_meta.map_name = "Unknown"
                                  map_meta.authors = "Unknown"
                                  map_meta.format = "Unsupported"
                                  map_meta.description = "No Description Found."
                                  map_meta.prefab_total = "None"
                                  map_meta.content = nil
                                end
                                if storage.maps[name] == nil then
                                  storage.maps[name] = {
                                    method = map_meta.method,
                                    status = "unloaded", -- unloaded, wait, loaded
                                    objects = {}
                                  }
                                end
                                return map_meta
                              end 
                            }
                          },
                          {"label",
                            {
                              text = function(meta_data)
                                return meta_data.map_name
                              end
                            }
                          },
                          {"label",
                            {
                              text = function(meta_data)

                                return "∟ Author: " .. meta_data.authors .. "\n" ..
                                       "∟ Format: " .. meta_data.format .. "\n" ..
                                       "∟ Objects: " .. meta_data.prefab_total
                              end
                            }
                          },
                          {"page",
                            {
                              text = "Map Description",
                              definition = {
                                {"label",
                                  {
                                    text = function(meta_data)
                                      local description = meta_data.description
                                      local last_space = 1
                                      for i = 1, #description do
                                        if description:sub(i, i) == " " then
                                          last_space = i
                                        end
                                        if i % 31 == 0 then
                                          description = description:sub(1, last_space) .. "\n" .. description:sub(last_space + 1)
                                        end
                                      end
                                      return description
                                    end
                                  }
                                }
                              }
                            }
                          },
                          {"label",
                            {
                              text = "--------------------------------------------------"
                            }
                          },
                          {"button",
                            {
                              text = function(meta_data)
                                local map = storage.maps[meta_data.name]
                                if map.method == "normal" then
                                  return "Load Method: Normal"
                                else
                                  return "Load Method: Chunks"
                                end
                              end,
                              callback = function(data, meta_data)
                                local map = storage.maps[meta_data.name]
                                local player_id = data.playerId
                                local id = data.id
                                if map.method == "normal" then
                                  map.method = "chunks"
                                  change_ui(player_id, id, "Load Method: Chunks")
                                else
                                  map.method = "normal"
                                  change_ui(player_id, id, "Load Method: Normal")
                                end
                              end
                            }
                          },
                          {"button",
                            {
                              text = function(meta_data)
                                local map_status = storage.maps[meta_data.name].status
                                if map_status == "unloaded" then
                                  return "Load Map"
                                elseif map_status == "wait" then
                                  return "Please Wait..."
                                else
                                  return "Unload Map"
                                end
                              end,
                              callback = function(data, meta_data)
                                local map = storage.maps[meta_data.name]
                                if map.status == "unloaded" then -- load map
                                  map.status = "wait"
                                  change_ui(data.playerId, data.id, "Loading... Please Wait")
                                  local format = meta_data.format
                                  local json_content = meta_data.content

                                  if map.method == "normal" then
                                    if format == "Trailmappers" then
                                      local prefabs = json_content["ObjectList"]
                                      local custom_assets = {
                                        objects = {},
                                        textures = {}
                                      }
                                      schedule_task(
                                        "critical",
                                        coroutine.create(
                                          function()
                                            for i, prefab in ipairs(prefabs) do
                                              local name = prefab.N
                                              local position = prefab.P
                                              position = new_vector3(position.x, position.y + 300, position.z)
                                              local rotation = prefab.R
                                              rotation = new_vector3(rotation.x, rotation.y, rotation.z)
                                              local scale = prefab.S
                                              scale = new_vector3(scale.x, scale.y, scale.z)
                                              local information = prefab.I

                                              -- this handles custom objects in Trailmapper files
                                              local game_object = nil
                                              if type(name) == "string" then
                                                game_object = tm_spawn_object(position, name)
                                              else
                                                local object = name[1]
                                                local texture = name[2]
                                                if table_contains(custom_assets.objects, object) == false then
                                                  tm.physics.AddMesh("data_static/maps/" .. meta_data.name .. "/assets/" .. object .. ".obj", object)
                                                end
                                                if texture ~= nil and table_contains(custom_assets.textures, texture) == false then
                                                  tm.physics.AddTexture("data_static/maps/" .. meta_data.name .. "/assets/" .. texture .. ".png", texture)
                                                end
                                                game_object = tm.physics.SpawnCustomObjectConcave(position, object, texture)
                                              end
                                              game_object.SetIsStatic(information.IsStatic)
                                              game_object.SetIsVisible(information.IsVisible)
                                              if information.CanCollide == false then
                                                game_object.SetIsTrigger(true)
                                              end

                                              local transform = game_object.GetTransform()
                                              transform.SetRotation(rotation)
                                              transform.SetScale(scale)
                                              table.insert(map.objects, game_object)
                                              if i % 25 == 0 then
                                                coroutine.yield()
                                              end
                                            end
                                            local spawnpoint = json_content["SpawnpointInfo"]
                                            local s_position = spawnpoint.P
                                            s_position = new_vector3(s_position.x, s_position.y + 300, s_position.z)
                                            local s_rotation = spawnpoint.R
                                            s_rotation = new_vector3(0, s_rotation.y, 0)
                                            for _, player in ipairs(tm.players.CurrentPlayers()) do
                                              local transform = tm.players.GetPlayerTransform(player.playerId)
                                              transform.SetPosition(s_position)
                                              transform.SetRotation(s_rotation)
                                            end
                                            map.status = "loaded"
                                            change_ui(data.playerId, data.id, "Unload Map")
                                          end
                                        )
                                      )        
                                    end
                                  end
                                elseif map.status == "loaded" then -- unload map
                                  map.status = "wait"
                                  change_ui(data.playerId, data.id, "Unloading... Please Wait")
                                  if map.method == "normal" then
                                    schedule_task(
                                      "critical",
                                      coroutine.create(
                                        function()
                                          for i, game_object in ipairs(map.objects) do
                                            game_object.Despawn()
                                            if i % 25 == 0 then
                                              coroutine.yield()
                                            end
                                          end
                                          map.objects = {}
                                          map.status = "unloaded"
                                          change_ui(data.playerId, data.id, "Load Map")
                                        end
                                      )
                                    )
                                  end
                                else
                                  change_ui(data.playerId, data.id, "Please Wait...")
                                end
                              end
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        {"page",
          {
            access = { 0 },
            text = "Map Editor",
            definition = {
              {"input",
                {
                  type = "text",
                  text = function()
                    local random_name = "map_" .. random_id(6)
                    storage.editor.map_name = random_name
                    return "Map Name: " .. random_name
                  end,
                  callback = function(data)
                    storage.editor.map_name = data.value
                  end
                }
              },
              {"page",
                {
                  text = "Create Map",
                  callback = function()
                    return {
                      name = storage.editor.map_name
                    }
                  end,
                  definition = map_editor
                }
              },
              {"label",
                {
                  text = "::::::::::::::::::::::::::::::::::::::::::::::::::\n" ..
                         "Saved Projects:                          "
                }
              },
              {"loop",
                {
                  callback = function()
                    local projects_list = {}
                    local projects = tm.os.ReadAllText_Dynamic("maps/projects/_")
                    for project in string.gmatch(projects, "[^\r\n]+") do
                      if project ~= "__empty" then
                        table.insert(projects_list,
                        {
                          name = project
                        }
                      )
                      end
                    end
                    
                    return projects_list
                  end,
                  definition = {
                    {"page",
                      {
                        text = |meta_data| meta_data.name,
                        callback = function(data, meta_data)
                          return {
                            name = meta_data.name
                          }
                        end,
                        definition = map_editor
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  },
  {"label",
    {
      access = { 1, 2, 3, 4, 5, 6, 7 },
      text = "This is a preview release.\nDo not share this menu."
    }
  },
  {"page",
    {
      access = { 0, 1, 2, 3, 4, 5, 6, 7 },
      text = "Licensing & Credits",
      definition = {
        {"label",
          {
            access = { 0, 1, 2, 3, 4, 5, 6, 7 },
            text = "Licensed under the:                      \n" ..
                  "∟GNU General Public License V3\n" ..
                  "∟ https://www.gnu.org/licenses    \n" ..
                  "::::::::::::::::::::::::::::::::::::::::::::::::::\n" ..
                  "Developed by lamersc                 \n" ..
                  "∟ https://lamersc.com                \n" ..
                  "∟ Find me in the Trailmakers      \n"..
                  "    discord server -> #modding.      \n" ..
                  "    https://lamersc.com/lgu\n" ..
                  "∟ Leave a review on steam!        \n" ..
                  "::::::::::::::::::::::::::::::::::::::::::::::::::\n" ..
                  "Thank you to:                              \n" ..
                  "∟ Madeline.Y.Scarlett & Azimuth\n" .. 
                  "    for their incredible support       \n" ..
                  "    and assistance throughout     \n" ..
                  "    development.                        \n" ..
                  "∟ Alexistyx for her mathematics \n" ..
                  "    and great attitude.                "
          }
        }
      }
    }
  }
}

tm.players.OnPlayerJoined.add(
  function(data)
    render_ui(definition, data.playerId)
  end
)