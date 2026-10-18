# Copyright (c) 2026 StormLabs. Licensed under the MIT License.

# Public API index: see ../API.md for signatures; ../README.md for validation status.
# - bloom_filter(t), MakeBloomFilter: BitCount, HashCount, Insert, MightContain, Clear, Clone.

Bloom<public> := module:
    MaxBitCount<internal>:int = 2147483647
    MaxHashCount<internal>:int = 32

    bloom_filter<public>(t:type) := class<internal><final>:
        Storage<internal>:Bits.fixed_bitset
        Probes<internal>:int
        Hash<internal>:type{_(:t, :int)<computes>:int}

        BitCount<public>()<transacts>:int =
            Storage.Count()

        HashCount<public>()<transacts>:int =
            Probes

        Insert<public>(Value:t)<transacts><decides>:void =
            for (Probe := 0..Probes - 1):
                Index := Mod[Hash(Value, Probe), Storage.Count()]
                Storage.Set[Index, 1]

        # Success means possibly present; failure means definitely absent.
        MightContain<public>(Value:t)<transacts><decides>:void =
            for (Probe := 0..Probes - 1):
                Index := Mod[Hash(Value, Probe), Storage.Count()]
                Storage.Get[Index] = 1

        Clear<public>()<transacts>:void =
            Storage.Clear()

        Clone<public>()<transacts>:bloom_filter(t) =
            bloom_filter(t){Storage := Storage.Clone(), Probes := Probes, Hash := Hash}

    MakeBloomFilter<public>(t:type, BitCount:int, HashCount:int, Hash:type{_(:t, :int)<computes>:int})<transacts><decides>:bloom_filter(t) =
        1 <= BitCount <= MaxBitCount
        1 <= HashCount <= MaxHashCount
        Storage := Bits.MakeFixedBitset[BitCount]
        bloom_filter(t){Storage := Storage, Probes := HashCount, Hash := Hash}
