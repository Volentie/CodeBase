local observer = {
	__index = function(self, k)
		return self[k]
	end
}

function observer:load_async()
	function observer.new()
		local self = setmetatable({}, observer)
		return self
	end

	function observer:update(data, ...)
		print(...)
		print("\nobserver received data:", data)
	end
end

return observer