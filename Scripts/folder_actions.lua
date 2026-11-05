-- Explicit user clicks only; native wide-character directory open, no shell.
local M={};local cache={}
function M.open(root,directory,notice)
 assert(type(directory)=='string'and not directory:find('[\r\n%z]'),'Invalid directory')
 local f=assert(io.open(root..'/State/ImportFolder.txt','wb'))
 assert(f:write(directory..'\n'));f:close()
 local name=notice and'cinematic_missing_video_notice'or'cinematic_open_import_folder'
 if not cache[name]then cache[name]=assert(package.loadlib(root..'/Tools/PBZCinematicAudio.dll',name))end
 cache[name]()
 f=assert(io.open(root..'/State/ImportStatus.txt','rb'));local result=f:read('*a');f:close()
 assert(result:match('^opened 0'),'Directory open failed: '..result)
 return true
end
return M
