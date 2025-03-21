DROP FUNCTION IF EXISTS random_position;
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