// Compare two GPU-visible snapshots of a byte range and return one bit per KiB.
// Descriptor slots 0 and 1 are raw SRVs padded to a dword, 2 a zeroed raw
// mask UAV, and 3 a raw SRV holding the logical byte length in its first dword.
groupshared uint blockChanged;

[numthreads(256, 1, 1)]
void main(uint3 group : SV_GroupID, uint lane : SV_GroupIndex)
{
    ByteAddressBuffer before = ResourceDescriptorHeap[0];
    ByteAddressBuffer after = ResourceDescriptorHeap[1];
    RWByteAddressBuffer changed = ResourceDescriptorHeap[2];
    ByteAddressBuffer parameters = ResourceDescriptorHeap[3];
    uint length = parameters.Load(0);
    uint offset = group.x * 1024 + lane * 4;
    if (lane == 0)
        blockChanged = 0;
    GroupMemoryBarrierWithGroupSync();
    if (offset < length) {
        uint validBytes = min(length - offset, 4u);
        uint mask = 0xffffffffu >> ((4u - validBytes) * 8u);
        if (((before.Load(offset) ^ after.Load(offset)) & mask) != 0)
            InterlockedOr(blockChanged, 1u);
    }
    GroupMemoryBarrierWithGroupSync();
    if (lane == 0 && blockChanged != 0)
        changed.InterlockedOr(4u * (group.x / 32u), 1u << (group.x % 32u));
}
