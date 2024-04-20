local meta = {}

function meta:load_sync(core)
    local event_bus = core:get_singleton("event_bus")
    
    -- Create event bus for connection manager
    local connection_manager = event_bus.new()

    local function on_subscribe_connection(service, event_name, handler)
        local connection = service[event_name]:Connect(handler)
        connection_manager:subscribe("unsubscribe_connection", function()
            if connection.Connected then
                connection:Disconnect()
            end
        end)
    end

    connection_manager:subscribe("subscribe_connection", on_subscribe_connection)
end

return meta