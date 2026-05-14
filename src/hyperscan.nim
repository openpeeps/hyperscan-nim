# Nim bindings for Intel's Hyperscan
#
# (c) 2026 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/hyperscan-nim

import hyperscan/bindings
export bindings

type
  DatabaseObj = object
    raw*: HsDatabasePtr

  Database* = ref DatabaseObj

  ScratchObj = object
    raw*: HsScratchPtr

  Scratch* = ref ScratchObj

  StreamObj = object
    raw*: HsStreamPtr
    scratch*: Scratch

  Stream* = ref StreamObj

  Pattern* = object
    expr*: string
    flags*: cuint
    id*: cuint

  MatchCallback* = proc(id: cuint, fromOffset, toOffset: culonglong): bool
    ## Return `false` to terminate scanning early
  
  HsException* = object of CatchableError
    code*: HsError
#
# Helpers
#

proc checkRc(rc: HsError, msg: string) {.inline.} =
  if rc != HS_SUCCESS:
    var e = newException(HsException, msg & " (code: " & $rc & ")")
    e.code = rc
    raise e

#
# Platform / Version
#

proc version*(): string =
  ## Returns the Hyperscan library version string.
  $hs_version()

proc validPlatform*() =
  ## Raises `HsException` if the current CPU is unsupported.
  checkRc hs_valid_platform(), "Unsupported platform"

#
# Database
#

proc `=destroy`(db: DatabaseObj) =
  if db.raw != nil:
    discard hs_free_database(db.raw)

proc compile*(pattern: string,
              flags: cuint = 0,
              mode: cuint = HS_MODE_BLOCK): Database =
  ## Compile a single regex pattern into a `Database`.
  new result
  var err: HsCompileErrorPtr = nil
  let rc = hs_compile(pattern.cstring, flags, mode, nil,
                      addr result.raw, addr err)
  if rc != HS_SUCCESS:
    let msg = if err != nil: $err.message else: "compile error"
    discard hs_free_compile_error(err)
    var e = newException(HsException, msg & " (code: " & $rc & ")")
    e.code = rc
    raise e

proc compile*(patterns: openArray[Pattern],
              mode: cuint = HS_MODE_BLOCK): Database =
  ## Compile multiple patterns into a single `Database`.
  new result
  let n = patterns.len.cuint
  var
    exprs = newSeq[cstring](n)
    flags = newSeq[cuint](n)
    ids   = newSeq[cuint](n)
  for i, p in patterns:
    exprs[i] = p.expr.cstring
    flags[i] = p.flags
    ids[i]   = p.id
  var err: HsCompileErrorPtr = nil
  let rc = hs_compile_multi(addr exprs[0], addr flags[0], addr ids[0],
                            n, mode, nil, addr result.raw, addr err)
  if rc != HS_SUCCESS:
    let msg = if err != nil: $err.message else: "compile_multi error"
    discard hs_free_compile_error(err)
    var e = newException(HsException, msg & " (code: " & $rc & ")")
    e.code = rc
    raise e

proc compileLit*(pattern: string,
                 flags: cuint = 0,
                 mode: cuint = HS_MODE_BLOCK): Database =
  ## Compile a literal (non-regex) pattern into a `Database`.
  new result
  var err: HsCompileErrorPtr = nil
  let rc = hs_compile_lit(pattern.cstring, flags, csize_t(pattern.len),
                          mode, nil, addr result.raw, addr err)
  if rc != HS_SUCCESS:
    let msg = if err != nil: $err.message else: "compile_lit error"
    discard hs_free_compile_error(err)
    var e = newException(HsException, msg & " (code: " & $rc & ")")
    e.code = rc
    raise e

proc size*(db: Database): csize_t =
  ## Returns the size in bytes of the compiled database.
  checkRc hs_database_size(db.raw, addr result), "database_size failed"

proc info*(db: Database): string =
  ## Returns a human-readable info string for the database.
  var s: cstring = nil
  checkRc hs_database_info(db.raw, addr s), "database_info failed"
  result = $s

proc serialize*(db: Database): seq[byte] =
  ## Serializes the database to a byte sequence.
  var
    bytes: cstring = nil
    length: csize_t = 0
  checkRc hs_serialize_database(db.raw, addr bytes, addr length),
          "serialize failed"
  result = newSeq[byte](length)
  copyMem(addr result[0], bytes, length)

proc deserialize*(data: openArray[byte]): Database =
  ## Deserializes a database from a byte sequence.
  new result
  checkRc hs_deserialize_database(cast[cstring](unsafeAddr data[0]),
                                  csize_t(data.len), addr result.raw),
          "deserialize failed"

#
# Scratch
#

proc `=destroy`(s: ScratchObj) =
  if s.raw != nil:
    discard hs_free_scratch(s.raw)

proc newScratch*(db: Database): Scratch =
  ## Allocates a scratch space for the given database.
  new result
  checkRc hs_alloc_scratch(db.raw, addr result.raw), "alloc_scratch failed"

proc clone*(s: Scratch): Scratch =
  ## Clones a scratch space.
  new result
  checkRc hs_clone_scratch(s.raw, addr result.raw), "clone_scratch failed"

proc size*(s: Scratch): csize_t =
  ## Returns the size in bytes of the scratch space.
  checkRc hs_scratch_size(s.raw, addr result), "scratch_size failed"

#
# Block scan
#

proc scan*(db: Database, data: string,
           scratch: Scratch, cb: MatchCallback): bool =
  ## Scans `data` in block mode. Returns `true` if scanning completed,
  ## `false` if the callback requested early termination.
  var cbRef = cb
  proc handler(id: cuint, f, t: culonglong,
               flags: cuint, ctx: pointer): cint {.cdecl.} =
    let fn = cast[ptr MatchCallback](ctx)[]
    if not fn(id, f, t): return 1  # HS_SCAN_TERMINATED
    return 0
  let rc = hs_scan(db.raw, data.cstring, cuint(data.len), 0.cuint,
                   scratch.raw, handler, addr cbRef)
  if rc == HS_SCAN_TERMINATED: return false
  checkRc rc, "scan failed"
  result = true

proc scan*(db: Database, data: string, cb: MatchCallback): bool =
  ## Convenience overload — allocates a temporary scratch space.
  let scratch = newScratch(db)
  db.scan(data, scratch, cb)

#
# Stream scan
#

proc `=destroy`(s: StreamObj) =
  if s.raw != nil:
    discard hs_close_stream(s.raw, nil, nil, nil)

proc openStream*(db: Database, scratch: Scratch): Stream =
  ## Opens a streaming scan session.
  new result
  result.scratch = scratch
  checkRc hs_open_stream(db.raw, 0.cuint, addr result.raw),
          "open_stream failed"

proc scan*(stream: Stream, data: string, cb: MatchCallback): bool =
  ## Pushes `data` into the stream. Returns `false` on early termination.
  var cbRef = cb
  proc handler(id: cuint, f, t: culonglong,
               flags: cuint, ctx: pointer): cint {.cdecl.} =
    let fn = cast[ptr MatchCallback](ctx)[]
    if not fn(id, f, t): return 1
    return 0
  let rc = hs_scan_stream(stream.raw, data.cstring, cuint(data.len),
                          0.cuint, stream.scratch.raw, handler, addr cbRef)
  if rc == HS_SCAN_TERMINATED: return false
  checkRc rc, "scan_stream failed"
  result = true

proc close*(stream: Stream, cb: MatchCallback = nil) =
  ## Closes the stream and flushes any pending matches.
  var cbRef = cb
  proc handler(id: cuint, f, t: culonglong,
               flags: cuint, ctx: pointer): cint {.cdecl.} =
    if ctx == nil: return 0
    let fn = cast[ptr MatchCallback](ctx)[]
    if not fn(id, f, t): return 1
    return 0
  let ctx = if cb != nil: addr cbRef else: nil
  checkRc hs_close_stream(stream.raw, stream.scratch.raw, handler, ctx),
          "close_stream failed"
  stream.raw = nil

proc reset*(stream: Stream, cb: MatchCallback = nil) =
  ## Resets a stream without closing it.
  var cbRef = cb
  proc handler(id: cuint, f, t: culonglong,
               flags: cuint, ctx: pointer): cint {.cdecl.} =
    if ctx == nil: return 0
    let fn = cast[ptr MatchCallback](ctx)[]
    if not fn(id, f, t): return 1
    return 0
  let ctx = if cb != nil: addr cbRef else: nil
  checkRc hs_reset_stream(stream.raw, 0.cuint,
                          stream.scratch.raw, handler, ctx),
          "reset_stream failed"

#
# Expression info (utility)
#

type ExpressionInfo* = object
  minWidth*, maxWidth*: cuint
  unorderedMatches*: bool
  matchesAtEod*: bool
  matchesOnlyAtEod*: bool

proc expressionInfo*(pattern: string, flags: cuint = 0): ExpressionInfo =
  ## Returns width and match property info for a pattern without compiling.
  var
    info: HsExprInfoPtr = nil
    err: HsCompileErrorPtr = nil
  let rc = hs_expression_info(pattern.cstring, flags, addr info, addr err)
  if rc != HS_SUCCESS:
    let msg = if err != nil: $err.message else: "expression_info error"
    discard hs_free_compile_error(err)
    var e = newException(HsException, msg & " (code: " & $rc & ")")
    e.code = rc
    raise e
  result = ExpressionInfo(
    minWidth: info.min_width,
    maxWidth: info.max_width,
    unorderedMatches: int(info.unordered_matches) != 0,
    matchesAtEod: int(info.matches_at_eod) != 0,
    matchesOnlyAtEod: int(info.matches_only_at_eod) != 0
  )
