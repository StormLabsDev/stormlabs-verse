# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API index: see ../API.md for signatures; ../README.md for validation status.
# - int_buffer{Values}: immutable integer-array holder; CopyRange[Start, Stop] copies a checked half-open range.

STL<public> := module:
    # An immutable integer-array holder. Share the object between range reads.
    # Values are not restricted to bytes; cryptographic callers validate bytes.
    int_buffer<public> := class<final>:
        Values<public>:[]int

        # Copy [Start, Stop). Empty ranges are valid, including at the end.
        # Fails unless 0 <= Start <= Stop <= Values.Length.
        CopyRange<public>(Start:int, Stop:int)<transacts><decides>:[]int =
            0 <= Start <= Stop <= Values.Length
            if (Start < Stop):
                for (Index := Start..Stop - 1) do Values[Index]
            else:
                array{}
