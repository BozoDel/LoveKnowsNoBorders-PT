-- checks if there's a first argument (the file)
if arg[1] then
	-- opens the file given as first argument in reading mode
	input = io.open (arg[1], "r")

	-- checks if it's an xml
	-- it just checks extension, not xml validity
	if string.find (arg[1], ".*%.xml") then
		isXML = true
	end
end

-- checks for the second argument, the date
if arg[2] then
	-- and if it fits the format
	if string.find (arg[2], "%d%d%d%d%d%d%d%d") then
		isDate = true
		-- turn it into an actual number
		arg[2] = tonumber (arg[2])
	end
end	

-- if our file is not valid
if input == nil or isXML == nil or isDate == nil then
	print ([[Something went wrong.
Usage:
lua stripper.lua filepath date
The filepath must lead to a .xml file.
The date should be formated as a single number, yyyymmdd.]])

-- if it is valid
else
	local list = {} -- this will keep information on each page
	local lineCount = 0
	local state = "started"

	-- go through each line gathering information about where the pages start, end, and their timestamp
	for line in input:lines () do

		lineCount = lineCount + 1

		-- it may be the beginning of the search,
		-- or maybe a page has been found completely and it's time to start searching for the next one 
		if state == "started" or state == "page ended" then
			local search = string.find (line, "<page>")
			if search ~= nil then
				state = "page found"
				table.insert (list, {}) -- a new page
				list[#list].start = lineCount -- writes down the start position of the last added page
			end

		-- a page has been found, now we need its timestamp
		elseif state == "page found" then
			local search = string.find (line, "<timestamp>.-</timestamp>")
			if search ~= nil then
				state = "timestamp found"
				-- copies the timestamp in the yyyymmdd format
				local timestamp = string.gsub (line, "%s*<timestamp>(%d%d%d%d)%-(%d%d)%-(%d%d).*</timestamp>", "%1%2%3")
				list[#list].timestamp = tonumber (timestamp) -- adds the timestamp to the latest page
			end

		-- we found the timestamp, now we just have to close the page 
		elseif state == "timestamp found" then
			local search = string.find (line, "</page>")
			if search ~= nil then
				state = "page ended"
				list[#list].finish = lineCount -- records the page's ending position
			end
		end
	end

	-- these are only for printing the results
	kept = 0
	removed = 0

	-- checks if the pages are approved comparing their timestamp to arg[2]
	for page in ipairs (list) do
		if list[page].timestamp > arg[2] then
			list[page].approved = true
			kept = kept + 1
		else
			list[page].approved = false
			removed = removed + 1
		end
	end


	-- creates the output file with a name similar to the input file, but ending in .stripped.xml
	output = io.open (string.gsub (arg[1], "(.*)(%.xml)", "%1%.stripped%2"), "w")

	-- restarts the input
	input = io.open (arg[1], "r")

	lineCount = 0 -- restarts
	state = "started" -- restarts
	pageCount = 1

	for line in input:lines () do

		lineCount = lineCount + 1

		-- everything before the first page must be copied
		if lineCount < list[1].start then
			output:write (line.."\n")
			output:flush ()

		-- checks for the last lines of the file, that must be copied too
		elseif lineCount > list[#list].finish then
			output:write (line)

		-- copies everything from approved pages, ignores unapproved
		elseif lineCount >= list[pageCount].start then
			jujuba = "page "..pageCount.." , line "..lineCount
			if list[pageCount].approved == true then
				output:write (line.."\n")
				output:flush ()
			end
		end

		-- if we come to the end of a page, a new one must begin next
		if lineCount == list[pageCount].finish then
			-- make sure we won't refer to an inexisting page
			if pageCount < #list then
				pageCount = pageCount + 1
			end
		end
	end

	-- closes both files
	input:close ()
	output:close ()

	-- prints a success message
	print ("XML successfully stripped to "..string.gsub (arg[1], "(.*)(%.xml)", "%1%.stripped%2"))
	print (kept .. " pages kept, " .. removed .. ' removed.')
end
