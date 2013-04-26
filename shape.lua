-- Variable Setup
local argTable = {...}

local cmd_line = false
local cmd_line_resume = false
local cmd_line_cost_only = false
local chain_next_shape = false -- this tells goHome() where to end, if true it goes to (0, 0, positionz) if false it goes to (0, 0, 0)
local special_chain = false -- for certain shapes that finish where the next chained shape should start, goHome() will have no affect if true
local cost_only = false
local sim_mode = false

local blocks = 0
local fuel = 0

local positionx = 0
local positiony = 0
local positionz = 0
local facing = 0

local resupply = 0
local gps = 0
local choice = ""

local temp_prog_table = {}
local prog_table = {} --this is the LOCAL table!  used for local stuff only, and is ONLY EVER WRITTEN when sim_mode is FALSE
local prog_file_name = "ShapesProgressFile"


-- Utility functions

function writeOut(message)
  print(message)
end

function wrapmodules() --checks for and wraps turtle modules
	if peripheral.getType("left")=="resupply" then 
		rs=peripheral.wrap("left")
		resupply = 1
		return "resupply"
	elseif peripheral.getType("right")=="resupply" then
		rs=peripheral.wrap("right")
		resupply = 1
		return "resupply"
	elseif peripheral.getType("left")="modem" then
		rs=peripheral.wrap("right")
		if gps(locate)~=nil then
			gps = 1
		end
		return true
	elseif peripheral.getType("left")="modem" then
		rs=peripheral.wrap("right")
		if gps(locate)~=nil then
			gps = 1
		end
	else
		return false
	end
end

function linktorsstation() --links to rs station
	if rs.link() then
		return true
	else
		writeOut("Please put Resupply Station to the left of the turtle and press Enter to continue")
		io.read()
		linktorsstation()
	end
end

function compareResources()
	if (turtle.compareTo(1)==false) then
		turtle.drop()
	end
end

function checkResources()
	if resupply == 1 then
		if turtle.getItemCount(activeslot) <= 1 then
			while not(rs.resupply(1)) do
				os.sleep(0.5)
			end
		end
	else
		compareResources()
		while (turtle.getItemCount(activeslot) <= 1) do
			if (activeslot == 16) and (turtle.getItemCount(activeslot)<=1) then
				writeOut("Turtle is empty, please put building block in slots and press enter to continue")
				io.read()
				activeslot = 1
				turtle.select(activeslot)
			else
				activeslot = activeslot+1
				writeOut("Turtle slot almost empty, trying slot "..activeslot)
				turtle.select(activeslot)
			end
			compareResources()
			os.sleep(0.2)
		end
	end
end

function checkFuel()
	if (not(tonumber(turtle.getFuelLevel()) == nil)) then
		while turtle.getFuelLevel() < 50 do
			writeOut("Turtle almost out of fuel, pausing. Please drop fuel in inventory. And press enter.")
			io.read()
			turtle.refuel()
		end
	end
end

function placeBlock()
	-- Cost calculation mode - don't move
	ProgressUpdate()
	SimulationCheck()
	blocks = blocks + 1
	if cost_only then
		return
	end
	if turtle.detectDown() and not turtle.compareDown() then
		turtle.digDown()
	end
	checkResources()
	turtle.placeDown()
	ProgressUpdate()
	WriteProgress()
end

-- Navigation features
-- allow the turtle to move while tracking its position
-- this allows us to just give a destination point and have it go there

function turnRightTrack()
	ProgressUpdate()
	SimulationCheck()
	facing = facing + 1
	if facing >= 4 then
		facing = 0
	end
	if cost_only then
		return
	end
	turtle.turnRight()
	ProgressUpdate()
	WriteProgress()
end

function turnLeftTrack()
	ProgressUpdate()
	SimulationCheck()
	facing = facing - 1
	if facing < 0 then
		facing = 3
	end
	if cost_only then
		return
	end
	turtle.turnLeft()
	ProgressUpdate()
	WriteProgress()
end

function turnAroundTrack()
	turnLeftTrack()
	turnLeftTrack()
end

function turnToFace(direction)
	if direction >= 4 or direction < 0 then
		return false
	end
	while facing > direction do
		turnLeftTrack()
	end
	return true
end

function safeForward()
	ProgressUpdate()
	SimulationCheck()
	fuel = fuel + 1
	if cost_only then
		return
	end
	checkFuel()
	success = false
	while not success do
		success = turtle.forward()
		if not success then
			while turtle.detect() do
				if not turtle.dig() then
					print("Blocked attempting to move forward.")
					print("Please clear and press enter to continue.")
					io.read()
				end
			end
		end
	end
	if facing == 0 then
		positiony = positiony + 1
	elseif facing == 1 then
		positionx = positionx + 1
	elseif facing == 2 then
		positiony = positiony - 1
	elseif facing == 3 then
		positionx = positionx - 1
	end
end

function safeBack()
	ProgressUpdate()
	SimulationCheck()
	fuel = fuel + 1
	if cost_only then
		return
	end
	checkFuel()
	success = false
	while not success do
		success = turtle.back()
		if not success then
			turnAroundTrack()
			while turtle.detect() do
				if not turtle.dig() then
					break
				end
			end
			turnAroundTrack()
			success = turtle.back()
			if not success then
				print("Blocked attempting to move back.")
				print("Please clear and press enter to continue.")
				io.read()
			end
		end
	end
	if facing == 0 then
		positiony = positiony - 1
	elseif facing == 1 then
		positionx = positionx - 1
	elseif facing == 2 then
		positiony = positiony + 1
	elseif facing == 3 then
		positionx = positionx + 1
	end
end

function safeUp()
	ProgressUpdate()
	SimulationCheck()
	fuel = fuel + 1	
	positionz = positionz + 1
	if cost_only then
		return
	end
	checkFuel()
	success = false
	while not success do
		success = turtle.up()
		if not success then
			while turtle.detectUp() do
				if not turtle.digUp() then
					print("Blocked attempting to move up.")
					print("Please clear and press enter to continue.")
					io.read()
				end
			end
		end
	end
end

function safeDown()
	ProgressUpdate()
	SimulationCheck()
	fuel = fuel + 1
	positionz = positionz - 1
	if cost_only then
		return
	end
	checkFuel()
	success = false
	while not success do
		success = turtle.down()
		if not success then
			while turtle.detectDown() do
				if not turtle.digDown() then
					print("Blocked attempting to move down.")
					print("Please clear and press enter to continue.")
					io.read()
				end
			end
		end
	end
end

function moveY(targety)
	if targety == positiony then
		return
	end
	if (facing ~= 0 and facing ~= 2) then -- check axis
		turnRightTrack()
	end
	while targety > positiony do
		if facing == 0 then
			safeForward()
		else
			safeBack()
		end
		ProgressUpdate()
		WriteProgress()
	end
	while targety < positiony do
		if facing == 2 then
			safeForward()
		else
			safeBack()
		end
		ProgressUpdate()
		WriteProgress()
	end
end

function moveX(targetx)
	if targetx == positionx then
		return
	end
	if (facing ~= 1 and facing ~= 3) then -- check axis
		turnRightTrack()
	end
	while targetx > positionx do
		if facing == 1 then
			safeForward()
		else
			safeBack()
		end
		ProgressUpdate()
		WriteProgress()
	end
	while targetx < positionx do
		if facing == 3 then
			safeForward()
		else
			safeBack()
		end
		ProgressUpdate()
		WriteProgress()
	end
end

--this is unused right now.  Ignore. --I've added it to navigateTo() for the future - Happydude11209
function moveZ(targetz) --this function for now, will ONLY be used to CHECK AND RECORD PROGRESS.  It does NOTHING currently because targetz ALWAYS equals positionz
	if targetz == positionz then
		return
	end
	while targetz < positionz do
		safeDown()
		ProgressUpdate()
		WriteProgress()
	end
	while targetz > positionz do
		safeUp()
		ProgressUpdate()
		WriteProgress()
	end
end

-- I *HIGHLY* suggest formatting all shape subroutines to use the format that dome() uses;  specifically, navigateTo(x,y,z) placeBlock().  This should ensure proper "data recording" and also makes readability better
function navigateTo(targetx, targety, targetz, moveZFirst)
	targetz = targetz or positionz -- if targetz isn't used in the function call it defaults to its current z position, this should make it compatible with all current implementations of navigateTo()
	moveZFirst = moveZFirst or false -- default to moving z last, if true is passed as last argument, it moves vertically first
	
	if moveZFirst then
		moveZ(targetz)
	end
	
	if facing == 0 or facing == 2 then -- Y axis
		moveY(targety)
		moveX(targetx)
	else
		moveX(targetx)
		moveY(targety)
	end
	
	if not moveZFirst then
		moveZ(targetz)
	end
end

function goHome()
	if chain_next_shape then
		if not special_chain then
			navigateTo(0, 0) -- so another program can chain multiple shapes together to create bigger structures
		end
	else
		navigateTo(-1, -1, 0) -- so the user can collect the turtle when it is done1
	end
	turnToFace(0)
end

function round(toBeRounded, decimalPlace) --needed for hexagon and octagon
  local multiplier = 10^(decimalPlace or 0)
  return math.floor(toBeRounded * multiplier + 0.5) / multiplier
end

-- Shape Building Routines

function line(length)
	if length <= 0 then
		error("Error, length can not be 0")
	end
	local i
	for i=1, length do
		placeBlock()
		if i ~= length then
			safeForward()
		end
	end
end

function rectangle(depth, width)
	if depth <= 0 then
		error("Error, depth can not be 0")
	end
	if width <= 0 then
		error("Error, width can not be 0")
	end
	local lengths = {depth, width, depth, width }
	local j
	for j=1,4 do
		line(lengths[j])
		turnRightTrack()
	end
end

function square(width)
	rectangle(width, width)
end

function wall(length, height)
	local i
	local j
	for i = 1, length do
		for j = 1, height do
			placeBlock()
			if j < height then
				safeUp()
			end
		end
		safeForward()
		for j = 1, height-1 do
			safeDown()
		end
	end
	turnLeftTrack()
end

function platform(x, y)
	local forward = true
	for cy = 0, y-1 do
		for cx = 0, x-1 do
			if forward then
				navigateTo(cx, cy)
			else
				navigateTo(x - cx - 1, cy)
			end
			placeBlock()
		end
		if forward then
			forward = false
		else
			forward = true
		end
	end
end

function stair(width, height)
	turnRightTrack()
	local cx=1
	local cy=0
	local goforward=0
	while cy < height do
		while cx < width do
			placeBlock()
			safeForward()
			cx = cx + 1
		end
		placeBlock()
		cx = 1
		cy = cy + 1
		if cy < height then
			if goforward == 1 then
				turnRightTrack()
				safeUp()
				safeForward()
				turnRightTrack()
				goforward = 0
			else
				turnLeftTrack()
				safeUp()
				safeForward()
				turnLeftTrack()
				goforward = 1
			end
		end
	end
end

function circle(radius)
	width = radius * 2 + 1
	sqrt3 = 3 ^ 0.5
	boundary_radius = radius + 1.0
	boundary2 = boundary_radius ^ 2
	z = radius
	cz2 = (radius - z) ^ 2
	limit_offset_y = (boundary2 - cz2) ^ 0.5
	max_offset_y = math.ceil(limit_offset_y)
	-- We do first the +x side, then the -x side to make movement efficient
	for side = 0,1 do
		-- On the right we go from small y to large y, on the left reversed
		-- This makes us travel clockwise around each layer
		if (side == 0) then
			ystart = radius - max_offset_y
			yend = radius + max_offset_y
			ystep = 1
		else
			ystart = radius + max_offset_y
			yend = radius - max_offset_y
			ystep = -1
		end
		for y = ystart,yend,ystep do
			cy2 = (radius - y) ^ 2
			remainder2 = (boundary2 - cz2 - cy2)
			if remainder2 >= 0 then
				-- This is the maximum difference in x from the centre we can be without definitely being outside the radius
				max_offset_x = math.ceil((boundary2 - cz2 - cy2) ^ 0.5)
					-- Only do either the +x or -x side
				if (side == 0) then
					-- +x side
					xstart = radius
					xend = radius + max_offset_x
				else
					-- -x side
					xstart = radius - max_offset_x
					xend = radius - 1
				end
				-- Reverse direction we traverse xs when in -y side
				if y > radius then
					temp = xstart
					xstart = xend
					xend = temp
					xstep = -1
				else
					xstep = 1
				end
					for x = xstart,xend,xstep do
					cx2 = (radius - x) ^ 2
					distance_to_centre = (cx2 + cy2 + cz2) ^ 0.5
					-- Only blocks within the radius but still within 1 3d-diagonal block of the edge are eligible
					if distance_to_centre < boundary_radius and distance_to_centre + sqrt3 >= boundary_radius then
						offsets = {{0, 1, 0}, {0, -1, 0}, {1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}}
						for i=1,6 do
							offset = offsets[i]
							dx = offset[1]
							dy = offset[2]
							dz = offset[3]
							if ((radius - (x + dx)) ^ 2 + (radius - (y + dy)) ^ 2 + (radius - (z + dz)) ^ 2) ^ 0.5 >= boundary_radius then
								-- This is a point to use
								navigateTo(x, y)
								placeBlock()
								break
							end
						end
					end
				end
			end
		end
	end
end

function dome(typus, radius)
	-- Main dome and sphere building routine
	width = radius * 2 + 1
	sqrt3 = 3 ^ 0.5
	boundary_radius = radius + 1.0
	boundary2 = boundary_radius ^ 2
	if typus == "dome" then
		zstart = radius
	elseif typus == "sphere" then
		zstart = 0
	elseif typus == "bowl" then
		zstart = 0
	end
	if typus == "bowl" then
		zend = radius
	else
		zend = width - 1
	end
	
	-- This loop is for each vertical layer through the sphere or dome.
	for z = zstart,zend do
		if not cost_only and z ~= zstart then
			safeUp()
		end
		--writeOut("Layer " .. z)
		cz2 = (radius - z) ^ 2
		limit_offset_y = (boundary2 - cz2) ^ 0.5
		max_offset_y = math.ceil(limit_offset_y)
		-- We do first the +x side, then the -x side to make movement efficient
		for side = 0,1 do
			-- On the right we go from small y to large y, on the left reversed
			-- This makes us travel clockwise around each layer
			if (side == 0) then
				ystart = radius - max_offset_y
				yend = radius + max_offset_y
				ystep = 1
			else
				ystart = radius + max_offset_y
				yend = radius - max_offset_y
				ystep = -1
			end
			for y = ystart,yend,ystep do
				cy2 = (radius - y) ^ 2
				remainder2 = (boundary2 - cz2 - cy2)
				if remainder2 >= 0 then
					-- This is the maximum difference in x from the centre we can be without definitely being outside the radius
					max_offset_x = math.ceil((boundary2 - cz2 - cy2) ^ 0.5)
					-- Only do either the +x or -x side
					if (side == 0) then
						-- +x side
						xstart = radius
						xend = radius + max_offset_x
					else
						-- -x side
						xstart = radius - max_offset_x
						xend = radius - 1
					end
					-- Reverse direction we traverse xs when in -y side
					if y > radius then
						temp = xstart
						xstart = xend
						xend = temp
						xstep = -1
					else
						xstep = 1
					end

					for x = xstart,xend,xstep do
						cx2 = (radius - x) ^ 2
						distance_to_centre = (cx2 + cy2 + cz2) ^ 0.5
						-- Only blocks within the radius but still within 1 3d-diagonal block of the edge are eligible
						if distance_to_centre < boundary_radius and distance_to_centre + sqrt3 >= boundary_radius then
							offsets = {{0, 1, 0}, {0, -1, 0}, {1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}}
							for i=1,6 do
								offset = offsets[i]
								dx = offset[1]
								dy = offset[2]
								dz = offset[3]
								if ((radius - (x + dx)) ^ 2 + (radius - (y + dy)) ^ 2 + (radius - (z + dz)) ^ 2) ^ 0.5 >= boundary_radius then
									-- This is a point to use
									navigateTo(x, y)
									placeBlock()
									break
								end
							end
						end
					end
				end
			end
		end
	end
end

function hexagon(sideLength)
	local changex = sideLength / 2
	local changey = round(math.sqrt(3) * changex, 0)
	changex = round(changex, 0)
	local counter = 0
	
	navigateTo(changex, 0)
	
	for currentSide = 1, 6 do
		counter = 0
		
		if currentSide == 1 then
			for placed = 1, sideLength do
				navigateTo(positionx + 1, positiony)
				placeBlock()
			end
		elseif currentSide == 2 then
			navigateTo(positionx, positiony + 1)
			while positiony <= changey do
				if counter == 0 or counter == 2 or counter == 4 then
					navigateTo(positionx + 1, positiony)
				end
				placeBlock()
				navigateTo(positionx, positiony + 1)
				counter = counter + 1
				if counter == 5 then
					counter = 0
				end
			end
		elseif currentSide == 3 then
			while positiony <= (2 * changey) do
				if counter == 0 or counter == 2 or counter == 4 then
					navigateTo(positionx - 1, positiony)
				end
				placeBlock()
				navigateTo(positionx, positiony + 1)
				counter = counter + 1
				if counter == 5 then
					counter = 0
				end
			end
		elseif currentSide == 4 then
			for placed = 1, sideLength do
				navigateTo(positionx - 1, positiony)
				placeBlock()
			end
		elseif currentSide == 5 then
		navigateTo(positionx, positiony - 1)
			while positiony >= changey do
				if counter == 0 or counter == 2 or counter == 4 then
					navigateTo(positionx - 1, positiony)
				end
				placeBlock()
				navigateTo(positionx, positiony - 1)
				counter = counter + 1
				if counter == 5 then
					counter = 0
				end
			end
		elseif currentSide == 6 then
			while positiony >= 0 do
				if counter == 0 or counter == 2 or counter == 4 then
					navigateTo(positionx + 1, positiony)
				end
				placeBlock()
				navigateTo(positionx, positiony - 1)
				counter = counter + 1
				if counter == 5 then
					counter = 0
				end
			end
		end
	end
end

function octagon(sideLength)
	local sideLength2 = sideLength - 1
	local change = round(sideLength2 / math.sqrt(2), 0)
	
	navigateTo(change, 0)
	
	for currentSide = 1, 8 do
		if currentSide == 1 then
			for placed = 1, sideLength2 do
				navigateTo(positionx + 1, positiony)
				placeBlock()
			end
		elseif currentSide == 2 then
			for placed = 1, change do
				navigateTo(positionx + 1, positiony + 1)
				placeBlock()
			end
		elseif currentSide == 3 then
			for placed = 1, sideLength2 do
				navigateTo(positionx, positiony + 1)
				placeBlock()
			end
		elseif currentSide == 4 then
			for placed = 1, change do
				navigateTo(positionx - 1, positiony + 1)
				placeBlock()
			end
		elseif currentSide == 5 then
			for placed = 1, sideLength2 do
				navigateTo(positionx - 1, positiony)
				placeBlock()
			end
		elseif currentSide == 6 then
			for placed = 1, change do
				navigateTo(positionx - 1, positiony - 1)
				placeBlock()
			end
		elseif currentSide == 7 then
		for placed = 1, sideLength2 do
				navigateTo(positionx, positiony - 1)
				placeBlock()
			end
		elseif currentSide == 8 then
			for placed = 1, change do
				navigateTo(positionx + 1, positiony - 1)
				placeBlock()
			end
		end
	end
end

-- Previous Progress Resuming, Sim Functions, Command Line, and File Backend

-- will check for a "progress" file.
function CheckForPrevious() 
	if fs.exists(prog_file_name) then
		return true
	else
		return false
	end
end

-- creates a progress file, containing a serialized table consisting of the shape type, shape input params, and the last known x, y, and z coords of the turtle (beginning of build project)
function ProgressFileCreate() 
	if not CheckForPrevious() then
		fs.makeDir(prog_file_name)
		return true
	else
		return false
	end
end

-- deletes the progress file (at the end of the project, also at beginning if user chooses to delete old progress)
function ProgressFileDelete() 
	if fs.exists(prog_file_name) then
		fs.delete(prog_file_name)
		return true
	else 
		return false
	end
end

-- to read the shape params from the file.  Shape type, and input params (e.g. "dome" and radius)
function ReadShapeParams()
	-- TODO unneeded for now, can just use the table elements directly
end

function WriteShapeParams(...) -- the ... lets it take any number of arguments and stores it to the table arg{} | This is still unused anywhere
	local paramTable = arg
	local param_name = "param"
	local param_name2 = param_name
	for i,v in ipairs(paramTable) do -- iterates through the args passed to the function, ex. paramTable[1] i = 1 so param_name2 should be "param1", tested and works!
		param_name2 = param_name .. i
		temp_prog_table[param_name2] = v
		prog_table[param_name2] = v
	end
	-- actually can't do anything right now, because all the param-gathering in Choicefunct() uses different variables -- Working on adding this in (since this can take any number of inputs)
end

-- function to write the progress to the file (x, y, z)
function WriteProgress()
	local prog_file
	local prog_string = ""
	--writeOut(textutils.serialize(prog_table))
	--ProgressFileCreate()
	--writeOut(prog_string)
	if sim_mode == false and cost_only == false then
		prog_string = textutils.serialize(prog_table) -- put in here to save processing time when in cost_only
		prog_file = fs.open(prog_file_name,"w")
		prog_file.write(prog_string)
		prog_file.close()
	end
	
end

-- reads progress from file (shape, x, y, z, facing, blocks, param1, param2, param3)
function ReadProgress()
	local prog_file = fs.open(prog_file_name, "r")
	local read_prog_table = textutils.unserialize(prog_file.readAll())
	prog_file.close()
	return read_prog_table
end

-- compares the progress read from the file to the current sim progress.  needs all four params 
function CompareProgress() -- return boolean
	local prog_table_in = prog_table
	local read_prog_table = ReadProgress()
	if (prog_table_in.shape == read_prog_table.shape and prog_table_in.x == read_prog_table.x and prog_table_in.y == read_prog_table.y and prog_table_in.blocks == read_prog_table.blocks and prog_table_in.facing == read_prog_table.facing) then
		writeOut("All caught up!")
		return true -- we're caught up!
	else
		return false -- not there yet...
	end
end

function SetSimFlags(b)
	sim_mode = b
	cost_only = b
	if cmd_line_cost_only then
		cost_only = true
	end
end

function SimulationCheck()  
	if sim_mode then
		if CompareProgress() then
			SetSimFlags(false) -- if we're caught up, un-set flags
		else
			SetSimFlags(true)  -- if not caught up, just re-affirm that the flags are set
		end
	end
end

function ContinueQuery()
	return false -- to disable the resume functionality until it is fixed, allows us to update on pastebin for the new shapes.
	-- if cmd_line_resume then
		-- return true
	-- else
		-- if not cmd_line then
			-- writeOut("Do you want to continue the last job?")
			-- local yes = io.read()
			-- if yes == "y" then
				-- return true
			-- else
				-- return false
			-- end
		-- end
	-- end
end

function ProgressUpdate()  -- this ONLY updates the local table variable.  Writing is handled above. -- I want to change this t allow for any number of params
	prog_table = {shape = choice, param1 = temp_prog_table.param1, param2 = temp_prog_table.param2, param3 = temp_prog_table.param3, x = positionx, y = positiony, facing = facing, blocks = blocks}
end

 -- Command Line
function checkCommandLine() --true if arguments were passed
	if #argTable > 0 then
		cmd_line = true
		return true
	else
		cmd_line = false
		return false
	end
end

function needsHelp() -- true if -h is passed
	for i, v in pairs(argTable) do
		if v == "-h" or v == "-help" or v == "--help" then
			return true
		else
			return false
		end
	end
end

function setFlagsFromCommandLine() -- sets count_only, chain_next_shape, and sim_mode
	for i, v in pairs(argTable) do
		if v == "-c" or v == "-cost" or v == "--cost" then
			cost_only = true
			cmd_line_cost_only = true
			writeOut("Cost only mode")
		end
		if v == "-z" or v == "-chain" or v == "--chain" then
			chain_next_shape = true
			writeOut("Chained shape mode")
		end
		if v == "-r" or v == "-resume" or v == "--resume" then
			cmd_line_resume = true
			writeOut("Resuming")
		end
	end
end

function setTableFromCommandLine() -- sets prog_table and temp_prog_table from command line arguments
	prog_table.shape = argTable[1]
	temp_prog_table.shape = argTable[1]
	local param_name = "param"
	local param_name2 = param_name
	for i = 2, #argTable do
		local add_on = tostring(i - 1)
		param_name2 = param_name .. add_on
		prog_table[param_name2] = argTable[i]
		temp_prog_table[param_name2] = argTable[i]
	end
end

-- Menu, drawing and Mainfunctions

function Choicefunct()
	if sim_mode == false and cmd_line == false then -- if we are NOT resuming progress
		choice = io.read()
		choice = string.lower(choice) -- all checks are aginst lower case words so this is to ensure that
		temp_prog_table = {shape = choice}
		prog_table = {shape = choice}
		if choice == "next" then
			WriteMenu2()
			choice = io.read()
			choice = string.lower(choice) -- all checks are aginst lower case words so this is to ensure that
		end
		if choice == "end" or choice == "exit" then
			writeOut("Goodbye.")
			return
		end
		if choice == "help" then
			showHelp()
			return
		end
		if choice == "credits" then
			showCredits()
			return
		end
		writeOut("Building a "..choice)
		writeOut("Want to just calculate the cost? [y/n]")
		local yes = io.read()
		if yes == 'y' then
			cost_only = true
		end
	elseif sim_mode == true then -- if we ARE resuming progress
		temp_prog_table = ReadProgress()
		choice = temp_prog_table.shape
		choice = string.lower(choice) -- all checks are aginst lower case words so this is to ensure that
	elseif cmd_line == true then -- if running from command line
		choice = temp_prog_table.shape
		choice = string.lower(choice) -- all checks are aginst lower case words so this is to ensure that
		writeOut("Building a "..choice)
	end	
	if not cost_only then
		turtle.select(1)
		activeslot = 1
		if turtle.getItemCount(activeslot) == 0 then
			if resupply then
				writeOut("Please put building blocks in the first slot.")
			else
				writeOut("Please put building blocks in the first slot (and more if you need them)")
			end
			while turtle.getItemCount(activeslot) == 0 do
				os.sleep(2)
			end
		end
	else
		activeslot = 1
	end
	
	if choice == "rectangle" then
		local h = 0
		local v = 0
		if sim_mode == false and cmd_line == false then
			writeOut("How deep do you want it to be?")
			h = io.read()
			writeOut("How wide do you want it to be?")
			v = io.read()
		elseif sim_mode == true or cmd_line == true then
			h = temp_prog_table.param1
			v = temp_prog_table.param2
		end
		h = tonumber(h)
		v = tonumber(v)
		temp_prog_table.param1 = h
		temp_prog_table.param2 = v
		prog_table = {param1 = h, param2 = v} -- THIS is here because we NEED to update the local table!
		rectangle(h, v)
	end
	if choice == "square" then
		local s
		if sim_mode == false and cmd_line == false then
			writeOut("How long does it need to be?")
			s = io.read()
		elseif sim_mode == true or cmd_line == true then
			s = temp_prog_table.param1
		end
		s = tonumber(s)
		temp_prog_table.param1 = s
		prog_table = {param1 = s}
		square(s)
	end
	if choice == "line" then
		local ll = 0
		if sim_mode == false and cmd_line == false then
			writeOut("How long does the line need to be?")
			ll = io.read()
		elseif sim_mode == true or cmd_line == true then
			ll = temp_prog_table.param1
		end
		ll = tonumber(ll)
		temp_prog_table.param1 = ll
		prog_table = {param1 = ll}
		line(ll)
	end
	if choice == "wall" then
	local wl = 0
	local wh = 0
		if sim_mode == false and cmd_line == false then
			writeOut("How long does it need to be?")
			wl = io.read()
			writeOut("How high does it need to be?")
			wh = io.read()
		elseif sim_mode == true or cmd_line == true then
			wl = temp_prog_table.param1
			wh = temp_prog_table.param2
		end			
		wl = tonumber(wl)
		wh = tonumber(wh)
		temp_prog_table.param1 = wl
		temp_prog_table.param2 = wh
		if  wh <= 0 then
			error("Error, the height can not be zero")
		end
		if wl <= 0 then
			error("Error, the length can not be 0")
		end
		prog_table = {param1 = wl, param2 = wh}
		wall(wl, wh)
	end
	if choice == "platform" then
		local x = 0
		local y = 0
		if sim_mode == false and cmd_line == false then
			writeOut("How wide do you want it to be?")
			x = io.read()
			writeOut("How long do you want it to be?")
			y = io.read()
		elseif sim_mode == true or cmd_line == true then
			x = temp_prog_table.param1	
			y = temp_prog_table.param2		
		end		
		x = tonumber(x)
		y = tonumber(y)
		temp_prog_table.param1 = x
		temp_prog_table.param2 = y
		prog_table = {param1 = x, param2 = y}
		platform(x, y)
	end
	if choice == "stair" then
		local x = 0
		local y = 0
		if sim_mode == false and cmd_line == false then
			writeOut("How wide do you want it to be?")
			x = io.read()
			writeOut("How high do you want it to be?")
			y = io.read()
		elseif sim_mode == true or cmd_line == true then
			x = temp_prog_table.param1
			y = temp_prog_table.param2
		end
		x = tonumber(x)
		y = tonumber(y)
		temp_prog_table.param1 = x
		temp_prog_table.param2 = y
		prog_table = {param1 = x, param2 = y}
		stair(x, y)
		special_chain = true
	end
	if choice == "cuboid" then
		local cl = 0
		local ch = 0
		local hi = 0
		local hollow = ""
		if sim_mode == false and cmd_line == false then
			writeOut("How wide does it need to be?")
			cl = io.read()
			writeOut("How deep does it need to be?")
			ch = io.read()
			writeOut("How high does it need to be?")
			hi = io.read()
			writeOut("Do you want it to be hollow? (y/n)")
			hollow = io.read()
		elseif sim_mode == true or cmd_line == true then
			cl = temp_prog_table.param1
			ch = temp_prog_table.param2
			hi = temp_prog_table.param3
			hollow = temp_prog_table.param4
		end
		cl = tonumber(cl)
		ch = tonumber(ch)
		hi = tonumber(hi)
		temp_prog_table.param1 = cl
		temp_prog_table.param2 = ch
		temp_prog_table.param3 = hi
		temp_prog_table.param4 = hollow
		if hi < 3 then
			hi = 3
		end
		if cl < 3 then
			cl = 3
		end
		if ch < 3 then
			ch = 3
		end	
		prog_table = {param1 = cl, param2 = ch, param3 = hi}
		platform(cl, ch)		
		while (facing > 0) do
			turnLeftTrack()
		end
		turnAroundTrack()
		if ((ch % 2)==0) then
			-- this is for reorienting the turtle to build the walls correct in relation to the floor and ceiling
			turnLeftTrack()
		end
		if not(hollow == "n") then
			for i = 1, hi-2 do
				safeUp()
				if ((ch % 2)==0) then -- this aswell
				rectangle(cl, ch)
				else
				rectangle(ch, cl)
				end
			end
		else
			for i=1,hi-2 do
				safeUp()
				platform(cl,ch)
			end
		end
		safeUp()
		platform(cl, ch)
	end
	if choice == "1/2-sphere" or choice == "1/2 sphere" then
		local rad = 0
		local half = ""
		if sim_mode == false and cmd_line == false then
			writeOut("What radius do you need it to be?")
			rad = io.read()
			writeOut("What half of the sphere do you want to build?(bottom/top)")
			half = io.read()
		elseif sim_mode == true or cmd_line == true then
			rad = temp_prog_table.param1
			half = temp_prog_table.param2
		end	
		rad = tonumber(rad)
		temp_prog_table.param1 = rad
		temp_prog_table.param2 = half
		prog_table = {param1 = rad, param2 = half}
		half = string.lower(half)
		if half == "bottom" then
			dome("bowl", rad)
		else
			dome("dome", rad)
		end
	end
	if choice == "dome" then
		local rad = 0
		if sim_mode == false and cmd_line == false then
			writeOut("What radius do you need it to be?")
			rad = io.read()
		elseif sim_mode == true or cmd_line == true then
			rad = temp_prog_table.param1
		end	
		rad = tonumber(rad)
		temp_prog_table.param1 = rad
		prog_table = {param1 = rad}
		dome("dome", rad)
	end
	if choice == "bowl" then
		local rad = 0
		if sim_mode == false and cmd_line == false then
			writeOut("What radius do you need it to be?")
			rad = io.read()
		elseif sim_mode == true or cmd_line == true then
			rad = temp_prog_table.param1
		end	
		rad = tonumber(rad)
		temp_prog_table.param1 = rad
		prog_table = {param1 = rad}
		dome("bowl", rad)
	end
	if choice == "circle" then
		local rad = 0
		if sim_mode == false and cmd_line == false then
			writeOut("What radius do you need it to be?")
			rad = io.read()
		elseif sim_mode == true or cmd_line == true then
			rad = temp_prog_table.param1
		end
		rad = tonumber(rad)
		temp_prog_table.param1 = rad
		prog_table = {param1 = rad}
		circle(rad)
	end
	if choice == "cylinder" then
		local rad = 0
		local height = 0
		if sim_mode == false and cmd_line == false then
			writeOut("What radius do you need it to be?")
			rad = io.read()
			writeOut("What height do you need it to be?")
			height = io.read()
		elseif sim_mode == true or cmd_line == true then
			rad = temp_prog_table.param1
			height = temp_prog_table.param2
		end
		rad = tonumber(rad)
		height = tonumber(height)
		temp_prog_table.param1 = rad
		temp_prog_table.param2 = height
		prog_table = {param1 = rad, param2 = height}
		for i = 1, height do
			circle(rad)
			safeUp()
		end
	end
	if choice == "pyramid" then
		local width = 0
		local hollow = ""
		if sim_mode == false and cmd_line == false then
			writeOut("What width/depth do you need it to be?")
			width = io.read()
			writeOut("Do you want it to be hollow [y/n]?")
			hollow = io.read()
		elseif sim_mode == true or cmd_line == true then
			width = temp_prog_table.param1
			hollow = temp_prog_table.param2
		end
		width = tonumber(width)
		temp_prog_table.param1 = width
		temp_prog_table.param2 = hollow
		prog_table = {param1 = width, param2 = hollow}
		if hollow == 'y' or hollow == 'yes' or hollow == 'true' then
			hollow = true
		else
			hollow = false
		end
		height = math.ceil(width / 2)
		for i = 1, height do
			if hollow then
				rectangle(width, width)
			else
				platform(width, width)
				navigateTo(0,0)
				while facing ~= 0 do
					turnRightTrack()
				end
			end
			if i ~= height then
				safeUp()
				safeForward()
				turnRightTrack()
				safeForward()
				turnLeftTrack()
				width = width - 2
			end
		end
	end
	if choice == "sphere" then
		local rad = 0
		if sim_mode == false and cmd_line == false then
			writeOut("What radius do you need it to be?")
			rad = io.read()
		elseif sim_mode == true or cmd_line == true then
			rad = temp_prog_table.param1
		end
		rad = tonumber(rad)
		temp_prog_table.param1 = rad
		prog_table = {param1 = rad}
		dome("sphere", rad)
	end
	if choice == "hexagon" then
		local length = 0
		if sim_mode == false and cmd_line == false then
			writeOut("How long do you need each side to be?")
			length = io.read()
		elseif sim_mode == true or cmd_line == true then
			length = temp_prog_table.param1
		end
		length = tonumber(length)
		temp_prog_table.param1 = length
		prog_table = {param1 = length}
		hexagon(length)
	end
	if choice == "octagon" then
		local length = 0
		if sim_mode == false and cmd_line == false then
			writeOut("How long do you need each side to be?")
			length = io.read()
		elseif sim_mode == true or cmd_line == true then
			length = temp_prog_table.param1
		end
		length = tonumber(length)
		temp_prog_table.param1 = length
		prog_table = {param1 = length}
		octagon(length)
	end
	if choice == "6-prism" or choice == "6 prism" then
		local length = 0
		local height = 0
		if sim_mode == false and cmd_line == false then
			writeOut("How long do you need each side to be?")
			length = io.read()
			writeOut("What height do you need it to be?")
			height = io.read()
		elseif sim_mode == true or cmd_line == true then
			length = temp_prog_table.param1
			height = temp_prog_table.param2
		end
		length = tonumber(length)
		height = tonumber(height)
		temp_prog_table.param1 = length
		temp_prog_table.param2 = height
		prog_table = {param1 = length, param2 = height}
		for i = 1, height do
			hexagon(length)
			safeUp()
		end
	end
	if choice == "8-prism" or choice == "8 prism" then
		local length = 0
		local height = 0
		if sim_mode == false and cmd_line == false then
			writeOut("How long do you need each side to be?")
			length = io.read()
			writeOut("What height do you need it to be?")
			height = io.read()
		elseif sim_mode == true or cmd_line == true then
			length = temp_prog_table.param1
			height = temp_prog_table.param2
		end
		length = tonumber(length)
		height = tonumber(height)
		temp_prog_table.param1 = length
		temp_prog_table.param2 = height
		prog_table = {param1 = length, param2 = height}
		for i = 1, height do
			octagon(length)
			safeUp()
		end
	end
	goHome() -- After all shape building has finished
	writeOut("Done") -- Saves a few lines when put here rather than in each if statement
end

function WriteMenu()
	term.clear()
	term.setCursorPos(1, 1)
	writeOut("Shape Maker 1.5 by Keridos/Happydude/pokemane")
	if resupply==1 then
		writeOut("Resupply Mode Active")
	else
		writeOut("")
	end
	if not cmd_line then
		writeOut("What should be built? [page 1/2]");
		writeOut("next for page 2")
		writeOut("+---------+-----------+-------+-------+")
		writeOut("| square  | rectangle | wall  | line  |")
		writeOut("| cylinder| platform  | stair | cuboid|")
		writeOut("| pyramid | 1/2-sphere| circle| next  |")
		writeOut("+---------+-----------+-------+-------+")
		writeOut("")
	end
end

function WriteMenu2()
	term.clear()
	term.setCursorPos(1, 1)
	writeOut("Shape Maker 1.5 by Keridos/Happydude/pokemane")
	if resupply==1 then
		writeOut("Resupply Mode Active")
	else
		writeOut("")
	end
	writeOut("What should be built [page 2/2]?");
	writeOut("")
	writeOut("+---------+-----------+-------+-------+")
	writeOut("| hexagon | octagon   | help  |       |")
	writeOut("| 6-prism | 8-prism   | end   |       |")
	writeOut("| sphere  | credits   |       |       |")
	writeOut("+---------+-----------+-------+-------+")
	writeOut("")
end

function showHelp()
	writeOut("Usage: shape [shape-type [param1 param2 param3 ...]] [-c] [-h] [-z] [-r]")
	writeOut("-c: Activate cost only mode")
	writeOut("-h: Show this page")
	writeOut("-z: Set chain_next_shape to true, lets you chain together multiple shapes")
	io.read() -- pause here
	writeOut("-r: Resume the last shape if there are any (Note: This is disabled until we can iron out the kinks")
	writeOut("shape-type can be any of the shapes in the menu")
	writeOut("After shape-type input any of the paramaters that you know, the rest should be asked for")
	io.read() -- pause here, too
end

function showCredits()
	writeOut("Credits for the shape builder:")
	writeOut("Based on work by Michiel,Vliekkie and Aeolun")
	writeOut("Sphere/dome code by pruby")
	writeOut("Additional improvements by Keridos,Happydude and pokemane")
	io.read() -- pause here, too
end

function main()
	if wrapmodules()=="resupply" then
		linktorsstation()
	end
	if checkCommandLine() then
		if needsHelp() then
			showHelp()
			return -- close the program after help info is shown
		end
		setFlagsFromCommandLine()
		setTableFromCommandLine()
	end
	if CheckForPrevious() then  -- will check to see if there was a previous job, and if so, ask if the user would like to re-initialize to current progress status
		if not ContinueQuery() then -- if I don't want to continue
			ProgressFileDelete()
			SetSimFlags(false) -- just to be safe
			WriteMenu()
			Choicefunct()
		else	-- if I want to continue
			SetSimFlags(true)
			Choicefunct()
		end
	else
		SetSimFlags(false)
		WriteMenu()
		Choicefunct()
	end
	if (blocks~=0) and (fuel~=0) then -- do not show on help or credits page or when selecting end
		print("Blocks used: " .. blocks)
		print("Fuel used: " .. fuel)
	end
	ProgressFileDelete() -- removes file upon successful completion of a job, or completion of a previous job.
	prog_table = {}
	temp_prog_table = {}
end

main()
