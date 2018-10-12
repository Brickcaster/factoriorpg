--When loading a save, these will be overwritten by what the save was generated with.
global.STARTING_RADIUS = settings.global["starting radius"].value
global.EASY_ORE_RADIUS = settings.global["simple ore radius"].value
global.DANGORE_MODE = settings.global["dangore mode"].value

--dangOreus, a scenario by Mylon
--MIT Licensed

require "perlin" --Perlin Noise.

ORE_SCALING = 0.78 --Exponent for ore amount.
LINEAR_SCALAR = 12 -- For ore amount.
--DANGORE_MODE = 2 -- 1 == Random, 2 == Perlin

if MODULE_LIST then
	module_list_add("dangOreus")
end

--Sprinkle ore everywhere
function gOre(event)
    --Ensure we've done our init
    if not global.perlin_ore_list then divOresity_init() end

    local oldores = event.surface.find_entities_filtered{type="resource", area=event.area}
    local oils = {}
    for k, v in pairs(oldores) do
        if v.prototype.resource_category == "basic-solid" then
            v.destroy()
        else
			table.insert(oils, v)
		end
    end

    --Generate our random once for the whole chunk.
    local rand = math.random()

    --What kind of chunk are we generating?  Biased, ore, or random?
    --Check our global table of nearby chunks.
    --If any nearby chunks use the biased table, we must use the matching that ore to determine ore type.
    -- chunk_type starts off as a table in case it borders multiple biased patches, then we collapse it after checking neighbors
    local chunk_type = {}
    local biased = false
    local chunkx = event.area.left_top.x
    local chunky = event.area.left_top.y

    local function check_chunk_bias(x,y)
        if global.ore_chunks[x] then
            if global.ore_chunks[x][y] then
                if global.ore_chunks[x][y].biased then
                    table.insert(chunk_type, global.ore_chunks[x][y].type)
                end
            end
        end
    end

    local function check_chunk_type(x,y)
        if global.ore_chunks[x] then
            if global.ore_chunks[x][y] then
                table.insert(chunk_type, global.ore_chunks[x][y].type)
                return
            end
        end
        -- Still here? Insert random.
        table.insert(chunk_type, "random")
    end

    --starting from top, clockwise
    check_chunk_bias(chunkx, chunky-32)
    check_chunk_bias(chunkx+32, chunky)
    check_chunk_bias(chunkx, chunky+32)
    check_chunk_bias(chunkx-32, chunky)

    --Collapse table
    if #chunk_type > 0 then
        chunk_type = chunk_type[math.random(#chunk_type)]
        -- chance this chunk is also biased.
        if math.random() < 0.25 then
            biased = true
        end
    else
        --Repeat process for non-biased chunks
        check_chunk_type(chunkx, chunky-32)
        check_chunk_type(chunkx+32, chunky)
        check_chunk_type(chunkx, chunky+32)
        check_chunk_type(chunkx-32, chunky)

        chunk_type = chunk_type[math.random(#chunk_type)]
        --If type is not random, chance chunk is biased.
        --If type is random, chance chunk type is different.
        if chunk_type == "random" then
            if math.random() < 0.25 then
                chunk_type = global.diverse_ore_list[math.random(#global.diverse_ore_list)]
            end
        else
            if math.random() < 0.25 then
                biased = true
            end
        end
    end

    --Set global table with this type/bias
    if not global.ore_chunks[chunkx] then
        global.ore_chunks[chunkx] = {}
    end
    global.ore_chunks[chunkx][chunky] = {type=chunk_type, biased=biased}

    for x = event.area.left_top.x, event.area.left_top.x + 31 do
        for y = event.area.left_top.y, event.area.left_top.y + 31 do
            local bbox = {{ x, y}, {x+0.5, y+0.5}}
            if event.surface.get_tile(x,y).collides_with("ground-tile") and event.surface.count_entities_filtered{type="cliff", area=bbox} == 0 then
                local amount = (x^2 + y^2)^ORE_SCALING / LINEAR_SCALAR
                if x^2 + y^2 >= global.STARTING_RADIUS^2 then
                    --Build the ore list.  Uranium can only appear in uranium chunks.
                    local ore_list = {}
                    for k, v in pairs(global.easy_ore_list) do
                        table.insert(ore_list, v)
                    end
                    if not (chunk_type == "random") then
                        --Build the ore list.  non-baised chunks get 3 instances, biased chunks get 6.  Except uranium, which has no default instance in the table.
                        table.insert(ore_list, chunk_type)
                        --table.insert(ore_list, chunk_type)
                        if biased then
                            table.insert(ore_list, chunk_type)
                            table.insert(ore_list, chunk_type)
                            --table.insert(ore_list, chunk_type)
                        end
                        --game.print(serpent.line(ore_list))
                    end

                    local type
                    if global.DANGORE_MODE == 1 then
                        type = ore_list[math.random(#ore_list)]
                    else
                        --With noise
                        --Using Perlin noise.
                        --Using Fixed threshholds
                        -- local noise = perlin.noise(x,y)
                        -- if noise > 0.04 then
                        --     type = "iron-ore"
                        -- elseif noise > -0.18 then
                        --     type = "copper-ore"
                        -- elseif noise > -0.30 then
                        --     type = "stone"
                        -- elseif noise > -0.6 then
                        --     type = "coal"
                        -- else
                        --     type = "uranium-ore"
                        -- end

                        --Using auto threshholds
                        local noise = perlin.noise(x,y)
                        for k,v in pairs(global.perlin_ore_list) do
                            if noise < v[2] then
                                type = v[1]
                                break
                            end
                        end
                        if not type then
                            local _
                            _, type = next(global.perlin_ore_list)
                        end
                    end

                    event.surface.create_entity{name=type, amount=amount, position={x, y}, enable_tree_removal=false, enable_cliff_removal=false}
                end
            end
        end
    end

    --Ore blocks oil from rendering the resource radius.  Clean up any resources around oil.
	for k, v in pairs(oils) do
		local overlap = v.surface.find_entities_filtered{type="resource", area=v.bounding_box}
		for n, p in pairs(overlap) do
			if p.prototype.resource_category == "basic-solid" then
				p.destroy()
			end
		end
	end
end

--Auto-destroy non-mining drills.
function dangOre(event)
    if not (event.created_entity and event.created_entity.valid) then
        return
    end
    if event.created_entity.type == "mining-drill" or event.created_entity.type == "car" or not event.created_entity.health then
        return
    end
    --Some entities have no bounding box area.  Not sure which.
    if event.created_entity.bounding_box.left_top.x == event.created_entity.bounding_box.right_bottom.x or event.created_entity.bounding_box.left_top.y == event.created_entity.bounding_box.right_bottom.y then
        return
    end
    if settings.global["easy mode"].value then --Dificulty setting
		if event.created_entity.type == "transport-belt" or
		event.created_entity.type == "underground-belt" or
		event.created_entity.type == "splitter" or
		event.created_entity.type == "electric-pole" or
		event.created_entity.type == "container" or
		event.created_entity.type == "logistic-container" then
			return
		end
	end
    local last_user = event.created_entity.last_user
    local ores = event.created_entity.surface.count_entities_filtered{type="resource", area=event.created_entity.bounding_box}
    if ores > 0 then
        --Need to turn off ghosts left by dead buildings so construction bots won't keep placing buildings and having them blow up.
        local ttl = event.created_entity.force.ghost_time_to_live
        local force = event.created_entity.force
        event.created_entity.force.ghost_time_to_live = 0
        event.created_entity.die()
        force.ghost_time_to_live = ttl
        if last_user then
            last_user.print("Cannot build non-miners on resources!")
        end
    end
end

--Destroying chests causes any contained ore to spill onto the ground.
function ore_rly(event)
    local items = {"stone", "coal", "iron-ore", "copper-ore", "uranium-ore"}
    if event.entity.type == "container" or event.entity.type == "cargo-wagon" or event.entity.type == "logistic-container" or event.entity.type == "car" then
        --Let's spill all items instead.
        for i = 1, 10 do
            if event.entity.get_inventory(i) then
                for k,v in pairs(event.entity.get_inventory(i).get_contents()) do
                    event.entity.surface.spill_item_stack(event.entity.position, {name=k, count=v})
                end
            end
        end
        -- for k, v in pairs(items) do
        --     if event.entity.get_item_count(v) > 0 then
        --         event.entity.surface.spill_item_stack(event.entity.position, {name=v, count=event.entity.get_item_count(v)})
        --     end
        -- end
    end
end

--Unchart one random chunk per minute to keep the map remotely sane.
function unchOret(event)
    if not (event.tick % (60*60) == 0) then
        return
    end

    local chunks = {}
    for chunk in game.surfaces[1].get_chunks() do
        if game.forces.player.is_chunk_charted("1", {chunk.x, chunk.y}) then
            if not game.forces.player.is_chunk_visible("1", {chunk.x, chunk.y}) then
                table.insert(chunks, {x=chunk.x, y=chunk.y})
            end
        end
    end

    if #chunks > 0 then
        local chunk = chunks[math.random(#chunks)]
        game.forces.player.unchart_chunk({chunk.x, chunk.y}, "1")
    end
end

--Limit exploring
function flOre_is_lava(event)
    if not (event.tick % (300) == 31) then
        return
    end
    for n, p in pairs(game.connected_players) do
        if not p.character then --Spectator or admin
            return
        end
        if math.abs(p.position.x) > global.EASY_ORE_RADIUS or math.abs(p.position.y) > global.EASY_ORE_RADIUS then
            --Check for nearby ore.
            local count = p.surface.count_entities_filtered{type="resource", area={{p.position.x-10, p.position.y-10}, {p.position.x+10, p.position.y+10}}}
            if count > 350 then
                if p.vehicle then
                    p.surface.create_entity{name="acid-projectile-purple", target=p.vehicle, position=p.vehicle.position, speed=10}
                    p.vehicle.health = p.vehicle.health - 50
                else
                    p.surface.create_entity{name="acid-projectile-purple", target=p.character, position=p.character.position, speed=10}
                    p.character.health = p.character.health - 10
                end
            end
        end
    end
end

--Build the list of ores
function divOresity_init()
    --Each chunk picks a table to generate from.  Each table has either 3 copies of one ore, or 6 copies.
    global.easy_ore_list = {}
	global.diverse_ore_list = {}

    global.ore_chunks = {}

    global.perlin_ore_list = {}

    --These are depreciated.
    -- global.easy_ores = {}
    -- global.diverse_ores = {}

	for k,v in pairs(game.entity_prototypes) do
        if v.type == "resource" and v.resource_category == "basic-solid" and v.autoplace_specification then
            table.insert(global.diverse_ore_list, v.name)
            if v.mineable_properties.required_fluid == nil then
			    table.insert(global.easy_ore_list, v.name)
            end
		end
	end

    --Check to see if we're playing normal.  Marathon requires more copper.
    if game.difficulty_settings.recipe_difficulty == 0 then
        --This is a hack to make the ratios easier to handle.
        --This hack only makes sense for vanilla ores.
        local vanilla_ores = false
        for k,v in pairs(global.easy_ore_list) do
            if v == "iron-ore" then
                vanilla_ores = true
                break
            end
        end
        if vanilla_ores then
            --1:1:1:1 creates way too much copper, stone.  Coal at least can be liquefied.
            --This changes it to a 3:2:2:1 ratio
            --table.insert(global.diverse_ore_list, "iron-ore")
            table.insert(global.easy_ore_list, "iron-ore")
            table.insert(global.easy_ore_list, "iron-ore")
            table.insert(global.easy_ore_list, "copper-ore")
            table.insert(global.easy_ore_list, "coal")
        end
    end

    --Easy ores
    -- for k, v in pairs(global.easy_ore_list) do
    --     local ore = {}
    --     local biased = {}
    --     local random = {}
        
    --     for i = 1, 2 do
    --         table.insert(ore, v)
    --         table.insert(biased, v)
    --     end
    --     for i = 1, 3 do
    --         table.insert(biased, v)
    --     end
    --     for n, p in pairs(global.easy_ore_list) do
    --         table.insert(ore, p)
    --         table.insert(biased, p)
    --         table.insert(random, p)
    --     end
    --     table.insert(global.easy_ores, ore)
    --     table.insert(global.easy_ores, biased)
    --     table.insert(global.easy_ores, random)
    -- end

    -- --Diverse ores
    -- for k, v in pairs(global.diverse_ore_list) do
    --     local ore = {}
    --     local biased = {}
    --     local random = {}
        
    --     for i = 1, 2 do
    --         table.insert(ore, v)
    --         table.insert(biased, v)
    --     end
    --     for i = 1, 3 do
    --         table.insert(biased, v)
    --     end
    --     for n, p in pairs(global.diverse_ore_list) do
    --         table.insert(ore, p)
    --         table.insert(biased, p)
    --         table.insert(random, p)
    --     end
    --     table.insert(global.diverse_ores, ore)
    --     table.insert(global.diverse_ores, biased)
    --     table.insert(global.diverse_ores, random)
    -- end

    --Perlin Ore list generation
    local ore_ranking_raw = {}
    local ore_ranking = {}
    local ore_total = 0
    
    for k,v in pairs(global.diverse_ore_list) do
        local autoplace = game.surfaces[1].map_gen_settings.autoplace_controls[v]
        if autoplace then
            local adding = 0
            if autoplace.frequency == "very-low" then
                adding = 1
            elseif autoplace.frequency == "low" then
                adding = 2
            elseif autoplace.frequency == "normal" then
                adding = 3
            elseif autoplace.frequency == "high" then
                adding = 4
            elseif autoplace.frequency == "very-high" then
                adding = 5
            end
            if adding > 0 then
                local amount = adding * game.entity_prototypes[v].autoplace_specification.coverage
                if game.entity_prototypes[v].mineable_properties.required_fluid then
                    table.insert(ore_ranking_raw, 1, {name=v, amount=amount})
                else
                    table.insert(ore_ranking_raw, {name=v, amount=amount})
                end
                ore_total = ore_total + amount
            end
        end
    end

    --Debug
    --log(serpent.block(ore_ranking_raw))

    --Calculate ore distribution from 0 to 1.
    local last_key = 0
    local ore_ranking_size = 0 --Essentially #ore_ranking_raw
    for k,v in pairs(ore_ranking_raw) do
        local key = last_key + v.amount / ore_total
        last_key = key

        if key == 1 then key = 0.9999999 end
        --ore_ranking[key] = v.name
        table.insert(ore_ranking, {v.name, key})
        --ore_ranking_size = ore_ranking_size + 1
        --Debug
        --log("Ore: " .. v.name .. " portion: " .. key)
        --According to this, at this stage, uranium should be 2% of all ore.
    end

    --This next bit requires a lerp
    --Returns x3
    local function lerp(x1, x2, dy, y3)
        return y3 * (x2-x1)/dy + x1
    end

    --Now do a pass to scale these numbers according to perlin.MEASURED distribution
    local last_ranking_key = 0
    last_key = -1
    local previous_iter = -1
    local count = 0
    for k,v in pairs(ore_ranking) do
        --local range = k - last_ranking_key -- This is the percentage that should appear of this ore type
        local range = v[2] - last_ranking_key -- This is the percentage that should appear of this ore type
        last_ranking_key = v[2]
        local measured_sum = 0 -- This is the range that our perlin steps cover, from last_key to n
        --log("For ore " .. v[1] .. " using range " .. range)
        -- count = count + 1 -- This is so we do something special on the last one.  Rounding errors may cause the last ore to not be inserted otherwise.
        --local perlin_key
        --The last ore will never get used.  Let's determine if we're at the end of the table and write the last key there.
        for n, p in pairs(perlin.MEASURED) do
            --Skip keys we've already iterated over
            if n > last_key then
                measured_sum = measured_sum + p
                --If I were to get fancy, I could add a LERP here for finer control of perlin_ore_list keys.
                --if count < ore_ranking_size then            
                    if measured_sum > range then
                        --log("measured sum is " .. measured_sum .. " and key range is " .. n - last_key)
                        local x3 = lerp(previous_iter, n, p, range - (measured_sum - p) )
                        table.insert(global.perlin_ore_list, {v[1], x3})
                        --perlin_ore_list[n] = name
                        last_key = n
                        previous_iter = n
                        break
                    end
                --else
                --    perlin_ore_list[0.9999999] = v
                    --game.print(0.88 - n .. "," .. range) --Debug.
                    --break
                --end
                previous_iter = n
            end
        end

        --Are we still here?  Insert at the last key.
        if not global.perlin_ore_list[k] then
            table.insert(global.perlin_ore_list, {v[1], 1})
        end
        
        --perlin_ore_list[0.9999999] = v

        -- perlin_ore_list[math.abs(k)^0.5 * sign] = v
        -- perlin_ore_list[k] = v
    end

    -- For debugging
    --log(serpent.block(perlin_ore_list))
    -- global.a = perlin_ore_list
    -- game.print(serpent.line(ore_list))
    --game.print(serpent.line(ore_ranking))
    -- Test perlin/measured.  Should return 1.
    -- local sum = 0
    -- for k,v in pairs(perlin.MEASURED) do
    --     sum = sum + v
    -- end
    -- game.print(sum)
    -- Tested, returns 1.0000001.  Close enough.
    --Count the number of generated entities to meausre the ratio.
    --/c game.print(game.player.surface.count_entities_filtered{name="iron-ore"}/game.player.surface.count_entities_filtered{name="copper-ore"})
    --prototype coverage ratio
    --/c game.print(game.entity_prototypes["copper-ore"].autoplace_specification.coverage/game.entity_prototypes["zinc-ore"].autoplace_specification.coverage)
end

script.on_event(defines.events.on_built_entity, function(event) dangOre(event) end)
script.on_event(defines.events.on_robot_built_entity, function(event) dangOre(event) end)
script.on_event(defines.events.on_chunk_generated, function(event) gOre(event) end)
script.on_event(defines.events.on_entity_died, function(event) ore_rly(event) end)
--script.on_configuration_changed(divOresity_init())
-- script.on_event(defines.events.on_tick, function(event)
	-- unchOret(event)
	-- -- flOre_is_lava(event) --Intended for multiplayer.
-- end)
--script.on_configuration_changed(function() perlin.shuffle() end)
--script.on_init(function(event) divOresity_init() perlin.shuffle() end)