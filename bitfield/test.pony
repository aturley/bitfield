use "ponytest"
use "collections"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None
  fun tag tests(test: PonyTest) =>
    test(_TestCreate)
    test(_TestFrom)
    test(_TestExtract)
    test(_TestParts)
    test(_TestFloat)

class iso _TestCreate is UnitTest
  fun name(): String => "bitfield/create"

  fun apply(h: TestHelper) =>
    let bf = Bitfield(3, 6)
    h.assert_eq[String]("110", bf.string())

class iso _TestFrom is UnitTest
  fun name(): String => "bitfield/from"

  fun apply(h: TestHelper) =>
    let bf1 = Bitfield(3, 0x5)
    let bf2 = Bitfield(3, 0x6)
    let bf3 = Bitfield(3, 0x7)
    let bf = Bitfield.from([bf1, bf2, bf3])
    h.assert_eq[String]("101110111", bf.string())

class iso _TestExtract is UnitTest
  fun name(): String => "bitfield/extract"

  fun apply(h: TestHelper) ? =>
    let bf = Bitfield(5, 0x1E)
    h.assert_eq[String]("11", bf.extract(0, 2).string())
    h.assert_eq[String]("110", bf.extract(2, 3).string())

class iso _TestParts is UnitTest
  fun name(): String => "bitfield/parts"

  fun apply(h: TestHelper) ? =>
    let bf = Bitfield(10, 0x3EE)
    let parts = bf.parts([2, 8])
    h.assert_eq[String]("11", parts(0).string())
    h.assert_eq[String]("11101110", parts(1).string())

    (let p1, let p2) = bf.parts_2((2, 8))
    h.assert_eq[String]("11", p1.string())
    h.assert_eq[String]("11101110", p2.string())

class iso _TestFloat is UnitTest
  fun name(): String => "bitfield floating point test"

  fun apply(h: TestHelper) ? =>
    let f = F64(1.0)
    let bf = Bitfield(64, f.u128())
    (let sign, let exp, let mantisa) = bf.parts_3((1, 11, 52))

    h.assert_eq[String]("0", sign.string())
    h.assert_eq[String]("00000000000", exp.string())
    h.assert_eq[String]("0000000000000000000000000000000000000000000000000001", mantisa.string())