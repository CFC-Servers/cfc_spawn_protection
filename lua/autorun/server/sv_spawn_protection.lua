-- Config Variables --
--
-- Time in seconds after moving for the first time that the player will lose spawn protection
local spawnProtectionMoveDelay = 0.75

-- Time in seconds before spawn protection wears off if no action is taken
local spawnProtectionDecayTime = 10

-- Prefix for the internal timer names - used to avoid timer collision
local spawnDecayPrefix = "cfc_spawn_decay_timer-"
local delayedRemovalPrefix = "cfc_spawn_removal_timer-"

-- players that have gotten a one time "infinite length" spawn protection
local doneInfiniteLength = {}

-- Table of key enums which are disallowed in spawn protection
local movementKeys = {
    [IN_MOVELEFT]  = true,
    [IN_MOVERIGHT] = true,
    [IN_FORWARD]   = true,
    [IN_BACK]      = true,
}

local attackKeys = {
    [IN_ATTACK]  = true,
    [IN_ATTACK2] = true,
    [IN_RELOAD]  = true,
    [IN_WEAPON1] = true,
    [IN_WEAPON2] = true,
}

-- Weapons allowed to the player which won't break spawn protection
local allowedSpawnWeapons = {
    ["Physics Gun"]       = true,
    ["weapon_physgun"]    = true,
    ["gmod_tool"]         = true,
    ["gmod_camera"]       = true,
    ["weapon_medkit"]     = true,
    ["none"]              = true,
    ["laserpointer"]      = true,
    ["remotecontroller"]  = true,
}

-- Helpers / Wrappers --

local function isValidPlayer( ply )
    local isValid = IsValid( ply ) and ply:IsPlayer()

    return isValid
end
-- Makes a given player transparent
local function setPlayerTransparent( ply )
    ply:SetRenderMode( RENDERMODE_TRANSALPHA )
    ply:Fire( "alpha", 180, 0 )
end

-- Returns a given player to visible state
local function setPlayerVisible( ply )
    if not isValidPlayer( ply ) then return end

    ply:SetRenderMode( RENDERMODE_NORMAL )
    ply:Fire( "alpha", 255, 0 )
end

-- Creates a unique name for the Spawn Protection Decay timer
local function playerDecayTimerIdentifier( ply )
    return spawnDecayPrefix .. ply:SteamID64()
end

-- Creates a unique name for the Delayed Removal timer
local function playerDelayedRemovalTimerIdentifier( ply )
    return delayedRemovalPrefix .. ply:SteamID64()
end

-- Set Spawn Protection
local function setSpawnProtection( ply )
    ply:SetNWBool( "HasSpawnProtection", true )
end

-- Remove Decay Timer
local function removeDecayTimer( ply )
    -- Timer might exist after player has left
    if not isValidPlayer( ply ) then return end

    local playerIdentifer = playerDecayTimerIdentifier( ply )
    timer.Remove( playerIdentifer )
end

-- Remove Delayed Removal Timer
local function removeDelayedRemoveTimer( ply )
    -- Timer might exist after player has left
    if not isValidPlayer( ply ) then return end

    local playerIdentifer = playerDelayedRemovalTimerIdentifier( ply )
    timer.Remove( playerIdentifer )
end

-- Revoke spawn protection for a player
local function removeSpawnProtection( ply, printMessage )
    if not isValidPlayer( ply ) then return end

    ply:ChatPrint( printMessage )
    ply:SetNWBool( "HasSpawnProtection", false )
end

-- Creates a decay timer which will expire after spawnProtectionDecayTime
local function createDecayTimer( ply )
    -- infinite spawn protection duration for first spawns
    if not doneInfiniteLength[ply] then doneInfiniteLength[ply] = true return end

    local playerIdentifer = playerDecayTimerIdentifier( ply )
    timer.Create( playerIdentifer, spawnProtectionDecayTime, 1, function()
        local printMessage = "You've lost your default spawn protection"

        removeSpawnProtection( ply, printMessage )
        setPlayerVisible( ply )
        removeDelayedRemoveTimer( ply )
    end )
end

-- Creates a delayed removal time which will expire after spawnProtectionMoveDelay
local function createDelayedRemoveTimer( ply )
    local playerIdentifer = playerDelayedRemovalTimerIdentifier( ply )
    timer.Create( playerIdentifer, spawnProtectionMoveDelay, 1, function()
        ply.disablingSpawnProtection = false

        local printMessage = "You've moved and lost spawn protection."
        removeSpawnProtection( ply, printMessage )
        setPlayerVisible( ply )
        removeDecayTimer( ply )
    end )
end

-- Used to delay the removal of spawn protection
local function delayRemoveSpawnProtection( ply )
    ply.disablingSpawnProtection = true
    createDelayedRemoveTimer( ply )
end

local function playerSpawnedAtEnemySpawnPoint( ply )
    local spawnPoint = ply.LinkedSpawnPoint
    if not spawnPoint or not IsValid( spawnPoint ) then return false end

    local spawnPointOwner = spawnPoint:CPPIGetOwner()
    if spawnPointOwner == ply then return false end

    return true
end

local function playerIsInPvp( ply )
    return ply.IsInPvp == nil and true or ply:IsInPvp()
end

local function playerHasSpawnProtection( ply )
    return ply:GetNWBool( "HasSpawnProtection", false )
end

local function playerIsDisablingSpawnProtection( ply )
    return ply.disablingSpawnProtection
end

local function weaponIsAllowed( weapon )
    return allowedSpawnWeapons[weapon:GetClass()]
end

-- Hook functions --

-- Function called on PlayerLoadout to grant spawn protection
local function setSpawnProtectionForPvpSpawn( ply )
    if not isValidPlayer( ply ) then return end
    if not playerIsInPvp( ply ) then return end

    if playerSpawnedAtEnemySpawnPoint( ply ) then return end

    if not ply.cfc_earnedSpawnProtection then return end -- dont give spawn protection if player never died, eg ulx ragdoll, glide ragdolling
    ply.cfc_earnedSpawnProtection = nil

    setSpawnProtection( ply )
    setPlayerTransparent( ply )
    createDecayTimer( ply )
end

-- Instantly removes spawn protection and removes timers and alpha level.
local function instantRemoveSpawnProtection( ply, message )
    if not playerHasSpawnProtection( ply ) then return end
    removeSpawnProtection( ply, message )
    setPlayerVisible( ply )
    removeDecayTimer( ply )
    removeDelayedRemoveTimer( ply )
end

-- Remove spawn protection on using objects
local function spawnProtectionUseCheck( ply )
    if not playerIsInPvp( ply ) then return end
    if not playerHasSpawnProtection( ply ) then return end
    instantRemoveSpawnProtection( ply, "You've used an entity and lost spawn protection." )
end

-- Called on player keyDown events to check if a movement/attack key was pressed
-- and remove spawn protection if so
local function spawnProtectionKeyPressCheck( ply, keyCode )
    if not ply:Alive() then return end
    if not playerHasSpawnProtection( ply ) then return end

    if ( not playerIsDisablingSpawnProtection( ply ) ) and movementKeys[keyCode] then
        delayRemoveSpawnProtection( ply )
        return
    end

    local plyActiveWeapon = ply:GetActiveWeapon()
    if attackKeys[keyCode] and plyActiveWeapon:IsValid() and not weaponIsAllowed( plyActiveWeapon ) then
        instantRemoveSpawnProtection( ply, "You've attacked and lost spawn protection." )
    end
end

-- Prevents damage if a player has spawn protection
local function preventDamageDuringSpawnProtection( ply )
    if playerHasSpawnProtection( ply ) then return true end
end

-- Hooks --

-- Prevents players from using weapons / vehicles.
hook.Add( "PlayerUse", "CFCspawnProtectionPlayerUse", spawnProtectionUseCheck )

-- Remove spawn protection when leaving Pvp ( just cleanup )
hook.Add( "PlayerExitPvP", "CFCremoveSpawnProtectionOnExitPvP", function( ply )
    if not playerHasSpawnProtection( ply ) then return end

    instantRemoveSpawnProtection( ply, "You've left pvp mode and lost spawn protection." )
end )

-- Remove spawn protection when player enters vehicle
hook.Add( "PlayerEnteredVehicle", "CFCremoveSpawnProtectionOnEnterVehicle", function( ply )
    if not playerHasSpawnProtection( ply ) then return end

    instantRemoveSpawnProtection( ply, "You've entered a vehicle and lost spawn protection." )
end )

-- Physgun activity
hook.Add( "OnPhysgunPickup", "CFCremoveSpawnProtectionOnPhysgunPickup", function( ply )
    if not playerHasSpawnProtection( ply ) then return end

    instantRemoveSpawnProtection( ply, "You've picked up a prop and lost spawn protection." )
end )

hook.Add( "PlayerSetModel", "CFCsetSpawnProtection", setSpawnProtectionForPvpSpawn, HOOK_HIGH )

hook.Add( "PlayerDeath", "CFCEarnSpawnProtection", function( ply )
    ply.cfc_earnedSpawnProtection = true
end )

-- Properly handle spawning in players
hook.Add( "PlayerFullLoad", "CFCResetInfiniteSpawnProtection", function( ply )
    doneInfiniteLength[ply] = nil
    ply.cfc_earnedSpawnProtection = true
    setSpawnProtectionForPvpSpawn( ply )
end, HOOK_LOW )

hook.Add( "PlayerDisconnected", "CFC_SpawnProtection_Cleanup", function( ply )
    doneInfiniteLength[ply] = nil
end )

-- Trigger spawn protection removal on player KeyPress
hook.Add( "KeyPress", "CFCspawnProtectionKeyPressCheck", spawnProtectionKeyPressCheck )

-- Prevent entity damage while in spawn protection
hook.Add( "EntityTakeDamage", "CFCpreventDamageDuringSpawnProtection", preventDamageDuringSpawnProtection, HOOK_HIGH )
