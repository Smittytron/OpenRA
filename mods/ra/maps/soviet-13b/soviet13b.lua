--[[
   Copyright 2007-2021 The OpenRA Developers (see AUTHORS)
   This file is part of OpenRA, which is free software. It is made
   available to you under the terms of the GNU General Public License
   as published by the Free Software Foundation, either version 3 of
   the License, or (at your option) any later version. For more
   information, see COPYING.
]]
Jeeps = { Jeep1, Jeep2 }
JeepWaypoints = { JeepWaypoint1.Location, JeepWaypoint2.Location }
BridgeDefenders = { BridgeAttack1, BridgeAttack2, BridgeAttack3, BridgeAttack4, BridgeAttack5 }
RadarSites = { Radar1, Radar2, Radar3, Radar4 }
StartAttack = { StartAttack1, StartAttack2, StartAttack3, StartAttack4, StartAttack5, StartAttack6 }
ChronoDemolitionTrigger = { CPos.New(36,96), CPos.New(37,96), CPos.New(37,97), CPos.New(38,97), CPos.New(38,98), CPos.New(39,98) }

Start = function()
	Reinforcements.Reinforce(USSR, { "mcv" }, { MCVEntry.Location, DefaultCameraPosition.Location }, 5)

	Utils.Do(Jeeps, function(jeep)
		jeep.Patrol(JeepWaypoints, true, 125)
	end)

	Utils.Do(StartAttack, function(a)
		IdleHunt(a)
	end)

	ChronoCam = Actor.Create("camera", true, { Owner = USSR, Location = Chronosphere.Location})
end

MissionTriggers = function()
	Trigger.OnAllKilled(RadarSites, function()
		USSR.MarkCompletedObjective(TakeDownRadar)
		ChronoshiftAlliedUnits()
	end)

	Trigger.OnCapture(Chronosphere, function()
		USSR.MarkCompletedObjective(CaptureChronosphere)
	end)

	Trigger.OnKilled(Chronosphere, function()
		USSR.MarkFailedObjective(CaptureChornosphere)
	end)

	local chronoTriggered
	Trigger.OnEnteredFootprint(ChronoDemolitionTrigger, function(actor, id)
		if actor.Owner == USSR and not chronoTriggered and not USSR.IsObjectiveCompleted(TakeDownRadar) then
			Trigger.RemoveFootprintTrigger(id)
			Media.DisplayMessage("We failed to take the trap offline!", "Headquarters")
			chronoTriggered = true
			Chronosphere.Kill()
		end
	end)

	Trigger.OnEnteredProximityTrigger(ChinookLZ.CenterPosition, WDist.FromCells(5), function(actor, id)
		if actor.Owner == USSR and actor.Type == "harv" then
			Trigger.RemoveProximityTrigger(id)
			SendChinook()
		end
	end)

	Trigger.OnEnteredProximityTrigger(BridgeAttackProxy.CenterPosition, WDist.FromCells(10), function(actor, id)
		if actor.Owner == USSR then
			Trigger.RemoveProximityTrigger(id)

			Utils.Do(BridgeDefenders, function(a)
				if not a.IsDead then
					IdleHunt(a)
				end
			end)
		end
	end)
end

ChronoshiftAlliedUnits = function()
	if Chronosphere.IsDead then
		return
	end

	local cells = Utils.ExpandFootprint({ ChronoshiftPoint.Location }, false)
	local units = { }
	for i = 1, #cells do
		local unit = Actor.Create("2tnk", true, { Owner = Greece, Facing = Angle.North })
		units[unit] = cells[i]
		IdleHunt(unit)
	end
	Chronosphere.Chronoshift(units)
end

Tick = function()
	Greece.Cash = 20000

	if USSR.HasNoRequiredUnits() then
		Greece.MarkCompletedObjective(AlliesObjective)
	end
end

WorldLoaded = function()
	USSR = Player.GetPlayer("USSR")
	Greece = Player.GetPlayer("Greece")
	
	Trigger.OnObjectiveAdded(USSR, function(p, id)
		Media.DisplayMessage(p.GetObjectiveDescription(id), "New " .. string.lower(p.GetObjectiveType(id)) .. " objective")
	end)
	
	AlliesObjective = Greece.AddObjective("Defeat the Soviet forces.")
	TakeDownRadar = USSR.AddObjective("Destroy the Allied radar sites before approaching the chronoshpere.")
	CaptureChornosphere = USSR.AddObjective("Capture the chronoshpere.")
	
	Trigger.OnObjectiveCompleted(USSR, function(p, id)
		Media.DisplayMessage(p.GetObjectiveDescription(id), "Objective completed")
	end)
	Trigger.OnObjectiveFailed(USSR, function(p, id)
		Media.DisplayMessage(p.GetObjectiveDescription(id), "Objective failed")
	end)

	Trigger.OnPlayerLost(USSR, function()
		Trigger.AfterDelay(DateTime.Seconds(1), function()
			Media.PlaySpeechNotification(USSR, "MissionFailed")
		end)
	end)
	Trigger.OnPlayerWon(USSR, function()
		Trigger.AfterDelay(DateTime.Seconds(1), function()
			Media.PlaySpeechNotification(USSR, "MissionAccomplished")
		end)
	end)

	Camera.Position = DefaultCameraPosition.CenterPosition
	Start()
	MissionTriggers()
	ActivateAI()
end
