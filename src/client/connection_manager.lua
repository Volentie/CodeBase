local connection_manager = {}

function connection_manager:load_sync(core)
    local event_bus = core:get_singleton("event_bus")
    
    -- Create event bus for connection manager
    local bus = event_bus.new()

    local function on_subscribe_connection(service, event_name, handler)
        local connection = service[event_name]:Connect(handler)
        bus:subscribe("unsubscribe_connection", function()
            if connection.Connected then
                connection:Disconnect()
            end
        end)
    end

    bus:subscribe("subscribe_connection", on_subscribe_connection)
end

return connection_manager