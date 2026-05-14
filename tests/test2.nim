import std/[unittest]
import ../src/hyperscan

#
# Platform & Version
#
suite "High-Level - Platform & Version":
  test "version returns non-empty string":
    let v = version()
    check v.len > 0

  test "validPlatform does not raise":
    # Just ensure no HsException is raised
    try:
      validPlatform()
      check true
    except HsException:
      fail()

#
# Database - Single Pattern
#
suite "High-Level - Database (Single Pattern)":
  test "compile simple pattern succeeds":
    let db = compile("foo")
    check db != nil
    check db.raw != nil

  test "compile with CASELESS flag":
    let db = compile("foo", HS_FLAG_CASELESS)
    check db != nil

  test "compile invalid pattern raises HsException":
    expect HsException:
      discard compile("(unclosed")

  test "compile invalid pattern exception has compiler error code":
    try:
      discard compile("(unclosed")
    except HsException as e:
      check e.code == HS_COMPILER_ERROR

  test "database size is positive":
    let db = compile("foo")
    check db.size() > 0

  test "database info returns non-empty string":
    let db = compile("foo")
    check db.info().len > 0

#
# Database - Literal Pattern
#

suite "High-Level - Database (Literal Pattern)":
  test "compileLit succeeds":
    let db = compileLit("hello.world")
    check db != nil
    check db.raw != nil

  test "compileLit treats dot as literal":
    let db = compileLit("hello.world")
    var matched = false
    discard db.scan("hello.world") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

  test "compileLit does not match regex interpretation":
    let db = compileLit("hello.world")
    var matched = false
    discard db.scan("helloXworld") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check not matched

#
# Database - Multi Pattern
#

suite "High-Level - Database (Multi Pattern)":
  test "compile multi patterns succeeds":
    let patterns = [
      Pattern(expr: "foo", flags: HS_FLAG_CASELESS, id: 1),
      Pattern(expr: "bar", flags: HS_FLAG_CASELESS, id: 2),
      Pattern(expr: "baz", flags: HS_FLAG_CASELESS, id: 3)
    ]
    let db = compile(patterns)
    check db != nil
    check db.raw != nil

  test "compile multi patterns matches each id":
    let patterns = [
      Pattern(expr: "foo", flags: 0, id: 1),
      Pattern(expr: "bar", flags: 0, id: 2),
      Pattern(expr: "baz", flags: 0, id: 3)
    ]
    let db = compile(patterns)
    var ids: seq[cuint]
    discard db.scan("foo bar baz") do(id: cuint, f, t: culonglong) -> bool:
      ids.add(id)
      return true
    check 1.cuint in ids
    check 2.cuint in ids
    check 3.cuint in ids

#
# Database - Serialize / Deserialize
#

suite "High-Level - Serialize & Deserialize":
  test "serialize returns non-empty bytes":
    let db = compile("abc")
    let data = db.serialize()
    check data.len > 0

  test "round-trip serialize/deserialize":
    let db = compile("abc")
    let data = db.serialize()
    let db2 = deserialize(data)
    check db2 != nil
    check db2.raw != nil

  test "deserialized database scans correctly":
    let db = deserialize(compile("abc").serialize())
    var matched = false
    discard db.scan("xabcx") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

#
# Scratch
#

suite "High-Level - Scratch":
  test "newScratch succeeds":
    let db = compile("test")
    let s = newScratch(db)
    check s != nil
    check s.raw != nil

  test "scratch size is positive":
    let db = compile("test")
    let s = newScratch(db)
    check s.size() > 0

  test "clone scratch succeeds":
    let db = compile("test")
    let s = newScratch(db)
    let c = s.clone()
    check c != nil
    check c.raw != nil

  test "cloned scratch has same size":
    let db = compile("test")
    let s = newScratch(db)
    let c = s.clone()
    check c.size() == s.size()

#
# Block Scan
#

suite "High-Level - Block Scan":
  test "scan finds match":
    let db = compile("foo", HS_FLAG_CASELESS)
    var matchCount = 0
    discard db.scan("hello FOO world") do(id: cuint, f, t: culonglong) -> bool:
      inc matchCount
      return true
    check matchCount > 0

  test "scan reports correct offsets":
    let db = compile("foo")
    var fromOff, toOff: culonglong
    discard db.scan("xxxfooyyy") do(id: cuint, f, t: culonglong) -> bool:
      fromOff = f
      toOff   = t
      return true
    check toOff == 6  # "foo" ends at index 6

  test "scan returns true on full completion":
    let db = compile("foo")
    let result = db.scan("foo") do(id: cuint, f, t: culonglong) -> bool:
      return true
    check result == true

  test "scan returns false on early termination":
    let db = compile("foo")
    let result = db.scan("foo foo foo") do(id: cuint, f, t: culonglong) -> bool:
      return false   # stop after first match
    check result == false

  test "scan no match":
    let db = compile("foo")
    var matchCount = 0
    discard db.scan("hello world") do(id: cuint, f, t: culonglong) -> bool:
      inc matchCount
      return true
    check matchCount == 0

  test "scan with explicit scratch":
    let db = compile("bar")
    let scratch = newScratch(db)
    var matched = false
    discard db.scan("foobar", scratch) do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

#
# Stream Scan
#

suite "High-Level - Stream Scan":
  test "openStream succeeds":
    let db = compile("foo", HS_FLAG_CASELESS, HS_MODE_STREAM)
    let scratch = newScratch(db)
    let stream = openStream(db, scratch)
    check stream != nil
    check stream.raw != nil

  test "stream scan finds match across chunks":
    let db = compile("foobar", HS_FLAG_CASELESS, HS_MODE_STREAM)
    let scratch = newScratch(db)
    let stream = openStream(db, scratch)
    var matchCount = 0
    discard stream.scan("foo") do(id: cuint, f, t: culonglong) -> bool:
      inc matchCount
      return true
    discard stream.scan("bar") do(id: cuint, f, t: culonglong) -> bool:
      inc matchCount
      return true
    stream.close()
    check matchCount > 0

  test "stream close flushes pending matches":
    let db = compile("foo", HS_FLAG_CASELESS, HS_MODE_STREAM)
    let scratch = newScratch(db)
    let stream = openStream(db, scratch)
    var matchCount = 0
    discard stream.scan("hello foo world") do(id: cuint, f, t: culonglong) -> bool:
      inc matchCount
      return true
    stream.close() do(id: cuint, f, t: culonglong) -> bool:
      inc matchCount
      return true
    check matchCount > 0

  test "stream reset clears state":
    let db = compile("foo", HS_FLAG_CASELESS, HS_MODE_STREAM)
    let scratch = newScratch(db)
    let stream = openStream(db, scratch)
    let result = stream.scan("foo") do(id: cuint, f, t: culonglong) -> bool:
      # Example callback logic
      echo "Match found! ID: ", id, " From: ", f, " To: ", t
      return true  # Continue scanning

    stream.reset()
    # After reset, scan should work again without error
    var matched = false
    discard stream.scan("foo") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    stream.close()
    check matched

  test "stream scan returns false on early termination":
    let db = compile("foo", HS_FLAG_CASELESS, HS_MODE_STREAM)
    let scratch = newScratch(db)
    let stream = openStream(db, scratch)
    let result = stream.scan("foo foo foo") do(id: cuint, f, t: culonglong) -> bool:
      return false
    stream.close()
    check result == false

#
# Expression Info
#

suite "High-Level - Expression Info":
  test "expressionInfo for simple pattern":
    let info = expressionInfo("foo")
    check info.minWidth == 3
    check info.maxWidth == 3

  test "expressionInfo for plus quantifier":
    let info = expressionInfo("foo+")
    check info.minWidth == 3
    check info.maxWidth > 3

  test "expressionInfo for optional quantifier":
    let info = expressionInfo("fo?o")
    check info.minWidth == 2

  test "expressionInfo invalid pattern raises HsException":
    expect HsException:
      discard expressionInfo("(unclosed")

  test "expressionInfo exception has compiler error code":
    try:
      discard expressionInfo("(unclosed")
    except HsException as e:
      check e.code == HS_COMPILER_ERROR

test "high-level API runnable example":
  # Compile a pattern into a database
  let db = compile("foo", HS_FLAG_CASELESS)

  # Scan some data
  let data = "Hello foo world"
  discard db.scan(data) do (id: cuint, fromOffset, toOffset: culonglong) -> bool:
    echo "Match found! ID: ", id, " From: ", fromOffset, " To: ", toOffset
    return true  # Continue scanning

  # Serialize the database
  let serializedDb = db.serialize()
  echo "Serialized database size: ", serializedDb.len

  # Deserialize the database
  let db2 = deserialize(serializedDb)

  # Scan again with the deserialized database
  discard db2.scan(data) do (id: cuint, fromOffset, toOffset: culonglong) -> bool:
    echo "Match found in deserialized DB! ID: ", id, " From: ", fromOffset, " To: ", toOffset
    return true

suite "High-Level - Regex Patterns":

  test "simple regex pattern matches":
    let db = compile("foo")
    var matched = false
    discard db.scan("foo bar baz") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

  test "regex with quantifiers matches correctly":
    let db = compile("fo+")
    var matched = false
    discard db.scan("foooo bar baz") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

  test "regex with alternation matches one of the patterns":
    let db = compile("foo|bar|baz")
    var ids: seq[cuint]
    discard db.scan("bar") do(id: cuint, f, t: culonglong) -> bool:
      ids.add(id)
      return true
    check ids.len == 1

  test "regex with anchors matches at start of string":
    let db = compile("^foo")
    var matched = false
    discard db.scan("foo bar") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

  test "regex with anchors does not match in the middle of string":
    let db = compile("^foo")
    var matched = false
    discard db.scan("bar foo") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check not matched

  test "regex with character classes matches correctly":
    let db = compile("[a-z]+")
    var matched = false
    discard db.scan("123abc456") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

  test "regex with negated character classes does not match excluded characters":
    let db = compile("[^a-z]+")
    var matched = false
    discard db.scan("abc123") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

  test "regex with groups captures correctly":
    let db = compile("(foo)(bar)")
    var matched = false
    discard db.scan("foobar") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

  test "regex with escaped characters matches correctly":
    let db = compile("\\.\\*\\?")
    var matched = false
    discard db.scan(".*?") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

  test "regex with unicode characters matches correctly":
    let db = compile("你好")
    var matched = false
    discard db.scan("你好世界") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

  test "regex with case-insensitive flag matches regardless of case":
    let db = compile("foo", HS_FLAG_CASELESS)
    var matched = false
    discard db.scan("FOO") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

  test "regex with multiline flag matches across lines":
    let db = compile("^foo", HS_FLAG_MULTILINE)
    var matched = false
    discard db.scan("bar\nfoo") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

  test "regex with dotall flag matches newlines":
    let db = compile("foo.bar", HS_FLAG_DOTALL)
    var matched = false
    discard db.scan("foo\nbar") do(id: cuint, f, t: culonglong) -> bool:
      matched = true
      return true
    check matched

  test "regex with invalid pattern raises HsException":
    expect HsException:
      discard compile("foo(")

  test "regex with invalid pattern exception has compiler error code":
    try:
      discard compile("foo(")
    except HsException as e:
      check e.code == HS_COMPILER_ERROR