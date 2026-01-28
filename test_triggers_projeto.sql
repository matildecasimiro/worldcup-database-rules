use MUNDIAL
go

/* NOTES:
- For simplification, assume that in the same insert statement (batch) for table Events, there will never be more than one record
 involving the same player.
 - Assume that when a referee is updated, the countries participating in the match are never being updated at the same time */

-- trigger 1 (slay)
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

	if @@ROWCOUNT < (Select count(*) From inserted) -- to display a message in case some record is not inserted
			print('There were records not inserted because player summoned does not belong to countries playing.');

End;
go


insert into MATCH(IDAWAYTEAM, IDTOURNAMENTPHASE, IDSTADIUM, IDHOMETEAM, IDREFEREE, STARTDATETIME, ADDEDTIME1STHALF, ADDEDTIME2NDHALF, 
					EXTRATIMEADDEDTIME1STHALF, EXTRATIMEADDEDTIME2NDHALF, EXTRATIME, PENALTIES)
values (2,	2,	3,	3,	3,	'2027-01-30 00:00:00.000',	2,	2,	NULL,	NULL,	NULL,	NULL)

insert into SUMMONEDS(IDEVENTPLAYEROUT, IDPLAYER, IDMATCH, STARTING11) 
values (NULL ,16 , 7, 1 ), (NULL ,1 , 7, 1 )

insert into SUMMONEDS(IDEVENTPLAYEROUT, IDPLAYER, IDMATCH, STARTING11) 
values (NULL ,1 , 7, 1 )

select * from SUMMONEDS
go



-- trigger 2 (slay)
create or alter trigger referees_not_own_country_insert
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

	if @@ROWCOUNT < (Select count(*) From inserted) -- to display a message in case some record is not inserted
		print('There were records not inserted because a referee cannot referee a match where her/his own country is participating.');

End;
go


insert into MATCH(IDAWAYTEAM, IDTOURNAMENTPHASE, IDSTADIUM, IDHOMETEAM, IDREFEREE, STARTDATETIME, ADDEDTIME1STHALF, ADDEDTIME2NDHALF, 
					EXTRATIMEADDEDTIME1STHALF, EXTRATIMEADDEDTIME2NDHALF, EXTRATIME, PENALTIES)
values (2,	1,	3,	5,	3,	'2027-01-10 00:00:00.000',	2,	2,	NULL,	NULL,	NULL,	NULL),
		(2,	1,	3,	5,	2,	'2027-01-10 00:00:00.000',	2,	2,	NULL,	NULL,	NULL,	NULL)



insert into MATCH(IDAWAYTEAM, IDTOURNAMENTPHASE, IDSTADIUM, IDHOMETEAM, IDREFEREE, STARTDATETIME, ADDEDTIME1STHALF, ADDEDTIME2NDHALF, 
					EXTRATIMEADDEDTIME1STHALF, EXTRATIMEADDEDTIME2NDHALF, EXTRATIME, PENALTIES)
values (2,	1,	3,	5,	2,	'2027-01-10 00:00:00.000',	2,	2,	NULL,	NULL,	NULL,	NULL)

select * from MATCH
select * from REFEREE
go




create or alter trigger referees_not_own_country_update
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

	if @@ROWCOUNT < (Select count(*) From inserted) -- to display a message in case some record is not inserted
		print('There were records not updated because a referee cannot referee a match where her/his own country is participating.');


End;
go


UPDATE MATCH set IDREFEREE= 4
where IDMATCH = 9


UPDATE MATCH set IDREFEREE= 2
where IDMATCH = 9

select * from MATCH
go

CREATE OR ALTER FUNCTION red_card_check(@IDSummoned numeric, @Minute numeric) 
RETURNS bit
AS
BEGIN
	-- set default result as 0
	Declare @red_card bit; Set @red_card = 0

	-- situation 1 -> player was in starting11 but received a red card before minute
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


-- trigger 3 (slay)
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




insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values (4,	NULL,17,'First half', 'Card',	0,	0, 'yellow')

insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values  (30,	NULL,29,'Second half', 'Card',	0,	0, 'yellow')

insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values (30,	NULL,40,'First half', 'Card',	0,	0, 'Yellow') , (4,	NULL,39,'Second half', 'Card',	0,	0, 'yellow')

select * from EVENTS
go






CREATE OR ALTER FUNCTION red_card_check(@IDSummoned numeric, @Minute numeric) 
RETURNS bit
AS
BEGIN
	-- set default result as 0
	Declare @red_card bit; Set @red_card = 0

	-- -- if player but received a red card before minute set result to 1
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

select dbo.player_on_field(2,15) -- should return 1
select dbo.player_on_field(3,78) -- should return 0
select dbo.player_on_field(2,60) -- should return 1
select dbo.player_on_field(2,70) -- should return 0
select dbo.player_on_field(6,71) -- should return 1
select dbo.player_on_field(6,50) -- should return 0



select * from EVENTS

select * from SUMMONEDS s where s.STARTING11 = 0
go





select * from SUMMONEDS

select dbo.red_card_check(3,80) -- should return 1
select dbo.red_card_check(3,50) -- should return 0
select dbo.red_card_check(7,15) -- should return 0
go 


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
					SUMMONEDS s join PLAYER p on 
					s.IDPLAYER = p.IDPERSON
					where s.IDSUMMONED = @IDSummoned_one) f
					join 
					(select p.IDCOUNTRY from 
					SUMMONEDS s join PLAYER p on 
					s.IDPLAYER = p.IDPERSON
					where s.IDSUMMONED = @IDSummoned_two) s
					on f.IDCOUNTRY = s.IDCOUNTRY
		)
		Set @same_country = 1

	Return @same_country;
END;
GO

select IDSUMMONED, IDCOUNTRY from SUMMONEDS s join PLAYER p on s.IDPLAYER = p.IDPERSON

select dbo.same_country_check(1,23) -- should return 1
select dbo.same_country_check(55,12) -- should return 0
go 



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

select * from SUMMONEDS

select dbo.same_match_check(98,99) -- should return 1
select dbo.same_match_check(66,68) -- should return 0
go 


create or alter trigger goals_replacements_rules
on EVENTS
instead of insert
as
Begin 
	-- insert records of events that are not replacements 
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


-- player on bench all game (starting11 = 0) -> not on field
insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values (30,	NULL,40,'First half', 'Goal',	0,	0, NULL)

-- player on field all game (starting11 = 1 and not replaced) -> on field
insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values (5,	NULL,67,'Second Half', 'Goal',	0,	0, NULL)

-- player starting11=1 but was replaced after the goal ->  on field
insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values (2,	NULL,61,'Second Half', 'Goal',	0,	0, NULL)

-- player starting11=1 but was replaced  the before goal -> not on field
insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values (2,	NULL,75,'Second Half', 'Goal',	0,	0, NULL)

-- player starting11=0 but replaced another before the goal ->  on field
insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values (6,	NULL,75,'Second Half', 'Goal',	0,	0, NULL)

-- player starting11=0 but replaced another after the goal -> not on field
insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values (6,	NULL,60,'Second Half', 'Goal',	0,	0, NULL)

select * from EVENTS

select * from SUMMONEDS where IDSUMMONED=30

-- player on bench all game (starting11 = 0) -> not on field
insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values (30,	NULL,40,'First half', 'Goal',	0,	0, NULL), (5,	NULL,67,'Second Half', 'Goal',	0,	0, NULL),
	   (2,	NULL,61,'Second Half', 'Goal',	0,	0, NULL), (2,	NULL,75,'Second Half', 'Goal',	0,	0, NULL),
	   (6,	NULL,75,'Second Half', 'Goal',	0,	0, NULL), (6,	NULL,60,'Second Half', 'Goal',	0,	0, NULL),
	   (10,	9,40,'First half', 'Replacement',	0,	0, NULL), (3,4	,80,'Second Half', 'replacement',	0,	0, NULL),
	   (8,	5,61,'Second Half', 'Replacement',	0,	0, NULL)
go 


-- two players on field -> reject 
insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values (10,	9,40,'First half', 'Replacement',	0,	0, NULL)

-- playerout on field, playerin red card  -> reject 
insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values (3,4	,80,'Second Half', 'replacement',	0,	0, NULL)

-- acept 
insert into EVENTS(IDSUMMONEDMAINPLAYER, IDSUMMONEDPLAYEROUT, MINUTE, MATCHPART, EVENTTYPE, ISPENALTY, ISOWNGOAL, CARDTYPE) 
values (8,	5,61,'Second Half', 'Replacement',	0,	0, NULL)

select * from SUMMONEDS
select * from EVENTS
select * from PLAYER