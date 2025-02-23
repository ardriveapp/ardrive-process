local AOEvent = require("ao_event")
local utils = require("utils")

--- @alias ARDRIVEEvent AOEvent

--- Convenience factory function for pre populating analytic and msg fields into AOEvents
--- @param msg table
--- @param initialData table<string, any> Optional initial data to populate the event with.
--- @returns ARDRIVEEvent
local function ARDRIVEEvent(msg, initialData)
	local event = AOEvent({
		Cron = msg.Cron or false,
		Cast = msg.Cast or false,
	})
	event:addFields(msg.Tags or {})
	event:addFieldsIfExist(msg, { "From", "Timestamp", "Action" })
	event:addField("Message-Id", msg.Id)
	event:addField("From-Formatted", utils.formatAddress(msg.From))
	if initialData ~= nil then
		event:addFields(initialData)
	end
	return event
end

return ARDRIVEEvent
