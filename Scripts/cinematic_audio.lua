-- The native worker decodes this local MP4 directly; no FFmpeg, WAV companion,
-- Lua background thread, external player or game Audio Mixer is required.
local M={}
function M.new(root,clip,log)
    local A={};local loaded,requested=false,false;local functions={}
    local function status()
        local file=io.open(root..'/State/AudioStatus.txt','rb');if not file then return '' end
        local text=file:read('*a');file:close();return text
    end
    local function load()
        if loaded then return end
        for _,name in ipairs({'audio_prepare','audio_play','audio_stop','audio_reset'}) do
            functions[name]=assert(package.loadlib(root..'/Tools/PBZCinematicAudio.dll',name))
        end
        loaded=true
    end
    function A.prepare()
        if requested then return end
        load();local file=assert(io.open(root..'/State/AudioRequest.txt','wb'),'Cannot write audio request')
        assert(file:write(clip..'\n'));file:close();requested=true;functions.audio_prepare()
        log('Local video audio preparation requested; native worker, no Lua async')
    end
    function A.ready()
        local text=status();if text:match('^error') then error('Video audio decode failed: '..text) end
        return text:match('^ready 0')~=nil
    end
    function A.describe() return status():gsub('[\r\n]',' ') end
    function A.play()
        assert(requested,'Audio not prepared');functions.audio_play()
        assert(status():match('^playing 0'),'Audio playback failed: '..status())
    end
    function A.reset()
        assert(requested,'Audio not prepared');functions.audio_reset();assert(A.ready(),'Audio reset failed')
    end
    function A.stop() requested=false;if loaded then functions.audio_stop() end end
    return A
end
return M
