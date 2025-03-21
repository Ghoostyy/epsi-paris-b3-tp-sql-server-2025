CREATE TRIGGER dbo.TR_TurnFinished
ON dbo.turns
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @tourID INT, @partyID INT;

    -- Identify a turn where end_time changed from NULL to a non-NULL value
    SELECT TOP 1 
           @tourID = i.id_turn, 
           @partyID = i.id_party
    FROM inserted i
    JOIN deleted d ON i.id_turn = d.id_turn
    WHERE d.end_time IS NULL AND i.end_time IS NOT NULL;

    IF @tourID IS NOT NULL
    BEGIN
         EXEC dbo.COMPLETE_TOUR @TOUR_ID = @tourID, @PARTY_ID = @partyID;
    END
END;
GO

--===================================================
-- Trigger: TR_PlayerInserted
-- Purpose: When a new player is inserted, convert the player's pseudo
--          to lowercase.
--===================================================
CREATE TRIGGER dbo.TR_PlayerInserted
ON dbo.players
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Simply call the USERNAME_TO_LOWER procedure, which updates all players.
    EXEC dbo.USERNAME_TO_LOWER;
END;
GO