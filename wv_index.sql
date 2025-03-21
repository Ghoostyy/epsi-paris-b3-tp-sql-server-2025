-- add roles type in roles
ALTER TABLE roles 
ADD role_type VARCHAR(50) NOT NULL DEFAULT 'undefined';

-- modify is_alive to a bool value in players_in_parties table
ALTER TABLE players_in_parties
DROP COLUMN is_alive;

ALTER TABLE players_in_parties
ADD is_alive BIT NOT NULL DEFAULT 1;

-- modify pseudo to varchar(50) in players table for view compatibility
ALTER TABLE players
DROP COLUMN pseudo;

ALTER TABLE players
ADD pseudo VARCHAR(50) NOT NULL;

-- modify title_party to varchar(50) in parties table for view compatibility
ALTER TABLE parties
DROP COLUMN title_party;

ALTER TABLE parties
ADD title_party VARCHAR(50) NOT NULL;