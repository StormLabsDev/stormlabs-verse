# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API index: see ../API.md for signatures; ../README.md for validation status.
# - ordered_buffer(t){Values, Less}: Count, Get, LowerBound, UpperBound, BinarySearch, EqualRange, ValidateOrder.

Search<public> := module:
    # A value-array snapshot, not a deep copy of class-valued elements.
    ordered_buffer<public>(t:type) := class<final>:
        Values<public>:[]t
        Less<public>:type{_(:t, :t)<computes><decides>:void}

        Count<public>()<transacts>:int =
            Values.Length

        Get<public>(Index:int)<transacts><decides>:t =
            Values[Index]

        # First index whose element does not precede Value, or Count().
        LowerBound<public>(Value:t)<transacts><decides>:int =
            var Low:int = 0
            var High:int = Values.Length
            var IsValid:logic = true
            loop:
                if (Low >= High):
                    break
                if (Half := Quotient[High - Low, 2], Element := Values[Low + Half]):
                    Middle := Low + Half
                    if (Less[Element, Value]):
                        set Low = Middle + 1
                    else:
                        set High = Middle
                else:
                    set IsValid = false
                    break
            IsValid?
            Low

        # First index whose element follows Value, or Count().
        UpperBound<public>(Value:t)<transacts><decides>:int =
            var Low:int = 0
            var High:int = Values.Length
            var IsValid:logic = true
            loop:
                if (Low >= High):
                    break
                if (Half := Quotient[High - Low, 2], Element := Values[Low + Half]):
                    Middle := Low + Half
                    if (Less[Value, Element]):
                        set High = Middle
                    else:
                        set Low = Middle + 1
                else:
                    set IsValid = false
                    break
            IsValid?
            Low

        # First comparator-equivalent element; ordinary failure when absent.
        BinarySearch<public>(Value:t)<transacts><decides>:int =
            Index := LowerBound[Value]
            Element := Values[Index]
            not Less[Element, Value]
            not Less[Value, Element]
            Index

        # [Lower, Upper); missing values produce an empty insertion range.
        EqualRange<public>(Value:t)<transacts><decides>:tuple(int, int) =
            Lower := LowerBound[Value]
            Upper := UpperBound[Value]
            (Lower, Upper)

        # Optional O(n) check of adjacent inversions, not comparator-law proof.
        ValidateOrder<public>()<transacts><decides>:void =
            if (Values.Length > 1):
                for (Index := 1..Values.Length - 1):
                    not Less[Values[Index], Values[Index - 1]]
