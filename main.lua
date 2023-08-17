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


-- user interface framework for Trailmakers
function render_ui(definition, player_id)
  local meta_data = {
    _ = {
      player_id = player_id
    }
  }
  if definition.meta ~= nil then
    for key, value in pairs(definition.meta) do
      meta_data[key] = value
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
    if type(parameters.text) == "function" then
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
        local default_input = parameters.text
        local colon_character = default_input:find(":")
        if colon_character ~= nil then
          field_title = default_input:sub(1, colon_character) .. " "
        end
        local callback = parameters.callback
        if input_type == "text" then
          new_input(
            player_id,
            parameters.id or random_id(8),
            parameters.text or "",
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
          new_input(
            player_id,
            parameters.id or random_id(8),
            parameters.text .. "  (←←←←|→→→→)",
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
  
                local left_length = #arrows[1]
                local right_length = #arrows[2]
                if right_length > 4 or 4 > right_length then
                  number = number + 1
                elseif left_length > 4 or 4 > left_length then
                  number = number - 1
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
            local left_length = arrow_state:match("(.*)%(")
            if left_length == nil then left_length = 6 else left_length = #left_length end
            local right_length = arrow_state:match("%)(.*)")
            if right_length == nil then right_length = 6 else right_length = #right_length end
  
            if right_length > left_length or left_length > right_length then
              page = page + right_length - left_length
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
        ui_call(
          player_id,
          parameters.id or random_id(8),
          parameters.text,
          function(data)
            clear_ui(player_id)
            local previous_definition = parameters.previous or table_shallowcopy(definition) -- protects original definition
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
                  callback = function()
                    clear_ui(player_id)
                    for i, element in ipairs(definition_copy) do
                      if element[1] == "event" then
                        if element[2].type == "unload" then
                          element[2].callback()
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
      elseif name == "loop" then
        local loop_array = parameters.callback(meta_data)

        for i, value in ipairs(loop_array) do
          local definition_copy = table_shallowcopy(parameters.definition or {})
          definition_copy.meta = value
          for _, element in ipairs(definition_copy) do
            if element[1] == "page" then
              element[2].previous = definition
            end
          end
          render_ui(definition_copy, player_id)
        end

      elseif name == "conditional" then
        if parameters.callback(meta_data) == true then
          parameters.definition.meta = meta_data
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
  table.insert(prefab_search_results, prefab:sub(5, -1))
end

local storage = {
  maps = {},
  editor = {
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
  local object_storage = storage.editor.objects
  local name = data.name
  local grouping = data.group

  local lookup_value = storage.editor.objects
  if grouping ~= "" then
    for group in string.gmatch(grouping, '([^%/]+)') do
      if lookup_value[group] == nil then
        lookup_value[group] = {}
      end
      lookup_value = lookup_value[group]
    end
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
    gameobj.SetIsTrigger(true)
    lookup_value[name] = {
      object = gameobj,
      id = "PFB_" .. data.object,
      transform = gameobj.GetTransform()
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

_G.map_editor_object_component = {
  {"conditional",
    {
      callback = function(meta_data)
        return meta_data.type == nil

      end,
      definition = {
        {"label",
          {
            text = "::::::::::::::::::Top Level::::::::::::::::::"
          }
        }
      }
    }
  },
  {"conditional",
    {
      callback = function(meta_data)
        return meta_data.type == "group"
      end,
      definition = {
        {"label",
          {
            text = "::::::::::::Group Information::::::::::::"
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
        {"label",
          {
            text = ":::::::Inner Groups & Objects::::::::"
          }
        }
      }
    }
  },
  {"conditional",
    {
      callback = function(meta_data)
        return meta_data.type == "object"
      end,
      definition = {
        {"label",
          {
            text = ":::::::::::Object Information::::::::::::"
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
        {"label",
          {
            text = "Position:"
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "x: " .. math.floor(meta_data.reference[meta_data.name].transform.GetPosition().x * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.reference[meta_data.name].transform
              local current_position = transform.GetPosition()
              meta_data.reference[meta_data.name].transform.SetPosition(value, current_position.y, current_position.z)
            end
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "y: " .. math.floor(meta_data.reference[meta_data.name].transform.GetPosition().y * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.reference[meta_data.name].transform
              local current_position = transform.GetPosition()
              meta_data.reference[meta_data.name].transform.SetPosition(current_position.x, value, current_position.z)
            end
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "z: " .. math.floor(meta_data.reference[meta_data.name].transform.GetPosition().z * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.reference[meta_data.name].transform
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
            text = |meta_data| "x: " .. math.floor(meta_data.reference[meta_data.name].transform.GetRotation().x * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.reference[meta_data.name].transform
              local current_rotation = transform.GetRotation()
              meta_data.reference[meta_data.name].transform.SetRotation(value, current_rotation.y, current_rotation.z)
            end
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "y: " .. math.floor(meta_data.reference[meta_data.name].transform.GetRotation().y * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.reference[meta_data.name].transform
              local current_rotation = transform.GetRotation()
              meta_data.reference[meta_data.name].transform.SetRotation(current_rotation.x, value, current_rotation.z)
            end
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "z: " .. math.floor(meta_data.reference[meta_data.name].transform.GetRotation().z * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.reference[meta_data.name].transform
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
            text = |meta_data| "x: " .. math.floor(meta_data.reference[meta_data.name].transform.GetScale().x * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.reference[meta_data.name].transform
              local current_scale = transform.GetScale()
              meta_data.reference[meta_data.name].transform.SetScale(value, current_scale.y, current_scale.z)
            end
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "y: " .. math.floor(meta_data.reference[meta_data.name].transform.GetScale().y * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.reference[meta_data.name].transform
              local current_scale = transform.GetScale()
              meta_data.reference[meta_data.name].transform.SetScale(current_scale.x, value, current_scale.z)
            end
          }
        },
        {"input",
          {
            type = "number",
            text = |meta_data| "z: " .. math.floor(meta_data.reference[meta_data.name].transform.GetScale().z * 1000) / 1000,
            callback = function(data, meta_data)
              local value = math.floor(data.value * 1000) / 1000
              local transform = meta_data.reference[meta_data.name].transform
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
                change_ui(0, data.id, "are you sure?")
                local current_time = get_time() + 1
                schedule_task(
                  "ordered",
                  coroutine.create(
                    function()
                      while current_time > get_time() do
                        coroutine.yield()
                      end
                      change_ui(0, data.id, "Delete Object")
                    end
                  )
                )
              else
                meta_data.reference[meta_data.name].object.Despawn()
                meta_data.reference[meta_data.name] = nil
                clear_ui(0)
                render_ui(meta_data["_"].previous_definition, meta_data["_"].player_id)
              end
            end
          }
        }
      }
    }
  },
  {"loop",
    {
      callback = function(meta_data)
        if meta_data.type == "object" then
          return {}
        end
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
              local definition_copy = table_shallowcopy(map_editor_object_component)
              definition_copy.meta = meta_data
              return map_editor_object_component
            end
          }
        }
      }
    }
  }
}
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
        print("loaded.")
        -- initiate the editor system
        local transform = tm.players.GetPlayerTransform(0)

        local current_time = get_time()
        local select_delay = 0.25
        local select_interval = current_time + select_delay
        local spawn_delay = 0.25
        local spawn_interval = current_time + spawn_delay
        local editor = storage.editor
        editor.enabled = true
        schedule_task("critical",
          coroutine.create(
            function()
              while editor.enabled == true do
                
                coroutine.yield()
              end
            end
          )
        )

        local name = meta_data.name

      end
    }
  },
  {"event",
    {
      type = "unload",
      callback = function()
        storage.editor.enabled = false
        print("unloaded.")
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
      text = "::::::::::::Object Attributes:::::::::::::"
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
  {"label",
    {
      text = "::::::::::::Available Objects::::::::::::"
    }
  },
  {"search",
    {
      configuration = storage.editor.search_config,
      callback = function(response)
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
                update_editor_message("[√]: " .. name .. "=(" .. object_name .. ") " .. " has been added.", 5)
              end
            else
              update_editor_message("[√]: " .. name .. "=(" .. object_name .. ") " .. " has been added.", 5)
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
      text = "Modify Groupings & Objects",
      definition = map_editor_object_component
    }
  },
  {"label",
    {
      text = ":::::::::::::::::::Settings:::::::::::::::::::"
    }
  },
  {"page",
    {
      text = "Map Configuration"
    }
  },
  {"page",
    {
      text = "Export Map"
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
              {"event",
                {
                  type = "load",
                  callback = function()
                    storage.editor.map_name = "map_" .. random_id(6)
                  end
                }
              },
              {"input",
                {
                  type = "text",
                  text = function()
                    return "Map Name: " .. storage.editor.map_name
                  end,
                  callback = function(data)
                    storage.editor.map_name = data.value
                  end
                }
              },
              {"page",
                {
                  access = { 0 },
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