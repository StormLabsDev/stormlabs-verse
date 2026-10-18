# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API index: see ../API.md for signatures; ../README.md for validation status.
# - CharToByte, ByteToChar; UTF8ScalarAt returns (scalar, byte width).
# - ValidateUTF8, UTF8Encode, UTF8Decode, CodePointsToUTF8, UTF8ToCodePoints.
# - Base64Encode, Base64Decode, Base64URLEncode, Base64URLDecode; HexEncode, HexDecode.

Encoding<public> := module:
    # Private holders avoid passing the complete source array to every group.
    text_buffer<internal> := class<final>:
        Values:string

    Base64Alphabet<internal>:string = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    Base64URLAlphabet<internal>:string = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    Base64Values<internal>:[char]int = map:
        'A' => 0
        'B' => 1
        'C' => 2
        'D' => 3
        'E' => 4
        'F' => 5
        'G' => 6
        'H' => 7
        'I' => 8
        'J' => 9
        'K' => 10
        'L' => 11
        'M' => 12
        'N' => 13
        'O' => 14
        'P' => 15
        'Q' => 16
        'R' => 17
        'S' => 18
        'T' => 19
        'U' => 20
        'V' => 21
        'W' => 22
        'X' => 23
        'Y' => 24
        'Z' => 25
        'a' => 26
        'b' => 27
        'c' => 28
        'd' => 29
        'e' => 30
        'f' => 31
        'g' => 32
        'h' => 33
        'i' => 34
        'j' => 35
        'k' => 36
        'l' => 37
        'm' => 38
        'n' => 39
        'o' => 40
        'p' => 41
        'q' => 42
        'r' => 43
        's' => 44
        't' => 45
        'u' => 46
        'v' => 47
        'w' => 48
        'x' => 49
        'y' => 50
        'z' => 51
        '0' => 52
        '1' => 53
        '2' => 54
        '3' => 55
        '4' => 56
        '5' => 57
        '6' => 58
        '7' => 59
        '8' => 60
        '9' => 61
        '+' => 62
        '/' => 63
        '-' => 62
        '_' => 63

    ValidateBytes<internal>(Data:[]int)<computes><decides>:void =
        for (Byte : Data):
            0 <= Byte <= 255

    EncodeBase64Group<internal>(Data:STL.int_buffer, Start:int, Alphabet:string, Padding:logic)<transacts><decides>:string =
        A := Data.Values[Start]
        B := Data.Values[Start + 1] or 0
        C := Data.Values[Start + 2] or 0
        Remaining := Data.Values.Length - Start
        First := Alphabet[Quotient[A, 4]]
        Second := Alphabet[BitAnd(A, 3) * 16 + Quotient[B, 16]]
        if (Remaining = 1):
            if (Padding?) then array{First, Second, '=', '='} else array{First, Second}
        else:
            Third := Alphabet[BitAnd(B, 15) * 4 + Quotient[C, 64]]
            if (Remaining = 2):
                if (Padding?) then array{First, Second, Third, '='} else array{First, Second, Third}
            else:
                array{First, Second, Third, Alphabet[BitAnd(C, 63)]}

    EncodeBase64Bytes<internal>(Data:[]int, URL:logic, Padding:logic)<transacts><decides>:string =
        ValidateBytes[Data]
        if (Data.Length = 0):
            ""
        else:
            Buffer := STL.int_buffer{Values := Data}
            Alphabet := if (URL?) then Base64URLAlphabet else Base64Alphabet
            Count := Quotient[Data.Length - 1, 3] + 1
            Groups := for (Index := 0..Count - 1) do EncodeBase64Group[Buffer, Index * 3, Alphabet, Padding]
            Concatenate(Groups)

    # Standard Base64 uses '=' padding exactly when the final group needs it.
    Base64Encode<public>(Data:[]int)<transacts><decides>:string =
        EncodeBase64Bytes[Data, false, true]

    Base64URLEncode<public>(Data:[]int, ?Padding:logic = false)<transacts><decides>:string =
        EncodeBase64Bytes[Data, true, Padding]

    Base64Value<internal>(Character:char, URL:logic)<transacts><decides>:int =
        if (URL?):
            Character <> '+'
            Character <> '/'
        else:
            Character <> '-'
            Character <> '_'
        Base64Values[Character]

    DecodeBase64Group<internal>(Text:text_buffer, Start:int, DataLength:int, URL:logic)<transacts><decides>:[]int =
        Count := Min(4, DataLength - Start)
        Count >= 2
        A := Base64Value[Text.Values[Start], URL]
        B := Base64Value[Text.Values[Start + 1], URL]
        First := A * 4 + Quotient[B, 16]
        if (Count = 2):
            BitAnd(B, 15) = 0
            array{First}
        else:
            C := Base64Value[Text.Values[Start + 2], URL]
            Second := BitAnd(B, 15) * 16 + Quotient[C, 4]
            if (Count = 3):
                BitAnd(C, 3) = 0
                array{First, Second}
            else:
                D := Base64Value[Text.Values[Start + 3], URL]
                array{First, Second, BitAnd(C, 3) * 64 + D}

    DecodeBase64Bytes<internal>(Text:string, URL:logic)<transacts><decides>:[]int =
        if (Text.Length = 0):
            array{}
        else:
            Padding := if (Text[Text.Length - 1] = '=') then (if (Text[Text.Length - 2] = '=') then 2 else 1) else 0
            DataLength := Text.Length - Padding
            Remainder := Mod[DataLength, 4]
            Remainder <> 1
            if (Padding > 0):
                Mod[Text.Length, 4] = 0
                Padding = 4 - Remainder
            else if (not URL?):
                Remainder = 0
            Buffer := text_buffer{Values := Text}
            Count := Quotient[DataLength - 1, 4] + 1
            Groups := for (Index := 0..Count - 1) do DecodeBase64Group[Buffer, Index * 4, DataLength, URL]
            Concatenate(Groups)

    # No whitespace, alternate alphabet, excess padding, or nonzero unused bits.
    Base64Decode<public>(Text:string)<transacts><decides>:[]int =
        DecodeBase64Bytes[Text, false]

    # Accepts canonical padded and unpadded URL forms, with no mixed alphabets.
    Base64URLDecode<public>(Text:string)<transacts><decides>:[]int =
        DecodeBase64Bytes[Text, true]

    HexAlphabet<internal>:string = "0123456789abcdef"
    HexValues<internal>:[char]int = map:
        '0' => 0
        '1' => 1
        '2' => 2
        '3' => 3
        '4' => 4
        '5' => 5
        '6' => 6
        '7' => 7
        '8' => 8
        '9' => 9
        'a' => 10
        'b' => 11
        'c' => 12
        'd' => 13
        'e' => 14
        'f' => 15
        'A' => 10
        'B' => 11
        'C' => 12
        'D' => 13
        'E' => 14
        'F' => 15

    HexEncode<public>(Data:[]int)<transacts><decides>:string =
        ValidateBytes[Data]
        for (Byte : Data, Divisor : array{16, 1}) do HexAlphabet[BitAnd(Quotient[Byte, Divisor], 15)]

    HexDecode<public>(Text:string)<transacts><decides>:[]int =
        Mod[Text.Length, 2] = 0
        Buffer := text_buffer{Values := Text}
        Count := Quotient[Text.Length, 2]
        if (Count = 0):
            array{}
        else:
            for (Index := 0..Count - 1) do HexValues[Buffer.Values[Index * 2]] * 16 + HexValues[Buffer.Values[Index * 2 + 1]]

    # Verse octet literals provide the byte/code-unit bridge without native casts.
    UTF8ByteCharacters<internal>:[]char = array{
        0o00, 0o01, 0o02, 0o03, 0o04, 0o05, 0o06, 0o07, 0o08, 0o09, 0o0A, 0o0B, 0o0C, 0o0D, 0o0E, 0o0F,
        0o10, 0o11, 0o12, 0o13, 0o14, 0o15, 0o16, 0o17, 0o18, 0o19, 0o1A, 0o1B, 0o1C, 0o1D, 0o1E, 0o1F,
        0o20, 0o21, 0o22, 0o23, 0o24, 0o25, 0o26, 0o27, 0o28, 0o29, 0o2A, 0o2B, 0o2C, 0o2D, 0o2E, 0o2F,
        0o30, 0o31, 0o32, 0o33, 0o34, 0o35, 0o36, 0o37, 0o38, 0o39, 0o3A, 0o3B, 0o3C, 0o3D, 0o3E, 0o3F,
        0o40, 0o41, 0o42, 0o43, 0o44, 0o45, 0o46, 0o47, 0o48, 0o49, 0o4A, 0o4B, 0o4C, 0o4D, 0o4E, 0o4F,
        0o50, 0o51, 0o52, 0o53, 0o54, 0o55, 0o56, 0o57, 0o58, 0o59, 0o5A, 0o5B, 0o5C, 0o5D, 0o5E, 0o5F,
        0o60, 0o61, 0o62, 0o63, 0o64, 0o65, 0o66, 0o67, 0o68, 0o69, 0o6A, 0o6B, 0o6C, 0o6D, 0o6E, 0o6F,
        0o70, 0o71, 0o72, 0o73, 0o74, 0o75, 0o76, 0o77, 0o78, 0o79, 0o7A, 0o7B, 0o7C, 0o7D, 0o7E, 0o7F,
        0o80, 0o81, 0o82, 0o83, 0o84, 0o85, 0o86, 0o87, 0o88, 0o89, 0o8A, 0o8B, 0o8C, 0o8D, 0o8E, 0o8F,
        0o90, 0o91, 0o92, 0o93, 0o94, 0o95, 0o96, 0o97, 0o98, 0o99, 0o9A, 0o9B, 0o9C, 0o9D, 0o9E, 0o9F,
        0oA0, 0oA1, 0oA2, 0oA3, 0oA4, 0oA5, 0oA6, 0oA7, 0oA8, 0oA9, 0oAA, 0oAB, 0oAC, 0oAD, 0oAE, 0oAF,
        0oB0, 0oB1, 0oB2, 0oB3, 0oB4, 0oB5, 0oB6, 0oB7, 0oB8, 0oB9, 0oBA, 0oBB, 0oBC, 0oBD, 0oBE, 0oBF,
        0oC0, 0oC1, 0oC2, 0oC3, 0oC4, 0oC5, 0oC6, 0oC7, 0oC8, 0oC9, 0oCA, 0oCB, 0oCC, 0oCD, 0oCE, 0oCF,
        0oD0, 0oD1, 0oD2, 0oD3, 0oD4, 0oD5, 0oD6, 0oD7, 0oD8, 0oD9, 0oDA, 0oDB, 0oDC, 0oDD, 0oDE, 0oDF,
        0oE0, 0oE1, 0oE2, 0oE3, 0oE4, 0oE5, 0oE6, 0oE7, 0oE8, 0oE9, 0oEA, 0oEB, 0oEC, 0oED, 0oEE, 0oEF,
        0oF0, 0oF1, 0oF2, 0oF3, 0oF4, 0oF5, 0oF6, 0oF7, 0oF8, 0oF9, 0oFA, 0oFB, 0oFC, 0oFD, 0oFE, 0oFF

    }

    UTF8CharacterBytes<internal>:[char]int = map:
        0o00 => 0
        0o01 => 1
        0o02 => 2
        0o03 => 3
        0o04 => 4
        0o05 => 5
        0o06 => 6
        0o07 => 7
        0o08 => 8
        0o09 => 9
        0o0A => 10
        0o0B => 11
        0o0C => 12
        0o0D => 13
        0o0E => 14
        0o0F => 15
        0o10 => 16
        0o11 => 17
        0o12 => 18
        0o13 => 19
        0o14 => 20
        0o15 => 21
        0o16 => 22
        0o17 => 23
        0o18 => 24
        0o19 => 25
        0o1A => 26
        0o1B => 27
        0o1C => 28
        0o1D => 29
        0o1E => 30
        0o1F => 31
        0o20 => 32
        0o21 => 33
        0o22 => 34
        0o23 => 35
        0o24 => 36
        0o25 => 37
        0o26 => 38
        0o27 => 39
        0o28 => 40
        0o29 => 41
        0o2A => 42
        0o2B => 43
        0o2C => 44
        0o2D => 45
        0o2E => 46
        0o2F => 47
        0o30 => 48
        0o31 => 49
        0o32 => 50
        0o33 => 51
        0o34 => 52
        0o35 => 53
        0o36 => 54
        0o37 => 55
        0o38 => 56
        0o39 => 57
        0o3A => 58
        0o3B => 59
        0o3C => 60
        0o3D => 61
        0o3E => 62
        0o3F => 63
        0o40 => 64
        0o41 => 65
        0o42 => 66
        0o43 => 67
        0o44 => 68
        0o45 => 69
        0o46 => 70
        0o47 => 71
        0o48 => 72
        0o49 => 73
        0o4A => 74
        0o4B => 75
        0o4C => 76
        0o4D => 77
        0o4E => 78
        0o4F => 79
        0o50 => 80
        0o51 => 81
        0o52 => 82
        0o53 => 83
        0o54 => 84
        0o55 => 85
        0o56 => 86
        0o57 => 87
        0o58 => 88
        0o59 => 89
        0o5A => 90
        0o5B => 91
        0o5C => 92
        0o5D => 93
        0o5E => 94
        0o5F => 95
        0o60 => 96
        0o61 => 97
        0o62 => 98
        0o63 => 99
        0o64 => 100
        0o65 => 101
        0o66 => 102
        0o67 => 103
        0o68 => 104
        0o69 => 105
        0o6A => 106
        0o6B => 107
        0o6C => 108
        0o6D => 109
        0o6E => 110
        0o6F => 111
        0o70 => 112
        0o71 => 113
        0o72 => 114
        0o73 => 115
        0o74 => 116
        0o75 => 117
        0o76 => 118
        0o77 => 119
        0o78 => 120
        0o79 => 121
        0o7A => 122
        0o7B => 123
        0o7C => 124
        0o7D => 125
        0o7E => 126
        0o7F => 127
        0o80 => 128
        0o81 => 129
        0o82 => 130
        0o83 => 131
        0o84 => 132
        0o85 => 133
        0o86 => 134
        0o87 => 135
        0o88 => 136
        0o89 => 137
        0o8A => 138
        0o8B => 139
        0o8C => 140
        0o8D => 141
        0o8E => 142
        0o8F => 143
        0o90 => 144
        0o91 => 145
        0o92 => 146
        0o93 => 147
        0o94 => 148
        0o95 => 149
        0o96 => 150
        0o97 => 151
        0o98 => 152
        0o99 => 153
        0o9A => 154
        0o9B => 155
        0o9C => 156
        0o9D => 157
        0o9E => 158
        0o9F => 159
        0oA0 => 160
        0oA1 => 161
        0oA2 => 162
        0oA3 => 163
        0oA4 => 164
        0oA5 => 165
        0oA6 => 166
        0oA7 => 167
        0oA8 => 168
        0oA9 => 169
        0oAA => 170
        0oAB => 171
        0oAC => 172
        0oAD => 173
        0oAE => 174
        0oAF => 175
        0oB0 => 176
        0oB1 => 177
        0oB2 => 178
        0oB3 => 179
        0oB4 => 180
        0oB5 => 181
        0oB6 => 182
        0oB7 => 183
        0oB8 => 184
        0oB9 => 185
        0oBA => 186
        0oBB => 187
        0oBC => 188
        0oBD => 189
        0oBE => 190
        0oBF => 191
        0oC0 => 192
        0oC1 => 193
        0oC2 => 194
        0oC3 => 195
        0oC4 => 196
        0oC5 => 197
        0oC6 => 198
        0oC7 => 199
        0oC8 => 200
        0oC9 => 201
        0oCA => 202
        0oCB => 203
        0oCC => 204
        0oCD => 205
        0oCE => 206
        0oCF => 207
        0oD0 => 208
        0oD1 => 209
        0oD2 => 210
        0oD3 => 211
        0oD4 => 212
        0oD5 => 213
        0oD6 => 214
        0oD7 => 215
        0oD8 => 216
        0oD9 => 217
        0oDA => 218
        0oDB => 219
        0oDC => 220
        0oDD => 221
        0oDE => 222
        0oDF => 223
        0oE0 => 224
        0oE1 => 225
        0oE2 => 226
        0oE3 => 227
        0oE4 => 228
        0oE5 => 229
        0oE6 => 230
        0oE7 => 231
        0oE8 => 232
        0oE9 => 233
        0oEA => 234
        0oEB => 235
        0oEC => 236
        0oED => 237
        0oEE => 238
        0oEF => 239
        0oF0 => 240
        0oF1 => 241
        0oF2 => 242
        0oF3 => 243
        0oF4 => 244
        0oF5 => 245
        0oF6 => 246
        0oF7 => 247
        0oF8 => 248
        0oF9 => 249
        0oFA => 250
        0oFB => 251
        0oFC => 252
        0oFD => 253
        0oFE => 254
        0oFF => 255

    UTF8ScalarAt<public>(Source:STL.int_buffer, Offset:int)<transacts><decides>:tuple(int, int) =
        0 <= Offset < Source.Values.Length
        A := Source.Values[Offset]
        if (0 <= A <= 127):
            (A, 1)
        else if (194 <= A <= 223):
            B := Source.Values[Offset + 1]
            128 <= B <= 191
            ((A - 192) * 64 + B - 128, 2)
        else if (224 <= A <= 239):
            B := Source.Values[Offset + 1]
            C := Source.Values[Offset + 2]
            128 <= B <= 191
            128 <= C <= 191
            if (A = 224):
                B >= 160
            if (A = 237):
                B <= 159
            ((A - 224) * 4096 + (B - 128) * 64 + C - 128, 3)
        else:
            240 <= A <= 244
            B := Source.Values[Offset + 1]
            C := Source.Values[Offset + 2]
            D := Source.Values[Offset + 3]
            128 <= B <= 191
            128 <= C <= 191
            128 <= D <= 191
            if (A = 240):
                B >= 144
            if (A = 244):
                B <= 143
            ((A - 240) * 262144 + (B - 128) * 4096 + (C - 128) * 64 + D - 128, 4)

    ValidateUTF8<public>(Data:[]int)<transacts><decides>:void =
        Source := STL.int_buffer{Values := Data}
        var Offset:int = 0
        var IsValid:logic = true
        loop:
            if (Offset >= Data.Length):
                break
            if (Scalar := UTF8ScalarAt[Source, Offset]):
                set Offset += Scalar(1)
            else:
                set IsValid = false
                break
        IsValid?

    UTF8Encode<public>(Text:string)<transacts><decides>:[]int =
        Data := for (Character : Text) do UTF8CharacterBytes[Character]
        ValidateUTF8[Data]
        Data

    UTF8Decode<public>(Data:[]int)<transacts><decides>:string =
        ValidateUTF8[Data]
        for (Byte : Data) do UTF8ByteCharacters[Byte]

    ScalarUTF8Bytes<internal>(Value:int)<computes><decides>:[]int =
        0 <= Value <= 1114111
        not (55296 <= Value <= 57343)
        if (Value < 128):
            array{Value}
        else if (Value < 2048):
            array{192 + Quotient[Value, 64], 128 + BitAnd(Value, 63)}
        else if (Value < 65536):
            array{224 + Quotient[Value, 4096], 128 + BitAnd(Quotient[Value, 64], 63), 128 + BitAnd(Value, 63)}
        else:
            array{240 + Quotient[Value, 262144], 128 + BitAnd(Quotient[Value, 4096], 63), 128 + BitAnd(Quotient[Value, 64], 63), 128 + BitAnd(Value, 63)}

    CodePointsToUTF8<public>(Values:[]int)<transacts><decides>:[]int =
        for (Value : Values):
            0 <= Value <= 1114111
            not (55296 <= Value <= 57343)
        Groups := for (Value : Values) do ScalarUTF8Bytes[Value]
        Concatenate(Groups)

    UTF8ToCodePoints<public>(Data:[]int)<transacts><decides>:[]int =
        Source := STL.int_buffer{Values := Data}
        var Output:[]int = array{}
        var Offset:int = 0
        var IsValid:logic = true
        loop:
            if (Offset >= Data.Length):
                break
            if (Scalar := UTF8ScalarAt[Source, Offset]):
                set Output += array{Scalar(0)}
                set Offset += Scalar(1)
            else:
                set IsValid = false
                break
        IsValid?
        Output

    # Raw UTF-8 code-unit conversion; whole-string validation is provided above.
    CharToByte<public>(Character:char)<computes><decides>:int =
        UTF8CharacterBytes[Character]

    ByteToChar<public>(Value:int)<computes><decides>:char =
        UTF8ByteCharacters[Value]
