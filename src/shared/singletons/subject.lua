local subject = {}
subject.__index = subject

function subject.new()
	local self = setmetatable({
		_observers = {},
		_data = nil
	}, subject)

	return self
end

function subject:attach(observer)
	table.insert(self._observers, observer)
end

function subject:detach(observer)
	for i, v in ipairs(self._observers) do
		if v == observer then
			table.remove(self._observers, i)
			break
		end
	end
end

function subject:notify(data)
	self._data = data
	for _, observer in ipairs(self._observers) do
		observer:update(self._data)
	end
end

return subject