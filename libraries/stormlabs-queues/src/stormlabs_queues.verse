# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API index (full signatures and contracts: ../API.md).
# Types: stack(t), priority_queue(t), deque(t). Factories: MakeStack,
# MakePriorityQueue (2 overloads), Heapify (2 overloads), MakeDeque,
# DequeFromArray. All: Count, MaxCount, Clear. Stack: Peek, Push, Pop, ToArray.
# Heap: Peek, HeapSnapshot, Push, Pop. Deque: Capacity, Get, Front, Back,
# ToArray, Reserve, PushFront, PushBack, PopFront, PopBack.
# Updates return new values; Pop returns (updated container, element).

Queues<public> := module:
    MaxCapacity<internal>:int = 2147483647

    # A persistent tail shared by immutable stack snapshots.
    stack_node<internal>(t:type) := class<final>:
        Value<internal>:t
        Next<internal>:?stack_node(t) = false

    stack<public>(t:type) := class<internal><final>:
        Head<internal>:?stack_node(t) = false
        Length<internal>:int = 0
        Limit<internal>:int

        Count<public>()<transacts>:int =
            Length

        MaxCount<public>()<transacts>:int =
            Limit

        Peek<public>()<transacts><decides>:t =
            Node := Head?
            Node.Value

        Push<public>(Value:t)<transacts><decides>:stack(t) =
            Length < Limit
            Node := stack_node(t){Value := Value, Next := Head}
            stack(t){Head := option{Node}, Length := Length + 1, Limit := Limit}

        Pop<public>()<transacts><decides>:tuple(stack(t), t) =
            Node := Head?
            (stack(t){Head := Node.Next, Length := Length - 1, Limit := Limit}, Node.Value)

        Clear<public>()<transacts>:stack(t) =
            stack(t){Limit := Limit}

        # Top to bottom. Traverse iteratively, without recursive call depth.
        ToArray<public>()<transacts><decides>:[]t =
            var Current:?stack_node(t) = Head
            if (Length > 0):
                Values := for (Index := 0..Length - 1):
                    Node := Current?
                    set Current = Node.Next
                    Node.Value
                Values.Length = Length
                Values
            else:
                array{}

    MakeStack<public>(t:type, ?MaxCount:int = 2147483647)<transacts><decides>:stack(t) =
        0 <= MaxCount <= MaxCapacity
        stack(t){Limit := MaxCount}

    # Immutable generic value. Before succeeds when left has higher priority.
    priority_queue<public>(t:type) := class<internal><final>:
        Items<internal>:[]t = array{}
        Before<internal>:type{_(:t, :t)<computes><decides>:void}
        Limit<internal>:int

        Count<public>()<transacts>:int =
            Items.Length

        MaxCount<public>()<transacts>:int =
            Limit

        Peek<public>()<transacts><decides>:t =
            Items[0]

        # Heap layout, not sorted order. Elements themselves are shallow copies.
        HeapSnapshot<public>()<transacts>:[]t =
            Items

        Clear<public>()<transacts>:priority_queue(t) =
            priority_queue(t){Before := Before, Limit := Limit}

        SiftDown<private>(Data:[]t, Start:int)<transacts><decides>:[]t =
            var Working:[]t = Data
            var Index:int = Start
            var Valid:logic = true
            loop:
                Left := Index * 2 + 1
                if (Left >= Working.Length):
                    break
                if (LeftValue := Working[Left], ParentValue := Working[Index]):
                    var Best:int = Left
                    var BestValue:t = LeftValue
                    Right := Left + 1
                    if (Right < Working.Length):
                        if (RightValue := Working[Right]):
                            if (Before[RightValue, BestValue]):
                                set Best = Right
                                set BestValue = RightValue
                        else:
                            set Valid = false
                            break
                    if (Before[BestValue, ParentValue]):
                        if (set Working[Index] = BestValue, set Working[Best] = ParentValue):
                            set Index = Best
                        else:
                            set Valid = false
                            break
                    else:
                        break
                else:
                    set Valid = false
                    break
            Valid?
            Working

        Rebuild<internal>()<transacts><decides>:priority_queue(t) =
            var Working:[]t = Items
            ParentCount := Quotient[Items.Length, 2]
            if (ParentCount > 0):
                for (Step := 0..ParentCount - 1):
                    Next := SiftDown[Working, ParentCount - Step - 1]
                    set Working = Next
            priority_queue(t){Items := Working, Before := Before, Limit := Limit}

        Push<public>(Value:t)<transacts><decides>:priority_queue(t) =
            Items.Length < Limit
            var Working:[]t = Items + array{Value}
            var Index:int = Items.Length
            var Valid:logic = true
            loop:
                if (Index = 0):
                    break
                if:
                    Parent := Quotient[Index - 1, 2]
                    ChildValue := Working[Index]
                    ParentValue := Working[Parent]
                then:
                    if (Before[ChildValue, ParentValue]):
                        if (set Working[Index] = ParentValue, set Working[Parent] = ChildValue):
                            set Index = Parent
                        else:
                            set Valid = false
                            break
                    else:
                        break
                else:
                    set Valid = false
                    break
            Valid?
            priority_queue(t){Items := Working, Before := Before, Limit := Limit}

        Pop<public>()<transacts><decides>:tuple(priority_queue(t), t) =
            Value := Peek[]
            if (Items.Length = 1):
                (Clear(), Value)
            else:
                Last := Items[Items.Length - 1]
                var Working:[]t = for (Index := 0..Items.Length - 2) do Items[Index]
                set Working[0] = Last
                Next := SiftDown[Working, 0]
                (priority_queue(t){Items := Next, Before := Before, Limit := Limit}, Value)

    MakePriorityQueue<public>(t:type, Before:type{_(:t, :t)<computes><decides>:void})<transacts><decides>:priority_queue(t) =
        priority_queue(t){Before := Before, Limit := MaxCapacity}

    MakePriorityQueue<public>(t:type, Before:type{_(:t, :t)<computes><decides>:void}, MaxCount:int)<transacts><decides>:priority_queue(t) =
        0 <= MaxCount <= MaxCapacity
        priority_queue(t){Before := Before, Limit := MaxCount}

    # Bottom-up heap construction, with no sorting or per-type specialization.
    Heapify<public>(t:type, Data:[]t, Before:type{_(:t, :t)<computes><decides>:void})<transacts><decides>:priority_queue(t) =
        Data.Length <= MaxCapacity
        Queue := priority_queue(t){Items := Data, Before := Before, Limit := MaxCapacity}
        Queue.Rebuild[]

    Heapify<public>(t:type, Data:[]t, Before:type{_(:t, :t)<computes><decides>:void}, MaxCount:int)<transacts><decides>:priority_queue(t) =
        0 <= Data.Length <= MaxCount <= MaxCapacity
        Queue := priority_queue(t){Items := Data, Before := Before, Limit := MaxCount}
        Queue.Rebuild[]

    # Immutable ring snapshot. No default t value or comparable bound is needed.
    deque<public>(t:type) := class<internal><final>:
        Slots<internal>:[]?t
        Head<internal>:int
        Length<internal>:int
        Limit<internal>:int

        Count<public>()<transacts>:int =
            Length

        Capacity<public>()<transacts>:int =
            Slots.Length

        MaxCount<public>()<transacts>:int =
            Limit

        Clear<public>()<transacts>:deque(t) =
            Empty:?t = false
            Cleared := for (Slot : Slots) do Empty
            deque(t){Slots := Cleared, Head := 0, Length := 0, Limit := Limit}

        Get<public>(Index:int)<transacts><decides>:t =
            0 <= Index < Length
            Slot := Mod[Head + Index, Capacity()]
            Slots[Slot]?

        Front<public>()<transacts><decides>:t =
            Get[0]

        Back<public>()<transacts><decides>:t =
            Get[Length - 1]

        ToArray<public>()<transacts><decides>:[]t =
            if (Length > 0):
                for (Index := 0..Length - 1) do Get[Index]
            else:
                array{}

        # Reserve never shrinks and never discards an element.
        Reserve<public>(RequestedCapacity:int)<transacts><decides>:deque(t) =
            0 <= RequestedCapacity <= Limit
            if (RequestedCapacity > Capacity()):
                Empty:?t = false
                Grown := for (Index := 0..RequestedCapacity - 1):
                    if (Index < Length):
                        Slot := Mod[Head + Index, Capacity()]
                        Slots[Slot]
                    else:
                        Empty
                deque(t){Slots := Grown, Head := 0, Length := Length, Limit := Limit}
            else:
                deque(t){Slots := Slots, Head := Head, Length := Length, Limit := Limit}

        PushBack<public>(Value:t)<transacts><decides>:deque(t) =
            Length < Limit
            Required := if (Length = Capacity()) then Min(Limit, Max(4, Capacity() * 2)) else Capacity()
            Current := Reserve[Required]
            var Working:[]?t = Current.Slots
            Index := Mod[Current.Head + Length, Working.Length]
            set Working[Index] = option{Value}
            deque(t){Slots := Working, Head := Current.Head, Length := Length + 1, Limit := Limit}

        PushFront<public>(Value:t)<transacts><decides>:deque(t) =
            Length < Limit
            Required := if (Length = Capacity()) then Min(Limit, Max(4, Capacity() * 2)) else Capacity()
            Current := Reserve[Required]
            var Working:[]?t = Current.Slots
            Index := Mod[Current.Head + Working.Length - 1, Working.Length]
            set Working[Index] = option{Value}
            deque(t){Slots := Working, Head := Index, Length := Length + 1, Limit := Limit}

        PopFront<public>()<transacts><decides>:tuple(deque(t), t) =
            Value := Front[]
            var Working:[]?t = Slots
            set Working[Head] = false
            NextHead := if (Length = 1) then 0 else Mod[Head + 1, Capacity()]
            (deque(t){Slots := Working, Head := NextHead, Length := Length - 1, Limit := Limit}, Value)

        PopBack<public>()<transacts><decides>:tuple(deque(t), t) =
            Value := Back[]
            Index := Mod[Head + Length - 1, Capacity()]
            var Working:[]?t = Slots
            set Working[Index] = false
            NextHead := if (Length = 1) then 0 else Head
            (deque(t){Slots := Working, Head := NextHead, Length := Length - 1, Limit := Limit}, Value)

    MakeDeque<public>(t:type, ?InitialCapacity:int = 0, ?MaxCount:int = 2147483647)<transacts><decides>:deque(t) =
        0 <= InitialCapacity <= MaxCount <= MaxCapacity
        Empty:?t = false
        var Slots:[]?t = array{}
        if (InitialCapacity > 0):
            set Slots = for (Index := 0..InitialCapacity - 1) do Empty
        deque(t){Slots := Slots, Head := 0, Length := 0, Limit := MaxCount}

    DequeFromArray<public>(t:type, Data:[]t, ?InitialCapacity:int = 0, ?MaxCount:int = 2147483647)<transacts><decides>:deque(t) =
        0 <= InitialCapacity <= MaxCount <= MaxCapacity
        Data.Length <= MaxCount
        Capacity := Max(InitialCapacity, Data.Length)
        Empty:?t = false
        var Slots:[]?t = array{}
        if (Capacity > 0):
            set Slots = for (Index := 0..Capacity - 1):
                if (Index < Data.Length) then option{Data[Index]} else Empty
        deque(t){Slots := Slots, Head := 0, Length := Data.Length, Limit := MaxCount}
