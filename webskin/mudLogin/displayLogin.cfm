<cfsetting enablecfoutputonly="Yes">
<!--- @@displayname: Microsoft UD login form --->

<!------------------ 
FARCRY IMPORT FILES
 ------------------>
<cfimport taglib="/farcry/core/tags/formtools/" prefix="ft" />
<cfimport taglib="/farcry/core/tags/security/" prefix="sec" />
<cfimport taglib="/farcry/core/tags/webskin/" prefix="skin" />



<!------------------ 
START WEBSKIN
 ------------------>	

<skin:view typename="farLogin" template="displayHeaderLogin" />
	
			
		<cfoutput>
		<div class="loginInfo">
		</cfoutput>	
		
			<ft:form>	
				
				<sec:selectProject />
				
				<cfset url.ud = "MICROSOFTUD" />
				<sec:SelectUDLogin />
			
				<cfif application.security.userdirectories.microsoftud.isEnabled()>
					<!--- run authenticate function? --->
					<cfif isdefined("url.logout")>
						<cfoutput><p class="error">You are logged out. <a href="http://#cgi.http_host#/index.cfm?type=mudLogin&view=displayLogin">Login again</a></p></cfoutput>
					<cfelseif isdefined("url.code") and not isdefined("arguments.stParam.message")>
						<cfset arguments.stParam = application.security.processLogin() />
						<cfif arguments.stParam.authenticated and not request.mode.profile>
							<cflocation url="#URLDecode(arguments.stParam.loginReturnURL)#" addtoken="false" />
						<cfelse>
							<cfoutput><p class="error">#arguments.stParam.message# <a href="http://#cgi.http_host#/index.cfm?type=mudLogin&view=displayLogin">Retry</a></p></cfoutput>
						</cfif>
					<cfelse>
						<cflocation url="#application.security.userdirectories.microsoftud.getAuthorisationURL(clientID=application.fapi.getConfig('microsoftud', 'clientid'),redirectURL=application.security.userdirectories.microsoftud.getRedirectURL(),scope=application.fapi.getConfig('microsoftud', 'scope'),state='')#" addtoken="false" />
					</cfif>
				<cfelse>
					<cfoutput>
						<p>The Microsoft User Directory is not set up yet.</p>
					</cfoutput>
				</cfif>
			
			</ft:form>
			
		<cfoutput>
		</div>
		</cfoutput>		
				
	

<skin:view typename="farLogin" template="displayFooterLogin" />


<cfsetting enablecfoutputonly="false">