
use PROJETO 
go


/* FUNTIONS */
-- We created a few auxiliary functions in order to simplify the syntax of some of the following triggers

-- Function that checks if a given summoned player received a red card before a given minute
-- returns 1 if received a red card and 0 if hasn't
CREATE OR ALTER FUNCTION red_card_check(@IDSummoned numeric, @Minute numeric) 
RETURNS bit
AS
BEGIN
	-- set default result as 0
	Declare @red_card bit; Set @red_card = 0

	-- if player received a red card before minute set result to 1
	if exists( 
		select IDSUMMONED, MINUTE
		from  EVENTS e join SUMMONEDS s
		on e.IDSUMMONEDMAINPLAYER = s.IDSUMMONED
		where  (e.CARDTYPE = 'Red' or e.CARDTYPE = 'red') and IDSUMMONED = @IDSummoned and MINUTE < @Minute
		)
		Set @red_card = 1

	Return @red_card;
END;
GO


-- Function that checks if a given summoned player was on the field at a given minute 
-- returns 1 if player was on field and 0 if wasn't
CREATE OR ALTER FUNCTION player_on_field (@IDSummoned numeric, @Minute numeric) 
RETURNS bit
AS
BEGIN
	-- set default result as 1
	Declare @player_on_field bit; Set @player_on_field = 1

	-- situation 1 -> player was in starting11 but received a red card before minute
	if exists( 
		select *
		from SUMMONEDS s where s.STARTING11 = 1 and s.IDEVENTPLAYEROUT is NULL and 
							   dbo.red_card_check(s.IDSUMMONED, @Minute) = 1
							   and s.IDSUMMONED = @IDSummoned 
			 )
		Set @player_on_field = 0

	-- situation 2 -> player was in starting11 but was replaced before minute
	if exists( 
		select IDSUMMONED, MINUTE
		from  
			( select * from SUMMONEDS s where s.STARTING11 = 1 and s.IDEVENTPLAYEROUT is not NULL) summoneds_starting
			join 
			( select * from EVENTS e where  e.EVENTTYPE= 'Replacement') replaced
			on summoneds_starting.IDEVENTPLAYEROUT = replaced.IDEVENT
			where IDSUMMONED = @IDSummoned and MINUTE < @Minute
		  )
		Set @player_on_field = 0

	-- situation 3 -> player was not starting11 and didn't enter the game before minute
	if exists( 
		select IDSUMMONED, MINUTE
		from  
			( select * from SUMMONEDS s where s.STARTING11 = 0 ) summoneds_starting
			left join 
			( select * from EVENTS e where  e.EVENTTYPE= 'Replacement') replaced
			on summoneds_starting.IDSUMMONED = replaced.IDSUMMONEDMAINPLAYER
			where IDSUMMONED = @IDSummoned and (MINUTE > @Minute or MINUTE is NULL)
		  )
		Set @player_on_field = 0

	Return @player_on_field;
END;
GO


-- Function that checks if two given summoned players belong to the same country
-- returns 1 if they belong to the same country and 0 if they don't
CREATE OR ALTER FUNCTION same_country_check(@IDSummoned_one numeric, @IDSummoned_two numeric) 
RETURNS bit
AS
BEGIN
	-- set default result as 0
	Declare @same_country bit; Set @same_country= 0

	-- set result to 1 if summoned players have the same country code 
	if exists( 
		select * from 
					(select p.IDCOUNTRY from 
					SUMMONEDS s join PLAYER p on s.IDPLAYER = p.IDPERSON
					where s.IDSUMMONED = @IDSummoned_one) f
					join 
					(select p.IDCOUNTRY from 
					SUMMONEDS s join PLAYER p on s.IDPLAYER = p.IDPERSON
					where s.IDSUMMONED = @IDSummoned_two) s
					on f.IDCOUNTRY = s.IDCOUNTRY
		)
		Set @same_country = 1

	Return @same_country;
END;
GO


-- Function that checks if two given summoned players where summoned to the same match
-- returns 1 if they belong to the same match and 0 if they don't
CREATE OR ALTER FUNCTION same_match_check(@IDSummoned_one numeric, @IDSummoned_two numeric) 
RETURNS bit
AS
BEGIN
	-- set default result as 0
	Declare @same_match bit; Set @same_match= 0

	-- set result to 1 if summoned players have the same country code 
	if exists( 
		select * from 
					(select s.IDMATCH from SUMMONEDS s 
					where s.IDSUMMONED = @IDSummoned_one) f
					join 
					(select s.IDMATCH from SUMMONEDS s 
					where s.IDSUMMONED = @IDSummoned_two) s
					on f.IDMATCH = s.IDMATCH
		)
		Set @same_match = 1

	Return @same_match;
END;
GO


/* TRIGGERS */ 

/* 1. It is not possible to summon a player that does not belong to any of the countries participating in the match.(INSERT) */
--  PLAYER.IDCountry should be equal to either MATCH.IDAwayTeam or MATCH.IDHomeTeam
--  path: SUMMONEDS.IDPlayer = PLAYER.IDPerson , SUMMONEDS.IDMatch = MATCH.IDMatch 

create or alter trigger player_in_matches_countries
on SUMMONEDS 
instead of insert
as
Begin 
	insert into SUMMONEDS ( IDEVENTPLAYEROUT, IDPLAYER, IDMATCH, STARTING11) 
	select i.IDEVENTPLAYEROUT, i.IDPLAYER, i.IDMATCH, i.STARTING11
	from inserted i join PLAYER p on  i.IDPLAYER = p.IDPERSON 
		 join MATCH m on i.IDMATCH = m.IDMATCH
	where p.IDCOUNTRY = m.IDAWAYTEAM or p.IDCOUNTRY = m.IDHOMETEAM

	-- to display a message in case some record is not inserted
	if @@ROWCOUNT < (Select count(*) From inserted) 
			print('There were records not inserted because player summoned does not belong to countries playing.');

End;
go


/* 2. A referee cannot referee a match where her/his own country is participating. (INSERT/UPDATE) */
-- REFEREE.IDCountry should be different to both MATCH.IDAwayTeam and MATCH.IDHomeTeam
-- path: REFEREE.IDPerson = MATCH.IDReferee

-- INSERT 

create or alter trigger referees_not_own_country_i
on MATCH 
instead of insert
as 
Begin 
	insert into MATCH( IDAWAYTEAM, IDTOURNAMENTPHASE, IDSTADIUM, IDHOMETEAM, IDREFEREE, STARTDATETIME, ADDEDTIME1STHALF, ADDEDTIME2NDHALF, 
	EXTRATIMEADDEDTIME1STHALF, EXTRATIMEADDEDTIME2NDHALF, EXTRATIME, PENALTIES)
	select i.IDAWAYTEAM, i.IDTOURNAMENTPHASE, i.IDSTADIUM, i.IDHOMETEAM, i.IDREFEREE, i.STARTDATETIME, i.ADDEDTIME1STHALF, i.ADDEDTIME2NDHALF, 
	i.EXTRATIMEADDEDTIME1STHALF, i.EXTRATIMEADDEDTIME2NDHALF, i.EXTRATIME, i.PENALTIES
	from inserted i join REFEREE r on i.IDREFEREE = r.IDPERSON 
	where r.IDCOUNTRY != i.IDHOMETEAM and r.IDCOUNTRY != i.IDAWAYTEAM 

	-- to display a message in case some record is not inserted
	if @@ROWCOUNT < (Select count(*) From inserted) 
		print('There were records not inserted because a referee cannot referee a match where her/his own country is participating.');

End;
go


-- UPDATE

create or alter trigger referees_not_own_country_u
on MATCH
instead of update
as
Begin
	update MATCH set IDAWAYTEAM = i.IDAWAYTEAM,
					 IDTOURNAMENTPHASE = i.IDTOURNAMENTPHASE,
					 IDSTADIUM = i.IDSTADIUM,
					 IDHOMETEAM= i.IDHOMETEAM,
					 IDREFEREE = i.IDREFEREE, 
					 STARTDATETIME = i.STARTDATETIME,
					 ADDEDTIME1STHALF = i.ADDEDTIME1STHALF,
					 ADDEDTIME2NDHALF = i.ADDEDTIME2NDHALF,
					 EXTRATIMEADDEDTIME1STHALF = i.EXTRATIMEADDEDTIME1STHALF,
					 EXTRATIMEADDEDTIME2NDHALF = i.EXTRATIMEADDEDTIME2NDHALF,
					 EXTRATIME = i.EXTRATIME,
					 PENALTIES = i.PENALTIES
	from inserted i join deleted d on i.IDMATCH = d.IDMATCH
	join REFEREE r on i.IDREFEREE = r.IDPERSON 
	where  r.IDCOUNTRY != i.IDHOMETEAM and r.IDCOUNTRY != i.IDAWAYTEAM ;

	-- to display a message in case some record is not updated
	if @@ROWCOUNT < (Select count(*) From inserted) 
		print('There were records not updated because a referee cannot referee a match where her/his own country is participating.');

End;
go


/* 3. When a yellow card event is inserted, it must be verified if the player already received a yellow card in the same match. 
If that is the case, then a new red card event must be inserted with the same data. (INSERT) */
-- path: EVENTS.IDSummonedMainPlayer = SUMMONEDS.IDSummoned
-- Considering both the red and yellow card are inserted in the data 

create or alter trigger two_yellows_equal_red
on EVENTS 
after insert 
as
begin
	insert into EVENTS
	select i.IDSUMMONEDMAINPLAYER, i.IDSUMMONEDPLAYEROUT, i.MINUTE, i.MATCHPART, i.EVENTTYPE, i.ISPENALTY, i.ISOWNGOAL, 'Red'
	from 
		(select * from inserted i where i.CARDTYPE = 'Yellow' or i.CARDTYPE = 'yellow') i
		 join 
		(select e.IDSUMMONEDMAINPLAYER, s.IDMATCH, count(e.IDEVENT) as nr_of_yellow_cards
		from EVENTS e join SUMMONEDS s on e.IDSummonedMainPlayer = s.IDSummoned
		where e.CARDTYPE = 'yellow' or e.CARDTYPE = 'Yellow'
		group by e.IDSUMMONEDMAINPLAYER, s.IDMATCH ) y 
		on i.IDSUMMONEDMAINPLAYER = y.IDSUMMONEDMAINPLAYER
		where y.nr_of_yellow_cards >= 2	 

End; 
go 


/* 4. When a “Goal” event is inserted, it must be verified if the player that scored the goal
was on the field. For a player to be on the field, either:
• She was part of the starting 11 and did not leave (was not replaced and did not receive a red card);
• She was not part of the starting 11 but replaced another player and did not leave afterwards (was not
replaced and did not receive a red card).
If the scorer was not on the field, then the record must not be inserted, and a message must be displayed. 
(INSERT) */

/* 5. When a “Replacement” event is inserted, it must be verified:
• If the “player out” was on the field;
• If the “player in” was not on the field already and was on the bench, available 
to replace another player (to be available to replace a player means that the 
person is summoned, is not in the starting 11, did not go in yet and did not 
receive a red card);
• If the “player in” and the “player out” belong to the same team;
• If the 2 players are in the same match.
If any of these points is not verified, then the record must not be inserted, and a message must be displayed. 
(INSERT) */

-- Since rules 4 and 5 both related to conditions associaced with the insertion of data in the table EVENTS, 
-- they can be executed simultaneosly in a single trigger.

create or alter trigger goals_replacements_rules
on EVENTS
instead of insert
as
Begin 
	-- insert records of events that are not replacements or goals
	insert into EVENTS( IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE)
	select i.IDSUMMONEDMAINPLAYER, i.IDSUMMONEDPLAYEROUT, i.MINUTE, i.MATCHPART, i.EVENTTYPE, i.ISPENALTY, i.ISOWNGOAL, i.CARDTYPE
	from inserted i 
	where i.EVENTTYPE != 'Replacement' and i.EVENTTYPE != 'Goal'

	declare @num_rec_ok int; set @num_rec_ok = @@ROWCOUNT;

	-- insert goal records of players that were of the field at the time of the goal
	insert into EVENTS( IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE)
	select i.IDSUMMONEDMAINPLAYER, i.IDSUMMONEDPLAYEROUT, i.MINUTE, i.MATCHPART, i.EVENTTYPE, i.ISPENALTY, i.ISOWNGOAL, i.CARDTYPE
	from inserted i 
	where i.EVENTTYPE = 'Goal' and dbo.player_on_field(i.IDSUMMONEDMAINPLAYER,i.MINUTE) = 1

	set @num_rec_ok =  @num_rec_ok + @@ROWCOUNT;

	-- insert replacement records that align with rules 
	insert into EVENTS( IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE)
	select IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE
	from inserted i 
	where i.EVENTTYPE = 'Replacement' and 
		  dbo.player_on_field(i.IDSUMMONEDPLAYEROUT, i.MINUTE) = 1 and 
		  dbo.player_on_field(i.IDSUMMONEDMAINPLAYER, i.MINUTE) = 0 and 
		  dbo.red_card_check(i.IDSUMMONEDMAINPLAYER, i.MINUTE) = 0 and 
		  dbo.same_country_check(i.IDSUMMONEDMAINPLAYER, i.IDSUMMONEDPLAYEROUT) = 1 and 
		  dbo.same_match_check(i.IDSUMMONEDMAINPLAYER, i.IDSUMMONEDPLAYEROUT) = 1

	set @num_rec_ok =  @num_rec_ok + @@ROWCOUNT;
	declare @num_rec int; select @num_rec = count(*) from inserted;

	-- to display a message in case some record is not inserted
	if @num_rec_ok < @num_rec
		print('There were ' +  convert(varchar, @num_rec - @num_rec_ok) + ' records not inserted because data did not align with events rules.');

End;
go

