

#Include, json.ahk

header := "owner,repo,cloned,description,language,created,updated"
csvData := header "`n"
IniFile := "settings.ini"

; Load the last selected Clone Folder from the ini file
IniRead, CloneFolder, %IniFile%, Settings, CloneFolder, 
if (CloneFolder = "ERROR") ; if not found, set to empty
    CloneFolder := ""

gui, font, s11, verdana


Gui, Add, Text, , Base Clone Folder (will render CloneFolder "\" owner "\" repo "\")
Gui, Add, Edit, section vCloneFolder w600, %CloneFolder%
Gui, Add, Button, ys gBrowseFolder, Browse


gui, add, text,xs , usernames (separate by line feed)
Gui, Add, Edit, section vUserInput w200 h100
Gui, Add, Button, ys w100 gPullData, Pull Data


; filtering control for all row
Gui, Add, Text, xs, Filter
Gui, Add, Edit, section vFilter w200 gFilterData
Gui, Add, Button, ys gSelectAll, Select All
Gui, Add, Button, ys gDeselectAll, Deselect All
Gui, Add, Button, ys  gClone, Clone Selected

Gui, Show, Maximize
Gui, +Resize

WinGetPos,,, GuiWidth, GuiHeight, A
GuiWidth -= 500 ; Adjust to fit within the GUI
ListViewHeaders := StrReplace(header, ",", "|")
Gui, Add, ListView, xs vlv w%GuiWidth% r25, %ListViewHeaders%

PullData(){
    global
    Gui, Submit, NoHide
    
    ; Check if Clone Folder is set
    if (CloneFolder = "") {
        MsgBox, Please select a clone folder before pulling data.
        return
    }

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
        JsonString := whr.ResponseText
        JsonObject := Json.Load(JsonString)
        if !IsObject(JsonObject) {
            MsgBox, % "Parsing JSON for " UserName " failed."
            continue
        }
        for index, repo in JsonObject {
            repoPath := CloneFolder "\" repo.owner.login "\" repo.name
            if (FileExist(repoPath)) {
                cloned := "Yes"
            } else {
                cloned := "No"
            }
            LV_Add("", repo.owner.login, repo.name, cloned, repo.description, repo.language, repo.created_at, repo.updated_at)
            csvData := repo.owner.login "," repo.name "," cloned "`n" "," """" repo.description """" "," repo.language "," repo.created_at "," repo.updated_at 
            FileAppend, % csvData, % aFile
        }
    }
    LV_ModifyCol()
    GuiControl, +Redraw, LV ; Re-enable redraw for ListView
    gui, show, maximize

}

FilterData(){
    global
    Gui, Submit, NoHide
    LV_Delete() ; Clear ListView before adding new data
    filter := Filter
    Loop, Parse, userinput, `,
    {
        UserName := A_LoopField
        aFile := "Data\" UserName ".csv"
        Loop, Read, %aFile%
        {
            If (A_Index = 1)
                continue ; Skip the header row

            row := StrSplit(A_LoopReadLine, ",")
            matches := false

            ; Check if any part of the row matches the filter
            for index, value in row
            {
                if (InStr(value, filter))
                {
                    matches := true
                    break
                }
            }

            if (matches)
            {
                LV_Add("", row*)
            }
        }
    }
    LV_ModifyCol()
}

Clone(){
    global
    Gui, Submit, NoHide
    if (CloneFolder = "") {
        MsgBox, Please select a folder to clone into.
        return
    }

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

        if (cloned = "No") {
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
        LV_Modify(RowNumber, "Col7", "Yes")
    }
}

BrowseFolder(){
    global
    FileSelectFolder, CloneFolder
    if (CloneFolder != "")
    {
        GuiControl,, CloneFolder, %CloneFolder%
        IniWrite, %CloneFolder%, %IniFile%, Settings, CloneFolder
    }
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
