local M={language='zh'};local root
local S={
 zh={original='魂 · 游戏原皮',live='当前角色',catalog='角色档案',empty='添加角色',
  switching='正在更新角色预览…',scan='扫描角色目录',scanning='正在扫描角色目录…',scanned='扫描完成；新增资源包需要重启游戏',
  scan_failed='扫描失败：',failed='操作失败：',footer='Esc / F10 关闭　↑ ↓ 选择　Enter 应用　F5 着色　F8 扫描',
  cinema_missing='大招动画 · 点击导入',cinema_on='大招动画 · 已开启',cinema_off='大招动画 · 已关闭',
  preview='检测并预览动画',missing='未找到 Ultimate.mp4，请导入到该角色目录',
  unavailable='动画功能不可用',apply_first='请先应用此外观',reload='原皮将在重载存档后生效',language='中文',refill='充满大招能量',refill_done='大招能量已充满'},
 en={original='Soul · Original',live='LIVE CHARACTER',catalog='CHARACTER ARCHIVE',empty='ADD CHARACTER',
  switching='Updating character preview…',scan='Scan character folders',scanning='Scanning character folders…',scanned='Scan complete; restart for new packages',
  scan_failed='Scan failed: ',failed='Action failed: ',footer='Esc / F10 Close   ↑ ↓ Select   Enter Apply   F5 Shader   F8 Scan',
  cinema_missing='Cinematic · Import video',cinema_on='Ultimate cinematic · ON',cinema_off='Ultimate cinematic · OFF',
  preview='Recheck and preview',missing='Ultimate.mp4 not found in this character folder',
  unavailable='Cinematics unavailable',apply_first='Apply this appearance first',reload='Reload save to apply Original',language='English',refill='Refill ultimate',refill_done='Ultimate energy full'}
}
function M.init(path)
 root=path;local f=io.open(root..'/State/Language.txt','rb')
 if f then local v=f:read('*a'):match('^%s*(%a+)');f:close();if S[v]then M.language=v end end
end
function M.get(key)return assert(S[M.language][key],key)end
function M.toggle()
 M.language=M.language=='zh'and'en'or'zh'
 local f=assert(io.open(root..'/State/Language.txt','wb'));assert(f:write(M.language..'\n'));f:close()
end
function M.profileName(p)
 if p.native_original then return M.get('original')end
 local ui=type(p.ui)=='table'and p.ui or {};local names=type(ui.names)=='table'and ui.names or {}
 local value=names[M.language]or ui['name_'..M.language]
 if type(value)=='string'and #value>0 then return value end
 if M.language=='en'then
  local known={seed='Seed',yeshunguang='Ye Shunguang',miyabi_base='Hoshimi Miyabi',miyabi_native='Hoshimi Miyabi'}
  if known[p.id]then return known[p.id]end
 end
 return p.name:gsub('（PBZ原生动作）',''):gsub('%(PBZ native animations%)','')
end
return M
