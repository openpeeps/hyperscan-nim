# Nim bindings for Intel's Hyperscan
#
# (c) 2026 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/hyperscan-nim

#
# HS Common - Types
#

type
  HsDatabase* {.importc: "hs_database_t",
      header: "hs/hs.h", incompleteStruct, byCopy.} = object
  HsDatabasePtr* = ptr HsDatabase

  HsError* = cint

  HsAllocFunc* = proc(size: csize_t): pointer {.cdecl.}
  HsFreeFunc*  = proc(p: pointer) {.cdecl.}

#
# HS Common - Error codes
#

const
  HS_SUCCESS*            = cint(0)
  HS_INVALID*            = cint(-1)
  HS_NOMEM*              = cint(-2)
  HS_SCAN_TERMINATED*    = cint(-3)
  HS_COMPILER_ERROR*     = cint(-4)
  HS_DB_VERSION_ERROR*   = cint(-5)
  HS_DB_PLATFORM_ERROR*  = cint(-6)
  HS_DB_MODE_ERROR*      = cint(-7)
  HS_BAD_ALIGN*          = cint(-8)
  HS_BAD_ALLOC*          = cint(-9)
  HS_SCRATCH_IN_USE*     = cint(-10)
  HS_ARCH_ERROR*         = cint(-11)
  HS_INSUFFICIENT_SPACE* = cint(-12)
  HS_UNKNOWN_ERROR*      = cint(-13)

#
# HS Common - Procs
#

{.push importc, header: "hs/hs.h".}

proc hs_free_database*(db: HsDatabasePtr): HsError
proc hs_serialize_database*(db: HsDatabasePtr,
    bytes: ptr cstring, length: ptr csize_t): HsError
proc hs_deserialize_database*(bytes: cstring, length: csize_t,
    db: ptr HsDatabasePtr): HsError
proc hs_deserialize_database_at*(bytes: cstring, length: csize_t,
    db: HsDatabasePtr): HsError
proc hs_stream_size*(database: HsDatabasePtr,
    stream_size: ptr csize_t): HsError
proc hs_database_size*(database: HsDatabasePtr,
    database_size: ptr csize_t): HsError
proc hs_serialized_database_size*(bytes: cstring, length: csize_t,
    deserialized_size: ptr csize_t): HsError
proc hs_database_info*(database: HsDatabasePtr,
    info: ptr cstring): HsError
proc hs_serialized_database_info*(bytes: cstring, length: csize_t,
    info: ptr cstring): HsError
proc hs_set_allocator*(alloc_func: HsAllocFunc,
    free_func: HsFreeFunc): HsError
proc hs_set_database_allocator*(alloc_func: HsAllocFunc,
    free_func: HsFreeFunc): HsError
proc hs_set_misc_allocator*(alloc_func: HsAllocFunc,
    free_func: HsFreeFunc): HsError
proc hs_set_scratch_allocator*(alloc_func: HsAllocFunc,
    free_func: HsFreeFunc): HsError
proc hs_set_stream_allocator*(alloc_func: HsAllocFunc,
    free_func: HsFreeFunc): HsError
proc hs_version*(): cstring
proc hs_valid_platform*(): HsError

{.pop.}

#
# HS Compile - Types
#

type
  HsCompileError* {.importc: "hs_compile_error_t",
      header: "hs/hs_compile.h", bycopy.} = object
    message*: cstring
    expression*: cint
  HsCompileErrorPtr* = ptr HsCompileError

  HsPlatformInfo* {.importc: "hs_platform_info_t",
      header: "hs/hs_compile.h", bycopy.} = object
    tune*: cuint
    cpu_features*: culonglong
    reserved1*: culonglong
    reserved2*: culonglong
  HsPlatformInfoPtr* = ptr HsPlatformInfo

  HsExprInfo* {.importc: "hs_expr_info_t",
      header: "hs/hs_compile.h", bycopy.} = object
    min_width*: cuint
    max_width*: cuint
    unordered_matches*: cchar
    matches_at_eod*: cchar
    matches_only_at_eod*: cchar
  HsExprInfoPtr* = ptr HsExprInfo

  HsExprExt* {.importc: "hs_expr_ext_t",
      header: "hs/hs_compile.h", bycopy.} = object
    flags*: culonglong
    min_offset*: culonglong
    max_offset*: culonglong
    min_length*: culonglong
    edit_distance*: cuint
    hamming_distance*: cuint
  HsExprExtPtr* = ptr HsExprExt

#
# HS Compile - Flags & constants
#

const
  HS_EXT_FLAG_MIN_OFFSET*       = culonglong(1)
  HS_EXT_FLAG_MAX_OFFSET*       = culonglong(2)
  HS_EXT_FLAG_MIN_LENGTH*       = culonglong(4)
  HS_EXT_FLAG_EDIT_DISTANCE*    = culonglong(8)
  HS_EXT_FLAG_HAMMING_DISTANCE* = culonglong(16)

  HS_FLAG_CASELESS*    = cuint(1)
  HS_FLAG_DOTALL*      = cuint(2)
  HS_FLAG_MULTILINE*   = cuint(4)
  HS_FLAG_SINGLEMATCH* = cuint(8)
  HS_FLAG_ALLOWEMPTY*  = cuint(16)
  HS_FLAG_UTF8*        = cuint(32)
  HS_FLAG_UCP*         = cuint(64)
  HS_FLAG_PREFILTER*   = cuint(128)
  HS_FLAG_SOM_LEFTMOST* = cuint(256)
  HS_FLAG_COMBINATION* = cuint(512)
  HS_FLAG_QUIET*       = cuint(1024)

  HS_CPU_FEATURES_AVX2*       = (culonglong(1) shl 2)
  HS_CPU_FEATURES_AVX512*     = (culonglong(1) shl 3)
  HS_CPU_FEATURES_AVX512VBMI* = (culonglong(1) shl 4)

  HS_TUNE_FAMILY_GENERIC* = cuint(0)
  HS_TUNE_FAMILY_SNB*     = cuint(1)
  HS_TUNE_FAMILY_IVB*     = cuint(2)
  HS_TUNE_FAMILY_HSW*     = cuint(3)
  HS_TUNE_FAMILY_SLM*     = cuint(4)
  HS_TUNE_FAMILY_BDW*     = cuint(5)
  HS_TUNE_FAMILY_SKL*     = cuint(6)
  HS_TUNE_FAMILY_SKX*     = cuint(7)
  HS_TUNE_FAMILY_GLM*     = cuint(8)
  HS_TUNE_FAMILY_ICL*     = cuint(9)
  HS_TUNE_FAMILY_ICX*     = cuint(10)

  HS_MODE_BLOCK*             = cuint(1)
  HS_MODE_NOSTREAM*          = cuint(1)
  HS_MODE_STREAM*            = cuint(2)
  HS_MODE_VECTORED*          = cuint(4)
  HS_MODE_SOM_HORIZON_LARGE*  = (cuint(1) shl 24)
  HS_MODE_SOM_HORIZON_MEDIUM* = (cuint(1) shl 25)
  HS_MODE_SOM_HORIZON_SMALL*  = (cuint(1) shl 26)

#
# HS Compile - Procs
#

{.push importc, header: "hs/hs_compile.h".}

proc hs_compile*(expression: cstring, flags: cuint, mode: cuint,
                 platform: HsPlatformInfoPtr,
                 db: ptr HsDatabasePtr,
                 error: ptr HsCompileErrorPtr): HsError

proc hs_compile_multi*(expressions: ptr cstring, flags: ptr cuint,
                       ids: ptr cuint, elements: cuint, mode: cuint,
                       platform: HsPlatformInfoPtr,
                       db: ptr HsDatabasePtr,
                       error: ptr HsCompileErrorPtr): HsError

proc hs_compile_ext_multi*(expressions: ptr cstring, flags: ptr cuint,
                           ids: ptr cuint,
                           ext: ptr ptr HsExprExt,
                           elements: cuint, mode: cuint,
                           platform: HsPlatformInfoPtr,
                           db: ptr HsDatabasePtr,
                           error: ptr HsCompileErrorPtr): HsError

proc hs_compile_lit*(expression: cstring, flags: cuint, len: csize_t,
                     mode: cuint, platform: HsPlatformInfoPtr,
                     db: ptr HsDatabasePtr,
                     error: ptr HsCompileErrorPtr): HsError

proc hs_compile_lit_multi*(expressions: ptr cstring, flags: ptr cuint,
                           ids: ptr cuint, lens: ptr csize_t,
                           elements: cuint, mode: cuint,
                           platform: HsPlatformInfoPtr,
                           db: ptr HsDatabasePtr,
                           error: ptr HsCompileErrorPtr): HsError

proc hs_free_compile_error*(error: HsCompileErrorPtr): HsError

proc hs_expression_info*(expression: cstring, flags: cuint,
                         info: ptr HsExprInfoPtr,
                         error: ptr HsCompileErrorPtr): HsError

proc hs_expression_ext_info*(expression: cstring, flags: cuint,
                             ext: HsExprExtPtr,
                             info: ptr HsExprInfoPtr,
                             error: ptr HsCompileErrorPtr): HsError

proc hs_populate_platform*(platform: HsPlatformInfoPtr): HsError

{.pop.}

#
# HS Runtime - Types
#

type
  MatchEventHandler* = proc(
    id: cuint,
    fromOffset: culonglong,
    toOffset: culonglong,
    flags: cuint,
    context: pointer
  ): cint {.cdecl.}

  HsStream* {.importc: "hs_stream_t",
      header: "hs/hs_runtime.h", incompleteStruct.} = object
  HsStreamPtr* = ptr HsStream

  HsScratch* {.importc: "hs_scratch_t",
      header: "hs/hs_runtime.h", incompleteStruct.} = object
  HsScratchPtr* = ptr HsScratch

#
# HS Runtime - Constants
#

const
  HS_OFFSET_PAST_HORIZON* = not culonglong(0)

#
# HS Runtime - Procs
#

{.push importc, header: "hs/hs_runtime.h".}

proc hs_open_stream*(db: HsDatabasePtr, flags: cuint,
                     stream: ptr HsStreamPtr): HsError

proc hs_scan_stream*(id: HsStreamPtr, data: cstring,
                     length: cuint, flags: cuint,
                     scratch: HsScratchPtr,
                     onEvent: MatchEventHandler,
                     ctxt: pointer): HsError

proc hs_close_stream*(id: HsStreamPtr,
                      scratch: HsScratchPtr,
                      onEvent: MatchEventHandler,
                      ctxt: pointer): HsError

proc hs_reset_stream*(id: HsStreamPtr, flags: cuint,
                      scratch: HsScratchPtr,
                      onEvent: MatchEventHandler,
                      context: pointer): HsError

proc hs_copy_stream*(to_id: ptr HsStreamPtr,
                     from_id: HsStreamPtr): HsError

proc hs_reset_and_copy_stream*(to_id: HsStreamPtr,
                               from_id: HsStreamPtr,
                               scratch: HsScratchPtr,
                               onEvent: MatchEventHandler,
                               context: pointer): HsError

proc hs_compress_stream*(stream: HsStreamPtr,
                         buf: ptr UncheckedArray[byte],
                         buf_space: csize_t,
                         used_space: ptr csize_t): HsError

proc hs_expand_stream*(db: HsDatabasePtr,
                       stream: ptr HsStreamPtr,
                       buf: ptr UncheckedArray[byte],
                       buf_size: csize_t): HsError

proc hs_reset_and_expand_stream*(to_stream: HsStreamPtr,
                                 buf: ptr UncheckedArray[byte],
                                 buf_size: csize_t,
                                 scratch: HsScratchPtr,
                                 onEvent: MatchEventHandler,
                                 context: pointer): HsError

proc hs_scan*(db: HsDatabasePtr, data: cstring,
              length: cuint, flags: cuint,
              scratch: HsScratchPtr,
              onEvent: MatchEventHandler,
              context: pointer): HsError

proc hs_scan_vector*(db: HsDatabasePtr,
                     data: ptr cstring,
                     length: ptr cuint,
                     count: cuint, flags: cuint,
                     scratch: HsScratchPtr,
                     onEvent: MatchEventHandler,
                     context: pointer): HsError

proc hs_alloc_scratch*(db: HsDatabasePtr,
                       scratch: ptr HsScratchPtr): HsError

proc hs_clone_scratch*(src: HsScratchPtr,
                       dest: ptr HsScratchPtr): HsError

proc hs_scratch_size*(scratch: HsScratchPtr,
                      scratch_size: ptr csize_t): HsError

proc hs_free_scratch*(scratch: HsScratchPtr): HsError

{.pop.}