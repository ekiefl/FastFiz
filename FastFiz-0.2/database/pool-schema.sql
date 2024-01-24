--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: pool; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON DATABASE pool IS 'Computational pool tournament server database';


SET search_path = public, pg_catalog;

--
-- Name: pending_match_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE pending_match_info AS (
	matchid integer,
	agentid integer,
	priority integer
);


--
-- Name: pending_shot_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE pending_shot_info AS (
	agentid integer,
	gameid integer,
	stateid integer,
	priority integer
);


--
-- Name: add_game_to_match(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION add_game_to_match(matchid integer, agentid integer, start_state integer) RETURNS bigint
    AS $_$INSERT INTO games (matchid,gametype,agentid1,agentid2,noiseid1,noiseid2,start_state) 
SELECT matchid,gametype,$2 as agentid1,agentid1+agentid2-$2 as agentid2, case when agentid1=$2 then noiseid1 else noiseid2 end as noiseid1, case when agentid1=$2 then noiseid2 else noiseid1 end as noiseid2, $3 as start_state FROM matches where matchid=$1;

INSERT INTO pendingshots (stateid,gameid,agentid) VALUES ($3,lastval(),$2);

UPDATE matches SET gamesleft1=gamesleft1-1 WHERE agentid1=$2 AND matchid=$1;
UPDATE matches SET gamesleft2=gamesleft2-1 WHERE agentid2=$2 AND matchid=$1;

SELECT lastval();$_$
    LANGUAGE sql;


--
-- Name: FUNCTION add_game_to_match(matchid integer, agentid integer, start_state integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION add_game_to_match(matchid integer, agentid integer, start_state integer) IS 'Adds a new game to a match and creates a pending shot for that game. Caller must already create a racked state in the database.
Returns the new gameid.';


--
-- Name: add_game_to_match_special(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION add_game_to_match_special(matchid integer, start_state integer) RETURNS bigint
    AS $_$
INSERT INTO noise(noisetype, n_a, n_b,  n_theta, n_phi, n_v, n_factor) VALUES
                 (2,0.5,0.5,0.1,0.125,0.075,random()*3+1.5);
INSERT INTO games (matchid,gametype,agentid1,noiseid1,start_state) SELECT matchid,gametype,agentid1,lastval(),$2 as start_state FROM matches where matchid=$1;

INSERT INTO pendingshots (stateid,gameid,agentid) VALUES ($2,lastval(),(SELECT agentid1 FROM matches WHERE matchid=$1));

UPDATE matches SET gamesleft1=gamesleft1-1 WHERE matchid=$1;

SELECT lastval();$_$
    LANGUAGE sql;


--
-- Name: FUNCTION add_game_to_match_special(matchid integer, start_state integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION add_game_to_match_special(matchid integer, start_state integer) IS 'This function is only used for special noise/time experiments.';


--
-- Name: add_to_cache(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION add_to_cache(gameid integer, stateid integer) RETURNS void
    AS $_$INSERT INTO state_cache(agentid,noiseid,timelimit,stateid) select g.agentid1,m.noiseid1 as noiseid,timelimit1 as timelimit, $2 as stateid from games g join matches m on g.matchid=m.matchid where gameid=$1;$_$
    LANGUAGE sql;


--
-- Name: clean_orphaned_states(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION clean_orphaned_states() RETURNS void
    AS $$delete from states where not exists (select 1 from shots s where
(stateid=prev_state or stateid=next_state)) and not exists (select 1 from
games g where stateid=start_state);$$
    LANGUAGE sql;


--
-- Name: FUNCTION clean_orphaned_states(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION clean_orphaned_states() IS 'Remove all states in the database that are not referenced by a game or a shot.';


--
-- Name: cleanup(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION cleanup() RETURNS void
    AS $$select cleanup_pendingshots();

-- Delete shotless games
delete from games g where not exists (select NULL from shots s where
s.gameid=g.gameid) and not exists (select NULL from pendingshots ps where ps.gameid=g.gameid);

-- Delete orphaned states
SELECT clean_orphaned_states();

-- Delete empty matches
delete from matches m WHERE gamesleft1=0 and gamesleft2=0 and NOT EXISTS (SELECT NULL FROM games g WHERE
g.matchid=m.matchid); 

SELECT cleanup_logfiles();$$
    LANGUAGE sql;


--
-- Name: FUNCTION cleanup(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION cleanup() IS 'Perform maintenence tasks, removing empty matches and games.';


--
-- Name: cleanup_logfiles(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION cleanup_logfiles() RETURNS void
    AS $$DELETE FROM logfiles WHERE expiration<now();$$
    LANGUAGE sql;


--
-- Name: FUNCTION cleanup_logfiles(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION cleanup_logfiles() IS 'Remove old uploaded log files.';


--
-- Name: cleanup_pendingshots(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION cleanup_pendingshots() RETURNS void
    AS $$update games g set start_player_won = not cur_player_started, end_reason=4 from pendingshots ps natural join states s where now()-timesent-timeleft > '1 hour' and g.gameid=ps.gameid;
delete from pendingshots ps where exists (select end_reason from games g where g.gameid=ps.gameid and end_reason is not null);$$
    LANGUAGE sql;


--
-- Name: FUNCTION cleanup_pendingshots(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION cleanup_pendingshots() IS 'Detect and remove pending shots where the agent is over an hour overdue and mark those as client crashes.';


--
-- Name: get_next_agent(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_next_agent(integer, integer) RETURNS integer
    AS $_$SELECT case when terminal then null else case when cur_player_started then agentid1 else agentid2 end end as agentid FROM states natural join turntypes, games WHERE gameid=$1 AND stateid=$2;$_$
    LANGUAGE sql;


--
-- Name: FUNCTION get_next_agent(integer, integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION get_next_agent(integer, integer) IS 'Returns the ID of the agent that is next to shoot in given game and state.';


--
-- Name: get_noise(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_noise(integer, integer) RETURNS text
    AS $_$SELECT string FROM games g JOIN noise_strings n ON CASE WHEN (SELECT cur_player_started FROM states WHERE stateid=$1) THEN noiseid1 ELSE noiseid2 END=n.noiseid WHERE gameid=$2;$_$
    LANGUAGE sql;


--
-- Name: get_tablestate(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_tablestate(stateid integer) RETURNS text
    AS $_$select count(*)||' '||concat(' 0.028575 ' || status || ' ' || ball || ' ' ||x || ' ' || y) from tablestates where stateid=$1;$_$
    LANGUAGE sql;


--
-- Name: populate_tournament(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION populate_tournament(tourid integer) RETURNS void
    AS $_$INSERT INTO matches(
            gametype, agentid1, agentid2,  noiseid1, noiseid2, 
            gamesleft1,gamesleft2, max_active_games, noisemetaid1, noisemetaid2, timelimit1, 
            timelimit2, rules, tournamentid, title, priority)
SELECT t.gametype, a.agentid AS agentid1, b.agentid AS agentid2,
       a.noiseid AS noiseid1, b.noiseid AS noiseid2, max_games/2 AS gamesleft1, max_games/2 AS gamesleft2, max_active_games,
       a.noisemetaid AS noisemetaid1, b.noisemetaid AS noisemetaid2,
       a.timelimit AS timelimit1, b.timelimit AS timelimit2, rules, 
       t.tournamentid, title, priority
FROM tournaments t, tournament_agents a, tournament_agents b 
WHERE a.tournamentid=t.tournamentid and b.tournamentid=t.tournamentid and 
      ((a.agentid<b.agentid and master_agent is null) or 
       (a.agentid=master_agent and b.agentid!=master_agent)) and 
      t.tournamentid=$1;
     $_$
    LANGUAGE sql;


--
-- Name: FUNCTION populate_tournament(tourid integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION populate_tournament(tourid integer) IS 'Add matches corresponding to a given tournament.';


--
-- Name: select_pending_match(integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION select_pending_match(agentids integer[]) RETURNS pending_match_info
    AS $_$SELECT m.matchid,case when (gamesleft1>gamesleft2 or agentid2!=ANY($1)) and agentid1=ANY($1) then agentid1 else agentid2 end as agentid,priority FROM matches m left join match_active_games mag on m.matchid=mag.matchid WHERE max_active_games-coalesce(mag.count,0)>0 and (gamesleft1>0 and agentid1 = ANY($1)) or (gamesleft2>0 and agentid2 = ANY($1))  order by priority desc, case when gamesleft1>gamesleft2 then gamesleft1 else gamesleft2 end desc limit 1;$_$
    LANGUAGE sql;


--
-- Name: FUNCTION select_pending_match(agentids integer[]); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION select_pending_match(agentids integer[]) IS 'Returns the highest priority match (and its priority) from those requiring a new game from one of the agents passed as the parameter.';


--
-- Name: select_pending_shot(integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION select_pending_shot(integer[]) RETURNS pending_shot_info
    AS $_$
   select agentid,gameid,stateid,priority from pendingshots p natural join games g join matches m on g.matchid=m.matchid where agentid = ANY($1) and timesent is null order by priority desc, gameid limit 1;
 $_$
    LANGUAGE sql;


--
-- Name: FUNCTION select_pending_shot(integer[]); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION select_pending_shot(integer[]) IS 'Returns the highest priority game and state (and its priority) from those requiring a shot from one of the agents passed as the parameter.';


--
-- Name: set_tablestate(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_tablestate(stateid integer, tablestate text) RETURNS void
    AS $_$insert into tablestates(stateid,status,ball,x,y) select $1 as
stateid, arr[1]::smallint as status,arr[2]::smallint as ball,arr[3]::double
precision as x,arr[4]::double precision as y from (select
regexp_split_to_array(regexp_split_to_table(regexp_replace($2,E'\\A\\d+\\s+0\\.02857\\d+\\s+',''), E'0\\.02857\\d+\\s+'),E'\\s+') as arr) q;$_$
    LANGUAGE sql;


--
-- Name: FUNCTION set_tablestate(stateid integer, tablestate text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION set_tablestate(stateid integer, tablestate text) IS 'Update ball positions of stateid using the encoded TableState object in the second parameter.
State must not have any balls assigned in the tablestates table.';


--
-- Name: concat(text); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE concat(text) (
    SFUNC = textcat,
    STYPE = text
);


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: agents; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE agents (
    agentid integer NOT NULL,
    agentname character varying NOT NULL,
    config character varying,
    passwd character varying,
    owner integer
);


--
-- Name: TABLE agents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE agents IS 'Table identifying all AI agents with IDs, names, configuration files, password, and the user who owns the agent (if any).';


--
-- Name: agents_agentid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE agents_agentid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: agents_agentid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE agents_agentid_seq OWNED BY agents.agentid;


--
-- Name: balls; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE balls (
    ball integer NOT NULL,
    solid boolean
);


--
-- Name: TABLE balls; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE balls IS 'Defines the allowed balls in a table state, and whether or not they are solid.';


--
-- Name: COLUMN balls.solid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN balls.solid IS 'True if solid, false if striped, NULL for other balls (such as the eight ball).';


--
-- Name: ballstates; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE ballstates (
    status integer NOT NULL,
    on_table boolean NOT NULL,
    in_game boolean NOT NULL,
    description character varying NOT NULL,
    moving boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE ballstates; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE ballstates IS 'Physical states a ball can be in.
Values in this table are compatible with the physics library and should not be changed.';


--
-- Name: COLUMN ballstates.on_table; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN ballstates.on_table IS 'True if the ball is physically on the table (i.e. in play and not pocketed).';


--
-- Name: COLUMN ballstates.in_game; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN ballstates.in_game IS 'True if the ball is used in the game, even though it might be in a pocket.';


--
-- Name: COLUMN ballstates.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN ballstates.description IS 'Human-readable description of the ball state.';


--
-- Name: COLUMN ballstates.moving; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN ballstates.moving IS 'True if the ball is in motion.';


--
-- Name: ballstates_stateid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ballstates_stateid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: ballstates_stateid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE ballstates_stateid_seq OWNED BY ballstates.status;


--
-- Name: cache_use; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE cache_use (
    stateid integer NOT NULL,
    matchid integer NOT NULL
);


--
-- Name: TABLE cache_use; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE cache_use IS 'This table is currently not in use.

It will be used for continuation matches to mark which cached states have been expanded to a full game.';


--
-- Name: debug; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE debug (
    shotid integer NOT NULL,
    debug_key character varying NOT NULL,
    debug_value double precision,
    debug_comment character varying
);


--
-- Name: TABLE debug; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE debug IS 'This table is not currently in use.

It will be used to allow clients to add comments their shots as the shots are executed. Comments are of the form of key/value pairs, where the value may be a number (debug_value) or a string (debug_comment).';


--
-- Name: decisions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE decisions (
    decision integer NOT NULL,
    description character varying
);


--
-- Name: TABLE decisions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE decisions IS 'This table lists the various decisions agents may make during a pool game.
Values in this table are compatible with the physics library and should not be changed.';


--
-- Name: decisions_decision_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE decisions_decision_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: decisions_decision_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE decisions_decision_seq OWNED BY decisions.decision;


--
-- Name: tablestates; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tablestates (
    stateid integer NOT NULL,
    ball smallint NOT NULL,
    status smallint NOT NULL,
    x double precision,
    y double precision
);


--
-- Name: TABLE tablestates; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE tablestates IS 'This table complements the states table with the actual locations of balls on the table. Dynamic information (velocity and spin) is not recorded.';


--
-- Name: encoded_tablestates; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW encoded_tablestates AS
    SELECT tablestates.stateid, ((count(*) || ' '::text) || concat((((((((' 0.028575 '::text || tablestates.status) || ' '::text) || tablestates.ball) || ' '::text) || tablestates.x) || ' '::text) || tablestates.y))) AS tablestate FROM tablestates GROUP BY tablestates.stateid;


--
-- Name: VIEW encoded_tablestates; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW encoded_tablestates IS 'Creates a Pool::TableState-compatible representation of all states.';


--
-- Name: states; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE states (
    stateid integer NOT NULL,
    turntype smallint NOT NULL,
    cur_player_started boolean DEFAULT true NOT NULL,
    playing_solids boolean,
    timeleft interval,
    timeleft_opp interval,
    gametype smallint NOT NULL
);


--
-- Name: TABLE states; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE states IS 'This table details game states and corresponds to a GameState object in the physics library. The actual positions of the balls are specified in the tablestates table. This table includes information related to the state within a game.';


--
-- Name: COLUMN states.turntype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN states.turntype IS 'Indicator of the game situation (such as normal shot, break, ball-in-hand).';


--
-- Name: COLUMN states.cur_player_started; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN states.cur_player_started IS 'true if the player who originally broke is the active player in this game state.';


--
-- Name: COLUMN states.playing_solids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN states.playing_solids IS 'True if the active player in this state is supposed to sink the solid balls (in eight ball). False if the active player is playing stripes. Null if the table is open or solids/stripes are irrelevant for the game.';


--
-- Name: COLUMN states.timeleft; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN states.timeleft IS 'Amount of time left for the current player in the game. NULL if no time limit is specified.';


--
-- Name: COLUMN states.timeleft_opp; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN states.timeleft_opp IS 'Amount of time left for the opponent in the game. NULL if no time limit is specified.';


--
-- Name: COLUMN states.gametype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN states.gametype IS 'Type of cue sport the state refers to.';


--
-- Name: encoded_gamestates; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW encoded_gamestates AS
    SELECT encoded_tablestates.stateid, (((((((((((((states.gametype)::text || ' '::text) || (states.turntype)::text) || ' '::text) || (COALESCE(date_part('epoch'::text, states.timeleft), (0)::double precision))::text) || ' '::text) || (COALESCE(date_part('epoch'::text, states.timeleft_opp), (0)::double precision))::text) || ' '::text) || CASE WHEN states.cur_player_started THEN 1 ELSE 0 END) || ' '::text) || encoded_tablestates.tablestate) || ' '::text) || CASE WHEN (states.playing_solids IS NULL) THEN '1 0'::text ELSE CASE WHEN states.playing_solids THEN '0 1'::text ELSE '0 0'::text END END) AS gamestate FROM (encoded_tablestates NATURAL JOIN states);


--
-- Name: VIEW encoded_gamestates; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW encoded_gamestates IS 'Creates a Pool::GameState::Factory-compatible representation of all states.';


--
-- Name: end_reasons; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE end_reasons (
    end_reason integer NOT NULL,
    description character varying,
    use_in_scoring boolean DEFAULT true NOT NULL,
    use_in_analysis boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE end_reasons; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE end_reasons IS 'This table includes all reasons a pool game may end. Reasons 1 and 2 refer to games that have been played in full. 
The reasons 3,4,5, and 6 refer to various problems in executing the game. 
Reason 7 is for single-agent games that are only played till loss of turn.
Reason 8 is when a client has explictly conceded the game.';


--
-- Name: COLUMN end_reasons.use_in_scoring; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN end_reasons.use_in_scoring IS 'A true value in this column means that games that ended this way will be counted towards an agent''s score in a tournament.';


--
-- Name: COLUMN end_reasons.use_in_analysis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN end_reasons.use_in_analysis IS 'A true value in this column means that games that ended this way will be counted when producing statistical information about a match.';


--
-- Name: end_reasons_end_reason_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE end_reasons_end_reason_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: end_reasons_end_reason_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE end_reasons_end_reason_seq OWNED BY end_reasons.end_reason;


--
-- Name: shots; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE shots (
    shotid integer NOT NULL,
    gameid integer NOT NULL,
    agentid integer NOT NULL,
    prev_state integer NOT NULL,
    next_state integer NOT NULL,
    a double precision,
    b double precision,
    theta double precision,
    phi double precision,
    v double precision,
    cue_x double precision,
    cue_y double precision,
    ball smallint,
    pocket smallint,
    nl_a double precision,
    nl_b double precision,
    nl_theta double precision,
    nl_phi double precision,
    nl_v double precision,
    decision smallint,
    timespent interval NOT NULL,
    timedone timestamp with time zone DEFAULT now() NOT NULL,
    duration double precision,
    remote_ip inet
);


--
-- Name: TABLE shots; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE shots IS 'This table includes all shots that have been processed by the server. Each shot is associated with a game and an agent, and transitions between two game states.
Decision nodes are also modeled as shots, but with cue strike parameters absent.';


--
-- Name: COLUMN shots.cue_x; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN shots.cue_x IS 'X position of cue ball as given by AI. prev_state will not include this cue ball placement.';


--
-- Name: COLUMN shots.cue_y; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN shots.cue_y IS 'Y position of cue ball as given by AI. prev_state will not include this cue ball placement.';


--
-- Name: COLUMN shots.ball; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN shots.ball IS 'Called ball, NULL if not applicable.';


--
-- Name: COLUMN shots.pocket; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN shots.pocket IS 'Called pocket, NULL if not applicable.';


--
-- Name: COLUMN shots.decision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN shots.decision IS 'Decision made by the agent (NULL if not applicable).';


--
-- Name: COLUMN shots.timespent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN shots.timespent IS 'Time (either real or fake) spent by the agent executing the shot.';


--
-- Name: COLUMN shots.timedone; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN shots.timedone IS 'Actual date and time the shot information was received.';


--
-- Name: COLUMN shots.duration; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN shots.duration IS 'Amount of time, in simulation seconds, the shot executes on the table.
This value is generated by the physics and is used in order to give the graphical frontend timing information to generate the scrollbar.';


--
-- Name: COLUMN shots.remote_ip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN shots.remote_ip IS 'IP address used by the client submitting the shot, if available.';


--
-- Name: end_states; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW end_states AS
    SELECT s.gameid, max(s.next_state) AS end_state FROM shots s GROUP BY s.gameid;


--
-- Name: VIEW end_states; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW end_states IS 'Identifies the final positions of all games (whether completed or not).';


--
-- Name: games; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE games (
    gameid integer NOT NULL,
    matchid integer NOT NULL,
    gametype smallint NOT NULL,
    agentid1 integer NOT NULL,
    agentid2 integer,
    noiseid1 integer NOT NULL,
    noiseid2 integer,
    start_state integer NOT NULL,
    start_player_won boolean,
    end_reason smallint
);


--
-- Name: TABLE games; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE games IS 'This table includes a row for each pool game (i.e. sequence of shots from break to victory of one of the players). All games must be part of a match. To play a single game, create a match with only one game.';


--
-- Name: COLUMN games.matchid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN games.matchid IS 'Match this game is part of. Required.';


--
-- Name: COLUMN games.agentid1; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN games.agentid1 IS 'Agent who plays first (breaks) in the game.';


--
-- Name: COLUMN games.agentid2; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN games.agentid2 IS 'Agent who does not break, may only be null for single-agent test games.';


--
-- Name: COLUMN games.noiseid1; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN games.noiseid1 IS 'Noise information for agent 1 as an index into the noise table.';


--
-- Name: COLUMN games.noiseid2; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN games.noiseid2 IS 'Noise information for agent 2 as an index into the noise table.';


--
-- Name: COLUMN games.start_state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN games.start_state IS 'Initial state of the game, usually a racked state.';


--
-- Name: COLUMN games.start_player_won; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN games.start_player_won IS 'True if agent identified by agentid1 has won the game (either normally or due to a loss by other player). False if agentid2 has won. Null if the game has not yet ended.';


--
-- Name: COLUMN games.end_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN games.end_reason IS 'Reason game ended. Null if game has not yet ended.';


--
-- Name: matches; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE matches (
    matchid integer NOT NULL,
    gametype smallint NOT NULL,
    agentid1 integer NOT NULL,
    agentid2 integer,
    noiseid1 integer NOT NULL,
    noiseid2 integer,
    gamesleft1 integer DEFAULT 0 NOT NULL,
    max_active_games integer,
    noisemetaid1 integer NOT NULL,
    noisemetaid2 integer,
    timelimit1 interval,
    timelimit2 interval,
    rules smallint DEFAULT 1 NOT NULL,
    tournamentid integer,
    title character varying,
    priority integer DEFAULT 0 NOT NULL,
    gamesleft2 integer DEFAULT 0 NOT NULL,
    faketime boolean DEFAULT false NOT NULL,
    owner integer
);


--
-- Name: TABLE matches; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE matches IS 'Matches are sets of one or more games between the same agents (or test games for a single agent), and can be added by the user. The matches table includes common information about the games within the match.';


--
-- Name: COLUMN matches.gametype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.gametype IS 'Type of cue sport being played.';


--
-- Name: COLUMN matches.agentid1; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.agentid1 IS 'First (or only) participant in the match.';


--
-- Name: COLUMN matches.agentid2; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.agentid2 IS 'Second participant in the match (if any)';


--
-- Name: COLUMN matches.noiseid1; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.noiseid1 IS 'Base noise for agent 1. For matches with variable noise, this could be modified by noisemetaid1.';


--
-- Name: COLUMN matches.noiseid2; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.noiseid2 IS 'Base noise for agent 2. For matches with variable noise, this could be modified by noisemetaid1.';


--
-- Name: COLUMN matches.gamesleft1; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.gamesleft1 IS 'Number of games not yet started where agent 1 has to break. Setting this to a value greater than 0 may assign agent 1 a new game in the match.';


--
-- Name: COLUMN matches.max_active_games; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.max_active_games IS 'Maximum number of incomplete games that are allowed to be resolved at once.';


--
-- Name: COLUMN matches.noisemetaid1; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.noisemetaid1 IS 'Modification of noise values for variable noise for agent 1. Set to 0 for constant noise.';


--
-- Name: COLUMN matches.noisemetaid2; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.noisemetaid2 IS 'Modification of noise values for variable noise for agent 2. Set to 0 for constant noise.';


--
-- Name: COLUMN matches.timelimit1; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.timelimit1 IS 'Amount of time allotted per game for agent 1.';


--
-- Name: COLUMN matches.timelimit2; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.timelimit2 IS 'Amount of time allotted per game for agent 2.';


--
-- Name: COLUMN matches.rules; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.rules IS 'Used to specify special rules for testing matches. Use 1 for normal rules.';


--
-- Name: COLUMN matches.tournamentid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.tournamentid IS 'If the match is part of a tournament, this is the identifier of the tournament';


--
-- Name: COLUMN matches.title; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.title IS 'Human-readable title for the match.';


--
-- Name: COLUMN matches.priority; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.priority IS 'Processing priority for games within this match. Matches with higher priority will always be processed before lower priority matches if they have any outstanding games or shots.';


--
-- Name: COLUMN matches.gamesleft2; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.gamesleft2 IS 'Number of games not yet started where agent 2 has to break. Setting this to a value greater than 0 may assign agent 2 a new game in the match.';


--
-- Name: COLUMN matches.faketime; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.faketime IS 'If true, the server will not measure time for the agents, but instead will trust time reports by the clients. Useful for running experiments.';


--
-- Name: COLUMN matches.owner; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN matches.owner IS 'User ID who owns the match and may adjust its settings and view all games within the match.';


--
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE users (
    userid integer NOT NULL,
    username character varying NOT NULL,
    passwd character varying NOT NULL,
    is_admin boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE users; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE users IS 'This table is part of the simple user permissions system employed for the web interface.
Admin users have complete access to the database, while normal users can only modify objects they own, and may only view objects that are related to objects they own.';


--
-- Name: game_access; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW game_access AS
    SELECT g.gameid, u.userid FROM games g, users u WHERE ((EXISTS (SELECT m.matchid FROM matches m WHERE ((m.matchid = g.matchid) AND (u.userid = m.owner)))) OR ((g.end_reason IS NOT NULL) AND (EXISTS (SELECT a.agentid FROM agents a WHERE (((a.agentid = g.agentid1) OR (a.agentid = g.agentid2)) AND (a.owner = u.userid))))));


--
-- Name: noise; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE noise (
    noiseid integer NOT NULL,
    noisetype smallint DEFAULT 0 NOT NULL,
    n_a double precision,
    n_b double precision,
    n_phi double precision,
    n_v double precision,
    n_factor double precision,
    known boolean DEFAULT true NOT NULL,
    known_opp boolean DEFAULT true NOT NULL,
    basenoiseid integer,
    noisemetaid integer,
    n_theta double precision,
    title character varying,
    owner integer
);


--
-- Name: TABLE noise; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE noise IS 'This table identifies a noise information for a player.';


--
-- Name: COLUMN noise.noisetype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN noise.noisetype IS 'Type of noise (none, gaussian, etc.)';


--
-- Name: COLUMN noise.known; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN noise.known IS 'True if the agent is aware of their own noise.';


--
-- Name: COLUMN noise.known_opp; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN noise.known_opp IS 'True if the agent is aware of the opponent''s noise.';


--
-- Name: COLUMN noise.basenoiseid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN noise.basenoiseid IS 'If this noise value was generated based on a meta-noise, this identifies the original noise entry it was based on.';


--
-- Name: COLUMN noise.noisemetaid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN noise.noisemetaid IS 'If this noise value was generated based on a meta-noise, this identifies the meta noise information.';


--
-- Name: COLUMN noise.title; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN noise.title IS 'A human-readable representation of the noise.';


--
-- Name: COLUMN noise.owner; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN noise.owner IS 'User who owns this noise entry.';


--
-- Name: noise_strings; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW noise_strings AS
    SELECT noise.noiseid, (noise.noisetype || COALESCE((((((((((' '::text || (noise.n_a * noise.n_factor)) || ' '::text) || (noise.n_b * noise.n_factor)) || ' '::text) || (noise.n_theta * noise.n_factor)) || ' '::text) || (noise.n_phi * noise.n_factor)) || ' '::text) || (noise.n_v * noise.n_factor)), ' '::text)) AS string FROM noise;


--
-- Name: VIEW noise_strings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW noise_strings IS 'Creates Noise::Factory-compatible string representation of noise entries.';


--
-- Name: game_logfiles; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW game_logfiles AS
    SELECT gg.gameid, (((('GTYPE '::text || gg.gametype) || '
'::text) || array_to_string(ARRAY(SELECT ((((((((((((((((((((((((((((((((((((((((((('STATE '::text || (SELECT encoded_gamestates.gamestate FROM encoded_gamestates WHERE (encoded_gamestates.stateid = sh.prev_state))) || '
'::text) || 'SHOT '::text) || COALESCE(sh.a, (0)::double precision)) || ' '::text) || COALESCE(sh.b, (0)::double precision)) || ' '::text) || COALESCE(sh.theta, (0)::double precision)) || ' '::text) || COALESCE(sh.phi, (0)::double precision)) || ' '::text) || COALESCE(sh.v, (0)::double precision)) || ' '::text) || COALESCE(sh.nl_a, (0)::double precision)) || ' '::text) || COALESCE(sh.nl_b, (0)::double precision)) || ' '::text) || COALESCE(sh.nl_theta, (0)::double precision)) || ' '::text) || COALESCE(sh.nl_phi, (0)::double precision)) || ' '::text) || COALESCE(sh.nl_v, (0)::double precision)) || ' '::text) || COALESCE((sh.ball)::integer, 16)) || ' '::text) || COALESCE((sh.pocket)::integer, 6)) || ' '::text) || COALESCE((sh.decision)::integer, 0)) || ' '::text) || COALESCE(sh.cue_x, (0)::double precision)) || ' '::text) || COALESCE(sh.cue_y, (0)::double precision)) || ' '::text) || COALESCE(date_part('epoch'::text, sh.timespent), (0)::double precision)) || ' '::text) || COALESCE(sh.duration, (0)::double precision)) || ' '::text) || COALESCE((SELECT noise_strings.string FROM noise_strings WHERE (noise_strings.noiseid = (SELECT CASE WHEN (sh.agentid = g.agentid1) THEN g.noiseid1 ELSE g.noiseid2 END AS noiseid2 FROM games g WHERE (g.gameid = gg.gameid)))), '1'::text)) || ' "'::text) || (COALESCE((SELECT a.agentname FROM agents a WHERE (a.agentid = sh.agentid)), ''::character varying))::text) || '" "'::text) || (COALESCE((SELECT a.agentname FROM agents a WHERE (a.agentid = (SELECT ((games.agentid1 + games.agentid2) - sh.agentid) FROM games WHERE (games.gameid = sh.gameid)))), ''::character varying))::text) || '"'::text) AS logrow FROM (shots sh JOIN states st ON ((sh.prev_state = st.stateid))) WHERE (sh.gameid = gg.gameid) ORDER BY sh.shotid), '
'::text)) || '
'::text) AS logfile FROM games gg;


--
-- Name: VIEW game_logfiles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW game_logfiles IS 'Generates a LogReader compatible log file for each game.';


--
-- Name: game_switchcount; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW game_switchcount AS
    SELECT g.gameid, g.agentid1, g.matchid, COALESCE(c.count, (0)::bigint) AS switches FROM ((games g NATURAL JOIN end_reasons e) LEFT JOIN (SELECT shots.gameid, count(*) AS count FROM ((shots JOIN states st1 ON ((shots.prev_state = st1.stateid))) JOIN states st2 ON ((shots.next_state = st2.stateid))) WHERE (st1.cur_player_started <> st2.cur_player_started) GROUP BY shots.gameid) c ON ((g.gameid = c.gameid))) WHERE e.use_in_analysis;


--
-- Name: VIEW game_switchcount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW game_switchcount IS 'Returns the number of times play has switched for each game that has ended without crashing.';


--
-- Name: games_gameid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE games_gameid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: games_gameid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE games_gameid_seq OWNED BY games.gameid;


--
-- Name: gametypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE gametypes (
    gametype integer NOT NULL,
    description character varying NOT NULL
);


--
-- Name: TABLE gametypes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE gametypes IS 'Types of cue sports supported by the database.

Currently only Eight Ball is supported.';


--
-- Name: gametypes_gametype_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE gametypes_gametype_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: gametypes_gametype_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE gametypes_gametype_seq OWNED BY gametypes.gametype;


--
-- Name: logfiles; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE logfiles (
    logid integer NOT NULL,
    logdata text NOT NULL,
    secret integer NOT NULL,
    expiration timestamp without time zone DEFAULT (now() + '1 day'::interval) NOT NULL
);


--
-- Name: TABLE logfiles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE logfiles IS 'This table supports the "view log" upload feature. When a log file is uploaded it will be added verbatim as a row to this table, and a secret identifier is assigned.

The function cleanup_logfiles() should be called preiodically to remove expired files.';


--
-- Name: logfiles_logid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE logfiles_logid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: logfiles_logid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE logfiles_logid_seq OWNED BY logfiles.logid;


--
-- Name: match_access; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW match_access AS
    SELECT m.matchid, u.userid FROM matches m, users u WHERE ((u.userid = m.owner) OR (EXISTS (SELECT a.agentid FROM agents a WHERE (((a.agentid = m.agentid1) OR (a.agentid = m.agentid2)) AND (a.owner = u.userid)))));


--
-- Name: pendingshots; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pendingshots (
    stateid integer NOT NULL,
    gameid integer NOT NULL,
    agentid integer NOT NULL,
    timesent timestamp with time zone,
    sent_to inet
);


--
-- Name: TABLE pendingshots; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE pendingshots IS 'This table identifies game states that require a shot from a client. If timesent is not NULL, this state is currently being processed by a client.';


--
-- Name: COLUMN pendingshots.timesent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN pendingshots.timesent IS 'Time when the agent started processing the shot. Used to calculate time spent and detect timeouts.';


--
-- Name: COLUMN pendingshots.sent_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN pendingshots.sent_to IS 'IP address of remote host processing the shot.';


--
-- Name: match_active_games; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW match_active_games AS
    SELECT m.matchid, count(*) AS count FROM ((pendingshots p JOIN games g ON ((p.gameid = g.gameid))) JOIN matches m ON ((g.matchid = m.matchid))) WHERE (p.timesent IS NOT NULL) GROUP BY m.matchid;


--
-- Name: VIEW match_active_games; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW match_active_games IS 'Returns the number of games waiting for a shot in each match.';


--
-- Name: match_endtype_histogram; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW match_endtype_histogram AS
    SELECT games.matchid, CASE WHEN ((games.end_reason = 1) = games.start_player_won) THEN games.agentid1 ELSE games.agentid2 END AS agent, games.end_reason, count(*) AS count FROM games WHERE (games.start_player_won IS NOT NULL) GROUP BY games.matchid, CASE WHEN ((games.end_reason = 1) = games.start_player_won) THEN games.agentid1 ELSE games.agentid2 END, games.end_reason ORDER BY games.matchid, CASE WHEN ((games.end_reason = 1) = games.start_player_won) THEN games.agentid1 ELSE games.agentid2 END, games.end_reason;


--
-- Name: VIEW match_endtype_histogram; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW match_endtype_histogram IS 'For every match, counts the number of times each agent has caused each end reason to happen (wins are caused by the winner, all other end types are caused by the loser).';


--
-- Name: match_shot_analysis; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW match_shot_analysis AS
    SELECT g.matchid, s.agentid, st1.turntype AS prevtt, st2.turntype AS posttt, (st1.cur_player_started <> st2.cur_player_started) AS switch, count(*) AS count FROM ((((shots s NATURAL JOIN games g) NATURAL JOIN end_reasons e) JOIN states st1 ON ((st1.stateid = s.prev_state))) JOIN states st2 ON ((st2.stateid = s.next_state))) WHERE e.use_in_analysis GROUP BY g.matchid, s.agentid, st1.turntype, st2.turntype, (st1.cur_player_started <> st2.cur_player_started) ORDER BY g.matchid, s.agentid, st1.turntype, st2.turntype, (st1.cur_player_started <> st2.cur_player_started);


--
-- Name: VIEW match_shot_analysis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW match_shot_analysis IS 'For each match, returns the number of times a shot by each agent has transitioned from one turn type to another with or without switching the active player.';


--
-- Name: match_switch_histogram; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW match_switch_histogram AS
    SELECT game_switchcount.matchid, game_switchcount.agentid1, game_switchcount.switches, count(game_switchcount.gameid) AS count FROM game_switchcount GROUP BY game_switchcount.matchid, game_switchcount.agentid1, game_switchcount.switches ORDER BY game_switchcount.matchid, game_switchcount.agentid1, game_switchcount.switches;


--
-- Name: VIEW match_switch_histogram; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW match_switch_histogram IS 'For each match, generates a histogram of how many times play has switched in games in that match.';


--
-- Name: matches_matchid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE matches_matchid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: matches_matchid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE matches_matchid_seq OWNED BY matches.matchid;


--
-- Name: noise_access; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW noise_access AS
    SELECT DISTINCT n.noiseid, a.userid FROM ((SELECT g.noiseid1 AS noiseid, g.gameid FROM games g UNION ALL SELECT g.noiseid2 AS noiseid, g.gameid FROM games g WHERE (g.noiseid2 IS NOT NULL)) n JOIN game_access a ON ((n.gameid = a.gameid))) ORDER BY n.noiseid, a.userid;


--
-- Name: noise_noiseid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE noise_noiseid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: noise_noiseid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE noise_noiseid_seq OWNED BY noise.noiseid;


--
-- Name: state_ball_counts; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW state_ball_counts AS
    SELECT s.stateid, sum(CASE WHEN (b.solid AND bs.on_table) THEN 1 ELSE 0 END) AS solids, sum(CASE WHEN ((NOT b.solid) AND bs.on_table) THEN 1 ELSE 0 END) AS stripes FROM (((states s NATURAL JOIN tablestates ts) NATURAL JOIN balls b) JOIN ballstates bs ON ((bs.status = ts.status))) GROUP BY s.stateid;


--
-- Name: VIEW state_ball_counts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW state_ball_counts IS 'Returns the number of stripes and solids left on the table for each table state.';


--
-- Name: noise_sim_ballsleft_surface; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW noise_sim_ballsleft_surface AS
    SELECT games.matchid, noise.n_factor AS noise, round((date_part('epoch'::text, states.timeleft) / (0.003)::double precision)) AS sim_limit, games.end_reason, end_states.end_state, CASE WHEN s2.playing_solids THEN state_ball_counts.solids WHEN (NOT s2.playing_solids) THEN state_ball_counts.stripes ELSE (7)::bigint END AS balls_left FROM (((((games JOIN noise ON ((games.noiseid1 = noise.noiseid))) JOIN states ON ((states.stateid = games.start_state))) JOIN end_states ON ((end_states.gameid = games.gameid))) JOIN states s2 ON ((s2.stateid = end_states.end_state))) JOIN state_ball_counts ON ((s2.stateid = state_ball_counts.stateid))) WHERE (games.end_reason IS NOT NULL);


--
-- Name: VIEW noise_sim_ballsleft_surface; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW noise_sim_ballsleft_surface IS 'Used to create a surface plot of noiselevel vs. time vs. amount of balls left for single-agent noise-time experiments.';


--
-- Name: noise_sim_scatterplot; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW noise_sim_scatterplot AS
    SELECT games.matchid, noise.n_factor AS noise, round((date_part('epoch'::text, states.timeleft) / (0.003)::double precision)) AS sim_limit, games.end_reason FROM ((games JOIN noise ON ((games.noiseid1 = noise.noiseid))) JOIN states ON ((states.stateid = games.start_state))) WHERE (games.end_reason IS NOT NULL);


--
-- Name: VIEW noise_sim_scatterplot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW noise_sim_scatterplot IS 'Used to create a scatter of noiselevel vs. time vs. wins off the break for single-agent noise-time experiments.';


--
-- Name: noisemeta; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE noisemeta (
    noisemetaid integer NOT NULL,
    metatype smallint DEFAULT 0 NOT NULL,
    n_a double precision,
    n_b double precision,
    n_theta double precision,
    n_phi double precision,
    n_v double precision,
    n_factor double precision,
    title character varying
);


--
-- Name: TABLE noisemeta; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE noisemeta IS 'This table is designed to specify the changes to a base noise in order to generate a new noise that may vary from game to game within a match.

Not in use.';


--
-- Name: noisemeta_noisemetaid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE noisemeta_noisemetaid_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: noisemeta_noisemetaid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE noisemeta_noisemetaid_seq OWNED BY noisemeta.noisemetaid;


--
-- Name: noisetypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE noisetypes (
    noisetype integer NOT NULL,
    description character varying NOT NULL
);


--
-- Name: noisetypes_noisetype_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE noisetypes_noisetype_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: noisetypes_noisetype_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE noisetypes_noisetype_seq OWNED BY noisetypes.noisetype;


--
-- Name: pockets; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pockets (
    pocket integer NOT NULL,
    description character varying NOT NULL
);


--
-- Name: TABLE pockets; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE pockets IS 'This table identifies pockets on the pool table.
Values in this table are compatible with the physics library and should not be changed.';


--
-- Name: pockets_pocket_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pockets_pocket_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: pockets_pocket_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pockets_pocket_seq OWNED BY pockets.pocket;


--
-- Name: rules; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE rules (
    rulesid integer NOT NULL,
    description character varying NOT NULL
);


--
-- Name: TABLE rules; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE rules IS 'This table specifies special rule modifications that may be used to run specialized test matches (such as a single-agent break test).';


--
-- Name: rules_rulesid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rules_rulesid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: rules_rulesid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE rules_rulesid_seq OWNED BY rules.rulesid;


--
-- Name: shot_access; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW shot_access AS
    SELECT s.shotid, a.userid FROM (shots s JOIN game_access a ON ((s.gameid = a.gameid)));


--
-- Name: shots_shotid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE shots_shotid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: shots_shotid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE shots_shotid_seq OWNED BY shots.shotid;


--
-- Name: state_access; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW state_access AS
    SELECT s.stateid, a.userid FROM ((SELECT s.next_state AS stateid, s.gameid FROM shots s UNION ALL SELECT g.start_state AS stateid, g.gameid FROM games g) s JOIN game_access a ON ((s.gameid = a.gameid)));


--
-- Name: state_cache; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE state_cache (
    agentid integer NOT NULL,
    noiseid integer NOT NULL,
    timelimit interval NOT NULL,
    stateid integer NOT NULL
);


--
-- Name: TABLE state_cache; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE state_cache IS 'This table includes non-terminal states encountered by single-agent test matches. Data in this table can be used to run a continuation match based on previously cached states.

Continuation matches are not yet implemented.';


--
-- Name: COLUMN state_cache.agentid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN state_cache.agentid IS 'ID of agent who broke.';


--
-- Name: COLUMN state_cache.noiseid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN state_cache.noiseid IS 'Noise applied to the agent.';


--
-- Name: COLUMN state_cache.timelimit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN state_cache.timelimit IS 'Amount of time agent had a the begining of the game. This is important as agents may behave differently with different time limits.';


--
-- Name: COLUMN state_cache.stateid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN state_cache.stateid IS 'ID of the state after the agent has lost its turn.';


--
-- Name: states_stateid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE states_stateid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: states_stateid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE states_stateid_seq OWNED BY states.stateid;


--
-- Name: tournament_agents; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tournament_agents (
    tournamentid integer NOT NULL,
    agentid integer NOT NULL,
    timelimit interval NOT NULL,
    noiseid integer NOT NULL,
    noisemetaid integer NOT NULL
);


--
-- Name: TABLE tournament_agents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE tournament_agents IS 'Assignment of agents to tournaments.';


--
-- Name: tournaments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tournaments (
    tournamentid integer NOT NULL,
    gametype integer NOT NULL,
    rules smallint NOT NULL,
    master_agent integer,
    title character varying,
    priority integer DEFAULT 0 NOT NULL,
    max_games integer NOT NULL,
    max_active_games integer,
    faketime boolean DEFAULT false NOT NULL,
    owner integer
);


--
-- Name: TABLE tournaments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE tournaments IS 'Tournaments are series of matches with 2 or more agents where either (a) one agent plays all other agents, or (b) every two agents play each other. In case (a), the agent who plays all others is the master agent. In case (b), master_agent is null.

After a tournament is set up, use populate_tournament() to create the relevant matches.';


--
-- Name: COLUMN tournaments.gametype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN tournaments.gametype IS 'Type of cue sport being played';


--
-- Name: COLUMN tournaments.rules; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN tournaments.rules IS 'Special rules, if needed';


--
-- Name: COLUMN tournaments.master_agent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN tournaments.master_agent IS 'If defined, only the master_agent will play all other agents. Otherwise, all agents will play all other agents.';


--
-- Name: COLUMN tournaments.priority; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN tournaments.priority IS 'Processing priority for games within this tournament. Matches with higher priority will always be processed before lower priority matches if they have any outstanding games or shots.';


--
-- Name: COLUMN tournaments.max_games; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN tournaments.max_games IS 'Total number of games for each match within the tournament.';


--
-- Name: COLUMN tournaments.max_active_games; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN tournaments.max_active_games IS 'Total number of games per match to be allowed to execute at once.';


--
-- Name: COLUMN tournaments.faketime; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN tournaments.faketime IS 'If true, clients'' time spent reports will be trusted.';


--
-- Name: tournaments_tournamentid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tournaments_tournamentid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tournaments_tournamentid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tournaments_tournamentid_seq OWNED BY tournaments.tournamentid;


--
-- Name: turntypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE turntypes (
    turntype integer NOT NULL,
    description character varying NOT NULL,
    terminal boolean DEFAULT false NOT NULL,
    posreqd boolean DEFAULT false NOT NULL,
    decisionallowed boolean DEFAULT false NOT NULL,
    shotreqd boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE turntypes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE turntypes IS 'This table identifies game situations in cue sports such as break or ball-in-hand.
Values in this table are compatible with the physics library and should not be changed.';


--
-- Name: turntypes_turntype_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE turntypes_turntype_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: turntypes_turntype_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE turntypes_turntype_seq OWNED BY turntypes.turntype;


--
-- Name: users_userid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_userid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: users_userid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_userid_seq OWNED BY users.userid;


--
-- Name: agentid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE agents ALTER COLUMN agentid SET DEFAULT nextval('agents_agentid_seq'::regclass);


--
-- Name: status; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ballstates ALTER COLUMN status SET DEFAULT nextval('ballstates_stateid_seq'::regclass);


--
-- Name: decision; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE decisions ALTER COLUMN decision SET DEFAULT nextval('decisions_decision_seq'::regclass);


--
-- Name: end_reason; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE end_reasons ALTER COLUMN end_reason SET DEFAULT nextval('end_reasons_end_reason_seq'::regclass);


--
-- Name: gameid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE games ALTER COLUMN gameid SET DEFAULT nextval('games_gameid_seq'::regclass);


--
-- Name: gametype; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE gametypes ALTER COLUMN gametype SET DEFAULT nextval('gametypes_gametype_seq'::regclass);


--
-- Name: logid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE logfiles ALTER COLUMN logid SET DEFAULT nextval('logfiles_logid_seq'::regclass);


--
-- Name: matchid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE matches ALTER COLUMN matchid SET DEFAULT nextval('matches_matchid_seq'::regclass);


--
-- Name: noiseid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE noise ALTER COLUMN noiseid SET DEFAULT nextval('noise_noiseid_seq'::regclass);


--
-- Name: noisemetaid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE noisemeta ALTER COLUMN noisemetaid SET DEFAULT nextval('noisemeta_noisemetaid_seq'::regclass);


--
-- Name: noisetype; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE noisetypes ALTER COLUMN noisetype SET DEFAULT nextval('noisetypes_noisetype_seq'::regclass);


--
-- Name: pocket; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE pockets ALTER COLUMN pocket SET DEFAULT nextval('pockets_pocket_seq'::regclass);


--
-- Name: rulesid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE rules ALTER COLUMN rulesid SET DEFAULT nextval('rules_rulesid_seq'::regclass);


--
-- Name: shotid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE shots ALTER COLUMN shotid SET DEFAULT nextval('shots_shotid_seq'::regclass);


--
-- Name: stateid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE states ALTER COLUMN stateid SET DEFAULT nextval('states_stateid_seq'::regclass);


--
-- Name: tournamentid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tournaments ALTER COLUMN tournamentid SET DEFAULT nextval('tournaments_tournamentid_seq'::regclass);


--
-- Name: turntype; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE turntypes ALTER COLUMN turntype SET DEFAULT nextval('turntypes_turntype_seq'::regclass);


--
-- Name: userid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE users ALTER COLUMN userid SET DEFAULT nextval('users_userid_seq'::regclass);


--
-- Name: AGENTS_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY agents
    ADD CONSTRAINT "AGENTS_pkey" PRIMARY KEY (agentid);


--
-- Name: BALLS_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY balls
    ADD CONSTRAINT "BALLS_pkey" PRIMARY KEY (ball);


--
-- Name: DEBUG_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY debug
    ADD CONSTRAINT "DEBUG_pkey" PRIMARY KEY (shotid, debug_key);


--
-- Name: GAMES_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY games
    ADD CONSTRAINT "GAMES_pkey" PRIMARY KEY (gameid);


--
-- Name: MATCHES_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY matches
    ADD CONSTRAINT "MATCHES_pkey" PRIMARY KEY (matchid);


--
-- Name: NOISEMETA_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY noisemeta
    ADD CONSTRAINT "NOISEMETA_pkey" PRIMARY KEY (noisemetaid);


--
-- Name: NOISE_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY noise
    ADD CONSTRAINT "NOISE_pkey" PRIMARY KEY (noiseid);


--
-- Name: PENDINGSHOTS_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pendingshots
    ADD CONSTRAINT "PENDINGSHOTS_pkey" PRIMARY KEY (stateid, gameid);


--
-- Name: SHOTS_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY shots
    ADD CONSTRAINT "SHOTS_pkey" PRIMARY KEY (shotid);


--
-- Name: STATES_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY states
    ADD CONSTRAINT "STATES_pkey" PRIMARY KEY (stateid);


--
-- Name: TBLSTATES_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tablestates
    ADD CONSTRAINT "TBLSTATES_pkey" PRIMARY KEY (stateid, ball);


--
-- Name: agents_agentname_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY agents
    ADD CONSTRAINT agents_agentname_key UNIQUE (agentname, config);


--
-- Name: ballstates_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY ballstates
    ADD CONSTRAINT ballstates_pkey PRIMARY KEY (status);


--
-- Name: cache_use_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cache_use
    ADD CONSTRAINT cache_use_pkey PRIMARY KEY (matchid, stateid);


--
-- Name: decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY decisions
    ADD CONSTRAINT decisions_pkey PRIMARY KEY (decision);


--
-- Name: end_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY end_reasons
    ADD CONSTRAINT end_reasons_pkey PRIMARY KEY (end_reason);


--
-- Name: gametypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY gametypes
    ADD CONSTRAINT gametypes_pkey PRIMARY KEY (gametype);


--
-- Name: logfiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY logfiles
    ADD CONSTRAINT logfiles_pkey PRIMARY KEY (logid);


--
-- Name: noisetypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY noisetypes
    ADD CONSTRAINT noisetypes_pkey PRIMARY KEY (noisetype);


--
-- Name: pendingshots_gameid_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pendingshots
    ADD CONSTRAINT pendingshots_gameid_key UNIQUE (gameid);


--
-- Name: pockets_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pockets
    ADD CONSTRAINT pockets_pkey PRIMARY KEY (pocket);


--
-- Name: rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_pkey PRIMARY KEY (rulesid);


--
-- Name: state_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY state_cache
    ADD CONSTRAINT state_cache_pkey PRIMARY KEY (agentid, noiseid, timelimit, stateid);


--
-- Name: state_cache_stateid_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY state_cache
    ADD CONSTRAINT state_cache_stateid_key UNIQUE (stateid);


--
-- Name: tournament_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tournament_agents
    ADD CONSTRAINT tournament_agents_pkey PRIMARY KEY (tournamentid, agentid, timelimit, noiseid, noisemetaid);


--
-- Name: tournaments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tournaments
    ADD CONSTRAINT tournaments_pkey PRIMARY KEY (tournamentid);


--
-- Name: turntypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY turntypes
    ADD CONSTRAINT turntypes_pkey PRIMARY KEY (turntype);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (userid);


--
-- Name: users_username_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: agents_agentname_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX agents_agentname_index ON agents USING btree (agentname);


--
-- Name: agents_owner; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX agents_owner ON agents USING btree (owner);


--
-- Name: fki_; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fki_ ON noise USING btree (basenoiseid);


--
-- Name: fki_games_end_reason_fkey; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fki_games_end_reason_fkey ON games USING btree (end_reason);


--
-- Name: fki_shots_pocket; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fki_shots_pocket ON shots USING btree (pocket);


--
-- Name: fki_status; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fki_status ON tablestates USING btree (status);


--
-- Name: games_matchid_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX games_matchid_index ON games USING hash (matchid);


--
-- Name: games_noiseid1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX games_noiseid1 ON games USING btree (noiseid1);


--
-- Name: games_noiseid2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX games_noiseid2 ON games USING btree (noiseid2);


--
-- Name: games_start_state; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX games_start_state ON games USING hash (start_state);


--
-- Name: logfiles_expiration; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX logfiles_expiration ON logfiles USING btree (expiration);


--
-- Name: noise_noiseindex; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX noise_noiseindex ON noise USING btree (noisetype, n_a, n_b, n_theta, n_phi, n_v, n_factor, known, known_opp, basenoiseid, noisemetaid);


--
-- Name: shots_gameid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX shots_gameid ON shots USING hash (gameid);


--
-- Name: shots_next_state; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX shots_next_state ON shots USING hash (next_state);


--
-- Name: shots_prev_state; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX shots_prev_state ON shots USING hash (prev_state);


--
-- Name: GAMES_agentid1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY games
    ADD CONSTRAINT "GAMES_agentid1_fkey" FOREIGN KEY (agentid1) REFERENCES agents(agentid);


--
-- Name: GAMES_agentid2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY games
    ADD CONSTRAINT "GAMES_agentid2_fkey" FOREIGN KEY (agentid2) REFERENCES agents(agentid);


--
-- Name: GAMES_noiseid1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY games
    ADD CONSTRAINT "GAMES_noiseid1_fkey" FOREIGN KEY (noiseid1) REFERENCES noise(noiseid);


--
-- Name: GAMES_noiseid2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY games
    ADD CONSTRAINT "GAMES_noiseid2_fkey" FOREIGN KEY (noiseid2) REFERENCES noise(noiseid);


--
-- Name: GAMES_startState_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY games
    ADD CONSTRAINT "GAMES_startState_fkey" FOREIGN KEY (start_state) REFERENCES states(stateid);


--
-- Name: MATCHES_agentid1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY matches
    ADD CONSTRAINT "MATCHES_agentid1_fkey" FOREIGN KEY (agentid1) REFERENCES agents(agentid);


--
-- Name: MATCHES_agentid2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY matches
    ADD CONSTRAINT "MATCHES_agentid2_fkey" FOREIGN KEY (agentid2) REFERENCES agents(agentid);


--
-- Name: MATCHES_noiseid1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY matches
    ADD CONSTRAINT "MATCHES_noiseid1_fkey" FOREIGN KEY (noiseid1) REFERENCES noise(noiseid);


--
-- Name: MATCHES_noiseid2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY matches
    ADD CONSTRAINT "MATCHES_noiseid2_fkey" FOREIGN KEY (noiseid2) REFERENCES noise(noiseid);


--
-- Name: MATCHES_noisemetaid1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY matches
    ADD CONSTRAINT "MATCHES_noisemetaid1_fkey" FOREIGN KEY (noisemetaid1) REFERENCES noisemeta(noisemetaid);


--
-- Name: MATCHES_noisemetaid2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY matches
    ADD CONSTRAINT "MATCHES_noisemetaid2_fkey" FOREIGN KEY (noisemetaid2) REFERENCES noisemeta(noisemetaid);


--
-- Name: NOISE_basenoiseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY noise
    ADD CONSTRAINT "NOISE_basenoiseid_fkey" FOREIGN KEY (basenoiseid) REFERENCES noise(noiseid);


--
-- Name: NOISE_noisemetaid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY noise
    ADD CONSTRAINT "NOISE_noisemetaid_fkey" FOREIGN KEY (noisemetaid) REFERENCES noisemeta(noisemetaid);


--
-- Name: PENDINGSHOTS_agentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pendingshots
    ADD CONSTRAINT "PENDINGSHOTS_agentid_fkey" FOREIGN KEY (agentid) REFERENCES agents(agentid);


--
-- Name: PENDINGSHOTS_stateid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pendingshots
    ADD CONSTRAINT "PENDINGSHOTS_stateid_fkey" FOREIGN KEY (stateid) REFERENCES states(stateid);


--
-- Name: SHOTS_agentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY shots
    ADD CONSTRAINT "SHOTS_agentid_fkey" FOREIGN KEY (agentid) REFERENCES agents(agentid);


--
-- Name: SHOTS_ball_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY shots
    ADD CONSTRAINT "SHOTS_ball_fkey" FOREIGN KEY (ball) REFERENCES balls(ball);


--
-- Name: SHOTS_nextState_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY shots
    ADD CONSTRAINT "SHOTS_nextState_fkey" FOREIGN KEY (next_state) REFERENCES states(stateid);


--
-- Name: SHOTS_prevState_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY shots
    ADD CONSTRAINT "SHOTS_prevState_fkey" FOREIGN KEY (prev_state) REFERENCES states(stateid);


--
-- Name: TBLSTATES_ball_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tablestates
    ADD CONSTRAINT "TBLSTATES_ball_fkey" FOREIGN KEY (ball) REFERENCES balls(ball);


--
-- Name: agents_owner_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY agents
    ADD CONSTRAINT agents_owner_fkey FOREIGN KEY (owner) REFERENCES users(userid);


--
-- Name: cache_use_matchid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cache_use
    ADD CONSTRAINT cache_use_matchid_fkey FOREIGN KEY (matchid) REFERENCES matches(matchid);


--
-- Name: cache_use_stateid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cache_use
    ADD CONSTRAINT cache_use_stateid_fkey FOREIGN KEY (stateid) REFERENCES state_cache(stateid);


--
-- Name: debug_shotid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY debug
    ADD CONSTRAINT debug_shotid_fkey FOREIGN KEY (shotid) REFERENCES shots(shotid) ON DELETE CASCADE;


--
-- Name: games_end_reason_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY games
    ADD CONSTRAINT games_end_reason_fkey FOREIGN KEY (end_reason) REFERENCES end_reasons(end_reason);


--
-- Name: games_gametype_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY games
    ADD CONSTRAINT games_gametype_fkey FOREIGN KEY (gametype) REFERENCES gametypes(gametype);


--
-- Name: games_matchid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY games
    ADD CONSTRAINT games_matchid_fkey FOREIGN KEY (matchid) REFERENCES matches(matchid) ON DELETE CASCADE;


--
-- Name: matches_gametype_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY matches
    ADD CONSTRAINT matches_gametype_fkey FOREIGN KEY (gametype) REFERENCES gametypes(gametype);


--
-- Name: matches_owner_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY matches
    ADD CONSTRAINT matches_owner_fkey FOREIGN KEY (owner) REFERENCES users(userid);


--
-- Name: matches_rules_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY matches
    ADD CONSTRAINT matches_rules_fkey FOREIGN KEY (rules) REFERENCES rules(rulesid);


--
-- Name: matches_tournamentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY matches
    ADD CONSTRAINT matches_tournamentid_fkey FOREIGN KEY (tournamentid) REFERENCES tournaments(tournamentid);


--
-- Name: noise_owner_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY noise
    ADD CONSTRAINT noise_owner_fkey FOREIGN KEY (owner) REFERENCES users(userid);


--
-- Name: pendingshots_gameid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pendingshots
    ADD CONSTRAINT pendingshots_gameid_fkey FOREIGN KEY (gameid) REFERENCES games(gameid) ON DELETE CASCADE;


--
-- Name: shots_decision_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY shots
    ADD CONSTRAINT shots_decision_fkey FOREIGN KEY (decision) REFERENCES decisions(decision);


--
-- Name: shots_gameid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY shots
    ADD CONSTRAINT shots_gameid_fkey FOREIGN KEY (gameid) REFERENCES games(gameid) ON DELETE CASCADE;


--
-- Name: shots_pocket_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY shots
    ADD CONSTRAINT shots_pocket_fkey FOREIGN KEY (pocket) REFERENCES pockets(pocket);


--
-- Name: state_cache_agentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY state_cache
    ADD CONSTRAINT state_cache_agentid_fkey FOREIGN KEY (agentid) REFERENCES agents(agentid);


--
-- Name: state_cache_noiseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY state_cache
    ADD CONSTRAINT state_cache_noiseid_fkey FOREIGN KEY (noiseid) REFERENCES noise(noiseid);


--
-- Name: state_cache_stateid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY state_cache
    ADD CONSTRAINT state_cache_stateid_fkey FOREIGN KEY (stateid) REFERENCES states(stateid);


--
-- Name: states_gametype_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY states
    ADD CONSTRAINT states_gametype_fkey FOREIGN KEY (gametype) REFERENCES gametypes(gametype);


--
-- Name: states_turntype_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY states
    ADD CONSTRAINT states_turntype_fkey FOREIGN KEY (turntype) REFERENCES turntypes(turntype);


--
-- Name: tablestates_stateid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tablestates
    ADD CONSTRAINT tablestates_stateid_fkey FOREIGN KEY (stateid) REFERENCES states(stateid) ON DELETE CASCADE;


--
-- Name: tablestates_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tablestates
    ADD CONSTRAINT tablestates_status_fkey FOREIGN KEY (status) REFERENCES ballstates(status);


--
-- Name: tournament_agents_agentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tournament_agents
    ADD CONSTRAINT tournament_agents_agentid_fkey FOREIGN KEY (agentid) REFERENCES agents(agentid) ON DELETE CASCADE;


--
-- Name: tournament_agents_noiseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tournament_agents
    ADD CONSTRAINT tournament_agents_noiseid_fkey FOREIGN KEY (noiseid) REFERENCES noise(noiseid);


--
-- Name: tournament_agents_noisemetaid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tournament_agents
    ADD CONSTRAINT tournament_agents_noisemetaid_fkey FOREIGN KEY (noisemetaid) REFERENCES noisemeta(noisemetaid);


--
-- Name: tournament_agents_tournamentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tournament_agents
    ADD CONSTRAINT tournament_agents_tournamentid_fkey FOREIGN KEY (tournamentid) REFERENCES tournaments(tournamentid) ON DELETE CASCADE;


--
-- Name: tournaments_gametype_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tournaments
    ADD CONSTRAINT tournaments_gametype_fkey FOREIGN KEY (gametype) REFERENCES gametypes(gametype);


--
-- Name: tournaments_master_agent_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tournaments
    ADD CONSTRAINT tournaments_master_agent_fkey FOREIGN KEY (master_agent) REFERENCES agents(agentid);


--
-- Name: tournaments_owner_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tournaments
    ADD CONSTRAINT tournaments_owner_fkey FOREIGN KEY (owner) REFERENCES users(userid);


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

--
-- Name: ballstates_stateid_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('ballstates_stateid_seq', 13, true);


--
-- Name: decisions_decision_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('decisions_decision_seq', 3, true);


--
-- Name: end_reasons_end_reason_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('end_reasons_end_reason_seq', 8, true);


--
-- Name: gametypes_gametype_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('gametypes_gametype_seq', 4, true);


--
-- Name: noisetypes_noisetype_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('noisetypes_noisetype_seq', 2, true);


--
-- Name: pockets_pocket_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('pockets_pocket_seq', 6, true);


--
-- Name: rules_rulesid_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('rules_rulesid_seq', 3, true);


--
-- Name: turntypes_turntype_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('turntypes_turntype_seq', 7, true);


--
-- Data for Name: balls; Type: TABLE DATA; Schema: public; Owner: -
--

COPY balls (ball, solid) FROM stdin;
1	t
2	t
3	t
4	t
5	t
6	t
7	t
8	\N
0	\N
9	f
10	f
11	f
12	f
13	f
14	f
15	f
\.


--
-- Data for Name: ballstates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY ballstates (status, on_table, in_game, description, moving) FROM stdin;
0	f	f	Not in Play	f
1	t	t	Stationary	f
5	f	t	Pocketed SW	f
6	f	t	Pocketed W	f
7	f	t	Pocketed NW	f
8	f	t	Pocketed NE	f
9	f	t	Pocketed E	f
10	f	t	Pocketed SE	f
11	t	t	Sliding Spinning	t
12	t	t	Rolling Spinning	t
13	f	t	Unknown State	f
2	t	t	Spinning	t
3	t	t	Sliding	t
4	t	t	Rolling	t
\.


--
-- Data for Name: decisions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY decisions (decision, description) FROM stdin;
0	No Decision
1	Keep Shooting
2	Rerack
3	Rerack, let opponent shoot
4	Concede
\.


--
-- Data for Name: end_reasons; Type: TABLE DATA; Schema: public; Owner: -
--

COPY end_reasons (end_reason, description, use_in_scoring, use_in_analysis) FROM stdin;
1	Normal win	t	t
2	Normal loss	t	t
3	Timeout	t	t
4	Crashed client	t	f
5	Crashed server	f	f
6	User Abort	f	f
7	Lost turn (statebank)	f	t
8	Conceded	t	f
\.


--
-- Data for Name: gametypes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY gametypes (gametype, description) FROM stdin;
1	8 ball
2	9 ball
3	snooker
4	one pocket
\.


--
-- Data for Name: noisetypes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY noisetypes (noisetype, description) FROM stdin;
1	No Noise
2	Gaussian Noise
\.


--
-- Data for Name: pockets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY pockets (pocket, description) FROM stdin;
0	SW
1	W
2	NW
3	NE
4	E
5	SE
6	Unknown
\.


--
-- Data for Name: rules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY rules (rulesid, description) FROM stdin;
1	Full Game
2	Win off break test
3	Continuation Game
\.


--
-- Data for Name: turntypes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY turntypes (turntype, description, terminal, posreqd, decisionallowed, shotreqd) FROM stdin;
0	Normal Shot	f	f	f	t
1	Ball in Hand	f	t	f	t
2	Ball in Hand behind line	f	t	f	t
4	Break shot	f	t	f	t
3	Reserved	t	f	f	f
5	Win	t	f	f	f
6	EightBall Foul on Break	f	f	t	f
7	EightBall pocketed on break	f	f	t	f
\.


--
-- PostgreSQL database dump complete
--


INSERT INTO noisemeta (noisemetaid, metatype) VALUES (0,0);
INSERT INTO users (username,passwd,is_admin) VALUES ('admin','admin','t');
INSERT INTO noise (noisetype, n_a, n_b, n_theta, n_phi, n_v, n_factor) VALUES (2,0.5,0.5,0.1,0.125,0.075,1);
                