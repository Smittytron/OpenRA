--[[
   Copyright 2007-2018 The OpenRA Developers (see AUTHORS)
   This file is part of OpenRA, which is free software. It is made
   available to you under the terms of the GNU General Public License
   as published by the Free Software Foundation, either version 3 of
   the License, or (at your option) any later version. For more
   information, see COPYING.
]]
AlliedBoatReinforcements = { "dd", "dd" }
TimerTicks = DateTime.Minutes(21)
ObjectiveBuildings = { Chronosphere, AlliedTechCenter }
ScientistType = { "chan", "chan", "chan", "chan" }
ScientistFootprint = { CPos.New(28, 83), CPos.New(29, 83) }

InitialAlliedReinforcements = function()
	Trigger.AfterDelay(DateTime.Seconds(2), function()
		Media.PlaySpeechNotification(greece, "ReinforcementsArrived")
		Reinforcements.Reinforce(greece, { "mcv" }, { MCVEntry.Location, MCVStop.Location })
		Reinforcements.Reinforce(greece, AlliedBoatReinforcements, { DDEntry.Location, DDStop.Location })
	end)
end

CreateScientists = function()
	scientists = Actor.Create(ScientistType, true, { Location = ScientistsExit.Location, Owner = greece })
	scientists.Scatter()
	Trigger.OnAllKilled(scientists, function()
		greece.MarkFailedObjective(EvacuateScientists)
	end)
	Trigger.OnAllRemovedFromWorld(scientists, function()
		greece.MarkCompletedObjective(EvacuateScientists)
	end)
end

FinishTimer = function()
	for i = 0, 5 do
		local c = TimerColor
		if i % 2 == 0 then
			c = HSLColor.White
		end

		Trigger.AfterDelay(DateTime.Seconds(i), function() UserInterface.SetMissionText("The experiment is a success!", c) end)
	end
	Trigger.AfterDelay(DateTime.Seconds(6), function() UserInterface.SetMissionText("") end)
end

DefendChronosphereCompleted = function()
	local cells = Utils.ExpandFootprint({ ChronoshiftLocation.Location }, false)
	local units = { }
	for i = 1, #cells do
		local unit = Actor.Create("2tnk", true, { Owner = greece, Facing = 0 })
		units[unit] = cells[i]
	end
	Chronosphere.Chronoshift(units)

	Trigger.AfterDelay(DateTime.Seconds(3), function()
		greece.MarkCompletedObjective(DefendChronosphere)
		greece.MarkCompletedObjective(KeepBasePowered)
	end)
end

ticked = TimerTicks
Tick = function()
	ussr.Cash = 5000

	if ussr.HasNoRequiredUnits() then
		greece.MarkCompletedObjective(DefendChronosphere)
		greece.MarkCompletedObjective(KeepBasePowered)
	end

	if greece.HasNoRequiredUnits() then
		ussr.MarkCompletedObjective(BeatAllies)
	end

	if ticked > 0 then
		UserInterface.SetMissionText("Chronosphere experiment completes in " .. Utils.FormatTime(ticked), TimerColor)
		ticked = ticked - 1
	elseif ticked == 0 and (greece.PowerState ~= "Normal") then
		greece.MarkFailedObjective(KeepBasePowered)
	elseif ticked == 0 then
		DefendChronosphereCompleted()
		ticked = ticked - 1
	end
end

WorldLoaded = function()
	greece = Player.GetPlayer("Greece")
	ussr = Player.GetPlayer("USSR")
	germany = Player.GetPlayer("Germany")

	DefendChronosphere = greece.AddPrimaryObjective("Defend the Chronosphere and the Tech Center \nat all costs.")
	KeepBasePowered = greece.AddPrimaryObjective("The Chronosphere must have power when the \ntimer runs out.")
	EvacuateScientists = greece.AddSecondaryObjective("Evacuate scientists from the island to \nthe Tech Center.")
	BeatAllies = ussr.AddPrimaryObjective("Defeat the Allied forces.")

	Trigger.OnObjectiveCompleted(greece, function(p, id)
		Media.DisplayMessage(p.GetObjectiveDescription(id), "Objective completed")
	end)
	Trigger.OnObjectiveFailed(greece, function(p, id)
		Media.DisplayMessage(p.GetObjectiveDescription(id), "Objective failed")
	end)

	Trigger.OnPlayerLost(greece, function()
		Trigger.AfterDelay(DateTime.Seconds(1), function()
			Media.PlaySpeechNotification(greece, "MissionFailed")
		end)
	end)
	Trigger.OnPlayerWon(greece, function()
		Trigger.AfterDelay(DateTime.Seconds(1), function()
			Media.PlaySpeechNotification(greece, "MissionAccomplished")
		end)
	end)

	Trigger.AfterDelay(DateTime.Minutes(1), function()
		Media.PlaySpeechNotification(greece, "TwentyMinutesRemaining")
	end)
	Trigger.AfterDelay(DateTime.Minutes(11), function()
		Media.PlaySpeechNotification(greece, "TenMinutesRemaining")
	end)
	Trigger.AfterDelay(DateTime.Minutes(16), function()
		Media.PlaySpeechNotification(greece, "WarningFiveMinutesRemaining")
	end)
	Trigger.AfterDelay(DateTime.Minutes(18), function()
		Media.PlaySpeechNotification(greece, "WarningThreeMinutesRemaining")
	end)
	Trigger.AfterDelay(DateTime.Minutes(20), function()
		Media.PlaySpeechNotification(greece, "WarningOneMinuteRemaining")
	end)

	PowerProxy = Actor.Create("powerproxy.paratroopers", false, { Owner = ussr })

	Camera.Position = DefaultCameraPosition.CenterPosition
	TimerColor = greece.Color

	Trigger.OnAnyKilled(ObjectiveBuildings, function()
		greece.MarkFailedObjective(DefendChronosphere)
	end)

	Trigger.OnEnteredFootprint(ScientistFootprint, function(a, id)
		if a.Owner == greece and not scientistsTriggered then
			scientistsTriggered = true
			Trigger.RemoveFootprintTrigger(id)
			CreateScientists()
		end
	end)

	InitialAlliedReinforcements()
	ActivateAI()
end
