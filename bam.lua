-- BAM: The Big Article Machine
-- (c) 2011, Stefano Meschiari
--
-- MIT licenced; see http://www.opensource.org/licenses/mit-license.php

local _open = io.open
local _dofile = dofile

bam = {}
bam.version = "0.1"
bam.inject = true
bam.cache = false
bam.nformat = "%.2f"
bam.words = {}
bam.words["and"] = "and"
bam.langs = { 'lua', 'R' }
bam.lang = 'lua'

bam.interp_filters = {}
bam.line_filters = {}

-----------------------------------------------------------------------------
-- define utility functions & variables


-- String buffer class
local mt_buffer
mt_buffer = { 
   append = function(buf, ...)
      local arg = {...}
      for i = 1, #arg do
         buf[#buf+1] = arg[i]
      end
      return buf
   end,
   appendn = function(buf, ...)
      local arg = {...}
      for i = 1, #arg do
         if arg[i] then
            buf[#buf+1] = arg[i]
         end
      end
      if #arg > 1 or arg[1] then
         buf[#buf+1] = "\n"		
      end
      return buf
   end,
   prepend = function(buf, ...)
      local arg = {...}
      for i = #arg, 1 do
         table.insert(buf, 1, arg[i])
      end
      return buf
   end,
   rep = function(buf, str, n)
      for i = 1, n do
         buf[#buf+1] = str
      end
      return buf
   end,
   appendf = function(buf, fmt, ...)
      return buf:append(string.format(fmt, ...))
   end,
   prependf = function(buf, fmt, ...)
      return buf:prepend(string.format(fmt, ...))
   end,
   clear = function(buf)
      for i = 1, #buf do buf[i] = nil end
   end,
   tostring = function(buf, sep)
      return table.concat(buf, sep)
   end,
   getn = function(buf, n)
      return buf[n]
   end,
   count = function(buf)
      return #buf
   end
}
mt_buffer.__index = mt_buffer

-- Create new string buffer
function buffer()
   local buf = {}
   setmetatable(buf, mt_buffer)
   return buf
end

sprintf = string.format

-- Return true if fn exists
function exists(fn)
   local fid = _open(fn, "r")
   if fid then
      fid:close()
      return true
   else
      return false
   end
end

-- Executes command and returns its output
function exec(cmd)
   local pipe = io.popen(cmd, "r")
   if pipe then
      local out = pipe:read("*a")
      pipe:close()
      return out
   end
end

-- Executes command; builds command from fmt (using string.format rules)
function execf(fmt, ...)
   return exec(string.format(fmt, ...))
end

-- Returns a table containing the output of ls
-- Example: ls("*.txt", "results/*.txt")
function ls(...)
   local dirs = {...}
   if #dirs == 0 then
      dirs = {""}
   end
   local l = {}

   for _, dir in ipairs(dirs) do
      local pipe = io.popen("ls " .. (dir or ""), "r")
      if pipe then
         for line in pipe:lines() do
            l[#l+1] = line
         end
         pipe:close()
      end
   end

   return l
end

-- Creates a new empty file 
function empty(name)
   local fid = io.open(name, "w")
   if fid then fid:close() else error("Could not create file " .. name) end
end

-- Identity function
function ident(f)
   return f
end

-- f is shorthand for string.format
f = string.format

-- Returns the content of the file as a string
function readf(fn)
   local fid = io.open(fn)
   if fid then
      local str = fid:read("*a")
      fid:close()
      return str
   end	
end

-- Returns an array containing the contents of the file split by newlines
function reada(fn)
   local fid = io.open(fn)
   
   if not fid then return end
   local tbl = {}
   tbl[#tbl+1] = fid:read("*n")
   while tbl[#tbl] do
      tbl[#tbl+1] = fid:read("*n")
   end
   fid:close()
   return tbl
end

-- Reads an ASCII table (containing numbers only), where each row is separated by a newline
-- and each column is separated by whitespace (spaces or tabs). Returns a table, where each
-- item (row) is a table of values
function readm(fn)
   
   local fid
   if type(fn) == "userdata" then
      fid = fn
   else
      fid = io.open(fn)
   end
   if not fid then return end
   
   local tbl = {}
   for l in fid:lines() do
      l = l:trim()
      if l:sub(1, 1) ~= "#" then
         local row = {}
         for num in l:gmatch("(-?[%ded%+%-%.]+)") do
            row[#row+1] = tonumber(num)
         end
         tbl[#tbl+1] = row
      end

   end
   return tbl
end

-- Saves a table to file fn, with the given numeric format fmt (%.4e by default)
function savem(fn, tbl, fmt) 
   local fid
   if type(fn) == "userdata" then
      fid = fn
   else
      fid = io.open(fn, "w")
   end
   
   fmt = fmt or "%.4e"
   
   for i = 1, #tbl do
      for j = 1, #tbl[i] do
         fid:write(string.format(fmt, tbl[i][j]))
         fid:write("\t")
      end
      fid:write("\n")
   end
   fid:close()
end

-- Writes a string to the specified file
function writef(fn, cont, append)
   local fid = io.open(fn, append and "a" or "w")
   if fid then
      fid:write(cont)
      fid:close()
   end
end

-- Prompt for string, return result
function prompt(ps)
   ps = ps or ""
   io.write(ps)
   return io.read()
end

-- Returns a copy of the iterator
function copy(iter)
   local tbl = {}
   for v in iter do tbl[#tbl+1] = v end
   return tbl
end

function injectf(tbl)
   if not tbl then return end
   
   for k, v in pairs(tbl) do
      if type(v) == "function" and not _G[k] then
         _G[k] = v
      end
   end
end

warning = print

function sandboxf(name)
   if (type(_G[name]) == "table") then
      local tbl = {}
      setmetatable(tbl, {__index = function()
                            warning(name .. " table is protected by sandbox. Rerun without the --sandbox option.")
      end})
      _G[name] = tbl
   elseif (type(_G[name]) == "function") then
      _G[name] = function() warning(name .. " function is protected by sandbox. Rerun without the --sandbox option.") end
   end
end

function string.trim(s)
   return s:match("^[%s\n]*(.-)[%s\n]*$") 	
end


function string.split(str, sep)

   local start = 1
   local ret = {}
   local pos = string.find(str, sep, start, true)
   
   while (pos) do
      ret[#ret+1] = string.sub(str, start, pos-1)
      start = pos+1
      pos = string.find(str, sep, start, true)
   end
   
   if (start ~= #str+1) then
      ret[#ret+1] = string.sub(str, start, #str)
   end
   if (string.sub(str, #str, -1) == sep) then
      ret[#ret+1] = ''
   end
   
   return ret
end

-- Ternary function: iff returns a if cond is true, b otherwise

function iff(cond, a, b)
   b = b or ""
   if cond then return a else return b end
end

__onelineonce = {}
function once(str)
   if not __onelineonce[__LINE__] then 
      __onelineonce[__LINE__] = true
      return str 
   else 
      return "" 
   end
end

-- Switch returns the argument next to the first true condition;
-- e.g. switch(cond1, ret1, cond2, ret2, ...)
function switch(...)
   local n = select('#', ...)
   local arg = {...}
   
   for i = 1, n, 2 do
      if i == n then
         return arg[i]
      elseif arg[i] then
         return arg[i+1]
      end
   end
end


function log(str)
   if (not logfid) then
      logfid = assert(_open(outfile .. ".bamlog", "w"))
   end
   logfid:write(str .. "\n")
end

-- Returns the same list with a new metatable, such that each call of
-- tostring on that list (e.g. through a <@ @>) returns a random element
-- of the list
function r(t)
   setmetatable(t, {__type = "_rand", __tostring = function(tbl)
                       local idx = math.random(#tbl)
                       return tostring(tbl[idx])
                                                   end
   })
   return t
end

-- Returns the same list with a new metatable, such that a call to tostring
-- returns a string in the format "item1, item2, item3 and item4"
function l(t)
   setmetatable(t, {__type = "_list", __tostring = function(tbl)
                       local str = tostring(t[1])
                       for i = 2, #t - 1 do 
                          str = str .. ", " .. tostring(t[i])
                       end
                       
                       if #t > 1 then
                          str = str .. " " .. bam.words["and"] .. " " .. tostring(t[#t])
                       end
                       return str
   end})
   return t
end

function pn(...)
   p(...)
   __body:append("\n")
end

-- utility functions

local oldtostring = tostring
function tostring(obj)
   if (obj == nil) then
      return "nil"
   elseif type(obj) == "string" then 
      return obj 
   elseif (type(obj) == "number") then
      -- try to auto-detect whether number is floating or integer
      if (math.floor(obj) ~= obj) then
         return string.format(bam.nformat, obj)
      else
         return oldtostring(obj)
      end
   elseif (type(obj) == "table") then	
      local mt = getmetatable(obj)
      if (mt) then
         if (mt.__tostring) then return mt.__tostring(obj) end
      else
         return tostring(l(obj))
      end
   else
      return oldtostring(obj)
   end
end

-----------------------------------------------------------------------------
-- filters can be used to parse tokens with non-standard Lua syntax to produce
-- more convenient expressions. Filters come in line (%@) and interp (<@ .. @>) 
-- flavors.


-- line filters
table.insert(bam.line_filters, function(str, idx)
                if str == "once" then
                   return _once(idx)
                end
end)

table.insert(bam.line_filters, function(str, idx)
                if str:trim():find("%?%?") == 1 then
                   str = str:sub(3):trim()
                   return "if not exists([[vars/b@" .. str .. "]]) or bam.bypass then empty[[vars/b@" .. str .. "]]\n" 
                end
end)

bam.block = false
table.insert(bam.line_filters, function(str, idx) 
                if str:trim() == "{" then
                   bam.block = true
                   bam.block_function = ident
                   return ""
                elseif str:trim() == "}" then
                   bam.block = false
                   return ""
                end
end)

-- interp filters
-- <@ rand1 | rand2 | rand3 @> syntax
table.insert(bam.interp_filters, function(str)

                if (str:find("%|")) then
                   local arr = {}

                   for v in str:gmatch("(.-)%|")  do
                      arr[#arr+1] = v:trim()
                   end
                   arr[#arr+1] = str:match("%|([^%|]-)$"):trim()
                   
                   _rarrs[#_rarrs+1] = r(arr)
                   return "_rarrs[" .. #_rarrs .. "]"
                end
end)

-- <@? cond1, ret1, cond2, ret2, ... @>: a list of conditions
table.insert(bam.interp_filters, function(str, idx)
                if (str:sub(1, 1) == "?") then
                   return "switch(" .. str:sub(2) .. ")"
                end
end)

-- <@fn number @>: floating point
table.insert(bam.interp_filters, function(str, idx)
                if (str:sub(1, 1) == "f") then
                   return string.format("string.format('%%.%df', %s, %d)",
                                        tonumber(str:sub(2, 2)), str:sub(3), tonumber(str:sub(2, 2)))
                end
end)

-- <@en number @>: scientific notation
table.insert(bam.interp_filters, function(str, idx)
                if (str:sub(1, 1) == "e") then
                   return string.format("sprintf('%%.%df', %s)",
                                        tonumber(str:sub(2, 2)), str:sub(3), tonumber(str:sub(2, 2)))
                end
end)

-- <@En number @>: a x 10^b
table.insert(bam.interp_filters, function(str, idx)
                if (str:sub(1, 1) == "E") then
                   local n = str:sub(2, 2)
                   return string.format("sprintf('$%%.%df \\\\times 10^{%%.0f}$', %s/10^floor(log10(%s)), floor(log10(%s)))", n, str:sub(3), str:sub(3), str:sub(3))
                end
end)

-- <@! command @>: executes the command, substitutes output
table.insert(bam.interp_filters, function(str, idx)
                if (str:sub(1, 1) == "!") then
                   return "string.trim(exec([===[" .. str:sub(2) .. " 2>&1" .. "]===]))"
                end
end)

-- <@~ command @>: includes the file
table.insert(bam.interp_filters, function(str, idx)
                if (str:sub(1, 1) == "~") then
                   return "readf([===[" .. str:sub(2)  .. "]===])"
                end
end)


_oncebarriers = {}
-- Creates an "once" barrier; the text within %@ once ... %@ end is printed out only
-- once. Useful in a loop.
function _once(idx)
   return "if not _oncebarriers[" .. idx .. " ] then\n" ..
      "_oncebarriers[" .. idx .. "] = true\n"
end

function _apply_filters(filters, str, idx)
   for i = 1, #filters do
      local transf = filters[i](str, idx)
      if transf then
         return transf
      end
   end
   return str
end

function filter(typ, fnc, endblock, startfnc, linefnc, endfnc)
   if typ == "interp" then
      table.insert(bam.interp_filters, fnc)
   elseif typ == "line" then
      table.insert(bam.line_filters, fnc)
   elseif typ == "block" then
      local startblock = fnc
      assert(startblock, "Block start string missing")
      assert(endblock, "Block start string missing")
      
      filter("line", function(str, idx)
                if str:trim() == startblock then
                   local ret = ""
                   if startfnc then ret = startfnc() end
                   bam.block = true
                   if linefnc then bam.block_function = linefnc else bam.block_function = ident end
                   return ret
                elseif str:trim() == endblock then
                   local ret = ""
                   if endfnc then ret = endfnc() end
                   bam.block = false
                   return ret
                end
      end)
      
   else
      error("Unknown filter type " .. typ or "nil")
   end
end

function _preprocess(buf)
   local out = buffer()
   
   for i, line in ipairs(buf) do
      bam.lineidx = i
      bam.line = line
      if line:trim():match("^%%%@") then
         line = line:sub(3):trim()
         if line ~= "" then
            out:appendn(_apply_filters(bam.line_filters, line, i))
         end
      elseif bam.block then
         out:appendn(bam.block_function(line))
      else
         line = _interpret(line)
         out:appendn("pn([===[", line, bam.quoteclose, "]===])")
      end

   end
   
   return out:tostring()
end

function p(...)
   local args = {...}
   for i = 1, #args do
      __body:append(_varexpand(args[i]))
   end
end

_rarrs = {}

function _interpret(str)
   local magic = false
   return str:gsub("%<%@(.-)%@%>", function(str)
                      magic = true
                      return "]===], tostring(" .. _apply_filters(bam.interp_filters, str) .. "), [===["
   end), magic
end


function _interpret2(str)
   
   -- remove %< tag
   str = str:sub(3, -3)
   str = string.trim(str)
   _result = ""
   
   local frag = loadstring("return " .. str)
   return tostring(frag())
end

function _varexpand(str)
   str = tostring(str)
   
   while str:match("(%<%@.-%@%>)") do
      str = str:gsub("(%<%@.-%@%>)", _interpret2)
   end
   
   return tostring(str)
end

bam.expand = _varexpand
bam.interpret = _interpret

setmetatable(_G, {
                __index = function(t, k) 	
                   if type(k) == "string" then
                      if exists("vars/@" .. k) then
                         _G[k] = readf("vars/@" .. k)
                         return _G[k]
                      elseif exists("vars/t@" .. k) then
                         _G[k] = reada("t@" .. k)
                         return _G[k]
                      elseif exists("vars/n@" .. k) then
                         _G[k] = tonumber(readf("vars/n@" .. k))
                         return _G[k]
                      end
                   end
                end
})

-----------------------------------------------------------------------------
-- main script

function bam.print_help()
   print("Usage: lua bam2.lua [--cache] [--debug] [--sandbox] [--nformat format] [--require require] inputfile", "\n")
   os.exit()
end


for i = 1, #arg do
   if arg[i] == "--no-inject" then
      bam.inject = false
   elseif arg[i] == "--help" then
      bam.print_help()
   elseif arg[i] == "--cache" then
      bam.cache = true
   elseif arg[i] == "--plugin" then
      dofile(arg[i+1])
      i = i + 1
   elseif arg[i] == "--sandbox" then
      bam.sandbox = true
   elseif arg[i] == "--nformat" or arg[i] == "-n" then
      bam.nformat = arg[i+1]
      i = i + 1
   elseif arg[i] == "--bypass" then
      bam.bypass = true
   elseif arg[i] == "--debug" then
      bam.debug = true
   elseif arg[i] == "--lang" then
      bam.lang = arg[i+1]
      print("Using lang ", bam.lang)
      i = i + 1
   elseif arg[i] == "-r" or arg[i] == "--require" then
      require(arg[i+1])
      i = i + 1
   else
      bam.infile = arg[i] .. ".bam"
      bam.auxfile = arg[i] .. ".aux"		
      bam.outfile = arg[i]
   end
end

if not bam.infile then
   bam.print_help()
end

if bam.sandbox then
   sandboxf('io')
   local date = os.date
   local time = os.time
   sandboxf('os')
   os.date = date
   os.time = time
   sandboxf('exec')
   sandboxf('require')
   sandboxf('dofile')
end

if bam.inject then
   -- inject table, math, os and io functions into global
   injectf(math)
   injectf(table)
   injectf(os)
   injectf(io)
end

assert(exists(bam.infile), "Could not find " .. bam.infile)

local fid = assert(_open(bam.infile, "r"))

print("Processing " .. bam.infile .. "...")
local __script = copy(fid:lines())

local body = _preprocess(__script)
__body = buffer()

local fidscript = assert(_open(bam.auxfile, "w"))
if bam.lang == "lua" then
   fidscript:write(body)
   fidscript:close()

   math.randomseed(os.time())
   math.random()

   local success, err = pcall(_dofile, bam.auxfile)
   if not success then
      local linen, err2 = err:match("%:(%d-)%:(.-)$")
      linen = tonumber(linen)
      local line = __script[linen] or "<end of file>"
      io.stderr:write(string.format("bam: %s:%d: %s\nline: %s\ntransl: %s\norig: %s\n", bam.infile, linen, err2, line, __body:getn(linen) or "?", err))
      return
   end

   local fido = assert(_open(bam.outfile, "w"))
   fido:write(__body:tostring())
   fido:close()
elseif bam.lang == "R" then
   local rtmp = bam.outfile .. ".tmp"
   
   body = body:gsub("%[===%[(.-)%]===%]", function(s) return "\"" .. s:gsub("\\", "\\\\") .. "\"" end):gsub("%$%$", "$")
   body = string.format("con <- file('%s', open='w'); source('.preamble.r'); %s\nfile.rename('%s', '%s')\n", rtmp, body, rtmp, bam.outfile)
   fidscript:write(body)
   fidscript:close()

   local fid_preamble = _open(".preamble.r", "w"):write([=[
pn <- function(...) {
l <- list(...)
for (i in l) {
if (length(i) > 1)
cat(file=con, i, sep='\n')
else
cat(file=con, i, sep='')
}
cat(file=con, '\n')
}

tostring <- as.character
string.format <- function(fmt, n, dig) {
n <- round(n, digits=dig)
return(sprintf(fmt,n))
}
]=]):close()

   os.execute("Rscript " .. bam.auxfile)
   
end
if (logfid) then logfid:close() end

print(bam.outfile .. " written.")

if not bam.debug then os.remove(bam.auxfile) end
