USE master;
GO

/*****************************************************
ENABLE CLR

Enabling the CLR feature of SQL server. 
For more information on CLR you can read through Microsoft's documentation here: 
https://docs.microsoft.com/en-us/sql/relational-databases/clr-integration/common-language-runtime-integration-overview?view=sql-server-ver15
******************************************************/

sp_configure 'clr enabled', 1
GO
RECONFIGURE
GO

/*****************************************************
CLEANUP PREVIOUS RUNS

This is primarially for trouble shooting, but this section will 
basically clean up everything that the script creates allowing 
for the creation script to run again.

******************************************************/

USE ProdTest
GO

PRINT 'DROPPING ProdTest RELATED ITEMS'

DROP TRIGGER IF EXISTS dbo.testRecordInserted

DROP FUNCTION IF EXISTS dbo.HttpRequest
DROP PROCEDURE IF EXISTS dbo.HttpRequestAsync

DROP ASSEMBLY IF EXISTS clr_httprequestasync_assembly
DROP ASSEMBLY IF EXISTS clr_httprequest_assembly

DROP USER clr_httprequest_login

USE master
GO

PRINT 'DROPPING master RELATED ITEMS'

DROP LOGIN clr_httprequest_login;
DROP ASYMMETRIC KEY clr_httprequest_key;

DROP SERVER ROLE clr_unsafe_assembly;
DROP SERVER ROLE clr_external_access_assembly;
GO

/*****************************************************
CREATE SERVER ROLES

This creates two server roles relating to CLR assembilies.
The first one is a role that will have permissiosn to create
unsafe assembilies. The second role is one that will be allowed
to create external_access assembilies.

******************************************************/

PRINT 'CREATING SERVER ROLES'

CREATE SERVER ROLE clr_unsafe_assembly AUTHORIZATION securityadmin;
GRANT UNSAFE ASSEMBLY TO clr_unsafe_assembly;

CREATE SERVER ROLE clr_external_access_assembly AUTHORIZATION securityadmin;
GRANT EXTERNAL ACCESS ASSEMBLY TO clr_external_access_assembly;
GO

/*****************************************************
CREATE AUTH KEYS

This uses the signed assembilies to create an asymmetric key
that will be used to creat a login that trusts this assembily.

*****************************************************/

PRINT 'CREATING KEYS'

CREATE ASYMMETRIC KEY clr_httprequest_key FROM EXECUTABLE FILE = 'C:\Temp\HttpRequest\HttpRequest.dll';
GO

/*****************************************************
CREATE LOGINS

This creates a server login from the key above so we can use 
non-"safe" assembilies. Since HttpRequestAsync creates threads,
the login will need to have the unsafe role.

*****************************************************/

PRINT 'CREATING LOGINS'

CREATE LOGIN clr_httprequest_login FROM ASYMMETRIC KEY clr_httprequest_key;
ALTER SERVER ROLE clr_unsafe_assembly ADD MEMBER clr_httprequest_login
--ALTER SERVER ROLE clr_external_access_assembly ADD MEMBER clr_httprequest_login
GO

USE ProdTest
GO

PRINT 'CREATING DATABASE USERS'

CREATE USER clr_httprequest_login FOR LOGIN clr_httprequest_login;
GO

/*****************************************************
CREATE ASSEMBILIES

Here we are creating the assemblies that we will be using. 

The first one (commented out) is the base HttpRequest 
CLR assembily, this contains a table defined function
that will run the http request provided then return the response info. 
Since this does not use any unsafe features but does access resources
outside of the database, we need to use external_access.

The second one contains an asyncrounus extention of the first 
assembily. It takes the syncronus function from the first one 
and creates a stored procedure that runs an asyncronus version.
Since this assembily creates threads on the system, it needs to be
unsafe.

*****************************************************/

PRINT 'CREATING ASSEMBILIES'

--CREATE ASSEMBLY clr_httprequest_assembly AUTHORIZATION clr_httprequest_login
--FROM 'C:\Temp\HttpRequest\HttpRequest.dll' 
--WITH PERMISSION_SET=EXTERNAL_ACCESS

CREATE ASSEMBLY clr_httprequestasync_assembly AUTHORIZATION clr_httprequest_login
FROM 'C:\Temp\HttpRequestAsync\HttpRequestAsync.dll' 
WITH PERMISSION_SET=UNSAFE
GO

/*****************************************************
CREATE SQL LINKS TO ASSEMBILIES

For CLR to work in SQL Server there needs to be a SQL Server
entity that links to the assembily.

The first one is the table function defined in the first assembily.
Since we are not creating the first assembily we have it commented out.

The second one is the stored procedure for the async http request.

*****************************************************/

PRINT 'CREATING FUNCTIONS/PROCEDURES FOR ASSEMBILIES'
GO

--CREATE FUNCTION dbo.HttpRequest (
--	@uri NVARCHAR(MAX), 
--	@method NVARCHAR(MAX), 
--	@timeoutMs INT,
--	@contentType NVARCHAR(MAX), 
--	@headersXml NVARCHAR(MAX), 
--	@body VARBINARY(MAX)
--) RETURNS TABLE (
--	[Status] INT,
--	ContentType NVARCHAR(MAX),
--	ContentLength BIGINT,
--	Headers XML,
--	Body VARBINARY(MAX)
--) AS EXTERNAL NAME clr_httprequest_assembly.HttpRequest.[Send]
--GO

CREATE PROCEDURE dbo.HttpRequestAsync (
	@uri NVARCHAR(MAX), 
	@method NVARCHAR(MAX), 
	@timeoutMs INT,
	@contentType NVARCHAR(MAX), 
	@headersXml NVARCHAR(MAX), 
	@body VARBINARY(MAX)
)
AS EXTERNAL NAME clr_httprequestasync_assembly.HttpRequestAsync.SendAsync
GO