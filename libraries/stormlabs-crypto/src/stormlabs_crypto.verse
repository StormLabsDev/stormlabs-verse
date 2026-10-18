# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API index: see ../API.md for signatures; ../README.md for validation status.
# - HexEncode, HexDecode; sha2_algorithm; SHA2DigestSize, SHA2BlockSize.
# - sha224_context, sha256_context, sha384_context, sha512_context,
# - sha512_224_context, sha512_256_context: Reset, Update, Finalize.
# - SHA224, SHA256, SHA384, SHA512, SHA512_224, SHA512_256; each has a Hex form.
# - HashSHA224, HashSHA256, HashSHA384, HashSHA512, HashSHA512_224, HashSHA512_256; SHA256Async.
# - hmac_context: DigestSize, BlockSize, Reset, Update, Finalize; MakeHMAC, HMAC, VerifyHMAC.
# - CreateHMAC, AuthenticateHMAC; HMACSHA224, HMACSHA256, HMACSHA384, HMACSHA512, HMACSHA512_224, HMACSHA512_256.
# - HKDFExtract, HKDFExpand, HKDF; ExtractHKDF, ExpandHKDF, DeriveHKDF; HKDFSHA256, HKDFSHA512.

using { /Verse.org/Simulation }

Crypto<public> := module:
    WordMask<internal>:int = 4294967295
    HexDigits<internal>:string = "0123456789abcdef"
    SHA256Constants<internal>:[]int = array{
        0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
        0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
        0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
        0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
        0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
        0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
        0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
        0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
        0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
        0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
        0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
        0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
        0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
        0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
        0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
        0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2}

    # Encode a normalized unsigned 32-bit word in big-endian order.
    WordBytes<internal>(Value:int)<computes>:[]int =
        array:
            Quotient[Value, 16777216] or 0
            BitAnd(Quotient[Value, 65536] or 0, 0xFF)
            BitAnd(Quotient[Value, 256] or 0, 0xFF)
            BitAnd(Value, 0xFF)

    ValidateBytes<internal>(Data:[]int)<computes><decides>:void =
        for (Value : Data):
            0 <= Value <= 255

    # Fails for any value outside 0..255. Encodes every byte, including zero.
    HexEncode<public>(Data:[]int)<transacts><decides>:string =
        ValidateBytes[Data]
        var Output:string = ""
        for (Value : Data):
            High := Quotient[Value, 16]
            Low := Mod[Value, 16]
            set Output += array{HexDigits[High], HexDigits[Low]}
        Output

    HexNibble<internal>(Digit:char)<transacts><decides>:int =
        Digits := "0123456789abcdefABCDEF"
        var Found:int = -1
        for (Index -> Candidate : Digits, Candidate = Digit):
            set Found = Index
        Found >= 0
        if (Found < 16):
            Found
        else:
            Found - 6

    # Accepts either letter case. Whitespace, odd lengths, and bad digits fail.
    HexDecode<public>(Text:string)<transacts><decides>:[]int =
        Mod[Text.Length, 2] = 0
        var Output:[]int = array{}
        PairCount := Quotient[Text.Length, 2]
        if (PairCount > 0):
            for (Index := 0..PairCount - 1):
                High := HexNibble[Text[Index * 2]]
                Low := HexNibble[Text[Index * 2 + 1]]
                set Output += array{High * 16 + Low}
        Output

    InitialSHA224State<internal>:[]int = array{
        0xC1059ED8, 0x367CD507, 0x3070DD17, 0xF70E5939,
        0xFFC00B31, 0x68581511, 0x64F98FA7, 0xBEFA4FA4}
    InitialSHA256State<internal>:[]int = array{
        0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
        0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19}
    MaxSHA256Bytes<internal>:int = 2305843009213693951

    BitLengthBytes<internal>(ByteCount:int)<computes><decides>:[]int =
        0 <= ByteCount <= MaxSHA256Bytes
        High := Quotient[ByteCount, 536870912]
        Low := BitAnd(ByteCount, 536870911) * 8
        WordBytes(High) + WordBytes(Low)

    # SHA-256 uses fixed counts. Constant factors avoid generic rotation
    # dispatch and table indexing in every round. Inputs are 32-bit words;
    # masking before multiplication keeps every intermediate below 2^32.
    SHA256SmallSigma0<internal>(Value:int)<computes>:int =
        R7 := BitOr(Quotient[Value, 128] or 0, BitAnd(Value, 127) * 33554432)
        R18 := BitOr(Quotient[Value, 262144] or 0, BitAnd(Value, 262143) * 16384)
        BitXor(BitXor(R7, R18), Quotient[Value, 8] or 0)

    SHA256SmallSigma1<internal>(Value:int)<computes>:int =
        R17 := BitOr(Quotient[Value, 131072] or 0, BitAnd(Value, 131071) * 32768)
        R19 := BitOr(Quotient[Value, 524288] or 0, BitAnd(Value, 524287) * 8192)
        BitXor(BitXor(R17, R19), Quotient[Value, 1024] or 0)

    SHA256BigSigma0<internal>(Value:int)<computes>:int =
        R2 := BitOr(Quotient[Value, 4] or 0, BitAnd(Value, 3) * 1073741824)
        R13 := BitOr(Quotient[Value, 8192] or 0, BitAnd(Value, 8191) * 524288)
        R22 := BitOr(Quotient[Value, 4194304] or 0, BitAnd(Value, 4194303) * 1024)
        BitXor(BitXor(R2, R13), R22)

    SHA256BigSigma1<internal>(Value:int)<computes>:int =
        R6 := BitOr(Quotient[Value, 64] or 0, BitAnd(Value, 63) * 67108864)
        R11 := BitOr(Quotient[Value, 2048] or 0, BitAnd(Value, 2047) * 2097152)
        R25 := BitOr(Quotient[Value, 33554432] or 0, BitAnd(Value, 33554431) * 128)
        BitXor(BitXor(R6, R11), R25)

    # Shared by one-shot, streaming, and yielding entry points.
    CompressSHA256<internal>(State:[]int, Data:[]int, Offset:int)<transacts><decides>:[]int =
        State.Length = 8
        0 <= Offset <= Data.Length - 64
        var Schedule:[]int = for (Index := 0..63) do 0
        for (Index := 0..15):
            WordOffset := Offset + Index * 4
            Word := Data[WordOffset] * 0x1000000 + Data[WordOffset + 1] * 0x10000 + Data[WordOffset + 2] * 0x100 + Data[WordOffset + 3]
            set Schedule[Index] = Word
        for (Index := 16..63):
            Earlier := Schedule[Index - 15]
            Later := Schedule[Index - 2]
            Sigma0 := SHA256SmallSigma0(Earlier)
            Sigma1 := SHA256SmallSigma1(Later)
            Word := BitAnd(Schedule[Index - 16] + Sigma0 + Schedule[Index - 7] + Sigma1, WordMask)
            set Schedule[Index] = Word

        var A:int = State[0]
        var B:int = State[1]
        var C:int = State[2]
        var D:int = State[3]
        var E:int = State[4]
        var F:int = State[5]
        var G:int = State[6]
        var H:int = State[7]

        for (Index := 0..63):
            Sum1 := SHA256BigSigma1(E)
            Choice := BitXor(G, BitAnd(E, BitXor(F, G)))
            Temp1 := BitAnd(H + Sum1 + Choice + SHA256Constants[Index] + Schedule[Index], WordMask)
            Sum0 := SHA256BigSigma0(A)
            Majority := BitOr(BitAnd(A, B), BitAnd(C, BitOr(A, B)))
            Temp2 := BitAnd(Sum0 + Majority, WordMask)
            set H = G
            set G = F
            set F = E
            set E = BitAnd(D + Temp1, WordMask)
            set D = C
            set C = B
            set B = A
            set A = BitAnd(Temp1 + Temp2, WordMask)

        array:
            BitAnd(State[0] + A, WordMask)
            BitAnd(State[1] + B, WordMask)
            BitAnd(State[2] + C, WordMask)
            BitAnd(State[3] + D, WordMask)
            BitAnd(State[4] + E, WordMask)
            BitAnd(State[5] + F, WordMask)
            BitAnd(State[6] + G, WordMask)
            BitAnd(State[7] + H, WordMask)

    # Shared lifecycle for SHA-224 and SHA-256. Configuration never escapes
    # the module; callers cannot supply a custom initial state or digest size.
    sha2_32_context<internal> := class<final>:
        InitialState<internal>:[]int
        DigestWordCount<internal>:int
        var State<private>:?[]int = false
        var Pending<private>:[]int = array{}
        var ByteCount<private>:int = 0
        var CachedDigest<private>:?[]int = false

        Reset<internal>()<transacts>:void =
            set State = false
            set Pending = array{}
            set ByteCount = 0
            set CachedDigest = false

        Clone<internal>()<transacts>:sha2_32_context =
            sha2_32_context{
                InitialState := InitialState, DigestWordCount := DigestWordCount,
                State := State, Pending := Pending, ByteCount := ByteCount,
                CachedDigest := CachedDigest}

        # Synchronous: bound each update's input to fit the caller's budget.
        Update<internal>(Data:[]int)<transacts><decides>:void =
            not CachedDigest?
            Data.Length <= MaxSHA256Bytes - ByteCount
            ValidateBytes[Data]
            var WorkingState:[]int = if (Existing := State?) then Existing else InitialState
            Source := STL.int_buffer{Values := Data}
            var Offset:int = 0
            if (Pending.Length > 0):
                FillCount := Min(64 - Pending.Length, Data.Length)
                Fill := Source.CopyRange[0, FillCount]
                set Pending += Fill
                set Offset = FillCount
                if (Pending.Length = 64):
                    NextState := CompressSHA256[WorkingState, Pending, 0]
                    set WorkingState = NextState
                    set Pending = array{}

            BlockCount := Quotient[Data.Length - Offset, 64]
            if (BlockCount > 0):
                for (Block := 0..BlockCount - 1):
                    NextState := CompressSHA256[WorkingState, Data, Offset]
                    set WorkingState = NextState
                    set Offset += 64
            if (Offset < Data.Length):
                Remainder := Source.CopyRange[Offset, Data.Length]
                set Pending += Remainder
            set State = option{WorkingState}
            set ByteCount += Data.Length

        Finalize<internal>()<transacts><decides>:[]int =
            if (Digest := CachedDigest?):
                Digest
            else:
                LengthBytes := BitLengthBytes[ByteCount]
                ZeroCount := Mod[119 - Pending.Length, 64]
                Zeros := for (Index := 0..63, Index < ZeroCount) do 0
                # Only the final one or two blocks are padded, never the input.
                Tail := Pending + array{128} + Zeros + LengthBytes
                BlockCount := Quotient[Tail.Length, 64]
                var FinalState:[]int = if (Existing := State?) then Existing else InitialState
                for (Block := 0..BlockCount - 1):
                    NextState := CompressSHA256[FinalState, Tail, Block * 64]
                    set FinalState = NextState
                Digest := for (Index -> Word : FinalState, Index < DigestWordCount, Byte : WordBytes(Word)) do Byte
                set CachedDigest = option{Digest}
                Digest

    # Each public context owns a private core. Finalize is idempotent;
    # Update fails after finalization until Reset. Failures roll back state.
    sha256_context<public> := class<final>:
        Core<private>:sha2_32_context = sha2_32_context{
            InitialState := InitialSHA256State, DigestWordCount := 8}

        Reset<public>()<transacts>:void =
            Core.Reset()

        Update<public>(Data:[]int)<transacts><decides>:void =
            Core.Update[Data]

        Finalize<public>()<transacts><decides>:[]int =
            Core.Finalize[]

    sha224_context<public> := class<final>:
        Core<private>:sha2_32_context = sha2_32_context{
            InitialState := InitialSHA224State, DigestWordCount := 7}

        Reset<public>()<transacts>:void =
            Core.Reset()

        Update<public>(Data:[]int)<transacts><decides>:void =
            Core.Update[Data]

        Finalize<public>()<transacts><decides>:[]int =
            Core.Finalize[]

    # Synchronous convenience API; use bounded Update calls or SHA256Async
    # for large messages. No full padded copy of the input is allocated.
    SHA256<public>(Data:[]int)<transacts><decides>:[]int =
        Context := sha256_context{}
        Context.Update[Data]
        Context.Finalize[]

    SHA256Hex<public>(Data:[]int)<transacts><decides>:string =
        HexEncode[SHA256[Data]]

    SHA224<public>(Data:[]int)<transacts><decides>:[]int =
        Context := sha224_context{}
        Context.Update[Data]
        Context.Finalize[]

    SHA224Hex<public>(Data:[]int)<transacts><decides>:string =
        HexEncode[SHA224[Data]]

    HashSHA2_32<internal>(Data:[]int, Context:sha2_32_context, BytesPerUpdate:int)<suspends>:?[]int =
        if (1 <= BytesPerUpdate <= 4096, Data.Length <= MaxSHA256Bytes):
            Source := STL.int_buffer{Values := Data}
            var Offset:int = 0
            loop:
                if (Offset >= Data.Length):
                    break
                Stop := Offset + Min(BytesPerUpdate, Data.Length - Offset)
                if (Chunk := Source.CopyRange[Offset, Stop], Context.Update[Chunk]):
                    set Offset = Stop
                else:
                    return false
                if (Offset < Data.Length):
                    Sleep(0.0)
            if (Digest := Context.Finalize[]):
                return option{Digest}
            else:
                return false
        else:
            return false

    # Each call owns its core, including across yields and cancellation.
    # Returns false on invalid input or a batch size outside 1..4096.
    HashSHA256<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int =
        Context := sha2_32_context{InitialState := InitialSHA256State, DigestWordCount := 8}
        HashSHA2_32(Data, Context, BytesPerUpdate)

    HashSHA224<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int =
        Context := sha2_32_context{InitialState := InitialSHA224State, DigestWordCount := 7}
        HashSHA2_32(Data, Context, BytesPerUpdate)

    # Compatibility name; new callers can use HashSHA256.
    SHA256Async<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int =
        HashSHA256(Data, ?BytesPerUpdate := BytesPerUpdate)

    # FIPS 180-4 SHA-512 family: each 64-bit word is (high32, low32).
    # No unsigned 64-bit packed value or signed overflow is required.
    SHA512ConstantsHigh<internal>:[]int = array{
        0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
        0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
        0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
        0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
        0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
        0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
        0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
        0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
        0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
        0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
        0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
        0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
        0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
        0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
        0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
        0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
        0xCA273ECE, 0xD186B8C7, 0xEADA7DD6, 0xF57D4F7F,
        0x06F067AA, 0x0A637DC5, 0x113F9804, 0x1B710B35,
        0x28DB77F5, 0x32CAAB7B, 0x3C9EBE0A, 0x431D67C4,
        0x4CC5D4BE, 0x597F299C, 0x5FCB6FAB, 0x6C44198C}

    SHA512ConstantsLow<internal>:[]int = array{
        0xD728AE22, 0x23EF65CD, 0xEC4D3B2F, 0x8189DBBC,
        0xF348B538, 0xB605D019, 0xAF194F9B, 0xDA6D8118,
        0xA3030242, 0x45706FBE, 0x4EE4B28C, 0xD5FFB4E2,
        0xF27B896F, 0x3B1696B1, 0x25C71235, 0xCF692694,
        0x9EF14AD2, 0x384F25E3, 0x8B8CD5B5, 0x77AC9C65,
        0x592B0275, 0x6EA6E483, 0xBD41FBD4, 0x831153B5,
        0xEE66DFAB, 0x2DB43210, 0x98FB213F, 0xBEEF0EE4,
        0x3DA88FC2, 0x930AA725, 0xE003826F, 0x0A0E6E70,
        0x46D22FFC, 0x5C26C926, 0x5AC42AED, 0x9D95B3DF,
        0x8BAF63DE, 0x3C77B2A8, 0x47EDAEE6, 0x1482353B,
        0x4CF10364, 0xBC423001, 0xD0F89791, 0x0654BE30,
        0xD6EF5218, 0x5565A910, 0x5771202A, 0x32BBD1B8,
        0xB8D2D0C8, 0x5141AB53, 0xDF8EEB99, 0xE19B48A8,
        0xC5C95A63, 0xE3418ACB, 0x7763E373, 0xD6B2B8A3,
        0x5DEFB2FC, 0x43172F60, 0xA1F0AB72, 0x1A6439EC,
        0x23631E28, 0xDE82BDE9, 0xB2C67915, 0xE372532B,
        0xEA26619C, 0x21C0C207, 0xCDE0EB1E, 0xEE6ED178,
        0x72176FBA, 0xA2C898A6, 0xBEF90DAE, 0x131C471B,
        0x23047D84, 0x40C72493, 0x15C9BEBC, 0x9C100D4C,
        0xCB3E42B6, 0xFC657E2A, 0x3AD6FAEC, 0x4A475817}

    InitialSHA512State<internal>:[]int = array{
        0x6A09E667, 0xF3BCC908, 0xBB67AE85, 0x84CAA73B,
        0x3C6EF372, 0xFE94F82B, 0xA54FF53A, 0x5F1D36F1,
        0x510E527F, 0xADE682D1, 0x9B05688C, 0x2B3E6C1F,
        0x1F83D9AB, 0xFB41BD6B, 0x5BE0CD19, 0x137E2179}

    InitialSHA384State<internal>:[]int = array{
        0xCBBB9D5D, 0xC1059ED8, 0x629A292A, 0x367CD507,
        0x9159015A, 0x3070DD17, 0x152FECD8, 0xF70E5939,
        0x67332667, 0xFFC00B31, 0x8EB44A87, 0x68581511,
        0xDB0C2E0D, 0x64F98FA7, 0x47B5481D, 0xBEFA4FA4}

    InitialSHA512_224State<internal>:[]int = array{
        0x8C3D37C8, 0x19544DA2, 0x73E19966, 0x89DCD4D6,
        0x1DFAB7AE, 0x32FF9C82, 0x679DD514, 0x582F9FCF,
        0x0F6D2B69, 0x7BD44DA8, 0x77E36F73, 0x04C48942,
        0x3F9D85A8, 0x6A1D36C8, 0x1112E6AD, 0x91D692A1}

    InitialSHA512_256State<internal>:[]int = array{
        0x22312194, 0xFC2BF72C, 0x9F555FA3, 0xC84C64C2,
        0x2393B86B, 0x6F53B151, 0x96387719, 0x5940EABD,
        0x96283EE2, 0xA88EFFE3, 0xBE5E1E25, 0x53863992,
        0x2B0199FC, 0x2C85B8AA, 0x0EB72DDC, 0x81C52CA2}

    SHA512SmallSigma0<internal>(High:int, Low:int)<computes>:tuple(int, int) =
        R1H := BitOr(Quotient[High, 2] or 0, BitAnd(Low, 1) * 2147483648)
        R1L := BitOr(Quotient[Low, 2] or 0, BitAnd(High, 1) * 2147483648)
        R8H := BitOr(Quotient[High, 256] or 0, BitAnd(Low, 255) * 16777216)
        R8L := BitOr(Quotient[Low, 256] or 0, BitAnd(High, 255) * 16777216)
        S7H := Quotient[High, 128] or 0
        S7L := BitOr(Quotient[Low, 128] or 0, BitAnd(High, 127) * 33554432)
        (BitXor(BitXor(R1H, R8H), S7H), BitXor(BitXor(R1L, R8L), S7L))

    SHA512SmallSigma1<internal>(High:int, Low:int)<computes>:tuple(int, int) =
        R19H := BitOr(Quotient[High, 524288] or 0, BitAnd(Low, 524287) * 8192)
        R19L := BitOr(Quotient[Low, 524288] or 0, BitAnd(High, 524287) * 8192)
        R61H := BitOr(Quotient[Low, 536870912] or 0, BitAnd(High, 536870911) * 8)
        R61L := BitOr(Quotient[High, 536870912] or 0, BitAnd(Low, 536870911) * 8)
        S6H := Quotient[High, 64] or 0
        S6L := BitOr(Quotient[Low, 64] or 0, BitAnd(High, 63) * 67108864)
        (BitXor(BitXor(R19H, R61H), S6H), BitXor(BitXor(R19L, R61L), S6L))

    SHA512BigSigma0<internal>(High:int, Low:int)<computes>:tuple(int, int) =
        R28H := BitOr(Quotient[High, 268435456] or 0, BitAnd(Low, 268435455) * 16)
        R28L := BitOr(Quotient[Low, 268435456] or 0, BitAnd(High, 268435455) * 16)
        R34H := BitOr(Quotient[Low, 4] or 0, BitAnd(High, 3) * 1073741824)
        R34L := BitOr(Quotient[High, 4] or 0, BitAnd(Low, 3) * 1073741824)
        R39H := BitOr(Quotient[Low, 128] or 0, BitAnd(High, 127) * 33554432)
        R39L := BitOr(Quotient[High, 128] or 0, BitAnd(Low, 127) * 33554432)
        (BitXor(BitXor(R28H, R34H), R39H), BitXor(BitXor(R28L, R34L), R39L))

    SHA512BigSigma1<internal>(High:int, Low:int)<computes>:tuple(int, int) =
        R14H := BitOr(Quotient[High, 16384] or 0, BitAnd(Low, 16383) * 262144)
        R14L := BitOr(Quotient[Low, 16384] or 0, BitAnd(High, 16383) * 262144)
        R18H := BitOr(Quotient[High, 262144] or 0, BitAnd(Low, 262143) * 16384)
        R18L := BitOr(Quotient[Low, 262144] or 0, BitAnd(High, 262143) * 16384)
        R41H := BitOr(Quotient[Low, 512] or 0, BitAnd(High, 511) * 8388608)
        R41L := BitOr(Quotient[High, 512] or 0, BitAnd(Low, 511) * 8388608)
        (BitXor(BitXor(R14H, R18H), R41H), BitXor(BitXor(R14L, R18L), R41L))

    CompressSHA512<internal>(State:[]int, Data:[]int, Offset:int)<transacts><decides>:[]int =
        State.Length = 16
        0 <= Offset <= Data.Length - 128
        var ScheduleHigh:[]int = for (Index := 0..79) do 0
        var ScheduleLow:[]int = for (Index := 0..79) do 0
        for (Index := 0..15):
            WordOffset := Offset + Index * 8
            High := Data[WordOffset] * 16777216 + Data[WordOffset + 1] * 65536 + Data[WordOffset + 2] * 256 + Data[WordOffset + 3]
            Low := Data[WordOffset + 4] * 16777216 + Data[WordOffset + 5] * 65536 + Data[WordOffset + 6] * 256 + Data[WordOffset + 7]
            set ScheduleHigh[Index] = High
            set ScheduleLow[Index] = Low
        for (Index := 16..79):
            Sigma0 := SHA512SmallSigma0(ScheduleHigh[Index - 15], ScheduleLow[Index - 15])
            Sigma1 := SHA512SmallSigma1(ScheduleHigh[Index - 2], ScheduleLow[Index - 2])
            LowSum := ScheduleLow[Index - 16] + Sigma0(1) + ScheduleLow[Index - 7] + Sigma1(1)
            set ScheduleLow[Index] = BitAnd(LowSum, WordMask)
            High := BitAnd(ScheduleHigh[Index - 16] + Sigma0(0) + ScheduleHigh[Index - 7] + Sigma1(0) + (Quotient[LowSum, 4294967296] or 0), WordMask)
            set ScheduleHigh[Index] = High

        var AHigh:int = State[0]
        var ALow:int = State[1]
        var BHigh:int = State[2]
        var BLow:int = State[3]
        var CHigh:int = State[4]
        var CLow:int = State[5]
        var DHigh:int = State[6]
        var DLow:int = State[7]
        var EHigh:int = State[8]
        var ELow:int = State[9]
        var FHigh:int = State[10]
        var FLow:int = State[11]
        var GHigh:int = State[12]
        var GLow:int = State[13]
        var HHigh:int = State[14]
        var HLow:int = State[15]

        for (Index := 0..79):
            Sum1 := SHA512BigSigma1(EHigh, ELow)
            ChoiceHigh := BitXor(GHigh, BitAnd(EHigh, BitXor(FHigh, GHigh)))
            ChoiceLow := BitXor(GLow, BitAnd(ELow, BitXor(FLow, GLow)))
            Temp1LowSum := HLow + Sum1(1) + ChoiceLow + SHA512ConstantsLow[Index] + ScheduleLow[Index]
            Temp1Low := BitAnd(Temp1LowSum, WordMask)
            Temp1High := BitAnd(HHigh + Sum1(0) + ChoiceHigh + SHA512ConstantsHigh[Index] + ScheduleHigh[Index] + (Quotient[Temp1LowSum, 4294967296] or 0), WordMask)
            Sum0 := SHA512BigSigma0(AHigh, ALow)
            MajorityHigh := BitOr(BitAnd(AHigh, BHigh), BitAnd(CHigh, BitOr(AHigh, BHigh)))
            MajorityLow := BitOr(BitAnd(ALow, BLow), BitAnd(CLow, BitOr(ALow, BLow)))
            Temp2LowSum := Sum0(1) + MajorityLow
            Temp2Low := BitAnd(Temp2LowSum, WordMask)
            Temp2High := BitAnd(Sum0(0) + MajorityHigh + (Quotient[Temp2LowSum, 4294967296] or 0), WordMask)
            NextELowSum := DLow + Temp1Low
            NextALowSum := Temp1Low + Temp2Low
            set HHigh = GHigh
            set HLow = GLow
            set GHigh = FHigh
            set GLow = FLow
            set FHigh = EHigh
            set FLow = ELow
            set EHigh = BitAnd(DHigh + Temp1High + (Quotient[NextELowSum, 4294967296] or 0), WordMask)
            set ELow = BitAnd(NextELowSum, WordMask)
            set DHigh = CHigh
            set DLow = CLow
            set CHigh = BHigh
            set CLow = BLow
            set BHigh = AHigh
            set BLow = ALow
            set AHigh = BitAnd(Temp1High + Temp2High + (Quotient[NextALowSum, 4294967296] or 0), WordMask)
            set ALow = BitAnd(NextALowSum, WordMask)

        FinalHigh := array{AHigh, BHigh, CHigh, DHigh, EHigh, FHigh, GHigh, HHigh}
        FinalLow := array{ALow, BLow, CLow, DLow, ELow, FLow, GLow, HLow}
        var Output:[]int = array{}
        for (Index := 0..7):
            LowSum := State[Index * 2 + 1] + FinalLow[Index]
            HighSum := State[Index * 2] + FinalHigh[Index] + (Quotient[LowSum, 4294967296] or 0)
            set Output += array{BitAnd(HighSum, WordMask), BitAnd(LowSum, WordMask)}
        Output

    # The byte counter uses four big-endian 32-bit limbs (up to 125 bits).
    # A single update's native array length fits in a signed 64-bit integer.
    AddSHA512ByteCount<internal>(Count:[]int, Increment:int)<computes><decides>:[]int =
        Count.Length = 4
        for (Word : Count):
            0 <= Word <= WordMask
        Count[0] <= 536870911
        0 <= Increment <= 9223372036854775807
        Low0 := Count[3] + BitAnd(Increment, WordMask)
        Low1 := Count[2] + (Quotient[Increment, 4294967296] or 0) + (Quotient[Low0, 4294967296] or 0)
        High0 := Count[1] + (Quotient[Low1, 4294967296] or 0)
        High1 := Count[0] + (Quotient[High0, 4294967296] or 0)
        High1 <= 536870911
        array{High1, BitAnd(High0, WordMask), BitAnd(Low1, WordMask), BitAnd(Low0, WordMask)}

    SHA512BitLengthBytes<internal>(Count:[]int)<computes><decides>:[]int =
        Checked := AddSHA512ByteCount[Count, 0]
        BitLengthWords := array:
            Checked[0] * 8 + (Quotient[Checked[1], 536870912] or 0)
            BitAnd(Checked[1], 536870911) * 8 + (Quotient[Checked[2], 536870912] or 0)
            BitAnd(Checked[2], 536870911) * 8 + (Quotient[Checked[3], 536870912] or 0)
            BitAnd(Checked[3], 536870911) * 8
        for (Word : BitLengthWords, Byte : WordBytes(Word)) do Byte

    # All four variants share padding, compression, and lifecycle. A digest
    # word here is a 32-bit limb; SHA-512/224 retains seven such limbs.
    sha2_64_context<internal> := class<final>:
        InitialState<internal>:[]int
        DigestWordCount<internal>:int
        var State<private>:?[]int = false
        var Pending<private>:[]int = array{}
        var ByteCount<private>:[]int = array{0, 0, 0, 0}
        var CachedDigest<private>:?[]int = false

        Reset<internal>()<transacts>:void =
            set State = false
            set Pending = array{}
            set ByteCount = array{0, 0, 0, 0}
            set CachedDigest = false

        Clone<internal>()<transacts>:sha2_64_context =
            sha2_64_context{
                InitialState := InitialState, DigestWordCount := DigestWordCount,
                State := State, Pending := Pending, ByteCount := ByteCount,
                CachedDigest := CachedDigest}

        Update<internal>(Data:[]int)<transacts><decides>:void =
            not CachedDigest?
            NextCount := AddSHA512ByteCount[ByteCount, Data.Length]
            ValidateBytes[Data]
            var WorkingState:[]int = if (Existing := State?) then Existing else InitialState
            Source := STL.int_buffer{Values := Data}
            var Offset:int = 0
            if (Pending.Length > 0):
                FillCount := Min(128 - Pending.Length, Data.Length)
                Fill := Source.CopyRange[0, FillCount]
                set Pending += Fill
                set Offset = FillCount
                if (Pending.Length = 128):
                    NextState := CompressSHA512[WorkingState, Pending, 0]
                    set WorkingState = NextState
                    set Pending = array{}
            BlockCount := Quotient[Data.Length - Offset, 128]
            if (BlockCount > 0):
                for (Block := 0..BlockCount - 1):
                    NextState := CompressSHA512[WorkingState, Data, Offset]
                    set WorkingState = NextState
                    set Offset += 128
            if (Offset < Data.Length):
                Remainder := Source.CopyRange[Offset, Data.Length]
                set Pending += Remainder
            set State = option{WorkingState}
            set ByteCount = NextCount

        Finalize<internal>()<transacts><decides>:[]int =
            if (Digest := CachedDigest?):
                Digest
            else:
                LengthBytes := SHA512BitLengthBytes[ByteCount]
                ZeroCount := Mod[239 - Pending.Length, 128]
                Zeros := for (Index := 0..127, Index < ZeroCount) do 0
                Tail := Pending + array{128} + Zeros + LengthBytes
                BlockCount := Quotient[Tail.Length, 128]
                var FinalState:[]int = if (Existing := State?) then Existing else InitialState
                for (Block := 0..BlockCount - 1):
                    NextState := CompressSHA512[FinalState, Tail, Block * 128]
                    set FinalState = NextState
                Digest := for (Index -> Word : FinalState, Index < DigestWordCount, Byte : WordBytes(Word)) do Byte
                set CachedDigest = option{Digest}
                Digest

    HashSHA2_64<internal>(Data:[]int, Context:sha2_64_context, BytesPerUpdate:int)<suspends>:?[]int =
        if (1 <= BytesPerUpdate <= 4096):
            Source := STL.int_buffer{Values := Data}
            var Offset:int = 0
            loop:
                if (Offset >= Data.Length):
                    break
                Stop := Offset + Min(BytesPerUpdate, Data.Length - Offset)
                if (Chunk := Source.CopyRange[Offset, Stop], Context.Update[Chunk]):
                    set Offset = Stop
                else:
                    return false
                if (Offset < Data.Length):
                    Sleep(0.0)
            if (Digest := Context.Finalize[]):
                return option{Digest}
            else:
                return false
        else:
            return false

    sha384_context<public> := class<final>:
        Core<private>:sha2_64_context = sha2_64_context{
            InitialState := InitialSHA384State, DigestWordCount := 12}

        Reset<public>()<transacts>:void =
            Core.Reset()

        Update<public>(Data:[]int)<transacts><decides>:void =
            Core.Update[Data]

        Finalize<public>()<transacts><decides>:[]int =
            Core.Finalize[]

    SHA384<public>(Data:[]int)<transacts><decides>:[]int =
        Context := sha384_context{}
        Context.Update[Data]
        Context.Finalize[]

    SHA384Hex<public>(Data:[]int)<transacts><decides>:string =
        HexEncode[SHA384[Data]]

    HashSHA384<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int =
        Context := sha2_64_context{InitialState := InitialSHA384State, DigestWordCount := 12}
        HashSHA2_64(Data, Context, BytesPerUpdate)

    sha512_context<public> := class<final>:
        Core<private>:sha2_64_context = sha2_64_context{
            InitialState := InitialSHA512State, DigestWordCount := 16}

        Reset<public>()<transacts>:void =
            Core.Reset()

        Update<public>(Data:[]int)<transacts><decides>:void =
            Core.Update[Data]

        Finalize<public>()<transacts><decides>:[]int =
            Core.Finalize[]

    SHA512<public>(Data:[]int)<transacts><decides>:[]int =
        Context := sha512_context{}
        Context.Update[Data]
        Context.Finalize[]

    SHA512Hex<public>(Data:[]int)<transacts><decides>:string =
        HexEncode[SHA512[Data]]

    HashSHA512<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int =
        Context := sha2_64_context{InitialState := InitialSHA512State, DigestWordCount := 16}
        HashSHA2_64(Data, Context, BytesPerUpdate)

    sha512_224_context<public> := class<final>:
        Core<private>:sha2_64_context = sha2_64_context{
            InitialState := InitialSHA512_224State, DigestWordCount := 7}

        Reset<public>()<transacts>:void =
            Core.Reset()

        Update<public>(Data:[]int)<transacts><decides>:void =
            Core.Update[Data]

        Finalize<public>()<transacts><decides>:[]int =
            Core.Finalize[]

    SHA512_224<public>(Data:[]int)<transacts><decides>:[]int =
        Context := sha512_224_context{}
        Context.Update[Data]
        Context.Finalize[]

    SHA512_224Hex<public>(Data:[]int)<transacts><decides>:string =
        HexEncode[SHA512_224[Data]]

    HashSHA512_224<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int =
        Context := sha2_64_context{InitialState := InitialSHA512_224State, DigestWordCount := 7}
        HashSHA2_64(Data, Context, BytesPerUpdate)

    sha512_256_context<public> := class<final>:
        Core<private>:sha2_64_context = sha2_64_context{
            InitialState := InitialSHA512_256State, DigestWordCount := 8}

        Reset<public>()<transacts>:void =
            Core.Reset()

        Update<public>(Data:[]int)<transacts><decides>:void =
            Core.Update[Data]

        Finalize<public>()<transacts><decides>:[]int =
            Core.Finalize[]

    SHA512_256<public>(Data:[]int)<transacts><decides>:[]int =
        Context := sha512_256_context{}
        Context.Update[Data]
        Context.Finalize[]

    SHA512_256Hex<public>(Data:[]int)<transacts><decides>:string =
        HexEncode[SHA512_256[Data]]

    HashSHA512_256<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int =
        Context := sha2_64_context{InitialState := InitialSHA512_256State, DigestWordCount := 8}
        HashSHA2_64(Data, Context, BytesPerUpdate)

    sha2_algorithm<public> := enum:
        Sha224
        Sha256
        Sha384
        Sha512
        Sha512_224
        Sha512_256

    SHA2DigestSize<public>(Algorithm:sha2_algorithm)<computes>:int =
        case (Algorithm):
            sha2_algorithm.Sha224 => 28
            sha2_algorithm.Sha256 => 32
            sha2_algorithm.Sha384 => 48
            sha2_algorithm.Sha512 => 64
            sha2_algorithm.Sha512_224 => 28
            sha2_algorithm.Sha512_256 => 32

    SHA2BlockSize<public>(Algorithm:sha2_algorithm)<computes>:int =
        case (Algorithm):
            sha2_algorithm.Sha224 => 64
            sha2_algorithm.Sha256 => 64
            sha2_algorithm.Sha384 => 128
            sha2_algorithm.Sha512 => 128
            sha2_algorithm.Sha512_224 => 128
            sha2_algorithm.Sha512_256 => 128

    # The wrapper only dispatches once per update. Compression stays specialized.
    sha2_digest_state<internal> := class<final>:
        Narrow<internal>:?sha2_32_context = false
        Wide<internal>:?sha2_64_context = false

        Update<internal>(Data:[]int)<transacts><decides>:void =
            if (Core := Narrow?):
                Core.Update[Data]
            else:
                Core := Wide?
                Core.Update[Data]

        Finalize<internal>()<transacts><decides>:[]int =
            if (Core := Narrow?):
                Core.Finalize[]
            else:
                Core := Wide?
                Core.Finalize[]

        Clone<internal>()<transacts><decides>:sha2_digest_state =
            if (Core := Narrow?):
                sha2_digest_state{Narrow := option{Core.Clone()}}
            else:
                Core := Wide?
                sha2_digest_state{Wide := option{Core.Clone()}}

    MakeSHA2State<internal>(Algorithm:sha2_algorithm)<transacts>:sha2_digest_state =
        case (Algorithm):
            sha2_algorithm.Sha224 => sha2_digest_state{Narrow := option{sha2_32_context{InitialState := InitialSHA224State, DigestWordCount := 7}}}
            sha2_algorithm.Sha256 => sha2_digest_state{Narrow := option{sha2_32_context{InitialState := InitialSHA256State, DigestWordCount := 8}}}
            sha2_algorithm.Sha384 => sha2_digest_state{Wide := option{sha2_64_context{InitialState := InitialSHA384State, DigestWordCount := 12}}}
            sha2_algorithm.Sha512 => sha2_digest_state{Wide := option{sha2_64_context{InitialState := InitialSHA512State, DigestWordCount := 16}}}
            sha2_algorithm.Sha512_224 => sha2_digest_state{Wide := option{sha2_64_context{InitialState := InitialSHA512_224State, DigestWordCount := 7}}}
            sha2_algorithm.Sha512_256 => sha2_digest_state{Wide := option{sha2_64_context{InitialState := InitialSHA512_256State, DigestWordCount := 8}}}

    # Prototypes contain key-derived state and remain inside the crypto module.
    # Every message clones them; reset and finalization never mutate prototypes.
    hmac_key<internal> := class<final>:
        Algorithm<internal>:sha2_algorithm
        Inner<internal>:sha2_digest_state
        Outer<internal>:sha2_digest_state

    MakeHMACKey<internal>(Algorithm:sha2_algorithm, Key:[]int)<transacts><decides>:hmac_key =
        BlockBytes := SHA2BlockSize(Algorithm)
        var EffectiveKey:[]int = array{}
        if (Key.Length > BlockBytes):
            KeyState := MakeSHA2State(Algorithm)
            KeyState.Update[Key]
            Reduced := KeyState.Finalize[]
            set EffectiveKey = Reduced
        else:
            ValidateBytes[Key]
            set EffectiveKey = Key
        EffectiveKey.Length <= BlockBytes
        InnerPad := for (Index := 0..BlockBytes - 1) do BitXor(EffectiveKey[Index] or 0, 0x36)
        OuterPad := for (Index := 0..BlockBytes - 1) do BitXor(EffectiveKey[Index] or 0, 0x5C)
        Inner := MakeSHA2State(Algorithm)
        Outer := MakeSHA2State(Algorithm)
        Inner.Update[InnerPad]
        Outer.Update[OuterPad]
        hmac_key{Algorithm := Algorithm, Inner := Inner, Outer := Outer}

    # Use MakeHMAC[Algorithm, Key]. The mandatory internal key field prevents
    # construction of an uninitialized public context outside this module.
    hmac_context<public> := class<internal><final>:
        Key<internal>:hmac_key
        var Current<private>:?sha2_digest_state = false
        var CachedDigest<private>:?[]int = false

        DigestSize<public>()<computes>:int =
            SHA2DigestSize(Key.Algorithm)

        BlockSize<public>()<computes>:int =
            SHA2BlockSize(Key.Algorithm)

        GetInner<private>()<transacts><decides>:sha2_digest_state =
            if (Core := Current?):
                Core
            else:
                Core := Key.Inner.Clone[]
                set Current = option{Core}
                Core

        Reset<public>()<transacts>:void =
            set Current = false
            set CachedDigest = false

        Update<public>(Data:[]int)<transacts><decides>:void =
            not CachedDigest?
            Core := GetInner[]
            Core.Update[Data]

        Finalize<public>()<transacts><decides>:[]int =
            if (Digest := CachedDigest?):
                Digest
            else:
                Core := GetInner[]
                InnerDigest := Core.Finalize[]
                Outer := Key.Outer.Clone[]
                Outer.Update[InnerDigest]
                Digest := Outer.Finalize[]
                set CachedDigest = option{Digest}
                Digest

        # Only the suspending authenticator calls this on its private context.
        # Yield between inner and outer finalization to keep them in separate slices.
        Finish<internal>()<suspends>:?[]int =
            if (Digest := CachedDigest?):
                return option{Digest}
            if (Core := GetInner[], InnerDigest := Core.Finalize[], Outer := Key.Outer.Clone[]):
                Sleep(0.0)
                if (Outer.Update[InnerDigest], Digest := Outer.Finalize[]):
                    set CachedDigest = option{Digest}
                    return option{Digest}
            return false

    MakeHMAC<public>(Algorithm:sha2_algorithm, Key:[]int)<transacts><decides>:hmac_context =
        Material := MakeHMACKey[Algorithm, Key]
        hmac_context{Key := Material}

    HMAC<public>(Algorithm:sha2_algorithm, Key:[]int, Data:[]int)<transacts><decides>:[]int =
        Context := MakeHMAC[Algorithm, Key]
        Context.Update[Data]
        Context.Finalize[]

    # Compare every byte after validating lengths and byte ranges. Verse does
    # not establish a constant-time runtime guarantee for these operations.
    TagsMatch<internal>(Actual:[]int, Expected:[]int)<transacts><decides>:void =
        Actual.Length = Expected.Length
        ValidateBytes[Actual]
        ValidateBytes[Expected]
        var Difference:int = 0
        for (Index -> Byte : Actual):
            ExpectedByte := Expected[Index]
            set Difference = BitOr(Difference, BitXor(Byte, ExpectedByte))
        Difference = 0

    VerifyHMAC<public>(Algorithm:sha2_algorithm, Key:[]int, Data:[]int, Tag:[]int)<transacts><decides>:void =
        Tag.Length = SHA2DigestSize(Algorithm)
        ValidateBytes[Tag]
        Actual := HMAC[Algorithm, Key, Data]
        TagsMatch[Actual, Tag]

    HashSHA2State<internal>(Algorithm:sha2_algorithm, Data:[]int, BytesPerUpdate:int)<suspends>:?[]int =
        if (1 <= BytesPerUpdate <= 4096):
            Core := MakeSHA2State(Algorithm)
            Source := STL.int_buffer{Values := Data}
            var Offset:int = 0
            loop:
                if (Offset >= Data.Length):
                    break
                Stop := Offset + Min(BytesPerUpdate, Data.Length - Offset)
                if (Chunk := Source.CopyRange[Offset, Stop], Core.Update[Chunk]):
                    set Offset = Stop
                else:
                    return false
                if (Offset < Data.Length):
                    Sleep(0.0)
            if (Digest := Core.Finalize[]):
                return option{Digest}
        return false

    CreateHMAC<public>(Algorithm:sha2_algorithm, Key:[]int, ?BytesPerUpdate:int = 128)<suspends>:?hmac_context =
        if (BytesPerUpdate < 1 or BytesPerUpdate > 4096):
            return false
        if (Key.Length > SHA2BlockSize(Algorithm)):
            Reduced := HashSHA2State(Algorithm, Key, BytesPerUpdate)
            if (EffectiveKey := Reduced?):
                Sleep(0.0)
                if (Context := MakeHMAC[Algorithm, EffectiveKey]):
                    return option{Context}
        else:
            if (Context := MakeHMAC[Algorithm, Key]):
                return option{Context}
        return false

    AuthenticateHMAC<public>(Algorithm:sha2_algorithm, Key:[]int, Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int =
        MaybeContext := CreateHMAC(Algorithm, Key, ?BytesPerUpdate := BytesPerUpdate)
        if (Context := MaybeContext?):
            Sleep(0.0)
            Source := STL.int_buffer{Values := Data}
            var Offset:int = 0
            loop:
                if (Offset >= Data.Length):
                    break
                Stop := Offset + Min(BytesPerUpdate, Data.Length - Offset)
                if (Chunk := Source.CopyRange[Offset, Stop], Context.Update[Chunk]):
                    set Offset = Stop
                else:
                    return false
                if (Offset < Data.Length):
                    Sleep(0.0)
            return Context.Finish()
        return false

    HMACSHA224<public>(Key:[]int, Data:[]int)<transacts><decides>:[]int =
        HMAC[sha2_algorithm.Sha224, Key, Data]

    HMACSHA256<public>(Key:[]int, Data:[]int)<transacts><decides>:[]int =
        HMAC[sha2_algorithm.Sha256, Key, Data]

    HMACSHA384<public>(Key:[]int, Data:[]int)<transacts><decides>:[]int =
        HMAC[sha2_algorithm.Sha384, Key, Data]

    HMACSHA512<public>(Key:[]int, Data:[]int)<transacts><decides>:[]int =
        HMAC[sha2_algorithm.Sha512, Key, Data]

    HMACSHA512_224<public>(Key:[]int, Data:[]int)<transacts><decides>:[]int =
        HMAC[sha2_algorithm.Sha512_224, Key, Data]

    HMACSHA512_256<public>(Key:[]int, Data:[]int)<transacts><decides>:[]int =
        HMAC[sha2_algorithm.Sha512_256, Key, Data]

    # Empty salt is equivalent to the specified HashLen zero bytes under HMAC.
    HKDFExtract<public>(Algorithm:sha2_algorithm, Salt:[]int, InputKeyMaterial:[]int)<transacts><decides>:[]int =
        HMAC[Algorithm, Salt, InputKeyMaterial]

    HKDFExpand<public>(Algorithm:sha2_algorithm, PRK:[]int, Info:[]int, Length:int)<transacts><decides>:[]int =
        HashBytes := SHA2DigestSize(Algorithm)
        0 <= Length <= 255 * HashBytes
        PRK.Length >= HashBytes
        ValidateBytes[PRK]
        ValidateBytes[Info]
        if (Length = 0):
            array{}
        else:
            Context := MakeHMAC[Algorithm, PRK]
            Count := Quotient[Length + HashBytes - 1, HashBytes]
            var Previous:[]int = array{}
            var Blocks:[][]int = array{}
            for (Index := 1..Count):
                Context.Reset()
                Context.Update[Previous]
                Context.Update[Info]
                Context.Update[array{Index}]
                Block := Context.Finalize[]
                set Previous = Block
                Remaining := Length - (Index - 1) * HashBytes
                Part := for (Offset := 0..Min(HashBytes, Remaining) - 1) do Block[Offset]
                set Blocks += array{Part}
            for (Block : Blocks, Byte : Block) do Byte

    HKDF<public>(Algorithm:sha2_algorithm, InputKeyMaterial:[]int, Salt:[]int, Info:[]int, Length:int)<transacts><decides>:[]int =
        0 <= Length <= 255 * SHA2DigestSize(Algorithm)
        PRK := HKDFExtract[Algorithm, Salt, InputKeyMaterial]
        HKDFExpand[Algorithm, PRK, Info, Length]

    CheckByteSequence<internal>(Data:[]int, BytesPerUpdate:int)<suspends>:logic =
        var Count:int = 0
        for (Byte : Data):
            if (Byte < 0 or Byte > 255):
                return false
            set Count += 1
            if (Count >= BytesPerUpdate):
                Sleep(0.0)
                set Count = 0
        return true

    UpdateHMACSequence<internal>(Context:hmac_context, Data:[]int, BytesPerUpdate:int)<suspends>:logic =
        Source := STL.int_buffer{Values := Data}
        var Offset:int = 0
        loop:
            if (Offset >= Data.Length):
                break
            Stop := Offset + Min(BytesPerUpdate, Data.Length - Offset)
            if (Chunk := Source.CopyRange[Offset, Stop], Context.Update[Chunk]):
                set Offset = Stop
            else:
                return false
            if (Offset < Data.Length):
                Sleep(0.0)
        return true

    ExtractHKDF<public>(Algorithm:sha2_algorithm, Salt:[]int, InputKeyMaterial:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int =
        AuthenticateHMAC(Algorithm, Salt, InputKeyMaterial, ?BytesPerUpdate := BytesPerUpdate)

    ExpandHKDF<public>(Algorithm:sha2_algorithm, PRK:[]int, Info:[]int, Length:int, ?BytesPerUpdate:int = 128)<suspends>:?[]int =
        HashBytes := SHA2DigestSize(Algorithm)
        if (BytesPerUpdate < 1 or BytesPerUpdate > 4096):
            return false
        if (Length < 0 or Length > 255 * HashBytes or PRK.Length < HashBytes):
            return false
        if (Length = 0):
            ValidKey := CheckByteSequence(PRK, BytesPerUpdate)
            ValidInfo := CheckByteSequence(Info, BytesPerUpdate)
            if (ValidKey?, ValidInfo?):
                return option{array{}}
            return false
        MaybeContext := CreateHMAC(Algorithm, PRK, ?BytesPerUpdate := BytesPerUpdate)
        if (Context := MaybeContext?):
            Sleep(0.0)
            Count := Quotient[Length + HashBytes - 1, HashBytes] or 0
            var Previous:[]int = array{}
            var Blocks:[][]int = array{}
            for (Index := 1..Count):
                Context.Reset()
                # Negating a successful transactional update would roll it back.
                if (Context.Update[Previous]) {}
                else:
                    return false
                Valid := UpdateHMACSequence(Context, Info, BytesPerUpdate)
                if (not Valid?):
                    return false
                if (Context.Update[array{Index}]) {}
                else:
                    return false
                MaybeBlock := Context.Finish()
                if (Block := MaybeBlock?):
                    set Previous = Block
                    Remaining := Length - (Index - 1) * HashBytes
                    Buffer := STL.int_buffer{Values := Block}
                    if (Part := Buffer.CopyRange[0, Min(HashBytes, Remaining)]):
                        set Blocks += array{Part}
                    else:
                        return false
                else:
                    return false
                if (Index < Count):
                    Sleep(0.0)
            return option{for (Block : Blocks, Byte : Block) do Byte}
        return false

    DeriveHKDF<public>(Algorithm:sha2_algorithm, InputKeyMaterial:[]int, Salt:[]int, Info:[]int, Length:int, ?BytesPerUpdate:int = 128)<suspends>:?[]int =
        if (Length < 0 or Length > 255 * SHA2DigestSize(Algorithm)):
            return false
        MaybePRK := ExtractHKDF(Algorithm, Salt, InputKeyMaterial, ?BytesPerUpdate := BytesPerUpdate)
        if (PRK := MaybePRK?):
            return ExpandHKDF(Algorithm, PRK, Info, Length, ?BytesPerUpdate := BytesPerUpdate)
        return false

    HKDFSHA256<public>(InputKeyMaterial:[]int, Salt:[]int, Info:[]int, Length:int)<transacts><decides>:[]int =
        HKDF[sha2_algorithm.Sha256, InputKeyMaterial, Salt, Info, Length]

    HKDFSHA512<public>(InputKeyMaterial:[]int, Salt:[]int, Info:[]int, Length:int)<transacts><decides>:[]int =
        HKDF[sha2_algorithm.Sha512, InputKeyMaterial, Salt, Info, Length]
