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
Authentication section. I thought about adding a function to create the API account ... but
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
PS> Request-uptGroup

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
PS> Request-uptGroupMember -GroupGUID 0ee92a05-7979-4e18-a620-2346eeabde9a

MonitorGUID                            Name
-----------                            ----
608174e8-01ec-4565-9abe-3ad5136b3a45   This is my monitor
```
You could also do this:
```Powershell
PS> Request-uptGroup -Filter 'Prod' | Request-uptGroupMember

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
PS> Request-uptGroup -Filter 'Prod' | Request-uptGroupMaintenancePeriod

ID        Disable MonitorGUID                          Name                                    Mode    Start            End
--        ------- -----------                          ----                                    ----    -----            ---
490638    All     608174e8-01ec-4565-9abe-3ad5136b3a45 This is my monitor                      OneTime 06/07/2019 16:03 06/28/2019 15:15
489633    Alerts  608174e8-01ec-4565-9abe-3ad5136b3a45 This is my monitor                      Daily   16:02            16:12
```

and

```Powershell
PS> Request-uptMonitorMaintenancePeriod -MonitorGUID '608174e8-01ec-4565-9abe-3ad5136b3a45'

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
PS> Request-uptMonitorMaintenancePeriod -MonitorGUID '608174e8-01ec-4565-9abe-3ad5136b3a45' -ShowSummary

MonitorGUID : 608174e8-01ec-4565-9abe-3ad5136b3a45
Name        : This is my monitor
Period      : {490638:OneTime:DisableMonitoring, 489733:Weeekly:DisableNotifications}
```

Of course, with the ShowSummary switch, you can pipe it to `| Select-Object -ExpandProperty Period` and
get back to that first list... it's all just creative formating.
