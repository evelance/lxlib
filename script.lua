-- Hello
local b64 = (lhf and lhf.base64) or require "base64"
local mathx = (lhf and lhf.mathx) or require "mathx"
local coro = coroutine.create(function()
    local i = 0
    while true do
        i = i + 1
        coroutine.yield(mathx.cos(i))
    end
end)
local x = 123
for i = 1, 100 do
    x = math.sin(x) + select(2, coroutine.resume(coro))
end
return b64.encode(tostring(x))
