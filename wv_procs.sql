DROP PROCEDURE IF EXISTS SEED_DATA;
DROP PROCEDURE IF EXISTS COMPLETE_TOUR;
DROP PROCEDURE IF EXISTS USERNAME_TO_LOWER;
GO
 
-- Procédure pour créer les tours de jeu
CREATE OR ALTER PROCEDURE SEED_DATA
    @NB_PLAYERS INT,
    @PARTY_ID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @max_turns INT = @NB_PLAYERS * 2; -- Nombre maximum de tours possibles
    
    -- Génère les tours
    WITH Numbers AS (
        SELECT TOP (@max_turns) 
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS turn_number
        FROM master.dbo.spt_values
    )
    INSERT INTO turns (id_turn, id_party, start_time, end_time)
    SELECT 
        turn_number,
        @PARTY_ID,
        NULL, -- start_time sera mis à jour quand le tour commencera
        NULL  -- end_time sera mis à jour quand le tour se terminera
    FROM Numbers;
END;
GO
 
-- Procédure pour compléter un tour en appliquant les déplacements
CREATE OR ALTER PROCEDURE COMPLETE_TOUR
    @TOUR_ID INT,
    @PARTY_ID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Vérifie que le tour existe et appartient à la partie
        IF NOT EXISTS (
            SELECT 1 
            FROM turns 
            WHERE id_turn = @TOUR_ID AND id_party = @PARTY_ID
        )
        BEGIN
            RAISERROR('Tour ou partie invalide', 16, 1);
        END;
        
        -- Vérifie que toutes les actions du tour sont complétées
        DECLARE @nb_players INT;
        DECLARE @nb_actions INT;
        
        SELECT @nb_players = COUNT(DISTINCT id_player)
        FROM players_in_parties
        WHERE id_party = @PARTY_ID;
        
        SELECT @nb_actions = COUNT(*)
        FROM players_play
        WHERE id_turn = @TOUR_ID;
        
        IF @nb_actions < @nb_players
        BEGIN
            RAISERROR('Toutes les actions du tour ne sont pas complétées', 16, 1);
        END;
        
        -- Met à jour les positions des joueurs
        UPDATE pp
        SET 
            origin_position_row = target_position_row,
            origin_position_col = target_position_col
        FROM players_play pp
        WHERE pp.id_turn = @TOUR_ID;
        
        -- Met à jour le temps de fin du tour
        UPDATE turns
        SET end_time = GETDATE()
        WHERE id_turn = @TOUR_ID;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        RAISERROR('Une erreur est survenue lors de la complétion du tour', 16, 1);
    END CATCH;
END;
GO
 
-- Procédure pour mettre les noms des joueurs en minuscules
CREATE OR ALTER PROCEDURE USERNAME_TO_LOWER
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Met à jour les pseudos en minuscules
        UPDATE players
        SET pseudo = LOWER(pseudo)
        WHERE pseudo != LOWER(pseudo);
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        RAISERROR('Une erreur est survenue lors de la mise à jour des noms', 16, 1);
    END CATCH;
END;
GO