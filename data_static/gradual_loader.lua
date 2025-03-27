local table_insert = table.insert
local coroutine_yield = coroutine.yield
local coroutine_resume = coroutine.resume
local new_vector3 = tm.vector3.Create
local new_gameobj = tm.physics.SpawnObject
local map = json.parse(tm.os.ReadAllText_Static("map"))
local lookup_table = {}
local gameobjs = {}
for _, v in pairs(map) do
  table.insert(lookup_table, v)
end
local i = 1
while #lookup_table >= i do
  local v = lookup_table[i]
  if v.prefab ~= nil then
    local pos = v.position
    local rot = v.rotation
    local scale = v.scale
    v.position = new_vector3(pos[1], pos[2], pos[3])
    v.rotation = new_vector3(rot[1], rot[2], rot[3])
    v.scale = new_vector3(scale[1], scale[2], scale[3])
    table.insert(gameobjs, v)
  else
    for _, v2 in pairs(v) do
      table.insert(lookup_table, v2)
    end
  end
  i = i + 1
end
local loader = coroutine.create(
  function()
    for i, gameobj in ipairs(gameobjs) do
      local _gameobj = new_gameobj(gameobj.position, gameobj.prefab)
      local attributes = _gameobj.attributes
      _gameobj.SetIsStatic(attributes[1])
      _gameobj.SetIsVisible(attributes[2])
      _gameobj.SetIsTrigger(attributes[3])
      local transform = _gameobj.GetTransform()
      transform.SetRotation(gameobj.rotation)
      transform.SetScale(gameobj.scale)
      if i % 25 == 0 then
        coroutine_yield()
      end
    end
    _G["update"] = nil
  end
)
function update()
  coroutine_resume(loader)
end