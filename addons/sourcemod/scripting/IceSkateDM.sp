// Ice Skate Deathmatch is a thing now thanks to Himanshu's choice of commands :)
// TODO: 
// 1. Add grenade boosting 
// 2. Add gamemode info somehow 
// 3. fix players from both getting kills with the bull 
// 4. Make vehicles lift at the right times
// 5. Fix download shit
// 6. Detect map size, change speeds accordingly
// 7. Fix speed perk #3 from not blocking damage sometimes

public Plugin:myinfo =
{
	name = "Ice Skate Deathmatch",
	author = "Ethorbit",
	description = "Greatly changes the way deathmatch is played introducing new techniques & perks",
	version = "1.2.7",
	url = ""
}

#include <sdktools>
#include <sdkhooks>
#include <convars>

new String:ISDM_Materials[][63] = { // The materials the gamemode uses
    "1speedperk", 
    "1speedperkandair", 
    "2speedperks", 
    "2speedperksandair", 
    "allspeedperks",
    "allspeedperksandair",
    "airperk",
    "Left/leftarrow",
    "Left/leftandairperk",
    "Left/leftand1speedperk",
    "Left/leftand2speedperks",
    "Left/leftandallspeedperks",
    "Left/left1speedperkandair",
    "Left/left2speedperksandair",
    "Left/leftallspeedperksandair",
    "Right/rightarrow",
    "Right/rightandairperk",
    "Right/rightand1speedperk",
    "Right/rightand2speedperks",
    "Right/rightandallspeedperks",
    "Right/right1speedperkandair",
    "Right/right2speedperksandair",
    "Right/rightallspeedperksandair"
}

new String:ISDM_Sounds[][32] = { // Sounds used by the gamemode
    "impact01",
    "impact02",
    "skate01",
    "skate02",
    "skate03"
}

new ISDM_MaxPlayers;
new ISDM_IsHooked[MAXPLAYERS + 1] = false;
new Handle:AddDirection[MAXPLAYERS + 1] = INVALID_HANDLE;
new Handle:ResolveDirectionsLeft[MAXPLAYERS + 1] = INVALID_HANDLE;
new Handle:ResolveDirectionsRight[MAXPLAYERS + 1] = INVALID_HANDLE;
new Handle:AddPlySkate[MAXPLAYERS + 1] = INVALID_HANDLE;
new Handle:AddTimeToPressedKey[MAXPLAYERS + 1] = INVALID_HANDLE;
new Handle:TimeForSkateSound[MAXPLAYERS + 1] = INVALID_HANDLE;
new Handle:NearbyEntSearch[MAXPLAYERS + 1] = INVALID_HANDLE;
new Handle:PushData[MAXPLAYERS + 1] = INVALID_HANDLE;
new Handle:ForceReloading[MAXPLAYERS + 1] = false;
int ElapsedLeftTime[MAXPLAYERS + 1] = 0;
int ElapsedRightTime[MAXPLAYERS + 1] = 0;
new Float:PlySkates[MAXPLAYERS + 1] = 0.0;
new Float:PlyInitialHeight[MAXPLAYERS + 1] = 0.0;
bool SkatedLeft[MAXPLAYERS + 1] = false;
bool SkatedRight[MAXPLAYERS + 1] = false;
bool DeniedSprintSoundPlayed[MAXPLAYERS + 1] = false;
bool PlayerIsBoosting[MAXPLAYERS + 1] = false;
new Float:MAXSLOWSPEED;
new Float:MAXAIRHEIGHT;
new Float:SPEED1SPEED;
new Float:SPEED2SPEED;
new Float:SPEED3SPEED;

new String:TheRightWeapons[][] = { // Weapons that will have their speeds modified the faster the player goes
    "weapon_357", 
    "weapon_crowbar", 
    "weapon_stunstick",
    "weapon_pistol"
}

public OnClientDisconnect_Post(client) { // When a player leaves it is important to reset the client index's statistics
    ISDM_IsHooked[client] = false;
    AddDirection[client] = INVALID_HANDLE;
    ResolveDirectionsLeft[client] = INVALID_HANDLE;
    ResolveDirectionsRight[client] = INVALID_HANDLE;
    AddPlySkate[client] = INVALID_HANDLE;
    AddTimeToPressedKey[client] = INVALID_HANDLE;
    TimeForSkateSound[client] = INVALID_HANDLE;
    ForceReloading[client] = INVALID_HANDLE;
    PushData[client] = INVALID_HANDLE;
    ElapsedLeftTime[client] = 0;   
    ElapsedRightTime[client] = 0; 
    PlySkates[client] = 0.0;
    PlyInitialHeight[client] = 0.0;
    SkatedLeft[client] = false;
    SkatedRight[client] = false;
    DeniedSprintSoundPlayed[client] = false;
    PlayerIsBoosting[client] = false;
}

enum Perks 
{
    ISDM_NoPerks,
    ISDM_SlowPerk,
    ISDM_AirPerk,
    ISDM_SpeedPerk1,
    ISDM_SpeedPerk2,
    ISDM_SpeedPerk3
}

enum PerkConVars 
{
    SlowPerkSpeedConVar, 
    FastPerk1SpeedConVar, 
    FastPerk2SpeedConVar, 
    FastPerk3SpeedConVar, 
    AirPerkHeightConVar
}

new ISDM_Perks[Perks];
new ISDM_PerkVars[PerkConVars];

public void OnPluginStart() {
    ISDM_MaxPlayers = GetMaxClients(); 
    SetConVarInt(FindConVar("sv_footsteps"), 0, false, false); // Footstep sounds are replaced with skating sounds
    SetConVarFloat(FindConVar("sv_friction"), 0.5, false, false); // No other way found so far to allow players to slide :(
    SetConVarFloat(FindConVar("sv_accelerate"), 100.0, false, false); // Very much optional, playable without it
    SetConVarFloat(FindConVar("sv_airaccelerate"), 9999.0, false, false); // Based on feedback airaccelerate is the more popular option over what was used
    SetConVarFloat(FindConVar("phys_timescale"), 2.0, false, false); // A necessity because of how fast players can go now
    SetConVarFloat(FindConVar("physcannon_minforce"), 20000.0, false, false); 
    SetConVarFloat(FindConVar("physcannon_maxforce"), 20000.0, false, false); // Not too fast, but not too slow for new player speeds either
    SetConVarFloat(FindConVar("physcannon_pullforce"), 10000.0, false, false); // Allow players to pull stuff 2.5x farther (not much of a difference)
    ISDM_PerkVars[SlowPerkSpeedConVar] = CreateConVar("ISDM_SlowPerkSpeed", "210.0", "The maximum speed players can go to get Slow Perk", FCVAR_SERVER_CAN_EXECUTE);
    ISDM_PerkVars[FastPerk1SpeedConVar] = CreateConVar("ISDM_FastPerk1Speed", "600.0", "The maximum speed players can go to get Fast Perk #1", FCVAR_SERVER_CAN_EXECUTE);
    ISDM_PerkVars[FastPerk2SpeedConVar] = CreateConVar("ISDM_FastPerk2Speed", "1200.0", "The maximum speed players can go to get Fast Perk #2", FCVAR_SERVER_CAN_EXECUTE);
    ISDM_PerkVars[FastPerk3SpeedConVar] = CreateConVar("ISDM_FastPerk3Speed", "1500.0", "The maximum speed players can go to get Fast Perk #3", FCVAR_SERVER_CAN_EXECUTE);
    ISDM_PerkVars[AirPerkHeightConVar] = CreateConVar("ISDM_AirPerkHeight", "50.0", "The minimum height speed players need to go before they get Air Perk", FCVAR_SERVER_CAN_EXECUTE);
    ISDM_UpdatePerkVars();

    for (new i = 0; i < sizeof(ISDM_Materials); i++) { // Loop through all Ice Skate Deathmatch materials and force clients to download them
        int MaxMatLength = 58;
        new String:VTFs[MaxMatLength];
        new String:VMTs[MaxMatLength];
        Format(VTFs, MaxMatLength, "materials/IceSkateDM/%s.vtf", ISDM_Materials[i]);
        Format(VMTs, MaxMatLength, "materials/IceSkateDM/%s.vmt", ISDM_Materials[i]);
        AddFileToDownloadsTable(VTFs);
        AddFileToDownloadsTable(VMTs);
        PrecacheDecal(VTFs);
    }

    for (new i = 0; i < sizeof(ISDM_Sounds); i++) { // Loop through sounds and force downloads too
        int MaxMatLength = 32;
        new String:Sounds[MaxMatLength];
        new String:SoundPrecache[MaxMatLength];
        Format(Sounds, MaxMatLength, "sound/IceSkateDM/%s.wav", ISDM_Sounds[i]);
        AddFileToDownloadsTable(Sounds);
        PrecacheSound(Sounds);
    }

    new const perkvar[5] = {SlowPerkSpeedConVar, FastPerk1SpeedConVar, FastPerk2SpeedConVar, FastPerk3SpeedConVar, AirPerkHeightConVar}; 
    for (new i = 0; i < sizeof(perkvar); i++) { // Loop through each perk convar and hook it to the ISDM_PerkChanged() function
        HookConVarChange(ISDM_PerkVars[perkvar[i]], ISDM_PerkChanged);
    }

    new const PerkIncrement[6] = {ISDM_NoPerks, ISDM_SlowPerk, ISDM_AirPerk, ISDM_SpeedPerk1, ISDM_SpeedPerk2, ISDM_SpeedPerk3};
    for (new i = 0; i < sizeof(PerkIncrement); i++) { // Loop through each perk and assign it to an array
        ISDM_Perks[PerkIncrement[i]] = CreateArray(32);
    }
}

public void ISDM_DelFromArray(Handle:array, item) {
    if (FindValueInArray(array, item) > -1) {
        RemoveFromArray(array, FindValueInArray(array, item));
    }
}

public OnGameFrame() {
    ISDM_StopSounds();
    for (new i = 1; i <= ISDM_MaxPlayers; i++) { // Loop through each player
        if (IsValidEntity(i)) {
            if (IsClientInGame(i)) {  
                if (ISDM_IsHooked[i] == false) { // Ensure that the player is ALWAYS hooked even if plugin is reloaded
                    SDKHook(i, SDKHook_OnTakeDamage, ISDM_PlyTookDmg);
                    SDKHook(i, SDKHook_Touch, ISDM_Touched);
                    ISDM_IsHooked[i] = true;
                }

                if (!IsPlayerAlive(i)) {
                    ClientCommand(i, "r_screenoverlay 0"); // Reset perks since they died
                }
            
                if (IsPlayerAlive(i)) {
                    ISDM_UpdatePerks(i);
                }
            }
        }
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////// ISDM DAMAGE LOGIC /////////////////////////////////
ISDM_DealDamage(victim, damage, attacker=0, damageType=DMG_GENERIC, String:weapon[]="") {
	if (IsValidEntity(victim) && IsValidEntity(attacker) && IsPlayerAlive(victim)) {
		new String:DmgString[16];
		new String:DmgTypeString[32];
        IntToString(damage, DmgString,16);
		IntToString(damageType, DmgTypeString,32);
		new pointHurt=CreateEntityByName("point_hurt");
		
        if (pointHurt) {
			DispatchKeyValue(victim, "targetname", "hurtme");
			DispatchKeyValue(pointHurt, "DamageTarget", "hurtme");
			DispatchKeyValue(pointHurt, "Damage", DmgString);
			DispatchKeyValue(pointHurt, "DamageType", DmgTypeString);

			if (!StrEqual(weapon, "")) {
				DispatchKeyValue(pointHurt,"classname",weapon);
			}

			DispatchSpawn(pointHurt);
			AcceptEntityInput(pointHurt, "Hurt", (attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt, "classname", "point_hurt");
			DispatchKeyValue(victim, "targetname", "donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}

public Action:ISDM_PlyTookDmg(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
    if (damagetype & DMG_FALL) { // Disable disgusting fall damage
        damage = 0.0;
        ISDM_ImpactSound(victim); // Function to replace the fall damage sound
        return Plugin_Changed;
    }

    // Props will be flying crazy in all directions and players will run into them at extreme speeds, so disable PVE prop damage:
    if (damagetype & DMG_CRUSH) { // DMG_CRUSH is prop damage
        if (attacker > MaxClients || attacker == victim) { // Make sure the attacker is the victim or that the attacker is not a player
            damage = 0.0;
            return Plugin_Changed;       
        }
    }

    if (damagetype & DMG_BLAST) {
        if (attacker > MaxClients || attacker == victim) {
            new String:PlyWepClass[32];
            int PlyWep = GetEntPropEnt(victim, Prop_Data, "m_hActiveWeapon");
            GetEntityClassname(PlyWep, PlyWepClass, 32);

            // Do less explosive damage to self for easy boosting:
            if (strcmp(PlyWepClass, "weapon_smg1") == 0) {
                damage = damage / 2; 
            } 

            if (strcmp(PlyWepClass, "weapon_rpg") == 0) {
                damage = damage / 1.3; 
            } 

            ISDM_BoostPlayer(victim, PlyWepClass);
            return Plugin_Changed;
        }
    }

    if (GetClientOfUserId(attacker) != 0) { // If there is an attacker
        new String:attackerweapon[32];
        GetClientWeapon(attacker, attackerweapon, 32);

        if (damagetype & DMG_BULLET && ISDM_GetPerk(attacker, ISDM_Perks[ISDM_AirPerk])) { // Air perk increases damage
            if (strcmp(attackerweapon, "weapon_357") == 0 || strcmp(attackerweapon, "weapon_crossbow") == 0) { // Only multiply the good weapons' damage a tiny bit
                damage = damage * 1.2;
                return Plugin_Changed; 
            } else if (strcmp(attackerweapon, "weapon_shotgun") == 0) { // Shotgun is decent but only up close, so multiply it a little more
                damage = damage * 1.4;
                return Plugin_Changed;
            } else if (strcmp(attackerweapon, "weapon_rpg") != 0) { // Every other weapon not including rpg are pretty bad at dmg, so multiply by 2X
                damage = damage * 2.0;
                return Plugin_Changed;
            }
        }

        // The 3rd speed perk makes you immune to certain damage:
        if (damagetype & DMG_BLAST && strcmp(attackerweapon, "weapon_rpg") != 0 && ISDM_GetPerk(victim, ISDM_Perks[ISDM_SpeedPerk3])) {
            damage = 0.0;
            return Plugin_Changed;
        }

        if (damagetype & DMG_CRUSH || damagetype & DMG_DISSOLVE && ISDM_GetPerk(victim, ISDM_Perks[ISDM_SpeedPerk3])) { 
            damage = 0.0;
            return Plugin_Changed;
        }
    }
        
    return Plugin_Continue;
}

public Action:ISDM_Touched(entity, entity2) {
    if (IsValidEntity(entity) && IsValidEntity(entity2)) {
        new String:EntClass[32];
        new String:EntClass2[32];
        GetEntityClassname(entity, EntClass, 32);
        GetEntityClassname(entity2, EntClass2, 32);

        if (strcmp(EntClass, "player") == 0 && strcmp(EntClass2, "player") == 0) { // If both entities are players
            if (entity != entity2) { // They are different players
                if (ISDM_GetPerk(entity, ISDM_Perks[ISDM_SpeedPerk2]) || ISDM_GetPerk(entity, ISDM_Perks[ISDM_SpeedPerk3])) {
                    ISDM_DealDamage(entity2, 1000, entity, DMG_BULLET, "");
                }

                if (ISDM_GetPerk(entity2, ISDM_Perks[ISDM_SpeedPerk2]) || ISDM_GetPerk(entity2, ISDM_Perks[ISDM_SpeedPerk3])) {
                    ISDM_DealDamage(entity, 1000, entity2, DMG_BULLET, "");
                }
            }
        }
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////// ISDM BOOSTING LOGIC /////////////////////////////////
public Action:ISDM_GroundCheck(Handle:timer, any:client) { // Gives the boosting system a chance to actually set them as boosting
    if (IsValidEntity(client)) {
        bool NotOnGround = (GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1);

        if (!NotOnGround) {
            PlayerIsBoosting[client] = false; // They are no longer boosted after hitting the ground
        }
    }
}

public ISDM_BoostPlayer(client, String:Weapon[]) {
    if (IsPlayerAlive(client)) {
        new Float:PlyVel[3];
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", PlyVel);

        float direction[3];
        NormalizeVector(PlyVel, direction);

        if (strcmp(Weapon, "weapon_smg1") == 0) { // SMG1 grenade blasted  
            ScaleVector(direction, GetRandomFloat(500.0, 1000.0)); 
            PlyVel[2] = GetRandomFloat(900.0, 1500.0);
            AddVectors(PlyVel, direction, PlyVel);
        } else if (strcmp(Weapon, "weapon_rpg") == 0) { // SMG1 grenade blasted  
            ScaleVector(direction, GetRandomFloat(1000.0, 1500.0)); 
            PlyVel[2] = GetRandomFloat(1500.0, 2000.0);
            AddVectors(PlyVel, direction, PlyVel);
        }

        PlayerIsBoosting[client] = true; // Will stop the automatic gravity system from kicking in
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, PlyVel);
    }   
}
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////// ISDM Automatic Prop Lift Logic /////////////////////////////////////////////
static bool:ISDM_EntVisible(client, entity) { // Will trace from player's eyes to props to determine whether they are visible or not
    new bool:isVisible = false;  
    new Float:EyePos[3], Float:EntPos[3];
    GetClientEyePosition(client, EyePos); 
    GetEntPropVector(entity, Prop_Data, "m_vecOrigin", EntPos);
    
    new Handle:EyeTrace = TR_TraceHullFilterEx(EyePos, EntPos, {-16.0, -16.0, 0.0}, {16.0, 16.0, 72.0}, MASK_SHOT, TraceEntityFilterPlayer);
    
    if (TR_DidHit(EyeTrace)) {
        if (TR_GetEntityIndex(EyeTrace) == 0) { // 0 means the trace hit part of the map
            isVisible = false;
        } else {
            isVisible = true;
        }
    }

    CloseHandle(EyeTrace);
    return isVisible;
}

public Action:ISDM_PushNearbyEnts(Handle:timer, Handle:data) { 
    ResetPack(data);
    if (IsPackReadable(data, 1)) {
        int client = ReadPackCell(data);
        new Float:PropDist = ReadPackFloat(data);
        new Float:clientOrigin[3];
        new Float:clientEyes[3];
        GetClientEyePosition(client, clientEyes);
        GetClientAbsOrigin(client, clientOrigin);

        for (new i = 0; i < GetMaxEntities(); i++) {
            if (IsValidEntity(i) && IsValidEntity(client) && IsPlayerAlive(client) && IsClientConnected(client)) {
                new String:EntClass[32];
                GetEntityClassname(i, EntClass, 32);    
                if (StrContains(EntClass, "prop_physics") == 0) {
                    new Float:propOrigin[3];
                    GetEntPropVector(i, Prop_Data, "m_vecOrigin", propOrigin);
                    
                    if (ISDM_EntVisible(client, i)) { // If the player can see the entity
                        if (GetEntProp(i, Prop_Data, "m_bThrownByPlayer") == 0) { // Make sure this prop was never thrown by anyone 
                            new Float:propSpeed[3];
                            new Float:plySpeed[3]; 
                            GetEntPropVector(client, Prop_Data, "m_vecVelocity", plySpeed); 
                            GetEntPropVector(i, Prop_Data, "m_vecVelocity", propSpeed);    

                            if (GetVectorDistance(propOrigin, clientOrigin) < PropDist) { // If the prop is too close to the player
                                if (GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1) { // Player is on the ground
                                    if (propSpeed[0] == 0.0 && propSpeed[1] == 0.0) { // And the prop has no speed
                                        if (GetEntPropEnt(i, Prop_Data, "m_hPhysicsAttacker") == -1) { // If no one has picked this up with the gravity gun               
                                            // 64th spawn flag means motion will enable on physcannon grab:
                                            if (GetEntProp(i, Prop_Data, "m_spawnflags") & 64) { 
                                                AcceptEntityInput(i, "EnableMotion"); // Enable the motion anyways
                                            }

                                            // Launch the prop in the air with higher Z velocity than the player:
                                            propSpeed[0] = 0.0;
                                            propSpeed[1] = 0.0;
                                            propSpeed[2] = plySpeed[2] + GetRandomFloat(450.0, 600.0);
                                            TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, propSpeed);
                                        } else { // The prop has been thrown before
                                            CreateTimer(3.0, ISDM_FixProps, i); // Fix physics attacker never resetting after impact
                                        }
                                    }
                                }
                            }     
                        }         
                    }
                }
            }
        }
        CloseHandle(PushData[client]);
    }
}

public Action:ISDM_FixProps(Handle:timer, any:entity) {
    if (GetEntPropEnt(entity, Prop_Data, "m_hPhysicsAttacker") != -1) {
        SetEntPropEnt(entity, Prop_Data, "m_hPhysicsAttacker", -1); 
    } 
}

stock ISDM_IncreaseFire(client, Float:Amount) {
	new ent = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if (ent != -1) {
		new Float:m_flNextPrimaryAttack = GetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack");
		new Float:m_flNextSecondaryAttack = GetEntPropFloat(ent, Prop_Send, "m_flNextSecondaryAttack");
        
		if (Amount > 12.0) {
			SetEntPropFloat(ent, Prop_Send, "m_flPlaybackRate", 12.0);
		} else {
			SetEntPropFloat(ent, Prop_Send, "m_flPlaybackRate", Amount);
            SetEntPropFloat(ent, Prop_Data, "m_flPlaybackRate", Amount);
		}

		new Float:GameTime = GetGameTime();	
		new Float:PeTime = (m_flNextPrimaryAttack - GameTime) - ((Amount - 1.0) / 50);
		new Float:SeTime = (m_flNextSecondaryAttack - GameTime) - ((Amount - 1.0) / 50);
		new Float:FinalP = PeTime+GameTime;
		new Float:FinalS = SeTime+GameTime;
			
		SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", FinalP);
		SetEntPropFloat(ent, Prop_Send, "m_flNextSecondaryAttack", FinalS);
	}
}

public bool:SearchForWep(String:WepName[32]) { 
    bool Found = false;

    for (new i = 0; i < sizeof(TheRightWeapons); i++) {
        if (strcmp(TheRightWeapons[i], WepName) == 0) {
            Found = true;
        }
    }

    return Found;
}

public Action:ISDM_ForceReload(Handle:timer, any:client) { // A timed timer to force reload, supposed to match modified reload times
    int PlyWep = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
    SetEntPropFloat(client, Prop_Send, "m_flNextAttack", 1.0);
    SetEntPropFloat(PlyWep, Prop_Send, "m_flNextPrimaryAttack", 1.0);
    SetEntPropFloat(PlyWep, Prop_Send, "m_flNextSecondaryAttack", 1.0);
}

public Action:OnPlayerRunCmd(client, int& buttons, int& impulse, float vel[3], float angles[3]) {
    new String:WepClass[32];
    new Float:currentPos[3];
    int PlyWep = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
    int Viewmodel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
    bool IsReloading = false;


    if (IsValidEntity(PlyWep)) {
        GetEntityClassname(PlyWep, WepClass, 32);
        IsReloading = GetEntProp(PlyWep, Prop_Data, "m_bInReload");
    }

    GetClientAbsOrigin(client, currentPos);

    if (GetEntityMoveType(client) != MOVETYPE_NOCLIP) { // Make sure noclipping players don't skate or get perks, that could be annoying for admins
        if (IsClientConnected(client) && IsPlayerAlive(client)) {
            new Float:currentSpeed[3];
            GetEntPropVector(client, Prop_Data, "m_vecVelocity", currentSpeed);

    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////// BASIC PERK LOGIC ///////////////////////////////
            float x = currentSpeed[0];
            float y = currentSpeed[1];
            float z = currentSpeed[2];
            bool CanSprintX = (x >= 0 && x > 435.0 || x <= 0 && x < -435.0);
            bool CanSprintY = (y >= 0 && y > 435.0 || y <= 0 && y < -435.0);
            bool IsSlowX = (x >= 0 && x < MAXSLOWSPEED || x <= 0 && x > -MAXSLOWSPEED);
            bool IsSlowY = (y >= 0 && y < MAXSLOWSPEED || y <= 0 && y > -MAXSLOWSPEED);
            bool IsFast1X = (x >= SPEED1SPEED && x < SPEED2SPEED || x <= -SPEED1SPEED && x > -SPEED2SPEED);
            bool IsFast1Y = (y >= SPEED1SPEED && y < SPEED2SPEED || y <= -SPEED1SPEED && y > -SPEED2SPEED);
            bool IsFast2X = (x >= SPEED2SPEED && x < SPEED3SPEED || x <= -SPEED2SPEED && x > -SPEED3SPEED);
            bool IsFast2Y = (y >= SPEED2SPEED && y < SPEED3SPEED || y <= -SPEED2SPEED && y > -SPEED3SPEED);
            bool IsFast3X = (x >= SPEED3SPEED || x <= -SPEED3SPEED);
            bool IsFast3Y = (y >= SPEED3SPEED || y <= -SPEED3SPEED);
            bool IsHigh = (z >= MAXAIRHEIGHT || z <= -MAXAIRHEIGHT && z < 0);
            bool NotSlow = (!IsSlowX && !IsSlowY);
            bool NotFast = (!IsFast1X && !IsFast1Y && !IsFast2X && !IsFast2Y && !IsFast3X && !IsFast3Y)
            bool NotOnGround = (GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1);
            bool SpeedPerk1Enabled = (ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk1]) || ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk2]) || ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk3]));
            bool SpeedPerk2Enabled = (ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk2]) || ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk3]));

            if (NotFast && !IsHigh) { // Display no perks if the user has no perks active
                ISDM_AddPerk(client, ISDM_Perks[ISDM_NoPerks]);
            } else {
                ISDM_DelFromArray(ISDM_Perks[ISDM_NoPerks], client);
            }

    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////// ISDM AIR LOGIC (& perk) ///////////////////////////////////////
            if (NotOnGround) { // Apply air perk
                new Float:plyPos[3];
                new Float:ThingBelowPly[3];   
                GetClientAbsOrigin(client, plyPos);     
                new Handle:TraceZ = TR_TraceRayFilterEx(plyPos, {90.0, 0.0, 0.0}, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);

                if (PlayerIsBoosting[client] == false) { // Only change their gravity if they aren't boosting themselves
                    if (TR_DidHit(TraceZ)) { // Kinda useless since it will always hit, but better safe than sorry
                        TR_GetEndPosition(ThingBelowPly, TraceZ);          
                        new Float:PlyDistanceToGround = GetVectorDistance(plyPos, ThingBelowPly);

                        if (PlyInitialHeight[client] == 0.0) {
                            PlyInitialHeight[client] = PlyDistanceToGround;
                        }

                        if (PlyInitialHeight[client] > 300) { // Make it seem like they are NOT being sucked into the ground when falling from high up
                            SetEntPropFloat(client, Prop_Data, "m_flGravity", 2.3); 
                        } else {
                            if (PlyDistanceToGround > MAXAIRHEIGHT) { // They are officially in the air now
                                ISDM_AddPerk(client, ISDM_Perks[ISDM_AirPerk]);
                            }

                            new Float:GravityEquation = (GetVectorDistance(plyPos, ThingBelowPly) / 50.0); // The higher you are the more brutal the gravity increases (Unless you start falling from high up already)               
                            if (GravityEquation > 1.0) { // Make sure low gravity never occurs
                                SetEntPropFloat(client, Prop_Data, "m_flGravity", GravityEquation);   
                            }   
                        }  
                        CloseHandle(TraceZ);  
                    } else {
                        CloseHandle(TraceZ);  
                    }
                } else { // The player is boosting themselves with explosions
                    SetEntPropFloat(client, Prop_Data, "m_flGravity", 2.3); 
                }
            } else { // If player is on the ground
                ISDM_DelFromArray(ISDM_Perks[ISDM_AirPerk], client);
                SetEntPropFloat(client, Prop_Data, "m_flGravity", 1.0);
                PlyInitialHeight[client] = 0.0;
                CreateTimer(1.0, ISDM_GroundCheck, client);
            }   

            if (ISDM_GetPerk(client, ISDM_Perks[ISDM_NoPerks])) {   
                if (IsReloading) { 
                    if (!IsValidHandle(ForceReloading[client])) { // Stops causing extreme rapid fire glitch after reloading
                        if (strcmp(WepClass, "weapon_rpg") != 0) { // Make sure the RPG never can reload faster
                            new Float:GameTime = GetGameTime();	
                            SetEntPropFloat(Viewmodel, Prop_Send, "m_flPlaybackRate", 1.0);
                            SetEntPropFloat(Viewmodel, Prop_Data, "m_flPlaybackRate", 1.0);
                            ForceReloading[client] = INVALID_HANDLE;
                        } 
                    }
                }  
            }
    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////// SPEED PERK #1 //////////////////////////////////
            if (SpeedPerk1Enabled) { // Push all props near players with speed perk #1
                // Make sure distance increases as the player goes faster or they will run into props still!:
                new Float:PropDist = 350.0;
                PropDist = 350.0 + PlySkates[client] * 8.5; 
        
                if (!IsValidHandle(NearbyEntSearch[client])) {
                    PushData[client] = CreateDataPack();
                    WritePackCell(PushData[client], client);
                    WritePackFloat(PushData[client], PropDist);
                    NearbyEntSearch[client] = CreateTimer(0.1, ISDM_PushNearbyEnts, PushData[client]);
                } 
            }

            if (ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk1])) {
                if (IsReloading) { 
                    if (!IsValidHandle(ForceReloading[client])) { // Stops causing extreme rapid fire glitch after reloading
                        if (strcmp(WepClass, "weapon_rpg") != 0) { // Make sure the RPG never can reload faster
                            new Float:GameTime = GetGameTime();	
                            SetEntPropFloat(Viewmodel, Prop_Send, "m_flPlaybackRate", 2.0);
                            SetEntPropFloat(Viewmodel, Prop_Data, "m_flPlaybackRate", 2.0);

                            if (strcmp(WepClass, "weapon_smg1") == 0 || strcmp(WepClass, "weapon_ar2") == 0) {   
                                ForceReloading[client] = CreateTimer(2.0, ISDM_DoNothing, client);
                            }

                            if (strcmp(WepClass, "weapon_357") != 0 && strcmp(WepClass, "weapon_rpg") != 0) {
                                ForceReloading[client] = CreateTimer(1.0, ISDM_DoNothing, client);
                                CreateTimer(0.7, ISDM_ForceReload, client);
                            }   

                            if (strcmp(WepClass, "weapon_357") == 0) {
                                CreateTimer(1.6, ISDM_ForceReload, client);
                                ForceReloading[client] = CreateTimer(2.0, ISDM_DoNothing, client);
                            }
                        } 
                    }
                }  

                if (buttons & IN_ATTACK || buttons & IN_ATTACK2) {
                    if (SearchForWep(WepClass)) {    
                        ISDM_IncreaseFire(client, 1.1);
                    }

                    if (strcmp(WepClass, "weapon_shotgun") == 0) {
                        ISDM_IncreaseFire(client, 1.5);
                    }       
                }  
            }

            if (IsFast1X || IsFast1Y) { // Apply speed perks #1
                ISDM_AddPerk(client, ISDM_Perks[ISDM_SpeedPerk1]);
            } else {
                ISDM_DelFromArray(ISDM_Perks[ISDM_SpeedPerk1], client);
            }         
    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////// SPEED PERK #2 //////////////////////////////////
            if (ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk2])) {
                if (IsReloading) { 
                    if (!IsValidHandle(ForceReloading[client])) { // Stops causing extreme rapid fire glitch after reloading
                        if (strcmp(WepClass, "weapon_rpg") != 0) { // Make sure the RPG never can reload faster
                            new Float:GameTime = GetGameTime();	
                            SetEntPropFloat(Viewmodel, Prop_Send, "m_flPlaybackRate", 3.0);
                            SetEntPropFloat(Viewmodel, Prop_Data, "m_flPlaybackRate", 3.0);

                            if (strcmp(WepClass, "weapon_smg1") == 0 || strcmp(WepClass, "weapon_ar2") == 0) {   
                                ForceReloading[client] = CreateTimer(2.0, ISDM_DoNothing, client);
                            }

                            if (strcmp(WepClass, "weapon_357") != 0 && strcmp(WepClass, "weapon_rpg") != 0) {
                                ForceReloading[client] = CreateTimer(1.0, ISDM_DoNothing, client);
                                CreateTimer(0.5, ISDM_ForceReload, client);
                            }   

                            if (strcmp(WepClass, "weapon_357") == 0) {
                                CreateTimer(1.3, ISDM_ForceReload, client);
                                ForceReloading[client] = CreateTimer(2.0, ISDM_DoNothing, client);
                            }
                        } 
                    }
                }

                if (buttons & IN_ATTACK || buttons & IN_ATTACK2) {
                    if (SearchForWep(WepClass)) {
                        ISDM_IncreaseFire(client, 1.2);
                    } 

                    if (strcmp(WepClass, "weapon_shotgun") == 0) {
                        ISDM_IncreaseFire(client, 2.0);
                    }                    
                }
            }

            if (IsFast2X || IsFast2Y) { // Apply speed perks #2
                ISDM_AddPerk(client, ISDM_Perks[ISDM_SpeedPerk2]);
            } else {
                ISDM_DelFromArray(ISDM_Perks[ISDM_SpeedPerk2], client);
            }         
    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////// SPEED PERK #3 //////////////////////////////////
            if (ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk3])) {
                if (buttons & IN_ATTACK || buttons & IN_ATTACK2) {
                    if (SearchForWep(WepClass)) {
                        ISDM_IncreaseFire(client, 1.3);
                    } 

                    if (strcmp(WepClass, "weapon_shotgun") == 0) {
                        ISDM_IncreaseFire(client, 2.5);
                    }        
                }

                if (IsReloading) { 
                    if (!IsValidHandle(ForceReloading[client])) { // Stops causing extreme rapid fire glitch after reloading
                        if (strcmp(WepClass, "weapon_rpg") != 0) { // Make sure the RPG never can reload faster
                            new Float:GameTime = GetGameTime();	
                            SetEntPropFloat(Viewmodel, Prop_Send, "m_flPlaybackRate", 4.0);
                            SetEntPropFloat(Viewmodel, Prop_Data, "m_flPlaybackRate", 4.0);

                            if (strcmp(WepClass, "weapon_smg1") == 0 || strcmp(WepClass, "weapon_ar2") == 0) {   
                                ForceReloading[client] = CreateTimer(2.0, ISDM_DoNothing, client);
                            }

                            if (strcmp(WepClass, "weapon_357") != 0 && strcmp(WepClass, "weapon_rpg") != 0) {
                                ForceReloading[client] = CreateTimer(1.0, ISDM_DoNothing, client);
                                CreateTimer(0.2, ISDM_ForceReload, client);
                            }   

                            if (strcmp(WepClass, "weapon_357") == 0) {
                                CreateTimer(1.0, ISDM_ForceReload, client);
                                ForceReloading[client] = CreateTimer(2.0, ISDM_DoNothing, client);
                            }
                        } 
                    }
                }
            }

            if (IsFast3X || IsFast3Y) { // Apply speed perks #3
               ISDM_AddPerk(client, ISDM_Perks[ISDM_SpeedPerk3]);
            } else {
                ISDM_DelFromArray(ISDM_Perks[ISDM_SpeedPerk3], client);
            }
    /////////////////////////////////////////////////////////////////////////////
    /////////////////////////// BASIC ISDM PLAYER LOGIC ///////////////////////// 
            if (buttons & IN_SPEED) {   
            } else {
                DeniedSprintSoundPlayed[client] = false;
            }
            
            if (PlySkates[client] > 0.0 && CanSprintX && CanSprintY && buttons & IN_SPEED) { // Stop player from sprinting if they are skating
                SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", 190.0); // Basically if you sprint you seem like you're still walking
                StopSound(client, 2, "player/suit_sprint.wav");

                if (DeniedSprintSoundPlayed[client] == false) {
                    EmitSoundToClient(client, "player/suit_denydevice.wav", _, 2, _, _, 1.0, _, _, _, _, _);
                    DeniedSprintSoundPlayed[client] = true;
                }
            } 
            
            if (GetEntPropFloat(client, Prop_Data, "m_flMaxspeed") == 190.0) { 
                //SetEntPropFloat(client, Prop_Data, "m_flSuitPower", 101.0); // If you go over 100.0 aux power it breaks the aux hud thus hiding it like we want
            }

            if (buttons & IN_JUMP) { 
                buttons &= ~IN_JUMP;
                return Plugin_Continue; 
            } 

            bool ValidSkateLeft = SkatedRight[client] && !SkatedLeft[client];
            bool ValidSkateRight = SkatedLeft[client] && !SkatedRight[client];

            if (buttons & 1 << 9 && buttons & 1 << 10 ) { // They are not skating they are just moving left and right at the same time...
            } else {
                if (buttons & IN_MOVELEFT) {
                    ElapsedRightTime[client] = 0; // They've let go of the right key, so reset the right key time as they are no longer holding it down
                }

                if (buttons & IN_MOVERIGHT) {
                    ElapsedLeftTime[client] = 0; 
                }

                if (ElapsedLeftTime[client] > 2 || ElapsedRightTime[client] > 2) { // They have let go of the skate keys for too long, make them lose speed
                    if (PlySkates[client] > 0) {
                        PlySkates[client]--;
                    }
                }

                if (!IsValidHandle(ResolveDirectionsLeft[client]) || !IsValidHandle(ResolveDirectionsRight[client]) && !IsValidHandle(AddDirection[client])) {
                    if (!IsValidHandle(AddTimeToPressedKey[client])) {
                        AddTimeToPressedKey[client] = CreateTimer(1.0, ISDM_AddKeyTime, client);
                    }
                    
                    AddDirection[client] = CreateTimer(1.0, ISDM_AddDirection, client);
                } else {
                    AddDirection[client] = INVALID_HANDLE;
                }

                if (!ValidSkateLeft && !ValidSkateRight) {
                    if (buttons & IN_MOVELEFT) {
                        SkatedRight[client] = false;
                        SkatedLeft[client] = true;
                    }

                    if (buttons & IN_MOVERIGHT) {
                        SkatedLeft[client] = false;
                        SkatedRight[client] = true;
                    }
                }

                if (!NotOnGround) {
                    if (buttons & IN_MOVELEFT && ValidSkateLeft || buttons & IN_MOVERIGHT && ValidSkateRight) {
                        ISDM_SkateSound(client)
                        if (!IsValidHandle(AddPlySkate[client])) {
                            AddPlySkate[client] = CreateTimer(0.1, ISDM_IncrementSkate, client);
                        } 
                    } else {
                        AddPlySkate[client] = INVALID_HANDLE;
                    }
                }

                if (buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT) { // Player is skating                      
                    if (PlySkates[client] > 0) {
                        float direction[3];
                        NormalizeVector(currentSpeed, direction);
                        ScaleVector(direction, PlySkates[client]);
                        AddVectors(currentSpeed, direction, currentSpeed);
                        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, currentSpeed); 
                        return Plugin_Continue; 
                    }
                } else { // The player is not skating   
                    if (x < 150 && y < 150 && x > 0 && y > 0) {  // They haven't really skated     
                        x = x / 2;
                        y = y / 2;
                        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, currentSpeed); // Make them slower unless they are skating
                        return Plugin_Continue; 
                    } 

                    if (PlySkates[client] > 0.0) {
                        PlySkates[client] = PlySkates[client] - 3; // Make them  lose a lot of speed if they stop skating
                    }
                }             
            } 
        }
    }

    return Plugin_Continue;
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
    return entity <= 0 || entity > MaxClients;
} 

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////// ISDM SOUND LOGIC //////////////////////////////////
int CHAN_AUTO = 0;
int SNDLVL_NORM = 75;

public ISDM_StopSounds() { // These are the sounds that are replaced/unwanted
    for (new i = 1; i <= ISDM_MaxPlayers; i++) {
        StopSound(i, CHAN_AUTO, "player/pl_fallpain1.wav");
        StopSound(i, CHAN_AUTO, "player/pl_fallpain3.wav");
    }
}

public ISDM_MuteSkateSounds(client) { // Stops emitting ice skate sounds from a client
    new String:SkateSounds[][] = {"skate01", "skate02", "skate03"};
    for (new i = 0; i < sizeof(SkateSounds); i++) {
        new String:SoundFile[58];
        Format(SoundFile, sizeof(SoundFile), "IceSkateDM/%s.wav", SkateSounds[i]);
        if (IsSoundPrecached(SoundFile)) {
            StopSound(client, CHAN_AUTO, SoundFile);
        }
    }    
}

public ISDM_ImpactSound(client) { // Replaces the fall damage sound with the new ice one
    new String:RandomImpact[][] = {"impact01.wav", "impact02.wav"};
    new String:SoundName[40];
    int RandomIndex = GetRandomInt(0, 1); 
    Format(SoundName, sizeof(SoundName), "IceSkateDM/%s", RandomImpact[RandomIndex]); // Randomly chooses between impact01 and impact02
    PrecacheSound(SoundName);
    EmitSoundToAll(SoundName, client, CHAN_AUTO, SNDLVL_NORM, _, 1.0, _, _, _, _, _, _); // Plays the ice impact sound
}

public ISDM_SkateSound(client) { // Plays a random ice skate sound for skating players
    if (!IsValidHandle(TimeForSkateSound[client])) { // If a skate sound isn't already in progress
        new String:RandomSound[][] = {"skate01", "skate02", "skate03"};
        new String:SoundName[40];
        int RandomIndex = GetRandomInt(0, 2);
        Format(SoundName, sizeof(SoundName), "IceSkateDM/%s.wav", RandomSound[RandomIndex]);
        TimeForSkateSound[client] = CreateTimer(0.50, ISDM_DoNothing);
        PrecacheSound(SoundName);
        EmitSoundToAll(SoundName, client, CHAN_AUTO, SNDLVL_NORM, _, 0.40, _, _, _, _, _, _); // Plays the ice skate sound
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////// ISDM SKATE LOGIC //////////////////////////////////
public Action:ISDM_IncrementSkate(Handle:timer, any:client) {
    if (IsValidEntity(client)) {   
        if (GetClientButtons(client) & 1 << 9 && GetClientButtons(client) & 1 << 10 ) {
        } else {
            if (PlySkates[client] < 8) { // Give them an easy chance to skate fast
                PlySkates[client] = PlySkates[client] + 2;
            } else if (PlySkates[client] < 20) {
                PlySkates[client]++; // They are pretty fast now, start adding normal speed boosts
            } else {
                PlySkates[client] = PlySkates[client] + 0.5; // They are going super fast, add smaller speed boosts
            }
        }
    }
}

public Action:ISDM_AddKeyTime(Handle:timer, any:client) {
    if (IsValidEntity(client)) {
        if (GetClientButtons(client) & IN_MOVELEFT) {
            ElapsedLeftTime[client]++;
        }

        if (GetClientButtons(client) & IN_MOVERIGHT) {
            ElapsedRightTime[client]++;
        }
    }
}

public Action:ISDM_AddDirection(Handle:timer, any:client) {
    if (IsValidEntity(client)) {
        if (GetClientButtons(client) & IN_MOVELEFT) {
            SkatedLeft[client] = true;
            SkatedRight[client] = false;
        }

        if (GetClientButtons(client) & IN_MOVERIGHT) {
            SkatedRight[client] = true;
            SkatedLeft[client] = false;
        }
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////// ISDM PERK STUFF ////////////////////////////////
public void ISDM_PerkChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
    ISDM_UpdatePerkVars();
}

public void ISDM_UpdatePerkVars() {
    MAXSLOWSPEED = GetConVarFloat(FindConVar("ISDM_SlowPerkSpeed"));
    SPEED1SPEED = GetConVarFloat(FindConVar("ISDM_FastPerk1Speed"));
    SPEED2SPEED = GetConVarFloat(FindConVar("ISDM_FastPerk2Speed"));
    SPEED3SPEED = GetConVarFloat(FindConVar("ISDM_FastPerk3Speed"));
    MAXAIRHEIGHT = GetConVarFloat(FindConVar("ISDM_AirPerkHeight"));
}

public void ISDM_UpdatePerks(client) {
    if (IsValidEntity(client)) {
        bool Only1SpeedPerk = (ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk1]) && !ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk2]));
        bool Only2SpeedPerks = (ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk2]) && !ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk3]));
        bool AllSpeedPerks = (ISDM_GetPerk(client, ISDM_Perks[ISDM_SpeedPerk3]));
        bool Speed1AndAir = (Only1SpeedPerk && ISDM_GetPerk(client, ISDM_Perks[ISDM_AirPerk]));
        bool Speed2AndAir = (Only2SpeedPerks && ISDM_GetPerk(client, ISDM_Perks[ISDM_AirPerk]));
        bool Speed3AndAir = (AllSpeedPerks && ISDM_GetPerk(client, ISDM_Perks[ISDM_AirPerk]));
        bool OnlyAirPerk = (ISDM_GetPerk(client, ISDM_Perks[ISDM_AirPerk]) && !Only1SpeedPerk && !Only2SpeedPerks && !AllSpeedPerks && !Speed1AndAir && !Speed2AndAir && !Speed3AndAir)

        if (ISDM_GetPerk(client, ISDM_Perks[ISDM_NoPerks])) {
            ClientCommand(client, "r_screenoverlay 0");
        }

        if (OnlyAirPerk) {
            ClientCommand(client, "r_screenoverlay IceSkateDM/airperk");
        }

        if (Only1SpeedPerk && !Speed1AndAir) {
            ClientCommand(client, "r_screenoverlay IceSkateDM/1speedperk");
        }

        if (Only2SpeedPerks && !Speed2AndAir) {
            ClientCommand(client, "r_screenoverlay IceSkateDM/2speedperks");
        }

        if (AllSpeedPerks && !Speed3AndAir) {
            ClientCommand(client, "r_screenoverlay IceSkateDM/allspeedperks");
        }

        if (Speed1AndAir) {
            ClientCommand(client, "r_screenoverlay IceSkateDM/1speedperkandair");
        }

        if (Speed2AndAir) {
            ClientCommand(client, "r_screenoverlay IceSkateDM/2speedperksandair");
        }

        if (Speed3AndAir) {
            ClientCommand(client, "r_screenoverlay IceSkateDM/allspeedperksandair");
        }
        
        if (SkatedRight[client] && GetClientButtons(client) & IN_MOVERIGHT) {          
            if (ISDM_GetPerk(client, ISDM_Perks[ISDM_NoPerks])) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Left/leftarrow");
            }

            if (OnlyAirPerk) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Left/leftandairperk");
            }

            if (Only1SpeedPerk && !Speed1AndAir) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Left/leftand1speedperk");
            }

            if (Only2SpeedPerks && !Speed2AndAir) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Left/leftand2speedperks");
            }

            if (AllSpeedPerks && !Speed3AndAir) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Left/leftandallspeedperks");
            }

            if (Speed1AndAir) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Left/left1speedperkandair");
            }

            if (Speed2AndAir) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Left/left2speedperksandair");
            }

            if (Speed3AndAir) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Left/leftallspeedperksandair");
            }
        }
            
        if (SkatedLeft[client] && GetClientButtons(client) & IN_MOVELEFT) {
            if (ISDM_GetPerk(client, ISDM_Perks[ISDM_NoPerks])) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Right/rightarrow");
            }

            if (OnlyAirPerk) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Right/rightandairperk");
            }

            if (Only1SpeedPerk && !Speed1AndAir) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Right/rightand1speedperk");
            }

            if (Only2SpeedPerks && !Speed2AndAir) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Right/rightand2speedperks");
            }

            if (AllSpeedPerks && !Speed3AndAir) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Right/rightandallspeedperks");
            }

            if (Speed1AndAir) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Right/right1speedperkandair");
            }

            if (Speed2AndAir) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Right/right2speedperksandair");
            }

            if (Speed3AndAir) {
                ClientCommand(client, "r_screenoverlay IceSkateDM/Right/rightallspeedperksandair");
            }
        }
    }
}

public Action:ISDM_DoNothing(Handle:timer, any:client) {}

public void ISDM_AddPerk(client, Handle:array) {
    if (FindValueInArray(array, client) < 0) { 
        PushArrayCell(array, client);
        ClientCommand(client, "r_screenoverlay 0");
    } 
}

public void ISDM_RemovePerk(client, Handle:array) {
    if (FindValueInArray(array, client) > -1) { 
        ISDM_DelFromArray(array, FindValueInArray(array, client));
    }
}

public ISDM_GetPerk(client, perk) {
    bool HasPerk;
    if (FindValueInArray(perk, client) > -1) {
        HasPerk = true;
    } else {
        HasPerk = false;
    }

    return HasPerk;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////// ISDM PROJECTILE STUFF ////////////////////////
public OnEntityCreated(entity, const String:classname[]) {
    if (IsValidEntity(entity)) {  
        if (strcmp(classname, "prop_combine_ball", false) == 0) { // Make projectiles always move faster than the player
            CreateTimer(0.2, GetClosestPlyToProj, entity);
        }

        // if (strcmp(classname, "grenade_ar2", false) == 0) {
        //     float currentSpeed[3];
        //     float direction[3];
        //     GetEntPropVector(entity, Prop_Data, "m_vecVelocity", currentSpeed); // Projectile's speed
        //     NormalizeVector(currentSpeed, direction);
        //     ScaleVector(direction, 99999.0);
        //     AddVectors(currentSpeed, direction, currentSpeed);
        //     TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, currentSpeed); 
        // }
    }
}

public Action:GetClosestPlyToProj(Handle:timer, any:entity) { // Calculates the closest player to the projectile entity, assumes this is the owner.
    if (IsValidEntity(entity)) {
        new Float:currentSpeed[3];
        GetEntPropVector(entity, Prop_Data, "m_vecVelocity", currentSpeed); // Projectile's speed

        if (currentSpeed[0] + currentSpeed[1] + currentSpeed[2] >= 300 || currentSpeed[0] + currentSpeed[1] + currentSpeed[2] <= -300) { // Make sure that it's not just an orb spawned by the map    
            new Float:projVector[3];
            new Float:playerDistance;
            int player;
            GetEntPropVector(entity, Prop_Data, "m_vecOrigin", projVector); // Projectile's position
            
            for(new i = 1; i <= ISDM_MaxPlayers; i++) // Loop through all players
            {
                new Float:playerVector[3];
                if (IsClientInGame(i)) {
                    GetEntPropVector(i, Prop_Data, "m_vecOrigin", playerVector); // Player's position
                    if (GetVectorDistance(playerVector, projVector) < playerDistance || playerDistance == 0) { // Found a closer player or this is the first distance calculated
                        playerDistance = GetVectorDistance(playerVector, projVector);
                        player = i; // The closest player to the projectile
                    } 
                }
            }
            
            if (ISDM_GetPerk(player, ISDM_Perks[ISDM_SpeedPerk1])) {
                SetEntPropFloat(entity, Prop_Data, "m_flSpeed", 1500.0);
            }

            if (ISDM_GetPerk(player, ISDM_Perks[ISDM_SpeedPerk2])) {
                SetEntPropFloat(entity, Prop_Data, "m_flSpeed", 2000.0);
            }

            if (ISDM_GetPerk(player, ISDM_Perks[ISDM_SpeedPerk3])) {
                SetEntPropFloat(entity, Prop_Data, "m_flSpeed", 2500.0 );
            }
        } 
    }
}