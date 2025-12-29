-- /system/desktop.lua
-- CCT Desktop (stable, folder browsing, mouse control, no unicode, graceful terminate)

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)

local w, h = term.getSize()
local listTop = 4
local listBottom = h - 2
local visible = listBottom - listTop + 1

local current = "/apps"
local scroll, selected = 0, 1

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function isLua(name) return name:match("%.lua$") ~= nil end

local function getEntries(path)
  if not fs.exists(path) then fs.makeDir(path) end

  local items = fs.list(path)
  local dirs, apps = {}, {}

  for _, it in ipairs(items) do
    local full = fs.combine(path, it)
    if fs.isDir(full) then
      table.insert(dirs, {kind="dir", name=it, full=full})
    elseif isLua(it) then
      table.insert(apps, {kind="lua", name=it:gsub("%.lua$", ""), full=full})
    end
  end

  table.sort(dirs, function(a,b) return a.name:lower() < b.name:lower() end)
  table.sort(apps, function(a,b) return a.name:lower() < b.name:lower() end)

  local out = {}
  for _, d in ipairs(dirs) do table.insert(out, d) end
  for _, a in ipairs(apps) do table.insert(out, a) end
  return out
end

local function clear()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
end

local function drawHeader(count)
  term.setBackgroundColor(colors.blue)
  term.setTextColor(colors.white)
  term.setCursorPos(1,1)
  term.write(string.rep(" ", w))

  term.setCursorPos(2,1)
  term.write("[Back]")

  term.setCursorPos(10,1)
  term.write("CCT Desktop")

  term.setCursorPos(22,1)
  term.write(current)

  local exitLabel = "[Exit]"
  term.setCursorPos(w - #exitLabel - 1, 1)
  term.write(exitLabel)

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.lightGray)
  term.setCursorPos(1,2)
  term.write(string.rep(" ", w))
  term.setCursorPos(2,2)
  term.write("Click folder to enter | Click app to run | Scroll | Q quit")
end

local function drawFooter()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.lightGray)
  term.setCursorPos(1,h)
  term.write(string.rep(" ", w))
  term.setCursorPos(2,h)
  term.write("Up/Down select | Enter run | Backspace up")
end

local function drawList(entries)
  term.setBackgroundColor(colors.gray)
  for y=3,h-1 do
    term.setCursorPos(1,y)
    term.write(string.rep(" ", w))
  end

  term.setBackgroundColor(colors.gray)
  term.setTextColor(colors.black)
  term.setCursorPos(2,3)
  term.write("Folders & Apps")

  for i=1,visible do
    local idx = i + scroll
    local y = listTop + i - 1

    term.setCursorPos(2,y)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.write(string.rep(" ", w-2))

    if idx <= #entries then
      local e = entries[idx]
      local label

      if e.kind == "dir" then
        label = "[DIR] " .. e.name
        term.setTextColor(colors.yellow)
      else
        label = "[APP] " .. e.name
        term.setTextColor(colors.lime)
      end

      if idx == selected then
        term.setBackgroundColor(colors.lightBlue)
        term.setTextColor(colors.black)
      else
        term.setBackgroundColor(colors.gray)
      end

      if #label > w-3 then label = label:sub(1, w-6) .. "..." end
      term.setCursorPos(2,y)
      term.write(label)
    end
  end
end

local function redraw(entries)
  clear()
  drawHeader(#entries)
  drawList(entries)
  drawFooter()
end

local function goUp()
  if current == "/apps" then return end
  local parent = fs.getDir(current)
  if parent == "" then parent = "/apps" end
  current = parent
  scroll, selected = 0, 1
end

local function runEntry(entry)
  if entry.kind == "dir" then
    current = entry.full
    scroll, selected = 0, 1
    return
  end

  -- run lua app
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1,1)

  if multishell and multishell.launch then
    multishell.launch({}, entry.full)
  else
    shell.run(entry.full)
  end
end

local function backClicked(x,y)
  return y == 1 and x >= 2 and x <= 7  -- [Back]
end

local function exitClicked(x,y)
  local label = "[Exit]"
  local x1 = w - #label - 1
  local x2 = w - 1
  return y == 1 and x >= x1 and x <= x2
end

-- MAIN LOOP
if not fs.exists("/apps") then fs.makeDir("/apps") end

local running = true
while running do
  local entries = getEntries(current)
  selected = clamp(selected, 1, math.max(1, #entries))
  scroll = clamp(scroll, 0, math.max(0, #entries - visible))

  redraw(entries)

  -- IMPORTANT: use pullEventRaw so terminate does not auto-error (no red "Terminated")
  local ev, a, b, c = os.pullEventRaw()

  if ev == "terminate" then
    -- graceful exit
    break
  end

  if ev == "mouse_scroll" then
    local dir = a
    if dir == 1 then
      scroll = clamp(scroll + 1, 0, math.max(0, #entries - visible))
    else
      scroll = clamp(scroll - 1, 0, math.max(0, #entries - visible))
    end

  elseif ev == "mouse_click" then
    local btn, x, y = a, b, c

    if exitClicked(x,y) then
      running = false

    elseif backClicked(x,y) then
      goUp()

    elseif y >= listTop and y <= listBottom then
      local idx = scroll + (y - listTop + 1)
      if idx >= 1 and idx <= #entries then
        selected = idx
        if btn == 1 then
          runEntry(entries[selected])
        end
      end
    end

  elseif ev == "key" then
    local key = a

    if key == keys.q then
      running = false

    elseif key == keys.up then
      selected = clamp(selected - 1, 1, math.max(1, #entries))
      if selected < scroll + 1 then scroll = selected - 1 end

    elseif key == keys.down then
      selected = clamp(selected + 1, 1, math.max(1, #entries))
      if selected > scroll + visible then scroll = selected - visible end

    elseif key == keys.enter then
      if #entries > 0 then
        runEntry(entries[selected])
      end

    elseif key == keys.backspace then
      goUp()
    end
  end
end

-- Clean exit (important)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1,1)
