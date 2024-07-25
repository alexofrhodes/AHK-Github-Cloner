#Include, json.ahk

ClonedYes := "--YES--"
ClonedNo := "--no---"
header := "owner,repo,cloned,description,language,created,updated"
csvData := header "`n"
IniFile := "settings.ini"
originalData := [] ; Array to hold the original data

IniRead, CloneFolder, %IniFile%, Settings, CloneFolder, 
if (CloneFolder = "ERROR") ; if not found, set to empty
    CloneFolder := A_ScriptDir

gui, font, s11, verdana

Gui, Add, Text, , Base Clone Folder  -  (will render CloneFolder "\" owner "\" repo "\")  -  (if empty then A_ScriptDir\Clones will be used)
Gui, Add, Edit, section vCloneFolder w600, %CloneFolder%
Gui, Add, Button, ys gBrowseFolder, Browse
Gui, Add, Button, ys gOpenFolder, Open

IniRead, UserInput, %IniFile%, Settings, UserInput, 
if (UserInput = "ERROR") ; if not found, set to empty
    UserInput := ""
gui, add, text, xs , usernames (separate by line feed)
Gui, Add, Edit, section vUserInput gUserInput w200 h100, %UserInput%

Gui, Add, Button, ys  w100 gPullData, Pull Data

Gui, Add, Text, xs , Filter ; filtering control for all row
Gui, Add, Edit, section vFilter w200 gFilterData

Gui, Add, Button, ys gSelectAll, Select All
Gui, Add, Button, ys gDeselectAll, Deselect All

Gui, Add, Button, ys gClone, Clone Selected

Gui, Show , Maximize
Gui, +Resize

WinGetPos,,, GuiWidth, GuiHeight, A
GuiWidth -= 500 ; Adjust to fit within the GUI
ListViewHeaders := StrReplace(header, ",", "|")
Gui, Add, ListView, xs vlv w%GuiWidth% r20, %ListViewHeaders%
Gui, Add, Text, xs w200 vItemCount, Total Items: 0

PullData(){
    global
    originalData := [] ; Clear originalData array

    if !DllCall("Wininet.dll\InternetGetConnectedState", "UInt*", flag, "UInt", 0)
    {
        MsgBox, , , No Internet Connection, 
        return
    }
    Gui, Submit, NoHide

    userinput := StrReplace(UserInput, "`r`n", ",")
    userinput := StrReplace(userinput, " ", "")

    GuiControl, -Redraw, LV ; Prevents flickering during ListView update
    LV_Delete()             ; Clear ListView before adding new data

    Loop, Parse, userinput, `,
    {
        UserName := A_LoopField
        aFile := "Data\" UserName ".csv"
        FileDelete, % aFile

        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        Address := "https://api.github.com/users/" UserName "/repos"
        whr.Open("GET", Address, true)
        whr.Send()
        whr.WaitForResponse()
        status := Whr.status
        if (status != 200)
            error := "HttpRequest error, status: " . status

        JsonString := whr.ResponseText
        JsonObject := Json.Load(JsonString)
        if !IsObject(JsonObject) {
            MsgBox, % "Parsing JSON for " UserName " failed."
            continue
        }

        for index, repo in JsonObject {
            repoPath := CloneFolder "\" repo.owner.login "\" repo.name
            if (FileExist(repoPath)) {
                cloned := ClonedYes
            } else {
                cloned := ClonedNo
            }
            ; first lv parameter reserved for icon
            created := SubStr(repo.created_at, 1 , 10)
            updated := SubStr(repo.updated_at, 1 , 10)
            row := [repo.owner.login, repo.name, cloned, repo.description, repo.language, created, updated]
            originalData.Push(row)
            LV_Add("", row*)

            csvData := repo.owner.login "," repo.name "," cloned  "," """" repo.description """" "," repo.language "," created "," updated "`n"
            FileAppend, % csvData, % aFile
        }
    }
    LV_ModifyCol() ;autosize
    GuiControl, +Redraw, LV ; Re-enable redraw for ListView
    ItemCount := LV_GetCount()
    GuiControl,, ItemCount, Total Items: %ItemCount%
    gui, show, maximize
}

FilterData(){
    global
    Gui, Submit, NoHide
    LV_Delete() ; Clear ListView before adding new data

    if (Filter = "") {
        ; No filter, restore original data
        for each, row in originalData {
            LV_Add("", row*)
        }
    } else {
        filter := Filter
        for each, row in originalData {
            matches := false

            ; Check if any part of the row matches the filter
            for index, value in row {
                if (InStr(value, filter)) {
                    matches := true
                    break
                }
            }

            if (matches) {
                LV_Add("", row*)
            }
        }
    }
    LV_ModifyCol()
    ItemCount := LV_GetCount()
    GuiControl,, ItemCount, Total Items: %ItemCount%
}

Clone(){
    global
    Gui, Submit, NoHide
    if (CloneFolder = "") {
        ;MsgBox, Please select a folder to clone into.
        CloneFolder := A_ScriptDir . "\clones"
    }
    CloneFolder:= StrReplace(CloneFolder, "\\", "\")
    
    RowNumber := 0
    selection := []
    Loop
    {
        RowNumber := LV_GetNext(RowNumber)
        if not RowNumber
            break
        LV_GetText(owner, RowNumber, GetColumnIndex("owner"))
        LV_GetText(repo, RowNumber, GetColumnIndex("repo"))
        LV_GetText(cloned, RowNumber, GetColumnIndex("cloned"))

        CloneRepoPath := CloneFolder "\" owner "\" repo

        if (cloned = ClonedNo) {
            CloneUrl := "https://github.com/" owner "/" repo
            CloneRepo(CloneUrl, CloneRepoPath, RowNumber)
        }
    }
    TrayTip, , Completed
}

CloneRepo(CloneUrl, CloneRepoPath, RowNumber) {
    global
    RunWait, %ComSpec% /C git clone %CloneUrl% %CloneRepoPath%, , Hide
    if (FileExist(CloneRepoPath)) {
        col := GetColumnIndex("cloned")
        LV_Modify(RowNumber, "Col" . col, ClonedYes)
    }
}

BrowseFolder(){
    global
    FileSelectFolder, CloneFolder
    If ErrorLevel
        Return
    GuiControl,, CloneFolder, %CloneFolder%
    IniWrite, %CloneFolder%, %IniFile%, Settings, CloneFolder
}

SelectAll(){
    LV_Modify(0, "Select")
}

DeselectAll(){
    LV_Modify(0, "-Select")
}

Join(delimiter, array*) {
    result := ""
    for _, element in array
        result .= (result = "" ? "" : delimiter) . element
    return result
}

GetColumnIndex(columnName) {
    global header
    headers := StrSplit(header, ",")
    Loop, % headers.MaxIndex()
    {
        if (headers[A_Index] = columnName)
            return A_Index
    }
    return -1 ; Column not found
}

UserInput()
{
    global
    Gui, Submit, NoHide
    IniWrite, %UserInput%, %IniFile%, Settings, UserInput
}

OpenFolder()
{
    global
    run, %CloneFolder%
}
