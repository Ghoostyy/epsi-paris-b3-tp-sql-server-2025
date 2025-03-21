DROP FUNCTION IF EXISTS random_position;
DROP FUNCTION IF EXISTS get_the_winner;
GO
 
-- Fonction pour générer une position aléatoire qui n'a pas encore été utilisée pour une partie donnée
CREATE OR ALTER FUNCTION random_position(         
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
            (SELECT TOP (10) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num 
             FROM master.dbo.spt_values) r
        CROSS JOIN 
            (SELECT TOP (10) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS col_num 
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

-- Vue intermédiaire pour l'aléatoire
CREATE OR ALTER VIEW RandomValue AS
SELECT CAST(RAND() * 100 AS INT) AS random_val;
GO
-- Fonction pour déterminer le prochain rôle à affecter (loup ou villageois) en respectant les quotas
CREATE OR ALTER FUNCTION random_role(
    @party_id INT           -- ID de la partie
)
RETURNS INT                 -- Retourne l'ID du rôle (loup ou villageois)
AS
BEGIN
    DECLARE @wolf_role_id INT;
    DECLARE @villager_role_id INT;
    DECLARE @wolf_count INT;
    DECLARE @villager_count INT;
    DECLARE @total_players INT;
    DECLARE @result_role_id INT;
    DECLARE @random_value INT;
    
    -- Récupère les IDs des rôles pour loup et villageois
    SELECT @wolf_role_id = id_role FROM roles WHERE role_type = 'loup';
    SELECT @villager_role_id = id_role FROM roles WHERE role_type = 'villageois';
    
    -- Compte le nombre actuel de loups dans la partie
    SELECT @wolf_count = COUNT(*)
    FROM players_in_parties
    WHERE id_party = @party_id AND id_role = @wolf_role_id;
    
    -- Compte le nombre actuel de villageois dans la partie
    SELECT @villager_count = COUNT(*)
    FROM players_in_parties
    WHERE id_party = @party_id AND id_role = @villager_role_id;
    
    -- Calcule le nombre total de joueurs inscrits
    SET @total_players = @wolf_count + @villager_count;
    
    -- Obtenir une valeur aléatoire de la vue
    SELECT @random_value = random_val FROM RandomValue;
    
    -- Détermine le rôle à attribuer en fonction des quotas
    -- Règle : Maintenir environ 1/4 de loups et 3/4 de villageois
    IF @wolf_count < CEILING(@total_players * 0.25) AND (@wolf_count < @total_players / 3)
        SET @result_role_id = @wolf_role_id;
    ELSE
        SET @result_role_id = @villager_role_id;
    
    -- Pour ajouter un peu d'aléatoire quand les quotas sont respectés
    -- Si les proportions sont déjà bonnes, attribue aléatoirement un rôle avec 75% de chance d'être villageois
    IF (@wolf_count >= CEILING(@total_players * 0.25)) AND (@villager_count >= CEILING(@total_players * 0.75))
    BEGIN
        IF @random_value <= 25  -- 25% de chance d'être un loup
            SET @result_role_id = @wolf_role_id;
        ELSE
            SET @result_role_id = @villager_role_id;
    END
    
    RETURN @result_role_id;
END;