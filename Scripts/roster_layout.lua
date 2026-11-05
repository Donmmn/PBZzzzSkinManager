-- One native sheared ScrollBox, inverse-sheared contents, five repeated cycles.
-- No runtime X compensation: Slate transforms scroll, clipping and hit testing.
local M={columns=3,width=220,height=220,columnStep=170,rowStep=240,
 slope=.28,angle=math.deg(math.atan(.28)),leading=6,viewport=1080,copies=3,center=1}
function M.new(count)
 local R={total=math.max(24,math.ceil((count+18)/3)*3)}
 R.period=R.total/3*M.rowStep
 R.contentHeight=R.period*M.copies
 function R.slot(index,copy)
  local z=index-1;local column=z%3;local row=math.floor(z/3)
  local y=-60+row*M.rowStep+(column==1 and -120 or 0)+(copy or 0)*R.period
  return {x=15+column*M.columnStep+M.slope*y,y=y,w=M.width,h=M.height}
 end
 function R.model(index,copy)return R.slot(index+M.leading,copy or 0)end
 function R.normalize(offset)return M.center*R.period+(offset-M.center*R.period)%R.period end
 function R.initial(index)
  if count<=6 then return M.center*R.period+30 end
  return R.normalize(M.center*R.period+R.model(index).y-260)
 end
 function R.reveal(index,offset)
  local box=R.model(index);local best,dist
  for copy=0,M.copies-1 do
   local y=box.y+copy*R.period
   local d=math.abs(y-offset-360)
   if not dist or d<dist then best=y;dist=d end
  end
  if best<offset+110 then return R.normalize(best-110)
  elseif best+M.height>offset+990 then return R.normalize(best+M.height-990)end
  return offset
 end
 return R
end
return M
