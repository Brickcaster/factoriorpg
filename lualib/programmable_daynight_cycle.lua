TAU = 6.28318530718 -- this is not the correct form to declare a global variable. Will fix once everything else works

function programmable_daynight_cycle(event)
	local daylength_ticks = 2000 --The day-night cycle length in ticks. Can be any value.
	local stepsize_ticks = 59 	 -- warning! stepsize_ticks cannot be over 25000!
	if not (game.tick % stepsize_ticks == 0) then -- Replace with 'on_nth_tick' once I figure out how to do that
		return
	end
	local time_ratio = (daylength_ticks/25000)
	game.surfaces[1].daytime = 0
	local current_time = (game.tick / daylength_ticks)
	local time_step = (stepsize_ticks/daylength_ticks)
	game.print("current time: " .. current_time .. " time step " .. time_step)
	
	local current_curve_start = {x = current_time, y = 0.15 + ((math.sin(TAU * current_time)+1)*0.425)}
	local current_curve_end = {x = current_time + (time_step * time_ratio), y = 0.15 + ((math.sin(TAU * (current_time + time_step))+1)*0.425)}
	local y_top_start, y_top_end = {x = -999999999, y = 1}, {x = 999999999, y = 1}
	local y_bot_start, y_bot_end = {x = -999999999, y = 0.15}, {x = 999999999, y = 0.15}
	
    local top_point = intersection(current_curve_start, current_curve_end, y_top_start, y_top_end)
	local bot_point = intersection(current_curve_start, current_curve_end, y_bot_start, y_bot_end)
	-- resetting to assumed safe values before poking further
	game.surfaces[1].dusk = -999999999
	game.surfaces[1].dawn = 999999999
	game.surfaces[1].evening = -999999998
	game.surfaces[1].morning = 999999998	
	if(top_point < bot_point) then -- dusk -> evening
		game.surfaces[1].evening = bot_point - current_time
		game.surfaces[1].dusk = top_point - current_time
	else -- morning -> dawn
		game.surfaces[1].morning = bot_point - current_time
		game.surfaces[1].dawn = top_point - current_time
	end
end

-- take all this and put it into a seperate module once everything else works
-- code stolen from https://rosettacode.org/wiki/Find_the_intersection_of_two_lines#Lua
function intersection (s1, e1, s2, e2)
  local d = (s1.x - e1.x) * (s2.y - e2.y) - (s1.y - e1.y) * (s2.x - e2.x)
  local a = s1.x * e1.y - s1.y * e1.x
  local b = s2.x * e2.y - s2.y * e2.x
  local x = (a * (s2.x - e2.x) - (s1.x - e1.x) * b) / d
  local y = (a * (s2.y - e2.y) - (s1.y - e1.y) * b) / d
  return x--, y
end

Event.register(defines.events.on_tick, programmable_daynight_cycle)