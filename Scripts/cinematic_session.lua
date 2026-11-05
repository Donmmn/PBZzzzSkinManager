-- Finite warmup/playback transactions. Ready cache is paused and schedules no timer.
local M={}
function M.new(backend,schedule,log)
    local S={state='idle',generation=0,elapsed=0,playElapsed=0}
    function S:stop(reason)
        if self.state=='idle' then return end
        self.generation=self.generation+1;self.state='recovering';self.previewPending=false;self.playPending=false
        local token=self.generation
        local function release(attempt)
            if token~=self.generation then return end
            local ok,result=pcall(backend.close)
            if ok and result~=false then self.state='idle';log('Stopped: '..tostring(reason));return end
            log('Cleanup retry '..attempt..': '..tostring(result))
            if attempt<3 then schedule(50,function() release(attempt+1) end)
            else self.state='recovery_required';log('Recovery still required; press Escape to retry') end
        end
        release(1)
    end
    local step
    local function queue(token) schedule(50,function() step(token) end) end
    local function beginPlayback()
        assert(backend.stillEligible(),'Cached player or world changed')
        assert(not backend.failed(),'Cached decoder unavailable')
        backend.showAndPause();S.state='playing';S.playElapsed=0
        S.lastPosition=backend.position();S.stalled=0
        S.clipDuration=backend.duration()
        S.playLimit=math.min(60000,math.max(6000,S.clipDuration*1000+2000))
        S.previewPending=false;S.playPending=false
        log('Video playing from warm cache; world pause acquired')
    end
    step=function(token)
        if token~=S.generation or S.state=='idle' or S.state=='ready' then return end
        local ok,err=pcall(function()
            S.elapsed=S.elapsed+50
            if not backend.stillEligible() then S:stop('model, player or world changed');return end
            if backend.failed() then S:stop('decoder error');return end
            if S.state=='warming' then
                if backend.describe and (S.elapsed==500 or S.elapsed==1500 or S.elapsed==2500) then log('Prewarming: '..backend.describe()) end
                if backend.ready() then
                    if S.playPending then beginPlayback()
                    else backend.park();S.state='parking';log('Decoded frames ready; parking: '..backend.describe()) end
                end
            elseif S.state=='parking' then
                if S.playPending and backend.canPlayPrepared() then beginPlayback()
                elseif backend.parked() then
                    S.state='ready';log('Warm cache ready; decoder paused; no idle timer')
                    if S.playPending then beginPlayback() end
                end
            elseif S.state=='playing' then
                S.playElapsed=S.playElapsed+50
                if not backend.playing() then
                    -- WMF can advance to the final timestamp between our finite
                    -- samples. Inspect the stopped clock as well as the last
                    -- playing sample before classifying normal EOS as a failure.
                    local stoppedAt=backend.position()
                    -- WMF may briefly report stopped while a cached seek/resume is asynchronous.
                    -- A single false sample immediately after Play is not end-of-stream.
                    if S.playElapsed>=1000 and math.max(S.lastPosition,stoppedAt)>=S.clipDuration-.15 then
                        backend.recycle();S.state='warming';S.elapsed=0
                        log('Playback finished; control restored; recycling warm cache')
                    elseif S.playElapsed>=1000 then S:stop('decoder stopped before clip end');return end
                else
                    local position=backend.position()
                    if math.abs(position-S.lastPosition)>.001 then S.stalled=0 else S.stalled=S.stalled+50 end
                    S.lastPosition=position
                    if S.stalled>=1000 then S:stop('media clock stalled');return end
                    if S.playElapsed>=S.playLimit then S:stop('playback watchdog');return end
                end
            end
            if (S.state=='warming' or S.state=='parking') and S.elapsed>=5000 then
                log('Cache timeout state='..S.state..'; '..backend.describe())
                S:stop('cache preparation timeout; world was not paused');return
            end
            if S.state=='warming' or S.state=='parking' or S.state=='playing' then queue(token) end
        end)
        if not ok then S:stop(err) end
    end
    function S:warm()
        if self.state~='idle' then return false,'already prepared or active' end
        self.generation=self.generation+1;self.state='warming';self.elapsed=0;self.previewPending=false;self.playPending=false
        local ok,err=pcall(backend.open)
        if not ok then self:stop(err);return false,tostring(err) end
        queue(self.generation);return true
    end
    function S:start(waitForReady)
        if self.state=='ready' then
            local healthy,usable=pcall(function() return backend.stillEligible() and not backend.failed() end)
            if healthy and usable then
                local ok,err=pcall(beginPlayback)
                if ok then queue(self.generation);return true end
                log('Cached playback failed; rebuilding for this cast: '..tostring(err))
            else log('Cached player/decoder expired; rebuilding for this cast') end
            self:stop('replace expired cache')
            if self.state~='idle' then return false,'cleanup still required before rebuilding' end
        end
        if self.state=='idle' then
            local ok,err=self:warm();if not ok then return false,err end
        end
        if self.state=='warming' or self.state=='parking' then
            if self.playPending then return false,'playback already pending' end
            self.previewPending=waitForReady==true;self.playPending=true
            log('Warm cache miss; bounded cold playback fallback requested')
            return true,'waiting for decoded frames'
        end
        return false,'already active'
    end
    return S
end
return M
