# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API: json_kind, json_value, json_member, json_limits, json_error_code,
# json_error, json_parse_result, json_write_result. See ../API.md.
# Factories: JSONNull, JSONBoolean, JSONNumber, JSONInteger, JSONArray,
# JSONString, JSONObject. Parse, ParseBytes, Write, WriteScalar.
# Values: typed Get* getters, WithElement, Append, WithoutElement,
# WithMember, WithoutMember; results: Value/Text and Error.

JSON<public> := module:
    json_kind<public> := enum:
        Null
        Boolean
        Number
        String
        Array
        Object

    # Only module factories construct values. All fields are immutable snapshots.
    json_value<public> := class<internal><final>:
        Kind<public>:json_kind
        BooleanValue<internal>:logic = false
        NumberLiteral<internal>:string = ""
        StringValue<internal>:string = ""
        ArrayValues<internal>:[]json_value = array{}
        ObjectMembers<internal>:[]json_member = array{}

        GetBoolean<public>()<computes><decides>:logic =
            Kind = json_kind.Boolean
            BooleanValue

        GetNumberLiteral<public>()<computes><decides>:string =
            Kind = json_kind.Number
            NumberLiteral

        # Accept only integer-form tokens within signed 64-bit bounds.
        # Fraction/exponent tokens stay lossless and do not silently round.
        GetInteger<public>()<transacts><decides>:int =
            Kind = json_kind.Number
            IntegerFromLiteral[NumberLiteral]

        GetString<public>()<computes><decides>:string =
            Kind = json_kind.String
            StringValue

        GetArray<public>()<computes><decides>:[]json_value =
            Kind = json_kind.Array
            ArrayValues

        GetElement<public>(Index:int)<computes><decides>:json_value =
            Kind = json_kind.Array
            ArrayValues[Index]

        GetObject<public>()<computes><decides>:[]json_member =
            Kind = json_kind.Object
            ObjectMembers

        # A present null succeeds with Kind=Null; a missing name fails.
        GetMember<public>(Name:string)<transacts><decides>:json_value =
            Kind = json_kind.Object
            Matches := for (Member : ObjectMembers, Member.Name = Name) do Member.Value
            Matches[0]

        WithElement<public>(Index:int, Value:json_value)<transacts><decides>:json_value =
            Kind = json_kind.Array
            0 <= Index < ArrayValues.Length
            Next := for (Position -> Existing : ArrayValues):
                if (Position = Index) then Value else Existing
            JSONArray(Next)

        Append<public>(Value:json_value)<transacts><decides>:json_value =
            Kind = json_kind.Array
            JSONArray(ArrayValues + array{Value})

        WithoutElement<public>(Index:int)<transacts><decides>:json_value =
            Kind = json_kind.Array
            0 <= Index < ArrayValues.Length
            Next := for (Position -> Existing : ArrayValues, Position <> Index) do Existing
            JSONArray(Next)

        # Removing an absent name is a successful no-op snapshot.
        WithoutMember<public>(Name:string)<transacts><decides>:json_value =
            Kind = json_kind.Object
            Next := for (Member : ObjectMembers, Member.Name <> Name) do Member
            json_value{Kind := json_kind.Object, ObjectMembers := Next}

        # Replacement keeps its original slot; a new name is appended.
        WithMember<public>(Name:string, Value:json_value, ?Limits:json_limits = json_limits{})<transacts><decides>:json_value =
            Kind = json_kind.Object
            ValidateLimits[Limits]
            NameBytes := Encoding.UTF8Encode[Name]
            NameBytes.Length <= Limits.MaxStringBytes
            var Replaced:logic = false
            Next := for (Member : ObjectMembers):
                if (Member.Name = Name):
                    set Replaced = true
                    json_member{Name := Name, Value := Value}
                else:
                    Member
            if (Replaced?):
                json_value{Kind := json_kind.Object, ObjectMembers := Next}
            else:
                json_value:
                    Kind := json_kind.Object
                    ObjectMembers := Next + array{json_member{Name := Name, Value := Value}}

    json_member<public> := struct:
        Name<public>:string
        Value<public>:json_value

    json_limits<public> := class<final>:
        MaxDepth<public>:int = 64
        MaxNodes<public>:int = 100000
        MaxInputBytes<public>:int = 1048576
        MaxOutputBytes<public>:int = 1048576
        MaxStringBytes<public>:int = 1048576
        MaxNumberBytes<public>:int = 4096

    ValidateLimits<internal>(Limits:json_limits)<computes><decides>:void =
        1 <= Limits.MaxDepth <= 256
        1 <= Limits.MaxNodes <= 1000000
        1 <= Limits.MaxInputBytes <= 67108864
        1 <= Limits.MaxOutputBytes <= 67108864
        0 <= Limits.MaxStringBytes <= 67108864
        1 <= Limits.MaxNumberBytes <= 1048576

    json_error_code<public> := enum:
        InvalidLimits
        InputLimit
        OutputLimit
        DepthLimit
        NodeLimit
        StringLimit
        NumberLimit
        InvalidUTF8
        UnexpectedEnd
        UnexpectedToken
        InvalidEscape
        InvalidNumber
        DuplicateName
        TrailingInput

    # Zero-based byte offset in UTF-8 input; end of input has offset Length.
    json_error<public> := struct:
        Code<public>:json_error_code
        ByteOffset<public>:int

    json_parse_result<public> := class<internal><final>:
        ParsedValue<internal>:?json_value = false
        Problem<internal>:?json_error = false

        Value<public>()<computes><decides>:json_value =
            ParsedValue?

        Error<public>()<computes><decides>:json_error =
            Problem?

    json_write_result<public> := class<internal><final>:
        OutputText<internal>:?string = false
        Problem<internal>:?json_error = false

        Text<public>()<computes><decides>:string =
            OutputText?

        Error<public>()<computes><decides>:json_error =
            Problem?

    NumberDigits<internal>:[char]int = map:
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

    ValidateNumber<internal>(Text:string)<transacts><decides>:void =
        Text.Length > 0
        var Offset:int = 0
        if (Text[Offset] = '-'):
            set Offset += 1
        if (Text[Offset] = '0'):
            set Offset += 1
        else:
            First := NumberDigits[Text[Offset]]
            First > 0
            set Offset += 1
            loop:
                if (NumberDigits[Text[Offset]]):
                    set Offset += 1
                else:
                    break
        if (Text[Offset] = '.'):
            set Offset += 1
            NumberDigits[Text[Offset]]
            set Offset += 1
            loop:
                if (NumberDigits[Text[Offset]]):
                    set Offset += 1
                else:
                    break
        if (Text[Offset] = 'e' or Text[Offset] = 'E'):
            set Offset += 1
            if (Text[Offset] = '+' or Text[Offset] = '-'):
                set Offset += 1
            NumberDigits[Text[Offset]]
            set Offset += 1
            loop:
                if (NumberDigits[Text[Offset]]):
                    set Offset += 1
                else:
                    break
        Offset = Text.Length

    IntegerFromLiteral<internal>(Text:string)<transacts><decides>:int =
        Text.Length > 0
        var Negative:logic = false
        var Offset:int = 0
        if (Text[0] = '-'):
            set Negative = true
            set Offset = 1
        Offset < Text.Length
        var Accumulator:int = 0
        for (Index := Offset..Text.Length - 1):
            Digit := NumberDigits[Text[Index]]
            Accumulator >= -922337203685477580
            if (Accumulator = -922337203685477580):
                LastDigit := if (Negative?) then 8 else 7
                Digit <= LastDigit
            set Accumulator = Accumulator * 10 - Digit
        if (Negative?) then Accumulator else -Accumulator

    JSONNull<public>()<transacts>:json_value =
        json_value{Kind := json_kind.Null}

    JSONBoolean<public>(Value:logic)<transacts>:json_value =
        json_value{Kind := json_kind.Boolean, BooleanValue := Value}

    JSONNumber<public>(Literal:string, ?Limits:json_limits = json_limits{})<transacts><decides>:json_value =
        ValidateLimits[Limits]
        Literal.Length <= Limits.MaxNumberBytes
        ValidateNumber[Literal]
        json_value{Kind := json_kind.Number, NumberLiteral := Literal}

    JSONInteger<public>(Value:int)<transacts>:json_value =
        json_value{Kind := json_kind.Number, NumberLiteral := ToString(Value)}

    JSONArray<public>(Values:[]json_value)<transacts>:json_value =
        json_value{Kind := json_kind.Array, ArrayValues := Values}

    JSONString<public>(Text:string, ?Limits:json_limits = json_limits{})<transacts><decides>:json_value =
        ValidateLimits[Limits]
        Bytes := Encoding.UTF8Encode[Text]
        Bytes.Length <= Limits.MaxStringBytes
        json_value{Kind := json_kind.String, StringValue := Text}

    JSONObject<public>(Members:[]json_member, ?Limits:json_limits = json_limits{})<transacts><decides>:json_value =
        ValidateLimits[Limits]
        var Seen:[string]logic = map{}
        for (Member : Members):
            NameBytes := Encoding.UTF8Encode[Member.Name]
            NameBytes.Length <= Limits.MaxStringBytes
            not Seen[Member.Name]
            set Seen[Member.Name] = true
        json_value{Kind := json_kind.Object, ObjectMembers := Members}

    # Small scalar operation independent of the UTF-8 dependency.
    WriteScalar<public>(Value:json_value)<transacts><decides>:string =
        if (Value.Kind = json_kind.Null):
            "null"
        else if (Value.Kind = json_kind.Boolean):
            if (Value.BooleanValue?) then "true" else "false"
        else:
            Value.GetNumberLiteral[]

    # Parser and writer state are per-call. Values never contain this state.
    json_writer<internal> := class<final>:
        Limits<internal>:json_limits
        Pretty<internal>:logic
        var Output<private>:[]int = array{}
        var Nodes<private>:int = 0
        var Problem<private>:?json_error = false

        RecordError<private>(Code:json_error_code)<transacts>:void =
            if (not Problem?):
                set Problem = option{json_error{Code := Code, ByteOffset := Output.Length}}

        Emit<private>(Bytes:[]int)<transacts>:void =
            if (Problem?):
                return
            if (Bytes.Length > Limits.MaxOutputBytes - Output.Length):
                RecordError(json_error_code.OutputLimit)
                return
            set Output += Bytes
            return

        NewLine<private>(Depth:int)<transacts>:void =
            if (Pretty?):
                Emit(array{10})
                for (Index := 0..Depth * 2 - 1):
                    Emit(array{32})

        WriteString<private>(Text:string)<transacts>:void =
            if (Bytes := Encoding.UTF8Encode[Text]):
                if (Bytes.Length > Limits.MaxStringBytes):
                    RecordError(json_error_code.StringLimit)
                    return
                Emit(array{34})
                for (Byte : Bytes):
                    if (Problem?):
                        return
                    if (Byte = 34 or Byte = 92):
                        Emit(array{92, Byte})
                    else if (Byte < 32):
                        High := Quotient[Byte, 16] or 0
                        Low := Mod[Byte, 16] or 0
                        if (HighByte := HexBytes[High], LowByte := HexBytes[Low]):
                            Emit(array{92, 117, 48, 48, HighByte, LowByte})
                        else:
                            RecordError(json_error_code.InvalidUTF8)
                            return
                    else:
                        Emit(array{Byte})
                Emit(array{34})
                return
            RecordError(json_error_code.InvalidUTF8)
            return

        WriteValue<private>(Value:json_value, Depth:int)<transacts>:void =
            if (Problem?):
                return
            if (Nodes >= Limits.MaxNodes):
                RecordError(json_error_code.NodeLimit)
                return
            set Nodes += 1
            if (Value.Kind = json_kind.Null):
                Emit(array{110, 117, 108, 108})
            else if (Value.Kind = json_kind.Boolean):
                if (Value.BooleanValue?):
                    Emit(array{116, 114, 117, 101})
                else:
                    Emit(array{102, 97, 108, 115, 101})
            else if (Value.Kind = json_kind.Number):
                if (Value.NumberLiteral.Length > Limits.MaxNumberBytes):
                    RecordError(json_error_code.NumberLimit)
                    return
                if (Bytes := Encoding.UTF8Encode[Value.NumberLiteral]):
                    Emit(Bytes)
                else:
                    RecordError(json_error_code.InvalidUTF8)
            else if (Value.Kind = json_kind.String):
                WriteString(Value.StringValue)
            else:
                if (Depth >= Limits.MaxDepth):
                    RecordError(json_error_code.DepthLimit)
                    return
                if (Value.Kind = json_kind.Array):
                    Emit(array{91})
                    for (Index -> Element : Value.ArrayValues):
                        if (Problem?):
                            return
                        if (Index > 0):
                            Emit(array{44})
                        NewLine(Depth + 1)
                        WriteValue(Element, Depth + 1)
                    if (Value.ArrayValues.Length > 0):
                        NewLine(Depth)
                    Emit(array{93})
                else:
                    Emit(array{123})
                    for (Index -> Member : Value.ObjectMembers):
                        if (Problem?):
                            return
                        if (Index > 0):
                            Emit(array{44})
                        NewLine(Depth + 1)
                        WriteString(Member.Name)
                        Emit(array{58})
                        if (Pretty?):
                            Emit(array{32})
                        WriteValue(Member.Value, Depth + 1)
                    if (Value.ObjectMembers.Length > 0):
                        NewLine(Depth)
                    Emit(array{125})
            return

        Write<internal>(Value:json_value)<transacts>:json_write_result =
            WriteValue(Value, 0)
            if (Error := Problem?):
                return json_write_result{Problem := option{Error}}
            if (Text := Encoding.UTF8Decode[Output]):
                return json_write_result{OutputText := option{Text}}
            return json_write_result:
                Problem := option{json_error{Code := json_error_code.InvalidUTF8, ByteOffset := Output.Length}}

    HexBytes<internal>:[]int = array{48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 97, 98, 99, 100, 101, 102}

    # ByteOffset in a writer error is the number of output bytes before failure.
    # Failed writes expose no partial text.
    Write<public>(Value:json_value, ?Pretty:logic = false, ?Limits:json_limits = json_limits{})<transacts>:json_write_result =
        if (ValidateLimits[Limits]):
            Writer := json_writer{Limits := Limits, Pretty := Pretty}
            return Writer.Write(Value)
        return json_write_result:
            Problem := option{json_error{Code := json_error_code.InvalidLimits, ByteOffset := 0}}

    IsWhitespace<internal>(Byte:int)<computes><decides>:void =
        Byte = 32 or 9 <= Byte <= 10 or Byte = 13

    IsDelimiter<internal>(Byte:int)<computes><decides>:void =
        IsWhitespace[Byte] or Byte = 44 or Byte = 93 or Byte = 125

    HexValue<internal>(Byte:int)<computes><decides>:int =
        if (48 <= Byte <= 57):
            Byte - 48
        else if (65 <= Byte <= 70):
            Byte - 55
        else:
            97 <= Byte <= 102
            Byte - 87

    json_reader<internal> := class<final>:
        Source<internal>:STL.int_buffer
        Limits<internal>:json_limits
        var Offset<private>:int = 0
        var Nodes<private>:int = 0
        var Problem<private>:?json_error = false

        Peek<private>()<transacts><decides>:int =
            Source.Values[Offset]

        RecordError<private>(Code:json_error_code, At:int)<transacts>:void =
            if (not Problem?):
                set Problem = option{json_error{Code := Code, ByteOffset := At}}

        Unexpected<private>()<transacts>:void =
            if (Offset >= Source.Values.Length):
                RecordError(json_error_code.UnexpectedEnd, Offset)
            else:
                RecordError(json_error_code.UnexpectedToken, Offset)

        SkipWhitespace<private>()<transacts>:void =
            loop:
                if (Byte := Peek[], IsWhitespace[Byte]):
                    set Offset += 1
                else:
                    break

        ReadHex4<private>()<transacts>:?int =
            var Value:int = 0
            for (Index := 0..3):
                if (Byte := Peek[]):
                    if (Digit := HexValue[Byte]):
                        set Value = Value * 16 + Digit
                        set Offset += 1
                    else:
                        RecordError(json_error_code.InvalidEscape, Offset)
                        return false
                else:
                    RecordError(json_error_code.UnexpectedEnd, Offset)
                    return false
            return option{Value}

        ReadEscapedScalar<private>(EscapeOffset:int)<transacts>:?int =
            FirstResult := ReadHex4()
            if (First := FirstResult?):
                if (55296 <= First <= 56319):
                    if (Peek[] = 92, Source.Values[Offset + 1] = 117):
                        set Offset += 2
                        SecondResult := ReadHex4()
                        if (Second := SecondResult?):
                            if (56320 <= Second <= 57343):
                                return option{65536 + (First - 55296) * 1024 + Second - 56320}
                            RecordError(json_error_code.InvalidEscape, EscapeOffset)
                            return false
                        return false
                    RecordError(json_error_code.InvalidEscape, EscapeOffset)
                    return false
                if (56320 <= First <= 57343):
                    RecordError(json_error_code.InvalidEscape, EscapeOffset)
                    return false
                return option{First}
            return false

        ReadString<private>()<transacts>:?string =
            # Caller has already checked the opening quote.
            set Offset += 1
            var Bytes:[]int = array{}
            loop:
                if (Byte := Peek[]):
                    if (Byte = 34):
                        set Offset += 1
                        if (Text := Encoding.UTF8Decode[Bytes]):
                            return option{Text}
                        RecordError(json_error_code.InvalidUTF8, Offset - 1)
                        return false
                    if (Byte < 32):
                        RecordError(json_error_code.UnexpectedToken, Offset)
                        return false
                    var NextBytes:[]int = array{}
                    ByteOffset := Offset
                    if (Byte = 92):
                        set Offset += 1
                        if (Escape := Peek[]):
                            set Offset += 1
                            if (Escape = 34 or Escape = 92 or Escape = 47):
                                set NextBytes = array{Escape}
                            else if (Escape = 98):
                                set NextBytes = array{8}
                            else if (Escape = 102):
                                set NextBytes = array{12}
                            else if (Escape = 110):
                                set NextBytes = array{10}
                            else if (Escape = 114):
                                set NextBytes = array{13}
                            else if (Escape = 116):
                                set NextBytes = array{9}
                            else if (Escape = 117):
                                ScalarResult := ReadEscapedScalar(ByteOffset)
                                if (Scalar := ScalarResult?):
                                    if (Encoded := Encoding.CodePointsToUTF8[array{Scalar}]):
                                        set NextBytes = Encoded
                                    else:
                                        RecordError(json_error_code.InvalidEscape, ByteOffset)
                                        return false
                                else:
                                    return false
                            else:
                                RecordError(json_error_code.InvalidEscape, Offset - 1)
                                return false
                        else:
                            RecordError(json_error_code.UnexpectedEnd, Offset)
                            return false
                    else:
                        if (Scalar := Encoding.UTF8ScalarAt[Source, Offset], Copied := Source.CopyRange[Offset, Offset + Scalar(1)]):
                            set NextBytes = Copied
                            set Offset += Scalar(1)
                        else:
                            RecordError(json_error_code.InvalidUTF8, Offset)
                            return false
                    if (NextBytes.Length > Limits.MaxStringBytes - Bytes.Length):
                        RecordError(json_error_code.StringLimit, ByteOffset)
                        return false
                    set Bytes += NextBytes
                else:
                    RecordError(json_error_code.UnexpectedEnd, Offset)
                    return false

        TakeDigits<private>()<transacts>:void =
            loop:
                if (Byte := Peek[], 48 <= Byte <= 57):
                    set Offset += 1
                else:
                    break

        ReadNumber<private>()<transacts>:?json_value =
            Start := Offset
            if (Peek[] = 45):
                set Offset += 1
            if (Peek[] = 48):
                set Offset += 1
                if (Byte := Peek[], 48 <= Byte <= 57):
                    RecordError(json_error_code.InvalidNumber, Offset)
                    return false
            else if (Byte := Peek[], 49 <= Byte <= 57):
                TakeDigits()
            else:
                RecordError(json_error_code.InvalidNumber, Offset)
                return false
            if (Peek[] = 46):
                set Offset += 1
                if (Byte := Peek[], 48 <= Byte <= 57):
                    TakeDigits()
                else:
                    RecordError(json_error_code.InvalidNumber, Offset)
                    return false
            if (Peek[] = 101 or Peek[] = 69):
                set Offset += 1
                if (Peek[] = 43 or Peek[] = 45):
                    set Offset += 1
                if (Byte := Peek[], 48 <= Byte <= 57):
                    TakeDigits()
                else:
                    RecordError(json_error_code.InvalidNumber, Offset)
                    return false
            if (Byte := Peek[]):
                if (not IsDelimiter[Byte]):
                    RecordError(json_error_code.InvalidNumber, Offset)
                    return false
            if (Offset - Start > Limits.MaxNumberBytes):
                RecordError(json_error_code.NumberLimit, Start + Limits.MaxNumberBytes)
                return false
            if (Bytes := Source.CopyRange[Start, Offset], Text := Encoding.UTF8Decode[Bytes]):
                return option{json_value{Kind := json_kind.Number, NumberLiteral := Text}}
            RecordError(json_error_code.InvalidUTF8, Start)
            return false

        ReadLiteral<private>(Expected:[]int, Value:json_value)<transacts>:?json_value =
            for (Byte : Expected):
                if (Peek[] = Byte):
                    set Offset += 1
                else:
                    Unexpected()
                    return false
            return option{Value}

        ReadArray<private>(Depth:int)<transacts>:?json_value =
            set Offset += 1
            SkipWhitespace()
            var Values:[]json_value = array{}
            if (Peek[] = 93):
                set Offset += 1
                return option{JSONArray(Values)}
            loop:
                Parsed := ReadValue(Depth)
                if (Value := Parsed?):
                    set Values += array{Value}
                else:
                    return false
                SkipWhitespace()
                if (Peek[] = 93):
                    set Offset += 1
                    return option{JSONArray(Values)}
                if (Peek[] = 44):
                    set Offset += 1
                    SkipWhitespace()
                else:
                    Unexpected()
                    return false

        ReadObject<private>(Depth:int)<transacts>:?json_value =
            set Offset += 1
            SkipWhitespace()
            var Members:[]json_member = array{}
            var Seen:[string]logic = map{}
            if (Peek[] = 125):
                set Offset += 1
                return option{json_value{Kind := json_kind.Object, ObjectMembers := Members}}
            loop:
                NameOffset := Offset
                if (not (Peek[] = 34)):
                    Unexpected()
                    return false
                NameResult := ReadString()
                if (Name := NameResult?):
                    if (Seen[Name]):
                        RecordError(json_error_code.DuplicateName, NameOffset)
                        return false
                    SkipWhitespace()
                    if (Peek[] = 58):
                        set Offset += 1
                    else:
                        Unexpected()
                        return false
                    SkipWhitespace()
                    Parsed := ReadValue(Depth)
                    if (Value := Parsed?):
                        if (set Seen[Name] = true):
                            set Members += array{json_member{Name := Name, Value := Value}}
                        else:
                            Unexpected()
                            return false
                    else:
                        return false
                else:
                    return false
                SkipWhitespace()
                if (Peek[] = 125):
                    set Offset += 1
                    return option{json_value{Kind := json_kind.Object, ObjectMembers := Members}}
                if (Peek[] = 44):
                    set Offset += 1
                    SkipWhitespace()
                else:
                    Unexpected()
                    return false

        ReadValue<private>(Depth:int)<transacts>:?json_value =
            if (Nodes >= Limits.MaxNodes):
                RecordError(json_error_code.NodeLimit, Offset)
                return false
            set Nodes += 1
            if (Byte := Peek[]):
                if (Byte = 110):
                    return ReadLiteral(array{110, 117, 108, 108}, JSONNull())
                if (Byte = 116):
                    return ReadLiteral(array{116, 114, 117, 101}, JSONBoolean(true))
                if (Byte = 102):
                    return ReadLiteral(array{102, 97, 108, 115, 101}, JSONBoolean(false))
                if (Byte = 34):
                    TextResult := ReadString()
                    if (Text := TextResult?):
                        return option{json_value{Kind := json_kind.String, StringValue := Text}}
                    return false
                if (Byte = 45 or 48 <= Byte <= 57):
                    return ReadNumber()
                if (Byte = 91 or Byte = 123):
                    if (Depth >= Limits.MaxDepth):
                        RecordError(json_error_code.DepthLimit, Offset)
                        return false
                    if (Byte = 91):
                        return ReadArray(Depth + 1)
                    return ReadObject(Depth + 1)
            Unexpected()
            return false

        Read<internal>()<transacts>:json_parse_result =
            # Validate all input first. Invalid UTF-8 wins over grammar errors.
            var CheckedOffset:int = 0
            loop:
                if (CheckedOffset >= Source.Values.Length):
                    break
                if (Scalar := Encoding.UTF8ScalarAt[Source, CheckedOffset]):
                    set CheckedOffset += Scalar(1)
                else:
                    return json_parse_result:
                        Problem := option{json_error{Code := json_error_code.InvalidUTF8, ByteOffset := CheckedOffset}}
            SkipWhitespace()
            Parsed := ReadValue(0)
            if (Value := Parsed?):
                SkipWhitespace()
                if (Offset < Source.Values.Length):
                    RecordError(json_error_code.TrailingInput, Offset)
                else:
                    return json_parse_result{ParsedValue := option{Value}}
            if (Error := Problem?):
                return json_parse_result{Problem := option{Error}}
            return json_parse_result:
                Problem := option{json_error{Code := json_error_code.UnexpectedToken, ByteOffset := Offset}}

    ParseBytes<public>(Bytes:[]int, ?Limits:json_limits = json_limits{})<transacts>:json_parse_result =
        if (not ValidateLimits[Limits]):
            return json_parse_result:
                Problem := option{json_error{Code := json_error_code.InvalidLimits, ByteOffset := 0}}
        if (Bytes.Length > Limits.MaxInputBytes):
            return json_parse_result:
                Problem := option{json_error{Code := json_error_code.InputLimit, ByteOffset := Limits.MaxInputBytes}}
        Reader := json_reader{Source := STL.int_buffer{Values := Bytes}, Limits := Limits}
        return Reader.Read()

    Parse<public>(Text:string, ?Limits:json_limits = json_limits{})<transacts>:json_parse_result =
        # Read raw code units first so malformed UTF-8 retains a useful offset.
        # UTF8Encode would reject it without returning the failing position.
        if (not ValidateLimits[Limits]):
            return json_parse_result:
                Problem := option{json_error{Code := json_error_code.InvalidLimits, ByteOffset := 0}}
        if (Text.Length > Limits.MaxInputBytes):
            return json_parse_result:
                Problem := option{json_error{Code := json_error_code.InputLimit, ByteOffset := Limits.MaxInputBytes}}
        var Bytes:[]int = array{}
        for (Index -> Character : Text):
            if (Byte := Encoding.CharToByte[Character]):
                set Bytes += array{Byte}
            else:
                return json_parse_result:
                    Problem := option{json_error{Code := json_error_code.InvalidUTF8, ByteOffset := Index}}
        return ParseBytes(Bytes, ?Limits := Limits)
