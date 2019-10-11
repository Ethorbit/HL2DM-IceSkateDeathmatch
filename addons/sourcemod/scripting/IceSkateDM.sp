// Ice Skate Deathmatch is a thing now thanks to Himanshu's choice of commands :)

// TODO:
// Scale gravity by player's velocity as well so that they never get outside the bounds of the map
// Make unusually slow at first, but gain speed over time at an unusal rate

public Plugin:myinfo =
{
	name = "Ice Skate Deathmatch",
	author = "Ethorbit",
	description = "Greatly changes the way deathmatch is played introducing new techniques & perks",
	version = "1.0",
	url = ""
}

#include <sdktools>
#include <sdkhooks>
#include <convars>

new String:ISDM_MaterialDirectory[] = "IceSkateDM" // The directory in the materials folder where the gamemode's materials are in
new String:ISDM_Materials[8][58] = { // The materials the gamemode uses
    "slowperk", 
    "1speedperk", 
    "1speedperkandair", 
    "2speedperks", 
    "2speedperksandair", 
    "allspeedperks",
    "allspeedperksandair",
    "airperk"
}

new ISDM_MaxPlayers;
new Handle:AddPlySkate[MAXPLAYERS + 1];
new Handle:ResetPlySkates[MAXPLAYERS + 1];
new Float:PlySkates[MAXPLAYERS + 1];
new Float:PlyInitialHeight[MAXPLAYERS + 1];
bool SkatedLeft[MAXPLAYERS + 1];
bool SkatedRight[MAXPLAYERS + 1];
new Float:MAXSLOWSPEED;
new Float:MAXAIRHEIGHT;
new Float:SPEED1SPEED;
new Float:SPEED2SPEED;
new Float:SPEED3SPEED;

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
    SetConVarFloat(FindConVar("sv_friction"), 1.0, false, false); // No other way found so far to allow players to slide :(
    SetConVarFloat(FindConVar("sv_accelerate"), 100.0, false, false); // Very much optional, playable without it
    SetConVarFloat(FindConVar("sv_airaccelerate"), 9999.0, false, false); // Based on feedback airaccelerate is more popular than custom movement
    ISDM_PerkVars[SlowPerkSpeedConVar] = CreateConVar("ISDM_SlowPerkSpeed", "210.0", "The maximum speed players can go to get Slow Perk", FCVAR_SERVER_CAN_EXECUTE);
    ISDM_PerkVars[FastPerk1SpeedConVar] = CreateConVar("ISDM_FastPerk1Speed", "600.0", "The maximum speed players can go to get Fast Perk #1", FCVAR_SERVER_CAN_EXECUTE);
    ISDM_PerkVars[FastPerk2SpeedConVar] = CreateConVar("ISDM_FastPerk2Speed", "800.0", "The maximum speed players can go to get Fast Perk #2", FCVAR_SERVER_CAN_EXECUTE);
    ISDM_PerkVars[FastPerk3SpeedConVar] = CreateConVar("ISDM_FastPerk3Speed", "1100.0", "The maximum speed players can go to get Fast Perk #3", FCVAR_SERVER_CAN_EXECUTE);
    ISDM_PerkVars[AirPerkHeightConVar] = CreateConVar("ISDM_AirPerkHeight", "50.0", "The minimum height speed players need to go before they get Air Perk", FCVAR_SERVER_CAN_EXECUTE);
    ISDM_UpdatePerkVars();

    for (new i = 0; i < sizeof(ISDM_Materials); i++) { // Loop through all Ice Skate Deathmatch materials and force clients to download them
        int MaxMatLength = 58;
        new String:VTFs[MaxMatLength];
        new String:VMTs[MaxMatLength];
        Format(VTFs, MaxMatLength, "materials/%s/%s.vtf", ISDM_MaterialDirectory, ISDM_Materials[i]);
        Format(VMTs, MaxMatLength, "materials/%s/%s.vmt", ISDM_MaterialDirectory, ISDM_Materials[i]);
        AddFileToDownloadsTable(VTFs);
        AddFileToDownloadsTable(VMTs);
        PrecacheDecal(VTFs);
    }

    new const perkvar[5] = {SlowPerkSpeedConVar, FastPerk1SpeedConVar, FastPerk2SpeedConVar, FastPerk3SpeedConVar, AirPerkHeightConVar}; 
    for (new i = 0; i < sizeof(perkvar); i++) { // Loop through each perk convar and hook it to the ISDM_PerkChanged() function
        HookConVarChange(ISDM_PerkVars[perkvar[i]], ISDM_PerkChanged);
    }

    new const PerkIncrement[6] = {ISDM_NoPerks, ISDM_SlowPerk, ISDM_AirPerk, ISDM_SpeedPerk1, ISDM_SpeedPerk2, ISDM_SpeedPerk3};
    for (new i = 0; i < sizeof(PerkIncrement); i++) { // Loop through each perk and assign it to an array
        ISDM_Perks[PerkIncrement[i]] = CreateArray(32);
    }

    for (new i = 1; i <= ISDM_MaxPlayers; i++) { // Loop through each player
        PlyInitialHeight[i] = 0.0;
        PlySkates[i] = 0.0;
        AddPlySkate[i] = INVALID_HANDLE;
        ResetPlySkates[i] = INVALID_HANDLE;
        SkatedRight[i] = false;
        SkatedLeft[i] = false;
    }
}

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

public void ISDM_DelFromArray(Handle:array, item) {
    if (FindValueInArray(array, item) > -1) {
        RemoveFromArray(array, FindValueInArray(array, item));
    }
}

public OnEntityCreated(entity, const String:classname[]) {
    if (IsValidEntity(entity)) {
        if (strcmp(classname, "prop_combine_ball", true) == 0 || strcmp(classname, "grenade_ar2", true) == 0) { // Make projectiles always move faster than the player
            CreateTimer(0.3, GetClosestPlyToProj, entity);
        }
    }
}

public Action:OnPlayerRunCmd(client, int& buttons, int& impulse, float vel[3], float angles[3])   
{
    new Float:currentPos[3];
    GetClientAbsOrigin(client, currentPos);

    if (GetEntityMoveType(client) != MOVETYPE_NOCLIP) { // Make sure noclipping players don't skate or get perks, that could be annoying for admins
        if (!IsPlayerAlive(client)) {
            ClientCommand(client, "r_screenoverlay 0"); // Reset perks since they died
        }

        if (IsClientConnected(client) && IsPlayerAlive(client)) {
            new Float:currentSpeed[3];
            GetEntPropVector(client, Prop_Data, "m_vecVelocity", currentSpeed);

    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////// BASIC PERK LOGIC ///////////////////////////////
            float x = currentSpeed[0];
            float y = currentSpeed[1];
            float z = currentSpeed[2];
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
    
            if (NotSlow && NotFast && !IsHigh) { // Display no perks if the user has no perks active
                ISDM_AddPerk(client, ISDM_Perks[ISDM_NoPerks]);
                ISDM_UpdatePerks(client);
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
                            ISDM_UpdatePerks(client);
                        }

                        new Float:GravityEquation = (GetVectorDistance(plyPos, ThingBelowPly) / 60.0); // The higher you are the more brutal the gravity increases (Unless you start falling from high up already)               
                        if (GravityEquation > 1.0) { // Make sure low gravity never occurs
                            SetEntPropFloat(client, Prop_Data, "m_flGravity", GravityEquation);   
                        }     
                    }
                }
            } else { // If player is on the ground
                ISDM_DelFromArray(ISDM_Perks[ISDM_AirPerk], client);
                SetEntPropFloat(client, Prop_Data, "m_flGravity", 1.0);
                PlyInitialHeight[client] = 0.0;
            }          
    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////// SLOW PERK //////////////////////////////////////
            if (IsSlowX && IsSlowY && !IsHigh) { // Apply slow perk
                ISDM_AddPerk(client, ISDM_Perks[ISDM_SlowPerk]);
                ISDM_UpdatePerks(client);
            } else {
                ISDM_DelFromArray(ISDM_Perks[ISDM_SlowPerk], client);
            }
    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////// SPEED PERK #1 //////////////////////////////////
            if (IsFast1X || IsFast1Y) { // Apply speed perks #1
                ISDM_AddPerk(client, ISDM_Perks[ISDM_SpeedPerk1]);
                ISDM_UpdatePerks(client);
            } else {
                ISDM_DelFromArray(ISDM_Perks[ISDM_SpeedPerk1], client);
            }
    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////// SPEED PERK #2 //////////////////////////////////
            if (IsFast2X || IsFast2Y) { // Apply speed perks #2
                ISDM_AddPerk(client, ISDM_Perks[ISDM_SpeedPerk2]);
                ISDM_UpdatePerks(client);
            } else {
                ISDM_DelFromArray(ISDM_Perks[ISDM_SpeedPerk2], client);
            }
    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////// SPEED PERK #3 //////////////////////////////////
            if (IsFast3X || IsFast3Y) { // Apply speed perks #3
               ISDM_AddPerk(client, ISDM_Perks[ISDM_SpeedPerk3]);
               ISDM_UpdatePerks(client);
            } else {
                ISDM_DelFromArray(ISDM_Perks[ISDM_SpeedPerk3], client);
            }
    /////////////////////////////////////////////////////////////////////////////
    /////////////////////////// BASIC ISDM PLAYER LOGIC /////////////////////////       
            if (buttons & IN_JUMP) { 
                buttons &= ~IN_JUMP;
                return Plugin_Continue; 
            } 

            new Float:TheirSkates = PlySkates[client];
           // PrintToChat(client, "Current skates achieved: %f", TheirSkates);
            if (buttons & 1 << 9 && buttons & 1 << 10 ) { // They are not skating they are just moving left and right at the same time...
            } else {
                // int Left = SkateLeft[client];
                // int Right = SkateRight[client];

                //PrintToServer("Their right amount: %i Their left amount: %i", SkatedRight[client], SkatedLeft[client]);

                if (buttons & IN_MOVELEFT) {
                    if (!IsValidHandle(AddPlySkate[client])) {
                        if (SkatedLeft[client] == false) { // Make sure they are switching between left and right
                            AddPlySkate[client] = CreateTimer(0.1, ISDM_IncrementSkate, client);
                        } else { // They failed to skate properly
                            //ISDM_LoseSpeed(client);
                            PrintToServer("Losing speed");
                        }
                    }
                }

                if (buttons & IN_MOVERIGHT) {
                    if (!IsValidHandle(AddPlySkate[client])) {
                        if (SkatedRight[client] == false) { // Make sure they are switching between left and right
                            AddPlySkate[client] = CreateTimer(0.1, ISDM_IncrementSkate, client);
                        } else { // They failed to skate properly
                            //ISDM_LoseSpeed(client);
                            PrintToServer("Losing speed");
                        }
                    }
                }

                if (buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT) { // Player is skating                      
                    if (TheirSkates > 0) {
                        float direction[3];
                        NormalizeVector(currentSpeed, direction);
                        ScaleVector(direction, TheirSkates);
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
                        if (!IsValidHandle(ResetPlySkates[client])) {
                            new Handle:theData = CreateDataPack();
                            WritePackCell(theData, client);
                            WritePackFloat(theData, currentPos[0]);
                            WritePackFloat(theData, currentPos[1]);
                            ResetPlySkates[client] = CreateTimer(0.5, ISDM_ResetSkates, theData);
                        }
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
/////////////////////////// ISDM SKATE LOGIC //////////////////////////////////
public Action:ISDM_IncrementSkate(Handle:timer, any:client) {
    PlySkates[client]++;
    AddPlySkate[client] = INVALID_HANDLE; // Timer finished so let it occur again

    if (GetClientButtons(client) & IN_MOVELEFT) {
        SkatedRight[client] = false;
        SkatedLeft[client] = true;
        
        //PrintCenterText(client, "       ⫸");
    }

    if (GetClientButtons(client) & IN_MOVERIGHT) {
        SkatedLeft[client] = false;
        SkatedRight[client] = true;
        //PrintCenterText(client, "⫷      ");
    }
}

public void ISDM_LoseSpeed(client) {
    PlySkates[client] = PlySkates[client] - 2;
    SkatedLeft[client] = false;
    SkatedRight[client] = false;
} 

public Action:ISDM_ResetSkates(Handle:timer, Handle:data) { // Reset their speed if they failed to maintain skating
    ResetPack(data);
    if (IsPackReadable(data, 1)) {
        new Float:OldPos[3]; 
        new client = ReadPackCell(data);
        PlySkates[client]--;

        OldPos[0] = ReadPackFloat(data);
        OldPos[1] = ReadPackFloat(data);
        
        new Float:currentPos[3];
        GetClientAbsOrigin(client, currentPos);

        
        // if (GetVectorDistance(OldPos, currentPos) < 50.0) {
        //     PlySkates[client]--; // They are hardly moving, lower their skate amount
        // }
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////// ISDM PERK STUFF ////////////////////////////////
public void ISDM_UpdatePerks(client) {
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

    if (ISDM_GetPerk(client, ISDM_Perks[ISDM_SlowPerk])) {
        ClientCommand(client, "r_screenoverlay IceSkateDM/slowperk");
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
}

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
public Action:GetClosestPlyToProj(Handle:timer, any:entity) { // Calculates the closest player to the projectile entity, assumes this is the owner.
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

        new Handle:MultiData = CreateDataPack();
        WritePackCell(MultiData, entity);
        WritePackCell(MultiData, player);
        CreateTimer(0.5, MatchSpeedConstantly, MultiData, 3); // Where the magic happens
    } 
}

public Action:MatchSpeedConstantly(Handle:timer, Handle:data) {
    ResetPack(data);
    if (IsPackReadable(data, 1)) { // If it isn't readable it means the projectile no longer exists
        int entity = ReadPackCell(data);
        int player = ReadPackCell(data);

        if (!IsValidEntity(entity)) {
            return Plugin_Stop;
        }

        float currentSpeed[3];
        float direction[3];
        GetEntPropVector(entity, Prop_Data, "m_vecVelocity", currentSpeed); // Projectile's speed

        NormalizeVector(currentSpeed, direction);
        ScaleVector(direction, 1000.0);
        AddVectors(currentSpeed, direction, currentSpeed);
        TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, currentSpeed); 

        return Plugin_Continue;
    } else {
        return Plugin_Stop; // Projectile is gone, time to stop the timer
    }
}
////////////////////////////////////////////////////////////////////////////////////