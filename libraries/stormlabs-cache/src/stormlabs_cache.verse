# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API index: see ../API.md for signatures; ../README.md for validation status.
# - entry(key, value){Key, Value}; lru_cache(key, value), MakeLRUCache.
# - Count, Capacity, Peek, Get, Put, Remove, Clear, Snapshot.

Cache<public> := module:
    MaxCapacity<internal>:int = 2147483647
    StampLimit<internal>:int = 9223372036854775807

    entry<public>(key:type, value:type) := class<internal><final>:
        Key<public>:key
        Value<public>:value

    StampLess<internal>(Left:int, Right:int)<computes><decides>:void =
        Left < Right

    lru_cache<public>(key:type, value:type) := class<internal><final>:
        Limit<internal>:int
        Keys<internal>:Ordered.ordered_map(key, tuple(value, int))
        Order<internal>:Ordered.ordered_map(int, tuple(key, value))
        NextStamp<internal>:int = 0

        Count<public>()<transacts>:int =
            Keys.Count()

        Capacity<public>()<transacts>:int =
            Limit

        WithState<private>(NextKeys:Ordered.ordered_map(key, tuple(value, int)), NextOrder:Ordered.ordered_map(int, tuple(key, value)), Stamp:int)<transacts>:lru_cache(key, value) =
            lru_cache(key, value){Limit := Limit, Keys := NextKeys, Order := NextOrder, NextStamp := Stamp}

        # Both indexes retain one live record per resident and exact LRU order.
        Rebase<private>()<transacts>:lru_cache(key, value) =
            var NextKeys:Ordered.ordered_map(key, tuple(value, int)) = Keys.Clear()
            var NextOrder:Ordered.ordered_map(int, tuple(key, value)) = Order.Clear()
            var Stamp:int = 0
            for (Pair : Order.Entries()):
                Item := Pair.Value
                set NextKeys = NextKeys.With(Item(0), (Item(1), Stamp))
                set NextOrder = NextOrder.With(Stamp, Item)
                set Stamp += 1
            WithState(NextKeys, NextOrder, Stamp)

        Ready<private>()<transacts>:lru_cache(key, value) =
            if (NextStamp >= StampLimit) then Rebase() else Self

        AppendEntry<private>(Key:key, Value:value, Evicted:?entry(key, value))<transacts>:tuple(lru_cache(key, value), ?entry(key, value)) =
            NextKeys := Keys.With(Key, (Value, NextStamp))
            NextOrder := Order.With(NextStamp, (Key, Value))
            (WithState(NextKeys, NextOrder, NextStamp + 1), Evicted)

        Peek<public>(Key:key)<transacts><decides>:value =
            Pair := Keys.Find[Key]
            Pair(0)

        Get<public>(Key:key)<transacts><decides>:tuple(lru_cache(key, value), value) =
            Existing := Keys.GetEntry[Key]
            Updated := Put[Existing.Key, Existing.Value(0)]
            (Updated(0), Existing.Value(0))

        # GetEntry retains the representative key without native key equality.
        Put<public>(Key:key, Value:value)<transacts><decides>:tuple(lru_cache(key, value), ?entry(key, value)) =
            NoEviction:?entry(key, value) = false
            if (Limit = 0):
                Item := entry(key, value){Key := Key, Value := Value}
                (WithState(Keys, Order, NextStamp), option{Item})
            else:
                Prepared := Ready()
                if (Existing := Prepared.Keys.GetEntry[Key]):
                    Removed := Prepared.Order.Remove[Existing.Value(1)]
                    Changed := Prepared.WithState(Prepared.Keys, Removed(0), Prepared.NextStamp)
                    Changed.AppendEntry(Existing.Key, Value, NoEviction)
                else if (Prepared.Keys.Count() < Limit):
                    Prepared.AppendEntry(Key, Value, NoEviction)
                else:
                    Oldest := Prepared.Order.First[]
                    RemovedKey := Prepared.Keys.Remove[Oldest.Value(0)]
                    RemovedOrder := Prepared.Order.Remove[Oldest.Key]
                    Changed := Prepared.WithState(RemovedKey(0), RemovedOrder(0), Prepared.NextStamp)
                    Evicted := entry(key, value){Key := Oldest.Value(0), Value := Oldest.Value(1)}
                    Changed.AppendEntry(Key, Value, option{Evicted})

        Remove<public>(Key:key)<transacts><decides>:tuple(lru_cache(key, value), value) =
            Existing := Keys.GetEntry[Key]
            RemovedKey := Keys.Remove[Existing.Key]
            RemovedOrder := Order.Remove[Existing.Value(1)]
            (WithState(RemovedKey(0), RemovedOrder(0), NextStamp), Existing.Value(0))

        Clear<public>()<transacts>:lru_cache(key, value) =
            WithState(Keys.Clear(), Order.Clear(), 0)

        # Order carries both fields: no key lookup is added per snapshot result.
        Snapshot<public>()<transacts>:[]entry(key, value) =
            OrderedEntries := Order.Entries()
            if (OrderedEntries.Length = 0):
                array{}
            else:
                for (Index := 0..OrderedEntries.Length - 1, Pair := OrderedEntries[OrderedEntries.Length - 1 - Index]):
                    entry(key, value){Key := Pair.Value(0), Value := Pair.Value(1)}

    MakeLRUCache<public>(key:type, value:type, Capacity:int, Less:type{_(:key, :key)<computes><decides>:void})<transacts><decides>:lru_cache(key, value) =
        0 <= Capacity <= MaxCapacity
        Keys := Ordered.MakeMap(key, tuple(value, int), Less)
        Order := Ordered.MakeMap(int, tuple(key, value), StampLess)
        lru_cache(key, value){Limit := Capacity, Keys := Keys, Order := Order}
