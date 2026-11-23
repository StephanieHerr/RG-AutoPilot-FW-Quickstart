-- ============================================================
-- Pizza ordering schema – SQL Server 2022
-- Uses [pizza] schema to avoid conflicts with existing dbo objects
-- Safe to run against an existing DB — all objects guarded
-- ============================================================

-- Create schema if it doesn't exist
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'pizza')
    EXEC('CREATE SCHEMA pizza');
GO

-- Accounts
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Accounts' AND schema_id = SCHEMA_ID('pizza'))
BEGIN
    CREATE TABLE pizza.Accounts
    (
        Id           INT            NOT NULL IDENTITY(1,1),
        Name         NVARCHAR(255)  NOT NULL,
        Email        NVARCHAR(255)  NOT NULL,
        PasswordHash NVARCHAR(255)  NOT NULL,
        CONSTRAINT PK_pizza_Accounts PRIMARY KEY CLUSTERED (Id)
    );

    CREATE INDEX IX_pizza_Accounts_Email
        ON pizza.Accounts (Email)
        INCLUDE (Id, PasswordHash);
END;
GO

-- Categories
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Categories' AND schema_id = SCHEMA_ID('pizza'))
BEGIN
    CREATE TABLE pizza.Categories
    (
        Id   INT           NOT NULL IDENTITY(1,1),
        Name NVARCHAR(255) NOT NULL,
        CONSTRAINT PK_pizza_Categories PRIMARY KEY CLUSTERED (Id)
    );
END;
GO

-- Restaurants
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Restaurants' AND schema_id = SCHEMA_ID('pizza'))
BEGIN
    CREATE TABLE pizza.Restaurants
    (
        Id          INT           NOT NULL IDENTITY(1,1),
        Name        NVARCHAR(255) NOT NULL,
        Address     NVARCHAR(500) NOT NULL,
        PhoneNumber NVARCHAR(50)  NOT NULL,
        CONSTRAINT PK_pizza_Restaurants PRIMARY KEY CLUSTERED (Id)
    );
END;
GO

-- Orders
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Orders' AND schema_id = SCHEMA_ID('pizza'))
BEGIN
    CREATE TABLE pizza.Orders
    (
        Id               INT           NOT NULL IDENTITY(1,1),
        AccountId        INT           NOT NULL,
        RestaurantId     INT           NOT NULL,
        TimeReceived     DATETIME2     NOT NULL,
        TimeAccepted     DATETIME2     NULL,
        TimeDispatched   DATETIME2     NULL,
        TimeDelivered    DATETIME2     NULL,
        Subtotal         MONEY         NOT NULL,
        TaxCharged       MONEY         NOT NULL,
        Total            MONEY         NOT NULL,
        TimeRefunded     DATETIME2     NULL,
        RestaurantNotes  NVARCHAR(MAX) NULL,
        VoucherCode      NVARCHAR(100) NULL,
        CONSTRAINT PK_pizza_Orders PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_pizza_Orders_Accounts    FOREIGN KEY (AccountId)    REFERENCES pizza.Accounts    (Id),
        CONSTRAINT FK_pizza_Orders_Restaurants FOREIGN KEY (RestaurantId) REFERENCES pizza.Restaurants (Id)
    );

    CREATE INDEX IX_pizza_Orders_AccountId
        ON pizza.Orders (AccountId);
END;
GO

-- Products
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Products' AND schema_id = SCHEMA_ID('pizza'))
BEGIN
    CREATE TABLE pizza.Products
    (
        Id           INT            NOT NULL IDENTITY(1,1),
        Name         NVARCHAR(255)  NOT NULL,
        Description  NVARCHAR(MAX)  NULL,
        CurrentPrice MONEY          NOT NULL,
        Available    BIT            NOT NULL,
        CategoryId   INT            NOT NULL,
        CONSTRAINT PK_pizza_Products PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_pizza_Products_Categories FOREIGN KEY (CategoryId) REFERENCES pizza.Categories (Id)
    );
END;
GO

-- OrderLineItems
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OrderLineItems' AND schema_id = SCHEMA_ID('pizza'))
BEGIN
    CREATE TABLE pizza.OrderLineItems
    (
        Id           INT          NOT NULL IDENTITY(1,1),
        OrderId      INT          NOT NULL,
        ProductId    INT          NOT NULL,
        UnitPrice    MONEY        NOT NULL,
        Quantity     INT          NOT NULL,
        DiscountRate DECIMAL(5,3) NULL,
        PricePaid    MONEY        NOT NULL,
        CONSTRAINT PK_pizza_OrderLineItems PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_pizza_OrderLineItems_Orders   FOREIGN KEY (OrderId)   REFERENCES pizza.Orders   (Id),
        CONSTRAINT FK_pizza_OrderLineItems_Products FOREIGN KEY (ProductId) REFERENCES pizza.Products (Id)
    );

    CREATE INDEX IX_pizza_OrderLineItems_OrderId
        ON pizza.OrderLineItems (OrderId)
        INCLUDE (ProductId, Quantity, DiscountRate, PricePaid, UnitPrice);
END;
GO

-- ============================================================
-- Stored procedure: Get a customer's leaderboard ranking
-- by total number of orders placed (highest = rank 1)
-- ============================================================

CREATE OR ALTER PROCEDURE pizza.GetCustomerOrderRanking
    @AccountId INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH Rankings AS
    (
        SELECT
            AccountId,
            Ranking = ROW_NUMBER() OVER (
                ORDER BY COUNT(*) DESC
            )
        FROM pizza.Orders
        GROUP BY AccountId
    )
    SELECT
        Rankings.AccountId,
        Rankings.Ranking
    FROM Rankings
    WHERE Rankings.AccountId = @AccountId;
END;
GO
