use "collections"

class Bitfield
  let _bits_per_chunk: USize = 128
  let _bytes_per_chunk: USize = 16
  let _bit_count: USize
  // data in _chunks is stored in big-endian order
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
    for c in _chunks.values() do
      for i in Reverse[U128](_bit_count.u128() - 1, 0) do
        acc.append(((c >> i) and 1).string())
      end
    end
    consume acc

//   fun extract(loc: USize, count: USize): Bitfield ? =>
//     if (loc + count) > _bit_count then
//       error
//     end
//     
//     // loc = 1
//     // count = 3
//     // _bit_count = 10
//     // mask = 0...01110_00000
//     // m1 = 1...1           -> all ones
//     // m2 = 0...0111        -> shift right 125 (128 - count)
//     // m3 = 0...01110_00000 -> shift left 6 (_bit_count - (count + loc))
//     let mask = (U128.max_value() >>
//                 (_bits_per_chunk - count).u128()) <<
//                (_bit_count - (count + loc)).u128()
//     Bitfield(count, (_chunk and mask) >> (_bit_count - (count + loc)).u128())
// 
//   new from(bitfields: Array[Bitfield]) =>
//     var chunk: U128 = 0
//     var sz: U128 = 0
//     for bf in bitfields.reverse().values() do
//       chunk = chunk or (bf._chunk << sz)
//       sz = sz + bf.size().u128()
//     end
//     _chunk = chunk
//     _bit_count = sz.usize()
// 
//   fun parts(counts: Array[USize]): Array[Bitfield] ? =>
//     let bfs = Array[Bitfield]
//     var pos = USize(0)
//     for c in counts.values() do
//       bfs.push(extract(pos, c))
//       pos = pos + c
//     end
//     bfs
// 
//   fun parts_2(counts_2: (USize, USize)): (Bitfield, Bitfield) ? =>
//     let counts = Array[USize].push(counts_2._1).push(counts_2._2)
//     let bfs = parts(counts)
//     (bfs(0), bfs(1))
// 
//   fun parts_3(counts_3: (USize, USize, USize)):
//     (Bitfield, Bitfield, Bitfield) ?
//   =>
//     let counts = Array[USize].push(counts_3._1).push(counts_3._2).push(counts_3._3)
//     let bfs = parts(counts)
//     (bfs(0), bfs(1), bfs(2))
// 
  fun tag _bits_to_chunks(bits: USize): USize =>
    match bits
    | 0 => 0
    else
      (bits / 128) + 1
    end