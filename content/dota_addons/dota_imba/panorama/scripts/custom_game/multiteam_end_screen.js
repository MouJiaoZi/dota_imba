"use strict";

(function()
{
	if ( ScoreboardUpdater_InitializeScoreboard === null ) { $.Msg( "WARNING: This file requires shared_scoreboard_updater.js to be included." ); }

	var scoreboardConfig =
	{
		"teamXmlName" : "file://{resources}/layout/custom_game/multiteam_end_screen_team.xml",
		"playerXmlName" : "file://{resources}/layout/custom_game/multiteam_end_screen_player.xml",
	};

	var endScoreboardHandle = ScoreboardUpdater_InitializeScoreboard( scoreboardConfig, $( "#TeamsContainer" ) );
	$.GetContextPanel().SetHasClass( "endgame", 1 );
	
	var teamInfoList = ScoreboardUpdater_GetSortedTeamInfoList( endScoreboardHandle );
	var delay = 0.2;
	var delay_per_panel = 1 / teamInfoList.length;
	for ( var teamInfo of teamInfoList )
	{
		var teamPanel = ScoreboardUpdater_GetTeamPanel( endScoreboardHandle, teamInfo.team_id );
		teamPanel.SetHasClass( "team_endgame", false );
		var callback = function( panel )
		{
			return function(){ panel.SetHasClass( "team_endgame", 1 ); }
		}( teamPanel );
		$.Schedule( delay, callback )
		delay += delay_per_panel;
	}

	var winningTeamId = Game.GetGameWinner();
	var winningTeamDetails = Game.GetTeamDetails( winningTeamId );
	var endScreenVictory = $( "#EndScreenVictory" );
	if ( endScreenVictory )
	{
		endScreenVictory.SetDialogVariable( "winning_team_name", $.Localize( winningTeamDetails.team_name ) );

		if ( GameUI.CustomUIConfig().team_colors )
		{
			var teamColor = GameUI.CustomUIConfig().team_colors[ winningTeamId ];
			teamColor = teamColor.replace( ";", "" );
			endScreenVictory.style.color = teamColor + ";";
		}

		var ImbaXPLabel = $( "#ImbaXPCount" ).FindChildTraverse("ImbaXPAdvertize");
		var GameCount = CustomNetTables.GetTableValue("game_options", "game_count").value;
//		$.Msg(GameCount)
		if ( GameCount == 1 )
		{
			ImbaXPLabel.text = "Imba XP: This game was recorded."
			ImbaXPLabel.style.color = "green"
		}
		else
		{
			ImbaXPLabel.text = "Imba XP: This game was not recorded."
			ImbaXPLabel.style.color = "red"
		}
	}

//	var winningTeamLogo = $( "#WinningTeamLogo" );
//	if ( winningTeamLogo )
//	{
//		var logo_xml = GameUI.CustomUIConfig().team_logo_large_xml;
//		if ( logo_xml )
//		{
//			winningTeamLogo.SetAttributeInt( "team_id", winningTeamId );
//			winningTeamLogo.BLoadLayout( logo_xml, false, false );
//		}
//	}

	//COOKIES: Disable HUD
	var parent_panel = $.GetContextPanel().GetParent().GetParent().GetParent().GetParent()
	parent_panel.FindChildTraverse("topbar").style.visibility = "collapse";
	parent_panel.FindChildTraverse("lower_hud").style.visibility = "collapse";
	parent_panel.FindChildTraverse("topbar").style.visibility = "collapse";
	parent_panel.FindChildTraverse("minimap_container").style.visibility = "collapse";
})();
