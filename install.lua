-- install.lua (run this on a CC:Tweaked computer)
local repo = "https://raw.githubusercontent.com/AMSstudio-CN-WEB-other/Minecraft-lua/main/"

local function fetch(path, saveAs)
  if fs.exists(saveAs) then fs.delete(saveAs) end
  local url = repo .. path
  print("Downloading: " .. url)
  local ok, err = pcall(function()
    shell.run("wget", url, saveAs)
  end)
  if not ok then error(err) end
end

print("== Installing Desktop System ==")
if not fs.exists("/system") then fs.makeDir("/system") end
if not fs.exists("/apps") then fs.makeDir("/apps") end

fetch("system/desktop.lua", "/system/desktop.lua")

-- Optional: startup
local startup = [[shell.run("/system/desktop.lua")]]
local f = fs.open("/startup.lua", "w")
f.write(startup)
f.close()

print("Done!")
print("Run: /system/desktop.lua")
