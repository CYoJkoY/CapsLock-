#Requires AutoHotkey v2.0

class QuickPhraseStore {
    static SectionPrefix := "QuickPhrase_"
    static _phrases := []

    static Load() {
        this._EnsureDirectories()
        this._phrases := []

        if !FileExist(AppState.QuickPhraseFile)
            return

        try sections := IniRead(AppState.QuickPhraseFile, , , "")
        catch
            return

        for section in StrSplit(sections, "`n", "`r") {
            section := Trim(section)
            if SubStr(section, 1, StrLen(this.SectionPrefix)) != this.SectionPrefix
                continue

            idText := SubStr(section, StrLen(this.SectionPrefix) + 1)
            if !(idText ~= "^\d+$")
                continue

            id := Integer(idText)
            name := IniRead(AppState.QuickPhraseFile, section, "Name", "")
            category := IniRead(AppState.QuickPhraseFile, section, "Category", "")
            orderText := IniRead(AppState.QuickPhraseFile, section, "Order", id)
            contentFile := IniRead(AppState.QuickPhraseFile, section, "ContentFile", "")

            if name == "" || !(contentFile ~= "^phrase-\d+\.txt$")
                continue
            if !(orderText ~= "^\d+$")
                orderText := id

            contentPath := AppState.QuickPhraseContentDir "\" contentFile
            if !FileExist(contentPath)
                continue

            try content := FileRead(contentPath, "UTF-8")
            catch
                continue

            this._phrases.Push({
                id: id,
                name: name,
                category: category,
                order: Integer(orderText),
                contentFile: contentFile,
                content: content
            })
        }

        this._Sort()
        this._NormalizeOrders()
    }

    static GetAll() => this._phrases

    static GetById(id) {
        index := this._FindIndex(id)
        return index ? this._phrases[index] : ""
    }

    static Create(name, category, content) {
        name := Trim(name)
        category := Trim(category)
        if name == "" || content == ""
            return false

        this._EnsureDirectories()
        id := this._NextId()
        phrase := {
            id: id,
            name: name,
            category: category,
            order: this._phrases.Length + 1,
            contentFile: "phrase-" id ".txt",
            content: content
        }
        contentPath := AppState.QuickPhraseContentDir "\" phrase.contentFile

        if !this._WriteContent(contentPath, content)
            return false

        try {
            this._WriteMetadata(phrase)
        } catch {
            try FileDelete(contentPath)
            return false
        }

        this._phrases.Push(phrase)
        return true
    }

    static Update(id, name, category, content) {
        phrase := this.GetById(id)
        if !IsObject(phrase)
            return false

        name := Trim(name)
        category := Trim(category)
        if name == "" || content == ""
            return false

        contentPath := AppState.QuickPhraseContentDir "\" phrase.contentFile
        if !this._WriteContent(contentPath, content)
            return false

        oldName := phrase.name
        oldCategory := phrase.category
        oldContent := phrase.content
        phrase.name := name
        phrase.category := category
        phrase.content := content

        try {
            this._WriteMetadata(phrase)
        } catch {
            phrase.name := oldName
            phrase.category := oldCategory
            phrase.content := oldContent
            return false
        }

        return true
    }

    static Delete(id) {
        index := this._FindIndex(id)
        if !index
            return false

        phrase := this._phrases[index]
        try IniDelete(AppState.QuickPhraseFile, this._Section(id))
        catch
            return false

        contentPath := AppState.QuickPhraseContentDir "\" phrase.contentFile
        if FileExist(contentPath)
            try FileDelete(contentPath)

        this._phrases.RemoveAt(index)
        this._NormalizeOrders()
        return true
    }

    static Move(id, direction) {
        this._Sort()
        index := this._FindIndex(id)
        if !index
            return false

        target := index + direction
        if target < 1 || target > this._phrases.Length
            return false

        left := this._phrases[index]
        right := this._phrases[target]
        temp := left.order
        left.order := right.order
        right.order := temp

        this._Sort()
        this._PersistMetadata()
        return true
    }

    static _EnsureDirectories() {
        if !DirExist(A_ScriptDir "configs")
            DirCreate(A_ScriptDir "configs")
        if !DirExist(AppState.QuickPhraseContentDir)
            DirCreate(AppState.QuickPhraseContentDir)
    }

    static _NextId() {
        highest := 0
        for phrase in this._phrases
            highest := Max(highest, phrase.id)
        return highest + 1
    }

    static _FindIndex(id) {
        for index, phrase in this._phrases
            if phrase.id == id
                return index
        return 0
    }

    static _Section(id) => this.SectionPrefix id

    static _WriteContent(path, content) {
        file := ""
        try {
            file := FileOpen(path, "w", "UTF-8")
            if !IsObject(file)
                return false
            file.Write(content)
            file.Close()
            return true
        } catch {
            try file.Close()
            return false
        }
    }

    static _WriteMetadata(phrase) {
        this._EnsureDirectories()
        section := this._Section(phrase.id)
        IniWrite(phrase.name, AppState.QuickPhraseFile, section, "Name")
        IniWrite(phrase.category, AppState.QuickPhraseFile, section, "Category")
        IniWrite(phrase.order, AppState.QuickPhraseFile, section, "Order")
        IniWrite(phrase.contentFile, AppState.QuickPhraseFile, section, "ContentFile")
    }

    static _PersistMetadata() {
        for phrase in this._phrases
            this._WriteMetadata(phrase)
    }

    static _NormalizeOrders() {
        changed := false
        expected := 1
        for phrase in this._phrases {
            if phrase.order != expected {
                phrase.order := expected
                changed := true
            }
            expected += 1
        }
        if changed
            this._PersistMetadata()
    }

    static _Sort() {
        n := this._phrases.Length
        if n <= 1
            return

        Loop n - 1 {
            swapped := false
            limit := n - A_Index
            Loop limit {
                left := this._phrases[A_Index]
                right := this._phrases[A_Index + 1]
                if right.order < left.order
                    || (right.order == left.order && right.id < left.id) {
                    this._phrases[A_Index] := right
                    this._phrases[A_Index + 1] := left
                    swapped := true
                }
            }
            if !swapped
                break
        }
    }
}
