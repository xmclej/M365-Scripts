
## Data layer (one-time per client, reuses what you already do)
Register an app in each client's Entra ID with read-only Graph permissions: 
- Policy.Read.All, 
- UserAuthenticationMethod.Read.All, 
- AuditLog.Read.All. 
Since you're already pulling this data by hand via Graph/PowerShell, wrap it into a scheduled script (Azure Automation runbook or a scheduled task on your own infrastructure) that runs daily or on-demand and drops the JSON/CSV exports into a fixed SharePoint library, one folder per client.

## Analysis layer
Build a declarative agent in Copilot Studio, something like "Essential Eight – MFA ML2 Assessor." 
Point its knowledge source at that SharePoint library. 
Bake your four-part prompt template into the agent's instructions field, but drop the "input data" section since the agent pulls that automatically from the grounded files instead of you pasting it. 
Your "role," "reference standard," and "output format" sections stay fixed.

## What signing in actually looks like day to day
You open the agent in Teams or the Copilot app, pick the client, type something like "run ML2 MFA assessment," and it cross-references whatever the scheduled export last pulled. Not literally zero clicks, but close, and no manual copy-paste of CSVs into a chat window.

One licensing note: Copilot Studio agents run on their own metered credits, separate from the M365 Copilot Chat license we talked about earlier. Worth checking current Copilot Studio pricing before committing, since this isn't the free tier.

## Phase 2: True on-demand pull (more setup, closer to your goal)
If you want the agent to query live data at the moment you ask, rather than reading yesterday's export, give the Copilot Studio agent a custom connector action that calls the Graph endpoints directly (/identity/conditionalAccess/policies, /reports/authenticationMethods/userRegistrationDetails, /auditLogs/signIns) using the app registration from Phase 1. This is more engineering work up front, building and testing a custom connector, but once it's done, "sign in and ask" really does mean live data every time, no export step in between.

## Practical starting point
Given where you already are, comfortable with Graph, PowerShell, and Terraform, I'd start with Phase 1 using your own scheduled script rather than learning Power Automate connectors from scratch. Get the agent and SharePoint grounding working with one client first, refine the prompt template against real output, then decide if the live-query version in Phase 2 is worth the extra build time.


# Process Overview
1. Pull data
2. Perform Analysis
3. Report on gaps


## Pull Data
Creating script to pull data, this can be done manually or automated.
Automation requires work



## Perform Analysis
Building an agent to pull the data from SharePoint