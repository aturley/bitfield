use "ponytest"
use "collections"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None
  fun tag tests(test: PonyTest) =>
    test(_TestCreate)
    test(_TestShiftCarry)
    // test(_TestFrom)
    test(_TestExtract)
    test(_TestInsert)
    test(_TestParts)
    test(_TestFloat)
    test(_TestRShiftInPlace)

class iso _TestCreate is UnitTest
  fun name(): String => "bitfield/create"

  fun apply(h: TestHelper) =>
    let bf = Bitfield(3, [as U128: 6])
    h.assert_eq[String]("110", bf.string())

class iso _TestShiftCarry is UnitTest
  fun name(): String => "bitfield/lshift_carry and bitfield/rshift_carry"

  fun apply(h: TestHelper) =>
    (let r1, let c1) = _ShiftCarry.l(0xFFFFFFFFFFFFFFFFEEEEEEEEEEEEEEEE, 4)
    h.assert_eq[U128](               0xFFFFFFFFFFFFFFFEEEEEEEEEEEEEEEE0, r1)
    h.assert_eq[U128](               0x0000000000000000000000000000000F, c1)

    (let r2, let c2) = _ShiftCarry.r(0xFFFFFFFFFFFFFFFFEEEEEEEEEEEEEEEE, 4)
    h.assert_eq[U128](               0x0FFFFFFFFFFFFFFFFEEEEEEEEEEEEEEE, r2)
    h.assert_eq[U128](               0xE0000000000000000000000000000000, c2)

class iso _TestFrom is UnitTest
  fun name(): String => "bitfield/from"

  fun apply(h: TestHelper) ? =>
    let bf1 = Bitfield(3, [as U128: 0x5])
    let bf2 = Bitfield(3, [as U128: 0x6])
    let bf3 = Bitfield(3, [as U128: 0x7])
    let bf4 = Bitfield.from([bf1, bf2, bf3])
    h.assert_eq[USize](9, bf4.size())
    let sr = "101110111"
    h.assert_eq[String](sr, bf4.string())

    let sr5 = sr + sr + sr + sr + sr +
              sr + sr + sr + sr + sr +
              sr + sr + sr + sr + sr +
              sr + sr + sr + sr + sr
    let bf5 = Bitfield.from([bf4, bf4, bf4, bf4, bf4,
                             bf4, bf4, bf4, bf4, bf4,
                             bf4, bf4, bf4, bf4, bf4,
                             bf4, bf4, bf4, bf4, bf4])
    h.assert_eq[USize](sr5.size(), bf5.size())
    h.assert_eq[String](sr5, bf5.string())

class iso _TestExtract is UnitTest
  fun name(): String => "bitfield/extract"

  fun apply(h: TestHelper) ? =>
    let bf1 = Bitfield(5, [as U128: 0x1E])
    h.assert_eq[String]("1111", bf1.extract(0, 4).string())
    h.assert_eq[String]("1110", bf1.extract(1, 4).string())
    h.assert_eq[String]("111", bf1.extract(0, 3).string())

    // len = 257, (1 x 130) + (0 x 127)
    let bf2 = Bitfield(257, [as U128: 1, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, (1 << 127)])
    h.assert_eq[USize](257, bf2.size())
    h.assert_eq[String]("1", bf2.extract(0, 1).string())
    h.assert_eq[String]("0", bf2.extract(256, 1).string())
    let bf3: Bitfield = bf2.extract(0, 130)
    h.assert_eq[USize](130, bf3.size())
    h.assert_eq[String]("1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111", bf3.string())

class iso _TestInsert is UnitTest
  fun name(): String => "bitfield/insert"

  fun apply(h: TestHelper) ? =>
    let bf1 = Bitfield(5, [as U128: 0x1F])
    let bf2 = Bitfield(3, [as U128: 0x02])
    h.assert_eq[String]("10101", bf1.insert(1, bf2).string())

class iso _TestParts is UnitTest
  fun name(): String => "bitfield/parts"

  fun apply(h: TestHelper) ? =>
    let bf = Bitfield(10, [as U128: 0x3EE])
    let parts = bf.parts([2, 8])
    h.assert_eq[String]("11", parts(0).string())
    h.assert_eq[String]("11101110", parts(1).string())

    (let p1, let p2) = bf.parts_2((2, 8))
    h.assert_eq[String]("11", p1.string())
    h.assert_eq[String]("11101110", p2.string())

class iso _TestRShiftInPlace is UnitTest
  fun name(): String => "bitfield/rshift_in_place"

  fun apply(h: TestHelper) =>
    var bf = Bitfield(257, [as U128: 0x1, 0x00, 0x00])
    var sr = "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    for i in Range(0, 257) do
      h.assert_eq[String](sr, bf.string())
      sr = "0" + sr.substring(0, ISize.from[USize](sr.size()) - 1)
      bf.rshift_into(Bitfield(1))
    end

    bf = Bitfield(260, [as U128: 0xE, 0xE << 124, 0x00])
    sr = "11101110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    for i in Range(0, 260) do
      h.assert_eq[String](sr, bf.string())
      sr = "0" + sr.substring(0, ISize.from[USize](sr.size()) - 1)
      bf.rshift_into(Bitfield(1))
    end

    bf = Bitfield(260, [as U128: 0xE, 0xE << 124, 0x00])
    bf.rshift_into(Bitfield(258))
    sr = "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011"
    h.assert_eq[String](sr, bf.string())

    bf = Bitfield(260, [as U128: 0xE, 0xE << 124, 0x00])
    bf.rshift_into(Bitfield(129))
    sr = "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011101110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    h.assert_eq[String](sr, bf.string())

class iso _TestFloat is UnitTest
  fun name(): String => "bitfield floating point test"

  fun apply(h: TestHelper) ? =>
    _check_float(h, F64(1.0), "0", "00000000000", "0000000000000000000000000000000000000000000000000001")
    _check_float(h, F32(-756.1367), "1", "10001000", "01111010000100011000000")

  fun _check_float(h: TestHelper, f: (F32 | F64), sign: String, exp: String, mantisa: String) ? =>
    (let sz: USize, let locs: (USize, USize, USize), let num: U128) = match f
    | let f32: F32 =>
      (32, (1, 8, 23), U128.from[U32](f32.bits()))
    | let f64: F64 =>
      (64, (1, 11, 52), f64.u128())
    else
      error
    end

    let bf = Bitfield(sz, [num])

    (let actual_sign: Bitfield, let actual_exp: Bitfield, let actual_mantisa: Bitfield) = bf.parts_3(locs)

    h.assert_eq[String](sign, actual_sign.string())
    h.assert_eq[String](exp, actual_exp.string())
    h.assert_eq[String](mantisa, actual_mantisa.string())
