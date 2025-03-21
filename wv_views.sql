DROP VIEW IF EXISTS ALL_PLAYERS;
DROP VIEW IF EXISTS ALL_PLAYERS_ELAPSED_GAME;
DROP VIEW IF EXISTS ALL_PLAYERS_ELAPSED_TOUR;
DROP VIEW IF EXISTS ALL_PLAYERS_STATS;
GO

-- Vue pour calculer le nombre de parties et de tours joués par chaque joueur
CREATE VIEW ALL_PLAYERS AS
SELECT
    p.pseudo AS nom_du_joueur,
    COUNT(DISTINCT pip.id_party) AS nombre_de_parties,
    COUNT(ppp.id_turn) AS nombre_de_tours,
    MIN(ppp.start_time) AS premiere_participation,
    MAX(ppp.end_time) AS derniere_action
FROM players p
JOIN players_in_parties pip ON p.id_player = pip.id_player
JOIN parties pa ON pip.id_party = pa.id_party
LEFT JOIN players_play ppp ON p.id_player = ppp.id_player
GROUP BY p.pseudo
HAVING COUNT(DISTINCT pip.id_party) > 0;
GO

-- Vue pour calculer le temps passé par chaque joueur dans chaque partie
CREATE VIEW ALL_PLAYERS_ELAPSED_GAME AS
SELECT
    p.pseudo AS nom_du_joueur,                                          
    pa.title_party AS nom_de_la_partie,                                
    COUNT(DISTINCT pip2.id_player) AS nombre_de_participants,          
    MIN(pp.start_time) AS premiere_action_du_joueur,                    
    MAX(pp.end_time) AS derniere_action_du_joueur,                      
    DATEDIFF(SECOND, MIN(pp.start_time), MAX(pp.end_time)) AS nb_secondes_passees 
FROM players p
JOIN players_in_parties pip ON p.id_player = pip.id_player              
JOIN parties pa ON pip.id_party = pa.id_party                           
JOIN players_play pp ON p.id_player = pp.id_player                     
JOIN turns t ON pp.id_turn = t.id_turn AND t.id_party = pa.id_party     
JOIN players_in_parties pip2 ON pip2.id_party = pa.id_party            
GROUP BY p.pseudo, pa.title_party;                                     
GO

CREATE VIEW ALL_PLAYERS_ELAPSED_TOUR AS
SELECT
    p.pseudo AS nom_du_joueur,
    pa.title_party AS nom_de_la_partie,
    ppp.id_turn AS numero_du_tour,
    ppp.start_time AS debut_du_tour,
    ppp.end_time AS prise_decision,
    DATEDIFF(SECOND, ppp.start_time, ppp.end_time) AS temps_secondes
FROM players p
JOIN players_play ppp ON p.id_player = ppp.id_player
JOIN turns t ON ppp.id_turn = t.id_turn
JOIN parties pa ON t.id_party = pa.id_party
WHERE ppp.start_time IS NOT NULL 
AND ppp.end_time IS NOT NULL
GO

CREATE VIEW ALL_PLAYERS_STATS AS
WITH ToursParPartie AS (
    SELECT 
        t.id_party,
        COUNT(DISTINCT t.id_turn) AS total_tours
    FROM turns t
    GROUP BY t.id_party
),
ToursParJoueur AS (
    SELECT 
        p.id_player,
        t.id_party,
        COUNT(DISTINCT t.id_turn) AS tours_joues
    FROM players p
    JOIN players_play pp ON p.id_player = pp.id_player
    JOIN turns t ON pp.id_turn = t.id_turn
    GROUP BY p.id_player, t.id_party
),
VainqueursPartie AS (
    SELECT 
        pip.id_party,
        CASE 
            WHEN COUNT(CASE WHEN r.role_type = 'loup' AND pip.is_alive = 1 THEN 1 END) > 0 THEN 'loup'
            ELSE 'villageois'
        END AS winner
    FROM players_in_parties pip
    JOIN roles r ON pip.id_role = r.id_role
    GROUP BY pip.id_party
)
SELECT
    p.pseudo AS nom_du_joueur,
    CASE 
        WHEN r.role_type = 'loup' THEN 'Loup'
        ELSE 'Villageois'
    END AS role,
    pa.title_party AS nom_de_la_partie,
    tpj.tours_joues AS nb_tours_joues,
    tpp.total_tours AS nb_total_tours,
    CASE 
        WHEN r.role_type = vp.winner THEN 'Vainqueur'
        ELSE 'Perdant'
    END AS resultat,
    AVG(DATEDIFF(SECOND, pp.start_time, pp.end_time)) AS temps_moyen_decision
FROM players p
JOIN players_in_parties pip ON p.id_player = pip.id_player
JOIN roles r ON pip.id_role = r.id_role
JOIN parties pa ON pip.id_party = pa.id_party
JOIN players_play pp ON p.id_player = pp.id_player
JOIN turns t ON pp.id_turn = t.id_turn
JOIN ToursParPartie tpp ON pa.id_party = tpp.id_party
JOIN ToursParJoueur tpj ON p.id_player = tpj.id_player AND pa.id_party = tpj.id_party
JOIN VainqueursPartie vp ON pa.id_party = vp.id_party
WHERE pp.start_time IS NOT NULL 
AND pp.end_time IS NOT NULL
GROUP BY 
    p.pseudo,
    r.role_type,
    pa.title_party,
    tpj.tours_joues,
    tpp.total_tours,
    vp.winner;
GO