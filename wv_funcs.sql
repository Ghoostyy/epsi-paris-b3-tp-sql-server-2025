DROP FUNCTION IF EXISTS random_position;
DROP FUNCTION IF EXISTS get_the_winner;
GO
 
-- Fonction pour générer une position aléatoire qui n'a pas encore été utilisée pour une partie donnée
CREATE OR ALTER FUNCTION random_position(
    @nb_rows INT,           
    @nb_cols INT,           
    @party_id INT           
)
RETURNS TABLE                
AS
RETURN (
    WITH AllPositions AS (
        -- Génère toutes les positions possibles sur le plateau (combinaisons lignes/colonnes)
        SELECT 
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS position_id,
            r.row_num AS row_pos,
            c.col_num AS col_pos
        FROM 
            (SELECT TOP (@nb_rows) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num 
             FROM master.dbo.spt_values) r
        CROSS JOIN 
            (SELECT TOP (@nb_cols) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS col_num 
             FROM master.dbo.spt_values) c
    ),
    UsedPositions AS (
        -- Récupère toutes les positions déjà utilisées dans cette partie
        SELECT DISTINCT 
            CAST(CAST(origin_position_row AS VARCHAR(10)) AS INT) AS row_pos,
            CAST(CAST(origin_position_col AS VARCHAR(10)) AS INT) AS col_pos
        FROM 
            players_play pp
        JOIN 
            turns t ON pp.id_turn = t.id_turn
        WHERE 
            t.id_party = @party_id
            AND origin_position_row IS NOT NULL
            AND origin_position_col IS NOT NULL
        
        UNION
        
        SELECT DISTINCT 
            CAST(CAST(target_position_row AS VARCHAR(10)) AS INT) AS row_pos,
            CAST(CAST(target_position_col AS VARCHAR(10)) AS INT) AS col_pos
        FROM 
            players_play pp
        JOIN 
            turns t ON pp.id_turn = t.id_turn
        WHERE 
            t.id_party = @party_id
            AND target_position_row IS NOT NULL
            AND target_position_col IS NOT NULL
    ),
    AvailablePositions AS (
        SELECT 
            a.row_pos,
            a.col_pos,
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS position_number
        FROM 
            AllPositions a
        WHERE 
            NOT EXISTS (
                SELECT 1 
                FROM UsedPositions u 
                WHERE u.row_pos = a.row_pos AND u.col_pos = a.col_pos
            )
    )
    -- Sélectionne une position aléatoire parmi celles disponibles
    SELECT TOP 1
        row_pos,
        col_pos
    FROM 
        AvailablePositions
    WHERE 
        position_number = (ABS(CAST(CAST(CAST(GETDATE() AS BIGINT) AS BINARY(8)) AS BIGINT)) % (SELECT COUNT(*) FROM AvailablePositions)) + 1
);
GO


CREATE OR ALTER FUNCTION get_the_winner(@partyid INT)
RETURNS TABLE
AS
RETURN
WITH ToursParPartie AS (
    SELECT 
        t.id_party,
        COUNT(DISTINCT t.id_turn) AS total_tours
    FROM turns t
    WHERE t.id_party = @partyid
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
    WHERE t.id_party = @partyid
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
    WHERE pip.id_party = @partyid
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
WHERE pa.id_party = @partyid
AND pp.start_time IS NOT NULL 
AND pp.end_time IS NOT NULL
AND r.role_type = vp.winner
GROUP BY 
    p.pseudo,
    r.role_type,
    pa.title_party,
    tpj.tours_joues,
    tpp.total_tours;
GO