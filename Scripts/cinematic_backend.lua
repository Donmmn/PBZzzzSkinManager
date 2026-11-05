-- UE5 Media Framework + UMG. No compiled material, process suspension or world scan.
local M={}
function M.new(api,clip,options)
    local H=require('UEHelpers.UEHelpers')
    local B={};local root,player,texture,imageSize,pawn,pc,world,paused,moveHeld,lookHeld
    local started,lastPosition,advances,tracksSelected,parkChecks,framePrimed
    local folder=assert(options.root,'Cannot locate cinematic runtime')
    local audio=require('cinematic_audio').new(folder,clip,api.log)
    local counter=0
    local function valid(o) local ok,v=pcall(function() return o and o:IsValid() end);return ok and v end
    local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
    local function create(path,outer,name)
        local class=StaticFindObject(path);assert(valid(class),'Class unavailable: '..path)
        local obj=StaticConstructObject(class,outer,FName('PBZCinema_'..counter..'_'..name))
        assert(valid(obj),'Cannot construct '..path);return obj
    end
    local function statics()
        local s=StaticFindObject('/Script/Engine.Default__GameplayStatics');assert(valid(s),'GameplayStatics unavailable');return s
    end
    function B.stillEligible()
        if not api.isActiveModel(options.profile_id) or not valid(pawn) or not valid(pc) then return false end
        return same(api.getPlayerController(),pc) and same(pc.Pawn,pawn) and same(pawn:GetWorld(),world)
    end
    function B.open()
        assert(api.isActiveModel(options.profile_id),'Select this character first')
        local f=assert(io.open(clip,'rb'),'Video file missing');f:close()
        -- Audio is decoded directly from this local video by Windows Media Foundation.
        pc=api.getPlayerController();assert(valid(pc),'Enter a playable save first')
        pawn=pc.Pawn;assert(valid(pawn),'Player unavailable');world=pawn:GetWorld()
        assert(not statics():IsGamePaused(pawn),'Game is already paused; resume before playback')
        counter=counter+1;started=false;lastPosition=nil;advances=0;tracksSelected=false;framePrimed=false
        root=create('/Script/UMG.UserWidget',pc,'Root')
        local tree=create('/Script/UMG.WidgetTree',root,'Tree');root.WidgetTree=tree
        local canvas=create('/Script/UMG.CanvasPanel',tree,'Canvas');tree.RootWidget=canvas
        local black=create('/Script/UMG.Border',canvas,'Black');black:SetBrushColor({R=0,G=0,B=0,A=1});black:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
        local slot=canvas:AddChildToCanvas(black);slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}});slot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0})
        local fit=create('/Script/UMG.ScaleBox',black,'Fit');fit:SetStretch(1);black:SetContent(fit)
        local size=create('/Script/UMG.SizeBox',fit,'Size');size:SetWidthOverride(852);size:SetHeightOverride(480);fit:SetContent(size);imageSize=size
        local image=create('/Script/UMG.Image',size,'Image');size:SetContent(image)
        player=create('/Script/MediaAssets.MediaPlayer',root,'Player')
        -- PBZ disables the UE audio mixer; video stays in UE, PCM uses a narrow Windows audio module.
        player.PlayOnOpen=false;player.NativeAudioOut=false;player:SetLooping(false)
        player:SetDesiredPlayerName(FName('WmfMedia'))
        texture=create('/Script/MediaAssets.MediaTexture',root,'Texture')
        -- SetMediaPlayer updates CurrentPlayer (weak), not the reflected strong MediaPlayer property.
        -- Lua references and an Outer alone do not retain a UObject through Unreal GC.
        texture.MediaPlayer=player
        assert(same(texture.MediaPlayer,player),'Cannot retain cached MediaPlayer')
        texture:SetMediaPlayer(player);texture:UpdateResource();image:SetBrushResourceObject(texture)
        -- Viewport -> WidgetTree -> Image brush -> Texture -> MediaPlayer forms a UE GC reference chain.
        -- Keep a practically transparent Slate draw so the first texture is rendered before takeover.
        root:SetRenderOpacity(.001);root:SetVisibility(3);root:AddToViewport(21000)
        audio.prepare()
        assert(player:OpenFile(clip),'Media backend rejected file')
    end
    function B.playing() return valid(player) and player:IsPlaying() end
    function B.position()
        if not valid(player) then return 0 end
        local math=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
        assert(valid(math),'Timespan conversion unavailable')
        return math:GetTotalSeconds(player:GetTime())
    end
    function B.duration()
        local math=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
        return valid(math) and math:GetTotalSeconds(player:GetDuration()) or 4
    end
    function B.ready()
        if not valid(player) or not player:IsReady() then return false end
        assert(B.duration()>0 and B.duration()<=60,'Use a video between 0 and 60 seconds')
        if not tracksSelected then
            if player:GetNumTracks(6)<1 then return false end
            if player:GetSelectedTrack(0)~=-1 then assert(player:SelectTrack(0,-1),'Cannot disable unused UE audio track') end
            if player:GetSelectedTrack(6)~=0 then assert(player:SelectTrack(6,0),'Cannot select video track') end
            tracksSelected=true
            api.log('Media opened backend='..player:GetPlayerName():ToString()..'; audio='..player:GetSelectedTrack(0)..'; video='..player:GetSelectedTrack(6))
        end
        if not started then
            assert(player:Play(),'Cannot start media');started=true;return false
        end
        if not player:IsPlaying() or texture:GetWidth()<16 or texture:GetHeight()<16 then return false end
        local format=player:GetTrackFormat(6,0);if format<0 then return false end
        local dimensions=player:GetVideoTrackDimensions(0,format)
        if dimensions.X<16 or dimensions.Y<16 then return false end
        imageSize:SetWidthOverride(dimensions.X);imageSize:SetHeightOverride(dimensions.Y)
        local now=B.position()
        if lastPosition and now>lastPosition+.005 then advances=advances+1 end
        lastPosition=now
        framePrimed=advances>=2 and now>=.08 and audio.ready()
        return framePrimed
    end
    function B.failed() return not valid(player) or player:HasError() end
    function B.describe()
        if not valid(player) then return 'player invalid' end
        return 'ready='..tostring(player:IsReady())..'; playing='..tostring(player:IsPlaying())..
            '; paused='..tostring(player:IsPaused())..'; preparing='..tostring(player:IsPreparing())..
            '; texture='..texture:GetWidth()..'x'..texture:GetHeight()..'; time='..tostring(B.position())..'; PCM='..audio.describe()
    end
    function B.park()
        -- Decode only during bounded warmup. Seek while paused, then retain the first frame.
        assert(player:Pause(),'Cannot pause prewarmed media')
        assert(player:Rewind(),'Cannot rewind prewarmed media');parkChecks=0
    end
    function B.parked()
        -- GetTime can retain the last displayed timestamp while a paused seek is pending.
        -- It is not a seek-completion signal. Require a decoded, non-playing source instead.
        if not B.canPlayPrepared() or player:IsPlaying() or player:IsPreparing() then
            parkChecks=0;return false
        end
        parkChecks=parkChecks+1
        if parkChecks<3 then return false end
        root:SetRenderOpacity(0);root:SetVisibility(2)
        return true
    end
    function B.canPlayPrepared()
        return framePrimed and valid(player) and player:IsReady() and
            texture:GetWidth()>=16 and texture:GetHeight()>=16 and audio.ready()
    end
    function B.showAndPause()
        assert(B.stillEligible(),'Player changed during open')
        local s=statics();assert(not s:IsGamePaused(pawn),'Another pause owner is active')
        -- A single seek against the open decoder also covers a paused seek that deferred completion.
        -- No file open, widget construction, track selection or device preparation on this path.
        assert(player:Rewind(),'Cannot rewind prepared video')
        assert(player:Play(),'Cannot resume cached media')
        assert(s:SetGamePaused(pawn,true),'World pause failed');paused=true
        moveHeld=true;pc:SetIgnoreMoveInput(true)
        lookHeld=true;pc:SetIgnoreLookInput(true)
        root:SetRenderOpacity(1);root:SetVisibility(0)
        audio.play()
        api.log('Primed texture='..texture:GetWidth()..'x'..texture:GetHeight()..'; audio=Windows PCM module')
    end
    local function resumeWorld()
        if valid(pc) then
            if moveHeld then local ok=pcall(function() pc:SetIgnoreMoveInput(false) end);if ok then moveHeld=false end end
            if lookHeld then local ok=pcall(function() pc:SetIgnoreLookInput(false) end);if ok then lookHeld=false end end
        end
        if paused and valid(pawn) and same(pawn:GetWorld(),world) then
            local ok,err=pcall(function() assert(statics():SetGamePaused(pawn,false),'World resume failed') end)
            if not ok then api.log('RESUME FAILED: '..tostring(err));return false end
            paused=false
        end
        if valid(pc) and (moveHeld or lookHeld) then return false end
        return true
    end
    function B.recycle()
        -- Return control before preparing the next cast; retain decoder and audio resources.
        root:SetRenderOpacity(.001);root:SetVisibility(3)
        assert(resumeWorld(),'World/input recovery failed')
        audio.reset();assert(player:Rewind(),'Cannot rewind cached media')
        started=false;lastPosition=nil;advances=0;parkChecks=0
    end
    function B.close()
        if valid(root) then pcall(function() root:RemoveFromParent() end) end
        local audioOk,audioErr=pcall(audio.stop)
        if valid(player) then pcall(function() player:Close() end) end
        local recovered=resumeWorld()
        if not audioOk then api.log('Audio cleanup failed: '..tostring(audioErr)) end
        if not recovered or not audioOk then return false end
        root=nil;player=nil;texture=nil;imageSize=nil;pawn=nil;pc=nil;world=nil
        paused=false;moveHeld=false;lookHeld=false
    end
    return B
end
return M
