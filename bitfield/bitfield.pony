use "collections"

primitive _ShiftCarry
  fun l(bits: U128, shift: USize): (U128, U128) =>
    (bits << shift.u128(), bits >> (128 - shift.u128()))

  fun r(bits: U128, shift: USize): (U128, U128) =>
    (bits >> shift.u128(), bits << (128 - shift.u128()))

class Bitfield
  let _bits_per_chunk: USize = 128
  let _bytes_per_chunk: USize = 16
  let _bit_count: USize
  // Data in _chunks is stored in big-endian order:
  //   _chunks[0] = most significant chunk
  //   ...
  //   _chunks[last] = least significant chunk
  let _chunks: Array[U128]

  new create(bit_count: USize, init: Array[U128] = Array[U128]) =>
    _bit_count = bit_count
    _chunks = Array[U128].init(0, _bits_to_chunks(bit_count))
    let insert_start = _chunks.size() - init.size()
    for (idx, chunk) in init.pairs() do
      try
        _chunks(insert_start + idx) = chunk
      end
    end

  fun size(): USize =>
    _bit_count

  fun string(): String =>
    let acc = recover String end
    for (idx, c) in _chunks.pairs() do
      let start_offset: U128 = if idx == 0 then
        (_bit_count.u128() % 128)  - 1
      else
        127
      end
      for i in Reverse[U128](start_offset, 0) do
        acc.append(((c >> i) and 1).string())
      end
    end
    consume acc

  fun extract(loc: USize, count: USize): Bitfield ? =>
    let chunk_offset = (size() - loc) % 128
    let new_chunk_offset = count % 128

    let required_shift = if (chunk_offset >= new_chunk_offset) then
      chunk_offset - new_chunk_offset
    else
      (chunk_offset + 128) - new_chunk_offset
    end

    let msc_idx = _loc_to_chunk_idx(loc)
    let lsc_idx = _loc_to_chunk_idx(loc + count)
    let input_chunk_count = (lsc_idx - msc_idx) + 1
    let output_chunk_count = _bits_to_chunks(count)

    let chunks = Array[U128].init(0, output_chunk_count)

    var chunk = U128(0)
    var new_carry = U128(0)

    (var carry, let start_idx) = if input_chunk_count == output_chunk_count then
      (U128(0), msc_idx)
    else
      (_ShiftCarry.r(_chunks(msc_idx), required_shift)._2, msc_idx + 1)
    end

    for idx in Range(start_idx, lsc_idx + 1) do
      try
        (chunk, new_carry) = _ShiftCarry.r(_chunks(idx), required_shift)
        chunks(idx - start_idx) = chunk or carry
        carry = new_carry
      end
    end
    // @printf[U32]("new bf with size (%u)!\n".cstring(), count)
    Bitfield(count, chunks)

  fun ref insert(loc: USize, bitfield: Bitfield): Bitfield ? =>
    let count = bitfield.size()
    let chunk_offset = (size() - loc) % 128
    let src_chunk_offset = count % 128

    let required_shift = if (chunk_offset >= src_chunk_offset) then
      chunk_offset - src_chunk_offset
    else
      (chunk_offset + 128) - src_chunk_offset
    end

    let msc_idx = _loc_to_chunk_idx(loc)
    let lsc_idx = _loc_to_chunk_idx(loc + count)
    let dst_chunk_count = (lsc_idx - msc_idx) + 1
    let src_chunk_count = _bits_to_chunks(count + required_shift)

    var chunk = U128(0)
    var new_carry = U128(0)

    (var carry, let start_idx) = if dst_chunk_count == src_chunk_count then
      (U128(0), msc_idx)
    else
      (_ShiftCarry.l(bitfield._chunks(0), required_shift)._2, msc_idx + 1)
    end

    let msc_mask: U128 = U128.max_value() << src_chunk_offset.u128()
    let lsc_mask: U128 = not((not (U128.max_value() << bitfield.size().u128())) << required_shift.u128())
    @printf[U32]("m: 0x%016x, ".cstring(), msc_mask)
    @printf[U32]("l: 0x%016x\n".cstring(), lsc_mask)
    @printf[U32]("required_shift: %u\n".cstring(), required_shift)

    try
      if (start_idx == lsc_idx) then
        @printf[U32]("one!\n".cstring())
        _chunks(start_idx) = _chunks(start_idx) and lsc_mask
      else
        @printf[U32]("more than one!\n".cstring())
        _chunks(start_idx) = _chunks(start_idx) and msc_mask
        _chunks(lsc_idx) = _chunks(lsc_idx) and lsc_mask
      end
    else
      @printf[U32]("error masking lsc_idx:%d, msc_idx:%d, start_idx:%d, %d, %d\n".cstring(), lsc_idx, msc_idx, start_idx, src_chunk_count, dst_chunk_count)
    end

    for idx in Reverse(lsc_idx, start_idx) do
      try
        (chunk, new_carry) = _ShiftCarry.l(bitfield._chunks(idx - start_idx), required_shift)
        if ((idx != lsc_idx) and (idx != msc_idx)) then
          _chunks(idx) = chunk or carry
        else
          _chunks(idx) = _chunks(idx) or chunk or carry
        end
        carry = new_carry
      else
        @printf[U32]("error, idx: %d!\n".cstring(), idx)
      end
    end
    // @printf[U32]("new bf with size (%u)!\n".cstring(), count)
    this

   fun ref rshift_into(bitfield: Bitfield): Bitfield =>
     let shift = bitfield.size()
     let chunks_shift = _bits_to_chunks(shift) - 1
     let bits_shift = shift % 128
     for idx in Reverse((_chunks.size() - 1) - chunks_shift, 0) do
       try
         (let v, let c) = _ShiftCarry.r(_chunks(idx), bits_shift)
         _chunks(idx + chunks_shift) = v
         if (idx + chunks_shift + 1) < size() then
           _chunks(idx + chunks_shift + 1) = _chunks(idx + chunks_shift + 1) or c
         end
       end
     end
     for idx in Range(0, chunks_shift) do
       try
         _chunks(idx) = bitfield._chunks(idx)
       end
     end
     if (chunks_shift + 1) < size() then
       try
         _chunks(chunks_shift + 1) = _chunks(chunks_shift + 1) or bitfield._chunks(bitfield._chunks.size() - 1)
       end
     end
     this

   new from(bitfields: Array[Bitfield]) ? =>
     var bit_count = USize(0)
     let locs = Array[USize].init(0, bitfields.size())
     var last_size: USize = 0

     for (idx, bf) in bitfields.pairs() do
       bit_count = bit_count + bf.size()
       locs(idx) = bf.size() + last_size
       last_size = locs(idx)
     end
     _bit_count = bit_count
     _chunks = if _bit_count < 128 then
       var bits: U128 = 0
       for bf in bitfields.values() do
         try
           bits = (bits << bf.size().u128()) or bf._chunks(0)
         end
       end
       Array[U128].init(bits, 1)
     else
       var last_start_index: USize = 0
       for (idx, bf) in bitfields.pairs() do
         let chunk_offset = locs(idx) % 128
         let bf_chunk_offset = bf.size() % 128
         (let required_shift, let start_index, var carry) = if (bf_chunk_offset > chunk_offset) then
           (bf_chunk_offset - chunk_offset, last_start_index, 0)
         else
           ((bf_chunk_offset + 128) - chunk_offset, last_start_index + 1, _ShiftCarry.l(bf._chunks(0), 0)._2)
         end
       end
       
       Array[U128].init(0, _bits_to_chunks(_bit_count))
     end

  fun parts(counts: Array[USize]): Array[Bitfield] ? =>
    let bfs = Array[Bitfield]
    var pos = USize(0)
    for c in counts.values() do
      bfs.push(extract(pos, c))
      pos = pos + c
    end
    bfs

  fun parts_2(counts_2: (USize, USize)): (Bitfield, Bitfield) ? =>
    let counts = Array[USize].push(counts_2._1).push(counts_2._2)
    let bfs = parts(counts)
    (bfs(0), bfs(1))

  fun parts_3(counts_3: (USize, USize, USize)):
    (Bitfield, Bitfield, Bitfield) ?
  =>
    let counts = Array[USize].push(counts_3._1).push(counts_3._2).push(counts_3._3)
    let bfs = parts(counts)
    (bfs(0), bfs(1), bfs(2))

  fun tag _bits_to_chunks(bits: USize): USize =>
    match bits
    | 0 => 0
    else
      (bits / 128) + 1
    end

  fun _loc_to_chunk_idx(loc: USize): USize =>
    let msb_offset = (128 - 1) - (size() % 128)
    _bits_to_chunks(loc + msb_offset) - 1
