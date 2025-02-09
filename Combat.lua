
--This module uses a custom module loader called 'OpenPackages' made by me (krichi), you can see if its working or not by joining to the game with the provided link (please press quick join to be teleported to the main game place)

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

-- Importing external modules and services
local OpenPackages = require(game.ReplicatedStorage.OpenPackages)
local OpenStorage = OpenPackages:Get('Storage')
local OpenModules = OpenPackages:Get('Modules')

-- References to player and entity states
local PlayerStates = OpenStorage:Get('PlayerStates')
local EntityStates = OpenStorage:Get('EntityStates')

-- References to controller modules for weapon and animation handling
local WeaponController = OpenModules:Get('WeaponController')
local AnimationController = OpenModules:Get('AnimationController')

-- Builder module for sound effects and visual effects
local Builder = OpenModules:Get('Builder')

-- Hitbox handling module
local HitboxV2 = OpenModules:Get('HitboxV2')

-- Reference to events
local Events = ReplicatedStorage.Library.Events

-- Combat module initialization
local Combat = {}
Combat.__index = Combat

-- Configuring required services for combat functionality
Combat.config = {
	required = { 'EntityService', 'PlayerService' }
}

-- Function to get the state of a target (Player or Entity)
function Combat:GetState(Target)
	local TargetState
	local TargetStateBuild

	-- Check if target is a player or entity and get its state
	if PlayerStates[Target] then
		TargetState = PlayerStates[Target]
	elseif EntityStates[Target] then
		TargetState = EntityStates[Target]
	end

	-- Return the state of the target
	if TargetState then
		return TargetState.state:Get()
	end
end

-- Toggle the weapon's equipped state for the target
function Combat:Toggle(Target)
	local TargetState
	local TargetStateBuild

	-- Get the state of the target
	if PlayerStates[Target] then
		TargetState = PlayerStates[Target]
	elseif EntityStates[Target] then
		TargetState = EntityStates[Target]
	end

	TargetStateBuild = TargetState.state:Get()

	-- If the target is not in certain states, toggle weapon state
	if TargetState and not (TargetStateBuild == 'perfect_parry' or TargetStateBuild == 'parry' or TargetStateBuild == 'block' or TargetStateBuild == 'attack' or TargetStateBuild == 'true_stun' or TargetStateBuild == 'stun' or TargetStateBuild == 'downed') then
		if TargetState.Weapon.Equipped == false then
			TargetState.Rig.Sword.Transparency = 0
			TargetState.Weapon.Equipped = true
		elseif TargetState.Weapon.Equipped == true then
			TargetState.Rig.Sword.Transparency = 1
			TargetState.Weapon.Equipped = false
		end
	end
end

-- Function to apply knockback to the target
function Combat:ApplyKnockback(UserRig, Rig)
	local PlayerRig = Players:GetPlayerFromCharacter(Rig)

	-- If the target is a player, send knockback event to client
	if PlayerRig then
		Events.Replicate:FireClient(PlayerRig, {{
			type = 'knockback';
			UserRig = UserRig;
			Rig = Rig;
		}})
	else
		-- Apply knockback for entities by using attachments and velocity
		local KnockbackAttachment = Instance.new('Attachment', Rig.HumanoidRootPart)
		KnockbackAttachment.Name = 'KnockbackAttachment'

		local KnockbackVelocity = Instance.new('LinearVelocity')

		KnockbackVelocity.Attachment0 = KnockbackAttachment
		KnockbackVelocity.MaxForce = 80000
		KnockbackVelocity.VectorVelocity = UserRig.HumanoidRootPart.CFrame.LookVector * 60

		KnockbackVelocity.Parent = KnockbackAttachment

		-- Clean up the attachment after 0.5 seconds
		task.delay(0.5, function()
			KnockbackAttachment:Destroy()
		end)
	end
end

-- Function to give the target iframe (invincibility frame) for a short time
function Combat:GiveIFrames(Target)
	local TargetState

	-- Get the state of the target
	if PlayerStates[Target] then
		TargetState = PlayerStates[Target]
	elseif EntityStates[Target] then
		TargetState = EntityStates[Target]
	end

	-- Switch to iframe state
	if TargetState then
		TargetState.state:Switch('iframe')
	end
end

-- Function to apply damage to a target
function Combat:Damage(Player, Target, Damage, Combo)
	local TargetState
	local TargetStateBuild

	local PlayerState

	-- Get the state of the target and player
	if PlayerStates[Target] then
		TargetState = PlayerStates[Target]
	elseif EntityStates[Target] then
		TargetState = EntityStates[Target]
	end

	if PlayerStates[Player] then
		PlayerState = PlayerStates[Player]
	elseif EntityStates[Player] then
		PlayerState = EntityStates[Player]
	end

	TargetStateBuild = TargetState.state:Get()

	-- Default damage if none provided
	Damage = Damage or 5

	-- If the target is not in invincible or iframe states
	if TargetState then
		-- Enter combat mode if not already in one and the target isn't invincible
		if TargetState.CombatMode:Get() == false and not(TargetStateBuild == 'invincible')  then
			TargetState.CombatMode:EnterCombat(30)
		end

		TargetState.Weapon.Combo = 1

		-- Handle different states like parry, block, or being downed
		if TargetStateBuild == 'perfect_parry' then
			PlayerState.state:Switch('true_stun', 2)
			Builder:BuildSound(TargetState.Rig, ReplicatedStorage.Library.Assets.Parry)
		elseif TargetStateBuild == 'parry' then
			PlayerState.state:Switch('stun', 1)
			Builder:BuildSound(TargetState.Rig, ReplicatedStorage.Library.Assets.Parry)
		elseif TargetStateBuild == 'block' then
			-- Increase posture if the target is blocking
			TargetState.posture += Damage * 1.5

			if TargetState.posture >= 100 then
				-- Apply true stun if posture exceeds threshold
				TargetState.state:Switch('true_stun', 2)
				TargetState.posture = 0
				self:Damage(Player, Target, Damage, Combo)
			else
				Builder:BuildSound(TargetState.Rig, ReplicatedStorage.Library.Assets.Block)
			end
		elseif TargetStateBuild == 'invincible' or TargetStateBuild == 'iframe' then
			-- Print message if invincible, meaning no damage is applied
		elseif TargetStateBuild == 'downed' then
			-- Print message if the target is already downed
		else
			-- Apply damage and switch to stun state
			TargetState.state:Switch('stun', 1.5)
			TargetState.Rig.Humanoid.Health = math.clamp(TargetState.Rig.Humanoid.Health - Damage, 0.4, TargetState.Rig.Humanoid.MaxHealth)

			-- If health is 0 or less, switch to downed state
			if math.round(TargetState.Rig.Humanoid.Health) == 0 then
				TargetState.state:Switch('downed')
			else
				-- Play a hit animation and apply knockback if it's a combo
				AnimationController:Play(Target, 'Hit'..tostring(math.random(1, 3)))
				if Combo == 5 then
					self:ApplyKnockback(PlayerState.Rig, TargetState.Rig)
				end
			end

			Builder:BuildSound(TargetState.Rig, ReplicatedStorage.Library.Assets.Slash)
		end
	end
end

-- Function to block an attack for the target
function Combat:Block(Target)
	local TargetState
	local TargetStateBuild

	-- Get the state of the target
	if PlayerStates[Target] then
		TargetState = PlayerStates[Target]
	elseif EntityStates[Target] then
		TargetState = EntityStates[Target]
	end

	TargetStateBuild = TargetState.state:Get() 

	-- If the target is not in certain states, allow for blocking
	if TargetState and TargetState.Weapon.Equipped == true and not (TargetStateBuild == 'perfect_parry' or TargetStateBuild == 'parry' or TargetStateBuild == 'block' or TargetStateBuild == 'attack' or TargetStateBuild == 'true_stun' or TargetStateBuild == 'stun' or TargetStateBuild == 'downed') then
		TargetState.state:Switch('perfect_parry')

		-- Transition through parry to block after a delay
		task.delay(0.1, function()		
			if TargetState.state:Get() == 'perfect_parry' then
				TargetState.state:Switch('parry')
				task.wait(0.25)
				if TargetState.state:Get() == 'parry' then
					TargetState.state:Switch('block')
				end
			end
		end)
	end	
end

-- Function to unblock a target
function Combat:Unblock(Target)
	local TargetState
	local TargetStateBuild

	-- Get the state of the target
	if PlayerStates[Target] then
		TargetState = PlayerStates[Target]
	elseif EntityStates[Target] then
		TargetState = EntityStates[Target]
	end

	TargetStateBuild = TargetState.state:Get() 

	-- If the target is blocking, switch to normal state
	if TargetState and (TargetStateBuild == 'perfect_parry' or TargetStateBuild == 'parry' or TargetStateBuild == 'block') then
		TargetState.state:Switch('normal')
	end	
end

-- Function to check if the target is attacking
function Combat:IsAttacking(Target)
	local TargetState
	local TargetStateBuild

	-- Get the state of the target
	if PlayerStates[Target] then
		TargetState = PlayerStates[Target]
	elseif EntityStates[Target] then
		TargetState = EntityStates[Target]
	end

	TargetStateBuild = TargetState.state:Get() 

	-- If the target is attacking, return true
	if TargetStateBuild == 'attack' then
		return true
	else
		return false
	end
end

-- Function to initiate an attack
function Combat:Attack(Target)
	local TargetState
	local TargetStateBuild

	-- Get the state of the target
	if PlayerStates[Target] then
		TargetState = PlayerStates[Target]
	elseif EntityStates[Target] then
		TargetState = EntityStates[Target]
	end

	TargetStateBuild = TargetState.state:Get() 

	-- If the target can attack (not in certain states), initiate an attack
	if TargetState and TargetState.Weapon.Equipped == true and not (TargetStateBuild == 'perfect_parry' or TargetStateBuild == 'parry' or TargetStateBuild == 'block' or TargetStateBuild == 'attack' or TargetStateBuild == 'true_stun' or TargetStateBuild == 'stun' or TargetStateBuild == 'downed') then		
		TargetState.Weapon.Combo += 1

		TargetState.state:Switch('attack')

		-- Play the attack sound
		Builder:BuildSound(TargetState.Rig, ReplicatedStorage.Library.Assets.Swing)

		-- Use weapon controller to initiate a slash
		local ControllerDetails = WeaponController:Get(TargetState.Weapon.Name):Slash(Target)

		-- Trigger the hitbox event for melee attack
		HitboxV2:MeleeStart(Target, { Time = ControllerDetails.Length }, function(Tagged)
			local PossiblePlayer = Players:GetPlayerFromCharacter(Tagged)

			-- Apply damage to the tagged target (Player or Entity)
			if PossiblePlayer then
				Combat:Damage(Target, PossiblePlayer, ControllerDetails.Damage, TargetState.Weapon.Combo)
			else
				Combat:Damage(Target, Tagged, ControllerDetails.Damage, TargetState.Weapon.Combo)
			end
		end)

		-- Wait for the attack animation to finish
		task.wait(ControllerDetails.Length)

		-- If attack finishes, return to normal state or apply stun
		if TargetState.state:Get() == 'attack' then
			if TargetState.Weapon.Combo >= 5 then
				TargetState.Weapon.Combo = 0
				TargetState.state:Switch('true_stun', 0.5)
			else
				TargetState.state:Switch('normal', 0.5)
			end
		end
	end	
end

-- Function to load the Combat module (Using a custom module loader in the provided game link.)
function Combat:Load()
	-- Event listener for blocking
	Events.Block.OnServerEvent:Connect(function(Player, Boolean)
		if Boolean == true then
			Combat:Block(Player)
		elseif Boolean == false then
			Combat:Unblock(Player)
		end
	end)

	-- Event listener for attacking
	Events.Attack.OnServerEvent:Connect(function(Player)
		Combat:Attack(Player)
	end)

	-- Event listener for toggling weapon equip
	Events.Toggle.OnServerEvent:Connect(function(Player)
		Combat:Toggle(Player)
	end)
end

return Combat
