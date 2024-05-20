-- 1D cellular automata 
-- v1.0 imminent gloom
--
--
-- adapted from elcos
-- by zebra
--
-- ...
-- bright buttons sets state
-- other buttons sets rule from context
--
-- every two rows creates a 4-state
-- gate stream from crow
--
-- e1 bpm
-- e2 rule
-- e3 shifts the window
-- 
-- k1 not used
-- k2 randomize state
-- k3 clear state

g = grid.connect()

local br_high = 10
local br_low = 4
local br_text = 15
local br_ca = 3
local br_window = 15

-- set voltage range for each output on crow
local gate_low = 0
local gate_a = 5
local gate_b = 8
local gate_high = 10

elca = require 'elca'
ca = elca.new()
ca.rule = 30
ca.offset = 60
ca.bound_mode_l = ca.bound_wrap
ca.bound_mode_r = ca.bound_wrap

past = {}
moment = {}

--[[
re = metro.init()
re.time = 1.0/24
re.event = function() redraw() end
re:start()
]]--

local name = 'rule'
local true_name = 'rule'

local rule_delay = 0

params:add_control('rule', 'rule', controlspec.new(1, 256, 'lin', 1, 30, '', 1/256, true))
params:set_action('rule', function(x) ca.rule = x end)

params:add_control('offset', 'offset', controlspec.new(0, 128, 'lin', 1, 60, '', 1/128, true))
params:set_action('offset', function(x) ca.offset = x - 1 end)

function forget_the_past()
	-- creates and zeros a 64x128 memory matrix
	-- the ca is 128 wide, and we store 64 past states
	-- big enough to fill the screen
	for y = 1, 128 do moment[y] = 0 end
	for x = 1, 64 do past[x] = moment end
end

function waits_for_no_man()
	while true do
		clock.sync (1/4)
		local last_window = ca.offset
		ca.offset = 0 
		moment = ca:window(128)
		ca.offset = last_window
		table.insert(past, moment)
		table.remove(past, 1)
		crow_output()
		redraw()
		ca:update()
	end
end

function modulo(num, mod)
	-- % to index 1-based lists
	return ((num - 1) % mod) + 1
end

function crow_output()
	local moment = past[64]
	function get_moment(y) return moment[modulo(y + ca.offset, 128)] end
	local c = 1
	for y = 1, 8, 2 do
		local gate
		if get_moment(y) == 0 and get_moment(y + 1) == 0 then gate = gate_low end
		if get_moment(y) == 1 and get_moment(y + 1) == 0 then gate = gate_a end
		if get_moment(y) == 0 and get_moment(y + 1) == 1 then gate = gate_b end
		if get_moment(y) == 1 and get_moment(y + 1) == 1 then gate = gate_high end
		crow.output[c].volts = gate
		c = c + 1
	end
end

function init()
	forget_the_past()
	time = clock.run(waits_for_no_man)
	
	ca.state[64] = 1
end

function g.key(x, y, z)
	if z == 1 then
		y = modulo(y + ca.offset, 128)
		if x == 16 then
			ca.state[y] = (ca.state[y] + 1) % 2
		else
			-- we can set states from all columns since the memory extends beyond the grid
			-- otherwise 1-4 would be wrong
			x = x + 48
			local moment = past[x - 1]
			local l
			local r
			if y == 1 then l = moment[128] else l = moment[y - 1] end
			if y == 128 then r = moment[1] else r = moment[y + 1] end
			local c = moment[y]
			local val
			if past[x][y] == 1 then val = 0 else val = 1 end
			past[x][y] = val
			ca.state[y] = c
  			ca:set_rule_by_state(past[x][y], l, c, r)
   			params:set('rule', ca.rule)
		end
	end
end

function key(n, z)
	if z == 1 then
		if n == 2 then
			for n = 1, 128 do ca.state[n] = math.random(0,1) end
		end		
		if n == 3 then
			ca:clear()
			forget_the_past()
		end
	end
end

function enc(n, d)
	if n == 1 then
		params:delta('clock_tempo', d)
		true_name = 'clock_tempo'
		name = 'bpm'
	end
	if n == 2 then
		params:delta('rule', d)
		true_name = 'rule'
		name = 'rule'
		end
	if n == 3 then
		params:delta('offset', d)
	end
	redraw()
end

function redraw()
	draw_norns()
	draw_grid()
end

function draw_ca()
	screen.level(br_ca)
	for n = 1, 64 do
		for m = 1, 128 do
			if past[n][m] == 1 then screen.pixel(m, 64 - n) end
		end		
	end
	screen.fill()
end

function draw_norns()
	screen.clear()
	screen.aa(1)
	screen.blend_mode(0)
		
	draw_ca()
	
	screen.level(br_window)
	for n = 1, 8 do screen.pixel(modulo(n + ca.offset, 128), 0) end
	for n = 1, 8 do screen.pixel(modulo(n + ca.offset, 128), 63) end
	screen.fill()

	screen.level(br_text)
	screen.font_face(11)
	screen.font_size(28)
	
	screen.move(6,56)
	screen.text(name .. ': ' .. params:get(true_name))
	if name ~= 'rule' then
		rule_delay = rule_delay + 1
	end
	if rule_delay == 10 then
		name = 'rule'
		true_name = name
		rule_delay = 0
	end
	
	screen.update()
end

function draw_grid()
	local br
	for x = 1, 16 do
		if x == 16 then br = br_high else br = br_low end
		for y = 1, 8 do
			if past[x + 48][modulo(y + ca.offset, 128)] == 1 then z = br else z = 0 end
			g:led(x, y, z)
		end
	end
	g:refresh()
end

function cleanup()

end