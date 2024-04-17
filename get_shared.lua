-- Shared file
local get_shared = {} :: {
    get_table: (self) -> table
}

function get_shared:boot(_shared)
    function self:get_table()
        return _shared
    end
end

function get_shared:run(_shared)
    function self:get_table()
        return _shared
    end
end

return get_shared