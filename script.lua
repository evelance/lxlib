-- Hello
local coro = coroutine.create(function()
    local i = 0
    while true do
        i = i + 1
        coroutine.yield(i)
    end
end)
local x = 123
for i = 1, 100 do
    x = math.sin(x) + select(2, coroutine.resume(coro))
end
return x
