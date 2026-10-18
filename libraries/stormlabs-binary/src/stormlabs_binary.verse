# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API index (full signatures and contracts: ../API.md).
# Types: byte_order{BigEndian, LittleEndian}, uint64{High, Low}, byte_buffer,
# binary_reader, binary_writer. Factories: MakeByteBuffer, MakeBinaryReader,
# MakeBinaryWriter. Words: Add/Subtract/And/Or/Xor/NotUInt32 and UInt64;
# ShiftLeft/ShiftRight/RotateLeft/RotateRightUInt32 and UInt64.
# Endian: EncodeUInt16/32/64; buffers: Count, CopyBytes, CopyRange, Append,
# Get, Set, Resize, WriteBytes, Read/WriteUInt16/32/64, Read/WriteUInt32BE/LE.
# Readers: Position, Remaining, Seek, ReadBytes, ReadByte, ReadUInt16/32/64.
# Writers: Count, CopyBytes, WriteBytes, WriteByte, WriteUInt16/32/64.

Binary<public> := module:
    MaxLength<internal>:int = 2147483647
    WordMask<internal>:int = 4294967295
    WordModulus<internal>:int = 4294967296
    Powers<internal>:[]int = array{
        1, 2, 4, 8, 16, 32, 64, 128,
        256, 512, 1024, 2048, 4096, 8192, 16384, 32768,
        65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608,
        16777216, 33554432, 67108864, 134217728, 268435456, 536870912,
        1073741824, 2147483648, 4294967296}

    byte_order<public> := enum:
        BigEndian
        LittleEndian

    # A value, not a packed native unsigned integer. Operations validate halves.
    uint64<public> := struct<computes>:
        High<public>:int
        Low<public>:int

    # Public integers are checked, never silently reduced to a byte or word.
    ValidateBytes<internal>(Data:[]int)<computes><decides>:void =
        for (Value : Data):
            0 <= Value <= 255

    ValidateUInt32<internal>(Value:int)<computes><decides>:void =
        0 <= Value <= WordMask

    ValidateUInt64<internal>(Value:uint64)<computes><decides>:void =
        ValidateUInt32[Value.High]
        ValidateUInt32[Value.Low]

    AddUInt32<public>(A:int, B:int)<transacts><decides>:int =
        ValidateUInt32[A]
        ValidateUInt32[B]
        BitAnd(A + B, WordMask)

    SubtractUInt32<public>(A:int, B:int)<transacts><decides>:int =
        ValidateUInt32[A]
        ValidateUInt32[B]
        BitAnd(A - B + WordModulus, WordMask)

    AndUInt32<public>(A:int, B:int)<transacts><decides>:int =
        ValidateUInt32[A]
        ValidateUInt32[B]
        BitAnd(A, B)

    OrUInt32<public>(A:int, B:int)<transacts><decides>:int =
        ValidateUInt32[A]
        ValidateUInt32[B]
        BitOr(A, B)

    XorUInt32<public>(A:int, B:int)<transacts><decides>:int =
        ValidateUInt32[A]
        ValidateUInt32[B]
        BitXor(A, B)

    (Value:int).NotUInt32<public>()<transacts><decides>:int =
        ValidateUInt32[Value]
        WordMask - Value

    ShiftLeftUInt32<public>(Value:int, Count:int)<transacts><decides>:int =
        ValidateUInt32[Value]
        Count >= 0
        if (Count >= 32):
            0
        else:
            # Discard before multiplying: the intermediate stays below 2^32.
            Mask := Powers[32 - Count] - 1
            BitAnd(Value, Mask) * Powers[Count]

    ShiftRightUInt32<public>(Value:int, Count:int)<transacts><decides>:int =
        ValidateUInt32[Value]
        Count >= 0
        if (Count >= 32) then 0 else Quotient[Value, Powers[Count]]

    RotateLeftUInt32<public>(Value:int, Count:int)<transacts><decides>:int =
        ValidateUInt32[Value]
        Count >= 0
        Shift := Mod[Count, 32]
        if (Shift = 0):
            Value
        else:
            BitOr(ShiftLeftUInt32[Value, Shift], ShiftRightUInt32[Value, 32 - Shift])

    RotateRightUInt32<public>(Value:int, Count:int)<transacts><decides>:int =
        ValidateUInt32[Value]
        Count >= 0
        Shift := Mod[Count, 32]
        if (Shift = 0):
            Value
        else:
            BitOr(ShiftRightUInt32[Value, Shift], ShiftLeftUInt32[Value, 32 - Shift])

    AddUInt64<public>(A:uint64, B:uint64)<transacts><decides>:uint64 =
        ValidateUInt64[A]
        ValidateUInt64[B]
        LowSum := A.Low + B.Low
        Carry := Quotient[LowSum, WordModulus]
        uint64{High := BitAnd(A.High + B.High + Carry, WordMask), Low := BitAnd(LowSum, WordMask)}

    SubtractUInt64<public>(A:uint64, B:uint64)<transacts><decides>:uint64 =
        ValidateUInt64[A]
        ValidateUInt64[B]
        Borrow := if (A.Low < B.Low) then 1 else 0
        uint64:
            High := BitAnd(A.High - B.High - Borrow + WordModulus, WordMask)
            Low := BitAnd(A.Low - B.Low + WordModulus, WordMask)

    AndUInt64<public>(A:uint64, B:uint64)<transacts><decides>:uint64 =
        ValidateUInt64[A]
        ValidateUInt64[B]
        uint64{High := BitAnd(A.High, B.High), Low := BitAnd(A.Low, B.Low)}

    OrUInt64<public>(A:uint64, B:uint64)<transacts><decides>:uint64 =
        ValidateUInt64[A]
        ValidateUInt64[B]
        uint64{High := BitOr(A.High, B.High), Low := BitOr(A.Low, B.Low)}

    XorUInt64<public>(A:uint64, B:uint64)<transacts><decides>:uint64 =
        ValidateUInt64[A]
        ValidateUInt64[B]
        uint64{High := BitXor(A.High, B.High), Low := BitXor(A.Low, B.Low)}

    (Value:uint64).NotUInt64<public>()<transacts><decides>:uint64 =
        ValidateUInt64[Value]
        uint64{High := WordMask - Value.High, Low := WordMask - Value.Low}

    ShiftLeftUInt64<public>(Value:uint64, Count:int)<transacts><decides>:uint64 =
        ValidateUInt64[Value]
        Count >= 0
        if (Count >= 64):
            uint64{High := 0, Low := 0}
        else if (Count >= 32):
            High := ShiftLeftUInt32[Value.Low, Count - 32]
            uint64{High := High, Low := 0}
        else if (Count = 0):
            Value
        else:
            High := BitOr(ShiftLeftUInt32[Value.High, Count], ShiftRightUInt32[Value.Low, 32 - Count])
            Low := ShiftLeftUInt32[Value.Low, Count]
            uint64{High := High, Low := Low}

    ShiftRightUInt64<public>(Value:uint64, Count:int)<transacts><decides>:uint64 =
        ValidateUInt64[Value]
        Count >= 0
        if (Count >= 64):
            uint64{High := 0, Low := 0}
        else if (Count >= 32):
            Low := ShiftRightUInt32[Value.High, Count - 32]
            uint64{High := 0, Low := Low}
        else if (Count = 0):
            Value
        else:
            High := ShiftRightUInt32[Value.High, Count]
            Low := BitOr(ShiftRightUInt32[Value.Low, Count], ShiftLeftUInt32[Value.High, 32 - Count])
            uint64{High := High, Low := Low}

    RotateLeftUInt64<public>(Value:uint64, Count:int)<transacts><decides>:uint64 =
        ValidateUInt64[Value]
        Count >= 0
        Shift := Mod[Count, 64]
        if (Shift = 0):
            Value
        else:
            OrUInt64[ShiftLeftUInt64[Value, Shift], ShiftRightUInt64[Value, 64 - Shift]]

    RotateRightUInt64<public>(Value:uint64, Count:int)<transacts><decides>:uint64 =
        ValidateUInt64[Value]
        Count >= 0
        Shift := Mod[Count, 64]
        if (Shift = 0):
            Value
        else:
            OrUInt64[ShiftRightUInt64[Value, Shift], ShiftLeftUInt64[Value, 64 - Shift]]

    EncodeUInt16<public>(Value:int, Order:byte_order)<transacts><decides>:[]int =
        0 <= Value <= 65535
        High := Quotient[Value, 256]
        Low := BitAnd(Value, 255)
        if (Order = byte_order.BigEndian) then array{High, Low} else array{Low, High}

    EncodeUInt32<public>(Value:int, Order:byte_order)<transacts><decides>:[]int =
        ValidateUInt32[Value]
        A := Quotient[Value, 16777216]
        B := BitAnd(Quotient[Value, 65536], 255)
        C := BitAnd(Quotient[Value, 256], 255)
        D := BitAnd(Value, 255)
        if (Order = byte_order.BigEndian) then array{A, B, C, D} else array{D, C, B, A}

    EncodeUInt64<public>(Value:uint64, Order:byte_order)<transacts><decides>:[]int =
        ValidateUInt64[Value]
        High := EncodeUInt32[Value.High, Order]
        Low := EncodeUInt32[Value.Low, Order]
        if (Order = byte_order.BigEndian) then High + Low else Low + High

    # Module-only construction keeps invalid bytes out of mutable storage.
    byte_buffer<public> := class<internal><final>:
        var Bytes<private>:[]int = array{}

        Count<public>()<transacts>:int =
            Bytes.Length

        CopyBytes<public>()<transacts>:[]int =
            Bytes

        CopyRange<public>(Start:int, Stop:int)<transacts><decides>:[]int =
            0 <= Start <= Stop <= Bytes.Length
            if (Start < Stop):
                for (Index := Start..Stop - 1) do Bytes[Index]
            else:
                array{}

        Append<public>(Data:[]int)<transacts><decides>:void =
            Data.Length <= MaxLength - Bytes.Length
            ValidateBytes[Data]
            set Bytes += Data

        Get<public>(Index:int)<transacts><decides>:int =
            Bytes[Index]

        Set<public>(Index:int, Value:int)<transacts><decides>:void =
            0 <= Value <= 255
            set Bytes[Index] = Value

        Resize<public>(Length:int, ?FillByte:int = 0)<transacts><decides>:void =
            0 <= Length <= MaxLength
            0 <= FillByte <= 255
            if (Length < Bytes.Length):
                Next := CopyRange[0, Length]
                set Bytes = Next
            else if (Length > Bytes.Length):
                Extra := for (Index := Bytes.Length..Length - 1) do FillByte
                set Bytes += Extra

        WriteBytes<public>(Offset:int, Data:[]int)<transacts><decides>:void =
            0 <= Offset <= Bytes.Length
            Data.Length <= Bytes.Length - Offset
            ValidateBytes[Data]
            for (Index -> Value : Data):
                set Bytes[Offset + Index] = Value

        ReadUInt16<public>(Offset:int, Order:byte_order)<transacts><decides>:int =
            0 <= Offset <= Bytes.Length
            2 <= Bytes.Length - Offset
            A := Bytes[Offset]
            B := Bytes[Offset + 1]
            if (Order = byte_order.BigEndian) then A * 256 + B else B * 256 + A

        ReadUInt32<public>(Offset:int, Order:byte_order)<transacts><decides>:int =
            0 <= Offset <= Bytes.Length
            4 <= Bytes.Length - Offset
            A := Bytes[Offset]
            B := Bytes[Offset + 1]
            C := Bytes[Offset + 2]
            D := Bytes[Offset + 3]
            if (Order = byte_order.BigEndian):
                A * 16777216 + B * 65536 + C * 256 + D
            else:
                D * 16777216 + C * 65536 + B * 256 + A

        ReadUInt64<public>(Offset:int, Order:byte_order)<transacts><decides>:uint64 =
            0 <= Offset <= Bytes.Length
            8 <= Bytes.Length - Offset
            First := ReadUInt32[Offset, Order]
            Second := ReadUInt32[Offset + 4, Order]
            if (Order = byte_order.BigEndian):
                uint64{High := First, Low := Second}
            else:
                uint64{High := Second, Low := First}

        WriteUInt16<public>(Offset:int, Value:int, Order:byte_order)<transacts><decides>:void =
            Data := EncodeUInt16[Value, Order]
            WriteBytes[Offset, Data]

        WriteUInt32<public>(Offset:int, Value:int, Order:byte_order)<transacts><decides>:void =
            Data := EncodeUInt32[Value, Order]
            WriteBytes[Offset, Data]

        WriteUInt64<public>(Offset:int, Value:uint64, Order:byte_order)<transacts><decides>:void =
            Data := EncodeUInt64[Value, Order]
            WriteBytes[Offset, Data]

        # Offset is in bytes. Validate by subtraction before adding offsets.
        ReadUInt32BE<public>(Offset:int)<transacts><decides>:int =
            ReadUInt32[Offset, byte_order.BigEndian]

        ReadUInt32LE<public>(Offset:int)<transacts><decides>:int =
            ReadUInt32[Offset, byte_order.LittleEndian]

        WriteUInt32BE<public>(Offset:int, Value:int)<transacts><decides>:void =
            WriteUInt32[Offset, Value, byte_order.BigEndian]

        WriteUInt32LE<public>(Offset:int, Value:int)<transacts><decides>:void =
            WriteUInt32[Offset, Value, byte_order.LittleEndian]

    MakeByteBuffer<public>(Data:[]int)<transacts><decides>:byte_buffer =
        Buffer := byte_buffer{}
        Buffer.Append[Data]
        Buffer

    # A reader owns a snapshot, never a mutable buffer alias supplied by callers.
    binary_reader<public> := class<internal><final>:
        Source<internal>:byte_buffer
        var Offset<private>:int = 0

        Position<public>()<transacts>:int =
            Offset

        Remaining<public>()<transacts>:int =
            Source.Count() - Offset

        Seek<public>(NewPosition:int)<transacts><decides>:void =
            0 <= NewPosition <= Source.Count()
            set Offset = NewPosition

        ReadBytes<public>(Length:int)<transacts><decides>:[]int =
            0 <= Length <= Remaining()
            Data := Source.CopyRange[Offset, Offset + Length]
            set Offset += Length
            Data

        ReadByte<public>()<transacts><decides>:int =
            Value := Source.Get[Offset]
            set Offset += 1
            Value

        ReadUInt16<public>(Order:byte_order)<transacts><decides>:int =
            Value := Source.ReadUInt16[Offset, Order]
            set Offset += 2
            Value

        ReadUInt32<public>(Order:byte_order)<transacts><decides>:int =
            Value := Source.ReadUInt32[Offset, Order]
            set Offset += 4
            Value

        ReadUInt64<public>(Order:byte_order)<transacts><decides>:uint64 =
            Value := Source.ReadUInt64[Offset, Order]
            set Offset += 8
            Value

    MakeBinaryReader<public>(Data:[]int)<transacts><decides>:binary_reader =
        Source := MakeByteBuffer[Data]
        binary_reader{Source := Source}

    # Appends only. No implicit seek or overwrite behavior.
    binary_writer<public> := class<internal><final>:
        Buffer<internal>:byte_buffer
        Limit<internal>:int

        Count<public>()<transacts>:int =
            Buffer.Count()

        CopyBytes<public>()<transacts>:[]int =
            Buffer.CopyBytes()

        WriteBytes<public>(Data:[]int)<transacts><decides>:void =
            Data.Length <= Limit - Count()
            Buffer.Append[Data]

        WriteByte<public>(Value:int)<transacts><decides>:void =
            WriteBytes[array{Value}]

        WriteUInt16<public>(Value:int, Order:byte_order)<transacts><decides>:void =
            Data := EncodeUInt16[Value, Order]
            WriteBytes[Data]

        WriteUInt32<public>(Value:int, Order:byte_order)<transacts><decides>:void =
            Data := EncodeUInt32[Value, Order]
            WriteBytes[Data]

        WriteUInt64<public>(Value:uint64, Order:byte_order)<transacts><decides>:void =
            Data := EncodeUInt64[Value, Order]
            WriteBytes[Data]

    MakeBinaryWriter<public>(?ByteLimit:int = 2147483647)<transacts><decides>:binary_writer =
        0 <= ByteLimit <= MaxLength
        Buffer := MakeByteBuffer[array{}]
        binary_writer{Buffer := Buffer, Limit := ByteLimit}
