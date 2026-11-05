-- Bounded menu transactions; no actor enumeration and no permanent timer.
-- Rendering pauses BEFORE mesh/material changes and resumes only after settle.
local M={}
function M.new(api)
 local Q={};local busy=false;local target;local paint=false;local sequence=0
 local advance
 local function fail(why)
  busy=false;target=nil;paint=false;api.error(tostring(why))
  -- Keep the last captured image frozen after failure. Do not resume a view
  -- whose model readiness could not be established.
 end
 local function settle(kind,id)
  local samples,tries=0,0
  local function poll()
   tries=tries+1
   local ok,ready=pcall(api.ready,kind,id)
   if not ok then fail(ready);return end
   samples=ready and samples+1 or 0
   if samples>=2 then
    if kind=='model'then local good,why=pcall(api.modelSettled,id);if not good then fail(why);return end end
    advance()
   elseif tries>=40 then fail('Timed out waiting for model/material settlement')
   else api.after(100,poll)end
  end
  api.after(450,poll)
 end
 advance=function()
  if target then
   local id=target;target=nil;sequence=sequence+1
   local ok,why=pcall(api.model,id)
   if not ok then fail(why);return end
   settle('model',id)
  elseif paint then
   paint=false;sequence=sequence+1
   local ok,why=pcall(api.paint)
   if not ok then fail(why);return end
   settle('paint')
  else busy=false;api.resume();api.done(sequence)end
 end
 local function start()
  if busy then return end
  busy=true;api.suspend();api.after(120,advance)
 end
 function Q.select(id)target=id;start()end
 function Q.togglePaint()paint=not paint;start()end
 function Q.clearPending()target=nil;paint=false end
 function Q.isBusy()return busy end
 return Q
end
return M
