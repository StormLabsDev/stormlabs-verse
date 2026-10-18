# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API index (full signatures and contracts: ../API.md).
# Type: disjoint_set(t). Factory: MakeDisjointSet (default/positional limit).
# Operations: Count, ComponentCount, MaxCount, Contains, Clear, Elements,
# Add, Find, ComponentSize, Connected, Union. Requires Ordered.
# Immutable updates; Find/ComponentSize/Connected return updated set first.

using { Ordered }

DisjointSet<public> := module:
    MaxElements<internal>:int = 2147483647

    IndexLess<internal>(A:int, B:int)<computes><decides>:void =
        A < B

    # Immutable values. Key equivalence is defined by the ordered index's Less.
    disjoint_set<public>(t:type) := class<internal><final>:
        Index<internal>:Ordered.ordered_map(t, int)
        # Each entry is (canonical value, parent insertion index, root size).
        Nodes<internal>:Ordered.ordered_map(int, tuple(t, int, int))
        Groups<internal>:int = 0
        Limit<internal>:int

        Count<public>()<computes>:int =
            Index.Count()

        ComponentCount<public>()<computes>:int =
            Groups

        MaxCount<public>()<computes>:int =
            Limit

        Contains<public>(Value:t)<transacts><decides>:void =
            Found := Index.Find[Value]

        Clear<public>()<transacts>:disjoint_set(t) =
            disjoint_set(t){Index := Index.Clear(), Nodes := Nodes.Clear(), Limit := Limit}

        Elements<public>()<transacts>:[]t =
            for (Entry : Nodes.Entries()):
                Node := Entry.Value
                Node(0)

        Add<public>(Value:t)<transacts><decides>:disjoint_set(t) =
            if (Existing := Index.Find[Value]):
                disjoint_set(t){Index := Index, Nodes := Nodes, Groups := Groups, Limit := Limit}
            else:
                Count() < Limit
                Id := Count()
                NextIndex := Index.With(Value, Id)
                Node := (Value, Id, 1)
                NextNodes := Nodes.With(Id, Node)
                disjoint_set(t){Index := NextIndex, Nodes := NextNodes, Groups := Groups + 1, Limit := Limit}

        # Follow the original path, then redirect every non-direct parent to root.
        FindIndex<private>(Start:int)<transacts><decides>:tuple(disjoint_set(t), int) =
            var Root:int = Start
            var Steps:int = 0
            var Valid:logic = true
            loop:
                if (Steps < Count(), Node := Nodes.Find[Root]):
                    if (Node(1) = Root):
                        break
                    set Root = Node(1)
                    set Steps += 1
                else:
                    set Valid = false
                    break
            Valid?
            var Working:Ordered.ordered_map(int, tuple(t, int, int)) = Nodes
            var Current:int = Start
            loop:
                if (Current = Root):
                    break
                if (Node := Nodes.Find[Current]):
                    if (Node(1) <> Root):
                        Compressed := (Node(0), Root, 0)
                        set Working = Working.With(Current, Compressed)
                    set Current = Node(1)
                else:
                    set Valid = false
                    break
            Valid?
            Result := disjoint_set(t){Index := Index, Nodes := Working, Groups := Groups, Limit := Limit}
            (Result, Root)

        Find<public>(Value:t)<transacts><decides>:tuple(disjoint_set(t), t) =
            Id := Index.Find[Value]
            Located := FindIndex[Id]
            Root := Located(0).Nodes.Find[Located(1)]
            (Located(0), Root(0))

        ComponentSize<public>(Value:t)<transacts><decides>:tuple(disjoint_set(t), int) =
            Id := Index.Find[Value]
            Located := FindIndex[Id]
            Root := Located(0).Nodes.Find[Located(1)]
            (Located(0), Root(2))

        Connected<public>(A:t, B:t)<transacts><decides>:tuple(disjoint_set(t), logic) =
            FirstId := Index.Find[A]
            SecondId := Index.Find[B]
            First := FindIndex[FirstId]
            Second := First(0).FindIndex[SecondId]
            (Second(0), logic{First(1) = Second(1)})

        Union<public>(A:t, B:t)<transacts><decides>:disjoint_set(t) =
            FirstId := Index.Find[A]
            SecondId := Index.Find[B]
            First := FindIndex[FirstId]
            Second := First(0).FindIndex[SecondId]
            Current := Second(0)
            AId := First(1)
            BId := Second(1)
            if (AId = BId):
                Current
            else:
                ANode := Current.Nodes.Find[AId]
                BNode := Current.Nodes.Find[BId]
                var WinnerId:int = AId
                var LoserId:int = BId
                var Winner:tuple(t, int, int) = ANode
                var Loser:tuple(t, int, int) = BNode
                if (BNode(2) > ANode(2)):
                    set WinnerId = BId
                    set LoserId = AId
                    set Winner = BNode
                    set Loser = ANode
                else if (BNode(2) = ANode(2), BId < AId):
                    set WinnerId = BId
                    set LoserId = AId
                    set Winner = BNode
                    set Loser = ANode
                Joined := (Winner(0), WinnerId, ANode(2) + BNode(2))
                Child := (Loser(0), WinnerId, 0)
                WithChild := Current.Nodes.With(LoserId, Child)
                NextNodes := WithChild.With(WinnerId, Joined)
                disjoint_set(t){Index := Index, Nodes := NextNodes, Groups := Groups - 1, Limit := Limit}

    MakeDisjointSet<public>(t:type, Less:type{_(:t, :t)<computes><decides>:void})<transacts><decides>:disjoint_set(t) =
        Index := Ordered.MakeMap(t, int, Less)
        Nodes := Ordered.MakeMap(int, tuple(t, int, int), IndexLess)
        disjoint_set(t){Index := Index, Nodes := Nodes, Limit := MaxElements}

    MakeDisjointSet<public>(t:type, Less:type{_(:t, :t)<computes><decides>:void}, MaxCount:int)<transacts><decides>:disjoint_set(t) =
        0 <= MaxCount <= MaxElements
        Index := Ordered.MakeMap(t, int, Less)
        Nodes := Ordered.MakeMap(int, tuple(t, int, int), IndexLess)
        disjoint_set(t){Index := Index, Nodes := Nodes, Limit := MaxCount}
