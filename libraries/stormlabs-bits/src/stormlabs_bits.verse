# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API index (full signatures and contracts: ../API.md).
# Types: fixed_bitset, growable_bitset. Factories: MakeFixedBitset,
# MakeGrowableBitset, FixedBitsetFromBytes, GrowableBitsetFromBytes.
# Both types: Count, Get, Set, SetRange, FlipRange, PopulationCount, Clear,
# FindFirstSet, FindFirstClear, Clone, Complement, Union, Intersect, Xor,
# Difference, ToBytes. Conversions: fixed.ToGrowable, growable.ToFixed.
# Growable only: Resize, AppendBit. Serialized logical length is out-of-band.

Bits<public> := module:
    MaxLength<internal>:int = 2147483647
    WordMask<internal>:int = 4294967295
    Powers<internal>:[]int = array{
        1, 2, 4, 8, 16, 32, 64, 128,
        256, 512, 1024, 2048, 4096, 8192, 16384, 32768,
        65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608,
        16777216, 33554432, 67108864, 134217728, 268435456, 536870912,
        1073741824, 2147483648, 4294967296}

    combination<internal> := enum:
        Union
        Intersection
        ExclusiveOr
        Difference

    # Both public types own a core; no mutable storage is publicly exposed.
    packed_bits<internal> := class<final>:
        var BitCount<private>:int = 0
        var Words<private>:[]int = array{}

        Count<internal>()<transacts>:int =
            BitCount

        Clone<internal>()<transacts>:packed_bits =
            Copy := packed_bits{}
            Copy.Load(BitCount, Words)
            Copy

        # Trusted callers supply bounded words and zero trailing bits.
        Load<private>(Length:int, Data:[]int)<transacts>:void =
            set BitCount = Length
            set Words = Data

        Resize<internal>(Length:int)<transacts><decides>:void =
            0 <= Length <= MaxLength
            WordCount := Quotient[Length, 32] + Min(1, Mod[Length, 32])
            var Next:[]int = array{}
            if (WordCount > 0):
                set Next = for (Index := 0..WordCount - 1) do Words[Index] or 0
                Remainder := Mod[Length, 32]
                if (Remainder > 0):
                    Last := Next[WordCount - 1]
                    Mask := Powers[Remainder] - 1
                    set Next[WordCount - 1] = BitAnd(Last, Mask)
            Load(Length, Next)

        Get<internal>(Index:int)<transacts><decides>:int =
            0 <= Index < BitCount
            WordIndex := Quotient[Index, 32]
            Mask := Powers[Mod[Index, 32]]
            if (BitAnd(Words[WordIndex], Mask) = 0) then 0 else 1

        Set<internal>(Index:int, Value:int)<transacts><decides>:void =
            0 <= Value <= 1
            0 <= Index < BitCount
            WordIndex := Quotient[Index, 32]
            Mask := Powers[Mod[Index, 32]]
            Word := Words[WordIndex]
            Next := if (Value = 0) then BitAnd(Word, WordMask - Mask) else BitOr(Word, Mask)
            set Words[WordIndex] = Next

        # Ranges are zero-based [Start, Stop); the empty end range is valid.
        SetRange<internal>(Start:int, Stop:int, Value:int)<transacts><decides>:void =
            0 <= Value <= 1
            0 <= Start <= Stop <= BitCount
            if (Start < Stop):
                First := Quotient[Start, 32]
                Last := Quotient[Stop - 1, 32]
                for (Index := First..Last):
                    Low := if (Index = First) then Mod[Start, 32] else 0
                    High := if (Index = Last) then Mod[Stop - 1, 32] + 1 else 32
                    Mask := Powers[High] - Powers[Low]
                    Word := Words[Index]
                    Next := if (Value = 0) then BitAnd(Word, WordMask - Mask) else BitOr(Word, Mask)
                    set Words[Index] = Next

        FlipRange<internal>(Start:int, Stop:int)<transacts><decides>:void =
            0 <= Start <= Stop <= BitCount
            if (Start < Stop):
                First := Quotient[Start, 32]
                Last := Quotient[Stop - 1, 32]
                for (Index := First..Last):
                    Low := if (Index = First) then Mod[Start, 32] else 0
                    High := if (Index = Last) then Mod[Stop - 1, 32] + 1 else 32
                    Mask := Powers[High] - Powers[Low]
                    Word := Words[Index]
                    set Words[Index] = BitXor(Word, Mask)

        PopulationCount<internal>()<transacts>:int =
            var Total:int = 0
            for (Initial : Words):
                var Word:int = Initial
                loop:
                    if (Word = 0):
                        break
                    set Word = BitAnd(Word, Word - 1)
                    set Total += 1
            Total

        Clear<internal>()<transacts>:void =
            set Words = for (Word : Words) do 0

        # Start is inclusive and may equal Count(); absence is ordinary failure.
        Find<internal>(Start:int, Value:int)<transacts><decides>:int =
            0 <= Start <= BitCount
            0 <= Value <= 1
            var Found:?int = false
            for (Index -> Initial : Words):
                WordStart := Index * 32
                if (not Found?, WordStart + 32 > Start):
                    var Word:int = if (Value = 1) then Initial else WordMask - Initial
                    if (WordStart < Start):
                        Keep := WordMask - (Powers[Start - WordStart] - 1)
                        set Word = BitAnd(Word, Keep)
                    if (Word > 0):
                        var Bit:int = 0
                        loop:
                            if (Mod[Word, 2] = 1):
                                break
                            Next := Quotient[Word, 2] or 0
                            set Word = Next
                            set Bit += 1
                        Candidate := WordStart + Bit
                        if (Candidate < BitCount):
                            set Found = option{Candidate}
            Found?

        Combine<internal>(Other:packed_bits, Operation:combination)<transacts><decides>:packed_bits =
            BitCount = Other.Count()
            Data := for (Index -> Word : Words):
                OtherWord := Other.Words[Index]
                case (Operation):
                    combination.Union => BitOr(Word, OtherWord)
                    combination.Intersection => BitAnd(Word, OtherWord)
                    combination.ExclusiveOr => BitXor(Word, OtherWord)
                    combination.Difference => BitAnd(Word, WordMask - OtherWord)
            Result := packed_bits{}
            Result.Load(BitCount, Data)
            Result

        ToBytes<internal>()<transacts><decides>:[]int =
            ByteCount := Quotient[BitCount, 8] + Min(1, Mod[BitCount, 8])
            if (ByteCount > 0):
                for (Index := 0..ByteCount - 1):
                    Word := Words[Quotient[Index, 4]]
                    Divisor := Powers[Mod[Index, 4] * 8]
                    BitAnd(Quotient[Word, Divisor], 255)
            else:
                array{}

        LoadBytes<internal>(Length:int, Data:[]int)<transacts><decides>:void =
            0 <= Length <= MaxLength
            ByteCount := Quotient[Length, 8] + Min(1, Mod[Length, 8])
            Data.Length = ByteCount
            for (Byte : Data):
                0 <= Byte <= 255
            Remainder := Mod[Length, 8]
            if (Remainder > 0):
                Last := Data[ByteCount - 1]
                Last < Powers[Remainder]
            Resize[Length]
            Clear()
            for (Index -> Byte : Data):
                WordIndex := Quotient[Index, 4]
                Word := Words[WordIndex]
                Factor := Powers[Mod[Index, 4] * 8]
                set Words[WordIndex] = BitOr(Word, Byte * Factor)

    # Fixed length after construction; Clone and set algebra return new owners.
    fixed_bitset<public> := class<internal><final>:
        Core<internal>:packed_bits

        Count<public>()<transacts>:int =
            Core.Count()

        Get<public>(Index:int)<transacts><decides>:int =
            Core.Get[Index]

        Set<public>(Index:int, Value:int)<transacts><decides>:void =
            Core.Set[Index, Value]

        SetRange<public>(Start:int, Stop:int, Value:int)<transacts><decides>:void =
            Core.SetRange[Start, Stop, Value]

        FlipRange<public>(Start:int, Stop:int)<transacts><decides>:void =
            Core.FlipRange[Start, Stop]

        PopulationCount<public>()<transacts>:int =
            Core.PopulationCount()

        Clear<public>()<transacts>:void =
            Core.Clear()

        FindFirstSet<public>(Start:int)<transacts><decides>:int =
            Core.Find[Start, 1]

        FindFirstClear<public>(Start:int)<transacts><decides>:int =
            Core.Find[Start, 0]

        Clone<public>()<transacts>:fixed_bitset =
            fixed_bitset{Core := Core.Clone()}

        Complement<public>()<transacts><decides>:fixed_bitset =
            Result := Clone()
            Result.FlipRange[0, Count()]
            Result

        ToGrowable<public>()<transacts>:growable_bitset =
            growable_bitset{Core := Core.Clone()}

        Union<public>(Other:fixed_bitset)<transacts><decides>:fixed_bitset =
            Result := Core.Combine[Other.Core, combination.Union]
            fixed_bitset{Core := Result}

        Intersect<public>(Other:fixed_bitset)<transacts><decides>:fixed_bitset =
            Result := Core.Combine[Other.Core, combination.Intersection]
            fixed_bitset{Core := Result}

        Xor<public>(Other:fixed_bitset)<transacts><decides>:fixed_bitset =
            Result := Core.Combine[Other.Core, combination.ExclusiveOr]
            fixed_bitset{Core := Result}

        Difference<public>(Other:fixed_bitset)<transacts><decides>:fixed_bitset =
            Result := Core.Combine[Other.Core, combination.Difference]
            fixed_bitset{Core := Result}

        # Exactly ceil(Count()/8) bytes, LSB-first; length is out-of-band.
        ToBytes<public>()<transacts><decides>:[]int =
            Core.ToBytes[]

    growable_bitset<public> := class<internal><final>:
        Core<internal>:packed_bits

        Count<public>()<transacts>:int =
            Core.Count()

        Get<public>(Index:int)<transacts><decides>:int =
            Core.Get[Index]

        Set<public>(Index:int, Value:int)<transacts><decides>:void =
            Core.Set[Index, Value]

        SetRange<public>(Start:int, Stop:int, Value:int)<transacts><decides>:void =
            Core.SetRange[Start, Stop, Value]

        FlipRange<public>(Start:int, Stop:int)<transacts><decides>:void =
            Core.FlipRange[Start, Stop]

        Resize<public>(Length:int)<transacts><decides>:void =
            Core.Resize[Length]

        AppendBit<public>(Value:int)<transacts><decides>:void =
            0 <= Value <= 1
            Length := Count()
            Length < MaxLength
            Core.Resize[Length + 1]
            Core.Set[Length, Value]

        PopulationCount<public>()<transacts>:int =
            Core.PopulationCount()

        Clear<public>()<transacts>:void =
            Core.Clear()

        FindFirstSet<public>(Start:int)<transacts><decides>:int =
            Core.Find[Start, 1]

        FindFirstClear<public>(Start:int)<transacts><decides>:int =
            Core.Find[Start, 0]

        Clone<public>()<transacts>:growable_bitset =
            growable_bitset{Core := Core.Clone()}

        Complement<public>()<transacts><decides>:growable_bitset =
            Result := Clone()
            Result.FlipRange[0, Count()]
            Result

        ToFixed<public>()<transacts>:fixed_bitset =
            fixed_bitset{Core := Core.Clone()}

        Union<public>(Other:growable_bitset)<transacts><decides>:growable_bitset =
            Result := Core.Combine[Other.Core, combination.Union]
            growable_bitset{Core := Result}

        Intersect<public>(Other:growable_bitset)<transacts><decides>:growable_bitset =
            Result := Core.Combine[Other.Core, combination.Intersection]
            growable_bitset{Core := Result}

        Xor<public>(Other:growable_bitset)<transacts><decides>:growable_bitset =
            Result := Core.Combine[Other.Core, combination.ExclusiveOr]
            growable_bitset{Core := Result}

        Difference<public>(Other:growable_bitset)<transacts><decides>:growable_bitset =
            Result := Core.Combine[Other.Core, combination.Difference]
            growable_bitset{Core := Result}

        ToBytes<public>()<transacts><decides>:[]int =
            Core.ToBytes[]

    MakeFixedBitset<public>(Length:int)<transacts><decides>:fixed_bitset =
        Core := packed_bits{}
        Core.Resize[Length]
        fixed_bitset{Core := Core}

    MakeGrowableBitset<public>(Length:int)<transacts><decides>:growable_bitset =
        Core := packed_bits{}
        Core.Resize[Length]
        growable_bitset{Core := Core}

    FixedBitsetFromBytes<public>(Length:int, Data:[]int)<transacts><decides>:fixed_bitset =
        Core := packed_bits{}
        Core.LoadBytes[Length, Data]
        fixed_bitset{Core := Core}

    GrowableBitsetFromBytes<public>(Length:int, Data:[]int)<transacts><decides>:growable_bitset =
        Core := packed_bits{}
        Core.LoadBytes[Length, Data]
        growable_bitset{Core := Core}
