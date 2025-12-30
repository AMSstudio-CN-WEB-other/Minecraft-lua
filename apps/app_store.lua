-- App Store for CC:Tweaked / ComputerCraft (supports subdirectories)
-- Reads remote app list from GitHub and allows install/uninstall to local /apps
-- Remote index: /apps/index.txt where each line is a relative path under /apps
-- Example lines:
--   music_player.lua
--   games/dodge.lua
--   utils/something.lua

local REPO_USER = "Ace-2778"
local REPO_NAME = "Minecraft-lua"
local BRANCH    = "main"

local APPS_DIR  = "apps"
local INDEX_URL = ("https://raw.githubusercontent.com/%s/%s/%s/apps/index.txt")
  :format(REPO_USER, REPO_NAME, BRANCH)

local function remoteUrl(relPath)
  -- relPath is like "music_player.lua" or "games/dodge.lua"
  return ("https://raw.githubusercontent.com/%s/%s/%s/apps/%s")
    :format(REPO_USER, REPO_NAME, BRANCH, relPath)
end

-- Ensure apps dir exists
if not fs.exists(APPS_DIR) then fs.makeDir(APPS_DIR) end

-- ---------- Utilities ----------
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function readAll(path)
  local h = fs.open(path, "r")
  if not h then return nil end
  local t = h.readAll()
  h.close()
  return t
end

local function ensureParentDirs(path)
  local parent = fs.getDir(path)
  if parent and parent ~= "" and not fs.exists(parent) then
    fs.makeDir(parent)
  end
end

local function localPath(relPath)
  return fs.combine(APPS_DIR, relPath)
end

local function existsLocal(relPath)
  return fs.exists(localPath(relPath))
end

local function deleteLocal(relPath)
  local p = localPath(relPath)
  if fs.exists(p) then
    fs.delete(p)
    return true
  end
  return false
end

local function wgetToLocal(relPath)
  local url = remoteUrl(relPath)
  local dst = localPath(relPath)

  ensureParentDirs(dst)

  if fs.exists(dst) then fs.delete(dst) end
  local ok = shell.run("wget", url, dst)
  return ok
end

-- ---------- Fetch remote index ----------
local function fetchIndex()
  if http and http.get then
    local res = http.get(INDEX_URL)
    if res then
      local txt = res.readAll()
      res.close()
      return txt
    end
  end

  local tmp = ".app_index_tmp"
  if fs.exists(tmp) then fs.delete(tmp) end
  local ok = shell.run("wget", INDEX_URL, tmp)
  if not ok then return nil end
  local txt = readAll(tmp)
  fs.delete(tmp)
  return txt
end

local function parseIndex(txt)
  local list = {}
  for line in txt:gmatch("[^\r\n]+") do
    line = trim(line)
    if line ~= "" and not line:match("^#") then
      -- normalize: remove leading "apps/" if user accidentally puts it
      line = line:gsub("^apps/", "")
      table.insert(list, line)
    end
  end
  table.sort(list)
  return list
end

-- ---------- UI ----------
local w, h = term.getSize()

local function clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end

local function clear(bg)
  term.setBackgroundColor(bg or colors.black)
  term.clear()
  term.setCursorPos(1,1)
end

local function drawBox(x1,y1,x2,y2,bg)
  term.setBackgroundColor(bg or colors.gray)
  for y=y1,y2 do
    term.setCursorPos(x1,y)
    term.write(string.rep(" ", x2-x1+1))
  end
end

local function centerText(y, text, fg, bg)
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  local x = math.floor((w - #text)/2) + 1
  term.setCursorPos(x, y)
  term.write(text)
end

local function writeAt(x,y,text,fg,bg)
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.setCursorPos(x,y)
  term.write(text)
end

local function button(x,y,label,active)
  local bw = #label + 2
  term.setCursorPos(x,y)
  term.setBackgroundColor(active and colors.lime or colors.gray)
  term.setTextColor(colors.black)
  term.write(" "..label.." ")
  return bw
end

local function inside(px,py,x,y,bw,bh)
  return px>=x and px<x+bw and py>=y and py<y+bh
end

-- ---------- App store state ----------
local statusMsg = ""
local remoteApps = {}
local selected = 1
local scroll = 0

local listX1 = 2
local listY1 = 6
local listX2 = math.floor(w*0.62)
local listH  = h - 8
if listH < 5 then listH = 5 end

local rightX  = listX2 + 2

local function setStatus(msg)
  statusMsg = msg or ""
end

local function shortName(path)
  -- display only file name but keep path for install
  local name = path:match("([^/]+)$") or path
  return name
end

local function drawUI()
  clear(colors.black)

  -- Header
  drawBox(1,1,w,3,colors.blue)
  centerText(2,"🛒 App Store (GitHub) - Subdir Support",colors.white,colors.blue)

  writeAt(2,4,"Remote apps (from /apps/index.txt, supports subfolders)",colors.yellow,colors.black)

  drawBox(1,5,listX2+1,h-2,colors.black)

  local maxScroll = math.max(0, #remoteApps - listH)
  scroll = clamp(scroll, 0, maxScroll)

  for i=1,listH do
    local idx = i + scroll
    local y = listY1 + i - 1
    term.setCursorPos(listX1,y)

    local rel = remoteApps[idx] or ""
    local installed = rel ~= "" and existsLocal(rel)

    local lineW = (listX2 - listX1 + 1)

    local show = rel
    if #show > lineW - 12 then
      show = show:sub(1, lineW - 15) .. "..."
    end

    if idx == selected then
      term.setBackgroundColor(colors.gray)
      term.setTextColor(colors.black)
    else
      term.setBackgroundColor(colors.black)
      term.setTextColor(colors.white)
    end

    term.write(string.rep(" ", lineW))
    term.setCursorPos(listX1,y)

    if rel ~= "" then
      term.write(show)

      local tag = installed and "[Installed]" or "[Remote]"
      term.setCursorPos(listX2 - #tag + 1, y)
      term.setTextColor(installed and colors.lime or colors.lightGray)
      term.write(tag)
    end
  end

  -- Right panel
  drawBox(rightX,4,w,h-2,colors.black)

  local cur = remoteApps[selected]

  writeAt(rightX,5,"Selected:",colors.cyan,colors.black)
  writeAt(rightX,6,cur or "(none)",colors.white,colors.black)

  local installed = cur and existsLocal(cur)

  writeAt(rightX,8,"Actions:",colors.cyan,colors.black)

  local bx = rightX
  local by = 10

  local labelInstall = installed and "Uninstall" or "Install"
  button(bx,by,labelInstall,true)
  button(bx,by+2,"Run",cur and installed)
  button(bx,by+4,"Refresh",true)

  writeAt(rightX,by+6,"Notes:",colors.cyan,colors.black)
  writeAt(rightX,by+7,"- Click list to select",colors.lightGray,colors.black)
  writeAt(rightX,by+8,"- Mouse wheel scroll",colors.lightGray,colors.black)
  writeAt(rightX,by+9,"- Enter runs selected",colors.lightGray,colors.black)

  -- Footer
  drawBox(1,h-1,w,h-1,colors.gray)
  writeAt(2,h-1,statusMsg,colors.black,colors.gray)
  writeAt(w-20,h-1,"Q:Quit  Enter:Run",colors.black,colors.gray)
end

local function refreshRemote()
  setStatus("Fetching app index...")
  drawUI()

  local txt = fetchIndex()
  if not txt then
    remoteApps = {}
    selected = 1
    scroll = 0
    setStatus("ERROR: Unable to fetch index. Is HTTP enabled?")
    return
  end

  remoteApps = parseIndex(txt)
  if #remoteApps == 0 then
    setStatus("No apps found in index.txt")
  else
    setStatus("Loaded "..#remoteApps.." app(s).")
  end
  selected = clamp(selected,1,math.max(1,#remoteApps))
  scroll = 0
end

local function doInstallOrUninstall()
  local app = remoteApps[selected]
  if not app then return end

  if existsLocal(app) then
    setStatus("Uninstalling "..app.." ...")
    drawUI()
    deleteLocal(app)
    setStatus("Uninstalled: "..app)
  else
    setStatus("Installing "..app.." ...")
    drawUI()
    local ok = wgetToLocal(app)
    if ok then
      setStatus("Installed: "..app)
    else
      setStatus("ERROR: Install failed (wget).")
    end
  end
end

local function runSelected()
  local app = remoteApps[selected]
  if not app then return end
  if not existsLocal(app) then
    setStatus("Install it first.")
    return
  end

  local path = localPath(app)
  setStatus("Running "..app.." ... (Ctrl+T to stop)")
  drawUI()

  shell.run(path)
  setStatus("Returned from "..app)
end

-- ---------- Start ----------
if not http then
  error("HTTP is disabled. Enable it in CC:Tweaked config to use App Store.")
end

refreshRemote()

while true do
  drawUI()
  local e = { os.pullEvent() }
  local ev = e[1]

  if ev == "term_resize" then
    w,h = term.getSize()
    listX2 = math.floor(w*0.62)
    listH = h - 8
    if listH < 5 then listH = 5 end
    rightX = listX2 + 2

  elseif ev == "mouse_scroll" then
    scroll = scroll + e[2]

  elseif ev == "mouse_click" then
    local x, y = e[3], e[4]

    -- click list
    if x >= listX1 and x <= listX2 and y >= listY1 and y < listY1 + listH then
      local idx = (y - listY1 + 1) + scroll
      if remoteApps[idx] then selected = idx end
    end

    -- buttons
    local bx = rightX
    local by = 10
    local cur = remoteApps[selected]
    local installed = cur and existsLocal(cur)

    local installW = (installed and #"Uninstall" or #"Install") + 2
    if inside(x,y,bx,by,installW,1) then
      doInstallOrUninstall()
    end

    local runW = #"Run" + 2
    if inside(x,y,bx,by+2,runW,1) then
      if cur and installed then runSelected() else setStatus("Install it first.") end
    end

    local refreshW = #"Refresh" + 2
    if inside(x,y,bx,by+4,refreshW,1) then
      refreshRemote()
    end

  elseif ev == "key" then
    local k = e[2]
    if k == keys.q then
      clear(colors.black)
      break
    elseif k == keys.up then
      selected = clamp(selected - 1, 1, #remoteApps)
      if selected < scroll + 1 then scroll = scroll - 1 end
    elseif k == keys.down then
      selected = clamp(selected + 1, 1, #remoteApps)
      if selected > scroll + listH then scroll = scroll + 1 end
    elseif k == keys.enter then
      runSelected()
    end
  end
end
