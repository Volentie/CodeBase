local event_bus = {}
event_bus.__index = event_bus

function event_bus.new()
    local self = setmetatable({}, event_bus)
    self.events = {}
    return self
end

function event_bus:subscribe(event_name, handler)
    if not self.events[event_name] then
        self.events[event_name] = {}
    end
    table.insert(self.events[event_name], handler)
end

function event_bus:unsubscribe(event_name, handler)
    if self.events[event_name] then
        for i, h in ipairs(self.events[event_name]) do
            if h == handler then
                table.remove(self.events[event_name], i)
                break
            end
        end
    end
end

function event_bus:unsubscribe_all()
    self.events = {}
end

function event_bus:publish(event_name, ...)
    if self.events[event_name] then
        for _, handler in ipairs(self.events[event_name]) do
            handler(...)
        end
    end
end

return event_bus