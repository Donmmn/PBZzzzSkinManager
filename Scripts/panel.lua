-- Native wardrobe menu. Portraits belong to character packs; shared art is original.
-- Native diagonal scrolling; animation runs only while visible. No world scans.
local H=require('UEHelpers.UEHelpers');local controls=require('controls')
local M={};local profiles,appearance,context,jobs,cinematics
local root,canvas,controller,oldCursor,detailBox,footer,modelList,scanRow,listHeader
local backRow,background,previewImage,preview,menuEpoch= nil,nil,nil,nil,0
local textureCache={};local previewOK=false
local rosterScroll,rosterLayout,lastScrolledSelection
local modelViews,emptyViews={},{ };local titleWidget,titleClip,liveLabel
local locale=require('ui_locale');local folders=require('folder_actions')
local shaderStatus=require('shader_status');local shaderTitle,shaderDetail
local function T(key)return locale.get(key)end
local image;local detailExtent;local settleFrames=0;local transitions
local lattice=require('roster_layout')
local opened,moveHeld,lookHeld=false,false,false
local generation,serial,selected,actionIndex=0,0,1,1
local focus='models';local models,actions,extensionRows,listeners={},{},{},{}
local C={ink={R=.012,G=.014,B=.018,A=.98},panel={R=.025,G=.029,B=.035,A=1},
 row={R=.014,G=.016,B=.018,A=1},lime={R=.72,G=.98,B=.025,A=1},
 white={R=.94,G=.96,B=.95,A=1},muted={R=.48,G=.53,B=.56,A=1},cyan={R=.08,G=.77,B=.83,A=1}}
local function valid(o)local ok,v=pcall(function()return o and o:IsValid()end);return ok and v end
local function log(s)print('[PBZWardrobePanel] '..s..'\n')end
local function new(class,outer,name)
 local cls=StaticFindObject('/Script/UMG.'..class);assert(valid(cls),'UI class unavailable: '..class)
 serial=serial+1;local o=StaticConstructObject(cls,outer,FName('PBZWardrobe_'..name..'_'..generation..'_'..serial))
 assert(valid(o),'UI construction failed: '..class);return o
end
local function color(t,c)t:SetColorAndOpacity({SpecifiedColor=c,ColorUseRule=0})end
local function text(parent,name,value,size,tint)
 local t=new('TextBlock',parent,name);t:SetText(FText(value))
 local font=t.Font;font.Size=size;pcall(function()font.TypefaceFontName=FName('Bold')end);t:SetFont(font)
 color(t,tint or C.white);t:SetAutoWrapText(true);return t
end
local function border(parent,name,tint,padding)
 local b=new('Border',parent,name);b:SetBrushColor(tint)
 b:SetPadding({Left=padding or 0,Top=padding or 0,Right=padding or 0,Bottom=padding or 0});return b
end
local function place(widget,x,y,right,bottom)
 local slot=canvas:AddChildToCanvas(widget)
 slot:SetAnchors({Minimum={X=x,Y=y},Maximum={X=right,Y=bottom}})
 slot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0});return slot
end
local function append(box,child,gap)
 local slot=box:AddChildToVerticalBox(child)
 slot:SetHorizontalAlignment(0)
 if gap then slot:SetPadding({Left=0,Top=gap,Right=0,Bottom=0})end;return slot
end
local function button(box,name,label,run,height)
 -- Border intentionally leaves mouse-down unhandled so UE4SS's event-only
 -- key binding receives it. UButton consumes it before that binding runs.
 local b=border(box,name,C.row,0);b:SetHorizontalAlignment(0)
 local size=new('SizeBox',b,name..'Size');size:SetMinDesiredHeight(height or 52);b:SetContent(size)
 pcall(function()size.Slot:SetHorizontalAlignment(0);size.Slot:SetVerticalAlignment(0)end)
 local bg=border(size,name..'Background',C.row,14);size:SetContent(bg)
 pcall(function()local brush=bg.Background;brush.DrawAs=4;brush.OutlineSettings.CornerRadii={X=18,Y=18,Z=18,W=18};brush.OutlineSettings.RoundingType=0;bg:SetBrush(brush)end)
 local labelWidget=text(bg,name..'Text',label,17);bg:SetContent(labelWidget);append(box,b,9)
 return {widget=b,bg=bg,text=labelWidget,run=run,label=label}
end
local function detailPlace(widget,x,y,w,h)
 local slot=detailBox:AddChildToCanvas(widget);slot:SetPosition({X=x,Y=y});slot:SetSize({X=w,Y=h});return slot
end
local function actionButton(index,label,run,globe)
 local y=70+(index-1)*72;local x=.28*y
 local width=globe and 140 or 270-x
 local b=border(detailBox,'Action'..index,{R=0,G=0,B=0,A=0},0)
 detailPlace(b,x,y,width,58)
 local layer=new('CanvasPanel',b,'ActionLayer'..index);b:SetContent(layer)
 local shape=globe and 'ActionGlobe.png' or ('Action'..math.min(index,8)..'.png')
 local bg=image(layer,'ActionShape'..index,profiles.root..'/Assets/'..shape)
 local bs=layer:AddChildToCanvas(bg);bs:SetPosition({X=0,Y=0});bs:SetSize({X=width,Y=58});bg:SetVisibility(4)
 local tx=globe and 67 or 30
 local labelWidget=text(layer,'ActionLabel'..index,label,14);labelWidget:SetAutoWrapText(false);labelWidget:SetVisibility(4)
 local ts=layer:AddChildToCanvas(labelWidget);ts:SetPosition({X=tx,Y=18});ts:SetSize({X=width-tx-12,Y=27})
 if globe then
  local icon=image(layer,'Globe',profiles.root..'/Assets/Globe.png');icon:SetVisibility(4)
  local gs=layer:AddChildToCanvas(icon);gs:SetPosition({X=26,Y=13});gs:SetSize({X=32,Y=32})
 end
 return {widget=b,bg=bg,text=labelWidget,run=run,label=label,imageBg=true}
end
local function setFooter(value)if valid(footer)then footer:SetText(FText(value))end end
local function refreshShaderStatus()
 if not opened or not valid(shaderTitle)then return end
 local component
 if context then pcall(function()local pc=context.getController();if valid(pc)and valid(pc.Pawn)then component=pc.Pawn.Mesh end end)end
 local ok,a,b=pcall(function()
  local record=shaderStatus.sample(appearance.current(),package.loaded.paint,component,transitions and transitions.isBusy())
  return shaderStatus.format(record,locale.language)
 end)
 if not ok then a=locale.language=='en'and'SHADING: Not verified'or'当前着色：待核对';b=locale.language=='en'and'Material status unavailable'or'暂时无法读取材质状态'end
 shaderTitle:SetText(FText(a));if valid(shaderDetail)then shaderDetail:SetText(FText(b))end
end

local cancelHandlers={}
function M.registerCancelHandler(fn)
 assert(type(fn)=='function');cancelHandlers[#cancelHandlers+1]=fn
end
function M.cancel()
 -- The wardrobe owns priority while visible. Other consumers (the movie
 -- player) receive Escape only after the panel has relinquished UI input.
 if opened then M.close();return true end
 for _,fn in ipairs(cancelHandlers)do
  local ok,handled=pcall(fn)
  if not ok then log('Cancel failed: '..tostring(handled))elseif handled then return true end
 end
 return false
end
local rebuildDetails,refreshModels,rebuildModelList
function M.close()
 opened=false;if transitions then transitions.clearPending()end;menuEpoch=menuEpoch+1;if preview then pcall(preview.close)end;previewOK=false
 if valid(root)then pcall(function()root:RemoveFromParent()end)end
 root=nil;models={};modelViews={};emptyViews={};actions={};detailBox=nil;footer=nil;shaderTitle=nil;shaderDetail=nil
 if valid(controller)then
  if moveHeld then pcall(function()controller:SetIgnoreMoveInput(false)end)end
  if lookHeld then pcall(function()controller:SetIgnoreLookInput(false)end)end
  pcall(function()controller.bShowMouseCursor=oldCursor==true end)
  local lib=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
  if valid(lib)then pcall(function()lib:SetInputMode_GameOnly(controller,false)end)end
 end
 controller=nil;moveHeld=false;lookHeld=false
 ModRef:SetSharedVariable('PBZWardrobePanelRoot',CreateInvalidObject())
 ModRef:SetSharedVariable('PBZWardrobePanelController',CreateInvalidObject());log('Closed; input restored')
end
function M.registerExtensionRow(row)
 assert(type(row.id)=='string' and type(row.name)=='function' and type(row.run)=='function','Invalid addon row')
 for _,r in ipairs(extensionRows)do assert(r.id~=row.id,'Duplicate addon row')end;extensionRows[#extensionRows+1]=row
end
function M.registerModelChangeListener(fn)assert(type(fn)=='function');listeners[#listeners+1]=fn end
function M.setCinematics(value)cinematics=value end
local function execute(fn)
 local ok,result=pcall(fn)
 if opened then
  rebuildDetails();refreshModels()
  if not ok then setFooter(T('failed')..tostring(result))elseif type(result)=='string' then setFooter(result)end
 end
 if not ok then log(result)end
end
local function apply(index)
 local row=models[index];if not row then return end;selected=index
 transitions.select(row.profile.id)
 rebuildDetails();refreshModels();setFooter(T('switching'));refreshShaderStatus()
end
local function refreshActions()
 for i,row in ipairs(actions)do
  local on=focus=='actions' and i==actionIndex
  if row.imageBg then row.bg:SetColorAndOpacity(on and C.lime or C.row)else row.bg:SetBrushColor(on and C.lime or C.row)end;color(row.text,on and C.ink or C.white)
  row.text:SetText(FText(row.label))
 end
end
refreshModels=function()
 local current=appearance.current()
 for _,row in ipairs(modelViews)do
  local chosen=row.index==selected;local on=chosen and focus=='models'
  row.bg:SetBrushColor({R=0,G=0,B=0,A=0});color(row.text,chosen and C.lime or C.white)
  if valid(row.frame)then row.frame:SetRenderOpacity(chosen and 1 or 0)end
  local pending=appearance.pendingSelection and appearance.pendingSelection()==row.profile.id
  row.text:SetText(FText(locale.profileName(row.profile)))
 end
 if valid(rosterScroll)and rosterLayout and lastScrolledSelection~=selected then
  lastScrolledSelection=selected
  local offset=rosterScroll:GetScrollOffset()
  rosterScroll:EndInertialScrolling()
  rosterScroll:SetScrollOffset(rosterLayout.reveal(selected,offset))
 end
 refreshActions()
end
rebuildDetails=function()
 if not opened or not valid(detailBox)then return end
 detailBox:ClearChildren();actions={};scanRow=nil
 local p=models[selected]and models[selected].profile;if not p then return end
 titleClip=new('CanvasPanel',detailBox,'TitleClip');titleClip:SetClipping(1);titleClip:SetVisibility(4)
 detailPlace(titleClip,0,0,270,46)
 titleWidget=text(titleClip,'CharacterName',locale.profileName(p),23);titleWidget:SetAutoWrapText(false);titleWidget:SetVisibility(4)
 local ns=titleClip:AddChildToCanvas(titleWidget);ns:SetAutoSize(true);ns:SetPosition({X=0,Y=0})
 local function add(label,run,globe)actions[#actions+1]=actionButton(#actions+1,label,run,globe)end
 if p.native_original then
  add(T('reload'),function()apply(selected)end)
 elseif cinematics then
  local info=cinematics.describe(p)
  add(T(not info.exists and 'cinema_missing'or(info.enabled and'cinema_on'or'cinema_off')),function()
   local ok,why=cinematics.toggle(p.id);if not ok then return T('unavailable')end
  end)
  add(T('preview'),function()
   local ok,why=cinematics.recheckAndPreview(p.id)
   if not ok then return T('missing')end
  end)
 else add(T('unavailable'),function()end)end
 add(T('refill'),function()
  if transitions and transitions.isBusy()then return T('switching')end
  local result=require('energy_refill').refill(context)
  log('MANUAL_ULTIMATE_REFILL before='..result.before..'; after='..result.after..'; max='..result.maximum)
  return T('refill_done')..string.format(' (%g / %g)',result.after,result.maximum)
 end)
 add(T('scan'),M.rescan)
 for _,provider in ipairs(extensionRows)do
  add(provider.name(),function()if provider.closePanel then M.close()end;return provider.run()end)
 end
 add(T('language'),function()
  locale.toggle()
  if valid(listHeader)then listHeader:SetText(FText(string.format('%s  /  %02d',T('catalog'),#profiles.list)))end
  if valid(liveLabel)then liveLabel:SetText(FText(T('live')))end
 end,true)
 detailExtent:SetHeightOverride(math.max(410,70+#actions*72))
 actionIndex=math.max(1,math.min(actionIndex,#actions));refreshActions()
 setFooter(T('footer'));refreshShaderStatus()
end
image=function(parent,name,path)
 local w=new('Image',parent,name)
 local t=textureCache[path]
 if not valid(t)then
  local rendering=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
  local ok,result=pcall(function()return rendering:ImportFileAsTexture2D(controller,path)end)
  if ok and valid(result)then t=result;textureCache[path]=t end
 end
 if valid(t)then w:SetBrushFromTexture(t,false)end
 return w
end
local function inCanvas(parent,widget,x,y,r,b)
 local s=parent:AddChildToCanvas(widget);s:SetAnchors({Minimum={X=x,Y=y},Maximum={X=r,Y=b}})
 s:SetOffsets({Left=0,Top=0,Right=0,Bottom=0});return s
end
local function card(parent,name,path,labelValue,x,y,w,h)
 local b=border(parent,name,{R=0,G=0,B=0,A=0},0)
 local slot=parent:AddChildToCanvas(b);slot:SetPosition({X=x,Y=y});slot:SetSize({X=w,Y=h})
 local layer=new('CanvasPanel',b,name..'Layer');b:SetContent(layer)
 local portrait=image(layer,name..'Portrait',path);inCanvas(layer,portrait,.02,0,.98,1)
 if not labelValue then emptyViews[#emptyViews+1]=b;return end
 local plate=border(layer,name..'NamePlate',{R=.008,G=.009,B=.010,A=1},0)
 inCanvas(layer,plate,.475,.845,.875,.985);plate:SetVisibility(4)
 local clip=new('CanvasPanel',layer,name..'NameClip');clip:SetClipping(1);clip:SetVisibility(4)
 inCanvas(layer,clip,.49,.858,.865,.975)
 local label=text(clip,name..'Name',labelValue,15);label:SetAutoWrapText(false);label:SetVisibility(4)
 local ns=clip:AddChildToCanvas(label);ns:SetAutoSize(true);ns:SetPosition({X=0,Y=0})
 local frame=image(layer,name..'Frame',profiles.root..'/Assets/CardSelected.png')
 inCanvas(layer,frame,0,-.015,1,1.015);frame:SetVisibility(4)
 return {widget=b,bg=b,text=label,frame=frame,nameClip=clip}
end
rebuildModelList=function(preferred)
 modelList:ClearChildren();models={};modelViews={};emptyViews={};selected=1
 rosterLayout=lattice.new(#profiles.list)
 if valid(listHeader)then listHeader:SetText(FText(string.format('%s  /  %02d',T('catalog'),#profiles.list)))end
 for copy=0,lattice.copies-1 do
 for slotIndex=1,rosterLayout.total do
  local i=slotIndex-lattice.leading;local p=profiles.list[i];local box=rosterLayout.slot(slotIndex,copy)
  if p and i>=1 then
   local path=p.directory and p.directory..'/UI/Portrait.png' or profiles.root..'/Assets/Original.png'
   if p.ui and type(p.ui.portrait)=='string' and p.ui.portrait:match('^[a-zA-Z0-9_][a-zA-Z0-9_/-]*%.png$') and not p.ui.portrait:find('..',1,true)then path=p.directory..'/'..p.ui.portrait end
   local row=card(modelList,'Model'..copy..'_'..i,path,locale.profileName(p),box.x,box.y,box.w,box.h)
   row.profile=p;row.index=i;local index=i;row.run=function()apply(index)end
   modelViews[#modelViews+1]=row
   if copy==lattice.center then models[i]=row;if preferred==p.id then selected=i end end
  else card(modelList,'EmptySlot'..copy..'_'..slotIndex,profiles.root..'/Assets/EmptySlot.png',nil,box.x,box.y,box.w,box.h)end
 end
 end
 local size=modelList:GetParent();if valid(size)then size:SetHeightOverride(rosterLayout.contentHeight)end
 lastScrolledSelection=selected;rosterScroll:SetScrollOffset(rosterLayout.initial(selected))
end
local scanning=false
function M.rescan()
 if not opened or scanning then return end;scanning=true
 setFooter(T('scanning'))
 jobs.after(50,function()
  local ok,why=pcall(function()
   local current=appearance.current();local preferred=models[selected] and models[selected].profile.id
   profiles.reload()
   -- Removing an active folder does not silently select another model.
   if not profiles.byId[current.id]then profiles.byId[current.id]=current;table.insert(profiles.list,current)end
   profiles.current=current
   if cinematics then cinematics.refresh()end
   if preview and type(preview.reloadSettings)=='function'then preview.reloadSettings()end
   if opened then
    rebuildModelList(preferred);rebuildDetails();refreshModels()
    setFooter(T('scanned'))
   end
  end)
  scanning=false
  if not ok then log(why);setFooter(T('scan_failed')..tostring(why))end
 end)
end
local function open()
 if not appearance.hasPlayer()then log('Enter a playable save before opening');return end
 -- Cooked resource additions require a game restart anyway. The startup catalog
 -- is authoritative; opening a panel must never spawn a directory-list shell
 -- or touch media/config files synchronously. Movie recheck remains explicit.
 log('Opening cached catalog; no directory or media scan')
 controller=context.getController();assert(valid(controller),'Local player controller unavailable')
 generation=generation+1;selected=1;actionIndex=1;focus='models'
 root=new('UserWidget',controller,'Root');local tree=new('WidgetTree',root,'Tree');root.WidgetTree=tree
 local scale=new('ScaleBox',tree,'ViewportScale');tree.RootWidget=scale;scale:SetStretch(2);scale:SetStretchDirection(0)
 local design=new('SizeBox',scale,'DesignSize');design:SetWidthOverride(1920);design:SetHeightOverride(1080);scale:SetContent(design)
 canvas=new('CanvasPanel',design,'Canvas');design:SetContent(canvas)
 -- Menu-local 30 Hz rendering; no world lookup, directory scan or movie scan.
 background=image(canvas,'AnimatedBackdrop',profiles.root..'/Assets/Backdrop.png');place(background,-.16,-.16,1.16,1.16)
 local veil=border(canvas,'BottomShade',{R=.005,G=.006,B=.006,A=.38});place(veil,0,.78,1,1)
 previewImage=new('Image',canvas,'LiveCharacter');place(previewImage,-.03,.10,.55,1.13):SetZOrder(10);previewImage:SetVisibility(4)
 preview=require('preview_scene');local ok,why=pcall(function()return preview.open(controller,previewImage)end);previewOK=ok
 if ok and transitions and transitions.isBusy()then preview.suspend()end
 if not ok then
  log('Preview unavailable: '..tostring(why));pcall(preview.close);previewImage:SetRenderOpacity(0)
  -- Visible fallback keeps the actual game scene. It never substitutes a still portrait.
  background:SetRenderOpacity(.25)
 end
 local top=new('VerticalBox',canvas,'BackArea');place(top,.035,.028,.105,.10):SetZOrder(30)
 backRow=button(top,'Back','↶  Esc',M.close,42);backRow.bg:SetBrushColor({R=.55,G=.015,B=.005,A=1})
 place(text(canvas,'Brand','PBZ  /  WARDROBE',15,C.white),.12,.045,.42,.08)
 listHeader=text(canvas,'ListHeader','',12,C.muted);place(listHeader,.41,.10,.68,.14):SetZOrder(30)
 rosterScroll=new('ScrollBox',canvas,'DiagonalRoster');place(rosterScroll,.37,0,.715,1):SetZOrder(15)
 rosterScroll:SetScrollBarVisibility(1);rosterScroll:SetAllowOverscroll(false)
 rosterScroll:SetAnimateWheelScrolling(true);rosterScroll:SetWheelScrollMultiplier(1.2)
 -- Slate composes these inverse shears in its own paint/hit-test pass. The
 -- native Y scroll is transformed diagonally with no Lua X catch-up frame.
 rosterScroll:SetRenderTransformPivot({X=0,Y=0});rosterScroll:SetRenderShear({X=lattice.angle,Y=0})
 local extent=new('SizeBox',rosterScroll,'RosterExtent');extent:SetWidthOverride(662);rosterScroll:AddChild(extent)
 modelList=new('CanvasPanel',extent,'RosterCanvas');extent:SetContent(modelList)
 modelList:SetRenderTransformPivot({X=0,Y=0});modelList:SetRenderShear({X=-lattice.angle,Y=0})
 rebuildModelList(appearance.current().id)
 local detailScroll=new('ScrollBox',canvas,'DetailsScroll');place(detailScroll,.71,.33,.86,.91):SetZOrder(20)
 detailScroll:SetScrollBarVisibility(1)
 detailExtent=new('SizeBox',detailScroll,'DetailsExtent');detailExtent:SetHeightOverride(450);detailScroll:AddChild(detailExtent)
 detailBox=new('CanvasPanel',detailExtent,'Details');detailExtent:SetContent(detailBox)
 liveLabel=text(canvas,'LiveLabel',T('live'),12,C.muted);place(liveLabel,.035,.87,.40,.90)
 footer=text(canvas,'Footer','',11,C.muted);place(footer,.035,.95,.95,.99):SetZOrder(30)
 shaderTitle=text(canvas,'ShaderStatusTitle','',12,C.white);shaderTitle:SetAutoWrapText(false);shaderTitle:SetVisibility(4);place(shaderTitle,.035,.902,.55,.925):SetZOrder(30)
 shaderDetail=text(canvas,'ShaderStatusDetail','',11,C.muted);shaderDetail:SetAutoWrapText(false);shaderDetail:SetVisibility(4);place(shaderDetail,.035,.927,.58,.948):SetZOrder(30)
 pcall(function()root:SetIsFocusable(true)end)
 opened=true;rebuildDetails();refreshModels();root:AddToViewport(19000)
 oldCursor=controller.bShowMouseCursor
 ModRef:SetSharedVariable('PBZWardrobePanelRoot',root);ModRef:SetSharedVariable('PBZWardrobePanelController',controller)
 ModRef:SetSharedVariable('PBZWardrobePanelOldCursor',oldCursor==true)
 controller:SetIgnoreMoveInput(true);moveHeld=true;controller:SetIgnoreLookInput(true);lookHeld=true;controller.bShowMouseCursor=true
 local lib=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
 assert(valid(lib),'Input mode library unavailable')
 -- UIOnly consumes unhandled mouse events instead of forwarding them to the
 -- pawn's attack bindings. UE4SS hotkeys continue to handle this native panel.
 lib:SetInputMode_UIOnlyEx(controller,root,0,true)
 menuEpoch=menuEpoch+1;local epoch=menuEpoch;local frame=0;local wrapCount=0
 local function menuFrame()
  if not opened or epoch~=menuEpoch then return end
  frame=frame+1
  -- Deliberate slow translation (not a barely perceptible small orbit).
  local phase=(frame/30/16)%2;local pan=(phase<=1 and phase or 2-phase)*170-85
  if valid(background)then background:SetRenderTranslation({X=pan,Y=-pan*math.tan(math.rad(16))})end
  if valid(rosterScroll)and valid(modelList)then
   local offset=rosterScroll:GetScrollOffset();local wrapped=rosterLayout.normalize(offset)
   if settleFrames>0 then
    settleFrames=settleFrames-1
    if settleFrames==0 then rosterScroll:SetScrollAnimationInterpolationSpeed(15)end
   end
   if math.abs(wrapped-offset)>.1 then
    -- Native wheel interpolation otherwise visibly travels back across a
    -- whole cycle. Snap only the identical-copy rebase, then restore easing.
    rosterScroll:SetScrollAnimationInterpolationSpeed(1000000)
    rosterScroll:EndInertialScrolling();rosterScroll:SetScrollOffset(wrapped);settleFrames=3
    if wrapCount<8 then wrapCount=wrapCount+1;log('Roster wrapped '..wrapCount)end
   end
  end
  if valid(titleWidget)then
   local w=titleWidget:GetDesiredSize().X
   if type(w)=='number'and w>270 then
    local travel=w-270;local t=(frame/30)%(4+travel/28)
    titleWidget:SetRenderTranslation({X=-math.min(travel,math.max(0,(t-1.5)*28)),Y=0})
   end
  end
  for _,row in ipairs(modelViews)do
   local width=row.text:GetDesiredSize().X;local available=82
   if type(width)=='number' and width>available then
    local travel=width-available;local phase=(frame/30)%(4+travel/28)
    local offset=math.min(travel,math.max(0,(phase-1.5)*28))
    row.text:SetRenderTranslation({X=-offset,Y=0})
   end
  end
  if previewOK then
   local ok,why=pcall(preview.frame)
   if not ok then previewOK=false;log('Preview stopped: '..tostring(why));pcall(preview.close)end
  end
  jobs.after(33,menuFrame)
 end
 jobs.after(33,menuFrame)
 log('Opened Core 2.4.2 cyclic diagonal roster; '..#models..' profiles; isolated preview='..tostring(previewOK))
end
local pinned={}
local function bind(key,fn)
 local busy=false
 local wrapper=function()
  if busy then return end;busy=true
  jobs.after(0,function()jobs.after(150,function()busy=false end);fn()end)
 end
 pinned[#pinned+1]=fn;pinned[#pinned+1]=wrapper;RegisterKeyBind(key,wrapper)
end
function M.init(p,a)
 profiles=p;appearance=a;locale.init(p.root);context=require('player_context').new(appearance.playerCandidates);jobs=require('game_thread_queue').new(log)
 local function ready(kind,id)
  local p=id and profiles.byId[id]or appearance.current()
  if p and p.native_original then return true end
  local pc=context.getController();if not valid(pc)or not valid(pc.Pawn)then return false end
  local c=pc.Pawn.Mesh;if not valid(c)then return false end
  local mesh=c:GetSkinnedAsset()
  if not valid(mesh)or not p or not mesh:GetFullName():find(p.mesh,1,true)then return false end
  local post=c.PostProcessAnimInstance
  if not valid(c:GetAnimInstance())or not valid(post)then return false end
  return type(p.post_process)=='string'and post:GetClass():GetFullName():find(p.post_process,1,true)~=nil
 end
 local paint=package.loaded.paint;local originalPaint
 if paint and type(paint.toggle)=='function'then
  originalPaint=paint._WardrobeRawToggle or paint.toggle;paint._WardrobeRawToggle=originalPaint
 end
 transitions=require('preview_transactions').new({
  after=jobs.after,
  suspend=function()if preview then preview.suspend()end end,
  resume=function()if opened and previewOK then preview.resume()end end,
  ready=ready,
  model=function(id)
   local current=appearance.current()
   if not(current and current.id==id and not(appearance.pendingSelection and appearance.pendingSelection()))then
    appearance.select(id);log('Model transaction submitted '..id)
   end
  end,
  modelSettled=function(id)
   for _,listener in ipairs(listeners)do local ok,why=pcall(listener);if not ok then log(why)end end
   if opened then rebuildDetails();refreshModels();setFooter(T('switching'));refreshShaderStatus()end
   log('Model transaction settled '..id)
  end,
  paint=function()if originalPaint then originalPaint()end end,
  done=function(n)if opened then setFooter(T('footer'));refreshShaderStatus()end;log('Preview transactions settled '..n)end,
  error=function(why)log('Transition stopped: '..why);if opened then setFooter(T('failed')..why);refreshShaderStatus()end end
 })
 if originalPaint then
  paint.toggle=function()
   if opened then transitions.togglePaint();setFooter(T('switching'));refreshShaderStatus()else originalPaint()end
  end
 end
 local cleanup=function()
  local previous=ModRef:GetSharedVariable('PBZWardrobePanelRoot');local pc=ModRef:GetSharedVariable('PBZWardrobePanelController')
  if valid(previous)then previous:RemoveFromParent()
   if valid(pc)then
    pc:SetIgnoreMoveInput(false);pc:SetIgnoreLookInput(false);pc.bShowMouseCursor=ModRef:GetSharedVariable('PBZWardrobePanelOldCursor')==true
    local lib=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary');if valid(lib)then lib:SetInputMode_GameOnly(pc,false)end
   end
  end
 end
 jobs.after(0,cleanup)
 if IsKeyBindRegistered(controls.wardrobe_key)then log(controls.wardrobe_name..' occupied; change controls.json');return end
 bind(controls.wardrobe_key,function()if opened then M.close()else local ok,why=pcall(open);if not ok then log(why);M.close()end end end)
 if not IsKeyBindRegistered(Key.ESCAPE)then bind(Key.ESCAPE,M.cancel)else log('Escape already occupied; existing owner preserved')end
 bind(Key.UP_ARROW,function()
  if not opened then return end
  if focus=='models' and #models>0 then selected=(selected-2)%#models+1;rebuildDetails()elseif #actions>0 then actionIndex=(actionIndex-2)%#actions+1 end
  refreshModels()
 end)
 bind(Key.DOWN_ARROW,function()
  if not opened then return end
  if focus=='models' and #models>0 then selected=selected%#models+1;rebuildDetails()elseif #actions>0 then actionIndex=actionIndex%#actions+1 end
  refreshModels()
 end)
 bind(Key.LEFT_ARROW,function()if opened then focus='models';refreshModels()end end)
 bind(Key.RIGHT_ARROW,function()if opened then focus='actions';refreshModels()end end)
 bind(Key.RETURN,function()if opened then if focus=='models' then apply(selected)elseif actions[actionIndex]then execute(actions[actionIndex].run)end end end)
 if not IsKeyBindRegistered(Key.F8)then bind(Key.F8,function()if opened then M.rescan()end end)else log('F8 already occupied; use the scan button')end
 bind(Key.LEFT_MOUSE_BUTTON,function()
  if not opened then return end
  -- Resolve hover after Slate processes the pointer event; no idle mouse scan.
  jobs.after(35,function()
   if not opened then return end
   if backRow and backRow.widget:IsHovered()then M.close();return end
   if scanRow and scanRow.widget:IsHovered()then M.rescan();return end
   for _,row in ipairs(modelViews)do if row.widget:IsHovered()then focus='models';apply(row.index);return end end
   for _,blank in ipairs(emptyViews)do if blank:IsHovered()then execute(function()folders.open(profiles.root,profiles.modelsRoot,false)end);return end end
   for i,row in ipairs(actions)do if row.widget:IsHovered()then focus='actions';actionIndex=i;execute(row.run);return end end
  end)
 end)
 local before=function()end;local after=function()if opened then M.close()end end
 pinned[#pinned+1]=before;pinned[#pinned+1]=after;RegisterHook('/Script/Engine.PlayerController:ClientRestart',before,after)
 log(controls.wardrobe_name..' bound; Core 2.4; menu-local animation only')
end
M._roots=pinned
return M
