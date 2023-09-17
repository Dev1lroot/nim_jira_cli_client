import std/asynchttpserver, os, strutils, json, system, rdstdin, httpclient, base64, uri

echo "Rоbототь JIVO! (TM)"
echo "Client started"

type
    JiraSessionCredentials = object
        name: string
        value*: string
    JiraLoginInfo = object
        failedLoginCount: int
        loginCount: int
        lastFailedLoginTime: string
        previousLoginTime: string
    JiraSessionResponse = object
        session*: JiraSessionCredentials
        loginInfo: JiraLoginInfo
    JiraDashboardResponse = object
        issues: seq[JiraTask]
        total: int
        startAt: int
        maxResults: int
    JiraTask = object
        id: string
        key: string
        fields: JiraTaskDescription
    JiraTaskDescription = object
        summary: string
        description: string
        status: JiraTaskStatus
    JiraTaskStatus = object
        name: string # Пока обойдемся такой инфой)

proc displayName(j: JiraTask): string = 
    return j.key & " - " & j.fields.summary

var hostname = ""
var username = ""
var password = ""
var basicAuthUsername = ""
var basicAuthPassword = ""
var JSESSIONID = ""
var mode      = ""
var allocated_dashboard: seq[JiraTask]
var nextParam = 0

for param in commandLineParams():
    if mode == "-i" or mode == "--help" or mode == "--info":
        echo "-i  --help --info"
        echo "-h  --host --hostname <address>"
        echo "-u  --user --username <username>"
        echo "-p  --pass --password <password>"
        echo "-ba --basicAuth <username:password>"

    if mode == "-h"  or mode == "--host" or mode == "--hostname": hostname = param
    if mode == "-u"  or mode == "--user" or mode == "--username": username = param
    if mode == "-p"  or mode == "--pass" or mode == "--password": password = param
    if mode == "-ba" or mode == "--basicAuth":
        var credentials = param.split(":")
        if credentials.len == 2:
            basicAuthUsername = credentials[0]
            basicAuthPassword = credentials[1]
    mode = param

proc jql(prompt: JsonNode): string =
    var o = ""
    if prompt.hasKey("where"):
        var where: seq[string]
        for key in prompt["where"].keys:
            if prompt["where"][key].kind == JString:
                where.add(key & " = " & prompt["where"][key].getStr())
            if prompt["where"][key].kind == JArray:
                var items: seq[string]
                for item in prompt["where"][key]:
                    items.add(item.getStr())
                where.add(key & " IN (" & items.join(", ") & ")")
        o = where.join(" AND ")
    if prompt.hasKey("order"):
        o = o & " ORDER BY " & prompt["order"][0].getStr() & " " & prompt["order"][1].getStr()
                
    return o

proc basicAuth(client: HttpClient, username, password: string)=
    client.headers["Authorization"] = "Basic " & base64.encode(username & ":" & password)

proc newJivoClient(): HttpClient =
    var client = newHttpClient()
    client.headers["Content-Type"] = "application/json"
    client.headers["Accept-Content"] = "application/json"
    client.headers["Client-Version"] = "1.0"
    if JSESSIONID.len > 0:
        client.headers["Cookie"] = "JSESSIONID=" & JSESSIONID
    if basicAuthUsername.len > 0:
        client.basicAuth(basicAuthUsername,basicAuthPassword)
    return client

proc dashboard(limit, startAt: int, assignee, resolution: string)=
    try:
        var jql = ""
        try:
            jql = jql(%*{
                "where": {
                    "assignee": assignee,
                    "project":  ["HDEV", "SDEV", "SREP"],
                    "resolution": resolution,
                },
                "order": ["updated","DESC"]
            })
        except:
            echo "Failet to comply JQL request"
        var client = newJivoClient()
        var prompt = encodeQuery({
            "fields": "resolution,id,key,summary,description,assignee,priority,status",
            "maxResults": $limit,
            "startAt": $startAt,
            "jql": jql
        })
        var url    = "https://" & hostname & "/rest/api/2/search?" & prompt
        try:
            var boards = parseJson($client.getContent(url)).to(JiraDashboardResponse)
            allocated_dashboard = boards.issues
            echo "================================================================"
            for issue in boards.issues:
                try:
                    echo issue.displayName()
                except:
                    echo "Failed to fetch a task"
            echo "================================================================"
            echo "Tasks: " & $boards.maxResults & " of " & $boards.total
            nextParam = boards.startAt + boards.maxResults
        except:
            echo "Failed to parse response"
    except:
        echo "Failed to perform JQL query"

var db_limit    = 100
var db_page     = 0
var db_assignee = username
var db_resolution = "Unresolved"

proc runtime()=
    var command  = readLineFromStdin(username & ": ")
    var params   = command.split(" ")
    var pmodes   = ""

    if command == "next":
        dashboard(db_limit,nextParam,db_assignee,db_resolution)

    if params.len > 1 and (params[0] == "list" or params[0] == "ls"):
        for param in params:
            if pmodes == "-p": db_page       = parseInt(param)
            if pmodes == "-l": db_limit      = parseInt(param)
            if pmodes == "-a": db_assignee   = param
            if pmodes == "-r": db_resolution = param
            pmodes = param
        dashboard(db_limit, (db_limit * db_page), db_assignee, db_resolution)

    for issue in allocated_dashboard:
        if command == issue.key:
            echo "================================================================"
            echo "Status: " & issue.fields.status.name
            echo issue.displayName()
            echo issue.fields.description
            echo "Open: https://" & hostname & "/browse/" & issue.key
            echo "================================================================"
    runtime()

proc authorize()=

    if hostname.len == 0: hostname = readLineFromStdin "Hostname: "
    if username.len == 0: username = readLineFromStdin "Username: "
    if password.len == 0: password = readLineFromStdin "Password: "

    try:
        var client = newJivoClient()

        try:
            var response = client.postContent("https://" & hostname & "/rest/auth/1/session",
            $(%* {
                "username": username,
                "password": password
            }))
            try:
                var data = parseJson(response).to(JiraSessionResponse)
                JSESSIONID = data.session.value
                runtime()
            except:
                echo "Unable to extract session key"
        except HttpRequestError as e:
            echo e.msg
            username = ""
            password = ""
            authorize()
    except:
        echo "Remote host not found, try again"
        hostname = ""
        authorize()

authorize()
