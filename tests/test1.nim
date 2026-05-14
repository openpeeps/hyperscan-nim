import std/[unittest]
import ../src/hyperscan

suite "HyperScan - Platform & Version":
  test "hs_valid_platform returns HS_SUCCESS":
    check hs_valid_platform() == HS_SUCCESS

  test "hs_version returns non-nil string":
    let v = hs_version()
    check v != nil
    check len($v) > 0

suite "HyperScan - Compile (Block Mode)":
  test "compile simple pattern":
    var db: HsDatabasePtr = nil
    var err: HsCompileErrorPtr = nil
    let rc = hs_compile("foo", HS_FLAG_CASELESS, HS_MODE_BLOCK, nil,
                        addr db, addr err)
    check rc == HS_SUCCESS
    check db != nil
    discard hs_free_database(db)

  test "compile invalid pattern returns error":
    var db: HsDatabasePtr = nil
    var err: HsCompileErrorPtr = nil
    let rc = hs_compile("(unclosed", 0.cuint, HS_MODE_BLOCK, nil,
                        addr db, addr err)
    check rc == HS_COMPILER_ERROR
    check err != nil
    check err.message != nil
    discard hs_free_compile_error(err)

  test "compile multi patterns":
    var db: HsDatabasePtr = nil
    var err: HsCompileErrorPtr = nil
    var exprs = [cstring("foo"), cstring("bar"), cstring("baz")]
    var flags = [HS_FLAG_CASELESS, HS_FLAG_CASELESS, HS_FLAG_CASELESS]
    var ids   = [cuint(1), cuint(2), cuint(3)]
    let rc = hs_compile_multi(addr exprs[0], addr flags[0], addr ids[0],
                              3.cuint, HS_MODE_BLOCK, nil,
                              addr db, addr err)
    check rc == HS_SUCCESS
    check db != nil
    discard hs_free_database(db)

  test "compile literal pattern":
    var db: HsDatabasePtr = nil
    var err: HsCompileErrorPtr = nil
    let pat = cstring("hello.world")
    let rc = hs_compile_lit(pat, 0.cuint, csize_t(11),
                            HS_MODE_BLOCK, nil, addr db, addr err)
    check rc == HS_SUCCESS
    check db != nil
    discard hs_free_database(db)

suite "HyperScan - Expression Info":
  test "hs_expression_info for valid pattern":
    var info: HsExprInfoPtr = nil
    var err: HsCompileErrorPtr = nil
    let rc = hs_expression_info("foo+", HS_FLAG_CASELESS,
                                addr info, addr err)
    check rc == HS_SUCCESS
    check info != nil
    check info.min_width >= 3.cuint

suite "HyperScan - Database Info & Size":
  var db: HsDatabasePtr

  setup:
    var err: HsCompileErrorPtr = nil
    discard hs_compile("test", 0.cuint, HS_MODE_BLOCK,
                       nil, addr db, addr err)

  teardown:
    discard hs_free_database(db)

  test "hs_database_size returns positive size":
    var sz: csize_t = 0
    let rc = hs_database_size(db, addr sz)
    check rc == HS_SUCCESS
    check sz > 0

  test "hs_database_info returns non-nil string":
    var info: cstring = nil
    let rc = hs_database_info(db, addr info)
    check rc == HS_SUCCESS
    check info != nil

suite "HyperScan - Scratch":
  var db: HsDatabasePtr
  var scratch: HsScratchPtr

  setup:
    var err: HsCompileErrorPtr = nil
    discard hs_compile("test", 0.cuint, HS_MODE_BLOCK,
                       nil, addr db, addr err)
    scratch = nil
    discard hs_alloc_scratch(db, addr scratch)

  teardown:
    discard hs_free_scratch(scratch)
    discard hs_free_database(db)

  test "hs_alloc_scratch succeeds":
    check scratch != nil

  test "hs_scratch_size returns positive size":
    var sz: csize_t = 0
    let rc = hs_scratch_size(scratch, addr sz)
    check rc == HS_SUCCESS
    check sz > 0

  test "hs_clone_scratch succeeds":
    var clone: HsScratchPtr = nil
    let rc = hs_clone_scratch(scratch, addr clone)
    check rc == HS_SUCCESS
    check clone != nil
    discard hs_free_scratch(clone)

suite "HyperScan - Block Scan":
  var db: HsDatabasePtr
  var scratch: HsScratchPtr

  setup:
    var err: HsCompileErrorPtr = nil
    discard hs_compile("foo", HS_FLAG_CASELESS, HS_MODE_BLOCK,
                       nil, addr db, addr err)
    scratch = nil
    discard hs_alloc_scratch(db, addr scratch)

  teardown:
    discard hs_free_scratch(scratch)
    discard hs_free_database(db)

  test "hs_scan finds match":
    var matchCount = 0
    proc handler(id: cuint, f, t: culonglong,
                 flags: cuint, ctx: pointer): cint {.cdecl.} =
      cast[ptr int](ctx)[] += 1
      return 0
    let data = cstring("hello FOO world")
    let rc = hs_scan(db, data, cuint(15), 0.cuint,
                     scratch, handler, addr matchCount)
    check rc == HS_SUCCESS
    check matchCount > 0

  test "hs_scan no match":
    var matchCount = 0
    proc handler(id: cuint, f, t: culonglong,
                 flags: cuint, ctx: pointer): cint {.cdecl.} =
      cast[ptr int](ctx)[] += 1
      return 0
    let data = cstring("hello world")
    let rc = hs_scan(db, data, cuint(11), 0.cuint,
                     scratch, handler, addr matchCount)
    check rc == HS_SUCCESS
    check matchCount == 0

suite "HyperScan - Serialize & Deserialize":
  test "round-trip serialize/deserialize":
    var db: HsDatabasePtr = nil
    var err: HsCompileErrorPtr = nil
    discard hs_compile("abc", 0.cuint, HS_MODE_BLOCK,
                       nil, addr db, addr err)

    var bytes: cstring = nil
    var length: csize_t = 0
    let rcSer = hs_serialize_database(db, addr bytes, addr length)
    check rcSer == HS_SUCCESS
    check length > 0

    var db2: HsDatabasePtr = nil
    let rcDes = hs_deserialize_database(bytes, length, addr db2)
    check rcDes == HS_SUCCESS
    check db2 != nil

    discard hs_free_database(db)
    discard hs_free_database(db2)

suite "HyperScan - Stream Mode":
  test "open, scan and close stream":
    var db: HsDatabasePtr = nil
    var err: HsCompileErrorPtr = nil
    discard hs_compile("foo", HS_FLAG_CASELESS, HS_MODE_STREAM,
                       nil, addr db, addr err)

    var scratch: HsScratchPtr = nil
    discard hs_alloc_scratch(db, addr scratch)

    var stream: HsStreamPtr = nil
    let rcOpen = hs_open_stream(db, 0.cuint, addr stream)
    check rcOpen == HS_SUCCESS
    check stream != nil

    var matchCount = 0
    proc handler(id: cuint, f, t: culonglong,
                 flags: cuint, ctx: pointer): cint {.cdecl.} =
      cast[ptr int](ctx)[] += 1
      return 0

    let data = cstring("hello foo world")
    let rcScan = hs_scan_stream(stream, data, cuint(15), 0.cuint,
                                scratch, handler, addr matchCount)
    check rcScan == HS_SUCCESS

    let rcClose = hs_close_stream(stream, scratch, handler, addr matchCount)
    check rcClose == HS_SUCCESS
    check matchCount > 0

    discard hs_free_scratch(scratch)
    discard hs_free_database(db)

test "low-level API runnable example":
  # Define a match event handler
  proc onMatch(id: cuint, fromOffset, toOffset: culonglong, flags: cuint, context: pointer): cint {.cdecl.} =
    echo "Match found! ID: ", id, " From: ", fromOffset, " To: ", toOffset
    return 0

  # Compile a pattern
  var db: HsDatabasePtr = nil
  var err: HsCompileErrorPtr = nil
  let pattern = "foo"
  let compileResult = hs_compile(pattern, HS_FLAG_CASELESS, HS_MODE_BLOCK, nil, addr db, addr err)

  if compileResult == HS_SUCCESS:
    echo "Pattern compiled successfully!"
  else:
    echo "Failed to compile pattern: ", err.message
    quit(1)

  # Allocate scratch space
  var scratch: HsScratchPtr = nil
  let scratchResult = hs_alloc_scratch(db, addr scratch)

  if scratchResult != HS_SUCCESS:
    echo "Failed to allocate scratch space!"
    discard hs_free_database(db)
    quit(1)

  # Scan data
  let data = "Hello foo world"
  let scanResult = hs_scan(db, data, cuint(len(data)), 0.cuint, scratch, onMatch, nil)

  if scanResult == HS_SUCCESS:
    echo "Scan completed successfully!"
  else:
    echo "Scan failed!"

  # Clean up
  discard hs_free_scratch(scratch)
  discard hs_free_database(db)