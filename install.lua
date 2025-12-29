-- install.lua (HTTP version, no wget flags)
local BASE = "https://raw.githubusercontent.com/AMSstudio-CN-WEB-other/Minecraft-lua/main/"

local function download(remotePath, localPath)
  local url = BASE .. remotePath
  print("GET " .. url)

  local res, err = http.get(url)
  if not res then
    error("HTTP failed: " .. tostring(err))
  end

  local data = res.readAll()
  res.close()

  if not data or #data == 0 then
    error("Empty file from: " .. url)
  end

  -- ensure folder exists
  local dir = fs.getDir(localPath)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end

  if fs.exists(localPath) then fs.delete(localPath) end
  local f = fs.open(localPath, "w")
  f.write(data)
  f.close()

  print("Saved -> " .. localPath)
end

print("== Installing CCT Desktop ==")

if not fs.exists("/apps") then fs.makeDir("/apps") end
if not fs.exists("/system") then fs.makeDir("/system") end

download("system/desktop.lua", "/system/desktop.lua")

-- startup
local s = fs.open("/startup.lua", "w")
s.write([[shell.run("/system/desktop.lua")]])
s.close()

print("Done! Rebooting is recommended.")
print("You can run now: lua /system/desktop.lua")
