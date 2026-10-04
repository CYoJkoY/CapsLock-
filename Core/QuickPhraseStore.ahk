#Requires AutoHotkey v2.0

class QuickPhraseStore {
    static SectionPrefix := "QuickPhrase_"
    static _phrases := []
    static _onChange := ""

    static Load() {
        this._EnsureDirectories()
        this._phrases := []

        if !FileExist(AppState.QuickPhraseFile) {
            this._NotifyChanged()
            return
        }

        try sections := IniRead(AppState.QuickPhraseFile, , , "")
        catch {
            this._NotifyChanged()
            return
        }

        for section in StrSplit(sections, Chr(10), Chr(13)) {
            section := Trim(section)
            if SubStr(section, 1, StrLen(this.SectionPrefix)) != this.SectionPrefix
                continue

            idText := SubStr(section, StrLen(this.SectionPrefix) + 1)
            if !(idText ~= "^\d+$")
                continue

            id := Integer(idText)
            name := IniRead(AppState.QuickPhraseFile, section, "Name", "")
            category := Trim(IniRead(AppState.QuickPhraseFile, section, "Category", ""))
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
        this._NotifyChanged()
    }

    static GetAll() => this._phrases

    static SetOnChange(callback) {
        this._onChange := IsObject(callback) ? callback : ""
    }

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
        this._NotifyChanged()
        this._NotifySyncDirty()
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
            this._WriteContent(contentPath, oldContent)
            return false
        }

        this._NotifyChanged()
        this._NotifySyncDirty()
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
        this._NotifyChanged()
        this._NotifySyncDirty()
        return true
    }

    static Move(id, direction) {
        if direction != -1 && direction != 1
            return false

        this._Sort()
        index := this._FindIndex(id)
        if !index
            return false

        phrase := this._phrases[index]
        category := phrase.category
        ; Reorder within the visible category group so the arrow buttons remain intuitive.
        target := index + direction
        count := this._phrases.Length

        while target >= 1 && target <= count {
            candidate := this._phrases[target]
            if StrCompare(category, candidate.category, false) == 0
                break
            target += direction
        }

        if target < 1 || target > count
            return false

        neighbor := this._phrases[target]
        temp := phrase.order
        phrase.order := neighbor.order
        neighbor.order := temp

        this._Sort()
        this._PersistMetadata()
        this._NotifyChanged()
        this._NotifySyncDirty()
        return true
    }

    static _NotifyChanged() {
        callback := this._onChange
        if !IsObject(callback)
            return

        try callback.Call()
    }

    static _NotifySyncDirty() {
        if AppState.CloudSyncApplying
            return

        CloudSyncCoordinator.MarkLocalChanged()
    }

    static _EnsureDirectories() {
        if !DirExist(A_ScriptDir "\configs")
            DirCreate(A_ScriptDir "\configs")
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
        myfile := ""
        try {
            myfile := FileOpen(path, "w", "UTF-8")
            if !IsObject(myfile)
                return false
            myfile.Write(content)
            myfile.Close()
            return true
        } catch {
            try myfile.Close()
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
        count := this._phrases.Length
        if count < 2
            return

        root := count // 2
        while root > 0 {
            this._SiftDown(root, count)
            root -= 1
        }

        heapEnd := count
        while heapEnd > 1 {
            this._Swap(1, heapEnd)
            heapEnd -= 1
            this._SiftDown(1, heapEnd)
        }
    }

    static _SiftDown(root, heapEnd) {
        while root * 2 <= heapEnd {
            child := root * 2
            if (
                child < heapEnd
                && this._CompareByOrder(this._phrases[child], this._phrases[child + 1]) < 0
            ) {
                child += 1
            }

            if this._CompareByOrder(this._phrases[root], this._phrases[child]) >= 0
                return

            this._Swap(root, child)
            root := child
        }
    }

    static _Swap(leftIndex, rightIndex) {
        temp := this._phrases[leftIndex]
        this._phrases[leftIndex] := this._phrases[rightIndex]
        this._phrases[rightIndex] := temp
    }

    static _CompareByOrder(left, right) {
        if left.order != right.order
            return left.order < right.order ? -1 : 1
        if left.id == right.id
            return 0
        return left.id < right.id ? -1 : 1
    }
}
