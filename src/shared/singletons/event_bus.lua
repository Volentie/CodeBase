local event_bus = {}
event_bus.__index = event_bus

local shared_events = {}

function event_bus.new()
    local self = setmetatable({}, event_bus)
    return self
end

function event_bus:subscribe(event_name, handler)
    if not shared_events[event_name] then
        shared_events[event_name] = {}
    end
    table.insert(shared_events[event_name], handler)
end

function event_bus:unsubscribe(event_name, handler)
    if shared_events[event_name] then
        for i, h in ipairs(shared_events[event_name]) do
            if h == handler then
                table.remove(shared_events[event_name], i)
                break
            end
        end
    end
end

function event_bus:publish(event_name, ...)
    if shared_events[event_name] then
        for _, handler in ipairs(shared_events[event_name]) do
            handler(...)
        end
    end
end

function event_bus:unsubscribe_all()
    shared_events = {}
end

return event_bus
