local observer = {}
observer.__index = observer

function observer.new(callback)
	local self = setmetatable({}, observer)
	self.callback = callback
	return self
end

function observer:update(data)
	self.callback(data)
end

return observer