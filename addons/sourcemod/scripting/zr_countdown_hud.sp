/*
 * =============================================================================
 * File:		  
 * Type:		  Base
 * Description:   Plugin's base file.
 *
 * Copyright (C)   Anubis Edition. All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <zombiereloaded>

#pragma newdecls required

#define VERSION "1.1"

ConVar ChPath = null;
ConVar ChEnabe = null;

char c_sChPath[PLATFORM_MAX_PATH];
bool c_bChEnabe;
bool g_bChEnabe[MAXPLAYERS+1] = {false, ...};

Handle g_taskClean[MAXPLAYERS+1] = INVALID_HANDLE;
Handle g_bChClientEnabe = INVALID_HANDLE;

public Plugin myinfo =
{
	name = "Countdown_Hud",
	author = "Anubis",
	description = "Countdown Overlay Infect. Only Zombie:Reloaded Anubis Edition",
	version = VERSION,
	url = "stewartbh@live.com"
};

public void OnPluginStart()
{
	ChPath = CreateConVar("zr_countdownhud_path", "contdown_hud", "CountdownHud image file folder.");
	ChEnabe = CreateConVar("zr_countdownhud_enable", "1", "Enable or disable CountdownHud.");
	g_bChClientEnabe = RegClientCookie("Zr_Countdown_Hud_Enable", "Zr Countdown Hud Enable.", CookieAccess_Protected);

	RegConsoleCmd("sm_zchud", Command_CountdowHud, "Enable or disable CountdownHud.");

	ChPath.AddChangeHook(ConVarChange);
	ChEnabe.AddChangeHook(ConVarChange);

	GetConVarString(ChPath, c_sChPath, sizeof(c_sChPath));
	c_bChEnabe = ChEnabe.BoolValue;

	if (FileExists("cfg/sourcemod/Zr_CountdownHud.cfg"))
	{
		// Auto-exec config file .
		ServerCommand("exec sourcemod/Zr_CountdownHud.cfg");
	}
	else
	{
		// Auto-generate config file if it doesn't exist, then execute.
		AutoExecConfig(true, "Zr_CountdownHud", "sourcemod/");
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
		continue;
		OnClientCookiesCached(i);
	}
}

public void OnMapStart()
{
	if (FileExists("cfg/sourcemod/Zr_CountdownHud.cfg"))
	{
		// Auto-exec config file .
		ServerCommand("exec sourcemod/Zr_CountdownHud.cfg");
	}

	AddFolderToDownloadsTable();
}

public void ConVarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	GetConVarString(ChPath, c_sChPath, sizeof(c_sChPath));
	c_bChEnabe = ChEnabe.BoolValue;
}

stock void AddFolderToDownloadsTable()
{
	char sFile[64], sPath[PLATFORM_MAX_PATH], sCache[PLATFORM_MAX_PATH];
	Format(sPath, sizeof(sPath), "materials/%s", c_sChPath);
	FileType iType;
	Handle hDir = OpenDirectory(sPath);
	if (hDir != INVALID_HANDLE)
	{
		while(ReadDirEntry(hDir, sFile, sizeof(sFile), iType))     
		{
			if(iType == FileType_File)
			{
				Format(sCache, sizeof(sCache), "/%s/%s", sPath, sFile);
				AddFileToDownloadsTable(sCache);
			}
		}
	}
	else if (hDir == INVALID_HANDLE)
	{
		LogError("Folder [%s/] Not Found.", c_sChPath);
	}
}

public void OnClientCookiesCached(int client)
{
	char c_Eneble[8];
	GetClientCookie(client, g_bChClientEnabe, c_Eneble, sizeof(c_Eneble));
	g_bChEnabe[client] = (c_Eneble[0] != '\0' && StringToInt(c_Eneble));
}

public void OnClientDisconnect_Post(int client)
{
	if(g_taskClean[client] !=INVALID_HANDLE)
	{
		KillTimer(g_taskClean[client]);
		g_taskClean[client] =INVALID_HANDLE;
	}
}

public Action Command_CountdowHud(int client, int arg)
{
	if(c_bChEnabe)
	{
		char sValue[8];
		g_bChEnabe[client] = !g_bChEnabe[client];
		PrintToChat(client, " \x04[ZR_Count_HUD]\x10 CountDown_Hud\x01 has been %s.", g_bChEnabe[client] ? "\x07disabled" : "\x0benabled");
		Format(sValue, sizeof(sValue), "%i", g_bChEnabe[client]);
		SetClientCookie(client, g_bChClientEnabe, sValue);
	}
	else
	{
		PrintToChat(client, " \x04[Zr_Count_HUD]\x10 The CountdownHud Plugin is currently disabled!");
	}
	return Plugin_Handled;
}

public int ZR_OnContdownWarningTick(int tick)
{
	if(tick <= 10 && tick >= 0 && c_bChEnabe)
	{
		char Count[64];
		Format(Count, sizeof(Count), "Count_%d", tick);
		ShowCountMessages(Count);
	}
}

public void ShowCountMessages(char[] type)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && !g_bChEnabe[i])
		{
			ClientCommand(i, "r_screenoverlay \"%s/%s\"", c_sChPath, type);
			
			if(g_taskClean[i] == INVALID_HANDLE)
			{
				g_taskClean[i] = CreateTimer(11.0,task_Clean,i);
			}
		}
		if (IsClientInGame(i) && !IsFakeClient(i) && g_bChEnabe[i] && g_taskClean[i] != INVALID_HANDLE)
		{
			g_taskClean[i] = CreateTimer(0.1,task_Clean,i);
		}
	}
}

public Action task_Clean(Handle Timer, any client)
{
	KillTimer(Timer);
	g_taskClean[client] = INVALID_HANDLE;

	ClientCommand(client, "r_screenoverlay \"\"");
}