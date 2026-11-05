-- Wardrobe-private local-player lookup. No shared helper edits or actor scan.
local M={}
local function valid(object)
    local ok,result=pcall(function() return object~=nil and object:IsValid() end)
    return ok and result==true
end
local function same(a,b)
    local ok,result=pcall(function()
        return valid(a) and valid(b) and a:GetAddress()==b:GetAddress()
    end)
    return ok and result==true
end
function M.new(providePawns)
    assert(type(providePawns)=='function','Player candidate provider required')
    local C={};local lastError;local gameplay
    local function resolvePawn(pawn)
        if not valid(pawn) then lastError='Event/player pawn unavailable';return nil end
        local ok,pc=pcall(function()
            if not valid(gameplay) then gameplay=StaticFindObject('/Script/Engine.Default__GameplayStatics') end
            assert(valid(gameplay),'GameplayStatics unavailable')
            return gameplay:GetPlayerController(pawn,0)
        end)
        if not ok then lastError='Native local PlayerController lookup failed: '..tostring(pc);return nil end
        if not valid(pc) then lastError='Native local PlayerController unavailable';return nil end
        local read,owned=pcall(function() return pc.Pawn end)
        if not read then lastError='PlayerController.Pawn read failed: '..tostring(owned);return nil end
        if not same(owned,pawn) then lastError='Native local PlayerController.Pawn does not match candidate';return nil end
        lastError=nil;return pc
    end
    function C.getController()
        local ok,pawns=pcall(providePawns)
        if not ok then lastError='Player candidate provider failed: '..tostring(pawns);return nil end
        if type(pawns)~='table' then lastError='Player candidate provider returned '..type(pawns);return nil end
        if #pawns==0 then lastError='No known playable pawn is ready';return nil end
        for _,pawn in ipairs(pawns) do local pc=resolvePawn(pawn);if pc then return pc end end
        return nil
    end
    function C.isPlayer(pawn) return resolvePawn(pawn)~=nil end
    function C.lastError() return lastError end
    return C
end
return M
