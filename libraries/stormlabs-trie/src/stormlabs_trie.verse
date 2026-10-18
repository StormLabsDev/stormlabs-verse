# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API: trie_entry(token,value), trie(token,value), MakeTrie. See ../API.md.
# Trie: Count, GetEntry, Find, Contains, With, Insert, Replace, Remove, Clear,
# PrefixCount, Enumerate. Entries expose immutable Key and Value.

Trie<public> := module:
    trie_entry<public>(token:type, value:type) := class<internal><final>:
        Key<public>:[]token
        Value<public>:value

    trie_node<internal>(token:type, value:type) := class<final>:
        Terminal<internal>:?trie_entry(token, value) = false
        Tokens<internal>:[]token = array{}
        Children<internal>:[]trie_node(token, value) = array{}
        Count<internal>:int = 0

    # Temporary immutable path frames keep key-length recursion off the stack.
    trie_path<internal>(token:type, value:type) := class<final>:
        Parent<internal>:trie_node(token, value)
        Token<internal>:token
        Previous<internal>:?trie_path(token, value) = false

    trie_cursor<internal>(token:type, value:type) := class<final>:
        Parent<internal>:trie_node(token, value)
        Next<internal>:int
        Previous<internal>:?trie_cursor(token, value) = false

    trie<public>(token:type, value:type) := class<internal><final>:
        Less<internal>:type {_(:token, :token)<computes><decides>:void}
        Root<internal>:trie_node(token, value)

        Count<public>()<computes>:int =
            Root.Count

        EmptyNode<private>()<transacts>:trie_node(token, value) =
            trie_node(token, value){}

        Lower<private>(Node:trie_node(token, value), Token:token)<transacts>:int =
            var Low:int = 0
            var High:int = Node.Tokens.Length
            loop:
                if (Low >= High):
                    break
                Middle := Low + (Quotient[High - Low, 2] or 0)
                if (Stored := Node.Tokens[Middle], Less[Stored, Token]):
                    set Low = Middle + 1
                else:
                    set High = Middle
            Low

        ChildIndex<private>(Node:trie_node(token, value), Token:token)<transacts><decides>:int =
            Index := Lower(Node, Token)
            Stored := Node.Tokens[Index]
            not Less[Stored, Token]
            not Less[Token, Stored]
            Index

        Child<private>(Node:trie_node(token, value), Token:token)<transacts><decides>:trie_node(token, value) =
            Index := ChildIndex[Node, Token]
            Node.Children[Index]

        # Keep token representatives on replacement. Insertion copies both arrays.
        WithChild<private>(Parent:trie_node(token, value), Token:token, Next:trie_node(token, value), Delta:int)<transacts>:trie_node(token, value) =
            Position := Lower(Parent, Token)
            if (Stored := Parent.Tokens[Position], not Less[Stored, Token], not Less[Token, Stored]):
                ReplacedChildren := for (Index -> Previous : Parent.Children):
                    if (Index = Position) then Next else Previous
                return trie_node(token, value){Terminal := Parent.Terminal, Tokens := Parent.Tokens, Children := ReplacedChildren, Count := Parent.Count + Delta}
            LeftTokens := for (Index -> PreviousToken : Parent.Tokens, Index < Position) do PreviousToken
            RightTokens := for (Index -> PreviousToken : Parent.Tokens, Index >= Position) do PreviousToken
            LeftChildren := for (Index -> PreviousChild : Parent.Children, Index < Position) do PreviousChild
            RightChildren := for (Index -> PreviousChild : Parent.Children, Index >= Position) do PreviousChild
            return trie_node(token, value):
                Terminal := Parent.Terminal
                Tokens := LeftTokens + array{Token} + RightTokens
                Children := LeftChildren + array{Next} + RightChildren
                Count := Parent.Count + Delta

        WithoutChild<private>(Parent:trie_node(token, value), Token:token)<transacts><decides>:trie_node(token, value) =
            Position := ChildIndex[Parent, Token]
            Tokens := for (Index -> Stored : Parent.Tokens, Index <> Position) do Stored
            Children := for (Index -> Previous : Parent.Children, Index <> Position) do Previous
            trie_node(token, value){Terminal := Parent.Terminal, Tokens := Tokens, Children := Children, Count := Parent.Count - 1}

        LocateNode<private>(Key:[]token)<transacts>:?trie_node(token, value) =
            var Current:trie_node(token, value) = Root
            for (Token : Key):
                if (Found := Child[Current, Token]):
                    set Current = Found
                else:
                    return false
            return option{Current}

        GetEntry<public>(Key:[]token)<transacts><decides>:trie_entry(token, value) =
            Found := LocateNode(Key)
            Node := Found?
            Node.Terminal?

        Find<public>(Key:[]token)<transacts><decides>:value =
            GetEntry[Key].Value

        Contains<public>(Key:[]token)<transacts><decides>:void =
            GetEntry[Key]

        With<public>(Key:[]token, Value:value)<transacts>:trie(token, value) =
            var Current:trie_node(token, value) = Root
            var Path:?trie_path(token, value) = false
            for (Token : Key):
                set Path = option{trie_path(token, value){Parent := Current, Token := Token, Previous := Path}}
                if (Found := Child[Current, Token]):
                    set Current = Found
                else:
                    set Current = EmptyNode()
            Representative := if (Stored := Current.Terminal?) then Stored.Key else Key
            NewEntry := trie_entry(token, value){Key := Representative, Value := Value}
            Added := if (Current.Terminal?) then 0 else 1
            var Next:trie_node(token, value) = trie_node(token, value):
                Terminal := option{NewEntry}
                Tokens := Current.Tokens
                Children := Current.Children
                Count := Current.Count + Added
            loop:
                if (Frame := Path?):
                    set Next = WithChild(Frame.Parent, Frame.Token, Next, Added)
                    set Path = Frame.Previous
                else:
                    break
            trie(token, value){Less := Less, Root := Next}

        Insert<public>(Key:[]token, Value:value)<transacts><decides>:trie(token, value) =
            not GetEntry[Key]
            With(Key, Value)

        Replace<public>(Key:[]token, Value:value)<transacts><decides>:tuple(trie(token, value), value) =
            Existing := GetEntry[Key]
            (With(Key, Value), Existing.Value)

        Remove<public>(Key:[]token)<transacts><decides>:tuple(trie(token, value), trie_entry(token, value)) =
            var Current:trie_node(token, value) = Root
            var Path:?trie_path(token, value) = false
            var Missing:logic = false
            for (Token : Key):
                if (not Missing?):
                    if (Found := Child[Current, Token]):
                        set Path = option{trie_path(token, value){Parent := Current, Token := Token, Previous := Path}}
                        set Current = Found
                    else:
                        set Missing = true
            not Missing?
            Existing := Current.Terminal?
            var Next:trie_node(token, value) = trie_node(token, value):
                Tokens := Current.Tokens
                Children := Current.Children
                Count := Current.Count - 1
            loop:
                if (Frame := Path?):
                    Parent := Frame.Parent
                    if (Next.Count = 0):
                        if (Pruned := WithoutChild[Parent, Frame.Token]):
                            set Next = Pruned
                        else:
                            set Missing = true
                            break
                    else:
                        set Next = WithChild(Parent, Frame.Token, Next, -1)
                    set Path = Frame.Previous
                else:
                    break
            not Missing?
            (trie(token, value){Less := Less, Root := Next}, Existing)

        Clear<public>()<transacts>:trie(token, value) =
            trie(token, value){Less := Less, Root := EmptyNode()}

        PrefixCount<public>(Prefix:[]token)<transacts>:int =
            Found := LocateNode(Prefix)
            if (Node := Found?) then Node.Count else 0

        Collect<private>(Start:trie_node(token, value), MaxResults:int)<transacts>:[]trie_entry(token, value) =
            if (MaxResults <= 0):
                return array{}
            var Output:[]trie_entry(token, value) = array{}
            var Current:?trie_node(token, value) = option{Start}
            var Stack:?trie_cursor(token, value) = false
            loop:
                if (Node := Current?):
                    if (Entry := Node.Terminal?):
                        set Output += array{Entry}
                        if (Output.Length >= MaxResults):
                            return Output
                    if (FirstChild := Node.Children[0]):
                        FirstCursor := trie_cursor(token, value):
                            Parent := Node
                            Next := 1
                            Previous := Stack
                        set Stack = option{FirstCursor}
                        set Current = option{FirstChild}
                    else:
                        set Current = false
                else if (Cursor := Stack?):
                    if (NextChild := Cursor.Parent.Children[Cursor.Next]):
                        FollowingCursor := trie_cursor(token, value):
                            Parent := Cursor.Parent
                            Next := Cursor.Next + 1
                            Previous := Cursor.Previous
                        set Stack = option{FollowingCursor}
                        set Current = option{NextChild}
                    else:
                        set Stack = Cursor.Previous
                else:
                    return Output

        # Return the first MaxResults entries in lexicographic token order.
        # PrefixCount(Prefix) > result.Length explicitly identifies truncation.
        Enumerate<public>(Prefix:[]token, MaxResults:int)<transacts><decides>:[]trie_entry(token, value) =
            MaxResults >= 0
            Found := LocateNode(Prefix)
            if (Node := Found?):
                Collect(Node, MaxResults)
            else:
                array{}

    MakeTrie<public>(token:type, value:type, Less:type {_(:token, :token)<computes><decides>:void})<transacts>:trie(token, value) =
        Root := trie_node(token, value){}
        trie(token, value){Less := Less, Root := Root}
