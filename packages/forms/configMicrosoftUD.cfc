<cfcomponent displayname="Microsoft User Directory" extends="farcry.core.packages.forms.forms" output="false" 
	key="microsoftud" hint="Configure user authentication via Microsoft Auth">

	<cfproperty ftSeq="1" ftFieldset="Microsoft User Directory" ftLabel="Proxy" 
				name="proxy" type="string" 
				ftHint="If internet access is only available through a proxy, set here. Use the format '[username:password@]domain[:port]'."
				ftHelpSection="When you set up this config you will need to enter the redirect URL: http://[hostname]/mudLogin/displayLogin" />

	<cfproperty ftSeq="2" ftFieldset="Microsoft User Directory" ftLabel="Client ID" 
				name="clientID" type="string" 
				ftHint="This should be copied exactly from the <a href='https://apps.dev.microsoft.com/'>Application Registration Portal</a>." />

	<cfproperty ftSeq="3" ftFieldset="Microsoft User Directory" ftLabel="Client Secret" 
				name="clientSecret" type="string" 
				ftHint="This should be copied exactly from the <a href='https://apps.dev.microsoft.com/'>Application Registration Portal</a>." />

	<cfproperty ftSeq="4" ftFieldset="Microsoft User Directory" ftLabel="Scope" 
				name="scope" type="string" ftDefault="user.read"
				ftHint="This should be a space delimited list of scopes as per the Microsoft Graph documentation" />

	<cfproperty ftSeq="5" ftFieldset="Microsoft User Directory" ftLabel="Tenant" 
				name="tenant" type="string" ftDefault="common"
				ftHint="This should be the <a href='https://docs.microsoft.com/en-gb/azure/active-directory/develop/active-directory-v2-protocols##endpoints'>Azure Directory tenant</a>" />


</cfcomponent>