# brshUPTrends - Manage Uptrends monitors via API calls

Note: Compatible with PowerShell 5.1 and PowerShell Core 6.x

[Uptrends](www.uptrends.com) (www.uptrends.com) provides site monitoring/alerting, plus some misc other features
that are nice to have (plus some that could use some improvements \<cough\>maintenance period
setting, mobile app\</cough\>).

This module is intended to set/unset Maintenance Periods (MPs) on monitors and monitor groups.
MPs are set on monitors to disable monitoring and/or alerting during specific times. Very
handy things to have when you're .. um .. performing maintenance. You _can_ set MPs en masse
via the web interface via a template, but it's never felt quite right ... and it's sooooo
much easier just to turn off the monitors/alerts at the Monitors (where there's a handy
Turn 'em All Off button!).

And besides, it's the future: we script everything nowadays.

## Access

### Credentials

You _do_ need API access (well, Uptrends access and _then_ API access) to use these functions.
I recommend heading over to https://www.uptrends.com/support/kb/api/v4 and scrolling to the
Authentication section (ok, here's a direct link to the Swagger UI that might work for ya: https://api.uptrends.com/v4/swagger/index.html?url=/v4/swagger/v1/swagger.json#/Register). I thought about adding a function to create the API account ... but
you only need it once... why not just use their interface?

Once you have creds, you'll need them for each access to the API - so cache 'em somehow: either
using `$cred = Get-Credential` or via this module's `Set-uptStoredCredential` function. The
`Set-uptStoredCredential` can (by default, but doesn't have to) cache the cred info in the
module's mem space so you don't need to specify it for each call. It can also utilize my
(shameless plug) [SecureTokens](http://github.com/brsh/SecureTokens) module to use local
encrypted tokens, cuz I find that to be simple.

#### Syntax

```Powershell
Syntax
Set-uptStoredCredential [-UserName <String>] [-Password <String>] [-DoNotStoreCred]

Set-uptStoredCredential [-UserName <String>] [-PasswordSecure <SecureString>] [-DoNotStoreCred]

Set-uptStoredCredential [-SecureTokenUserName <String>] [-SecureTokenPasswordName <String>] [-DoNotStoreCred]
```
If you don't supply anything, the function will ask you for your creds - this keeps it off the
command line, which is nice. You can also pass in SecureString that you establish beforehand if
that's your pref.

If you use the `-DoNotStoreCred` switch - the function will return a cred that you can save
in your own variable. Otherwise, the cred is saved in the module's memory and used automatically
with each API call.

## Read from the API

The main piece of information needed to do almost anything with the API is a GUID: whether
for MonitorGroups or Monitors themselves (although there's a bit of inconsistency what can
be done with one versus the other). The only time you need something other than a GUID
is if you're working with MPs ... then you need the ID.

### Request Monitor Groups

The module's first function is the `Request-uptGroup` - this pulls a list of ... monitor
groups from the API, including the ever useful GUID.

#### Syntax

```Powershell
Request-uptGroup [[-Credential] <PSCredential>] [-Filter <String[]>] [-DoNotStoreGroups]
```
Nothing much to see here. Provide a cred (if not cached), filter by name (regex), and weird switch....

Yeah, so originally I planned to cache the results so you wouldn't have to do multiple calls to the
API ... which can be expensive if you have lots of results. And, yeah, I still do cache the
results - enabling autocomplete in places where it's nice to have autocomplete. But, 1) it's not
that expensive, and 2) this will really serve more as a module you will script against, I don't
expect to get as much mileage out of caching the results. Whatevs. If you don't want to cache,
you don't have to (and, in fact, I use that switch a lot in other parts of the code cuz I don't
want to overwrite what you cache).

Anyway, running that command will return something akin to:

```Powershell
PS C:\>Request-uptGroup

GroupGUID                              Description
---------                              -----------
6dc636cf-2696-4377-8052-731d3878fd05   All Monitors
0ee92a05-7979-4e18-a620-2346eeabde9a   Prod Group
91528d7f-1bf0-481d-829b-7f67b3d99558   Stage Group
01cc7795-9d68-46dc-ae48-25c122d25318   Dev Stuff
```

Or you can filter with a string (`'Group'`), string array (`'Prod', 'Stage'`), or regex (`'(up|ff)$'`).
Note, they're all really regex... so be careful with those strings.

### Request Monitors

Ok, you've got the groups - now what? Well, one thing you can do, is pull the list of Monitors
within those groups. Again, this is handy for doing stuff ... cuz you get those handy GUIDs.

#### Syntax

```Powershell
Request-uptGroupMember [-Credential <PSCredential>] [-Filter <String[]>] [-DoNotStoreMembers ]

Request-uptGroupMember [-GroupGUID] <Guid[]> [-Credential <PSCredential>] [-Filter <String[]>] [-DoNotStoreMembers]

Request-uptGroupMember [-MonitorGroupName] <String[]> [-Credential <PSCredential>] [-Filter <String[]>] [-DoNotStoreMembers]
```

If you have the GroupGUID, that'll get you the fastest turnaround. Just supply it (as 1 GUID or an array),
and you'll get the monitors therein.

If you don't want to mess with GUIDs... well, 1) get over it, and 2) ok, you don't have to. You can
supply the group .. um .. Description (not Name... nope, not Name) - and if you've cached the Groups,
you can use PowerShell's autocomplete to help you. This can be a little slower, if the data is not cached,
as it'll have to request the groups to find the GUID from the name, THEN it can query the members.

And there's a filter here too, so you can use a string, array of strings, or regex to filter the
monitors to a specific subset (see Note about Request-uptGroup's filter above).

And, if you've cached the Groups, specifying _nothing_ on the command line will look for members
of all the groups cached (so, be careful of that All Monitors one...).

So, something like this:

```Powershell
PS C:\>Request-uptGroupMember -GroupGUID 0ee92a05-7979-4e18-a620-2346eeabde9a

MonitorGUID                            Name
-----------                            ----
608174e8-01ec-4565-9abe-3ad5136b3a45   This is my monitor
```
You could also do this:
```Powershell
PS C:\>Request-uptGroup -Filter 'Prod' | Request-uptGroupMember

MonitorGUID                            Name
-----------                            ----
608174e8-01ec-4565-9abe-3ad5136b3a45   This is my monitor
```

### Request Maintenance Periods

To see what MPs are defined on monitors, you use the `Request-uptMonitorMaintenancePeriod` function
for querying individual monitors, or the `Request-uptGroupMaintenancePeriod` function for querying
groups (the Group one just wraps the GroupMember function and pipes it to the MonitorMP function,
basically just helping shorten things for you).

#### Syntax

```Powershell
Request-uptGroupMaintenancePeriod [-Credential <pscredential>] [-ShowSummary] [-IncludeAllMonitors]

Request-uptGroupMaintenancePeriod [-GroupGUID] <guid[]> [-Credential <pscredential>] [-ShowSummary] [-IncludeAllMonitors]

Request-uptGroupMaintenancePeriod [-Description] <string[]> [-Credential <pscredential>] [-ShowSummary] [-IncludeAllMonitors]
```
and

```Powershell
Request-uptMonitorMaintenancePeriod [-Credential <pscredential>] [-ShowSummary] [-IncludeAllMonitors]

Request-uptMonitorMaintenancePeriod [-MonitorGuid] <guid[]> [-Credential <pscredential>] [-ShowSummary] [-IncludeAllMonitors]

Request-uptMonitorMaintenancePeriod [-Name] <string[]> [-Credential <pscredential>] [-ShowSummary] [-IncludeAllMonitors]
```

These are very similar, really only differing in the GUID you use (GroupGUID vs MonitorGUID). On the
command line, you can reference the group Description (even if not cached) or the Monitor Name
(only if cached).

The `ShowSummary` switch is leftover from an earlier incarnation of the function - but it's still
useful: rather than showing each MP, it instead shows a list of monitors with their MPs
grouped/summarized together. Vs the default view of each MP _not_ grouped.

The `IncludeAllMonitors` switch includes all monitors - even those without MPs. This is useful to verify
what does and does not have MPs defined.

The default output lists a stylized view of MPs. Uptrends returns MPs with different properties,
depending if the MP is onetime vs daily/weekly/monthly. The default view of MPs will group the
props together for simpler viewing - however, this view is _not_ indicative of the actual
property names; you'll want to view the real properties via `Format-List` or something similar
if you really want to know the real props....

```Powershell
PS C:\>Request-uptGroup -Filter 'Prod' | Request-uptGroupMaintenancePeriod

ID        Disable MonitorGUID                          Name                                    Mode    Start            End
--        ------- -----------                          ----                                    ----    -----            ---
490638    All     608174e8-01ec-4565-9abe-3ad5136b3a45 This is my monitor                      OneTime 06/07/2019 16:03 06/28/2019 15:15
489633    Alerts  608174e8-01ec-4565-9abe-3ad5136b3a45 This is my monitor                      Daily   16:02            16:12
```

and

```Powershell
PS C:\>Request-uptMonitorMaintenancePeriod -MonitorGUID '608174e8-01ec-4565-9abe-3ad5136b3a45'

ID        Disable MonitorGUID                          Name                                    Mode    Start            End
--        ------- -----------                          ----                                    ----    -----            ---
490638    All     608174e8-01ec-4565-9abe-3ad5136b3a45 This is my monitor                      OneTime 06/07/2019 16:03 06/28/2019 15:15
489733    Alerts  608174e8-01ec-4565-9abe-3ad5136b3a45 This is my monitor                      Weekly  Mon @ 16:02      16:12
```

This is a wide output, mostly because I include the MonitorGUID _and_ Name both ... they're just
both sooooo handy.

Notice that this includes 2 MPs on a single Monitor. If you used the `ShowSummary` switch,
it would look like this:

```Powershell
PS C:\>Request-uptMonitorMaintenancePeriod -MonitorGUID '608174e8-01ec-4565-9abe-3ad5136b3a45' -ShowSummary

MonitorGUID : 608174e8-01ec-4565-9abe-3ad5136b3a45
Name        : This is my monitor
Period      : {490638:OneTime:DisableMonitoring, 489733:Weeekly:DisableNotifications}
```

Of course, with the ShowSummary switch, you can pipe it to `| Select-Object -ExpandProperty Period` and
get back to that first list... it's all just creative formating.

## Setting or Changing Maintenance Periods

The main piece of information needed to do almost anything with the API is a GUID: whether
for MonitorGroups or Monitors themselves (although there's a bit of inconsistency what can
be done with one versus the other). The only time you need something other than a GUID
is if you're working with MPs ... then you need the ID (and also, usually, a GUID).

Key thing to remember about MPs (explained several times above): the default
table-view of MPs simplifies the MPs properties so they can all be viewed
together in a nice, succinct table. The actual properties are vieable when you
pipe to Format-Table (a la ` ... | Format-Table *`)

See https://www.uptrends.com/support/kb/api/maintenance-periods for some fun light reading.

### Define a New Maintenance Period

To create a Maintenance Period, you have to feed the API a properly formatted
set of information. This function... creates that info for you.

The types of Maintenance Periods are:
* OneTime - only happen once and never again
* Daily   - happen daily at the same time each day
* Weekly  - happen once a week on the same day and same time
* Monthly - happen once a month, on a specific day of the month

Depending on the type of MP, you'll need to specify either the WeekDay or the
MonthDay when the MP should occur.

The Start date/time is the only one you really need to specify as a date. You
can specify and End date/time, or how many minutes or how many hours the MP
should last.

Finally, MPs can DisableAlertsOnly or, by default, it will disable Alerts
AND Monitoring. If you're really working on the system, you'll prolly want to
use the default and disable all Monitoring. But, sometimes, you want the
Monitors to continue, but you just don't care to hear about it. Your choice.

#### Syntax
```Powershell
New-uptMaintenancePeriod -OneTime  -Start <DateTime> [-End <DateTime>] [-Minutes <Int32>] [-Hours <Int32>] [-DisableAlertsOnly ] [-ID <Int32>] [<CommonParameters>]

New-uptMaintenancePeriod -Daily  -Start <DateTime> [-End <DateTime>] [-Minutes <Int32>] [-Hours <Int32>] [-DisableAlertsOnly ] [-ID <Int32>] [<CommonParameters>]

New-uptMaintenancePeriod -Weekly  -Start <DateTime> [-End <DateTime>] [-Minutes <Int32>] [-Hours <Int32>] -WeekDay <String> [-DisableAlertsOnly ] [-ID <Int32>] [<CommonParameters>]

New-uptMaintenancePeriod -Monthly  -Start <DateTime> [-End <DateTime>] [-Minutes <Int32>] [-Hours <Int32>] -MonthDay <Int32> [-DisableAlertsOnly ] [-ID <Int32>] [<CommonParameters>]
```
Reasonably self-explanatory here. (And yeah, I'm sorry I couldn't figure out the
right combo of ParameterSetNames to minimize some of the overlap).

Prolly the one piece that needs explaining is the `-DisableAlertsOnly` switch.
By default, these MPs will disable all monitoring AND alerting. This switch
will keep monitoring active, but stop alerts.

A example of a one-time MP is

```PowerShell

PS C:\>$b = New-uptMaintenancePeriod -OneTime -Start '5/22/2019 7pm' -Hours 2 -DisableAlertsOnly
PS C:\>$b

Name                           Value
----                           -----
ID                             0
MaintenanceType                DisableNotifications
StartDateTime                  2019-05-22T19:00:00.0000000
EndDateTime                    2019-05-22T21:00:00.0000000
ScheduleMode                   OneTime
```

By the way, TimeZones are gonna be a pain with these things. Just saying.

Similarly, a weekly MP looks like this:

```PowerShell
PS C:\>$b = New-uptMaintenancePeriod -Weekly -Start '5/22/2019 7pm' -Hours 2 -WeekDay Tuesday
PS C:\>$b

Name                           Value
----                           -----
ID                             0
MaintenanceType                DisableMonitoring
ScheduleMode                   Weekly
WeekDay                        Tuesday
StartTime                      19:00
EndTime                        21:00
```

### Add a Maintenance Period to a Monitor

A function to add a pre-defined MaintenancePeriod object to one or several
monitors. This works at the monitor level and is intended for the one- or
few-offs that occur.

If you need a quick way to set MPs on all Monitors in a Group, use the
Add-uptGroupMaintenancePeriod function.

#### Syntax
```Powershell
Add-uptMonitorMaintenancePeriod [-MonitorGUID] <Guid[]> [[-MaintenancePeriod] <Object>] [[-Credential] <PSCredential>]
```

So, to add an MP to a monitor:
```powershell
PS C:\>$mp = New-uptMaintenancePeriod -Onetime -Start $((get-date).AddHours(2)) -Hours 2
PS C:\>Add-uptMonitorMaintenancePeriod -MonitorGUID '76c69d9f-05a7-4e8e-a6cc-7c6dc17538f1' -MaintenancePeriod $mp
```

### Add a Maintenance Period to a Group

Possibly better than the Add-uptMonitorMaintenancePeriod function...

The quickest way to add an MP to a lot of monitors: add it to the Group. The
drawback ... Uptrends does not return anything other than a status code, so
the only proof that it succeeds is a "quick" list of all MPs on the Group :(

#### Syntax
```Powershell
Add-uptGroupMaintenancePeriod [-GroupGUID] <Guid[]> [[-MaintenancePeriod] <Object>] [[-Credential] <PSCredential>]
```

So, to add an MP to every Monitor in a Group:
```powershell
PS C:\>$mp = New-uptMaintenancePeriod -Onetime -Start $((get-date).AddHours(2)) -Hours 2
PS C:\>Add-uptGroupMaintenancePeriod -GroupGUID '76c69d9f-05a7-4e8e-a6cc-7c6dc17538f1' -MaintenancePeriod $mp
```

### Edit a Maintenance Period

Doesn't matter if you set the MP on a Monitor or a Group... you can only
edit an MP on a monitor: you need the MonitorGUID and the MP ID. Luckily,
that's all contained in the MPs returned by the various MP Request functions.

This function adjusts the settings of an MP - so you can change the end time,
or the week day... whatever you need to change, you prolly can change it. The
key pieces of information are the MonitorGUID, the MP ID, and the changes.

And since MonitorGUID and MP ID are both required, it's best to pull the specific
MP(s) you want via

`Request-uptMonitorMaintenancePeriod | where-object { $_.ID -eq ### }`

and then changing the approp property... and then using it in the command line.

#### Syntax
```powershell
Edit-uptMaintenancePeriod [-MaintenancePeriod] <PSObject[]> [-Credential <PSCredential>] [<CommonParameters>]
```

So, changing the day on a Weekly MP requires: first getting the MP, then editing
the day, then saving it.

```Powershell
PS C:\>$mp = Request-uptMonitorMaintenancePeriod -MonitorGUID '76c69d9f-05a7-4e8e-a6cc-7c6dc17538f1' | Where-Object { $_.ID -eq 503378 }
PS C:\>$mp.WeekDay = 'Tuesday'
PS C:\>Edit-uptMaintenancePeriod -MaintenancePeriod $mp
```
Bam! Just that ez

And you can do that for multiple MPs just by adjusting the Where-Object
statement to return more MPs. Just bear in mind that you'll have to adjust
EACH MP in the array ... so `$MP[0].Weekday`, `$MP[1].Weekday` etc. (or,
of course, a nice tidy foreach-object loop).

### Delete a Maintenance Period

Very similar to the Edit... this function deletes an MP - gone. Bye Bye.

Here, the key pieces of information are the MonitorGUID and the MP ID

And since MonitorGUID and MP ID are both required, it's best to pull the specific
MP(s) you want via the Request-uptMonitorMaintenancePeriod function,
and then using it in the command line.

#### Syntax
```powershell
Remove-uptMaintenancePeriod [-MaintenancePeriod] <PSObject[]> [-Credential <PSCredential>] [<CommonParameters>]
```

So, to delete an MP with a specific ID:
```powershell
PS C:\>$mp = Request-uptMonitorMaintenancePeriod -MonitorGUID '76c69d9f-05a7-4e8e-a6cc-7c6dc17538f1' | Where-Object { $_.ID -eq 503378 }
PS C:\>Remove-uptMaintenancePeriod -MaintenancePeriod $mp
```

and to delete all MPs on that Monitor
```powershell
PS C:\>$mp = Request-uptMonitorMaintenancePeriod -MonitorGUID '76c69d9f-05a7-4e8e-a6cc-7c6dc17538f1'
PS C:\>Remove-uptMaintenancePeriod -MaintenancePeriod $mp
```
