-- install.lua
-- Installer for CCT Desktop System
local base = "https://raw.githubusercontent.com/AMSstudio-CN-WEB-other/Minecraft-lua/main/"

local function fetch(remotePath, savePath)
  if fs.exists(savePath) then fs.delete(savePath) end
  local url = base .. remotePath
  print("Downloading: " .. url)
  shell.run("wget", "-f", url, savePath)
  if not fs.exists(savePath) then
    error("Failed to download: " .. remotePath)
  end
end

print("== Installing CCT Desktop System ==")

if not fs.exists("/system") then fs.makeDir("/system") end
if not fs.exists("/apps") then fs.makeDir("/apps") end

fetch("system/desktop.lua", "/system/desktop.lua")

-- Write startup.lua to auto boot into desktop
local f = fs.open("/startup.lua", "w")
f.write([[shell.run("/system/desktop.lua")]])
f.close()

print("Done!")
print("Desktop installed at /system/desktop.lua")
print("Reboot to start automatically, or run: lua /system/desktop.lua")
