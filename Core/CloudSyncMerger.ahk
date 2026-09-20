#Requires AutoHotkey v2.0

class CloudSyncMerger {
    static Merge(base, localData, remoteData) {
        conflicts := []
        mergedConfig := this._MergeMap(
            IsObject(base) && base.Has("config") ? base["config"] : Map(),
            IsObject(local) && local.Has("config") ? local["config"] : Map(),
            IsObject(remote) && remote.Has("config") ? remote["config"] : Map(),
            "config",
            conflicts
        )

        basePhrases := IsObject(base) && base.Has("quickPhrases")
            ? base["quickPhrases"]
            : []
        localPhrases := IsObject(local) && local.Has("quickPhrases")
            ? local["quickPhrases"]
            : []
        remotePhrases := IsObject(remote) && remote.Has("quickPhrases")
            ? remote["quickPhrases"]
            : []

        mergedPhrases := this.MergeQuickPhrases(
            basePhrases,
            localPhrases,
            remotePhrases,
            conflicts
        )

        result := Map()
        result["config"] := mergedConfig
        result["quickPhrases"] := mergedPhrases

        return {
            ok: conflicts.Length == 0,
            value: result,
            conflicts: conflicts
        }
    }

    static MergeQuickPhrases(base, localData, remoteData, conflicts := "") {
        if !IsObject(conflicts)
            conflicts := []

        baseMap := this._IndexPhrases(base)
        localMap := this._IndexPhrases(local)
        remoteMap := this._IndexPhrases(remote)

        ids := Map()
        for id in baseMap
            ids[id] := true
        for id in localMap
            ids[id] := true
        for id in remoteMap
            ids[id] := true

        merged := []

        for id in ids {
            hasBase := baseMap.Has(id)
            hasLocal := localMap.Has(id)
            hasRemote := remoteMap.Has(id)

            baseItem := hasBase ? baseMap[id] : ""
            localItem := hasLocal ? localMap[id] : ""
            remoteItem := hasRemote ? remoteMap[id] : ""

            mergedItem := this._MergeValue(
                hasBase,
                baseItem,
                hasLocal,
                localItem,
                hasRemote,
                remoteItem,
                "quickPhrases[" id "]",
                conflicts
            )

            if mergedItem.Has("present") && mergedItem["present"]
                merged.Push(mergedItem["value"])
        }

        this._SortPhrases(merged)
        return merged
    }

    static _MergeMap(base, localData, remoteData, path, conflicts) {
        result := Map()
        keys := Map()

        if IsObject(base) && base is Map
            for key in base
                keys[key] := true
        if IsObject(local) && local is Map
            for key in local
                keys[key] := true
        if IsObject(remote) && remote is Map
            for key in remote
                keys[key] := true

        keyList := []
        for key in keys
            keyList.Push(String(key))
        this._SortStrings(keyList)

        for key in keyList {
            hasBase := IsObject(base) && base is Map && base.Has(key)
            hasLocal := IsObject(local) && local is Map && local.Has(key)
            hasRemote := IsObject(remote) && remote is Map && remote.Has(key)

            baseValue := hasBase ? base[key] : ""
            localValue := hasLocal ? local[key] : ""
            remoteValue := hasRemote ? remote[key] : ""

            mergedItem := this._MergeValue(
                hasBase,
                baseValue,
                hasLocal,
                localValue,
                hasRemote,
                remoteValue,
                path "." key,
                conflicts
            )

            if mergedItem.Has("present") && mergedItem["present"]
                result[key] := mergedItem["value"]
        }

        return result
    }

    static _MergeValue(
        hasBase,
        baseValue,
        hasLocal,
        localValue,
        hasRemote,
        remoteValue,
        path,
        conflicts
    ) {
        if hasLocal && hasRemote && this._Equals(localValue, remoteValue)
            return {present: true, value: localValue}

        if this._SameState(hasBase, baseValue, hasLocal, localValue)
            return hasRemote
                ? {present: true, value: remoteValue}
                : {present: false}

        if this._SameState(hasBase, baseValue, hasRemote, remoteValue)
            return hasLocal
                ? {present: true, value: localValue}
                : {present: false}

        if hasLocal && hasRemote
            && this._CanMergeMaps(localValue, remoteValue)
            && this._CanMergeMaps(baseValue, baseValue)
        {
            baseMap := hasBase && baseValue is Map ? baseValue : Map()
            nestedConflicts := []
            merged := this._MergeMap(
                baseMap,
                localValue,
                remoteValue,
                path,
                nestedConflicts
            )

            for item in nestedConflicts
                conflicts.Push(item)

            if nestedConflicts.Length == 0
                return {present: true, value: merged}
        }

        conflicts.Push({
            path: path,
            base: hasBase ? baseValue : "",
            local: hasLocal ? localValue : "",
            remote: hasRemote ? remoteValue : ""
        })

        return {present: hasLocal, value: localValue}
    }

    static _SameState(hasA, valueA, hasB, valueB) {
        if !hasA && !hasB
            return true
        if hasA != hasB
            return false
        return this._Equals(valueA, valueB)
    }

    static _CanMergeMaps(valueA, valueB) {
        return IsObject(valueA)
            && IsObject(valueB)
            && valueA is Map
            && valueB is Map
    }

    static _Equals(valueA, valueB) {
        if IsObject(valueA) || IsObject(valueB)
            return Json.Stringify(valueA, false) == Json.Stringify(valueB, false)
        return valueA === valueB
    }

    static _IndexPhrases(phrases) {
        result := Map()

        if !IsObject(phrases) || !(phrases is Array)
            return result

        for item in phrases {
            if !IsObject(item) || !(item is Map)
                continue
            if !item.Has("id")
                continue

            id := String(item["id"])
            if !(id ~= "^\d+$") || id == "0"
                continue

            result[id] := item
        }

        return result
    }

    static _SortPhrases(arr) {
        n := arr.Length
        if n <= 1
            return

        Loop n - 1 {
            swapped := false
            Loop n - A_Index {
                left := arr[A_Index]
                right := arr[A_Index + 1]

                leftOrder := left.Has("order") ? Integer(left["order"]) : 0
                rightOrder := right.Has("order") ? Integer(right["order"]) : 0
                leftId := left.Has("id") ? Integer(left["id"]) : 0
                rightId := right.Has("id") ? Integer(right["id"]) : 0

                if rightOrder < leftOrder
                    || (rightOrder == leftOrder && rightId < leftId)
                {
                    arr[A_Index] := right
                    arr[A_Index + 1] := left
                    swapped := true
                }
            }
            if !swapped
                break
        }
    }

    static _SortStrings(arr) {
        n := arr.Length
        if n <= 1
            return

        Loop n - 1 {
            swapped := false
            Loop n - A_Index {
                if StrCompare(arr[A_Index], arr[A_Index + 1]) > 0 {
                    temp := arr[A_Index]
                    arr[A_Index] := arr[A_Index + 1]
                    arr[A_Index + 1] := temp
                    swapped := true
                }
            }
            if !swapped
                break
        }
    }
}
