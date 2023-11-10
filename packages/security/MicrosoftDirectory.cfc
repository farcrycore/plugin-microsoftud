<cfcomponent displayname="Microsoft User Directory" extends="farcry.core.packages.security.UserDirectory" output="false" key="MICROSOFTUD">
	
	
	<cffunction name="getLoginForm" access="public" output="false" returntype="string" hint="Returns the form component to use for login">
		
		<cfreturn "mudLogin" />
	</cffunction>
	
	<cffunction name="authenticate" access="public" output="false" returntype="struct" hint="Attempts to process a user. Runs every time the login form is loaded.">
		<cfset var stResult = structnew() />
		<cfset var stTokens = structnew() />
		<cfset var stTokenInfo = structnew() />
		<cfset var oUser = application.fapi.getContentType("mudUser") />

		<cfif structkeyexists(url,"error")>
			
			<cfset stResult.userid = "" />
			<cfset stResult.authenticated = false />
			<cfset stResult.message = url.error />
			
		<cfelseif isDefined("url.type") and url.type eq "mudLogin" and structkeyexists(url,"code")>
			
			<!--- <cftry> --->
				<!--- Get Microsoft access information --->
				<cfset stTokens = getTokens(url.code,application.fapi.getConfig('microsoftUD', 'clientID'),application.fapi.getConfig('microsoftUD', 'clientSecret'),application.security.userdirectories.microsoftUD.getRedirectURL(),application.fapi.getConfig('microsoftUD', 'proxy')) />
				<cfset var stProfile = getMicrosoftProfile(stTokens.access_token,application.fapi.getConfig('microsoftUD', 'proxy')) />
				<cfparam name="session.security.mud" default="#structnew()#" >
				<cfset session.security.mud[stProfile.id] = stTokens />
				<cfset session.security.mud[stProfile.id].profile = stProfile />

				<!--- If there isn't a mudUser record, create one --->
				<cfset var stUser = oUser.getByUserID(stProfile.id) />
				<cfif structisempty(stUser)>
					<cfset stUser = oUser.getData(createuuid()) />
					<cfset stUser.userid = stProfile.id />
					<cfif structkeyexists(stTokens,"refresh_token")>
						<cfset stUser.refreshToken = stTokens.refresh_token />
					</cfif>
					<cfset stUser.providerDomain = listlast(session.security.mud[stProfile.id].profile.userPrincipalName,"@") />
					<cfset oUser.setData(stProperties=stUser) />
				<cfelse>
					<cfif structkeyexists(stTokens,"refresh_token")>
						<cfset stUser.refreshToken = stTokens.refresh_token />
						<cfset oUser.setData(stProperties=stUser) />
					</cfif>
					<cfset session.security.mud[stProfile.id].refresh_token = stUser.refreshToken />
				</cfif>

				<cfset stResult.authenticated = "true" />
				<cfset stResult.userid = stProfile.id />
				<cfset stResult.ud = "MICROSOFTUD" />
				
				<!--- <cfcatch>
					<cfset application.fc.lib.error.logData(application.fc.lib.error.normalizeError(cfcatch)) />
					<cfset stResult.authenticated = "false" />
					<cfset stResult.userid = "" />
					<cfset stResult.message = "Error while logging into Microsoft: #cfcatch.message#" />
				</cfcatch>
			</cftry> --->
			
		</cfif>
		
		<cfreturn stResult />
	</cffunction>
	
	<cffunction name="getUserGroups" access="public" output="false" returntype="array" hint="Returns the groups that the specified user is a member of">
		<cfargument name="UserID" type="string" required="true" hint="The user being queried" />
		
		<cfset var qGroups = "" />
		<cfset var aGroups = arraynew(1) />
		<cfset var stUser = application.fapi.getContentType(typename="mudUser").getByUserID(arguments.userID) />
		
		<cfquery datasource="#application.dsn#" name="qGroups">
			select	title
			from	#application.dbowner#mudGroup
			where	objectid in (
						select	<cfif application.dbtype eq "mysql">`data`<cfelse>data</cfif>
						from	#application.dbowner#mudUser_aGroups
						where	parentid=<cfqueryparam cfsqltype="cf_sql_varchar" value="#stUser.objectid#" />
					)
					or objectid in (
						select	parentid
						from	#application.dbowner#mudGroup_aDomains
						where	<cfif application.dbtype eq "mysql">`data`<cfelse>data</cfif>=<cfqueryparam cfsqltype="cf_sql_varchar" value="*" />
								or <cfif application.dbtype eq "mysql">`data`<cfelse>data</cfif>=<cfqueryparam cfsqltype="cf_sql_varchar" value="#stUser.providerDomain#" />
					)
		</cfquery>
		
		<cfloop query="qGroups">
			<cfset arrayappend(aGroups,title) />
		</cfloop>
		
		<cfreturn listtoarray(valuelist(qGroups.title)) />
	</cffunction>
	
	<cffunction name="getAllGroups" access="public" output="false" returntype="array" hint="Returns all the groups that this user directory supports">
		<cfset var qGroups = "" />
		<cfset var aGroups = arraynew(1) />
		
		<cfquery datasource="#application.dsn#" name="qGroups">
			select		*
			from		#application.dbowner#mudGroup
			order by	title
		</cfquery>
		
		<cfloop query="qGroups">
			<cfset arrayappend(aGroups,title) />
		</cfloop>

		<cfreturn aGroups />
	</cffunction>

	<cffunction name="getGroupUsers" access="public" output="false" returntype="array" hint="Returns all the users in a specified group">
		<cfargument name="group" type="string" required="true" hint="The group to query" />
		
		<cfset var qUsers = "" />
		
		<cfquery datasource="#application.dsn#" name="qUsers">
			select	userid
			from	#application.dbowner#mudUser
			where	objectid in (
						select	parentid
						from	#application.dbowner#mudUser_aGroups ug
								inner join
								#application.dbowner#mudGroup g
								on ug.<cfif application.dbtype eq "mysql">`data`<cfelse>data</cfif>=g.objectid
						where	g.title=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.group#" />
								or objectid in (
									select	parentid
									from	#application.dbowner#mudGroup_aDomains
									where	<cfif application.dbtype eq "mysql">`data`<cfelse>data</cfif>=<cfqueryparam cfsqltype="cf_sql_varchar" value="*" />
											or <cfif application.dbtype eq "mysql">`data`<cfelse>data</cfif>=mudUser.providerDomain
								)
					)
		</cfquery>
		
		<cfreturn listtoarray(valuelist(qUsers.userid)) />
	</cffunction>

	<cffunction name="getProfile" access="public" output="false" returntype="struct" hint="Returns profile data available through the user directory">
		<cfargument name="userid" type="string" required="true" hint="The user directory specific user id" />
		<cfargument name="currentprofile" type="struct" required="false" hint="The current user profile" />

		<cfset var stProfile = structnew() />

		<cfif isdefined("session.security.mud") AND structKeyExists(session.security.mud, arguments.userid) AND structKeyExists(session.security.mud[arguments.userid], "profile")>
			<cfif structKeyExists(session.security.mud[arguments.userid].profile, "givenName") and structKeyExists(session.security.mud[arguments.userid].profile, "surname")>
				<cfset stProfile.firstname = session.security.mud[arguments.userid].profile.givenName />
				<cfset stProfile.lastname = session.security.mud[arguments.userid].profile.surname />
			<cfelse>
				<cfset stProfile.firstname = listFirst(session.security.mud[arguments.userid].profile.displayName, " ") />
				<cfset stProfile.lastname = listRest(session.security.mud[arguments.userid].profile.displayName, " ") />
			</cfif>
			<cfset stProfile.emailaddress = session.security.mud[arguments.userid].profile.userPrincipalName />
			<cfset stProfile.label = "#stProfile.firstname# #stProfile.lastname#" />
			<cfif structKeyExists(session.security.mud[arguments.userid].profile, "profilePhoto")>
				<cfset stProfile.avatar = replace(session.security.mud[arguments.userid].profile.profilePhoto, "https://", "//") />
			</cfif>
		</cfif>

		<cfset stProfile.override = true />

		<cfreturn stProfile />
	</cffunction>

	<cffunction name="isEnabled" access="public" output="false" returntype="boolean" hint="Returns true if this user directory is active. This function can be overridden to check for the existence of config settings.">
		
		<cfreturn len(application.fapi.getConfig('microsoftUD', 'clientID', '')) and len(application.fapi.getConfig('microsoftUD', 'clientSecret', '')) />
	</cffunction>
					
	
	<cffunction name="parseProxy" access="private" output="false" returntype="struct">
		<cfargument name="proxy" type="string" required="true" />
		
		<cfset var stResult = structnew() />
		
		<cfif len(arguments.proxy)>
			<cfif listlen(arguments.proxy,"@") eq 2>
				<cfset stResult.login = listfirst(arguments.proxy,"@") />
				<cfset stResult.proxyUser = listfirst(stResult.login,":") />
				<cfset stResult.proxyPassword = listlast(stResult.login,":") />
			<cfelse>
				<cfset stResult.proxyUser = "" />
				<cfset stResult.proxyPassword = "" />
			</cfif>
			<cfset stResult.server = listlast(arguments.proxy,"@") />
			<cfset stResult.proxyServer = listfirst(stResult.server,":") />
			<cfif listlen(stResult.server,":") eq 2>
				<cfset stResult.proxyPort = listlast(stResult.server,":") />
			<cfelse>
				<cfset stResult.proxyPort = "80" />
			</cfif>
		</cfif>
		
		<cfreturn stResult />
	</cffunction>

	<cffunction name="getAuthorisationURL" access="public" output="false" returntype="string">
		<cfargument name="clientid" type="string" required="false" />
		<cfargument name="redirectURL" type="string" required="false" />
		<cfargument name="state" type="string" required="false" default="" />
		<cfargument name="prompt" type="string" required="false" default="" />
		
		<cfset var scope = application.fapi.getConfig("microsoftUD", "scope") />
		<cfset var tenant = application.fapi.getConfig("microsoftUD", "tenant") />

		<cfif not structKeyExists(arguments, "clientid")>
			<cfset arguments.clientid = application.fapi.getConfig("microsoftUD", "clientid") />
		</cfif>
		<cfif not structKeyExists(arguments, "redirectURL")>
			<cfset arguments.redirectURL = getRedirectURL() />
		</cfif>

		<cfreturn "https://login.microsoftonline.com/#tenant#/oauth2/v2.0/authorize?response_type=code&client_id=#arguments.clientid#&redirect_uri=#urlencodedformat(arguments.redirectURL)#&scope=#urlencodedformat(scope)#&access_type=offline&prompt=#urlencodedformat(arguments.prompt)#&state=#urlencodedformat(arguments.state)#" />
	</cffunction>
	
	<cffunction name="getTokens" access="private" output="false" returntype="struct">
		<cfargument name="authorizationCode" type="string" required="true" />
		<cfargument name="clientID" type="string" required="true" />
		<cfargument name="clientSecret" type="string" required="true" />
		<cfargument name="redirectURL" type="string" required="true" />
		<cfargument name="scope" type="string" required="false" default="#application.fapi.getConfig("microsoftUD", "scope")#" />
		<cfargument name="tenant" type="string" required="false" default="#application.fapi.getConfig("microsoftUD", "tenant")#" />
		<cfargument name="proxy" type="string" required="false" default="" />
		
		<cfset var stResponse = "">
		<cfset var stResult = structnew() />
		<cfset var stAttr = structnew() />

		<cfset stAttr.url = "https://login.microsoftonline.com/#arguments.tenant#/oauth2/v2.0/token" />
		<cfset stAttr.method = "POST" />
		
		<cfif len(arguments.proxy)>
			<cfset structappend(stAttr,parseProxy(arguments.proxy)) />
		</cfif>
		
		<cfhttp attributeCollection="#stAttr#" result="stResponse" timeout="5">
			<cfhttpparam type="formfield" name="code" value="#arguments.authorizationCode#" />
			<cfhttpparam type="formfield" name="client_id" value="#arguments.clientID#" />
			<cfhttpparam type="formfield" name="client_secret" value="#arguments.clientSecret#" />
			<cfhttpparam type="formfield" name="redirect_uri" value="#arguments.redirectURL#" />
			<cfhttpparam type="formfield" name="grant_type" value="authorization_code" />
			<cfhttpparam type="formfield" name="scope" value="#arguments.scope#" />
		</cfhttp>

		<cfif not stResponse.statuscode eq "200 OK">
			<cfset throwError(message="Error accessing Microsoft Auth API: #stResponse.statuscode#",endpoint="https://login.microsoftonline.com/#arguments.tenant#/oauth2/v2.0/token",response=trim(stResponse.filecontent),args=arguments,stAttr=stAttr) />
		</cfif>
		
		<cfset stResult = deserializeJSON(stResponse.FileContent.toString()) />
		<cfset stResult.access_token_expires = dateadd("s",stResult.expires_in,now()) />
		
		<cfreturn stResult />
	</cffunction>
	<cffunction name="getAccessTokenRefresh" access="private" output="false" returntype="struct">
		<cfargument name="refresh_token" type="string" required="true" />
		<cfargument name="access_token_expires" type="date" required="true" />
		<cfargument name="proxy" type="string" required="false" default="" />
		<cfargument name="scope" type="string" required="false" default="#application.fapi.getConfig("microsoftUD", "scope")#" />
		<cfargument name="tenant" type="string" required="false" default="#application.fapi.getConfig("microsoftUD", "tenant")#" />

		<cfset var cfhttp = structnew() />
		<cfset var stResult = structnew() />
		<cfset var stProxy = parseProxy(arguments.proxy) />
		
		<cfif isdefined("arguments.refresh_token") and datecompare(arguments.access_token_expires,now()) lt 0>
			<cfhttp url="https://login.microsoftonline.com/#arguments.tenant#/oauth2/v2.0/token" method="POST" attributeCollection="#stProxy#">
				<cfhttpparam type="formfield" name="refresh_token" value="#arguments.refresh_token#" />
				<cfhttpparam type="formfield" name="client_id" value="#application.fapi.getConfig('microsoftUD', 'clientID')#" />
				<cfhttpparam type="formfield" name="client_secret" value="#application.fapi.getConfig('microsoftUD', 'clientSecret')#" />
				<cfhttpparam type="formfield" name="grant_type" value="refresh_token" />
				<cfhttpparam type="formfield" name="scope" value="#arguments.scope#" />
			</cfhttp>
			
			<cfif not cfhttp.statuscode eq "200 OK">
				<cfset throwError(message="Error accessing Microsoft Auth API: #cfhttp.statuscode#",endpoint="https://login.microsoftonline.com/#arguments.tenant#/oauth2/v2.0/token",response=cfhttp.filecontent,argumentCollection=arguments) />
			</cfif>
			
			
			
			<cfset stResult = deserializeJSON(cfhttp.FileContent.toString()) />
			
			<cfreturn stResult />
		<cfelseif not isdefined("arguments.refresh_token")>
			<cfset throwError(message="Error accessing Microsoft Auth API: no refresh_token available",endpoint="https://login.microsoftonline.com/#arguments.tenant#/oauth2/v2.0/token",response=cfhttp.filecontent,argumentCollection=arguments) />
		</cfif>
		
		<cfreturn stResult />
	</cffunction>
	
	
	<cffunction name="getAccessToken" access="public" output="false" returntype="string">
		<cfargument name="refresh_token" type="string" required="false" />
		<cfargument name="access_token" type="string" required="true" />
		<cfargument name="access_token_expires" type="date" required="true" />
		<cfargument name="proxy" type="string" required="false" default="" />
		<cfargument name="scope" type="string" required="false" default="#application.fapi.getConfig("microsoftUD", "scope")#" />
		<cfargument name="tenant" type="string" required="false" default="#application.fapi.getConfig("microsoftUD", "tenant")#" />

		<cfset var stResponse = "">
		<cfset var stResult = structnew() />
		<cfset var stProxy = parseProxy(arguments.proxy) />
		
		<cfif isdefined("arguments.refresh_token") and datecompare(arguments.access_token_expires,now()) lt 0>
			<cfhttp url="https://login.microsoftonline.com/#arguments.tenant#/oauth2/v2.0/token" method="POST" attributeCollection="#stProxy#" result="stResponse" timeout="5">
				<cfhttpparam type="formfield" name="refresh_token" value="#arguments.refreshToken#" />
				<cfhttpparam type="formfield" name="client_id" value="#arguments.clientID#" />
				<cfhttpparam type="formfield" name="client_secret" value="#arguments.clientSecret#" />
				<cfhttpparam type="formfield" name="grant_type" value="refresh_token" />
				<cfhttpparam type="formfield" name="scope" value="#arguments.scope#" />
			</cfhttp>
			
			<cfif not stResponse.statuscode eq "200 OK">
				<cfset throwError(message="Error accessing Microsoft Auth API: #stResponse.statuscode#",endpoint="https://login.microsoftonline.com/#arguments.tenant#/oauth2/v2.0/token",response=stResponse.filecontent,argumentCollection=arguments) />
			</cfif>
			
			<cfset stResult = deserializeJSON(stResponse.FileContent.toString()) />
			
			<cfreturn stResult.access_token />
		<cfelseif not isdefined("arguments.refresh_token")>
			<cfset throwError(message="Error accessing Microsoft Auth API: access token has expired and no refresh token is available",endpoint="https://login.microsoftonline.com/#arguments.tenant#/oauth2/v2.0/token",response=stResponse.filecontent,argumentCollection=arguments) />
		</cfif>
		
		<cfreturn arguments.access_token />
	</cffunction>
	
	<cffunction name="getMicrosoftProfile" access="private" output="false" returntype="struct">
		<cfargument name="accessToken" type="string" required="true" />
		<cfargument name="proxy" type="string" required="false" default="" />
		
		<cfset var stResponse = "">
		<cfset var stResult = structnew() />
		<cfset var stProxy = parseProxy(arguments.proxy) />
		<cfset var k = "" />
		
		<cfhttp url="https://graph.microsoft.com/v1.0/me" method="GET" attributeCollection="#stProxy#" result="stResponse" timeout="5">
			<cfhttpparam type="header" name="Authorization" value="Bearer #arguments.accessToken#" />
		</cfhttp>

		<cfif not stResponse.statuscode eq "200 OK">
			<cfset throwError(message="Error accessing Microsoft Graph API: #stResponse.statuscode#",endpoint="https://graph.microsoft.com/v1.0/me",response=stResponse.filecontent,argumentCollection=arguments) />
		</cfif>
		
		<cfset stResult = deserializeJSON(stResponse.FileContent.toString()) />
		
		<!--- Clean out the null values --->
		<cfloop collection="#stResult#" item="k">
			<cfif isNull(stResult[k])>
				<cfset structDelete(stResult, k) />
			</cfif>
		</cfloop>

		<cfreturn stResult />
	</cffunction>
	
	<cffunction name="checkAccessToken" access="public" output="false" returntype="void" hint="Checks if the access_token has expired and if so, uses the refresh_token to get a new one.">	
	<cfset var stUser = session.security.mud[listfirst(session.security.userid,'_')]>
	<cfset var stNewToken = getAccessTokenRefresh(stUser.refresh_token,stUser.access_token_expires)>
	<!--- now see if a new access_token was passed back and update the session --->
		<cfif structKeyExists(stNewToken,'access_token')>
			<cfset session.security.mud[listfirst(session.security.userid,'_')].access_token = stNewToken.access_token>
			<cfset session.security.mud[listfirst(session.security.userid,'_')].refresh_token = stNewToken.refresh_token>
			<cfset session.security.mud[listfirst(session.security.userid,'_')].access_token_expires = dateadd("s",stNewToken.expires_in,now()) />
		</cfif>
	</cffunction>
	
	<cffunction name="getRedirectURL" access="public" output="false" returntype="string" hint="For use with getAuthorisationURL and getRefreshToken">
		
		<cfreturn "#application.fc.lib.seo.getCanonicalProtocol()#://#cgi.http_host##application.url.webroot#/mudLogin/displayLogin" />
	</cffunction>
	
	<cffunction name="throwError" access="private" output="false" returntype="void">
		<cfargument name="message" type="string" required="true" />
		
		<cfset var stLog = application.fc.lib.error.collectRequestInfo() />
		
		<cfset structappend(stLog,arguments) />
		<cfset stLog.stack = application.fc.lib.error.getStack(true,false,1) />
		<cfset stLog.logtype = "MICROSOFTUD" />
		
		<cfset application.fc.lib.error.logData(stLog,false,false) />
		
		<cfthrow message="#arguments.message#" detail="#serializeJSON(arguments)#" />
	</cffunction>
	
</cfcomponent>
