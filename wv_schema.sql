drop table if exists parties;
drop table if exists roles;
drop table if exists players;
drop table if exists players_in_parties;
drop table if exists turns;
drop table if exists players_play;

create table parties (
    id_party int,
    title_party text -- title_party VARCHAR(50) NOT NULL DEFAULT 'undefined' --> in wv_index.sql
);

create table roles (
    id_role int,
    description_role text
    -- roles_type VARCHAR(50) NOT NULL DEFAULT 'undefined' --> in wv_index.sql
);

create table players (
    id_player int,
    pseudo text -- pseudo VARCHAR(50) NOT NULL --> in wv_index.sql
);

create table players_in_parties (
    id_party int,
    id_player int,
    id_role int,
    is_alive text -- is_alive BIT NOT NULL DEFAULT 1; --> in wv_index.sql
);

create table turns (
    id_turn int,
    id_party int,
    start_time datetime,
    end_time datetime
);

create table players_play (
    id_player int,
    id_turn int,
    start_time datetime,
    end_time datetime,
    action varchar(10),
    origin_position_col text,
    origin_position_row text,
    target_position_col text,
    target_position_row text
);