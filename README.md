# nim_jira_cli_client
Nim CommandLine Client for JIRA - Issue &amp; Project Tracking Software

- launch arguments:
  - -i --info --help # opens info about launch arguments
  - -h --host --hostname \<hostname\> # ex. project.atlassian.com / 127.0.0.1:1337 (without protocol)
  - -u --user --username \<username\> # Jira account username
  - -p --pass --password \<password\> # Jira account password
  - -ba --basicAuth \<username:password\> # HTTP Basic Auth Credentials

- in-client commands:
  - ls -l \<limit\> -p \<page\> -a \<assignee\> -r \<resolution\> # issue list
  - \<issue.key\> # opens short info about issue
 
Powered by Nim Programming Language
