/* =============================================================================
   Flyway sandbox: create the sandbox databases from your own database (SQL Server)

   Your AI assistant fills in the values below. Then open this file in SSMS (or
   Azure Data Studio), connect to the sandbox server and run the whole script.

   Start from EITHER
     @SourceDatabase    your database, already on this server
     @SourceBackupFile  a backup (.bak) of your database, in a folder on this
                        server. A file name alone means the server's default
                        backup folder. It is restored as a temporary database,
                        its structure is copied, then it is dropped.

   What it does:
     1. Makes a dataless backup of your database: a copy of its structure
        (tables, views, procedures and so on; no data, no statistics) made with
        DBCC CLONEDATABASE and backed up to @BaselineBackupFile. Flyway uses
        this backup as its baseline. Background: https://documentation.red-gate.com/flyway/learn-more-about-flyway/how-to-articles/use-a-sql-server-backup-to-baseline-a-database
     2. Restores that baseline as <Prefix>_Dev, <Prefix>_Test and <Prefix>_Prod,
        so all three start identical.
     3. Creates empty <Prefix>_Shadow, <Prefix>_Check and <Prefix>_Build for
        Flyway's own use.
     4. Shows the baseline backup's full path. Give it to your assistant.

   Your database and your backup file are only read. Databases that already
   exist are left alone, so it's safe to run again.
   Needs sysadmin on this server, and SQL Server 2016 SP2 or later.
   ========================================================================== */
SET NOCOUNT ON;

DECLARE @SourceDatabase     sysname       = N'northwind_dev';  -- your database on this server, OR leave empty and use the next line
DECLARE @SourceBackupFile   nvarchar(400) = N'';  -- the exact file name, e.g. N'AdventureWorks2016.bak' (in the default backup folder) or N'D:\Backups\Sales.bak', as this server sees it
DECLARE @Prefix             sysname       = N'NorthwindFW';                    -- 'Sales' gives Sales_Dev, Sales_Test ...
DECLARE @BaselineBackupFile nvarchar(400) = N'NorthwindFW_FlywayBaseline.bak'; -- a file name alone goes in the server's default backup folder

DECLARE @TempSource   sysname       = @Prefix + N'_FlywayTempSource',
        @Clone        sysname       = @Prefix + N'_FlywayStructureCopy',
        @DataPath     nvarchar(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(260)),
        @LogPath      nvarchar(260) = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS nvarchar(260)),
        @Started      datetime      = DATEADD(SECOND, -5, GETDATE()),
        @BaselinePath nvarchar(400),
        @Sql          nvarchar(max),
        @Move         nvarchar(max),
        @Similar      nvarchar(max) = N'',
        @Msg          nvarchar(2048),
        @Db           sysname,
        @FromBaseline bit,
        @i            int           = 1,
        @Try          int           = 0,
        @ReadOk       bit           = 0;
DECLARE @Files   TABLE (LogicalName sysname, FileType tinyint, FileId int);
DECLARE @Targets TABLE (Ord int, Name sysname, FromBaseline bit);

SELECT @SourceDatabase = ISNULL(@SourceDatabase, N''), @SourceBackupFile = ISNULL(@SourceBackupFile, N'');

IF @Prefix LIKE N'<%' OR @BaselineBackupFile LIKE N'<%'
    THROW 50000, N'Fill in the values at the top of the script first.', 1;
IF (CASE WHEN @SourceDatabase = N'' THEN 0 ELSE 1 END) + (CASE WHEN @SourceBackupFile = N'' THEN 0 ELSE 1 END) <> 1
    THROW 50001, N'Set either @SourceDatabase or @SourceBackupFile (one of them, not both).', 1;
IF @SourceDatabase <> N'' AND DB_ID(@SourceDatabase) IS NULL
BEGIN
    -- Suggest close matches: sample databases carry a year, such as AdventureWorks2022
    SELECT @Similar = @Similar + CASE WHEN @Similar = N'' THEN N'' ELSE N', ' END + name
    FROM sys.databases
    WHERE database_id > 4 AND name LIKE N'%' + @SourceDatabase + N'%' AND name NOT LIKE @Prefix + N'[_]%';
    SET @Msg = LEFT(N'@SourceDatabase was not found on this server. Use the exact name shown in Object Explorer'
             + CASE WHEN @Similar <> N'' THEN N'. Similar names here: ' + @Similar ELSE N', or use @SourceBackupFile instead' END
             + N'.', 2000);
    THROW 50002, @Msg, 1;
END;
IF ISNULL(IS_SRVROLEMEMBER('sysadmin'), 0) = 0
    THROW 50003, N'This script needs sysadmin, because DBCC CLONEDATABASE does. Use a server where you are an administrator (SQL Server Developer Edition on your own machine is ideal), or ask a DBA to run it.', 1;

/* 0. Starting from a backup file: restore it as a temporary database --------- */
IF @SourceBackupFile <> N''
BEGIN
    IF DB_ID(@TempSource) IS NOT NULL -- left over from an earlier run of this script
    BEGIN
        SET @Sql = N'ALTER DATABASE ' + QUOTENAME(@TempSource) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ' + QUOTENAME(@TempSource) + N';';
        EXEC (@Sql);
    END;

    -- Read the backup's file list. Newer SQL Server versions may return extra columns, so add spares and retry.
    DROP TABLE IF EXISTS #FileList;
    CREATE TABLE #FileList (
        LogicalName nvarchar(128) NULL, PhysicalName nvarchar(260) NULL, [Type] char(1) NULL, FileGroupName nvarchar(128) NULL,
        Size numeric(20,0) NULL, MaxSize numeric(20,0) NULL, FileId bigint NULL, CreateLSN numeric(25,0) NULL,
        DropLSN numeric(25,0) NULL, UniqueId uniqueidentifier NULL, ReadOnlyLSN numeric(25,0) NULL, ReadWriteLSN numeric(25,0) NULL,
        BackupSizeInBytes bigint NULL, SourceBlockSize int NULL, FileGroupId int NULL, LogGroupGUID uniqueidentifier NULL,
        DifferentialBaseLSN numeric(25,0) NULL, DifferentialBaseGUID uniqueidentifier NULL, IsReadOnly bit NULL, IsPresent bit NULL,
        TDEThumbprint varbinary(32) NULL, SnapshotUrl nvarchar(360) NULL);

    WHILE @ReadOk = 0 AND @Try < 4
    BEGIN
        BEGIN TRY
            INSERT #FileList EXEC sp_executesql N'RESTORE FILELISTONLY FROM DISK = @p;', N'@p nvarchar(400)', @p = @SourceBackupFile;
            SET @ReadOk = 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() <> 213
            BEGIN
                PRINT N'Stopped: SQL Server could not read @SourceBackupFile (the error below shows the full path it tried).';
                PRINT N'- Operating system error 2: no file by that name there. Check the exact file name: sample backups carry a year, such as AdventureWorks2022.bak.';
                PRINT N'- Operating system error 5: SQL Server isn''t allowed to read that folder. Your Downloads folder is the usual culprit.';
                PRINT N'Either way: move the file into the server''s default backup folder and use the file name alone.';
                THROW;
            END;
            SET @Try += 1;
            SET @Sql = N'ALTER TABLE #FileList ADD Spare' + CAST(@Try AS nvarchar(10)) + N' nvarchar(4000) NULL;';
            EXEC (@Sql);
        END CATCH;
    END;
    IF @ReadOk = 0
    BEGIN
        PRINT N'Stopped: could not read the file list of @SourceBackupFile. Restore it once with SSMS (Restore Database), then use @SourceDatabase instead.';
        RETURN;
    END;

    SET @Move = N'';
    SELECT @Move = @Move + N', MOVE N''' + REPLACE(LogicalName, N'''', N'''''') + N''' TO N'''
         + REPLACE(CASE [Type] WHEN 'L' THEN @LogPath ELSE @DataPath END
                   + @TempSource + N'_' + CAST(FileId AS nvarchar(20))
                   + CASE [Type] WHEN 'D' THEN CASE WHEN FileId = 1 THEN N'.mdf' ELSE N'.ndf' END
                                 WHEN 'L' THEN N'.ldf' ELSE N'' END,
                   N'''', N'''''') + N''''
    FROM #FileList;

    PRINT N'Restoring your backup as a temporary database (a big backup takes a while)...';
    SET @Sql = N'RESTORE DATABASE ' + QUOTENAME(@TempSource) + N' FROM DISK = @p WITH RECOVERY' + @Move + N';';
    EXEC sp_executesql @Sql, N'@p nvarchar(400)', @p = @SourceBackupFile;
    IF ISNULL(CAST(DATABASEPROPERTYEX(@TempSource, 'Status') AS nvarchar(60)), N'') <> N'ONLINE'
    BEGIN
        PRINT N'Stopped: your backup could not be restored. See the messages above.';
        RETURN;
    END;
    SET @SourceDatabase = @TempSource;
END;

/* 1. Dataless backup: copy the structure, back it up as the baseline -------- */
IF DB_ID(@Clone) IS NOT NULL -- left over from an earlier run
BEGIN
    SET @Sql = N'ALTER DATABASE ' + QUOTENAME(@Clone) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ' + QUOTENAME(@Clone) + N';';
    EXEC (@Sql);
END;

PRINT N'Copying the structure of ' + @SourceDatabase + N' (no data)...';
SET @Sql = N'DBCC CLONEDATABASE (' + QUOTENAME(@SourceDatabase) + N', ' + QUOTENAME(@Clone)
         + N') WITH VERIFY_CLONEDB, NO_STATISTICS, NO_QUERYSTORE;';
EXEC (@Sql);

-- The temporary copy of your backup held data. It's no longer needed.
IF @SourceDatabase = @TempSource AND DB_ID(@TempSource) IS NOT NULL
BEGIN
    SET @Sql = N'ALTER DATABASE ' + QUOTENAME(@TempSource) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ' + QUOTENAME(@TempSource) + N';';
    EXEC (@Sql);
END;

IF DB_ID(@Clone) IS NULL
BEGIN
    PRINT N'Stopped: the structure copy failed. See the messages above.';
    RETURN;
END;

-- The copy is read-only. Make it writable so the databases restored from it are too.
SET @Sql = N'ALTER DATABASE ' + QUOTENAME(@Clone) + N' SET READ_WRITE WITH ROLLBACK IMMEDIATE;';
EXEC (@Sql);

INSERT @Files (LogicalName, FileType, FileId)
SELECT name, type, file_id FROM sys.master_files WHERE database_id = DB_ID(@Clone);

PRINT N'Backing up the structure copy as the baseline (a dataless backup)...';
BACKUP DATABASE @Clone TO DISK = @BaselineBackupFile WITH FORMAT, INIT;

SELECT TOP (1) @BaselinePath = mf.physical_device_name
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS mf ON mf.media_set_id = bs.media_set_id
WHERE bs.database_name = @Clone AND bs.backup_start_date >= @Started
ORDER BY bs.backup_finish_date DESC;

SET @Sql = N'DROP DATABASE ' + QUOTENAME(@Clone) + N';';
EXEC (@Sql);

IF @BaselinePath IS NULL
BEGIN
    PRINT N'Stopped: the baseline backup failed. See the messages above.';
    PRINT N'"Cannot open backup device" means SQL Server cannot write to that folder: use a file name alone, or a folder the SQL Server service account can write to.';
    RETURN;
END;

/* 2 and 3. Dev, Test and Prod from the baseline; empty Shadow, Check and Build */
INSERT @Targets (Ord, Name, FromBaseline) VALUES
    (1, @Prefix + N'_Dev', 1), (2, @Prefix + N'_Test', 1), (3, @Prefix + N'_Prod', 1),
    (4, @Prefix + N'_Shadow', 0), (5, @Prefix + N'_Check', 0), (6, @Prefix + N'_Build', 0);

WHILE @i <= 6
BEGIN
    SELECT @Db = Name, @FromBaseline = FromBaseline FROM @Targets WHERE Ord = @i;

    IF DB_ID(@Db) IS NOT NULL
    BEGIN
        PRINT @Db + N' already exists, left as it is.';
    END
    ELSE IF @FromBaseline = 1
    BEGIN
        -- Give each file a new name in the server's default folders
        SET @Move = N'';
        SELECT @Move = @Move + N', MOVE N''' + REPLACE(LogicalName, N'''', N'''''') + N''' TO N'''
             + REPLACE(CASE FileType WHEN 1 THEN @LogPath ELSE @DataPath END
                       + @Db + N'_' + CAST(FileId AS nvarchar(10))
                       + CASE FileType WHEN 0 THEN CASE FileId WHEN 1 THEN N'.mdf' ELSE N'.ndf' END
                                       WHEN 1 THEN N'.ldf' ELSE N'' END,
                       N'''', N'''''') + N''''
        FROM @Files;

        SET @Sql = N'RESTORE DATABASE ' + QUOTENAME(@Db) + N' FROM DISK = @p WITH RECOVERY' + @Move + N';';
        EXEC sp_executesql @Sql, N'@p nvarchar(400)', @p = @BaselinePath;
        PRINT CASE WHEN ISNULL(CAST(DATABASEPROPERTYEX(@Db, 'Status') AS nvarchar(60)), N'') = N'ONLINE'
                   THEN N'Created ' + @Db + N' (structure only).'
                   ELSE N'Could not create ' + @Db + N'. See the messages above.' END;
    END
    ELSE
    BEGIN
        SET @Sql = N'CREATE DATABASE ' + QUOTENAME(@Db) + N';';
        EXEC (@Sql);
        PRINT N'Created empty ' + @Db + N'.';
    END;

    SET @i += 1;
END;

PRINT N'';
PRINT N'Done. Baseline backup file (dataless), for your AI assistant:';
PRINT @BaselinePath;
SELECT @BaselinePath AS [Baseline backup file (give this to your assistant)];
