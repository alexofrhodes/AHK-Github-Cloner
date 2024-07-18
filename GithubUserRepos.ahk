;TODO - add a control to type or pick a folder to clone into (before proceeding)
;TODO - create command to clone
;TODO - create a column to check if the selected repo is already cloned
;TODO - 

#Include, json.ahk

header := "owner,repo,description,language,created,updated"
csvData := header "`n"

gui, add, text, , usernames (separate by line feed)
Gui, Add, Edit, section vUserInput w200 h50
Gui, Add, Button, ys gPullData, Pull Data
Gui, Add, Button, gClone, Clone

; Add a single filtering control
Gui, Add, Text, xs, Filter
Gui, Add, Edit, section vFilter w200 gFilterData
Gui, Add, Button, ys gSelectAll, Select All
Gui, Add, Button, ys gDeselectAll, Deselect All

ListViewHeaders := StrReplace(header, ",", "|")
Gui, Add, ListView, xs vlv w1000 r10, %ListViewHeaders%
Gui, Show, AutoSize

PullData(){
    global
    Gui, Submit, NoHide
    userinput := StrReplace(UserInput, "`r`n", ",")
    userinput := StrReplace(userinput, " ", "")
    GuiControl, -Redraw, LV ; Prevents flickering during ListView update
    LV_Delete() ; Clear ListView before adding new data
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
            LV_Add("", repo.owner.login, repo.name, repo.description, repo.language, repo.created_at, repo.updated_at)
            csvData := repo.owner.login "," repo.name "," """" repo.description """" "," repo.language "," repo.created_at "," repo.updated_at "`n"
            FileAppend, % csvData, % aFile
        }
    }
    LV_ModifyCol()
    GuiControl, +Redraw, LV ; Re-enable redraw for ListView
    gui, show, AutoSize
    TrayTip, , Complete
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
    RowNumber := 0
    selection := []
    Loop
    {
        RowNumber := LV_GetNext(RowNumber)
        if not RowNumber
            break
        LV_GetText(owner, RowNumber, GetColumnIndex("owner"))
        LV_GetText(repo, RowNumber, GetColumnIndex("repo"))
        Text := "https://github.com/" owner "/" repo
        selection.Push(Text)
    }
    out := Join("`n", selection*)
    MsgBox %out%
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
