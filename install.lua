-- install.lua
local user = "mettemfurfur000"
local repo = "tempackage"
local branch = "main"
local filelist_name = "src_files.lua"

local program_name = "tempackage"
local source = "https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/" .. branch .. "/"

local files = {}
local destpath = "./" .. program_name .. ".d"

-- require http/fs/parallel availability
if not http then error("HTTP API not available", 0) end
if not fs then error("FS API not available", 0) end

-- fetch the file list (expects src_files.lua to return a table of relative paths)
local req, err = http.get(source .. filelist_name)
if not req then error("Failed to download file list: " .. (err or "unknown"), 0) end
local list_text = req.readAll()
req.close()

local loader, load_err = load(list_text, "=" .. filelist_name)
if not loader then error("Failed to load file list: " .. load_err, 0) end
local ok, result = pcall(loader)
if not ok then error("Error executing file list: " .. result, 0) end
if type(result) ~= "table" then error("File list must return a table of paths", 0) end
files = result

-- ensure destination dirs exist
fs.makeDir(destpath)
fs.makeDir(destpath .. "/src")

-- create download tasks
local tasks = {}
for i, path in ipairs(files) do
    tasks[i] = function()
        local url = source .. path
        local r, e = http.get(url)
        if not r then error("Failed to download " .. path .. ": " .. (e or "unknown"), 0) end
        local data = r.readAll()
        r.close()

        local dir = string.match(path, "(.*/)")
        if dir then fs.makeDir(destpath .. "/src/" .. dir) end

        local f = fs.open(destpath .. "/src/" .. path, "w")
        f.write(data)
        f.close()
    end
end

if #tasks > 0 then
    parallel.waitForAll(table.unpack(tasks))
else
    print("No files to download")
end

-- write launcher
local launcher = io.open(program_name .. ".lua", "w")
launcher:write('shell.run("' .. program_name .. '/src/launch.lua")')
launcher:close()

print("success")
