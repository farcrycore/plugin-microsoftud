<cfsetting enablecfoutputonly="true">

<!--- import tag libraries --->
<cfimport taglib="/farcry/core/tags/admin/" prefix="admin" />
<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />

<!--- set up page header --->
<admin:header title="Microsoft Group Admin" />

<ft:objectadmin 
	typename="mudGroup"
	title="Microsoft Group Administration"
	columnList="title" 
	sortableColumns="title"
	lFilterFields="title"
	sqlorderby="title asc"
	module="customlists/mudGroup.cfm"
	plugin="microsoftud" />

<admin:footer />

<cfsetting enablecfoutputonly="false">