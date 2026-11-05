-- Finite one-shot jobs only. The installed cdbc0b66 loader owns delivery on the
-- game thread; do not cross the async Lua state with nested dispatch calls.
local M={}
function M.new(log)
    assert(type(ExecuteInGameThreadWithDelay)=='function','Loader lacks native delayed game-thread actions; video addon not initialized')
    local pending={};local serial=0
    local Q={}
    function Q.after(ms,fn)
        assert(type(ms)=='number' and ms>=0 and ms<=60000 and type(fn)=='function','Invalid finite game-thread job')
        serial=serial+1;local id=serial
        local function deliver()
            local ok,err=pcall(fn)
            pending[id]=nil
            if not ok then log('Game-thread job failed: '..tostring(err)) end
        end
        pending[id]=deliver
        local ok,handle=pcall(ExecuteInGameThreadWithDelay,math.floor(ms),deliver)
        if not ok then pending[id]=nil;error(handle) end
        return handle
    end
    function Q.pendingCount()
        local count=0;for _ in pairs(pending) do count=count+1 end;return count
    end
    return Q
end
return M
