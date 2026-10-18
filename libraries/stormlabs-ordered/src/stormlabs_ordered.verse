# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API: ordered_entry(key,value), ordered_map(key,value), ordered_set(set_key).
# Factories: MakeMap, SingletonMap, MakeSet, SingletonSet. See ../API.md.
# Map/set: Count, Find, With, Insert, Remove, Clear, First, Last, LowerBound,
# UpperBound, Predecessor, Successor, Range. Map: GetEntry, Replace, Entries.
# Set: Contains, Elements. Entries expose immutable Key and Value.

Ordered<public> := module:
    ordered_entry<public>(key:type, value:type) := class<internal><final>:
        Key<public>:key
        Value<public>:value

    rb_node<internal>(key:type, value:type) := class<final>:
        Entry<internal>:ordered_entry(key, value)
        Red<internal>:logic = false
        Left<internal>:?rb_node(key, value) = false
        Right<internal>:?rb_node(key, value) = false
        Size<internal>:int = 1

    # Generic value semantics: updates path-copy nodes and never mutate a snapshot.
    ordered_map<public>(key:type, value:type) := class<internal><final>:
        Less<internal>:type {_(:key, :key)<computes><decides>:void}
        Root<internal>:?rb_node(key, value) = false

        Count<public>()<computes>:int =
            if (Node := Root?) then Node.Size else 0

        Locate<private>(Key:key)<transacts>:?ordered_entry(key, value) =
            var Current:?rb_node(key, value) = Root
            loop:
                if (Node := Current?):
                    if (Less[Key, Node.Entry.Key]):
                        set Current = Node.Left
                    else if (Less[Node.Entry.Key, Key]):
                        set Current = Node.Right
                    else:
                        return option{Node.Entry}
                else:
                    return false

        GetEntry<public>(Key:key)<transacts><decides>:ordered_entry(key, value) =
            Found := Locate(Key)
            Found?

        Find<public>(Key:key)<transacts><decides>:value =
            GetEntry[Key].Value

        SizeOf<private>(Part:?rb_node(key, value))<computes>:int =
            if (Node := Part?) then Node.Size else 0

        IsRed<private>(Part:?rb_node(key, value))<computes><decides>:void =
            Node := Part?
            Node.Red?

        NodeWith<private>(Entry:ordered_entry(key, value), Red:logic, Left:?rb_node(key, value), Right:?rb_node(key, value))<transacts>:rb_node(key, value) =
            rb_node(key, value):
                Entry := Entry
                Red := Red
                Left := Left
                Right := Right
                Size := 1 + SizeOf(Left) + SizeOf(Right)

        Paint<private>(Node:rb_node(key, value), Red:logic)<transacts>:rb_node(key, value) =
            NodeWith(Node.Entry, Red, Node.Left, Node.Right)

        RotateLeft<private>(Node:rb_node(key, value))<transacts>:rb_node(key, value) =
            # Callers establish a red right child before this rotation.
            if (Right := Node.Right?):
                Left := NodeWith(Node.Entry, true, Node.Left, Right.Left)
                return NodeWith(Right.Entry, Node.Red, option{Left}, Right.Right)
            return Node

        RotateRight<private>(Node:rb_node(key, value))<transacts>:rb_node(key, value) =
            # Callers establish a red left child before this rotation.
            if (Left := Node.Left?):
                Right := NodeWith(Node.Entry, true, Left.Right, Node.Right)
                return NodeWith(Left.Entry, Node.Red, Left.Left, option{Right})
            return Node

        FlipColors<private>(Node:rb_node(key, value))<transacts>:rb_node(key, value) =
            Left:?rb_node(key, value) = if (Child := Node.Left?) then option{Paint(Child, if (Child.Red?) then false else true)} else false
            Right:?rb_node(key, value) = if (Child := Node.Right?) then option{Paint(Child, if (Child.Red?) then false else true)} else false
            Red := if (Node.Red?) then false else true
            NodeWith(Node.Entry, Red, Left, Right)

        Balance<private>(Node:rb_node(key, value))<transacts>:rb_node(key, value) =
            # Repair a right red link, then a double left red link, then a 4-node.
            var Working:rb_node(key, value) = Node
            if (IsRed[Working.Right]):
                set Working = RotateLeft(Working)
            if:
                IsRed[Working.Left]
                Left := Working.Left?
                IsRed[Left.Left]
            then:
                set Working = RotateRight(Working)
            if (IsRed[Working.Left], IsRed[Working.Right]):
                set Working = FlipColors(Working)
            Working

        InsertNode<private>(Part:?rb_node(key, value), Key:key, Value:value)<transacts>:rb_node(key, value) =
            if (Node := Part?):
                if (Less[Key, Node.Entry.Key]):
                    Left := InsertNode(Node.Left, Key, Value)
                    return Balance(NodeWith(Node.Entry, Node.Red, option{Left}, Node.Right))
                if (Less[Node.Entry.Key, Key]):
                    Right := InsertNode(Node.Right, Key, Value)
                    return Balance(NodeWith(Node.Entry, Node.Red, Node.Left, option{Right}))
                # Equivalent keys replace only the value, preserving the key.
                Replacement := ordered_entry(key, value){Key := Node.Entry.Key, Value := Value}
                return NodeWith(Replacement, Node.Red, Node.Left, Node.Right)
            Added := ordered_entry(key, value){Key := Key, Value := Value}
            return NodeWith(Added, true, false, false)

        With<public>(Key:key, Value:value)<transacts>:ordered_map(key, value) =
            RootNode := Paint(InsertNode(Root, Key, Value), false)
            ordered_map(key, value){Less := Less, Root := option{RootNode}}

        Insert<public>(Key:key, Value:value)<transacts><decides>:ordered_map(key, value) =
            not GetEntry[Key]
            With(Key, Value)

        Replace<public>(Key:key, Value:value)<transacts><decides>:tuple(ordered_map(key, value), value) =
            Existing := GetEntry[Key]
            (With(Key, Value), Existing.Value)

        Clear<public>()<transacts>:ordered_map(key, value) =
            ordered_map(key, value){Less := Less}

        Minimum<private>(Node:rb_node(key, value))<transacts>:ordered_entry(key, value) =
            var Current:rb_node(key, value) = Node
            loop:
                if (Left := Current.Left?):
                    set Current = Left
                else:
                    return Current.Entry

        MoveRedLeft<private>(Node:rb_node(key, value))<transacts>:rb_node(key, value) =
            # Borrow through the sibling before descending into a black 2-node.
            var Working:rb_node(key, value) = FlipColors(Node)
            if (Right := Working.Right?, IsRed[Right.Left]):
                NewRight := RotateRight(Right)
                set Working = NodeWith(Working.Entry, Working.Red, Working.Left, option{NewRight})
                set Working = RotateLeft(Working)
                set Working = FlipColors(Working)
            Working

        MoveRedRight<private>(Node:rb_node(key, value))<transacts>:rb_node(key, value) =
            var Working:rb_node(key, value) = FlipColors(Node)
            if (Left := Working.Left?, IsRed[Left.Left]):
                set Working = RotateRight(Working)
                set Working = FlipColors(Working)
            Working

        DeleteMinimum<private>(Node:rb_node(key, value))<transacts>:?rb_node(key, value) =
            if (not Node.Left?):
                # A minimum with no left child has no right child in a valid LLRB.
                return false
            var Working:rb_node(key, value) = Node
            if (Left := Working.Left?):
                if (not IsRed[Working.Left], not IsRed[Left.Left]):
                    set Working = MoveRedLeft(Working)
            if (Left := Working.Left?):
                NextLeft := DeleteMinimum(Left)
                WorkingNode := NodeWith(Working.Entry, Working.Red, NextLeft, Working.Right)
                return option{Balance(WorkingNode)}
            return false

        DeleteNode<private>(Node:rb_node(key, value), Key:key)<transacts>:?rb_node(key, value) =
            # Remove establishes that the key exists before top-down rebalancing.
            var Working:rb_node(key, value) = Node
            if (Less[Key, Working.Entry.Key]):
                if (Left := Working.Left?):
                    if (not IsRed[Working.Left], not IsRed[Left.Left]):
                        set Working = MoveRedLeft(Working)
                if (Left := Working.Left?):
                    NextLeft := DeleteNode(Left, Key)
                    set Working = NodeWith(Working.Entry, Working.Red, NextLeft, Working.Right)
            else:
                if (IsRed[Working.Left]):
                    set Working = RotateRight(Working)
                if (not Less[Key, Working.Entry.Key], not Less[Working.Entry.Key, Key]):
                    if (not Working.Right?):
                        return false
                if (Right := Working.Right?):
                    if (not IsRed[Working.Right], not IsRed[Right.Left]):
                        set Working = MoveRedRight(Working)
                if (Right := Working.Right?):
                    if (not Less[Key, Working.Entry.Key], not Less[Working.Entry.Key, Key]):
                        Entry := Minimum(Right)
                        NextRight := DeleteMinimum(Right)
                        set Working = NodeWith(Entry, Working.Red, Working.Left, NextRight)
                    else:
                        NextRight := DeleteNode(Right, Key)
                        set Working = NodeWith(Working.Entry, Working.Red, Working.Left, NextRight)
            return option{Balance(Working)}

        Remove<public>(Key:key)<transacts><decides>:tuple(ordered_map(key, value), ordered_entry(key, value)) =
            Existing := GetEntry[Key]
            var Working:rb_node(key, value) = Root?
            if (not IsRed[Working.Left], not IsRed[Working.Right]):
                set Working = Paint(Working, true)
            Next := DeleteNode(Working, Key)
            BlackRoot:?rb_node(key, value) = if (Node := Next?) then option{Paint(Node, false)} else false
            (ordered_map(key, value){Less := Less, Root := BlackRoot}, Existing)

        First<public>()<transacts><decides>:ordered_entry(key, value) =
            Minimum(Root?)

        Maximum<private>(Node:rb_node(key, value))<transacts>:ordered_entry(key, value) =
            var Current:rb_node(key, value) = Node
            loop:
                if (Right := Current.Right?):
                    set Current = Right
                else:
                    return Current.Entry

        Last<public>()<transacts><decides>:ordered_entry(key, value) =
            Maximum(Root?)

        SeekAfter<private>(Key:key, Strict:logic)<transacts>:?ordered_entry(key, value) =
            var Current:?rb_node(key, value) = Root
            var Candidate:?ordered_entry(key, value) = false
            loop:
                if (Node := Current?):
                    if (Less[Key, Node.Entry.Key]):
                        set Candidate = option{Node.Entry}
                        set Current = Node.Left
                    else if (Less[Node.Entry.Key, Key]):
                        set Current = Node.Right
                    else if (Strict?):
                        set Current = Node.Right
                    else:
                        return option{Node.Entry}
                else:
                    return Candidate

        LowerBound<public>(Key:key)<transacts><decides>:ordered_entry(key, value) =
            Found := SeekAfter(Key, false)
            Found?

        UpperBound<public>(Key:key)<transacts><decides>:ordered_entry(key, value) =
            Found := SeekAfter(Key, true)
            Found?

        Successor<public>(Key:key)<transacts><decides>:ordered_entry(key, value) =
            UpperBound[Key]

        SeekBefore<private>(Key:key)<transacts>:?ordered_entry(key, value) =
            var Current:?rb_node(key, value) = Root
            var Candidate:?ordered_entry(key, value) = false
            loop:
                if (Node := Current?):
                    if (Less[Node.Entry.Key, Key]):
                        set Candidate = option{Node.Entry}
                        set Current = Node.Right
                    else:
                        set Current = Node.Left
                else:
                    return Candidate

        Predecessor<public>(Key:key)<transacts><decides>:ordered_entry(key, value) =
            Found := SeekBefore(Key)
            Found?

        Collect<private>(Part:?rb_node(key, value), Lower:?key, Upper:?key, MaxResults:int)<transacts>:[]ordered_entry(key, value) =
            if (MaxResults <= 0):
                return array{}
            if (Node := Part?):
                if (Bound := Lower?, Less[Node.Entry.Key, Bound]):
                    return Collect(Node.Right, Lower, Upper, MaxResults)
                if (Bound := Upper?, not Less[Node.Entry.Key, Bound]):
                    return Collect(Node.Left, Lower, Upper, MaxResults)
                Left := Collect(Node.Left, Lower, Upper, MaxResults)
                if (Left.Length >= MaxResults):
                    return Left
                Prefix := Left + array{Node.Entry}
                Right := Collect(Node.Right, Lower, Upper, MaxResults - Prefix.Length)
                return Prefix + Right
            return array{}

        Entries<public>()<transacts>:[]ordered_entry(key, value) =
            Collect(Root, false, false, Count())

        Range<public>(Lower:key, Upper:key, MaxResults:int)<transacts><decides>:[]ordered_entry(key, value) =
            # Half-open in comparator order; an explicit cap returns a prefix.
            MaxResults >= 0
            not Less[Upper, Lower]
            Collect(Root, option{Lower}, option{Upper}, MaxResults)

    ordered_set<public>(set_key:type) := class<internal><final>:
        Core<internal>:ordered_map(set_key, logic)

        Count<public>()<computes>:int =
            Core.Count()

        Find<public>(Element:set_key)<transacts><decides>:set_key =
            Core.GetEntry[Element].Key

        Contains<public>(Element:set_key)<transacts><decides>:void =
            Core.GetEntry[Element]

        With<public>(Element:set_key)<transacts>:ordered_set(set_key) =
            ordered_set(set_key){Core := Core.With(Element, true)}

        Insert<public>(Element:set_key)<transacts><decides>:ordered_set(set_key) =
            Next := Core.Insert[Element, true]
            ordered_set(set_key){Core := Next}

        Remove<public>(Element:set_key)<transacts><decides>:tuple(ordered_set(set_key), set_key) =
            Removed := Core.Remove[Element]
            (ordered_set(set_key){Core := Removed(0)}, Removed(1).Key)

        Clear<public>()<transacts>:ordered_set(set_key) =
            ordered_set(set_key){Core := Core.Clear()}

        Elements<public>()<transacts>:[]set_key =
            for (Entry : Core.Entries()) do Entry.Key

        First<public>()<transacts><decides>:set_key =
            Core.First[].Key

        Last<public>()<transacts><decides>:set_key =
            Core.Last[].Key

        LowerBound<public>(Element:set_key)<transacts><decides>:set_key =
            Core.LowerBound[Element].Key

        UpperBound<public>(Element:set_key)<transacts><decides>:set_key =
            Core.UpperBound[Element].Key

        Predecessor<public>(Element:set_key)<transacts><decides>:set_key =
            Core.Predecessor[Element].Key

        Successor<public>(Element:set_key)<transacts><decides>:set_key =
            Core.Successor[Element].Key

        Range<public>(Lower:set_key, Upper:set_key, MaxResults:int)<transacts><decides>:[]set_key =
            Entries := Core.Range[Lower, Upper, MaxResults]
            for (Entry : Entries) do Entry.Key

    MakeMap<public>(key:type, value:type, Less:type {_(:key, :key)<computes><decides>:void})<transacts>:ordered_map(key, value) =
        ordered_map(key, value){Less := Less}

    SingletonMap<public>(key:type, value:type, Key:key, Value:value, Less:type {_(:key, :key)<computes><decides>:void})<transacts>:ordered_map(key, value) =
        Entry := ordered_entry(key, value){Key := Key, Value := Value}
        ordered_map(key, value):
            Less := Less
            Root := option{rb_node(key, value){Entry := Entry}}

    MakeSet<public>(set_key:type, Less:type {_(:set_key, :set_key)<computes><decides>:void})<transacts>:ordered_set(set_key) =
        ordered_set(set_key){Core := MakeMap(set_key, logic, Less)}

    SingletonSet<public>(set_key:type, Element:set_key, Less:type {_(:set_key, :set_key)<computes><decides>:void})<transacts>:ordered_set(set_key) =
        ordered_set(set_key){Core := SingletonMap(set_key, logic, Element, true, Less)}
