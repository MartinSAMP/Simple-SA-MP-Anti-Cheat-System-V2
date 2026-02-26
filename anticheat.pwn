/*

Basic AC By Martin

*/


#include <a_samp>
#include <foreach>

#define MAX_SPEED_FOOT        25.0
#define MAX_SPEED_VEHICLE     40.0
#define MAX_SPEED_AIR         60.0
#define MAX_TP_DIST           40.0
#define MAX_HP                100.0
#define MAX_ARMOR             100.0
#define MAX_AMMO              9999
#define MAX_FLY_HEIGHT        25.0
#define UNDERGROUND_Z         -50.0
#define GODMODE_THRESHOLD     5
#define RAPID_FIRE_THRESHOLD  150
#define DELAY_KICK            300
#define CHECK_INTERVAL        500
#define WARN_RESET_TIME       10000
#define MAX_WARNINGS          3

enum E_AC_DATA
{
    Float:ac_PosX,
    Float:ac_PosY,
    Float:ac_PosZ,
    ac_Tick,
    ac_WarnSpeed,
    ac_WarnTP,
    ac_WarnFly,
    ac_WarnGod,
    ac_WarnRapid,
    ac_WarnWeapon,
    ac_LastShotTick,
    ac_LastWeapon,
    ac_ShotCount,
    Float:ac_LastHP,
    Float:ac_LastArmor,
    Float:ac_GroundZ,
    bool:ac_PendingKick,
    bool:ac_JustSpawned,
    bool:ac_InVehicle,
    ac_VehicleID
};

new ac_Data[MAX_PLAYERS][E_AC_DATA];
new Float:ac_VehicleSpeed[MAX_VEHICLES];
new ac_VehicleDriver[MAX_VEHICLES];

forward ac_CheckPlayer(playerid);
forward ac_ResetWarnings(playerid);
forward ac_DelayedKick(playerid);
forward ac_ResetSpawnProtection(playerid);

stock ac_IsPlayerNearGround(playerid, Float:radius = 2.0)
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    
    new Float:gx, Float:gy, Float:gz;
    if(CA_FindZ_For2DCoord(x, y, gz))
    {
        return floatabs(z - gz) < radius;
    }
    return true;
}

stock ac_IsPlayerInWater(playerid)
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    return (z < 0.5 && z > -5.0);
}

stock ac_IsPlayerOnBike(playerid)
{
    if(!IsPlayerInAnyVehicle(playerid)) return false;
    new model = GetVehicleModel(GetPlayerVehicleID(playerid));
    return (model >= 481 && model <= 483) || (model == 461 || model == 462 || model == 463 || model == 468 || model == 471 || model == 586);
}

stock ac_IsPlayerInAirVehicle(playerid)
{
    if(!IsPlayerInAnyVehicle(playerid)) return false;
    new model = GetVehicleModel(GetPlayerVehicleID(playerid));
    return (model == 417 || model == 425 || model == 447 || model == 469 || model == 476 || model == 487 || model == 488 || model == 497 || model == 548 || model == 563 || model == 592 || model == 593);
}

stock ac_GetVehicleSpeed(vehicleid)
{
    new Float:vx, Float:vy, Float:vz;
    GetVehicleVelocity(vehicleid, vx, vy, vz);
    return floatsqroot(vx*vx + vy*vy + vz*vz) * 181.5;
}

stock ac_KickPlayer(playerid, const reason[], Float:value = 0.0)
{
    if(ac_Data[playerid][ac_PendingKick]) return;
    
    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));
    
    new str[144];
    if(value != 0.0) format(str, sizeof(str), "[AC] %s kicked: %s (%.2f)", name, reason, value);
    else format(str, sizeof(str), "[AC] %s kicked: %s", name, reason);
    
    SendClientMessageToAll(0xFF4444FF, str);
    format(str, sizeof(str), "Kicked: %s", reason);
    SendClientMessage(playerid, 0xFF4444FF, str);
    
    ac_Data[playerid][ac_PendingKick] = true;
    SetTimerEx("ac_DelayedKick", DELAY_KICK, false, "i", playerid);
}

public ac_CheckPlayer(playerid)
{
    if(!IsPlayerConnected(playerid)) return;
    if(!IsPlayerSpawned(playerid)) return;
    if(ac_Data[playerid][ac_PendingKick]) return;
    if(GetPlayerState(playerid) == PLAYER_STATE_SPECTATING) return;
    if(IsPlayerAdmin(playerid) && GetPVarInt(playerid, "ac_bypass") == 1) return;
    
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    
    new tick = GetTickCount();
    new dt = tick - ac_Data[playerid][ac_Tick];
    if(dt < 1) dt = 1;
    
    new Float:dist = VectorSize(x - ac_Data[playerid][ac_PosX], y - ac_Data[playerid][ac_PosY], z - ac_Data[playerid][ac_PosZ]);
    new Float:speed = (dist / dt) * 1000.0;
    
    new state = GetPlayerState(playerid);
    new specAction = GetPlayerSpecialAction(playerid);
    new interior = GetPlayerInterior(playerid);
    new vw = GetPlayerVirtualWorld(playerid);
    
    if(state == PLAYER_STATE_ONFOOT)
    {
        new Float:maxSpeed = MAX_SPEED_FOOT;
        
        if(specAction == SPECIAL_ACTION_USEJETPACK) maxSpeed = MAX_SPEED_AIR;
        else if(specAction == SPECIAL_ACTION_DUCK) maxSpeed = 8.0;
        else if(ac_IsPlayerInWater(playerid)) maxSpeed = 5.0;
        
        if(speed > maxSpeed && !ac_Data[playerid][ac_JustSpawned])
        {
            if(!ac_IsPlayerNearGround(playerid, 5.0) || specAction == SPECIAL_ACTION_PARACHUTE)
            {
                ac_Data[playerid][ac_WarnSpeed]++;
                if(ac_Data[playerid][ac_WarnSpeed] >= MAX_WARNINGS)
                {
                    ac_KickPlayer(playerid, "Speed hack (foot)", speed);
                    return;
                }
            }
        }
        else ac_Data[playerid][ac_WarnSpeed] = 0;
    }
    else if(state == PLAYER_STATE_DRIVER)
    {
        new vid = GetPlayerVehicleID(playerid);
        new vmodel = GetVehicleModel(vid);
        new Float:vmax = MAX_SPEED_VEHICLE;
        
        if(ac_IsPlayerInAirVehicle(playerid)) vmax = MAX_SPEED_AIR;
        else if(vmodel == 520 || vmodel == 476) vmax = 80.0;
        
        new vspeed = ac_GetVehicleSpeed(vid);
        if(vspeed > vmax && !ac_Data[playerid][ac_JustSpawned])
        {
            ac_Data[playerid][ac_WarnSpeed]++;
            if(ac_Data[playerid][ac_WarnSpeed] >= MAX_WARNINGS)
            {
                ac_KickPlayer(playerid, "Vehicle speed hack", float(vspeed));
                return;
            }
        }
        else ac_Data[playerid][ac_WarnSpeed] = 0;
        
        if(ac_VehicleDriver[vid] != playerid)
        {
            if(ac_VehicleDriver[vid] != INVALID_PLAYER_ID && IsPlayerConnected(ac_VehicleDriver[vid]))
            {
                if(GetPlayerState(ac_VehicleDriver[vid]) == PLAYER_STATE_DRIVER && GetPlayerVehicleID(ac_VehicleDriver[vid]) == vid)
                {
                    ac_KickPlayer(playerid, "Seat hack");
                    return;
                }
            }
        }
        ac_VehicleDriver[vid] = playerid;
    }
    
    if(dist > MAX_TP_DIST && !ac_Data[playerid][ac_JustSpawned] && state != PLAYER_STATE_PASSENGER)
    {
        if(interior == 0 && vw == 0)
        {
            if(!ac_IsPlayerInAirVehicle(playerid))
            {
                ac_Data[playerid][ac_WarnTP]++;
                if(ac_Data[playerid][ac_WarnTP] >= 2)
                {
                    ac_KickPlayer(playerid, "Teleport hack", dist);
                    return;
                }
            }
        }
    }
    else ac_Data[playerid][ac_WarnTP] = 0;
    
    if(z > ac_Data[playerid][ac_GroundZ] + MAX_FLY_HEIGHT && state == PLAYER_STATE_ONFOOT)
    {
        if(specAction != SPECIAL_ACTION_USEJETPACK && specAction != SPECIAL_ACTION_PARACHUTE)
        {
            if(interior == 0 && vw == 0 && !ac_IsPlayerNearGround(playerid, 10.0))
            {
                ac_Data[playerid][ac_WarnFly]++;
                if(ac_Data[playerid][ac_WarnFly] >= MAX_WARNINGS)
                {
                    ac_KickPlayer(playerid, "Fly hack", z);
                    return;
                }
            }
        }
    }
    else ac_Data[playerid][ac_WarnFly] = 0;
    
    if(z < UNDERGROUND_Z && interior == 0)
    {
        ac_KickPlayer(playerid, "Underground hack", z);
        return;
    }
    
    new Float:hp, Float:armor;
    GetPlayerHealth(playerid, hp);
    GetPlayerArmour(playerid, armor);
    
    if(hp > MAX_HP)
    {
        ac_KickPlayer(playerid, "Health hack", hp);
        return;
    }
    
    if(armor > MAX_ARMOR)
    {
        ac_KickPlayer(playerid, "Armor hack", armor);
        return;
    }
    
    if(hp > ac_Data[playerid][ac_LastHP] && ac_Data[playerid][ac_LastHP] < MAX_HP && hp == MAX_HP)
    {
        if(GetTickCount() - ac_Data[playerid][ac_Tick] < 100)
        {
            ac_Data[playerid][ac_WarnGod]++;
            if(ac_Data[playerid][ac_WarnGod] >= GODMODE_THRESHOLD)
            {
                ac_KickPlayer(playerid, "Godmode/Health regen hack");
                return;
            }
        }
    }
    else ac_Data[playerid][ac_WarnGod] = 0;
    
    ac_Data[playerid][ac_LastHP] = hp;
    ac_Data[playerid][ac_LastArmor] = armor;
    
    new weapon, ammo;
    for(new i = 0; i < 13; i++)
    {
        GetPlayerWeaponData(playerid, i, weapon, ammo);
        
        if(weapon > 0)
        {
            if(weapon < 1 || weapon > 46 || weapon == 19 || weapon == 20 || weapon == 21)
            {
                ac_KickPlayer(playerid, "Invalid weapon", float(weapon));
                return;
            }
            
            if(ammo > MAX_AMMO)
            {
                ac_KickPlayer(playerid, "Ammo hack", float(ammo));
                return;
            }
            
            new maxAmmo;
            switch(weapon)
            {
                case 22..24: maxAmmo = 150;
                case 25..27: maxAmmo = 100;
                case 28, 32: maxAmmo = 300;
                case 29, 30: maxAmmo = 150;
                case 31: maxAmmo = 150;
                case 33, 34: maxAmmo = 200;
                case 35, 36: maxAmmo = 150;
                case 38: maxAmmo = 50;
                case 16..18, 39: maxAmmo = 25;
                case 41, 43: maxAmmo = 500;
                case 42, 31: maxAmmo = 150;
                default: maxAmmo = 9999;
            }
            
            if(ammo > maxAmmo)
            {
                ac_KickPlayer(playerid, "Weapon ammo hack", float(ammo));
                return;
            }
        }
    }
    
    new currentWeapon = GetPlayerWeapon(playerid);
    if(currentWeapon != ac_Data[playerid][ac_LastWeapon])
    {
        ac_Data[playerid][ac_LastWeapon] = currentWeapon;
        ac_Data[playerid][ac_ShotCount] = 0;
    }
    
    ac_Data[playerid][ac_PosX] = x;
    ac_Data[playerid][ac_PosY] = y;
    ac_Data[playerid][ac_PosZ] = z;
    ac_Data[playerid][ac_Tick] = tick;
    
    new Float:gx, Float:gy;
    CA_FindZ_For2DCoord(x, y, ac_Data[playerid][ac_GroundZ]);
}

public ac_ResetWarnings(playerid)
{
    if(!IsPlayerConnected(playerid)) return;
    ac_Data[playerid][ac_WarnSpeed] = 0;
    ac_Data[playerid][ac_WarnTP] = 0;
    ac_Data[playerid][ac_WarnFly] = 0;
    ac_Data[playerid][ac_WarnGod] = 0;
    ac_Data[playerid][ac_WarnRapid] = 0;
    ac_Data[playerid][ac_WarnWeapon] = 0;
}

public ac_DelayedKick(playerid)
{
    if(IsPlayerConnected(playerid))
    {
        Kick(playerid);
    }
}

public ac_ResetSpawnProtection(playerid)
{
    if(IsPlayerConnected(playerid))
    {
        ac_Data[playerid][ac_JustSpawned] = false;
    }
}

public OnPlayerWeaponShot(playerid, weaponid, hittype, hitid, Float:fX, Float:fY, Float:fZ)
{
    if(ac_Data[playerid][ac_PendingKick]) return 0;
    
    new tick = GetTickCount();
    new dt = tick - ac_Data[playerid][ac_LastShotTick];
    
    if(dt < RAPID_FIRE_THRESHOLD && dt > 0)
    {
        ac_Data[playerid][ac_ShotCount]++;
        if(ac_Data[playerid][ac_ShotCount] > 5)
        {
            ac_KickPlayer(playerid, "Rapid fire hack", float(dt));
            return 0;
        }
    }
    else ac_Data[playerid][ac_ShotCount] = 0;
    
    ac_Data[playerid][ac_LastShotTick] = tick;
    
    if(hittype == BULLET_HIT_TYPE_PLAYER)
    {
        new Float:ox, Float:oy, Float:oz;
        GetPlayerPos(playerid, ox, oy, oz);
        
        new Float:tx, Float:ty, Float:tz;
        GetPlayerPos(hitid, tx, ty, tz);
        
        new Float:dist = GetPlayerDistanceFromPoint(playerid, tx, ty, tz);
        
        if(weaponid == 34 && dist > 300.0)
        {
            if(!IsPlayerAimingAt(playerid, hitid))
            {
                return 0;
            }
        }
    }
    
    return 1;
}

public OnPlayerTakeDamage(playerid, issuerid, Float:amount, weaponid, bodypart)
{
    if(issuerid != INVALID_PLAYER_ID)
    {
        if(ac_Data[issuerid][ac_PendingKick]) return 0;
        
        if(weaponid == 37 || weaponid == 54) return 0;
        
        new Float:ox, Float:oy, Float:oz;
        GetPlayerPos(issuerid, ox, oy, oz);
        
        new Float:tx, Float:ty, Float:tz;
        GetPlayerPos(playerid, tx, ty, tz);
        
        new Float:dist = GetPlayerDistanceFromPoint(issuerid, tx, ty, tz);
        new Float:maxDist = 50.0;
        
        switch(weaponid)
        {
            case 22..24: maxDist = 35.0;
            case 25..27: maxDist = 40.0;
            case 28, 32: maxDist = 35.0;
            case 29..31: maxDist = 90.0;
            case 33, 34: maxDist = 300.0;
            case 35..38: maxDist = 100.0;
        }
        
        if(dist > maxDist * 1.5)
        {
            return 0;
        }
    }
    return 1;
}

public OnPlayerGiveDamage(playerid, damagedid, Float:amount, weaponid, bodypart)
{
    if(ac_Data[playerid][ac_PendingKick]) return 0;
    
    new Float:maxDamage;
    switch(weaponid)
    {
        case 22: maxDamage = 13.2;
        case 23: maxDamage = 13.2;
        case 24: maxDamage = 46.2;
        case 25: maxDamage = 16.5;
        case 26: maxDamage = 16.5;
        case 27: maxDamage = 16.5;
        case 28: maxDamage = 6.6;
        case 29: maxDamage = 8.25;
        case 30: maxDamage = 9.9;
        case 31: maxDamage = 9.9;
        case 32: maxDamage = 6.6;
        case 33: maxDamage = 24.75;
        case 34: maxDamage = 41.25;
        default: maxDamage = 100.0;
    }
    
    if(amount > maxDamage * 1.5 && weaponid != 37 && weaponid != 54)
    {
        ac_Data[playerid][ac_WarnWeapon]++;
        if(ac_Data[playerid][ac_WarnWeapon] >= 3)
        {
            ac_KickPlayer(playerid, "Damage hack", amount);
            return 0;
        }
    }
    
    return 1;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
    ac_Data[playerid][ac_InVehicle] = true;
    ac_Data[playerid][ac_VehicleID] = vehicleid;
    
    if(!ispassenger)
    {
        if(ac_VehicleDriver[vehicleid] != INVALID_PLAYER_ID && ac_VehicleDriver[vehicleid] != playerid)
        {
            if(IsPlayerConnected(ac_VehicleDriver[vehicleid]) && GetPlayerState(ac_VehicleDriver[vehicleid]) == PLAYER_STATE_DRIVER)
            {
                if(GetPlayerVehicleID(ac_VehicleDriver[vehicleid]) == vehicleid)
                {
                    ClearAnimations(playerid);
                    return 0;
                }
            }
        }
    }
    return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
    ac_Data[playerid][ac_InVehicle] = false;
    ac_Data[playerid][ac_VehicleID] = INVALID_VEHICLE_ID;
    return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
    if(newstate == PLAYER_STATE_DRIVER)
    {
        new vid = GetPlayerVehicleID(playerid);
        ac_VehicleDriver[vid] = playerid;
    }
    if(oldstate == PLAYER_STATE_DRIVER)
    {
        new vid = GetPlayerVehicleID(playerid);
        if(ac_VehicleDriver[vid] == playerid)
        {
            ac_VehicleDriver[vid] = INVALID_PLAYER_ID;
        }
    }
    return 1;
}

public OnPlayerSpawn(playerid)
{
    GetPlayerPos(playerid, ac_Data[playerid][ac_PosX], ac_Data[playerid][ac_PosY], ac_Data[playerid][ac_PosZ]);
    ac_Data[playerid][ac_Tick] = GetTickCount();
    ac_Data[playerid][ac_WarnSpeed] = 0;
    ac_Data[playerid][ac_WarnTP] = 0;
    ac_Data[playerid][ac_WarnFly] = 0;
    ac_Data[playerid][ac_WarnGod] = 0;
    ac_Data[playerid][ac_WarnRapid] = 0;
    ac_Data[playerid][ac_WarnWeapon] = 0;
    ac_Data[playerid][ac_PendingKick] = false;
    ac_Data[playerid][ac_JustSpawned] = true;
    ac_Data[playerid][ac_LastHP] = 100.0;
    ac_Data[playerid][ac_LastArmor] = 0.0;
    ac_Data[playerid][ac_LastWeapon] = 0;
    ac_Data[playerid][ac_ShotCount] = 0;
    ac_Data[playerid][ac_InVehicle] = false;
    ac_Data[playerid][ac_VehicleID] = INVALID_VEHICLE_ID;
    
    SetTimerEx("ac_ResetSpawnProtection", 3000, false, "i", playerid);
    SetTimerEx("ac_CheckPlayer", CHECK_INTERVAL, true, "i", playerid);
    SetTimerEx("ac_ResetWarnings", WARN_RESET_TIME, true, "i", playerid);
    
    return 1;
}

public OnPlayerConnect(playerid)
{
    ac_Data[playerid][ac_PosX] = 0.0;
    ac_Data[playerid][ac_PosY] = 0.0;
    ac_Data[playerid][ac_PosZ] = 0.0;
    ac_Data[playerid][ac_Tick] = 0;
    ac_Data[playerid][ac_WarnSpeed] = 0;
    ac_Data[playerid][ac_WarnTP] = 0;
    ac_Data[playerid][ac_WarnFly] = 0;
    ac_Data[playerid][ac_WarnGod] = 0;
    ac_Data[playerid][ac_WarnRapid] = 0;
    ac_Data[playerid][ac_WarnWeapon] = 0;
    ac_Data[playerid][ac_LastShotTick] = 0;
    ac_Data[playerid][ac_LastWeapon] = 0;
    ac_Data[playerid][ac_ShotCount] = 0;
    ac_Data[playerid][ac_LastHP] = 100.0;
    ac_Data[playerid][ac_LastArmor] = 0.0;
    ac_Data[playerid][ac_GroundZ] = 0.0;
    ac_Data[playerid][ac_PendingKick] = false;
    ac_Data[playerid][ac_JustSpawned] = false;
    ac_Data[playerid][ac_InVehicle] = false;
    ac_Data[playerid][ac_VehicleID] = INVALID_VEHICLE_ID;
    
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if(ac_Data[playerid][ac_InVehicle])
    {
        new vid = ac_Data[playerid][ac_VehicleID];
        if(vid != INVALID_VEHICLE_ID && ac_VehicleDriver[vid] == playerid)
        {
            ac_VehicleDriver[vid] = INVALID_PLAYER_ID;
        }
    }
    ac_Data[playerid][ac_PendingKick] = false;
    return 1;
}

public OnGameModeInit()
{
    for(new i = 0; i < MAX_VEHICLES; i++)
    {
        ac_VehicleDriver[i] = INVALID_PLAYER_ID;
        ac_VehicleSpeed[i] = 0.0;
    }
    return 1;
}

public OnGameModeExit()
{
    return 1;
}
