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