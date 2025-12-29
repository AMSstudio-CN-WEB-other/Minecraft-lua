-- /system/desktop.lua
-- Desktop as base layer + Apps as "windows" using multishell tabs
-- Features: folder browser, launch app in new tab, taskbar, switch/close apps.

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)

local w, h = term.getSize()
local listTop = 4
local listBottom = h - 3
local visible = listBottom - listTop + 1

local current = "/apps"
local scroll, selected = 0, 1

local desktopTab = (multishell and multishell.getCurrent and multishell.getCurrent()) or nil

local function clamp(v,a,b) return math.max(a, math.min(b,v)) end
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
      table.insert(apps, {kind="lua", name=it:gsub("%.lua$",""), full=full})
    end
  end

  table.sort(dirs, function(a,b) return a.name:lower() < b.name:lower() end)
  table.sort(apps, function(a,b) return a.name:lower() < b.name:lower() end)

  local out = {}
  for _,d in ipairs(dirs) do table.insert(out,d) end
  for _,a in ipairs(apps) do table.insert(out,a) end
  return out
end

local function clear()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
end

-- Get running app tabs (exclude desktop tab)
local function getRunningTabs()
  if not multishell then return {} end
  local tabs = {}
  local count = multishell.getCount()

  for i = 1, count do
    local id = i

    -- Some versions have getTab(i). If not, tab id == i.
    if multishell.getTab then
      local ok, val = pcall(multishell.getTab, i)
      if ok and val then id = val end
    end

    if id ~= desktopTab then
      local title = "Tab " .. tostring(id)
      if multishell.getTitle then
        local ok2, t = pcall(multishell.getTitle, id)
        if ok2 and t and #t > 0 then title = t end
      end
      table.insert(tabs, {id = id, title = title})
    end
  end

  return tabs
end

local function drawHeader(countEntries)
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
  term.write("Apps open in new tabs (windows). Taskbar below. Click tab to focus, X to close.")
end

local function drawList(entries)
  term.setBackgroundColor(colors.gray)
  for y=3,h-2 do
    term.setCursorPos(1,y)
    term.write(string.rep(" ", w))
  end

  term.setBackgroundColor(colors.gray)
  term.setTextColor(colors.black)
  term.setCursorPos(2,3)
  term.write("Folders & Apps (click to open)")

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

      if #label > w-3 then label = label:sub(1, w-6).."..." end
      term.setCursorPos(2,y)
      term.write(label)
    end
  end
end

-- Draw taskbar: [tabname x] [tabname x] ...
-- Return clickable regions: {x1,x2, closeX1,closeX2, id}
local function drawTaskbar(tabs)
  term.setCursorPos(1,h-1)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.write(string.rep(" ", w))

  term.setCursorPos(2,h-1)
  term.setTextColor(colors.cyan)
  term.write("Taskbar: ")

  local regions = {}
  local x = 11
  for _, t in ipairs(tabs) do
    local name = t.title
    if #name > 10 then name = name:sub(1,9).."…" end

    local block = "["..name.." x]"
    if x + #block >= w then break end

    term.setCursorPos(x, h-1)
    term.setTextColor(colors.white)
    term.write("[")

    term.setTextColor(colors.yellow)
    term.write(name)

    term.setTextColor(colors.red)
    term.write(" x")

    term.setTextColor(colors.white)
    term.write("]")

    table.insert(regions, {
      id = t.id,
      x1 = x,
      x2 = x + #block - 1,
      closeX1 = x + #block - 2,  -- the 'x' position (approx)
      closeX2 = x + #block - 2
    })

    x = x + #block + 1
  end

  -- footer line
  term.setCursorPos(1,h)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.lightGray)
  term.write(string.rep(" ", w))
  term.setCursorPos(2,h)
  term.write("Scroll list | Backspace up | Q exit desktop | Tabs keep running independently")
  return regions
end

local function redraw(entries, tabs)
  clear()
  drawHeader(#entries)
  drawList(entries)
  local regions = drawTaskbar(tabs)
  return regions
end

local function goUp()
  if current == "/apps" then return end
  local parent = fs.getDir(current)
  if parent == "" then parent = "/apps" end
  current = parent
  scroll, selected = 0, 1
end

local function backClicked(x,y)
  return y == 1 and x >= 2 and x <= 7
end

local function exitClicked(x,y)
  local label = "[Exit]"
  local x1 = w - #label - 1
  local x2 = w - 1
  return y == 1 and x >= x1 and x <= x2
end

local function runEntry(entry)
  if entry.kind == "dir" then
    current = entry.full
    scroll, selected = 0, 1
    return
  end

  -- Launch app as a "window"
  if multishell and multishell.launch then
    local id = multishell.launch({}, entry.full)
    if id and multishell.setFocus then
      multishell.setFocus(id) -- bring window to front
    end
  else
    -- Fallback: single-task mode
    shell.run(entry.full)
  end
end

-- MAIN LOOP
if not fs.exists("/apps") then fs.makeDir("/apps") end

local running = true
while running do
  local entries = getEntries(current)
  selected = clamp(selected, 1, math.max(1, #entries))
  scroll = clamp(scroll, 0, math.max(0, #entries - visible))

  local tabs = getRunningTabs()
  local regions = redraw(entries, tabs)

  local ev, a, b, c = os.pullEventRaw()
  if ev == "terminate" then
    -- Desktop should be "system layer": don't crash with red text.
    -- We just exit gracefully.
    break
  end

  if ev == "mouse_scroll" then
    local dir = a
    if dir == 1 then
      scroll = clamp(scroll+1, 0, math.max(0, #entries - visible))
    else
      scroll = clamp(scroll-1, 0, math.max(0, #entries - visible))
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

    elseif y == h-1 then
      -- taskbar click
      for _, r in ipairs(regions) do
        if x >= r.x1 and x <= r.x2 then
          if x >= r.closeX1 and x <= r.closeX2 then
            -- close window
            if multishell and multishell.terminate then
              multishell.terminate(r.id)
            end
          else
            -- focus window
            if multishell and multishell.setFocus then
              multishell.setFocus(r.id)
            end
          end
          break
        end
      end
    end

  elseif ev == "key" then
    local key = a

    if key == keys.q then
      running = false

    elseif key == keys.up then
      selected = clamp(selected-1, 1, math.max(1, #entries))
      if selected < scroll+1 then scroll = selected-1 end

    elseif key == keys.down then
      selected = clamp(selected+1, 1, math.max(1, #entries))
      if selected > scroll+visible then scroll = selected-visible end

    elseif key == keys.enter then
      if #entries > 0 then runEntry(entries[selected]) end

    elseif key == keys.backspace then
      goUp()
    end
  end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1,1)
